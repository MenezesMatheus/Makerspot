//
//  SpotsViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class SpotsViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    private(set) var cadastro: CadastrarSpotViewModel?
    let fotosSpots: FotosSpotsViewModel
    private(set) var spots: [Spot] = []
    private(set) var identificadoresSalvos: Set<UUID> = []
    private(set) var estaCarregando = false
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0
    private(set) var tipoSelecionado: TipoSpot?
    private(set) var coordenadasDeReferencia: Coordenadas?
    private(set) var dataAtual = Date()

    private let crud: SpotCRUD
    private let salvosCRUD: SalvosCRUD
    private let localizacaoUsuario: ServicoLocalizacaoUsuario
    private let usuarioAtualID: () -> UUID?
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var criarCadastro: (() -> CadastrarSpotViewModel)?
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    private(set) var carregouPrimeiraPagina = false

    var eventosEmDestaque: [Spot] {
        let eventosDisponiveis = spots.filter { spot in
            spot.tipo == .evento && spot.estaDisponivel(em: dataAtual)
        }

        return Array(eventosDisponiveis.sorted(by: ordenarEventos).prefix(3))
    }

    var espacosEmDestaque: [Spot] {
        let espacos = spots.filter { $0.tipo == .espaco }
        return Array(espacos.sorted(by: ordenarPorProximidade).prefix(5))
    }

    init(
        crud: SpotCRUD,
        salvosCRUD: SalvosCRUD,
        fotosSpots: FotosSpotsViewModel,
        localizacaoUsuario: ServicoLocalizacaoUsuario,
        usuarioAtualID: @escaping () -> UUID?,
        tamanhoDaPagina: Int = 30
    ) {
        self.crud = crud
        self.salvosCRUD = salvosCRUD
        self.fotosSpots = fotosSpots
        self.localizacaoUsuario = localizacaoUsuario
        self.usuarioAtualID = usuarioAtualID
        self.tamanhoDaPagina = max(1, tamanhoDaPagina)
    }

    convenience init(
        sessao: SessaoUsuario,
        tamanhoDaPagina: Int = 30
    ) {
        self.init(
            crud: SpotCRUD(sessao: sessao),
            salvosCRUD: SalvosCRUD(sessao: sessao),
            fotosSpots: FotosSpotsViewModel(sessao: sessao),
            localizacaoUsuario: ServicoLocalizacaoUsuario(),
            usuarioAtualID: { [weak sessao] in sessao?.usuarioAtual?.id },
            tamanhoDaPagina: tamanhoDaPagina
        )
        observarAlteracoes(sessao.alteracoesSpots)
        criarCadastro = { CadastrarSpotViewModel(sessao: sessao) }
    }

    func iniciarCadastro() {
        guard cadastro == nil else { return }
        cadastro = criarCadastro?()
    }

    func encerrarCadastro() {
        if let spot = cadastro?.spotCriado, spot.estaDisponivel() {
            let atualizado = alteracoes?.spots[spot.id] ?? spot
            spots.removeAll { $0.id == spot.id }
            spots.insert(atualizado, at: 0)
            identificadoresCarregados.insert(spot.id)
        }
        cadastro = nil
    }

    func carregarPrimeiraPagina(tipo: TipoSpot? = nil) async {
        guard !estaCarregando else { return }
        redefinirPaginacao(tipo: tipo)

        let tarefaLocalizacao = Task {
            await localizacaoUsuario.obterCoordenadas()
        }
        let tarefaEventos = Task {
            try await crud.listarEventosAtivos()
        }

        var paginasCarregadas = 0
        repeat {
            await carregarProximaPagina()
            paginasCarregadas += 1
        } while precisaCompletarDestaques
            && podeCarregarMais
            && paginasCarregadas < 3

        if !Task.isCancelled, let eventos = try? await tarefaEventos.value {
            incorporarEventos(eventos)
        }
        coordenadasDeReferencia = await tarefaLocalizacao.value
        await sincronizarSalvos()
    }

    func recarregar() async {
        guard carregouPrimeiraPagina else {
            await carregarPrimeiraPagina(tipo: tipoSelecionado)
            return
        }
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer {
            estaCarregando = false
            aplicarAlteracoes()
        }

        do {
            let tarefaEventos = Task {
                try await crud.listarEventosAtivos()
            }
            var novos: [Spot] = []
            var novoCursor: CursorPaginaSpots?
            var ignorados = 0
            var paginasCarregadas = 0
            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: tipoSelecionado,
                    limite: tamanhoDaPagina,
                    continuando: novoCursor
                )
                novos.append(contentsOf: pagina.spots)
                ignorados += pagina.quantidadeRegistrosIgnorados
                novoCursor = pagina.proximoCursor
                paginasCarregadas += 1
            } while novoCursor != nil
                && paginasCarregadas < 3
                && novos.filter { $0.tipo == .espaco }.count < 5
                && !Task.isCancelled

            guard !Task.isCancelled else { return }
            spots = novos
            cursor = novoCursor
            identificadoresCarregados = Set(novos.map(\.id))
            quantidadeRegistrosIgnorados = ignorados
            podeCarregarMais = novoCursor != nil
            if !Task.isCancelled, let eventos = try? await tarefaEventos.value {
                incorporarEventos(eventos)
            }
            await sincronizarSalvos()
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func carregarProximaPagina() async {
        guard !estaCarregando, podeCarregarMais else { return }

        estaCarregando = true
        mensagemDeErro = nil
        defer {
            estaCarregando = false
            aplicarAlteracoes()
        }

        do {
            let quantidadeAntes = spots.count
            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: tipoSelecionado,
                    limite: tamanhoDaPagina,
                    continuando: cursor
                )

                for spot in pagina.spots
                where identificadoresCarregados.insert(spot.id).inserted {
                    spots.append(spot)
                }
                quantidadeRegistrosIgnorados += pagina.quantidadeRegistrosIgnorados
                cursor = pagina.proximoCursor
            } while spots.count == quantidadeAntes
                && cursor != nil
                && !Task.isCancelled

            carregouPrimeiraPagina = true
            podeCarregarMais = cursor != nil
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
            podeCarregarMais = !carregouPrimeiraPagina || cursor != nil
        }
    }

    func limpar() {
        redefinirPaginacao(tipo: nil)
        identificadoresSalvos = []
        coordenadasDeReferencia = nil
        fotosSpots.limpar()
        podeCarregarMais = false
    }

    func estaSalvo(_ spot: Spot) -> Bool {
        identificadoresSalvos.contains(spot.id)
    }

    func podeSalvar(_ spot: Spot) -> Bool {
        guard let usuarioID = usuarioAtualID() else { return false }
        return spot.proprietarioID != usuarioID
    }

    func alternarSalvo(do spot: Spot) {
        guard spots.contains(where: { $0.id == spot.id }), podeSalvar(spot) else { return }
        mensagemDeErro = nil
        do {
            try salvosCRUD.alternar(spot: spot)
            identificadoresSalvos = Set(try salvosCRUD.listar().map(\.spotID))
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func atualizarDisponibilidade() {
        dataAtual = Date()
        aplicarAlteracoes()
        spots.removeAll { !$0.estaDisponivel(em: dataAtual) }
    }

    private func observarAlteracoes(_ alteracoes: AlteracoesSpots) {
        self.alteracoes = alteracoes
        observacaoAlteracoes = alteracoes.atualizacoes.sink { [weak self] in
            self?.aplicarAlteracoes()
        }
        aplicarAlteracoes()
    }

    private func aplicarAlteracoes() {
        guard let alteracoes else { return }
        spots = alteracoes.consolidar(spots) {
            $0.estaDisponivel(em: dataAtual) && (tipoSelecionado == nil || $0.tipo == tipoSelecionado)
        }
        if let salvos = try? salvosCRUD.listar() {
            identificadoresSalvos = Set(salvos.map(\.spotID))
        }
    }

    private func sincronizarSalvos() async {
        do {
            identificadoresSalvos = Set(try salvosCRUD.listar().map(\.spotID))
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    private func redefinirPaginacao(tipo: TipoSpot?) {
        dataAtual = Date()
        spots = []
        cursor = nil
        identificadoresCarregados = []
        quantidadeRegistrosIgnorados = 0
        mensagemDeErro = nil
        tipoSelecionado = tipo
        carregouPrimeiraPagina = false
        podeCarregarMais = true
    }

    private var precisaCompletarDestaques: Bool {
        espacosEmDestaque.count < 5
    }

    private func ordenarEventos(_ primeiro: Spot, _ segundo: Spot) -> Bool {
        let pontuacaoPrimeiro = pontuacaoDestaque(primeiro)
        let pontuacaoSegundo = pontuacaoDestaque(segundo)
        if pontuacaoPrimeiro != pontuacaoSegundo {
            return pontuacaoPrimeiro < pontuacaoSegundo
        }
        if inicio(do: primeiro) != inicio(do: segundo) {
            return inicio(do: primeiro) < inicio(do: segundo)
        }
        return primeiro.id.uuidString < segundo.id.uuidString
    }

    private func pontuacaoDestaque(_ spot: Spot) -> Double {
        let horasAteInicio = max(0, inicio(do: spot).timeIntervalSince(dataAtual) / 3_600)
        guard coordenadasDeReferencia != nil else { return horasAteInicio }
        // Uma hora de espera pesa tanto quanto dois quilômetros de deslocamento.
        return horasAteInicio * 2 + distanciaAteReferencia(spot) / 1_000
    }

    private func incorporarEventos(_ eventos: [Spot]) {
        for evento in eventos where tipoSelecionado == nil || tipoSelecionado == .evento {
            if let indice = spots.firstIndex(where: { $0.id == evento.id }) {
                spots[indice] = evento
            } else {
                spots.append(evento)
            }
            identificadoresCarregados.insert(evento.id)
        }
        aplicarAlteracoes()
    }

    private func ordenarPorProximidade(_ primeiro: Spot, _ segundo: Spot) -> Bool {
        guard coordenadasDeReferencia != nil else {
            return primeiro.nome.localizedCaseInsensitiveCompare(segundo.nome)
                == .orderedAscending
        }

        let distanciaPrimeiro = distanciaAteReferencia(primeiro)
        let distanciaSegundo = distanciaAteReferencia(segundo)
        if distanciaPrimeiro == distanciaSegundo {
            return primeiro.nome.localizedCaseInsensitiveCompare(segundo.nome)
                == .orderedAscending
        }
        return distanciaPrimeiro < distanciaSegundo
    }

    private func inicio(do spot: Spot) -> Date {
        guard case .evento(let evento) = spot.detalhes else {
            return .distantFuture
        }
        return evento.inicio
    }

    private func distanciaAteReferencia(_ spot: Spot) -> Double {
        guard let referencia = coordenadasDeReferencia else {
            return .greatestFiniteMagnitude
        }

        let latitude1 = referencia.latitude * .pi / 180
        let latitude2 = spot.localizacao.coordenadas.latitude * .pi / 180
        let diferencaLatitude = latitude2 - latitude1
        let diferencaLongitude = (
            spot.localizacao.coordenadas.longitude - referencia.longitude
        ) * .pi / 180

        let haversine = pow(sin(diferencaLatitude / 2), 2)
            + cos(latitude1) * cos(latitude2)
            * pow(sin(diferencaLongitude / 2), 2)

        return 6_371_000 * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }
}
