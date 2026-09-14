//
//  Localizacao.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

struct Localizacao: Codable, Equatable, Sendable {
    var endereco: Endereco
    var coordenadas: Coordenadas
}

struct Endereco: Codable, Equatable, Sendable {
    var logradouro: String
    var numero: String
    var complemento: String?
    var bairro: String?
    var cidade: String
    var estado: String
    var codigoPostal: String?
    var codigoPais: String
}

struct Coordenadas: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
}

struct RedeSocial: Codable, Equatable, Sendable {
    var nome: String
    var url: URL
}
