//
//  DetalhesSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DetalhesSpotViewModel {
    private(set) var spot: Spot?
    private(set) var fotos: [FotoDisponivel] = []
    private(set) var estaSalvo = false
    private(set) var estaCarregando = false
    private(set) var estaAlterandoSalvo = false
    private(set) var mensagemDeErro: String?
    private(set) var estadoNotificacoes: EstadoPermissaoNotificacoes = .naoSolicitada

    let spotID: UUID

    private let sessao: SessaoUsuario
    private let spotCRUD: SpotCRUD
    private let fotoCRUD: FotoCRUD
    private let salvosCRUD: SalvosCRUD
    private let localizacao: ServicoLocalizacao
    private let notificacoes: Notificacoes

    var ehProprietario: Bool {
        guard let usuarioID = sessao.usuarioAtual?.id else { return false }
        return spot?.proprietarioID == usuarioID
    }

    init(
        spotID: UUID,
        sessao: SessaoUsuario,
        spotCRUD: SpotCRUD,
        fotoCRUD: FotoCRUD,
        salvosCRUD: SalvosCRUD,
        localizacao: ServicoLocalizacao,
        notificacoes: Notificacoes
    ) {
        self.spotID = spotID
        self.sessao = sessao
        self.spotCRUD = spotCRUD
        self.fotoCRUD = fotoCRUD
        self.salvosCRUD = salvosCRUD
        self.localizacao = localizacao
        self.notificacoes = notificacoes
    }

    convenience init(spotID: UUID, sessao: SessaoUsuario) {
        self.init(
            spotID: spotID,
            sessao: sessao,
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao),
            salvosCRUD: SalvosCRUD(sessao: sessao),
            localizacao: ServicoLocalizacao(),
            notificacoes: Notificacoes()
        )
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            let spot = try await spotCRUD.buscar(id: spotID)
            self.spot = spot
            fotos = try await fotoCRUD.buscarFotos(para: spot)

            if ehProprietario {
                estaSalvo = false
            } else {
                estaSalvo = try await salvosCRUD.estaSalvo(spotID: spot.id)
                if estaSalvo {
                    _ = try await salvosCRUD.marcarComoVisualizado(spotID: spot.id)
                }
            }
            estadoNotificacoes = await notificacoes.verificarPermissao()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func alternarSalvo() async {
        guard let spot, !ehProprietario, !estaAlterandoSalvo else { return }
        estaAlterandoSalvo = true
        mensagemDeErro = nil
        defer { estaAlterandoSalvo = false }

        do {
            if estaSalvo {
                try await salvosCRUD.dessalvar(spotID: spot.id)
                estaSalvo = false
            } else {
                _ = try await salvosCRUD.salvar(spotID: spot.id)
                estaSalvo = true
                await prepararNotificacoes()
            }
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func abrirNoMapas() {
        guard let spot else { return }
        mensagemDeErro = nil
        do {
            try localizacao.abrirNoMapas(
                localizacao: spot.localizacao,
                nome: spot.nome
            )
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    private func prepararNotificacoes() async {
        do {
            let autorizada: Bool
            switch await notificacoes.verificarPermissao() {
            case .naoSolicitada:
                autorizada = try await notificacoes.solicitarPermissao()
            case .autorizada, .provisoria:
                autorizada = true
            case .negada:
                autorizada = false
            }

            estadoNotificacoes = await notificacoes.verificarPermissao()
            if autorizada {
                notificacoes.registrarParaNotificacoesRemotas()
            }
        } catch {
            estadoNotificacoes = await notificacoes.verificarPermissao()
        }
    }
}
