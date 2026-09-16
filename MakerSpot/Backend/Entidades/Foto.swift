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

struct Foto: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let enviadaPorID: UUID
    let destino: DestinoFoto
    var textoAlternativo: String?
    let criadaEm: Date
}
