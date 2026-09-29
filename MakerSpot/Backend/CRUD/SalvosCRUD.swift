//
//  SalvosCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

enum MudancaSpotSalvo: Equatable, Sendable {
    case ignorada
    case atualizado(Spot)
    case removido(UUID)
}

final class SalvosCRUD {
    private let alteracoes: AlteracoesSpots
    private let cliente: ClienteCloudKit
    private let assinaturas: AssinaturasCloudKit
    private let autorizacao: AutorizacaoCRUD
    private let notificacoes: Notificacoes

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario,
        assinaturas: AssinaturasCloudKit = AssinaturasCloudKit(),
        notificacoes: Notificacoes = Notificacoes()
    ) {
        self.cliente = cliente
        self.alteracoes = sessao.alteracoesSpots
        self.assinaturas = assinaturas
        self.notificacoes = notificacoes
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
    }

    func salvar(spotID: UUID) async throws -> SpotSalvo {
        let contexto = try await autorizacao.contextoAtual()
        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        let spot = try ApoioCRUD.spotValido(de: registroSpot)
        guard spot.estaDisponivel() else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Este Spot não está disponível para salvar."
            )
        }
        guard !autorizacao.foiCriadoPeloUsuarioAtual(
            registroSpot,
            spot: spot,
            contexto: contexto
        ) else {
            throw ErroCRUD.spotProprioNaoPodeSerSalvo
        }

        let identificador = IdentificadorCloudKit.spotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spot.id
        )
        do {
            let existente = try await cliente.buscar(identificador, tipo: .spotSalvo)
            let salvo = try ConversorRegistroCloudKit.spotSalvo(de: existente)
            return finalizarSalvamento(salvo, spot: spot)
        } catch ErroCloudKit.registroNaoEncontrado {
        }

        let salvo = SpotSalvo(
            usuarioID: contexto.usuario.id,
            spotID: spot.id,
            salvoEm: Date(),
            ultimaVersaoConhecida: spot.versao
        )

        do {
            let registro = try ConversorRegistroCloudKit.registro(de: salvo)
            let registroSalvo = try ConversorRegistroCloudKit.spotSalvo(
                de: try await cliente.salvar(registro)
            )
            return finalizarSalvamento(registroSalvo, spot: spot)
        } catch {
            let erroOriginal = error
            do {
                let existente = try await cliente.buscar(
                    identificador,
                    tipo: .spotSalvo
                )
                let registroSalvo = try ConversorRegistroCloudKit.spotSalvo(
                    de: existente
                )
                return finalizarSalvamento(registroSalvo, spot: spot)
            } catch let erroVerificacao as ErroCloudKit {
                if case .registroNaoEncontrado = erroVerificacao {
                    Task { try? await assinaturas.removerAssinatura(do: spot.id) }
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
        } catch {
            let erroOriginal = error
            do {
                _ = try await cliente.buscar(identificador, tipo: .spotSalvo)
                throw erroOriginal
            } catch ErroCloudKit.registroNaoEncontrado {
                // A resposta da exclusão se perdeu, mas o registro sumiu.
            }
        }
        // Notificações são complementares e não precisam atrasar a interface.
        alteracoes.dessalvar(spotID)
        EstadoSpotsSalvosNotificacoes.compartilhado.definir(
            false,
            spotID: spotID,
            usuarioID: contexto.usuario.id
        )
        Task {
            try? await assinaturas.removerAssinatura(do: spotID)
            if EstadoSpotsSalvosNotificacoes.compartilhado.contem(spotID) {
                try? await assinaturas.garantirAssinatura(para: spotID)
            }
        }
        notificacoes.cancelarLembretes(spotID: spotID, papel: .salvo)
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
        let sequenciaInicial = EstadoSpotsSalvosNotificacoes.compartilhado.sequenciaAtual
        let salvos = try await listarRegistros(do: contexto.usuario)
        let identificadores = Set(salvos.map(\.spotID))
        EstadoSpotsSalvosNotificacoes.compartilhado.substituir(
            identificadores,
            usuarioID: contexto.usuario.id,
            consultaIniciadaNa: sequenciaInicial
        )
        Task {
            try? await assinaturas.reconciliarAssinaturas()
        }
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
        let itens: [ItemSpotSalvo] = salvos.compactMap { salvo in
            guard let spot = spots[salvo.spotID] else { return nil }
            return ItemSpotSalvo(registro: salvo, spot: spot)
        }
        let eventosParaLembretes = itens.map(\.spot)
        let estadoSalvos = EstadoSpotsSalvosNotificacoes.compartilhado
        let revisoesAoIniciar = Dictionary(
            uniqueKeysWithValues: eventosParaLembretes.compactMap { spot in
                estadoSalvos.revisaoSeSalvo(spot.id).map { (spot.id, $0) }
            }
        )
        Task {
            try? await notificacoes.sincronizarLembretes(
                eventos: eventosParaLembretes.filter { estadoSalvos.contem($0.id) },
                papel: .salvo
            )
            for spot in eventosParaLembretes where
                !estadoSalvos.contem(spot.id) {
                notificacoes.cancelarLembretes(spotID: spot.id, papel: .salvo)
            }
            // Uma gravação posterior pode ter ocorrido enquanto a lista era
            // sincronizada. Reponha os lembretes desse estado mais recente.
            for id in estadoSalvos.identificadoresAtuais()
                where revisoesAoIniciar[id] != estadoSalvos.revisaoSeSalvo(id) {
                guard let registro = try? await cliente.buscar(
                    IdentificadorCloudKit.spot(id),
                    tipo: .spot
                ), let spot = try? ApoioCRUD.spotValido(de: registro),
                   estadoSalvos.contem(id) else { continue }
                try? await notificacoes.agendarLembretes(para: spot, papel: .salvo)
            }
        }
        return itens
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
        let atualizado = try ConversorRegistroCloudKit.spotSalvo(
            de: try await cliente.salvar(alterado)
        )
        alteracoes.marcarComoVisualizado(atualizado, spot: spot)
        return atualizado
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
            guard spot.versao > salvo.ultimaVersaoConhecida else {
                return .ignorada
            }
            try? await notificacoes.agendarLembretes(
                para: spot,
                papel: .salvo
            )
            return .atualizado(spot)
        } catch ErroCloudKit.registroNaoEncontrado {
            try? await cliente.excluir(identificadorSalvo, tipo: .spotSalvo)
            try? await assinaturas.removerAssinatura(do: spotID)
            notificacoes.cancelarLembretes(spotID: spotID, papel: .salvo)
            return .removido(spotID)
        }
    }

    private func finalizarSalvamento(
        _ salvo: SpotSalvo,
        spot: Spot
    ) -> SpotSalvo {
        alteracoes.salvar(salvo, spot: spot)
        let revisao = EstadoSpotsSalvosNotificacoes.compartilhado.definir(
            true,
            spotID: spot.id,
            usuarioID: salvo.usuarioID
        )
        Task {
            try? await assinaturas.garantirAssinatura(para: spot.id)
            guard let revisao,
                  EstadoSpotsSalvosNotificacoes.compartilhado.permaneceSalvo(
                    spot.id,
                    revisao: revisao
                  ) else {
                if !EstadoSpotsSalvosNotificacoes.compartilhado.contem(spot.id) {
                    try? await assinaturas.removerAssinatura(do: spot.id)
                }
                return
            }
            let estado = await notificacoes.verificarPermissao()
            guard estado == .autorizada || estado == .provisoria else { return }
            notificacoes.registrarParaNotificacoesRemotas()
            guard EstadoSpotsSalvosNotificacoes.compartilhado.permaneceSalvo(
                spot.id,
                revisao: revisao
            ) else { return }
            try? await notificacoes.agendarLembretes(
                para: spot,
                papel: .salvo
            )
            if !EstadoSpotsSalvosNotificacoes.compartilhado.permaneceSalvo(
                spot.id,
                revisao: revisao
            ), !EstadoSpotsSalvosNotificacoes.compartilhado.contem(spot.id) {
                notificacoes.cancelarLembretes(spotID: spot.id, papel: .salvo)
            }
        }
        return salvo
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
