//
//  Notificacoes.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import UIKit
import UserNotifications

enum EstadoPermissaoNotificacoes: Equatable, Sendable {
    case naoSolicitada
    case negada
    case autorizada
    case provisoria
}

final class Notificacoes {
    private let central: UNUserNotificationCenter

    init(central: UNUserNotificationCenter = .current()) {
        self.central = central
    }

    func solicitarPermissao() async throws -> Bool {
        try await central.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func verificarPermissao() async -> EstadoPermissaoNotificacoes {
        let configuracoes = await central.notificationSettings()
        switch configuracoes.authorizationStatus {
        case .notDetermined:
            return .naoSolicitada
        case .denied:
            return .negada
        case .authorized:
            return .autorizada
        case .provisional, .ephemeral:
            return .provisoria
        @unknown default:
            return .negada
        }
    }

    func registrarParaNotificacoesRemotas() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func limparIndicadorDoAplicativo() async {
        try? await central.setBadgeCount(0)
    }
}
