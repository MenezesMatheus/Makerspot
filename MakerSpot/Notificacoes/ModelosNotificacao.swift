//
//  ModelosNotificacao.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 22/09/26.
//

import Foundation

enum PapelLembreteEvento: String, Codable, Sendable {
    case salvo
    case organizador

    var descricao: String {
        switch self {
        case .salvo:
            return "que você salvou"
        case .organizador:
            return "que você está organizando"
        }
    }
}

enum TipoConteudoModerado: String, Codable, CaseIterable, Sendable {
    case evento
    case espaco
    case fotoSpot
    case fotoPerfil
    case perfil
    case outro

    var descricao: String {
        switch self {
        case .evento: return "evento"
        case .espaco: return "espaço"
        case .fotoSpot, .fotoPerfil: return "foto"
        case .perfil: return "perfil"
        case .outro: return "conteúdo"
        }
    }
}

struct NotificacaoModeracao: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let destinatarioID: UUID
    let tipoConteudo: TipoConteudoModerado
    let conteudoID: UUID?
    let nomeConteudo: String?
    let motivo: String
    let criadaEm: Date
}

struct AlertaModeracao: Identifiable, Equatable, Sendable {
    let id: UUID
    let tipoConteudo: TipoConteudoModerado
    let conteudoID: UUID?
    let nomeConteudo: String?
    let motivo: String

    var titulo: String {
        "Remoção pela moderação"
    }

    var mensagem: String {
        let item = nomeConteudo.map { "\(tipoConteudo.descricao.capitalized) “\($0)”" }
            ?? tipoConteudo.descricao.capitalized
        return "\(item) foi removido pela moderação.\n\nMotivo: \(motivo)\n\nSe desejar solicitar uma revisão, entre em contato com \(Notificacoes.emailSuporte)."
    }
}
