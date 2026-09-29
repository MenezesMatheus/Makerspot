//
//  SpotCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import CloudKit

struct DadosSpot: Equatable, Sendable {
    var nome: String
    var descricao: String
    var endereco: Endereco
    var telefone: String
    var link: URL?
    var redesSociais: [RedeSocial]
    var detalhes: DetalhesSpot
}

struct CursorPaginaSpots: Sendable {
    fileprivate let valor: CursorRegistrosCloudKit
}

struct PaginaSpots: Sendable {
    let spots: [Spot]
    let proximoCursor: CursorPaginaSpots?
    let quantidadeRegistrosIgnorados: Int
}

final class SpotCRUD {
    private let alteracoes: AlteracoesSpots
    private let cliente: ClienteCloudKit
    private let localizacao: ServicoLocalizacao
    private let autorizacao: AutorizacaoCRUD
    private let notificacoes: Notificacoes
    private let restricoes: SpotsRestritosCRUD

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario,
        localizacao: ServicoLocalizacao = ServicoLocalizacao(),
        notificacoes: Notificacoes = Notificacoes()
    ) {
        self.cliente = cliente
        self.alteracoes = sessao.alteracoesSpots
        self.localizacao = localizacao
        self.notificacoes = notificacoes
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
        self.restricoes = SpotsRestritosCRUD(cliente: cliente)
    }

    func criar(_ dados: DadosSpot, id: UUID = UUID()) async throws -> Spot {
        let contexto = try await autorizacao.contextoAtual()
        let dados = try ValidadorSpotCRUD.validarCadastro(dados)
        let coordenadas = try await localizacao.buscarCoordenadas(para: dados.endereco)
        let agora = Date()
        let spot = Spot(
            id: id,
            proprietarioID: contexto.usuario.id,
            nomePublicador: ApoioCRUD.nomePublico(do: contexto.usuario),
            nome: dados.nome,
            descricao: dados.descricao,
            localizacao: Localizacao(
                endereco: dados.endereco,
                coordenadas: coordenadas
            ),
            telefone: dados.telefone,
            link: dados.link,
            redesSociais: dados.redesSociais,
            fotoIDs: [],
            detalhes: dados.detalhes,
            estaAtivo: true,
            versao: 1,
            criadoEm: agora,
            atualizadoEm: agora
        )

        let registro = try ConversorRegistroCloudKit.registro(de: spot)
        let criado: Spot
        do {
            criado = try ConversorRegistroCloudKit.spot(
                de: try await cliente.salvar(registro)
            )
        } catch {
            let erroOriginal = error
            guard let remoto = try? await cliente.buscar(registro.recordID, tipo: .spot),
                  let confirmado = try? ApoioCRUD.spotValido(de: remoto),
                  confirmado.id == spot.id,
                  confirmado.proprietarioID == spot.proprietarioID else {
                throw erroOriginal
            }
            criado = confirmado
        }
        atualizarLembretesEmSegundoPlano(para: criado)
        alteracoes.atualizar(criado)
        return criado
    }

    func buscar(id: UUID) async throws -> Spot {
        _ = try await autorizacao.contextoAtual()
        let registro = try await cliente.buscar(
            IdentificadorCloudKit.spot(id),
            tipo: .spot
        )
        return try ApoioCRUD.spotValido(de: registro)
    }

    func listarAtivos(
        tipo: TipoSpot? = nil,
        limite: Int = 30,
        continuando cursor: CursorPaginaSpots? = nil
    ) async throws -> PaginaSpots {
        _ = try await autorizacao.contextoAtual()
        let pagina: PaginaRegistrosCloudKit
        if let cursor {
            pagina = try await cliente.continuarConsulta(
                cursor.valor,
                limite: limite
            )
        } else {
            pagina = try await cliente.consultarPrimeiraPagina(
                tipo: .spot,
                predicado: predicadoListagem(
                    somenteAtivos: true,
                    proprietarioID: nil,
                    tipo: tipo
                ),
                ordenacao: [
                    NSSortDescriptor(
                        key: CampoCloudKit.atualizadoEm,
                        ascending: false
                    ),
                    NSSortDescriptor(key: CampoCloudKit.id, ascending: true)
                ],
                limite: limite
            )
        }
        try ApoioCRUD.exigirSemFalhas(pagina.falhas)
        let agora = Date()
        let spotsValidos = pagina.registros.compactMap { try? ApoioCRUD.spotValido(de: $0) }
        let spots = spotsValidos.filter { $0.estaDisponivel(em: agora) }
        return PaginaSpots(
            spots: spots,
            proximoCursor: pagina.proximoCursor.map { CursorPaginaSpots(valor: $0) },
            quantidadeRegistrosIgnorados: pagina.registros.count - spotsValidos.count
        )
    }

    func listarDoUsuarioAtual(tipo: TipoSpot? = nil) async throws -> [Spot] {
        let contexto = try await autorizacao.contextoAtual()
        let resultado = try await cliente.consultarTodos(
            tipo: .spot,
            predicado: predicadoListagem(
                somenteAtivos: false,
                proprietarioID: contexto.usuario.id,
                tipo: tipo
            ),
            ordenacao: [
                NSSortDescriptor(key: CampoCloudKit.atualizadoEm, ascending: false),
                NSSortDescriptor(key: CampoCloudKit.id, ascending: true)
            ]
        )
        try ApoioCRUD.exigirSemFalhas(resultado.falhas)
        return resultado.registros.compactMap { registro in
            guard let spot = try? ApoioCRUD.spotValido(de: registro),
                  autorizacao.ehProprietario(
                    do: registro,
                    spot: spot,
                    contexto: contexto
                  ) else {
                return nil
            }
            return spot
        }
    }

    func editar(id: UUID, com dados: DadosSpot) async throws -> Spot {
        let contexto = try await autorizacao.contextoAtual()
        let registroAtual = try await cliente.buscar(
            IdentificadorCloudKit.spot(id),
            tipo: .spot
        )
        var spot = try ConversorRegistroCloudKit.spot(de: registroAtual)
        try autorizacao.validarProprietario(
            do: registroAtual,
            spot: spot,
            contexto: contexto
        )
        if try await restricoes.estaRestrito(id) {
            throw ErroCRUD.spotRestrito
        }

        let dados = try ValidadorSpotCRUD.validarENormalizar(dados)
        let coordenadas: Coordenadas
        if dados.endereco == spot.localizacao.endereco {
            coordenadas = spot.localizacao.coordenadas
        } else {
            coordenadas = try await localizacao.buscarCoordenadas(para: dados.endereco)
        }

        spot.nomePublicador = ApoioCRUD.nomePublico(do: contexto.usuario)
        spot.nome = dados.nome
        spot.descricao = dados.descricao
        spot.localizacao = Localizacao(
            endereco: dados.endereco,
            coordenadas: coordenadas
        )
        spot.telefone = dados.telefone
        spot.link = dados.link
        spot.redesSociais = dados.redesSociais
        spot.detalhes = dados.detalhes
        try ApoioCRUD.registrarAlteracao(&spot)

        let alterado = try ConversorRegistroCloudKit.registro(
            de: spot,
            existente: registroAtual
        )
        let editado = try ConversorRegistroCloudKit.spot(
            de: try await cliente.salvar(alterado)
        )
        atualizarLembretesEmSegundoPlano(para: editado)
        alteracoes.atualizar(editado)
        return editado
    }

    func definirAtivo(_ estaAtivo: Bool, para id: UUID) async throws -> Spot {
        let contexto = try await autorizacao.contextoAtual()
        let registroAtual = try await cliente.buscar(
            IdentificadorCloudKit.spot(id),
            tipo: .spot
        )
        var spot = try ConversorRegistroCloudKit.spot(de: registroAtual)
        try autorizacao.validarProprietario(
            do: registroAtual,
            spot: spot,
            contexto: contexto
        )
        if estaAtivo, try await restricoes.estaRestrito(id) {
            throw ErroCRUD.spotRestrito
        }
        if estaAtivo, spot.fotoIDs.isEmpty {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Adicione ao menos uma foto antes de publicar o Spot."
            )
        }
        if estaAtivo, spot.eventoEncerrado() {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Atualize a data do evento antes de reativá-lo."
            )
        }
        guard spot.estaAtivo != estaAtivo else { return spot }

        spot.estaAtivo = estaAtivo
        try ApoioCRUD.registrarAlteracao(&spot)
        let alterado = try ConversorRegistroCloudKit.registro(
            de: spot,
            existente: registroAtual
        )
        let atualizado = try ConversorRegistroCloudKit.spot(
            de: try await cliente.salvar(alterado)
        )
        atualizarLembretesEmSegundoPlano(para: atualizado)
        alteracoes.atualizar(atualizado)
        return atualizado
    }

    func estaRestritoPelaModeracao(_ id: UUID) async throws -> Bool {
        _ = try await autorizacao.contextoAtual()
        return try await restricoes.estaRestrito(id)
    }

    func excluir(id: UUID) async throws {
        let contexto = try await autorizacao.contextoAtual()
        let registro = try await cliente.buscar(
            IdentificadorCloudKit.spot(id),
            tipo: .spot
        )
        let spot = try ConversorRegistroCloudKit.spot(de: registro)
        try autorizacao.validarProprietario(
            do: registro,
            spot: spot,
            contexto: contexto
        )
        if try await restricoes.estaRestrito(id) {
            throw ErroCRUD.spotRestrito
        }
        do {
            try await cliente.excluir(registro.recordID, tipo: .spot)
        } catch ErroCloudKit.registroNaoEncontrado {
        } catch {
            let erroOriginal = error
            do {
                _ = try await cliente.buscar(registro.recordID, tipo: .spot)
                throw erroOriginal
            } catch ErroCloudKit.registroNaoEncontrado {
                // A exclusão foi aplicada mesmo sem uma resposta de sucesso.
            }
        }
        alteracoes.excluir(spot.id)
        notificacoes.cancelarLembretes(
            spotID: spot.id,
            papel: .organizador
        )
    }

    private func predicadoListagem(
        somenteAtivos: Bool,
        proprietarioID: UUID?,
        tipo: TipoSpot?
    ) -> NSPredicate {
        var predicados: [NSPredicate] = []

        if somenteAtivos {
            predicados.append(
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.Spot.estaAtivo,
                    NSNumber(value: true)
                )
            )
        }
        if let proprietarioID {
            predicados.append(
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.Spot.proprietarioID,
                    proprietarioID.uuidString.lowercased()
                )
            )
        }
        if let tipo {
            predicados.append(
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.Spot.tipo,
                    tipo.rawValue
                )
            )
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicados)
    }

    private func atualizarLembretesEmSegundoPlano(para spot: Spot) {
        Task {
            try? await notificacoes.agendarLembretes(
                para: spot,
                papel: .organizador
            )
        }
    }
}
