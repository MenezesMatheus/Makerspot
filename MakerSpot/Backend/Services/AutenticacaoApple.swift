//
//  AutenticacaoApple.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import AuthenticationServices
import Foundation

struct DadosAutenticacaoApple: Equatable, Sendable {
    let identificadorUsuario: String
    let nome: String?
    let sobrenome: String?
}

enum EstadoCredencialApple: Equatable, Sendable {
    case autorizada
    case revogada
    case naoEncontrada
    case transferida
}

enum ErroAutenticacaoApple: LocalizedError {
    case credencialInvalida
    case estadoDesconhecido
    case falha(descricao: String)

    var errorDescription: String? {
        switch self {
        case .credencialInvalida:
            return "Não foi possível obter uma credencial válida da Apple."
        case .estadoDesconhecido:
            return "Não foi possível determinar o estado da credencial Apple."
        case .falha(let descricao):
            return descricao
        }
    }
}

final class AutenticacaoApple {
    private let provedor = ASAuthorizationAppleIDProvider()

    func configurar(_ requisicao: ASAuthorizationAppleIDRequest) {
        requisicao.requestedScopes = [.fullName]
    }
    
    func obterDados(de autorizacao: ASAuthorization) throws -> DadosAutenticacaoApple {
        guard let credencial = autorizacao.credential as? ASAuthorizationAppleIDCredential else {
            throw ErroAutenticacaoApple.credencialInvalida
        }

        return DadosAutenticacaoApple(
            identificadorUsuario: credencial.user,
            nome: textoNormalizado(credencial.fullName?.givenName),
            sobrenome: textoNormalizado(credencial.fullName?.familyName)
        )
    }

    func verificarEstado(identificadorUsuario: String) async throws -> EstadoCredencialApple {
        do {
            let estado = try await provedor.credentialState(forUserID: identificadorUsuario)
            switch estado {
            case .authorized:
                return .autorizada
            case .revoked:
                return .revogada
            case .notFound:
                return .naoEncontrada
            case .transferred:
                return .transferida
            @unknown default:
                throw ErroAutenticacaoApple.estadoDesconhecido
            }
        } catch let erro as ErroAutenticacaoApple {
            throw erro
        } catch {
            throw ErroAutenticacaoApple.falha(descricao: error.localizedDescription)
        }
    }

    private func textoNormalizado(_ texto: String?) -> String? {
        guard let texto else { return nil }
        let resultado = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return resultado.isEmpty ? nil : resultado
    }
}
