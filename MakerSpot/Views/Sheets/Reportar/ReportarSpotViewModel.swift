//
//  ReportarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ReportarSpotViewModel {
    var texto = ""

    private(set) var denunciaEnviada: Denuncia?
    private(set) var estaEnviando = false
    private(set) var mensagemDeErro: String?

    let limiteCaracteres = DenunciaCRUD.limiteCaracteres
    let spotID: UUID

    private let crud: DenunciaCRUD

    var quantidadeCaracteresRestantes: Int {
        max(0, limiteCaracteres - texto.count)
    }

    init(spotID: UUID, crud: DenunciaCRUD) {
        self.spotID = spotID
        self.crud = crud
    }

    convenience init(spotID: UUID, sessao: SessaoUsuario) {
        self.init(
            spotID: spotID,
            crud: DenunciaCRUD(sessao: sessao)
        )
    }

    @discardableResult
    func enviar() async -> Bool {
        guard !estaEnviando, denunciaEnviada == nil else { return false }
        estaEnviando = true
        mensagemDeErro = nil
        defer { estaEnviando = false }

        do {
            denunciaEnviada = try await crud.denunciar(
                spotID: spotID,
                texto: texto
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func reiniciar() {
        guard !estaEnviando else { return }
        texto = ""
        denunciaEnviada = nil
        mensagemDeErro = nil
    }
}
