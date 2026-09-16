//
//  AssinaturasCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

final class AssinaturasCloudKit {
    private static let limiteAssinaturasPorLote = 200
    private static let fila = FilaAssinaturasCloudKit()

    private let configuracao: ConfiguracaoCloudKit

    init(configuracao: ConfiguracaoCloudKit = ConfiguracaoCloudKit()) {
        self.configuracao = configuracao
    }

    func garantirAssinatura(para spotID: UUID) async throws {
        let configuracao = configuracao
        let assinatura = Self.criarAssinatura(para: spotID)

        try await enfileirar {
            _ = try await configuracao.banco(para: .spot).save(assinatura)
        }
    }

    func removerAssinatura(do spotID: UUID) async throws {
        let identificador = IdentificadorCloudKit.assinaturaSpot(spotID)
        let configuracao = configuracao

        try await enfileirar {
            do {
                _ = try await configuracao
                    .banco(para: .spot)
                    .deleteSubscription(withID: identificador)
            } catch {
                let erro = ErroCloudKit.converter(error)
                guard case .registroNaoEncontrado = erro else {
                    throw erro
                }
            }
        }
    }

    func reconciliarAssinaturas(com spotsSalvos: Set<UUID>) async throws {
        let configuracao = configuracao

        try await enfileirar {
            let banco = configuracao.banco(para: .spot)

            let assinaturasExistentes = try await banco.allSubscriptions()
            let assinaturasDesejadas = spotsSalvos
                .sorted { $0.uuidString < $1.uuidString }
                .map { spotID in
                    Self.criarAssinatura(para: spotID)
                }
            let identificadoresDesejados = Set(
                assinaturasDesejadas.map(\.subscriptionID)
            )
            let identificadoresExistentes = Set(
                assinaturasExistentes.map(\.subscriptionID)
            )
            let novasAssinaturas = assinaturasDesejadas.filter {
                !identificadoresExistentes.contains($0.subscriptionID)
            }

            var falhas: [String: ErroCloudKit] = [:]

            for lote in novasAssinaturas.emLotes(
                de: Self.limiteAssinaturasPorLote
            ) {
                falhas.merge(
                    try await Self.salvar(lote, no: banco),
                    uniquingKeysWith: { _, novaFalha in novaFalha }
                )
            }

            let identificadoresAtuaisConfirmados = identificadoresDesejados
                .intersection(identificadoresExistentes)
                .union(
                    novasAssinaturas
                        .map(\.subscriptionID)
                        .filter { falhas[$0] == nil }
                )
            let spotsComAssinaturaAtual = Set(
                identificadoresAtuaisConfirmados.compactMap { identificador in
                    IdentificadorCloudKit.spotDaAssinatura(identificador)
                }
            )
            let identificadoresParaExcluir = assinaturasExistentes
                .map(\.subscriptionID)
                .filter { identificador in
                    IdentificadorCloudKit.ehAssinaturaMakerSpot(identificador)
                }
                .filter { !identificadoresDesejados.contains($0) }
                .filter { identificador in
                    guard let spotID = IdentificadorCloudKit
                        .spotDeQualquerAssinaturaMakerSpot(identificador) else {
                        return true
                    }
                    return !spotsSalvos.contains(spotID)
                        || spotsComAssinaturaAtual.contains(spotID)
                }

            // As versões antigas só são removidas depois que as atuais foram confirmadas, evitando deixar um spot salvo sem notificações.
            for lote in identificadoresParaExcluir.emLotes(
                de: Self.limiteAssinaturasPorLote
            ) {
                falhas.merge(
                    try await Self.excluir(lote, do: banco),
                    uniquingKeysWith: { _, novaFalha in novaFalha }
                )
            }

            if !falhas.isEmpty {
                throw ErroCloudKit.falhaParcial(falhas)
            }
        }
    }

    private func enfileirar(
        _ operacao: @escaping @MainActor @Sendable () async throws -> Void
    ) async throws {
        try await Self.fila.executar {
            do {
                try await operacao()
            } catch {
                throw ErroCloudKit.converter(error)
            }
        }
    }

    private static func salvar(
        _ assinaturas: [CKSubscription],
        no banco: CKDatabase
    ) async throws -> [String: ErroCloudKit] {
        do {
            let resultados = try await banco.modifySubscriptions(
                saving: assinaturas,
                deleting: []
            )
            return falhas(
                resultados.saveResults,
                identificadores: assinaturas.map(\.subscriptionID)
            )
        } catch {
            let erro = ErroCloudKit.converter(error)
            guard case .limiteExcedido = erro, assinaturas.count > 1 else {
                throw erro
            }

            let metade = assinaturas.count / 2
            var falhas = try await salvar(
                Array(assinaturas[..<metade]),
                no: banco
            )
            falhas.merge(
                try await salvar(Array(assinaturas[metade...]), no: banco),
                uniquingKeysWith: { _, novaFalha in novaFalha }
            )
            return falhas
        }
    }

    private static func excluir(
        _ identificadores: [CKSubscription.ID],
        do banco: CKDatabase
    ) async throws -> [String: ErroCloudKit] {
        do {
            let resultados = try await banco.modifySubscriptions(
                saving: [],
                deleting: identificadores
            )
            return falhas(
                resultados.deleteResults,
                identificadores: identificadores,
                ignorarAusentes: true
            )
        } catch {
            let erro = ErroCloudKit.converter(error)
            guard case .limiteExcedido = erro, identificadores.count > 1 else {
                throw erro
            }

            let metade = identificadores.count / 2
            var falhas = try await excluir(
                Array(identificadores[..<metade]),
                do: banco
            )
            falhas.merge(
                try await excluir(Array(identificadores[metade...]), do: banco),
                uniquingKeysWith: { _, novaFalha in novaFalha }
            )
            return falhas
        }
    }

    private static func falhas<T>(
        _ resultados: [CKSubscription.ID: Result<T, Error>],
        identificadores: [CKSubscription.ID],
        ignorarAusentes: Bool = false
    ) -> [String: ErroCloudKit] {
        var falhas: [String: ErroCloudKit] = [:]
        for identificador in identificadores {
            do {
                guard let resultado = resultados[identificador] else {
                    throw ErroCloudKit.respostaInconsistente
                }
                _ = try resultado.get()
            } catch {
                let erro = ErroCloudKit.converter(error)
                if ignorarAusentes, case .registroNaoEncontrado = erro { continue }
                falhas[identificador] = erro
            }
        }
        return falhas
    }

    func interpretarNotificacao(
        _ dados: [AnyHashable: Any]
    ) -> UUID? {
        guard let notificacao = CKNotification(
            fromRemoteNotificationDictionary: dados
        ) as? CKQueryNotification,
              notificacao.databaseScope == .public,
              let identificador = notificacao.subscriptionID,
              let spotID = IdentificadorCloudKit
                .spotDeQualquerAssinaturaMakerSpot(identificador) else {
            return nil
        }

        return spotID
    }

    private static func criarAssinatura(para spotID: UUID) -> CKQuerySubscription {
        let assinatura = CKQuerySubscription(
            recordType: TipoRegistroCloudKit.spot.rawValue,
            predicate: NSPredicate(
                format: "%K == %@",
                CampoCloudKit.id,
                spotID.uuidString.lowercased()
            ),
            subscriptionID: IdentificadorCloudKit.assinaturaSpot(spotID),
            options: [.firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let informacoes = CKSubscription.NotificationInfo(
            alertBody: "Um Spot que você salvou foi atualizado ou removido.",
            title: "MakerSpot",
            soundName: "default",
            shouldBadge: true,
            shouldSendContentAvailable: true
        )
        assinatura.notificationInfo = informacoes
        return assinatura
    }
}

private actor FilaAssinaturasCloudKit {
    private var estaExecutando = false
    private var aguardando: [CheckedContinuation<Void, Never>] = []

    func executar(
        _ operacao: @MainActor @Sendable () async throws -> Void
    ) async throws {
        await aguardarVez()
        defer { liberarProximaOperacao() }

        try Task.checkCancellation()
        try await operacao()
    }

    private func aguardarVez() async {
        guard estaExecutando else {
            estaExecutando = true
            return
        }

        await withCheckedContinuation { continuacao in
            aguardando.append(continuacao)
        }
    }

    private func liberarProximaOperacao() {
        guard !aguardando.isEmpty else {
            estaExecutando = false
            return
        }

        aguardando.removeFirst().resume()
    }
}
