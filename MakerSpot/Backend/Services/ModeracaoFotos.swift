//
//  ModeracaoFotos.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import SensitiveContentAnalysis

enum ResultadoTriagemFoto: Equatable, Sendable {
    case bloqueadaPorConteudoSensivel
    case conteudoSensivelNaoDetectado
    case analiseNaoHabilitadaNoSistema
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
            // `disabled` significa que o recurso opcional "Aviso de Conteúdo
            // Sensível" não está habilitado nos Ajustes do dispositivo. Isso
            // não é uma reprovação da imagem e não deve bloquear o cadastro.
            return .analiseNaoHabilitadaNoSistema
        }

        do {
            let analise = try await analisador.analyzeImage(at: arquivoURL)
            return analise.isSensitive
                ? .bloqueadaPorConteudoSensivel
                : .conteudoSensivelNaoDetectado
        } catch {
            throw ErroModeracaoFotos.falhaNaAnalise(descricao: error.localizedDescription)
        }
    }
}
