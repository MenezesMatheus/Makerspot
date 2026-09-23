//
//  AppDelegateNotificacoes.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class RoteadorNotificacoes {
    static let compartilhado = RoteadorNotificacoes()

    var alertaModeracao: AlertaModeracao?

    private init() {}

    func processarInteracao(_ dados: [AnyHashable: Any]) {
        alertaModeracao = Notificacoes().interpretarAlertaModeracao(dados)
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
        [.banner, .list, .sound, .badge]
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
                completionHandler(alterou ? .newData : .noData)
            } catch {
                completionHandler(.failed)
            }
        }
    }
}
