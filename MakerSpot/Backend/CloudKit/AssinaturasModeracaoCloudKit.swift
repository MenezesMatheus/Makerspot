//
//  AssinaturasModeracaoCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import CloudKit
import Foundation

final class AssinaturasModeracaoCloudKit {
    private let configuracao: ConfiguracaoCloudKit

    init(configuracao: ConfiguracaoCloudKit = ConfiguracaoCloudKit()) {
        self.configuracao = configuracao
    }

    func garantirAssinatura(para usuarioID: UUID) async throws {
        let assinatura = CKQuerySubscription(
            recordType: TipoRegistroCloudKit.notificacaoModeracao.rawValue,
            predicate: NSPredicate(
                format: "%K == %@",
                CampoCloudKit.NotificacaoModeracao.destinatarioID,
                usuarioID.uuidString.lowercased()
            ),
            subscriptionID: IdentificadorCloudKit.assinaturaModeracao(usuarioID),
            options: [.firesOnRecordCreation]
        )
        
        let informacoes = CKSubscription.NotificationInfo()
        informacoes.title = "MakerSpot"
        informacoes.alertBody = "Um conteúdo seu foi removido pela moderação. Toque para ver o motivo."
        informacoes.soundName = "default"
        informacoes.shouldBadge = true
        informacoes.shouldSendContentAvailable = true
        informacoes.category = Notificacoes.categoriaModeracao
        informacoes.desiredKeys = [
            CampoCloudKit.id,
            CampoCloudKit.NotificacaoModeracao.destinatarioID,
            CampoCloudKit.NotificacaoModeracao.tipoConteudo,
            CampoCloudKit.NotificacaoModeracao.conteudoID,
            CampoCloudKit.NotificacaoModeracao.nomeConteudo,
            CampoCloudKit.NotificacaoModeracao.motivo
        ]
        assinatura.notificationInfo = informacoes

        do {
            _ = try await configuracao
                .banco(para: .notificacaoModeracao)
                .save(assinatura)
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }
}
