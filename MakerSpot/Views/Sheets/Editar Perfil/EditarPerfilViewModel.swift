//
//  EditarPerfilViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class EditarPerfilViewModel {
    var nome: String
    var sobrenome: String
    var telefonePadrao: String

    private(set) var usuario: Usuario
    private(set) var estaSalvando = false
    private(set) var mensagemDeErro: String?

    private let crud: UsuarioCRUD

    var temAlteracoes: Bool {
        textoNormalizado(nome) != usuario.nome
            || textoNormalizado(sobrenome) != usuario.sobrenome
            || textoNormalizado(telefonePadrao) != usuario.telefonePadrao
    }

    init(usuario: Usuario, crud: UsuarioCRUD) {
        self.usuario = usuario
        nome = usuario.nome ?? ""
        sobrenome = usuario.sobrenome ?? ""
        telefonePadrao = usuario.telefonePadrao ?? ""
        self.crud = crud
    }

    convenience init(usuario: Usuario, sessao: SessaoUsuario) {
        self.init(
            usuario: usuario,
            crud: UsuarioCRUD(sessao: sessao)
        )
    }

    @discardableResult
    func salvar() async -> Usuario? {
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

    func descartarAlteracoes() {
        aplicar(usuario)
        mensagemDeErro = nil
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

    private func textoNormalizado(_ valor: String) -> String? {
        let texto = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        return texto.isEmpty ? nil : texto
    }
}
