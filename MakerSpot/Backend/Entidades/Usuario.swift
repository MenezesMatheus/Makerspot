//
//  Usuario.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

struct Usuario: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let appleUserID: String
    let cloudKitUserRecordName: String
    var nome: String?
    var sobrenome: String?
    var fotoID: UUID?
    var telefonePadrao: String?
    let criadoEm: Date
    var atualizadoEm: Date

    // O cadastro inicial mantém as datas iguais; salvar o perfil atualiza atualizadoEm.
    // Use os dados persistidos, pois a Apple não reenvia o nome em todo login.
    var precisaCompletarPerfil: Bool {
        atualizadoEm <= criadoEm
    }
}
