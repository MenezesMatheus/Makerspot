//
//  ClienteCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

struct FalhaRegistroCloudKit: Sendable {
    let identificador: CKRecord.ID
    let erro: ErroCloudKit
}

struct ResultadoRegistrosCloudKit: Sendable {
    let registros: [CKRecord]
    let falhas: [FalhaRegistroCloudKit]
}

struct CursorRegistrosCloudKit: Sendable {
    fileprivate let valor: CKQueryOperation.Cursor
    fileprivate let tipoRegistro: TipoRegistroCloudKit
}

struct PaginaRegistrosCloudKit: Sendable {
    let registros: [CKRecord]
    let falhas: [FalhaRegistroCloudKit]
    let proximoCursor: CursorRegistrosCloudKit?
}

final class ClienteCloudKit {
    private let configuracao: ConfiguracaoCloudKit
    private let limiteItensPorLote = 200

    init(configuracao: ConfiguracaoCloudKit = ConfiguracaoCloudKit()) {
        self.configuracao = configuracao
    }

    func verificarConta() async throws -> CKRecord.ID {
        try await configuracao.verificarConta()
    }

    func salvar(_ registro: CKRecord) async throws -> CKRecord {
        let tipo = try tipoRegistro(do: registro)

        do {
            return try await configuracao.banco(para: tipo).save(registro)
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }

    func buscar(
        _ identificador: CKRecord.ID,
        tipo: TipoRegistroCloudKit
    ) async throws -> CKRecord {
        do {
            let registro = try await configuracao
                .banco(para: tipo)
                .record(for: identificador)
            guard registro.recordType == tipo.rawValue else {
                throw ErroCloudKit.tipoRegistroIncompativel(
                    esperado: tipo.rawValue,
                    recebido: registro.recordType
                )
            }
            return registro
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }

    func buscar(
        _ identificadores: [CKRecord.ID],
        tipo: TipoRegistroCloudKit,
        campos: [CKRecord.FieldKey]? = nil
    ) async throws -> ResultadoRegistrosCloudKit {
        guard !identificadores.isEmpty else {
            return ResultadoRegistrosCloudKit(registros: [], falhas: [])
        }
        guard Set(identificadores).count == identificadores.count else {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "A busca em lote não aceita identificadores duplicados."
            )
        }
        return try await buscarLote(
            identificadores,
            tipo: tipo,
            campos: campos
        )
    }

    func excluir(
        _ identificador: CKRecord.ID,
        tipo: TipoRegistroCloudKit
    ) async throws {
        do {
            _ = try await configuracao
                .banco(para: tipo)
                .deleteRecord(withID: identificador)
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }

    func consultarPrimeiraPagina(
        tipo: TipoRegistroCloudKit,
        predicado: NSPredicate = NSPredicate(format: "TRUEPREDICATE"),
        ordenacao: [NSSortDescriptor] = [],
        campos: [CKRecord.FieldKey]? = nil,
        limite: Int = CKQueryOperation.maximumResults
    ) async throws -> PaginaRegistrosCloudKit {
        let limiteValido = try validarLimite(limite)

        do {
            let consulta = CKQuery(recordType: tipo.rawValue, predicate: predicado)
            consulta.sortDescriptors = ordenacao
            let resultados = try await configuracao.banco(para: tipo).records(
                matching: consulta,
                desiredKeys: campos,
                resultsLimit: limiteValido
            )

            let resultado = organizar(resultados.matchResults, tipo: tipo)
            return PaginaRegistrosCloudKit(
                registros: resultado.registros,
                falhas: resultado.falhas,
                proximoCursor: resultados.queryCursor.map {
                    CursorRegistrosCloudKit(valor: $0, tipoRegistro: tipo)
                }
            )
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }

    func continuarConsulta(
        _ cursor: CursorRegistrosCloudKit,
        campos: [CKRecord.FieldKey]? = nil,
        limite: Int = CKQueryOperation.maximumResults
    ) async throws -> PaginaRegistrosCloudKit {
        let limiteValido = try validarLimite(limite)
        let tipo = cursor.tipoRegistro

        do {
            let resultados = try await configuracao.banco(para: tipo).records(
                continuingMatchFrom: cursor.valor,
                desiredKeys: campos,
                resultsLimit: limiteValido
            )
            let resultado = organizar(resultados.matchResults, tipo: tipo)
            return PaginaRegistrosCloudKit(
                registros: resultado.registros,
                falhas: resultado.falhas,
                proximoCursor: resultados.queryCursor.map {
                    CursorRegistrosCloudKit(valor: $0, tipoRegistro: tipo)
                }
            )
        } catch {
            throw ErroCloudKit.converter(error)
        }
    }

    func consultarTodos(
        tipo: TipoRegistroCloudKit,
        predicado: NSPredicate = NSPredicate(format: "TRUEPREDICATE"),
        ordenacao: [NSSortDescriptor] = [],
        campos: [CKRecord.FieldKey]? = nil
    ) async throws -> ResultadoRegistrosCloudKit {
        var registros: [CKRecord] = []
        var falhas: [FalhaRegistroCloudKit] = []
        var pagina = try await consultarPrimeiraPagina(
            tipo: tipo,
            predicado: predicado,
            ordenacao: ordenacao,
            campos: campos
        )

        while true {
            registros.append(contentsOf: pagina.registros)
            falhas.append(contentsOf: pagina.falhas)

            guard let cursor = pagina.proximoCursor else { break }
            pagina = try await continuarConsulta(cursor, campos: campos)
        }

        return ResultadoRegistrosCloudKit(registros: registros, falhas: falhas)
    }

    private func validarLimite(_ limite: Int) throws -> Int {
        guard limite == CKQueryOperation.maximumResults || limite > 0 else {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "O limite de resultados do CloudKit deve ser maior que zero."
            )
        }
        return limite
    }

    private func buscarLote(
        _ identificadores: [CKRecord.ID],
        tipo: TipoRegistroCloudKit,
        campos: [CKRecord.FieldKey]?
    ) async throws -> ResultadoRegistrosCloudKit {
        if identificadores.count > limiteItensPorLote {
            var registros: [CKRecord] = []
            var falhas: [FalhaRegistroCloudKit] = []
            for lote in identificadores.emLotes(de: limiteItensPorLote) {
                let resultado = try await buscarLote(lote, tipo: tipo, campos: campos)
                registros.append(contentsOf: resultado.registros)
                falhas.append(contentsOf: resultado.falhas)
            }
            return ResultadoRegistrosCloudKit(registros: registros, falhas: falhas)
        }

        do {
            let resultados = try await configuracao
                .banco(para: tipo)
                .records(for: identificadores, desiredKeys: campos)
            let ordenados = identificadores.map { identificador in
                (
                    identificador,
                    resultados[identificador]
                        ?? .failure(ErroCloudKit.respostaInconsistente)
                )
            }
            return organizar(ordenados, tipo: tipo)
        } catch {
            let erro = ErroCloudKit.converter(error)
            guard case .limiteExcedido = erro, identificadores.count > 1 else {
                throw erro
            }

            let metade = identificadores.count / 2
            let primeiraParte = try await buscarLote(
                Array(identificadores[..<metade]),
                tipo: tipo,
                campos: campos
            )
            let segundaParte = try await buscarLote(
                Array(identificadores[metade...]),
                tipo: tipo,
                campos: campos
            )
            return ResultadoRegistrosCloudKit(
                registros: primeiraParte.registros + segundaParte.registros,
                falhas: primeiraParte.falhas + segundaParte.falhas
            )
        }
    }

    private func organizar(
        _ resultados: [(CKRecord.ID, Result<CKRecord, Error>)],
        tipo: TipoRegistroCloudKit
    ) -> ResultadoRegistrosCloudKit {
        var registros: [CKRecord] = []
        var falhas: [FalhaRegistroCloudKit] = []
        for (identificador, resultado) in resultados {
            do {
                let registro = try resultado.get()
                guard registro.recordType == tipo.rawValue else {
                    throw ErroCloudKit.tipoRegistroIncompativel(
                        esperado: tipo.rawValue,
                        recebido: registro.recordType
                    )
                }
                registros.append(registro)
            } catch {
                falhas.append(FalhaRegistroCloudKit(
                    identificador: identificador,
                    erro: .converter(error)
                ))
            }
        }
        return ResultadoRegistrosCloudKit(registros: registros, falhas: falhas)
    }

    private func tipoRegistro(do registro: CKRecord) throws -> TipoRegistroCloudKit {
        guard let tipo = TipoRegistroCloudKit(rawValue: registro.recordType) else {
            throw ErroCloudKit.tipoRegistroIncompativel(
                esperado: "um tipo de registro do MakerSpot",
                recebido: registro.recordType
            )
        }
        return tipo
    }
}

extension Array {
    func emLotes(de tamanho: Int) -> [[Element]] {
        stride(from: 0, to: count, by: tamanho).map { inicio in
            Array(self[inicio..<Swift.min(inicio + tamanho, count)])
        }
    }
}
