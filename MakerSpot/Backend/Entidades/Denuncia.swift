//
//  Denuncia.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//


import Foundation

enum StatusDenuncia: String, Codable, CaseIterable, Sendable {
    case pendente, emAnalise, procedente, improcedente
}

struct Denuncia: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let spotID: UUID
    let texto: String
    let criadaEm: Date
}

struct AnaliseDenuncia: Identifiable, Codable, Equatable, Sendable {
    let denunciaID: UUID
    var status: StatusDenuncia = .pendente
    var observacao: String?
    var analisadaEm: Date?

    var id: UUID { denunciaID }
}

struct BanimentoUsuario: Identifiable, Codable, Equatable, Sendable {
    let contaHash: String
    let banidoEm: Date

    var id: String { contaHash }
}
