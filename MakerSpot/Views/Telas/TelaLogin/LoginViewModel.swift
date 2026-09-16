//
//  LoginViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import AuthenticationServices
import Observation

@MainActor
@Observable
final class LoginViewModel {
    private(set) var estaCarregando = false
    private(set) var estaRestaurandoSessao = false
    private(set) var mensagemDeErro: String?

    private let autenticacaoApple: AutenticacaoApple
    private let crud: UsuarioCRUD

    init(
        autenticacaoApple: AutenticacaoApple,
        crud: UsuarioCRUD
    ) {
        self.autenticacaoApple = autenticacaoApple
        self.crud = crud
    }

    convenience init(sessao: SessaoUsuario) {
        let autenticacaoApple = AutenticacaoApple()
        self.init(
            autenticacaoApple: autenticacaoApple,
            crud: UsuarioCRUD(
                sessao: sessao,
                autenticacaoApple: autenticacaoApple
            )
        )
    }

    func configurar(_ requisicao: ASAuthorizationAppleIDRequest) {
        autenticacaoApple.configurar(requisicao)
    }

    @discardableResult
    func entrar(com autorizacao: ASAuthorization) async -> Bool {
        guard !estaCarregando else { return false }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            let dadosApple = try autenticacaoApple.obterDados(de: autorizacao)
            _ = try await crud.entrar(com: dadosApple)
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restaurarSessao() async -> Bool {
        guard !estaRestaurandoSessao else { return false }
        estaRestaurandoSessao = true
        mensagemDeErro = nil
        defer { estaRestaurandoSessao = false }

        do {
            return try await crud.restaurarSessao() != nil
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func registrarFalhaDaApple(_ erro: Error) {
        mensagemDeErro = erro.localizedDescription
    }

    func limparErro() {
        mensagemDeErro = nil
    }
}
