//
//  PerfilViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Combine
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class PerfilViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    let fotosSpots: FotosSpotsViewModel
    private(set) var usuario: Usuario?
    private(set) var fotoPerfil: FotoDisponivel?
    private(set) var eventos: [Spot] = []
    private(set) var espacos: [Spot] = []
    private(set) var estaCarregando = false
    private(set) var estaAlterandoFoto = false
    private(set) var estaExcluindoConta = false
    private(set) var spotEmAlteracao: UUID?
    private(set) var mensagemDeErro: String?
    private(set) var avisoAtivacao: AvisoAtivacaoSpot?

    private let usuarioCRUD: UsuarioCRUD
    private let fotoCRUD: FotoCRUD
    private let spotCRUD: SpotCRUD

    init(
        usuarioCRUD: UsuarioCRUD,
        fotoCRUD: FotoCRUD,
        spotCRUD: SpotCRUD,
        fotosSpots: FotosSpotsViewModel
    ) {
        self.usuarioCRUD = usuarioCRUD
        self.fotoCRUD = fotoCRUD
        self.spotCRUD = spotCRUD
        self.fotosSpots = fotosSpots
    }

    convenience init(sessao: SessaoUsuario) {
        let fotoCRUD = FotoCRUD(sessao: sessao)
        self.init(
            usuarioCRUD: UsuarioCRUD(sessao: sessao),
            fotoCRUD: fotoCRUD,
            spotCRUD: SpotCRUD(sessao: sessao),
            fotosSpots: FotosSpotsViewModel(fotoCRUD: fotoCRUD, sessao: sessao)
        )
        usuario = sessao.usuarioAtual
        alteracoes = sessao.alteracoesSpots
        observacaoAlteracoes = sessao.alteracoesSpots.atualizacoes.sink { [weak self] in
            self?.aplicarAlteracoes()
        }
        aplicarAlteracoes()
    }

    func criarEditorPerfil() -> EditarPerfilViewModel? {
        guard let usuario else { return nil }
        return EditarPerfilViewModel(
            usuario: usuario,
            crud: usuarioCRUD,
            fotoCRUD: fotoCRUD
        )
    }

    func carregar() async {
        guard !estaCarregando else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer {
            estaCarregando = false
            aplicarAlteracoes()
        }

        do {
            async let usuarioAtual = usuarioCRUD.buscarUsuarioAtual()
            async let fotoAtual = fotoCRUD.buscarFotoPerfilAtual()
            async let spotsAtuais = spotCRUD.listarDoUsuarioAtual()
            let (usuarioCarregado, fotoCarregada, spots) = try await (
                usuarioAtual, fotoAtual, spotsAtuais
            )
            usuario = usuarioCarregado
            fotoPerfil = fotoCarregada
            eventos = spots.filter { $0.tipo == .evento }
            espacos = spots.filter { $0.tipo == .espaco }
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func selecionarFoto(_ item: PhotosPickerItem) async {
        guard !estaAlterandoFoto else { return }
        estaAlterandoFoto = true
        mensagemDeErro = nil
        defer { estaAlterandoFoto = false }

        do {
            guard let dados = try await item.loadTransferable(type: Data.self), !dados.isEmpty else {
                throw ErroCRUD.dadosInvalidos(descricao: "Não foi possível ler a foto selecionada.")
            }
            try await ModeracaoFotos().validarParaAnexar(dados)
            try Task.checkCancellation()
            let arquivoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("imagem")
            defer { try? FileManager.default.removeItem(at: arquivoURL) }
            try dados.write(to: arquivoURL, options: .atomic)
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

    func definirAtivo(_ estaAtivo: Bool, para spot: Spot) async {
        guard spotEmAlteracao == nil,
              eventos.contains(where: { $0.id == spot.id })
                || espacos.contains(where: { $0.id == spot.id }) else {
            return
        }

        spotEmAlteracao = spot.id
        mensagemDeErro = nil
        avisoAtivacao = nil
        defer { spotEmAlteracao = nil }

        if estaAtivo && spot.eventoEncerrado() {
            do {
                let restrito = try await spotCRUD.estaRestritoPelaModeracao(spot.id)
                avisoAtivacao = restrito
                    ? .restrito(nomeSpot: spot.nome)
                    : .eventoEncerrado
            } catch ErroCloudKit.operacaoCancelada {
                return
            } catch is CancellationError {
                return
            } catch {
                mensagemDeErro = error.localizedDescription
            }
            return
        }

        guard spot.estaAtivo != estaAtivo else { return }

        var otimista = spot
        otimista.estaAtivo = estaAtivo
        substituir(otimista)

        do {
            let atualizado = try await spotCRUD.definirAtivo(
                estaAtivo,
                para: spot.id
            )
            substituir(atualizado)
        } catch ErroCloudKit.operacaoCancelada {
            substituir(spot)
            return
        } catch is CancellationError {
            substituir(spot)
            return
        } catch ErroCRUD.spotRestrito {
            substituir(spot)
            avisoAtivacao = .restrito(nomeSpot: spot.nome)
        } catch {
            substituir(spot)
            mensagemDeErro = error.localizedDescription
        }
    }

    @discardableResult
    func excluirSpot(_ spot: Spot) async -> Bool {
        guard spotEmAlteracao == nil else { return false }
        spotEmAlteracao = spot.id
        mensagemDeErro = nil
        defer { spotEmAlteracao = nil }

        do {
            try await spotCRUD.excluir(id: spot.id)
            eventos.removeAll { $0.id == spot.id }
            espacos.removeAll { $0.id == spot.id }
            fotosSpots.removerSpot(spot.id)
            return true
        } catch ErroCloudKit.operacaoCancelada {
            return false
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func sair() -> Bool {
        mensagemDeErro = nil
        do {
            try usuarioCRUD.encerrarSessao()
            limparPerfil()
            return true
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func excluirConta() async {
        guard !estaExcluindoConta else { return }
        estaExcluindoConta = true
        mensagemDeErro = nil
        defer { estaExcluindoConta = false }

        do {
            try await usuarioCRUD.excluirConta()
            limparPerfil()
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparPerfil() {
        usuario = nil
        fotoPerfil = nil
        eventos = []
        espacos = []
        fotosSpots.limpar()
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func limparAvisoAtivacao() {
        avisoAtivacao = nil
    }

    private func aplicarAlteracoes() {
        guard let alteracoes, let usuarioID = usuario?.id else { return }
        let pendente = (eventos + espacos).first { $0.id == spotEmAlteracao }
        eventos = alteracoes.consolidar(eventos) {
            $0.tipo == .evento && $0.proprietarioID == usuarioID
        }
        espacos = alteracoes.consolidar(espacos) {
            $0.tipo == .espaco && $0.proprietarioID == usuarioID
        }
        if let pendente, !alteracoes.excluidos.contains(pendente.id) {
            substituir(pendente)
        }
    }

    func aplicarAtualizacao(_ usuario: Usuario) {
        self.usuario = usuario
    }

    func aplicarAtualizacao(_ spot: Spot) {
        substituir(spot)
    }

    private func substituir(_ spot: Spot) {
        switch spot.tipo {
        case .evento:
            guard let indice = eventos.firstIndex(where: { $0.id == spot.id }) else {
                return
            }
            eventos[indice] = spot
        case .espaco:
            guard let indice = espacos.firstIndex(where: { $0.id == spot.id }) else {
                return
            }
            espacos[indice] = spot
        }
    }
}
