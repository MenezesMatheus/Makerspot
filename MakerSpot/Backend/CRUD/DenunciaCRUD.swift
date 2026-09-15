//
//  DenunciaCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

final class DenunciaCRUD {
    static let limiteCaracteres = 4_000

    private let cliente: ClienteCloudKit
    private let autorizacao: AutorizacaoCRUD

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario
    ) {
        self.cliente = cliente
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
    }

    func denunciar(spotID: UUID, texto: String) async throws -> Denuncia {
        let contexto = try await autorizacao.contextoAtual()
        let motivo = try ApoioCRUD.textoObrigatorio(
            texto,
            nome: "o motivo da denúncia"
        )
        guard motivo.count <= Self.limiteCaracteres else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "A denúncia deve ter no máximo \(Self.limiteCaracteres) caracteres."
            )
        }

        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        let spot = try ConversorRegistroCloudKit.spot(de: registroSpot)
        guard let criadorSpot = registroSpot.creatorUserRecordID else {
            throw ErroCRUD.respostaInconsistente
        }
        guard criadorSpot.recordName != contexto.identificadorCloudKit.recordName else {
            throw ErroCRUD.spotProprioNaoPodeSerDenunciado
        }

        let denuncia = Denuncia(
            id: UUID(),
            spotID: spot.id,
            texto: motivo,
            criadaEm: Date()
        )
        let registro = try ConversorRegistroCloudKit.registro(de: denuncia)
        return try ConversorRegistroCloudKit.denuncia(
            de: try await cliente.salvar(registro)
        )
    }
}
