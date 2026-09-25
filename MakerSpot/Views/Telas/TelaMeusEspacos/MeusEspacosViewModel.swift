//
//  MeusEspacosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

enum FiltroMeusEspacos: String, CaseIterable, Identifiable {
    case disponiveis = "Disponíveis"
    case indisponiveis = "Indisponíveis"

    var id: Self { self }
}

@MainActor
@Observable
final class MeusEspacosViewModel {
    private(set) var cadastro: CadastrarSpotViewModel?
    let fotosSpots: FotosSpotsViewModel
    private(set) var espacos: [Spot] = []
    private(set) var estaCarregando = false
    private(set) var spotEmAlteracao: UUID?
    private(set) var mensagemDeErro: String?
    var filtroSelecionado: FiltroMeusEspacos = .disponiveis

    private let crud: SpotCRUD
    @ObservationIgnored private var criarCadastro: (() -> CadastrarSpotViewModel)?

    var espacosFiltrados: [Spot] {
        espacos.filter { spot in
            switch filtroSelecionado {
            case .disponiveis:
                return spot.estaAtivo
            case .indisponiveis:
                return !spot.estaAtivo
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
            cadastro.tipoSelecionado = .espaco
            return cadastro
        }
    }

    func iniciarCadastro() {
        guard cadastro == nil else { return }
        cadastro = criarCadastro?()
    }

    func encerrarCadastro() {
        defer { cadastro = nil }
        guard let criado = cadastro?.spotCriado, criado.tipo == .espaco else {
            return
        }

        if let indice = espacos.firstIndex(where: { $0.id == criado.id }) {
            espacos[indice] = criado
        } else {
            espacos.insert(criado, at: 0)
        }
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        fotosSpots.limpar()
        defer { estaCarregando = false }

        do {
            espacos = try await crud.listarDoUsuarioAtual(tipo: .espaco)
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func definirAtivo(_ estaAtivo: Bool, para id: UUID) async {
        guard spotEmAlteracao == nil else { return }
        spotEmAlteracao = id
        mensagemDeErro = nil
        defer { spotEmAlteracao = nil }

        do {
            let atualizado = try await crud.definirAtivo(estaAtivo, para: id)
            substituir(atualizado)
        } catch is CancellationError {
            return
        } catch {
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
            espacos.removeAll { $0.id == id }
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
        guard spot.tipo == .espaco else { return }
        substituir(spot)
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    private func substituir(_ spot: Spot) {
        guard let indice = espacos.firstIndex(where: { $0.id == spot.id }) else {
            return
        }
        espacos[indice] = spot
    }
}
