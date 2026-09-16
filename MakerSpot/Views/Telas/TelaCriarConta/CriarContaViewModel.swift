//
//  CriarContaViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CriarContaViewModel {
    var nome: String
    var sobrenome: String
    var telefonePadrao: String

    private(set) var usuario: Usuario?
    private(set) var estaCarregando = false
    private(set) var estaSalvando = false
    private(set) var mensagemDeErro: String?

    private let crud: UsuarioCRUD

    init(usuarioInicial: Usuario? = nil, crud: UsuarioCRUD) {
        usuario = usuarioInicial
        nome = usuarioInicial?.nome ?? ""
        sobrenome = usuarioInicial?.sobrenome ?? ""
        telefonePadrao = usuarioInicial?.telefonePadrao ?? ""
        self.crud = crud
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            usuarioInicial: sessao.usuarioAtual,
            crud: UsuarioCRUD(sessao: sessao)
        )
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            aplicar(try await crud.buscarUsuarioAtual())
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func concluirCadastro() async -> Usuario? {
        guard !estaSalvando else { return nil }
        estaSalvando = true
        mensagemDeErro = nil
        defer { estaSalvando = false }

        do {
            let atualizado = try await crud.atualizarPerfil(
                DadosPerfilUsuario(
                    nome: nome,
                    sobrenome: sobrenome,
                    telefonePadrao: telefonePadrao
                )
            )
            aplicar(atualizado)
            return atualizado
        } catch is CancellationError {
            return nil
        } catch {
            mensagemDeErro = error.localizedDescription
            return nil
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
