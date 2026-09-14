//
//  Foto.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

enum DestinoFoto: Codable, Equatable, Sendable {
    case spot(UUID)
    case perfil(UUID)
}

enum StatusModeracaoFoto: String, Codable, CaseIterable, Sendable {
    case pendente, aprovada, rejeitada
}

struct Foto: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let enviadaPorID: UUID
    let destino: DestinoFoto
    var textoAlternativo: String?
    let criadaEm: Date
}

struct ModeracaoFoto: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var status: StatusModeracaoFoto = .pendente
    var motivo: String?
    var analisadaEm: Date?
}
