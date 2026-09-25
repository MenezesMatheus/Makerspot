//
//  Notificacoes.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import CloudKit
import UIKit
import UserNotifications

enum EstadoPermissaoNotificacoes: Equatable, Sendable {
    case naoSolicitada
    case negada
    case autorizada
    case provisoria
}

final class Notificacoes {
    static let emailSuporte = "suporte@makerspot.app"
    static let categoriaModeracao = "MAKERSPOT_MODERACAO"
    static let acaoSolicitarRevisao = "MAKERSPOT_SOLICITAR_REVISAO"

    private static let limiteNotificacoesLocais = 64
    private static let prefixoLembrete = "makerspot.evento"
    private static let chaveTipo = "makerSpot.tipo"
    private static let chaveSpotID = "makerSpot.spotID"
    private static let chavePapel = "makerSpot.papel"

    private let central: UNUserNotificationCenter

    init(central: UNUserNotificationCenter = .current()) {
        self.central = central
    }

    func solicitarPermissao() async throws -> Bool {
        try await central.requestAuthorization(options: [.alert, .badge, .sound])
    }

    @discardableResult
    func prepararSistema(solicitarSeNecessario: Bool = true) async throws -> Bool {
        registrarCategorias()

        let autorizada: Bool
        switch await verificarPermissao() {
        case .naoSolicitada where solicitarSeNecessario:
            autorizada = try await solicitarPermissao()
        case .autorizada, .provisoria:
            autorizada = true
        case .naoSolicitada, .negada:
            autorizada = false
        }

        if autorizada {
            registrarParaNotificacoesRemotas()
        }
        return autorizada
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

    func registrarCategorias() {
        let solicitarRevisao = UNNotificationAction(
            identifier: Self.acaoSolicitarRevisao,
            title: "Solicitar revisão",
            options: [.foreground]
        )
        let categoria = UNNotificationCategory(
            identifier: Self.categoriaModeracao,
            actions: [solicitarRevisao],
            intentIdentifiers: []
        )
        central.setNotificationCategories([categoria])
    }

    func limparIndicadorDoAplicativo() async {
        try? await central.setBadgeCount(0)
    }

    func agendarLembretes(
        para spot: Spot,
        papel: PapelLembreteEvento
    ) async throws {
        guard spot.estaAtivo,
              case .evento(let evento) = spot.detalhes else {
            cancelarLembretes(spotID: spot.id, papel: papel)
            return
        }

        try await agendarLembretes(
            eventoID: spot.id,
            nome: spot.nome,
            inicio: evento.inicio,
            fusoHorarioID: evento.fusoHorarioID,
            papel: papel
        )
    }

    func sincronizarLembretes(
        eventos: [Spot],
        papel: PapelLembreteEvento
    ) async throws {
        let pendentes = await central.pendingNotificationRequests()
        let prefixo = Self.prefixoLembrete(papel: papel)
        let identificadoresAntigos = pendentes
            .map(\.identifier)
            .filter { $0.hasPrefix(prefixo) }
        central.removePendingNotificationRequests(
            withIdentifiers: identificadoresAntigos
        )

        let ocupadasPorOutrosFluxos = pendentes.filter {
            !identificadoresAntigos.contains($0.identifier)
        }.count
        var vagas = max(0, Self.limiteNotificacoesLocais - ocupadasPorOutrosFluxos)

        for spot in eventos.sorted(by: Self.ordenarPorInicio) where vagas > 0 {
            guard spot.estaAtivo,
                  case .evento(let evento) = spot.detalhes else { continue }
            let solicitacoes = solicitacoesDeLembrete(
                eventoID: spot.id,
                nome: spot.nome,
                inicio: evento.inicio,
                fusoHorarioID: evento.fusoHorarioID,
                papel: papel
            )
            for solicitacao in solicitacoes.prefix(vagas) {
                try await central.add(solicitacao)
                vagas -= 1
            }
        }
    }

    func cancelarLembretes(
        spotID: UUID,
        papel: PapelLembreteEvento
    ) {
        central.removePendingNotificationRequests(
            withIdentifiers: Self.identificadoresLembrete(
                spotID: spotID,
                papel: papel
            )
        )
    }

    func processarAlteracaoRemota(
        _ dados: [AnyHashable: Any]
    ) async throws -> Bool {
        if let alerta = interpretarAlertaModeracao(dados) {
            if alerta.tipoConteudo == .evento,
               let eventoID = alerta.conteudoID {
                cancelarLembretes(spotID: eventoID, papel: .organizador)
                cancelarLembretes(spotID: eventoID, papel: .salvo)
            }
            return true
        }

        guard let notificacao = CKNotification(
            fromRemoteNotificationDictionary: dados
        ) as? CKQueryNotification,
        let identificador = notificacao.subscriptionID,
        let spotID = IdentificadorCloudKit
            .spotDeQualquerAssinaturaMakerSpot(identificador) else {
            return false
        }

        if notificacao.queryNotificationReason == .recordDeleted {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }

        guard notificacao.queryNotificationReason == .recordUpdated,
              let campos = notificacao.recordFields else {
            return true
        }

        let tipo = Self.texto(campos[CampoCloudKit.Spot.tipo])
        let estaAtivo = Self.booleano(campos[CampoCloudKit.Spot.estaAtivo]) ?? true
        guard tipo == TipoSpot.evento.rawValue,
              estaAtivo,
              let inicio = campos[CampoCloudKit.Spot.inicioEvento] as? Date else {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }

        try await agendarLembretes(
            eventoID: spotID,
            nome: Self.texto(campos[CampoCloudKit.Spot.nome]) ?? "Evento",
            inicio: inicio,
            fusoHorarioID: Self.texto(
                campos[CampoCloudKit.Spot.fusoHorarioID]
            ) ?? TimeZone.current.identifier,
            papel: .salvo
        )
        return true
    }

    func interpretarAlertaModeracao(
        _ dados: [AnyHashable: Any]
    ) -> AlertaModeracao? {
        var campos: [String: Any] = [:]
        var id = UUID()

        if let notificacao = CKNotification(
            fromRemoteNotificationDictionary: dados
        ) as? CKQueryNotification,
        let identificador = notificacao.subscriptionID,
        IdentificadorCloudKit.usuarioDaAssinaturaModeracao(identificador) != nil {
            campos = notificacao.recordFields ?? [:]
            if let textoID = Self.texto(campos[CampoCloudKit.id]),
               let idConvertido = UUID(uuidString: textoID) {
                id = idConvertido
            }
        } else if Self.texto(dados[Self.chaveTipo]) == "moderacao" {
            campos = dados.reduce(into: [:]) { resultado, elemento in
                guard let chave = elemento.key as? String else { return }
                resultado[chave] = elemento.value
            }
            if let textoID = Self.texto(campos[CampoCloudKit.id]),
               let idConvertido = UUID(uuidString: textoID) {
                id = idConvertido
            }
        } else {
            return nil
        }

        guard let tipoTexto = Self.texto(
            campos[CampoCloudKit.NotificacaoModeracao.tipoConteudo]
        ),
        let tipo = TipoConteudoModerado(rawValue: tipoTexto),
        let motivo = Self.texto(
            campos[CampoCloudKit.NotificacaoModeracao.motivo]
        ),
        !motivo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return AlertaModeracao(
            id: id,
            tipoConteudo: tipo,
            conteudoID: Self.texto(
                campos[CampoCloudKit.NotificacaoModeracao.conteudoID]
            ).flatMap(UUID.init(uuidString:)),
            nomeConteudo: Self.texto(
                campos[CampoCloudKit.NotificacaoModeracao.nomeConteudo]
            ),
            motivo: motivo
        )
    }

    private func agendarLembretes(
        eventoID: UUID,
        nome: String,
        inicio: Date,
        fusoHorarioID: String,
        papel: PapelLembreteEvento
    ) async throws {
        cancelarLembretes(spotID: eventoID, papel: papel)
        for solicitacao in solicitacoesDeLembrete(
            eventoID: eventoID,
            nome: nome,
            inicio: inicio,
            fusoHorarioID: fusoHorarioID,
            papel: papel
        ) {
            try await central.add(solicitacao)
        }
    }

    private func solicitacoesDeLembrete(
        eventoID: UUID,
        nome: String,
        inicio: Date,
        fusoHorarioID: String,
        papel: PapelLembreteEvento
    ) -> [UNNotificationRequest] {
        let agora = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: fusoHorarioID) ?? .current
        let horario = formatter.string(from: inicio)

        return [24, 5].compactMap { horasAntes in
            let disparo = inicio.addingTimeInterval(-Double(horasAntes) * 3_600)
            let intervalo = disparo.timeIntervalSince(agora)
            guard intervalo > 1 else { return nil }

            let conteudo = UNMutableNotificationContent()
            conteudo.title = horasAntes == 24
                ? "Evento amanhã"
                : "Evento em 5 horas"
            conteudo.body = "“\(nome)”, \(papel.descricao), começa em \(horasAntes) horas (\(horario))."
            conteudo.sound = .default
            conteudo.threadIdentifier = "makerspot.evento.\(eventoID.uuidString.lowercased())"
            conteudo.userInfo = [
                Self.chaveTipo: "lembreteEvento",
                Self.chaveSpotID: eventoID.uuidString.lowercased(),
                Self.chavePapel: papel.rawValue
            ]

            return UNNotificationRequest(
                identifier: Self.identificadorLembrete(
                    spotID: eventoID,
                    papel: papel,
                    horasAntes: horasAntes
                ),
                content: conteudo,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: intervalo,
                    repeats: false
                )
            )
        }
    }

    private static func identificadoresLembrete(
        spotID: UUID,
        papel: PapelLembreteEvento
    ) -> [String] {
        [24, 5].map {
            identificadorLembrete(
                spotID: spotID,
                papel: papel,
                horasAntes: $0
            )
        }
    }

    private static func identificadorLembrete(
        spotID: UUID,
        papel: PapelLembreteEvento,
        horasAntes: Int
    ) -> String {
        "\(prefixoLembrete(papel: papel))\(spotID.uuidString.lowercased()).\(horasAntes)h"
    }

    private static func prefixoLembrete(papel: PapelLembreteEvento) -> String {
        "\(prefixoLembrete).\(papel.rawValue)."
    }

    private static func ordenarPorInicio(_ primeiro: Spot, _ segundo: Spot) -> Bool {
        guard case .evento(let eventoA) = primeiro.detalhes else { return false }
        guard case .evento(let eventoB) = segundo.detalhes else { return true }
        return eventoA.inicio < eventoB.inicio
    }

    private static func texto(_ valor: Any?) -> String? {
        if let texto = valor as? String { return texto }
        if let texto = valor as? NSString { return texto as String }
        return nil
    }

    private static func booleano(_ valor: Any?) -> Bool? {
        if let valor = valor as? Bool { return valor }
        if let numero = valor as? NSNumber { return numero.boolValue }
        return nil
    }
}
