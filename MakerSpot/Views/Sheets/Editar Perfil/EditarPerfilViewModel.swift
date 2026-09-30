//
//  EditarPerfilViewModel.swift
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
final class EditarPerfilViewModel {
    var nome: String
    var sobrenome: String
    var telefonePadrao: String
    private(set) var novaFotoDados: Data?
    private(set) var removerFotoAtual = false

    private(set) var usuario: Usuario
    private(set) var fotoPerfil: FotoDisponivel?
    private(set) var estaCarregando = false
    private(set) var estaSalvando = false
    private(set) var estaVerificandoFoto = false
    private(set) var estaExcluindoConta = false
    private(set) var mensagemDeErro: String?

    private let crud: UsuarioCRUD
    private let fotoCRUD: FotoCRUD

    var fotoFoiAlterada: Bool {
        novaFotoDados != nil || removerFotoAtual
    }

    var telefoneFoiAlterado: Bool {
        textoOpcional(telefonePadrao) != usuario.telefonePadrao
    }

    var temAlteracoes: Bool {
        textoOpcional(nome) != usuario.nome
            || textoOpcional(sobrenome) != usuario.sobrenome
            || telefoneFoiAlterado
            || fotoFoiAlterada
    }

    var descricaoAlteracoesParaConfirmacao: String? {
        guard temAlteracoes else { return nil }
        let acaoFoto = removerFotoAtual
            ? "removeu sua foto de perfil"
            : "alterou sua foto de perfil"

        switch (fotoFoiAlterada, telefoneFoiAlterado) {
        case (true, true):
            return "Você \(acaoFoto) e alterou seu número de telefone."
        case (true, false):
            return "Você \(acaoFoto)."
        case (false, true):
            return "Você alterou seu número de telefone."
        case (false, false):
            return "Você alterou os dados do seu perfil."
        }
    }

    var podeSalvar: Bool {
        !textoNormalizado(nome).isEmpty
            && !textoNormalizado(sobrenome).isEmpty
            && !estaCarregando
            && !estaSalvando
            && !estaVerificandoFoto
            && !estaExcluindoConta
    }

    init(
        usuario: Usuario,
        crud: UsuarioCRUD,
        fotoCRUD: FotoCRUD
    ) {
        self.usuario = usuario
        nome = usuario.nome ?? ""
        sobrenome = usuario.sobrenome ?? ""
        telefonePadrao = usuario.telefonePadrao ?? ""
        self.crud = crud
        self.fotoCRUD = fotoCRUD
    }

    convenience init(usuario: Usuario, sessao: SessaoUsuario) {
        self.init(
            usuario: usuario,
            crud: UsuarioCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao)
        )
    }

    func carregarFoto() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            fotoPerfil = try await fotoCRUD.buscarFotoPerfilAtual()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func selecionarFoto(_ item: PhotosPickerItem) async {
        guard !estaVerificandoFoto, !estaSalvando, !estaExcluindoConta else { return }
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
    func salvar() async -> Usuario? {
        guard !estaSalvando else { return nil }
        guard podeSalvar else {
            mensagemDeErro = mensagemDeValidacao
            return nil
        }
        guard temAlteracoes else { return usuario }

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

    @discardableResult
    func sair() -> Bool {
        mensagemDeErro = nil
        do {
            try crud.encerrarSessao()
            return true
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func excluirConta() async -> Bool {
        guard !estaExcluindoConta else { return false }
        estaExcluindoConta = true
        mensagemDeErro = nil
        defer { estaExcluindoConta = false }

        do {
            try await crud.excluirConta()
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func descartarAlteracoes() {
        novaFotoDados = nil
        removerFotoAtual = false
        aplicar(usuario)
        mensagemDeErro = nil
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

    private func textoOpcional(_ valor: String) -> String? {
        let texto = textoNormalizado(valor)
        return texto.isEmpty ? nil : texto
    }

}
