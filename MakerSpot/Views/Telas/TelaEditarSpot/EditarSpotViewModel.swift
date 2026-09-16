//
//  EditarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class EditarSpotViewModel {
    private(set) var spot: Spot
    private(set) var fotos: [FotoDisponivel] = []
    private(set) var estaCarregandoFotos = false
    private(set) var estaSalvando = false
    private(set) var estaAlterandoFotos = false
    private(set) var mensagemDeErro: String?

    private let spotCRUD: SpotCRUD
    private let fotoCRUD: FotoCRUD

    init(spot: Spot, spotCRUD: SpotCRUD, fotoCRUD: FotoCRUD) {
        self.spot = spot
        self.spotCRUD = spotCRUD
        self.fotoCRUD = fotoCRUD
    }

    convenience init(spot: Spot, sessao: SessaoUsuario) {
        self.init(
            spot: spot,
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao)
        )
    }

    func carregarFotos() async {
        guard !estaCarregandoFotos else { return }
        estaCarregandoFotos = true
        mensagemDeErro = nil
        defer { estaCarregandoFotos = false }

        do {
            fotos = try await fotoCRUD.buscarFotos(para: spot)
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func salvar(dados: DadosSpot) async -> Bool {
        guard !estaSalvando else { return false }
        estaSalvando = true
        mensagemDeErro = nil
        defer { estaSalvando = false }

        do {
            spot = try await spotCRUD.editar(id: spot.id, com: dados)
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func adicionarFoto(
        arquivoURL: URL,
        textoAlternativo: String? = nil
    ) async {
        guard !estaAlterandoFotos else { return }
        estaAlterandoFotos = true
        mensagemDeErro = nil
        defer { estaAlterandoFotos = false }

        do {
            let resultado = try await fotoCRUD.enviarParaSpot(
                arquivoURL: arquivoURL,
                spotID: spot.id,
                textoAlternativo: textoAlternativo
            )
            spot = resultado.spotAtualizado
            fotos = try await fotoCRUD.buscarFotos(para: spot)
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func removerFoto(id fotoID: UUID) async {
        guard !estaAlterandoFotos else { return }
        estaAlterandoFotos = true
        mensagemDeErro = nil
        defer { estaAlterandoFotos = false }

        do {
            spot = try await fotoCRUD.excluirDoSpot(
                fotoID: fotoID,
                spotID: spot.id
            )
            fotos.removeAll { $0.foto.id == fotoID }
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }
}
