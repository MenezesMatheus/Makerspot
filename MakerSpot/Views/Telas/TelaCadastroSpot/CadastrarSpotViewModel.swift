//
//  CadastrarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CadastrarSpotViewModel {
    private(set) var spotCriado: Spot?
    private(set) var quantidadeFotosProcessadas = 0
    private(set) var estaCadastrando = false
    private(set) var mensagemDeErro: String?

    let telefoneSugerido: String?
    let limiteFotos = FotoCRUD.limiteFotosPorSpot

    private let spotCRUD: SpotCRUD
    private let fotoCRUD: FotoCRUD

    init(
        spotCRUD: SpotCRUD,
        fotoCRUD: FotoCRUD,
        telefoneSugerido: String? = nil
    ) {
        self.spotCRUD = spotCRUD
        self.fotoCRUD = fotoCRUD
        self.telefoneSugerido = telefoneSugerido
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao),
            telefoneSugerido: sessao.usuarioAtual?.telefonePadrao
        )
    }

    @discardableResult
    func cadastrar(
        dados: DadosSpot,
        fotos: [URL] = []
    ) async -> Spot? {
        guard !estaCadastrando else { return nil }
        estaCadastrando = true
        mensagemDeErro = nil
        spotCriado = nil
        quantidadeFotosProcessadas = 0
        defer { estaCadastrando = false }

        guard fotos.count <= limiteFotos else {
            mensagemDeErro = "Selecione no máximo \(limiteFotos) fotos."
            return nil
        }

        do {
            var spot = try await spotCRUD.criar(dados)
            spotCriado = spot

            for arquivoURL in fotos {
                let resultado = try await fotoCRUD.enviarParaSpot(
                    arquivoURL: arquivoURL,
                    spotID: spot.id
                )
                spot = resultado.spotAtualizado
                spotCriado = spot
                quantidadeFotosProcessadas += 1
            }
            return spot
        } catch is CancellationError {
            return nil
        } catch {
            mensagemDeErro = error.localizedDescription
            return nil
        }
    }

    func reiniciar() {
        guard !estaCadastrando else { return }
        spotCriado = nil
        quantidadeFotosProcessadas = 0
        mensagemDeErro = nil
    }
}
