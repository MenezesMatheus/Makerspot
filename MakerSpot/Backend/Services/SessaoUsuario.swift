//
//  SessaoUsuario.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation
import Security

enum ErroSessaoUsuario: LocalizedError {
    case falhaAoSalvarIdentificador
    case falhaAoLerIdentificador
    case falhaAoRemoverIdentificador

    var errorDescription: String? {
        switch self {
        case .falhaAoSalvarIdentificador:
            return "Não foi possível guardar a sessão com segurança."
        case .falhaAoLerIdentificador:
            return "Não foi possível recuperar a sessão salva."
        case .falhaAoRemoverIdentificador:
            return "Não foi possível encerrar a sessão salva."
        }
    }
}

@Observable
final class SessaoUsuario {
    private(set) var usuarioAtual: Usuario?

    var estaAutenticado: Bool {
        usuarioAtual != nil
    }

    func iniciar(com usuario: Usuario) throws {
        try ChaveiroSessao.salvar(usuario.appleUserID)
        usuarioAtual = usuario
    }

    func restaurar(_ usuario: Usuario) {
        usuarioAtual = usuario
    }

    func identificadorAppleSalvo() throws -> String? {
        try ChaveiroSessao.ler()
    }

    func encerrar() throws {
        try ChaveiroSessao.remover()
        usuarioAtual = nil
    }
}

private enum ChaveiroSessao {
    private static let conta = "usuarioApple"
    private static var servico: String {
        Bundle.main.bundleIdentifier ?? "MakerSpot"
    }

    static func salvar(_ identificador: String) throws {
        let dados = Data(identificador.utf8)
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: servico,
            kSecAttrAccount: conta
        ]

        SecItemDelete(consulta as CFDictionary)

        var novoItem = consulta
        novoItem[kSecValueData] = dados
        novoItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        guard SecItemAdd(novoItem as CFDictionary, nil) == errSecSuccess else {
            throw ErroSessaoUsuario.falhaAoSalvarIdentificador
        }
    }

    static func ler() throws -> String? {
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: servico,
            kSecAttrAccount: conta,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var resultado: CFTypeRef?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let dados = resultado as? Data,
              let identificador = String(data: dados, encoding: .utf8) else {
            throw ErroSessaoUsuario.falhaAoLerIdentificador
        }
        return identificador
    }

    static func remover() throws {
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: servico,
            kSecAttrAccount: conta
        ]

        let status = SecItemDelete(consulta as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ErroSessaoUsuario.falhaAoRemoverIdentificador
        }
    }
}
