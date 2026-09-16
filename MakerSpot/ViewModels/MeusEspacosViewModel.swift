//
//  MeusEspacosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class MeusEspacosViewModel {
    private(set) var espacos: [Spot] = []
    private(set) var estaCarregando = false
    private(set) var spotEmAlteracao: UUID?
    private(set) var mensagemDeErro: String?

    private let crud: SpotCRUD

    init(crud: SpotCRUD) {
        self.crud = crud
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(crud: SpotCRUD(sessao: sessao))
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
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

    private func substituir(_ spot: Spot) {
        guard let indice = espacos.firstIndex(where: { $0.id == spot.id }) else {
            return
        }
        espacos[indice] = spot
    }
}
