//
//  SalvosCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

struct ItemSpotSalvo: Equatable, Sendable {
    let registro: SpotSalvo
    let spot: Spot

    var foiAtualizado: Bool {
        spot.versao > registro.ultimaVersaoConhecida
    }
}

enum MudancaSpotSalvo: Equatable, Sendable {
    case ignorada
    case atualizado(Spot)
    case removido(UUID)
}

final class SalvosCRUD {
    private let cliente: ClienteCloudKit
    private let assinaturas: AssinaturasCloudKit
    private let autorizacao: AutorizacaoCRUD

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario,
        assinaturas: AssinaturasCloudKit = AssinaturasCloudKit()
    ) {
        self.cliente = cliente
        self.assinaturas = assinaturas
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
    }

    func salvar(spotID: UUID) async throws -> SpotSalvo {
        let contexto = try await autorizacao.contextoAtual()
        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        let spot = try ApoioCRUD.spotValido(de: registroSpot)
        guard let criadorSpot = registroSpot.creatorUserRecordID else {
            throw ErroCRUD.respostaInconsistente
        }
        guard criadorSpot.recordName != contexto.identificadorCloudKit.recordName else {
            throw ErroCRUD.spotProprioNaoPodeSerSalvo
        }

        let identificador = IdentificadorCloudKit.spotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spot.id
        )
        do {
            let existente = try await cliente.buscar(identificador, tipo: .spotSalvo)
            let salvo = try ConversorRegistroCloudKit.spotSalvo(de: existente)
            try await assinaturas.garantirAssinatura(para: spot.id)
            return salvo
        } catch ErroCloudKit.registroNaoEncontrado {
        }

        let salvo = SpotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spot.id,
            salvoEm: Date(),
            ultimaVersaoConhecida: spot.versao
        )

        try await assinaturas.garantirAssinatura(para: spot.id)
        do {
            let registro = try ConversorRegistroCloudKit.registro(de: salvo)
            return try ConversorRegistroCloudKit.spotSalvo(
                de: try await cliente.salvar(registro)
            )
        } catch {
            let erroOriginal = error
            do {
                let existente = try await cliente.buscar(
                    identificador,
                    tipo: .spotSalvo
                )
                return try ConversorRegistroCloudKit.spotSalvo(de: existente)
            } catch let erroVerificacao as ErroCloudKit {
                if case .registroNaoEncontrado = erroVerificacao {
                    try? await assinaturas.removerAssinatura(do: spot.id)
                }
                throw erroOriginal
            } catch {
                throw erroOriginal
            }
        }
    }

    func dessalvar(spotID: UUID) async throws {
        let contexto = try await autorizacao.contextoAtual()
        let identificador = IdentificadorCloudKit.spotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spotID
        )

        do {
            try await cliente.excluir(identificador, tipo: .spotSalvo)
        } catch ErroCloudKit.registroNaoEncontrado {
        }
        try await assinaturas.removerAssinatura(do: spotID)
    }

    func estaSalvo(spotID: UUID) async throws -> Bool {
        let contexto = try await autorizacao.contextoAtual()
        do {
            _ = try await cliente.buscar(
                IdentificadorCloudKit.spotSalvo(
                    usuarioID: contexto.usuario.id,
                    spotID: spotID
                ),
                tipo: .spotSalvo
            )
            return true
        } catch ErroCloudKit.registroNaoEncontrado {
            return false
        }
    }

    func listar() async throws -> [SpotSalvo] {
        let contexto = try await autorizacao.contextoAtual()
        let salvos = try await listarRegistros(do: contexto.usuario)
        try await assinaturas.reconciliarAssinaturas(
            com: Set(salvos.map(\.spotID))
        )
        return salvos
    }

    func listarComSpots() async throws -> [ItemSpotSalvo] {
        let salvos = try await listar()
        guard !salvos.isEmpty else { return [] }

        let resultado = try await cliente.buscar(
            salvos.map { IdentificadorCloudKit.spot($0.spotID) },
            tipo: .spot
        )

        var falhasReais: [FalhaRegistroCloudKit] = []
        for falha in resultado.falhas {
            if case .registroNaoEncontrado = falha.erro,
               let spotID = IdentificadorCloudKit.spotDoRegistro(falha.identificador) {
                try? await dessalvar(spotID: spotID)
            } else {
                falhasReais.append(falha)
            }
        }
        try ApoioCRUD.exigirSemFalhas(falhasReais)

        let paresValidos: [(UUID, Spot)] = resultado.registros.compactMap { registro in
            guard let spot = try? ApoioCRUD.spotValido(de: registro) else { return nil }
            return (spot.id, spot)
        }
        let spots = Dictionary(uniqueKeysWithValues: paresValidos)
        return salvos.compactMap { salvo in
            guard let spot = spots[salvo.spotID] else { return nil }
            return ItemSpotSalvo(registro: salvo, spot: spot)
        }
    }

    func marcarComoVisualizado(spotID: UUID) async throws -> SpotSalvo {
        let contexto = try await autorizacao.contextoAtual()
        let identificadorSalvo = IdentificadorCloudKit.spotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spotID
        )
        let registroSalvo = try await cliente.buscar(
            identificadorSalvo,
            tipo: .spotSalvo
        )
        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        var salvo = try ConversorRegistroCloudKit.spotSalvo(de: registroSalvo)
        let spot = try ApoioCRUD.spotValido(de: registroSpot)
        salvo.ultimaVersaoConhecida = spot.versao

        let alterado = try ConversorRegistroCloudKit.registro(
            de: salvo,
            existente: registroSalvo
        )
        return try ConversorRegistroCloudKit.spotSalvo(
            de: try await cliente.salvar(alterado)
        )
    }

    func processarNotificacao(
        _ dados: [AnyHashable: Any]
    ) async throws -> MudancaSpotSalvo {
        guard let spotID = assinaturas.interpretarNotificacao(dados) else {
            return .ignorada
        }

        let contexto = try await autorizacao.contextoAtual()
        let identificadorSalvo = IdentificadorCloudKit.spotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spotID
        )
        let salvo: SpotSalvo
        do {
            salvo = try ConversorRegistroCloudKit.spotSalvo(
                de: try await cliente.buscar(identificadorSalvo, tipo: .spotSalvo)
            )
        } catch ErroCloudKit.registroNaoEncontrado {
            try? await assinaturas.removerAssinatura(do: spotID)
            return .ignorada
        }

        do {
            let spot = try ApoioCRUD.spotValido(
                de: try await cliente.buscar(
                    IdentificadorCloudKit.spot(spotID),
                    tipo: .spot
                )
            )
            return spot.versao > salvo.ultimaVersaoConhecida
                ? .atualizado(spot)
                : .ignorada
        } catch ErroCloudKit.registroNaoEncontrado {
            try? await cliente.excluir(identificadorSalvo, tipo: .spotSalvo)
            try? await assinaturas.removerAssinatura(do: spotID)
            return .removido(spotID)
        }
    }

    private func listarRegistros(do usuario: Usuario) async throws -> [SpotSalvo] {
        let resultado = try await cliente.consultarTodos(
            tipo: .spotSalvo,
            predicado: NSPredicate(
                format: "%K == %@",
                CampoCloudKit.SpotSalvo.usuarioID,
                usuario.id.uuidString.lowercased()
            ),
            ordenacao: [
                NSSortDescriptor(
                    key: CampoCloudKit.SpotSalvo.salvoEm,
                    ascending: false
                ),
                NSSortDescriptor(key: CampoCloudKit.id, ascending: true)
            ]
        )
        try ApoioCRUD.exigirSemFalhas(resultado.falhas)
        return try resultado.registros.map { registro in
            try ConversorRegistroCloudKit.spotSalvo(de: registro)
        }
    }
}
