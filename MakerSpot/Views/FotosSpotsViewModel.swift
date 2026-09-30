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
    @ObservationIgnored private var sessao: SessaoUsuario?
    @ObservationIgnored private var fotoIDsConhecidos: [UUID: [UUID]] = [:]
    @ObservationIgnored private var spotsSemFoto: Set<UUID> = []
    @ObservationIgnored private var requisicoes: [UUID: UUID] = [:]

    init(fotoCRUD: FotoCRUD, sessao: SessaoUsuario? = nil) {
        self.fotoCRUD = fotoCRUD
        self.sessao = sessao
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(fotoCRUD: FotoCRUD(sessao: sessao), sessao: sessao)
    }

    func fotoPrincipal(do spot: Spot) -> FotoDisponivel? {
        guard fotoIDsConhecidos[spot.id] == spot.fotoIDs else {
            return sessao?.capaEmCache(para: spot)
        }
        return fotosPrincipais[spot.id] ?? sessao?.capaEmCache(para: spot)
    }

    func estaCarregando(_ spot: Spot) -> Bool {
        spotsEmCarregamento.contains(spot.id)
    }

    func carregarFotoPrincipal(do spot: Spot) async {
        if fotoIDsConhecidos[spot.id] != spot.fotoIDs {
            requisicoes[spot.id] = nil
            spotsEmCarregamento.remove(spot.id)
            fotosPrincipais[spot.id] = nil
            spotsSemFoto.remove(spot.id)
            fotoIDsConhecidos[spot.id] = spot.fotoIDs
        }

        if let guardada = sessao?.capaEmCache(para: spot) {
            fotosPrincipais[spot.id] = guardada
            return
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

        let requisicao = UUID()
        requisicoes[spot.id] = requisicao
        defer {
            if requisicoes[spot.id] == requisicao {
                requisicoes[spot.id] = nil
                spotsEmCarregamento.remove(spot.id)
            }
        }

        do {
            let foto = try await fotoCRUD.buscarFotoPrincipal(para: spot)
            guard requisicoes[spot.id] == requisicao else { return }
            if let foto {
                fotosPrincipais[spot.id] = foto
                sessao?.guardarCapaEmCache(foto, para: spot)
            } else {
                spotsSemFoto.insert(spot.id)
            }
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            guard requisicoes[spot.id] == requisicao else { return }
            mensagemDeErro = error.localizedDescription
        }
    }

    func removerSpot(_ spotID: UUID) {
        requisicoes[spotID] = nil
        fotosPrincipais[spotID] = nil
        fotoIDsConhecidos[spotID] = nil
        spotsSemFoto.remove(spotID)
        spotsEmCarregamento.remove(spotID)
    }

    func limpar() {
        requisicoes = [:]
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
