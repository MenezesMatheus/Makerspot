//
//  BuscaViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class BuscaViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    let fotosSpots: FotosSpotsViewModel
    var texto = ""
    private(set) var tipoSelecionado: TipoSpot?
    private(set) var spotsCarregados: [Spot] = []
    private(set) var identificadoresSalvos: Set<UUID> = []
    private(set) var estaCarregando = false
    private(set) var estaCompletandoBusca = false
    private(set) var estaSincronizandoSalvos = false
    private(set) var spotsEmAlteracao: Set<UUID> = []
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0
    private(set) var agora = Date()

    private let crud: SpotCRUD
    private let salvosCRUD: SalvosCRUD
    private let usuarioAtualID: () -> UUID?
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    private(set) var carregouPrimeiraPagina = false

    var resultados: [Spot] {
        let termo = normalizar(texto)
        let disponiveis = spotsCarregados.filter { $0.estaDisponivel(em: agora) }
        guard !termo.isEmpty else { return disponiveis }

        return disponiveis.filter { spot in
            let endereco = spot.localizacao.endereco
            let campos = [
                spot.nome,
                spot.descricao,
                spot.nomePublicador,
                endereco.logradouro,
                endereco.bairro,
                endereco.cidade,
                endereco.estado,
                endereco.codigoPostal
            ]
            return campos
                .compactMap { $0 }
                .contains { normalizar($0).contains(termo) }
        }
    }

    init(
        crud: SpotCRUD,
        salvosCRUD: SalvosCRUD,
        fotosSpots: FotosSpotsViewModel,
        usuarioAtualID: @escaping () -> UUID?,
        tamanhoDaPagina: Int = 30
    ) {
        self.crud = crud
        self.salvosCRUD = salvosCRUD
        self.fotosSpots = fotosSpots
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
            usuarioAtualID: { [weak sessao] in sessao?.usuarioAtual?.id },
            tamanhoDaPagina: tamanhoDaPagina
        )
        observarAlteracoes(sessao.alteracoesSpots)
    }

    func carregarPrimeiraPagina() async {
        guard !estaCarregando else { return }
        redefinirPaginacao()
        await carregarProximaPagina()
        await sincronizarSalvos()
    }

    func definirTipo(_ tipo: TipoSpot?) async {
        guard tipoSelecionado != tipo else { return }
        tipoSelecionado = tipo
        await carregarPrimeiraPagina()
    }

    func recarregar() async {
        await carregarPrimeiraPagina()
    }

    func completarResultadosDaBusca() async {
        guard !normalizar(texto).isEmpty else { return }

        estaCompletandoBusca = true
        defer { estaCompletandoBusca = false }

        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            return
        }

        while !Task.isCancelled, podeCarregarMais {
            while estaCarregando, !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            await carregarProximaPagina()

            if mensagemDeErro != nil {
                return
            }
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
            let quantidadeAntes = spotsCarregados.count
            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: tipoSelecionado,
                    limite: tamanhoDaPagina,
                    continuando: cursor
                )

                for spot in pagina.spots
                where identificadoresCarregados.insert(spot.id).inserted {
                    spotsCarregados.append(spot)
                }
                quantidadeRegistrosIgnorados += pagina.quantidadeRegistrosIgnorados
                cursor = pagina.proximoCursor
            } while spotsCarregados.count == quantidadeAntes
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
        texto = ""
        tipoSelecionado = nil
        redefinirPaginacao()
        identificadoresSalvos = []
        spotsEmAlteracao = []
        fotosSpots.limpar()
        podeCarregarMais = false
    }

    func estaSalvo(_ spot: Spot) -> Bool {
        identificadoresSalvos.contains(spot.id)
    }

    func estaAlterandoSalvo(_ spot: Spot) -> Bool {
        estaSincronizandoSalvos || spotsEmAlteracao.contains(spot.id)
    }

    func podeSalvar(_ spot: Spot) -> Bool {
        guard let usuarioID = usuarioAtualID() else { return false }
        return spot.proprietarioID != usuarioID
    }

    func alternarSalvo(do spot: Spot) async {
        guard spotsCarregados.contains(where: { $0.id == spot.id }),
              podeSalvar(spot),
              !estaSincronizandoSalvos,
              spotsEmAlteracao.insert(spot.id).inserted else {
            return
        }

        mensagemDeErro = nil
        defer { spotsEmAlteracao.remove(spot.id) }

        let estavaSalvo = identificadoresSalvos.contains(spot.id)
        if estavaSalvo {
            identificadoresSalvos.remove(spot.id)
        } else {
            identificadoresSalvos.insert(spot.id)
        }

        do {
            if estavaSalvo {
                try await salvosCRUD.dessalvar(spotID: spot.id)
            } else {
                _ = try await salvosCRUD.salvar(spotID: spot.id)
            }
        } catch ErroCloudKit.operacaoCancelada {
            restaurarEstadoSalvo(estavaSalvo, spotID: spot.id)
            return
        } catch is CancellationError {
            restaurarEstadoSalvo(estavaSalvo, spotID: spot.id)
            return
        } catch {
            restaurarEstadoSalvo(estavaSalvo, spotID: spot.id)
            mensagemDeErro = error.localizedDescription
        }
    }

    private func restaurarEstadoSalvo(_ estavaSalvo: Bool, spotID: UUID) {
        if estavaSalvo {
            identificadoresSalvos.insert(spotID)
        } else {
            identificadoresSalvos.remove(spotID)
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func atualizarDisponibilidade() {
        agora = Date()
        aplicarAlteracoes()
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
        spotsCarregados = alteracoes.consolidar(spotsCarregados) {
            $0.estaDisponivel() && (tipoSelecionado == nil || $0.tipo == tipoSelecionado)
        }
        let pendentesSalvos = identificadoresSalvos.intersection(spotsEmAlteracao)
        identificadoresSalvos = alteracoes.consolidarSalvos(identificadoresSalvos)
            .subtracting(spotsEmAlteracao).union(pendentesSalvos)
    }

    func sincronizarSalvos() async {
        guard !estaSincronizandoSalvos else { return }
        estaSincronizandoSalvos = true
        defer {
            estaSincronizandoSalvos = false
            aplicarAlteracoes()
        }

        do {
            identificadoresSalvos = Set(
                try await salvosCRUD.listar().map(\.spotID)
            )
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    private func redefinirPaginacao() {
        spotsCarregados = []
        cursor = nil
        identificadoresCarregados = []
        quantidadeRegistrosIgnorados = 0
        mensagemDeErro = nil
        carregouPrimeiraPagina = false
        podeCarregarMais = true
    }

    private func normalizar(_ valor: String) -> String {
        valor
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
    }
}
