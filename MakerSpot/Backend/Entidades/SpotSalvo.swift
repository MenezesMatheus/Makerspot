//
//  SpotSalvo.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

struct SpotSalvo: Identifiable, Codable, Equatable, Sendable {
    let usuarioID: UUID
    let spotID: UUID
    let salvoEm: Date
    var ultimaVersaoConhecida: Int

    var id: String {
        "salvo_\(usuarioID.uuidString.lowercased())_\(spotID.uuidString.lowercased())"
    }
}
