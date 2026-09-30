//
//  CriarContaViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class CriarContaViewModel {
    var nome: String
    var sobrenome: String
    var telefonePadrao: String
    private(set) var novaFotoDados: Data?
    private(set) var removerFotoAtual = false

    private(set) var usuario: Usuario?
    private(set) var fotoPerfil: FotoDisponivel?
    private(set) var estaCarregando = false
    private(set) var estaSalvando = false
    private(set) var estaVerificandoFoto = false
    private(set) var mensagemDeErro: String?

    private let crud: UsuarioCRUD
    private let fotoCRUD: FotoCRUD

    var podeConcluir: Bool {
        !textoNormalizado(nome).isEmpty
            && !textoNormalizado(sobrenome).isEmpty
            && !estaCarregando
            && !estaSalvando
            && !estaVerificandoFoto
    }

    init(
        usuarioInicial: Usuario? = nil,
        crud: UsuarioCRUD,
        fotoCRUD: FotoCRUD
    ) {
        usuario = usuarioInicial
        nome = usuarioInicial?.nome ?? ""
        sobrenome = usuarioInicial?.sobrenome ?? ""
        telefonePadrao = usuarioInicial?.telefonePadrao ?? ""
        self.crud = crud
        self.fotoCRUD = fotoCRUD
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            usuarioInicial: sessao.usuarioAtual,
            crud: UsuarioCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao)
        )
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            let usuario = try await crud.buscarUsuarioAtual()
            fotoPerfil = try await fotoCRUD.buscarFotoPerfilAtual()
            aplicar(usuario)
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func selecionarFoto(_ item: PhotosPickerItem) async {
        guard !estaVerificandoFoto, !estaSalvando else { return }
        estaVerificandoFoto = true
        mensagemDeErro = nil
        defer { estaVerificandoFoto = false }

        do {
            guard let dados = try await item.loadTransferable(type: Data.self), !dados.isEmpty else {
                throw ErroCRUD.dadosInvalidos(descricao: "Não foi possível ler a foto selecionada.")
            }
            try await ModeracaoFotos().validarParaAnexar(dados)
            try Task.checkCancellation()
            novaFotoDados = dados
            removerFotoAtual = false
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func removerFoto() {
        guard !estaVerificandoFoto, !estaSalvando else { return }
        if novaFotoDados != nil {
            novaFotoDados = nil
        } else if fotoPerfil != nil {
            removerFotoAtual = true
        }
    }

    @discardableResult
    func concluirCadastro() async -> Usuario? {
        guard !estaSalvando else { return nil }
        guard podeConcluir else {
            mensagemDeErro = mensagemDeValidacao
            return nil
        }

        estaSalvando = true
        mensagemDeErro = nil
        defer { estaSalvando = false }

        do {
            var atualizado = try await crud.atualizarPerfil(
                DadosPerfilUsuario(
                    nome: nome,
                    sobrenome: sobrenome,
                    telefonePadrao: telefonePadrao
                )
            )

            if let novaFotoDados {
                fotoPerfil = try await enviarFoto(novaFotoDados)
                self.novaFotoDados = nil
                atualizado = try await crud.buscarUsuarioAtual()
            } else if removerFotoAtual {
                try await fotoCRUD.removerFotoPerfil()
                fotoPerfil = nil
                removerFotoAtual = false
                atualizado = try await crud.buscarUsuarioAtual()
            }

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

    private var mensagemDeValidacao: String {
        if textoNormalizado(nome).isEmpty {
            return "Informe seu nome."
        }
        if textoNormalizado(sobrenome).isEmpty {
            return "Informe seu sobrenome."
        }
        return "Revise os dados do perfil."
    }

    private func aplicar(_ usuario: Usuario) {
        self.usuario = usuario
        nome = usuario.nome ?? ""
        sobrenome = usuario.sobrenome ?? ""
        telefonePadrao = usuario.telefonePadrao ?? ""
    }

    private func enviarFoto(_ dados: Data) async throws -> FotoDisponivel {
        let arquivo = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("imagem")
        try dados.write(to: arquivo, options: .atomic)
        defer { try? FileManager.default.removeItem(at: arquivo) }
        return try await fotoCRUD.definirFotoPerfil(arquivoURL: arquivo)
    }

    private func textoNormalizado(_ valor: String) -> String {
        valor.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
