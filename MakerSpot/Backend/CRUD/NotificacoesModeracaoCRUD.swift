//
//  NotificacoesModeracaoCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import Foundation

final class NotificacoesModeracaoCRUD {
    static let limiteCaracteresMotivo = 4000

    private let cliente: ClienteCloudKit

    init(cliente: ClienteCloudKit = ClienteCloudKit()) {
        self.cliente = cliente
    }

    func publicarRemocao(
        para destinatarioID: UUID,
        tipoConteudo: TipoConteudoModerado,
        conteudoID: UUID? = nil,
        nomeConteudo: String? = nil,
        motivo: String
    ) async throws -> NotificacaoModeracao {
        let motivo = try ApoioCRUD.textoObrigatorio(
            motivo,
            nome: "o motivo da remoção"
        )
        guard motivo.count <= Self.limiteCaracteresMotivo else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "O motivo da remoção deve ter no máximo \(Self.limiteCaracteresMotivo) caracteres."
            )
        }

        let notificacao = NotificacaoModeracao(
            id: UUID(),
            destinatarioID: destinatarioID,
            tipoConteudo: tipoConteudo,
            conteudoID: conteudoID,
            nomeConteudo: ApoioCRUD.textoOpcional(nomeConteudo),
            motivo: motivo,
            criadaEm: Date()
        )
        let registro = try ConversorRegistroCloudKit.registro(de: notificacao)
        return try ConversorRegistroCloudKit.notificacaoModeracao(
            de: try await cliente.salvar(registro)
        )
    }
}
