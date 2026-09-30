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

@MainActor
final class EstadoSpotsSalvosNotificacoes {
    static let compartilhado = EstadoSpotsSalvosNotificacoes()

    private var usuarioID: UUID?
    private var identificadores: Set<UUID> = []
    private var revisoes: [UUID: Int] = [:]
    private var sequenciaMutacoes = 0
    private var ultimaMutacao: [UUID: Int] = [:]

    private init() {}

    func ativar(usuarioID: UUID) {
        guard self.usuarioID != usuarioID else { return }
        self.usuarioID = usuarioID
        identificadores = []
        revisoes = [:]
        sequenciaMutacoes = 0
        ultimaMutacao = [:]
    }

    func limpar() {
        usuarioID = nil
        identificadores = []
        revisoes = [:]
        sequenciaMutacoes = 0
        ultimaMutacao = [:]
    }

    var sequenciaAtual: Int { sequenciaMutacoes }

    func substituir(
        _ novos: Set<UUID>,
        usuarioID: UUID,
        consultaIniciadaNa sequencia: Int
    ) {
        guard self.usuarioID == usuarioID else { return }
        var reconciliados = novos
        for (id, ultima) in ultimaMutacao where ultima > sequencia {
            if identificadores.contains(id) { reconciliados.insert(id) }
            else { reconciliados.remove(id) }
        }
        for id in identificadores.symmetricDifference(reconciliados) {
            revisoes[id, default: 0] += 1
        }
        identificadores = reconciliados
    }

    @discardableResult
    func definir(_ salvo: Bool, spotID: UUID, usuarioID: UUID) -> Int? {
        guard self.usuarioID == usuarioID else { return nil }
        if salvo { identificadores.insert(spotID) }
        else { identificadores.remove(spotID) }
        revisoes[spotID, default: 0] += 1
        sequenciaMutacoes += 1
        ultimaMutacao[spotID] = sequenciaMutacoes
        return revisoes[spotID]
    }

    func contem(_ spotID: UUID) -> Bool {
        identificadores.contains(spotID)
    }

    func identificadoresAtuais() -> Set<UUID> { identificadores }

    func revisaoSeSalvo(_ spotID: UUID) -> Int? {
        guard identificadores.contains(spotID) else { return nil }
        return revisoes[spotID, default: 0]
    }

    func permaneceSalvo(_ spotID: UUID, revisao: Int) -> Bool {
        identificadores.contains(spotID) && revisoes[spotID] == revisao
    }
}

final class Notificacoes {
    static let emailSuporte = "supportemakerspot@gmail.com"
    static let categoriaModeracao = "MAKERSPOT_MODERACAO"
    static let acaoSolicitarRevisao = "MAKERSPOT_SOLICITAR_REVISAO"

    private static let limiteNotificacoesLocais = 64
    private static let prefixoLembrete = "makerspot.evento"
    private static let chaveTipo = "makerSpot.tipo"
    private static let chaveSpotID = "makerSpot.spotID"
    private static let chavePapel = "makerSpot.papel"

    private let central: UNUserNotificationCenter
    private let cliente: ClienteCloudKit

    init(
        central: UNUserNotificationCenter = .current(),
        cliente: ClienteCloudKit = ClienteCloudKit()
    ) {
        self.central = central
        self.cliente = cliente
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
        if let notificacao = CKNotification(
            fromRemoteNotificationDictionary: dados
        ) as? CKQueryNotification,
        let identificador = notificacao.subscriptionID,
        IdentificadorCloudKit.usuarioDaAssinaturaSpotRestrito(
            identificador
        ) != nil {
            if let textoID = Self.texto(
                notificacao.recordFields?[CampoCloudKit.SpotRestrito.spotID]
            ), let spotID = UUID(uuidString: textoID) {
                cancelarLembretes(spotID: spotID, papel: .organizador)
                cancelarLembretes(spotID: spotID, papel: .salvo)
            }
            return true
        }

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

        guard let revisao = EstadoSpotsSalvosNotificacoes.compartilhado
            .revisaoSeSalvo(spotID) else {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }

        if notificacao.queryNotificationReason == .recordDeleted {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }

        guard notificacao.queryNotificationReason == .recordUpdated else {
            return true
        }

        let registro: CKRecord
        do {
            registro = try await cliente.buscar(
                IdentificadorCloudKit.spot(spotID),
                tipo: .spot
            )
        } catch ErroCloudKit.registroNaoEncontrado {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }
        guard let spot = try? ApoioCRUD.spotValido(de: registro) else {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }
        guard EstadoSpotsSalvosNotificacoes.compartilhado.permaneceSalvo(
            spotID,
            revisao: revisao
        ) else {
            cancelarLembretes(spotID: spotID, papel: .salvo)
            return true
        }
        try await agendarLembretes(para: spot, papel: .salvo)
        if !EstadoSpotsSalvosNotificacoes.compartilhado.permaneceSalvo(
            spotID,
            revisao: revisao
        ) {
            cancelarLembretes(spotID: spotID, papel: .salvo)
        }
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

}
