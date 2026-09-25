//
//  CoordenadorNotificacoes.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import Foundation

@MainActor
final class CoordenadorNotificacoes {
    private let notificacoes: Notificacoes
    private let assinaturasModeracao: AssinaturasModeracaoCloudKit

    init(
        notificacoes: Notificacoes? = nil,
        assinaturasModeracao: AssinaturasModeracaoCloudKit? = nil
    ) {
        self.notificacoes = notificacoes ?? Notificacoes()
        self.assinaturasModeracao = assinaturasModeracao
            ?? AssinaturasModeracaoCloudKit()
    }

    func configurar(sessao: SessaoUsuario) async {
        guard let usuario = sessao.usuarioAtual else { return }

        do {
            let autorizada = try await notificacoes.prepararSistema()
            guard autorizada else { return }

            try? await assinaturasModeracao.garantirAssinatura(
                para: usuario.id
            )

            if let salvos = try? await SalvosCRUD(sessao: sessao)
                .listarComSpots() {
                try? await notificacoes.sincronizarLembretes(
                    eventos: salvos.map(\.spot),
                    papel: .salvo
                )
            }

            if let eventosDoUsuario = try? await SpotCRUD(sessao: sessao)
                .listarDoUsuarioAtual(tipo: .evento) {
                try? await notificacoes.sincronizarLembretes(
                    eventos: eventosDoUsuario,
                    papel: .organizador
                )
            }
        } catch is CancellationError {
            return
        } catch {}
    }
}
