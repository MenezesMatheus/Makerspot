//
//  ModeracaoFotos.swift .swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import SensitiveContentAnalysis

enum ResultadoTriagemFoto: Equatable, Sendable {
    case bloqueadaPorConteudoSensivel
    case encaminharParaModeracao
}

enum ErroModeracaoFotos: LocalizedError {
    case arquivoNaoEncontrado
    case falhaNaAnalise(descricao: String)

    var errorDescription: String? {
        switch self {
        case .arquivoNaoEncontrado:
            return "A foto selecionada não foi encontrada."
        case .falhaNaAnalise(let descricao):
            return descricao
        }
    }
}

final class ModeracaoFotos {
    private let analisador = SCSensitivityAnalyzer()

    func analisarImagem(em arquivoURL: URL) async throws -> ResultadoTriagemFoto {
        guard FileManager.default.fileExists(atPath: arquivoURL.path) else {
            throw ErroModeracaoFotos.arquivoNaoEncontrado
        }

        guard analisador.analysisPolicy != .disabled else {
            return .encaminharParaModeracao
        }

        do {
            let analise = try await analisador.analyzeImage(at: arquivoURL)
            return analise.isSensitive
                ? .bloqueadaPorConteudoSensivel
                : .encaminharParaModeracao
        } catch {
            throw ErroModeracaoFotos.falhaNaAnalise(descricao: error.localizedDescription)
        }
    }
}
