//
//  Espaco.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation

enum DiaSemana: String, Codable, CaseIterable, Sendable {
    case segunda, terca, quarta, quinta, sexta, sabado, domingo
}

struct Espaco: Codable, Equatable, Sendable {
    var funcionamento: FuncionamentoSemanal
}

struct FuncionamentoSemanal: Codable, Equatable, Sendable {
    var fusoHorarioID: String
    var dias: [FuncionamentoDia]
}

struct FuncionamentoDia: Codable, Equatable, Sendable {
    var dia: DiaSemana
    var intervalos: [IntervaloFuncionamento]
}

struct HorarioLocal: Codable, Equatable, Sendable {
    var hora: Int
    var minuto: Int
}

struct IntervaloFuncionamento: Codable, Equatable, Sendable {
    var abertura: HorarioLocal
    var fechamento: HorarioLocal
    var terminaNoDiaSeguinte: Bool = false
}
