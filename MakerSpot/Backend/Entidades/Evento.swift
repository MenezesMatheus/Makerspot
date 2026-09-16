//
//  Evento.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

struct Evento: Codable, Equatable, Sendable {
    var inicio: Date
    var termino: Date
    var fusoHorarioID: String
}
