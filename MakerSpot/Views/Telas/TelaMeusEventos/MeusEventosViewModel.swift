//
//  MeusEventosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Combine
import Observation

enum FiltroMeusEventos: String, CaseIterable, Identifiable {
    case disponiveis = "Disponíveis"
    case indisponiveis = "Indisponíveis"

    var id: Self { self }
}

@MainActor
@Observable
final class MeusEventosViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    @ObservationIgnored private var usuarioID: UUID?
    private(set) var cadastro: CadastrarSpotViewModel?
    let fotosSpots: FotosSpotsViewModel
    private(set) var eventos: [Spot] = []
    private(set) var estaCarregando = false
    private(set) var carregouDados = false
    private(set) var spotEmAlteracao: UUID?
    private(set) var mensagemDeErro: String?
    var filtroSelecionado: FiltroMeusEventos = .disponiveis

    private let crud: SpotCRUD
    @ObservationIgnored private var criarCadastro: (() -> CadastrarSpotViewModel)?

    var eventosFiltrados: [Spot] {
        eventos.filter { evento in
            switch filtroSelecionado {
            case .disponiveis:
                return evento.estaAtivo
            case .indisponiveis:
                return !evento.estaAtivo
            }
        }
    }

    init(crud: SpotCRUD, fotosSpots: FotosSpotsViewModel) {
        self.crud = crud
        self.fotosSpots = fotosSpots
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            crud: SpotCRUD(sessao: sessao),
            fotosSpots: FotosSpotsViewModel(sessao: sessao)
        )
        criarCadastro = {
            let cadastro = CadastrarSpotViewModel(sessao: sessao)
            cadastro.tipoSelecionado = .evento
            return cadastro
        }
        usuarioID = sessao.usuarioAtual?.id
        alteracoes = sessao.alteracoesSpots
        observacaoAlteracoes = sessao.alteracoesSpots.atualizacoes.sink { [weak self] in
            self?.aplicarAlteracoes()
        }
        aplicarAlteracoes()
    }

    func iniciarCadastro() {
        guard cadastro == nil else { return }
        cadastro = criarCadastro?()
    }

    func encerrarCadastro() {
        defer { cadastro = nil }
        guard let criado = cadastro?.spotCriado, criado.tipo == .evento else {
            return
        }

        let atualizado = alteracoes?.spots[criado.id] ?? criado
        if let indice = eventos.firstIndex(where: { $0.id == criado.id }) {
            eventos[indice] = atualizado
        } else {
            eventos.insert(atualizado, at: 0)
        }
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer {
            estaCarregando = false
            aplicarAlteracoes()
        }

        do {
            eventos = try await crud.listarDoUsuarioAtual(tipo: .evento)
            carregouDados = true
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func definirAtivo(_ estaAtivo: Bool, para id: UUID) async {
        guard spotEmAlteracao == nil,
              let anterior = eventos.first(where: { $0.id == id }),
              anterior.estaAtivo != estaAtivo else { return }
        spotEmAlteracao = id
        mensagemDeErro = nil
        defer { spotEmAlteracao = nil }

        var otimista = anterior
        otimista.estaAtivo = estaAtivo
        substituir(otimista)

        do {
            let atualizado = try await crud.definirAtivo(estaAtivo, para: id)
            substituir(atualizado)
        } catch is CancellationError {
            substituir(anterior)
            return
        } catch {
            substituir(anterior)
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func excluir(id: UUID) async -> Bool {
        guard spotEmAlteracao == nil else { return false }
        spotEmAlteracao = id
        mensagemDeErro = nil
        defer { spotEmAlteracao = nil }

        do {
            try await crud.excluir(id: id)
            eventos.removeAll { $0.id == id }
            fotosSpots.removerSpot(id)
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func atualizar(_ spot: Spot) {
        guard spot.tipo == .evento else { return }
        substituir(spot)
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    private func aplicarAlteracoes() {
        guard let alteracoes, let usuarioID else { return }
        let pendente = eventos.first { $0.id == spotEmAlteracao }
        eventos = alteracoes.consolidar(eventos) {
            $0.tipo == .evento && $0.proprietarioID == usuarioID
        }
        if let pendente, !alteracoes.excluidos.contains(pendente.id) {
            substituir(pendente)
        }
    }

    private func substituir(_ spot: Spot) {
        guard let indice = eventos.firstIndex(where: { $0.id == spot.id }) else {
            return
        }
        eventos[indice] = spot
    }
}
