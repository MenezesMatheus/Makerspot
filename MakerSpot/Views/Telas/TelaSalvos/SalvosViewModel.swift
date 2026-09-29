//
//  SalvosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class SalvosViewModel {
    @ObservationIgnored private var alteracoes: AlteracoesSpots?
    @ObservationIgnored private var observacaoAlteracoes: AnyCancellable?
    let fotosSpots: FotosSpotsViewModel
    private(set) var itens: [ItemSpotSalvo] = []
    private(set) var estaCarregando = false
    private(set) var spotEmAlteracao: UUID?
    private(set) var mensagemDeErro: String?
    private(set) var estadoNotificacoes: EstadoPermissaoNotificacoes = .naoSolicitada
    private(set) var agora = Date()

    var espacosSalvos: [ItemSpotSalvo] {
        itens.filter { $0.spot.tipo == .espaco && $0.spot.estaDisponivel(em: agora) }
    }

    var eventosSalvos: [ItemSpotSalvo] {
        itens.filter { $0.spot.tipo == .evento && $0.spot.estaDisponivel(em: agora) }
    }

    private let crud: SalvosCRUD
    private let notificacoes: Notificacoes

    init(
        crud: SalvosCRUD,
        notificacoes: Notificacoes,
        fotosSpots: FotosSpotsViewModel
    ) {
        self.crud = crud
        self.notificacoes = notificacoes
        self.fotosSpots = fotosSpots
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            crud: SalvosCRUD(sessao: sessao),
            notificacoes: Notificacoes(),
            fotosSpots: FotosSpotsViewModel(sessao: sessao)
        )
        alteracoes = sessao.alteracoesSpots
        observacaoAlteracoes = sessao.alteracoesSpots.atualizacoes.sink { [weak self] in
            self?.aplicarAlteracoes()
        }
        aplicarAlteracoes()
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
            itens = try await crud.listarComSpots()
            estadoNotificacoes = await notificacoes.verificarPermissao()
            if estadoNotificacoes == .autorizada
                || estadoNotificacoes == .provisoria {
                notificacoes.registrarParaNotificacoesRemotas()
            }
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func dessalvar(spotID: UUID) async {
        guard spotEmAlteracao == nil,
              let indice = itens.firstIndex(where: { $0.spot.id == spotID }) else {
            return
        }
        let itemRemovido = itens.remove(at: indice)
        spotEmAlteracao = spotID
        mensagemDeErro = nil
        defer { spotEmAlteracao = nil }

        do {
            try await crud.dessalvar(spotID: spotID)
            fotosSpots.removerSpot(spotID)
        } catch is CancellationError {
            itens.insert(itemRemovido, at: min(indice, itens.count))
            return
        } catch {
            itens.insert(itemRemovido, at: min(indice, itens.count))
            mensagemDeErro = error.localizedDescription
        }
    }

    func marcarComoVisualizado(spotID: UUID) async {
        do {
            let registro = try await crud.marcarComoVisualizado(spotID: spotID)
            guard let indice = itens.firstIndex(where: { $0.spot.id == spotID }) else {
                return
            }
            itens[indice] = ItemSpotSalvo(
                registro: registro,
                spot: itens[indice].spot
            )
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func processarNotificacao(_ dados: [AnyHashable: Any]) async {
        do {
            switch try await crud.processarNotificacao(dados) {
            case .ignorada:
                return
            case .atualizado(let spot):
                if let indice = itens.firstIndex(where: { $0.spot.id == spot.id }) {
                    itens[indice] = ItemSpotSalvo(
                        registro: itens[indice].registro,
                        spot: spot
                    )
                } else {
                    await carregar()
                }
            case .removido(let spotID):
                itens.removeAll { $0.spot.id == spotID }
                fotosSpots.removerSpot(spotID)
            }
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func atualizarDisponibilidade() {
        agora = Date()
    }

    private func aplicarAlteracoes() {
        guard let alteracoes else { return }
        itens = alteracoes.consolidarItensSalvos(itens)
            .filter { $0.spot.id != spotEmAlteracao }
    }
}
