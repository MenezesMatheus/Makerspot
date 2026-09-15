//
//  Spot.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

enum TipoSpot: String, Codable, CaseIterable, Sendable {
    case evento, espaco
}

enum DetalhesSpot: Codable, Equatable, Sendable {
    case evento(Evento)
    case espaco(Espaco)
}

struct Spot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let proprietarioID: UUID
    var nomePublicador: String
    var nome: String
    var descricao: String
    var localizacao: Localizacao
    var telefone: String
    var link: URL?
    var redesSociais: [RedeSocial] = []
    var fotoIDs: [UUID] = []
    var detalhes: DetalhesSpot
    var estaAtivo: Bool = true
    var versao: Int = 1
    let criadoEm: Date
    var atualizadoEm: Date

    var tipo: TipoSpot {
        switch detalhes {
        case .evento: return .evento
        case .espaco: return .espaco
        }
    }
}
