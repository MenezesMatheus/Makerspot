//
//  PerfilViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PerfilViewModel {
    private(set) var usuario: Usuario?
    private(set) var fotoPerfil: FotoDisponivel?
    private(set) var estaCarregando = false
    private(set) var estaAlterandoFoto = false
    private(set) var mensagemDeErro: String?

    private let usuarioCRUD: UsuarioCRUD
    private let fotoCRUD: FotoCRUD

    init(usuarioCRUD: UsuarioCRUD, fotoCRUD: FotoCRUD) {
        self.usuarioCRUD = usuarioCRUD
        self.fotoCRUD = fotoCRUD
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            usuarioCRUD: UsuarioCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao)
        )
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            usuario = try await usuarioCRUD.buscarUsuarioAtual()
            fotoPerfil = try await fotoCRUD.buscarFotoPerfilAtual()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func definirFotoPerfil(arquivoURL: URL) async {
        guard !estaAlterandoFoto else { return }
        estaAlterandoFoto = true
        mensagemDeErro = nil
        defer { estaAlterandoFoto = false }

        do {
            fotoPerfil = try await fotoCRUD.definirFotoPerfil(arquivoURL: arquivoURL)
            usuario = try await usuarioCRUD.buscarUsuarioAtual()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func removerFotoPerfil() async {
        guard !estaAlterandoFoto else { return }
        estaAlterandoFoto = true
        mensagemDeErro = nil
        defer { estaAlterandoFoto = false }

        do {
            try await fotoCRUD.removerFotoPerfil()
            fotoPerfil = nil
            usuario = try await usuarioCRUD.buscarUsuarioAtual()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func sair() -> Bool {
        mensagemDeErro = nil
        do {
            try usuarioCRUD.encerrarSessao()
            usuario = nil
            fotoPerfil = nil
            return true
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func aplicarAtualizacao(_ usuario: Usuario) {
        self.usuario = usuario
    }
}
