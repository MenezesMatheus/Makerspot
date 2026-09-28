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

    func denunciar(
        spotID: UUID,
        texto: String,
        id: UUID = UUID()
    ) async throws -> Denuncia {
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
        guard !autorizacao.foiCriadoPeloUsuarioAtual(
            registroSpot,
            spot: spot,
            contexto: contexto
        ) else {
            throw ErroCRUD.spotProprioNaoPodeSerDenunciado
        }

        let denuncia = Denuncia(
            id: id,
            spotID: spot.id,
            texto: motivo,
            criadaEm: Date()
        )
        let registro = try ConversorRegistroCloudKit.registro(de: denuncia)
        do {
            return try ConversorRegistroCloudKit.denuncia(
                de: try await cliente.salvar(registro)
            )
        } catch {
            let erroOriginal = error
            guard let remoto = try? await cliente.buscar(registro.recordID, tipo: .denuncia),
                  let confirmada = try? ConversorRegistroCloudKit.denuncia(de: remoto),
                  confirmada.id == denuncia.id,
                  confirmada.spotID == denuncia.spotID,
                  confirmada.texto == denuncia.texto else {
                throw erroOriginal
            }
            return confirmada
        }
    }
}
