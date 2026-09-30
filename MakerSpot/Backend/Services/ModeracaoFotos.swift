//
//  ModeracaoFotos.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import CryptoKit
import ImageIO
import SensitiveContentAnalysis

enum ResultadoTriagemFoto: Equatable, Sendable {
    case bloqueadaPorConteudoSensivel
    case conteudoSensivelNaoDetectado
    case analiseNaoHabilitadaNoSistema
}

enum ErroModeracaoFotos: LocalizedError {
    case arquivoNaoEncontrado
    case analiseDesativada
    case falhaNaAnalise(descricao: String)

    var errorDescription: String? {
        switch self {
        case .arquivoNaoEncontrado:
            return "A foto selecionada não foi encontrada."
        case .analiseDesativada:
            return "A foto não foi adicionada porque a análise de conteúdo sensível está indisponível. Confira Aviso de Conteúdo Sensível em Ajustes > Privacidade e Segurança e permita a análise para o MakerSpot."
        case .falhaNaAnalise(let descricao):
            return descricao
        }
    }
}

@MainActor
final class ModeracaoFotos {
    private let analisador = SCSensitivityAnalyzer()
    // Aprovações transitórias por conteúdo, sem reter fotos. O upload pode
    // reconhecer a mesma imagem já verificada durante a anexação.
    private static var aprovacoes: [SHA256.Digest: Date] = [:]
    private static let validadeAprovacao: TimeInterval = 15 * 60
    private static let limiteAprovacoes = 64

    /// Somente retorna depois da aprovação. Não mantém a imagem em cache.
    func validarParaAnexar(_ dados: Data) async throws {
        guard !dados.isEmpty, dados.count <= 30 * 1_024 * 1_024 else {
            throw ErroCRUD.dadosInvalidos(descricao: "Cada foto deve ter até 30 MB.")
        }
        let arquivo = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("imagem")
        defer { try? FileManager.default.removeItem(at: arquivo) }
        try dados.write(to: arquivo, options: .atomic)
        try await validarParaAnexar(em: arquivo)
    }

    func validarParaAnexar(em arquivoURL: URL) async throws {
        try Task.checkCancellation()
        switch try await analisarImagem(em: arquivoURL) {
        case .bloqueadaPorConteudoSensivel:
            throw ErroCRUD.conteudoFotoNaoPermitido
        case .analiseNaoHabilitadaNoSistema:
            throw ErroModeracaoFotos.analiseDesativada
        case .conteudoSensivelNaoDetectado:
            try Task.checkCancellation()
        }
    }

    func analisarImagem(em arquivoURL: URL) async throws -> ResultadoTriagemFoto {
        guard FileManager.default.fileExists(atPath: arquivoURL.path) else {
            throw ErroModeracaoFotos.arquivoNaoEncontrado
        }

        guard let tamanho = try arquivoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              tamanho > 0, tamanho <= 30 * 1_024 * 1_024,
              let fonte = CGImageSourceCreateWithURL(arquivoURL as CFURL, nil),
              let propriedades = CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil) as? [CFString: Any],
              let largura = propriedades[kCGImagePropertyPixelWidth] as? NSNumber,
              let altura = propriedades[kCGImagePropertyPixelHeight] as? NSNumber,
              (1...20_000).contains(largura.intValue),
              (1...20_000).contains(altura.intValue) else {
            throw ErroCRUD.dadosInvalidos(descricao: "Selecione uma imagem válida de até 30 MB e 20.000 pixels.")
        }

        guard analisador.analysisPolicy != .disabled else {
            return .analiseNaoHabilitadaNoSistema
        }

        try Task.checkCancellation()
        let agora = Date()
        Self.aprovacoes = Self.aprovacoes.filter { agora.timeIntervalSince($0.value) < Self.validadeAprovacao }
        let resumo = SHA256.hash(data: try Data(contentsOf: arquivoURL, options: .mappedIfSafe))
        if Self.aprovacoes[resumo] != nil {
            return .conteudoSensivelNaoDetectado
        }

        do {
            let analise = try await analisador.analyzeImage(at: arquivoURL)
            try Task.checkCancellation()
            guard analisador.analysisPolicy != .disabled else {
                return .analiseNaoHabilitadaNoSistema
            }
            if #available(iOS 27.0, *), !analise.detectedTypes.isEmpty {
                return .bloqueadaPorConteudoSensivel
            }
            guard !analise.isSensitive else { return .bloqueadaPorConteudoSensivel }
            if Self.aprovacoes.count >= Self.limiteAprovacoes,
               let maisAntiga = Self.aprovacoes.min(by: { $0.value < $1.value })?.key {
                Self.aprovacoes.removeValue(forKey: maisAntiga)
            }
            Self.aprovacoes[resumo] = Date()
            return .conteudoSensivelNaoDetectado
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ErroModeracaoFotos.falhaNaAnalise(
                descricao: "Não foi possível verificar a segurança da foto. Ela não foi adicionada. Tente novamente."
            )
        }
    }
}
