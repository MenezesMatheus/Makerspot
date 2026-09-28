//
//  AppDelegateNotificacoes.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import CloudKit
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class RoteadorNotificacoes {
    static let compartilhado = RoteadorNotificacoes()

    var alertaModeracao: AlertaModeracao?
    var atualizacaoRestricaoSpot = UUID()
    var avisosRestricaoSpotPendentes: [SpotRestrito] = []

    private init() {}

    func processarInteracao(_ dados: [AnyHashable: Any]) {
        if processarRestricaoSpot(dados) { return }
        alertaModeracao = Notificacoes().interpretarAlertaModeracao(dados)
    }

    @discardableResult
    func processarRestricaoSpot(_ dados: [AnyHashable: Any]) -> Bool {
        guard let notificacao = CKNotification(
            fromRemoteNotificationDictionary: dados
        ) as? CKQueryNotification,
        let identificador = notificacao.subscriptionID,
        let usuarioID = IdentificadorCloudKit.usuarioDaAssinaturaSpotRestrito(
            identificador
        ) else {
            return false
        }

        if let nomeSpot = notificacao.recordFields?[CampoCloudKit.SpotRestrito.nomeSpot] as? String,
           !nomeSpot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let spotIDTexto = notificacao.recordFields?[CampoCloudKit.SpotRestrito.spotID] as? String,
           let spotID = UUID(uuidString: spotIDTexto),
           let id = notificacao.recordID?.recordName,
           !avisosRestricaoSpotPendentes.contains(where: { $0.id == id }) {
            avisosRestricaoSpotPendentes.append(
                SpotRestrito(
                    id: id,
                    spotID: spotID,
                    proprietarioID: usuarioID,
                    nomeSpot: nomeSpot,
                    status: .restrito,
                    criadoEm: Date()
                )
            )
        }
        atualizacaoRestricaoSpot = UUID()
        return true
    }

    func abrirEmailDeRevisao() {
        var componentes = URLComponents()
        componentes.scheme = "mailto"
        componentes.path = Notificacoes.emailSuporte
        componentes.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "Solicitação de revisão de moderação — MakerSpot"
            )
        ]
        guard let url = componentes.url else { return }
        UIApplication.shared.open(url)
    }
}

final class AppDelegateNotificacoes: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]? = nil
    ) -> Bool {
        let notificacoes = Notificacoes()
        notificacoes.registrarCategorias()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        _ = await MainActor.run {
            RoteadorNotificacoes.compartilhado.processarRestricaoSpot(
                notification.request.content.userInfo
            )
        }
        return [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let dados = response.notification.request.content.userInfo
        await MainActor.run {
            RoteadorNotificacoes.compartilhado.processarInteracao(dados)
            if response.actionIdentifier == Notificacoes.acaoSolicitarRevisao {
                RoteadorNotificacoes.compartilhado.abrirEmailDeRevisao()
            }
        }
        await Notificacoes().limparIndicadorDoAplicativo()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (
            UIBackgroundFetchResult
        ) -> Void
    ) {
        Task {
            do {
                let alterou = try await Notificacoes()
                    .processarAlteracaoRemota(userInfo)
                _ = await MainActor.run {
                    RoteadorNotificacoes.compartilhado.processarRestricaoSpot(userInfo)
                }
                completionHandler(alterou ? .newData : .noData)
            } catch {
                completionHandler(.failed)
            }
        }
    }
}
