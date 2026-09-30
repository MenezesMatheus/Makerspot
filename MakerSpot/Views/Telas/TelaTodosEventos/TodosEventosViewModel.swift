//
//  TodosEventosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class TodosEventosViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    private(set) var cadastro: CadastrarSpotViewModel?
    let fotosSpots: FotosSpotsViewModel
    private(set) var eventos: [Spot] = []
    private(set) var identificadoresSalvos: Set<UUID> = []
    private(set) var estaCarregando = false
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0

    private let crud: SpotCRUD
    private let salvosCRUD: SalvosCRUD
    private let usuarioAtualID: () -> UUID?
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    private(set) var carregouPrimeiraPagina = false
    @ObservationIgnored private var criarCadastro: (() -> CadastrarSpotViewModel)?

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
        criarCadastro = {
            let cadastro = CadastrarSpotViewModel(sessao: sessao)
            cadastro.tipoSelecionado = .evento
            return cadastro
        }
    }

    func iniciarCadastro() {
        guard cadastro == nil else { return }
        cadastro = criarCadastro?()
    }

    func encerrarCadastro() {
        defer { cadastro = nil }
        guard let criado = cadastro?.spotCriado,
              criado.tipo == .evento,
              criado.estaDisponivel() else {
            return
        }

        let atualizado = alteracoes?.spots[criado.id] ?? criado
        if let indice = eventos.firstIndex(where: { $0.id == criado.id }) {
            eventos[indice] = atualizado
        } else {
            eventos.insert(atualizado, at: 0)
            identificadoresCarregados.insert(criado.id)
        }
    }

    func carregarPrimeiraPagina() async {
        guard !estaCarregando else { return }
        redefinirPaginacao()
        await carregarProximaPagina()
        await sincronizarSalvos()
    }

    func recarregar() async {
        guard carregouPrimeiraPagina else {
            await carregarPrimeiraPagina()
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
            var novos: [Spot] = []
            var novoCursor: CursorPaginaSpots?
            var ignorados = 0
            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: .evento,
                    limite: tamanhoDaPagina,
                    continuando: novoCursor
                )
                novos.append(contentsOf: pagina.spots)
                ignorados += pagina.quantidadeRegistrosIgnorados
                novoCursor = pagina.proximoCursor
            } while novos.isEmpty && novoCursor != nil && !Task.isCancelled

            guard !Task.isCancelled else { return }
            eventos = novos
            cursor = novoCursor
            identificadoresCarregados = Set(novos.map(\.id))
            quantidadeRegistrosIgnorados = ignorados
            podeCarregarMais = novoCursor != nil
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
            let quantidadeAntes = eventos.count
            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: .evento,
                    limite: tamanhoDaPagina,
                    continuando: cursor
                )

                for evento in pagina.spots
                where identificadoresCarregados.insert(evento.id).inserted {
                    eventos.append(evento)
                }
                quantidadeRegistrosIgnorados += pagina.quantidadeRegistrosIgnorados
                cursor = pagina.proximoCursor
            } while eventos.count == quantidadeAntes
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
        redefinirPaginacao()
        identificadoresSalvos = []
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
        guard eventos.contains(where: { $0.id == spot.id }), podeSalvar(spot) else { return }
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
        aplicarAlteracoes()
        eventos.removeAll { !$0.estaDisponivel() }
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
        eventos = alteracoes.consolidar(eventos) {
            $0.estaDisponivel() && $0.tipo == .evento
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

    private func redefinirPaginacao() {
        eventos = []
        cursor = nil
        identificadoresCarregados = []
        quantidadeRegistrosIgnorados = 0
        mensagemDeErro = nil
        carregouPrimeiraPagina = false
        podeCarregarMais = true
    }
}
