//
//  FotosSpotsViewModel.swift
//  MakerSpot
//

import Foundation
import Observation

@MainActor
@Observable
final class FotosSpotsViewModel {
    private(set) var fotosPrincipais: [UUID: FotoDisponivel] = [:]
    private(set) var spotsEmCarregamento: Set<UUID> = []
    private(set) var mensagemDeErro: String?

    private let fotoCRUD: FotoCRUD
    @ObservationIgnored private var fotoIDsConhecidos: [UUID: [UUID]] = [:]
    @ObservationIgnored private var spotsSemFoto: Set<UUID> = []

    init(fotoCRUD: FotoCRUD) {
        self.fotoCRUD = fotoCRUD
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(fotoCRUD: FotoCRUD(sessao: sessao))
    }

    func fotoPrincipal(do spot: Spot) -> FotoDisponivel? {
        guard fotoIDsConhecidos[spot.id] == spot.fotoIDs else { return nil }
        return fotosPrincipais[spot.id]
    }

    func estaCarregando(_ spot: Spot) -> Bool {
        spotsEmCarregamento.contains(spot.id)
    }

    func carregarFotoPrincipal(do spot: Spot) async {
        if fotoIDsConhecidos[spot.id] != spot.fotoIDs {
            fotosPrincipais[spot.id] = nil
            spotsSemFoto.remove(spot.id)
            fotoIDsConhecidos[spot.id] = spot.fotoIDs
        }

        guard !spot.fotoIDs.isEmpty else {
            spotsSemFoto.insert(spot.id)
            return
        }
        guard fotosPrincipais[spot.id] == nil,
              !spotsSemFoto.contains(spot.id),
              spotsEmCarregamento.insert(spot.id).inserted else {
            return
        }

        defer { spotsEmCarregamento.remove(spot.id) }

        do {
            if let foto = try await fotoCRUD.buscarFotos(para: spot).first {
                fotosPrincipais[spot.id] = foto
            } else {
                spotsSemFoto.insert(spot.id)
            }
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func removerSpot(_ spotID: UUID) {
        fotosPrincipais[spotID] = nil
        fotoIDsConhecidos[spotID] = nil
        spotsSemFoto.remove(spotID)
        spotsEmCarregamento.remove(spotID)
    }

    func limpar() {
        fotosPrincipais = [:]
        spotsEmCarregamento = []
        mensagemDeErro = nil
        fotoIDsConhecidos = [:]
        spotsSemFoto = []
    }

    func limparErro() {
        mensagemDeErro = nil
    }
}
