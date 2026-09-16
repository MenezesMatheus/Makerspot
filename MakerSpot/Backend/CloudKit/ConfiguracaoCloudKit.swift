//
//  ConfiguracaoCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import CryptoKit
import Foundation

enum EscopoBancoCloudKit: Sendable {
    case publico
    case privado
}

enum TipoRegistroCloudKit: String, CaseIterable, Sendable {
    case usuario = "Usuario"
    case spot = "Spot"
    case fotoSpot = "FotoSpot"
    case fotoPerfil = "FotoPerfil"
    case spotSalvo = "SpotSalvo"
    case denuncia = "Denuncia"
    case analiseDenuncia = "AnaliseDenuncia"
    case banimentoUsuario = "BanimentoUsuario"

    var escopo: EscopoBancoCloudKit {
        switch self {
        case .usuario, .fotoPerfil, .spotSalvo:
            return .privado
        case .spot, .fotoSpot, .denuncia, .analiseDenuncia, .banimentoUsuario:
            return .publico
        }
    }
}

enum CampoCloudKit {
    static let id = "id"
    static let versaoEsquema = "versaoEsquema"
    static let criadoEm = "criadoEm"
    static let atualizadoEm = "atualizadoEm"

    enum Usuario {
        static let appleUserID = "appleUserID"
        static let cloudKitUserRecordName = "cloudKitUserRecordName"
        static let nome = "nome"
        static let sobrenome = "sobrenome"
        static let fotoID = "fotoID"
        static let telefonePadrao = "telefonePadrao"
    }

    enum Spot {
        static let proprietarioID = "proprietarioID"
        static let nomePublicador = "nomePublicador"
        static let tipo = "tipo"
        static let nome = "nome"
        static let descricao = "descricao"
        static let telefone = "telefone"
        static let link = "link"
        static let redesSociais = "redesSociais"
        static let fotoIDs = "fotoIDs"
        static let estaAtivo = "estaAtivo"
        static let versao = "versao"

        static let logradouro = "logradouro"
        static let numero = "numero"
        static let complemento = "complemento"
        static let bairro = "bairro"
        static let cidade = "cidade"
        static let estado = "estado"
        static let codigoPostal = "codigoPostal"
        static let codigoPais = "codigoPais"
        static let localizacao = "localizacao"

        static let inicioEvento = "inicioEvento"
        static let terminoEvento = "terminoEvento"
        static let fusoHorarioID = "fusoHorarioID"
        static let funcionamento = "funcionamento"
    }

    enum Foto {
        static let enviadaPorID = "enviadaPorID"
        static let destinoTipo = "destinoTipo"
        static let destinoID = "destinoID"
        static let textoAlternativo = "textoAlternativo"
        static let arquivo = "arquivo"
        static let spotReferencia = "spotReferencia"
        static let usuarioReferencia = "usuarioReferencia"
    }

    enum SpotSalvo {
        static let usuarioID = "usuarioID"
        static let spotID = "spotID"
        static let salvoEm = "salvoEm"
        static let ultimaVersaoConhecida = "ultimaVersaoConhecida"
    }

    enum Denuncia {
        static let spotID = "spotID"
        static let spotReferencia = "spotReferencia"
        static let texto = "texto"
        static let criadaEm = "criadaEm"
    }

    enum AnaliseDenuncia {
        static let denunciaID = "denunciaID"
        static let denunciaReferencia = "denunciaReferencia"
        static let status = "status"
        static let observacao = "observacao"
        static let analisadaEm = "analisadaEm"
    }

    enum BanimentoUsuario {
        static let contaHash = "contaHash"
        static let banidoEm = "banidoEm"
    }
}

enum VersaoEsquemaCloudKit {
    static let atual = 1
}

enum IdentificadorContaCloudKit {
    static func hash(de cloudKitUserRecordName: String) -> String {
        SHA256.hash(data: Data(cloudKitUserRecordName.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func normalizarHash(_ valor: String) -> String? {
        let hash = valor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard hash.count == 64,
              hash.unicodeScalars.allSatisfy({ escalar in
                (48...57).contains(escalar.value) || (97...102).contains(escalar.value)
              }) else {
            return nil
        }
        return hash
    }
}

enum IdentificadorCloudKit {
    private static let prefixoBaseAssinaturaSpot = "alteracoes_spot_"
    private static let prefixoAssinaturaSpot = "\(prefixoBaseAssinaturaSpot)v1_"

    private static func texto(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    static func usuario(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "usuario_\(texto(id))")
    }

    static func spot(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "spot_\(texto(id))")
    }

    static func foto(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "foto_\(texto(id))")
    }

    static func spotSalvo(_ salvo: SpotSalvo) -> CKRecord.ID {
        spotSalvo(usuarioID: salvo.usuarioID, spotID: salvo.spotID)
    }

    static func spotSalvo(usuarioID: UUID, spotID: UUID) -> CKRecord.ID {
        CKRecord.ID(
            recordName: "salvo_\(texto(usuarioID))_\(texto(spotID))"
        )
    }

    static func denuncia(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "denuncia_\(texto(id))")
    }

    static func analiseDenuncia(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "analise_denuncia_\(texto(id))")
    }

    static func banimentoUsuario(contaHash: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "banimento_usuario_\(contaHash)")
    }

    static func assinaturaSpot(_ id: UUID) -> CKSubscription.ID {
        "\(prefixoAssinaturaSpot)\(texto(id))"
    }

    static func spotDaAssinatura(_ identificador: CKSubscription.ID) -> UUID? {
        uuid(de: identificador, removendo: prefixoAssinaturaSpot)
    }

    static func ehAssinaturaMakerSpot(_ identificador: CKSubscription.ID) -> Bool {
        identificador.hasPrefix(prefixoBaseAssinaturaSpot)
    }

    static func spotDeQualquerAssinaturaMakerSpot(
        _ identificador: CKSubscription.ID
    ) -> UUID? {
        guard ehAssinaturaMakerSpot(identificador) else { return nil }

        let sufixo = identificador.dropFirst(prefixoBaseAssinaturaSpot.count)
        if let idLegado = UUID(uuidString: String(sufixo)) {
            return idLegado
        }

        guard let separador = sufixo.lastIndex(of: "_") else { return nil }
        return UUID(uuidString: String(sufixo[sufixo.index(after: separador)...]))
    }

    static func spotDoRegistro(_ identificador: CKRecord.ID) -> UUID? {
        uuid(de: identificador.recordName, removendo: "spot_")
    }

    static func fotoDoRegistro(_ identificador: CKRecord.ID) -> UUID? {
        uuid(de: identificador.recordName, removendo: "foto_")
    }

    private static func uuid(de texto: String, removendo prefixo: String) -> UUID? {
        guard texto.hasPrefix(prefixo) else { return nil }
        return UUID(uuidString: String(texto.dropFirst(prefixo.count)))
    }
}

final class ConfiguracaoCloudKit {
    let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    private func banco(_ escopo: EscopoBancoCloudKit) -> CKDatabase {
        switch escopo {
        case .publico:
            return container.publicCloudDatabase
        case .privado:
            return container.privateCloudDatabase
        }
    }

    func banco(para tipo: TipoRegistroCloudKit) -> CKDatabase {
        banco(tipo.escopo)
    }

    func verificarConta() async throws -> CKRecord.ID {
        do {
            switch try await container.accountStatus() {
            case .available:
                return try await container.userRecordID()
            case .noAccount:
                throw ErroCloudKit.contaNaoAutenticada
            case .restricted:
                throw ErroCloudKit.contaRestrita
            case .temporarilyUnavailable:
                throw ErroCloudKit.servicoTemporariamenteIndisponivel(tentarNovamenteEm: nil)
            case .couldNotDetermine:
                throw ErroCloudKit.estadoDaContaIndeterminado
            @unknown default:
                throw ErroCloudKit.estadoDaContaIndeterminado
            }
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }
}
