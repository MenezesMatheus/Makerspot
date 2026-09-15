//
//  ApoioCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 15/09/26.
//

import CloudKit
import Foundation

enum ErroCRUD: LocalizedError {
    case usuarioNaoAutenticado
    case contaCloudKitDivergente
    case usuarioBanido
    case somenteProprietario
    case spotProprioNaoPodeSerSalvo
    case spotProprioNaoPodeSerDenunciado
    case conteudoFotoNaoPermitido
    case moderacaoLocalIndisponivel
    case respostaInconsistente
    case dadosInvalidos(descricao: String)

    var errorDescription: String? {
        switch self {
        case .usuarioNaoAutenticado:
            return "Entre com sua conta Apple para continuar."
        case .contaCloudKitDivergente:
            return "A conta do iCloud atual não corresponde ao perfil autenticado."
        case .usuarioBanido:
            return "Esta conta foi impedida de usar o MakerSpot."
        case .somenteProprietario:
            return "Somente o proprietário pode alterar este Spot."
        case .spotProprioNaoPodeSerSalvo:
            return "Você não pode salvar um Spot criado por você."
        case .spotProprioNaoPodeSerDenunciado:
            return "Você não pode denunciar um Spot criado por você."
        case .conteudoFotoNaoPermitido:
            return "Esta foto contém conteúdo que não é permitido no MakerSpot."
        case .moderacaoLocalIndisponivel:
            return "Não foi possível verificar a segurança da foto. Tente novamente."
        case .respostaInconsistente:
            return "O banco retornou uma resposta incompleta. Atualize os dados e tente novamente."
        case .dadosInvalidos(let descricao):
            return descricao
        }
    }
}

struct ContextoUsuarioCRUD: Sendable {
    let usuario: Usuario
    let identificadorCloudKit: CKRecord.ID
}

final class AutorizacaoCRUD {
    private let cliente: ClienteCloudKit
    private let sessao: SessaoUsuario

    init(cliente: ClienteCloudKit, sessao: SessaoUsuario) {
        self.cliente = cliente
        self.sessao = sessao
    }

    func contextoAtual() async throws -> ContextoUsuarioCRUD {
        guard let usuario = sessao.usuarioAtual else {
            throw ErroCRUD.usuarioNaoAutenticado
        }

        let identificadorCloudKit = try await cliente.verificarConta()
        guard usuario.cloudKitUserRecordName == identificadorCloudKit.recordName else {
            throw ErroCRUD.contaCloudKitDivergente
        }

        try await validarUsuarioAtivo(
            cloudKitUserRecordName: identificadorCloudKit.recordName
        )

        return ContextoUsuarioCRUD(
            usuario: usuario,
            identificadorCloudKit: identificadorCloudKit
        )
    }

    func validarUsuarioAtivo(cloudKitUserRecordName: String) async throws {
        let contaHash = IdentificadorContaCloudKit.hash(
            de: cloudKitUserRecordName
        )
        do {
            let registro = try await cliente.buscar(
                IdentificadorCloudKit.banimentoUsuario(contaHash: contaHash),
                tipo: .banimentoUsuario
            )
            let banimento = try ConversorRegistroCloudKit.banimentoUsuario(de: registro)
            guard banimento.contaHash == contaHash else {
                throw ErroCRUD.respostaInconsistente
            }
            throw ErroCRUD.usuarioBanido
        } catch ErroCloudKit.registroNaoEncontrado {
            return
        }
    }

    func validarProprietario(
        do registro: CKRecord,
        spot: Spot,
        contexto: ContextoUsuarioCRUD
    ) throws {
        guard spot.proprietarioID == contexto.usuario.id,
              registro.creatorUserRecordID == contexto.identificadorCloudKit else {
            throw ErroCRUD.somenteProprietario
        }
    }
}

enum ApoioCRUD {
    static func spotValido(de registro: CKRecord) throws -> Spot {
        let spot = try ConversorRegistroCloudKit.spot(de: registro)
        try ValidadorSpotCRUD.validarRecebido(spot)
        return spot
    }

    static func registrarAlteracao(_ spot: inout Spot) throws {
        let (versao, excedeuLimite) = spot.versao.addingReportingOverflow(1)
        guard !excedeuLimite else { throw ErroCRUD.respostaInconsistente }
        spot.versao = versao
        spot.atualizadoEm = Date()
    }

    static func nomePublico(do usuario: Usuario) -> String {
        let partes = [usuario.nome, usuario.sobrenome]
            .compactMap { textoOpcional($0) }

        return partes.isEmpty
            ? "Usuário MakerSpot"
            : partes.joined(separator: " ")
    }

    static func textoObrigatorio(_ valor: String, nome: String) throws -> String {
        let texto = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else {
            throw ErroCRUD.dadosInvalidos(descricao: "Informe \(nome).")
        }
        return texto
    }

    static func textoOpcional(_ valor: String?) -> String? {
        guard let valor else { return nil }
        let texto = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        return texto.isEmpty ? nil : texto
    }

    static func validarURLWeb(_ url: URL?, nome: String) throws {
        guard let url else { return }
        let esquema = url.scheme?.lowercased()
        guard esquema == "http" || esquema == "https",
              url.host != nil else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "O endereço de \(nome) precisa ser um link HTTP ou HTTPS válido."
            )
        }
    }

    static func exigirSemFalhas(_ falhas: [FalhaRegistroCloudKit]) throws {
        guard let falha = falhas.first else { return }
        if falhas.count == 1 {
            throw falha.erro
        }

        let erros = Dictionary(
            uniqueKeysWithValues: falhas.map { falha in
                (falha.identificador.recordName, falha.erro)
            }
        )
        throw ErroCloudKit.falhaParcial(erros)
    }
}
