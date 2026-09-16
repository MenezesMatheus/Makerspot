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
    private(set) var estaSalvando = false
    private(set) var estaAlterandoFoto = false
    private(set) var mensagemDeErro: String?

    var nome = ""
    var sobrenome = ""
    var telefonePadrao = ""

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
            let usuario = try await usuarioCRUD.buscarUsuarioAtual()
            aplicar(usuario)
            fotoPerfil = try await fotoCRUD.buscarFotoPerfilAtual()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func salvarPerfil() async -> Bool {
        guard !estaSalvando else { return false }
        estaSalvando = true
        mensagemDeErro = nil
        defer { estaSalvando = false }

        do {
            let atualizado = try await usuarioCRUD.atualizarPerfil(
                DadosPerfilUsuario(
                    nome: nome,
                    sobrenome: sobrenome,
                    telefonePadrao: telefonePadrao
                )
            )
            aplicar(atualizado)
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func definirFotoPerfil(arquivoURL: URL) async {
        guard !estaAlterandoFoto else { return }
        estaAlterandoFoto = true
        mensagemDeErro = nil
        defer { estaAlterandoFoto = false }

        do {
            fotoPerfil = try await fotoCRUD.definirFotoPerfil(arquivoURL: arquivoURL)
            aplicar(try await usuarioCRUD.buscarUsuarioAtual())
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
            aplicar(try await usuarioCRUD.buscarUsuarioAtual())
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

    private func aplicar(_ usuario: Usuario) {
        self.usuario = usuario
        nome = usuario.nome ?? ""
        sobrenome = usuario.sobrenome ?? ""
        telefonePadrao = usuario.telefonePadrao ?? ""
    }
}
