//
//  UsuarioCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import CryptoKit
import Foundation

struct DadosPerfilUsuario: Equatable, Sendable {
    var nome: String?
    var sobrenome: String?
    var telefonePadrao: String?
}

final class UsuarioCRUD {
    private let cliente: ClienteCloudKit
    private let sessao: SessaoUsuario
    private let autenticacaoApple: AutenticacaoApple
    private let autorizacao: AutorizacaoCRUD

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario,
        autenticacaoApple: AutenticacaoApple = AutenticacaoApple()
    ) {
        self.cliente = cliente
        self.sessao = sessao
        self.autenticacaoApple = autenticacaoApple
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
    }

    func entrar(com dadosApple: DadosAutenticacaoApple) async throws -> Usuario {
        let identificadorApple = try ApoioCRUD.textoObrigatorio(
            dadosApple.identificadorUsuario,
            nome: "uma credencial Apple válida"
        )
        let identificadorCloudKit = try await cliente.verificarConta()
        let encontrado = try await buscarUsuario(
            appleUserID: identificadorApple,
            cloudKitUserRecordName: identificadorCloudKit.recordName
        )

        let usuario: Usuario
        if let existente = encontrado {
            guard existente.usuario.cloudKitUserRecordName
                    == identificadorCloudKit.recordName else {
                throw ErroCRUD.contaCloudKitDivergente
            }

            var atualizado = existente.usuario
            if atualizado.nome == nil {
                atualizado.nome = ApoioCRUD.textoOpcional(dadosApple.nome)
            }
            if atualizado.sobrenome == nil {
                atualizado.sobrenome = ApoioCRUD.textoOpcional(dadosApple.sobrenome)
            }

            if atualizado != existente.usuario {
                atualizado.atualizadoEm = Date()
                let registro = try ConversorRegistroCloudKit.registro(
                    de: atualizado,
                    existente: existente.registro
                )
                let salvo = try await cliente.salvar(registro)
                usuario = try ConversorRegistroCloudKit.usuario(de: salvo)
            } else {
                usuario = existente.usuario
            }
        } else {
            let agora = Date()
            let novoUsuario = Usuario(
                id: identificadorDeterministico(
                    appleUserID: identificadorApple,
                    cloudKitUserRecordName: identificadorCloudKit.recordName
                ),
                appleUserID: identificadorApple,
                cloudKitUserRecordName: identificadorCloudKit.recordName,
                nome: ApoioCRUD.textoOpcional(dadosApple.nome),
                sobrenome: ApoioCRUD.textoOpcional(dadosApple.sobrenome),
                fotoID: nil,
                telefonePadrao: nil,
                criadoEm: agora,
                atualizadoEm: agora
            )
            let registro = try ConversorRegistroCloudKit.registro(de: novoUsuario)
            do {
                usuario = try ConversorRegistroCloudKit.usuario(
                    de: try await cliente.salvar(registro)
                )
            } catch {
                let erroOriginal = error
                guard let existente = try? await cliente.buscar(
                    IdentificadorCloudKit.usuario(novoUsuario.id),
                    tipo: .usuario
                ),
                let usuarioExistente = try? ConversorRegistroCloudKit.usuario(de: existente),
                usuarioExistente.appleUserID == identificadorApple,
                usuarioExistente.cloudKitUserRecordName == identificadorCloudKit.recordName else {
                    throw erroOriginal
                }
                usuario = usuarioExistente
            }
        }

        try await autorizacao.validarUsuarioAtivo(
            cloudKitUserRecordName: identificadorCloudKit.recordName
        )
        try sessao.iniciar(com: usuario)
        return usuario
    }

    func restaurarSessao() async throws -> Usuario? {
        guard let identificadorApple = try sessao.identificadorAppleSalvo() else {
            return nil
        }

        let estado = try await autenticacaoApple.verificarEstado(
            identificadorUsuario: identificadorApple
        )
        guard estado == .autorizada else {
            try sessao.encerrar()
            return nil
        }

        let identificadorCloudKit = try await cliente.verificarConta()
        let encontrado = try await buscarUsuario(
            appleUserID: identificadorApple,
            cloudKitUserRecordName: identificadorCloudKit.recordName
        )
        guard let encontrado else {
            try sessao.encerrar()
            return nil
        }
        guard encontrado.usuario.cloudKitUserRecordName
                == identificadorCloudKit.recordName else {
            try sessao.encerrar()
            throw ErroCRUD.contaCloudKitDivergente
        }

        try await autorizacao.validarUsuarioAtivo(
            cloudKitUserRecordName: identificadorCloudKit.recordName
        )
        sessao.restaurar(encontrado.usuario)
        return encontrado.usuario
    }

    func buscarUsuarioAtual() async throws -> Usuario {
        let contexto = try await autorizacao.contextoAtual()
        let registro = try await cliente.buscar(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        let usuario = try ConversorRegistroCloudKit.usuario(de: registro)
        guard usuario.appleUserID == contexto.usuario.appleUserID,
              usuario.cloudKitUserRecordName == contexto.identificadorCloudKit.recordName else {
            throw ErroCRUD.contaCloudKitDivergente
        }
        sessao.restaurar(usuario)
        return usuario
    }

    func atualizarPerfil(_ dados: DadosPerfilUsuario) async throws -> Usuario {
        let contexto = try await autorizacao.contextoAtual()
        let registroAtual = try await cliente.buscar(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        var usuario = try ConversorRegistroCloudKit.usuario(de: registroAtual)
        usuario.nome = ApoioCRUD.textoOpcional(dados.nome)
        usuario.sobrenome = ApoioCRUD.textoOpcional(dados.sobrenome)
        usuario.telefonePadrao = ApoioCRUD.textoOpcional(dados.telefonePadrao)
        usuario.atualizadoEm = Date()

        let alterado = try ConversorRegistroCloudKit.registro(
            de: usuario,
            existente: registroAtual
        )
        let salvo = try await cliente.salvar(alterado)
        let atualizado = try ConversorRegistroCloudKit.usuario(de: salvo)
        sessao.restaurar(atualizado)
        return atualizado
    }

    func encerrarSessao() throws {
        try sessao.encerrar()
    }

    func excluirConta() async throws {
        let contexto = try await autorizacao.contextoAtual()
        let usuarioID = contexto.usuario.id

        let salvos = try await registrosDoUsuario(
            tipo: .spotSalvo,
            campo: CampoCloudKit.SpotSalvo.usuarioID,
            usuarioID: usuarioID
        )
        let spots = try await registrosDoUsuario(
            tipo: .spot,
            campo: CampoCloudKit.Spot.proprietarioID,
            usuarioID: usuarioID
        )
        let fotos = try await registrosDoUsuario(
            tipo: .fotoSpot,
            campo: CampoCloudKit.Foto.enviadaPorID,
            usuarioID: usuarioID
        )

        guard spots.allSatisfy({
            $0.creatorUserRecordID == contexto.identificadorCloudKit
        }) else {
            throw ErroCRUD.respostaInconsistente
        }

        try await AssinaturasCloudKit().reconciliarAssinaturas(com: [])
        try await excluir(fotos, tipo: .fotoSpot)
        try await excluir(spots, tipo: .spot)
        try await excluir(salvos, tipo: .spotSalvo)

        if let fotoID = contexto.usuario.fotoID {
            try await excluirSeExistir(
                IdentificadorCloudKit.foto(fotoID),
                tipo: .fotoPerfil
            )
        }

        try await excluirSeExistir(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        try sessao.encerrar()
    }

    private func buscarUsuario(
        appleUserID: String,
        cloudKitUserRecordName: String
    ) async throws -> (usuario: Usuario, registro: CKRecord)? {
        let identificador = IdentificadorCloudKit.usuario(
            identificadorDeterministico(
                appleUserID: appleUserID,
                cloudKitUserRecordName: cloudKitUserRecordName
            )
        )

        do {
            let registro = try await cliente.buscar(
                identificador,
                tipo: .usuario
            )
            let usuario = try ConversorRegistroCloudKit.usuario(de: registro)
            guard usuario.appleUserID == appleUserID,
                  usuario.cloudKitUserRecordName == cloudKitUserRecordName else {
                throw ErroCRUD.contaCloudKitDivergente
            }
            return (usuario, registro)
        } catch ErroCloudKit.registroNaoEncontrado {
            return nil
        }
    }

    private func registrosDoUsuario(
        tipo: TipoRegistroCloudKit,
        campo: String,
        usuarioID: UUID
    ) async throws -> [CKRecord] {
        let resultado = try await cliente.consultarTodos(
            tipo: tipo,
            predicado: NSPredicate(
                format: "%K == %@",
                campo,
                usuarioID.uuidString.lowercased()
            )
        )
        try ApoioCRUD.exigirSemFalhas(resultado.falhas)
        return resultado.registros
    }

    private func excluir(
        _ registros: [CKRecord],
        tipo: TipoRegistroCloudKit
    ) async throws {
        for registro in registros {
            try await excluirSeExistir(registro.recordID, tipo: tipo)
        }
    }

    private func excluirSeExistir(
        _ identificador: CKRecord.ID,
        tipo: TipoRegistroCloudKit
    ) async throws {
        do {
            try await cliente.excluir(identificador, tipo: tipo)
        } catch ErroCloudKit.registroNaoEncontrado {
        }
    }

    private func identificadorDeterministico(
        appleUserID: String,
        cloudKitUserRecordName: String
    ) -> UUID {
        let origem = Data(
            "MakerSpot.Usuario|\(cloudKitUserRecordName)|\(appleUserID)".utf8
        )
        var bytes = Array(SHA256.hash(data: origem).prefix(16))

        // Marca os bits como UUID versão 8 (uso específico) e variante RFC 4122.
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
