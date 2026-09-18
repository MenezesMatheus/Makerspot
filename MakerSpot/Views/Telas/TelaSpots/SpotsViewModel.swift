//
//  SpotsViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SpotsViewModel {
    private(set) var spots: [Spot] = []
    private(set) var identificadoresSalvos: Set<UUID> = []
    private(set) var estaCarregando = false
    private(set) var estaSincronizandoSalvos = false
    private(set) var spotsEmAlteracao: Set<UUID> = []
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0
    private(set) var tipoSelecionado: TipoSpot?

    private let crud: SpotCRUD
    private let salvosCRUD: SalvosCRUD
    private let usuarioAtualID: () -> UUID?
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    @ObservationIgnored private var carregouPrimeiraPagina = false

    init(
        crud: SpotCRUD,
        salvosCRUD: SalvosCRUD,
        usuarioAtualID: @escaping () -> UUID?,
        tamanhoDaPagina: Int = 30
    ) {
        self.crud = crud
        self.salvosCRUD = salvosCRUD
        self.usuarioAtualID = usuarioAtualID
        self.tamanhoDaPagina = max(1, tamanhoDaPagina)
    }

    convenience init(
        sessao: SessaoUsuario,
        tamanhoDaPagina: Int = 30
    ) {
        self.init(
            crud: SpotCRUD(sessao: sessao),
            salvosCRUD: SalvosCRUD(sessao: sessao),
            usuarioAtualID: { [weak sessao] in sessao?.usuarioAtual?.id },
            tamanhoDaPagina: tamanhoDaPagina
        )
    }

    func carregarPrimeiraPagina(tipo: TipoSpot? = nil) async {
        guard !estaCarregando else { return }
        redefinirPaginacao(tipo: tipo)
        await carregarProximaPagina()
        await sincronizarSalvos()
    }

    func recarregar() async {
        await carregarPrimeiraPagina(tipo: tipoSelecionado)
    }

    func carregarProximaPagina() async {
        guard !estaCarregando, podeCarregarMais else { return }

        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            let quantidadeAntes = spots.count
            var paginasPercorridas = 0

            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: tipoSelecionado,
                    limite: tamanhoDaPagina,
                    continuando: cursor
                )

                for spot in pagina.spots
                where identificadoresCarregados.insert(spot.id).inserted {
                    spots.append(spot)
                }
                quantidadeRegistrosIgnorados += pagina.quantidadeRegistrosIgnorados
                cursor = pagina.proximoCursor
                paginasPercorridas += 1
            } while spots.count == quantidadeAntes
                && cursor != nil
                && paginasPercorridas < 3

            carregouPrimeiraPagina = true
            podeCarregarMais = cursor != nil
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
            podeCarregarMais = !carregouPrimeiraPagina || cursor != nil
        }
    }

    func limpar() {
        redefinirPaginacao(tipo: nil)
        identificadoresSalvos = []
        spotsEmAlteracao = []
        podeCarregarMais = false
    }

    func estaSalvo(_ spot: Spot) -> Bool {
        identificadoresSalvos.contains(spot.id)
    }

    func estaAlterandoSalvo(_ spot: Spot) -> Bool {
        estaSincronizandoSalvos || spotsEmAlteracao.contains(spot.id)
    }

    func podeSalvar(_ spot: Spot) -> Bool {
        guard let usuarioID = usuarioAtualID() else { return false }
        return spot.proprietarioID != usuarioID
    }

    func alternarSalvo(do spot: Spot) async {
        guard spots.contains(where: { $0.id == spot.id }),
              podeSalvar(spot),
              !estaSincronizandoSalvos,
              spotsEmAlteracao.insert(spot.id).inserted else {
            return
        }

        mensagemDeErro = nil
        defer { spotsEmAlteracao.remove(spot.id) }

        do {
            if identificadoresSalvos.contains(spot.id) {
                try await salvosCRUD.dessalvar(spotID: spot.id)
                identificadoresSalvos.remove(spot.id)
            } else {
                _ = try await salvosCRUD.salvar(spotID: spot.id)
                identificadoresSalvos.insert(spot.id)
            }
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    private func sincronizarSalvos() async {
        guard !estaSincronizandoSalvos else { return }
        estaSincronizandoSalvos = true
        defer { estaSincronizandoSalvos = false }

        do {
            identificadoresSalvos = Set(
                try await salvosCRUD.listar().map(\.spotID)
            )
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    private func redefinirPaginacao(tipo: TipoSpot?) {
        spots = []
        cursor = nil
        identificadoresCarregados = []
        quantidadeRegistrosIgnorados = 0
        mensagemDeErro = nil
        tipoSelecionado = tipo
        carregouPrimeiraPagina = false
        podeCarregarMais = true
    }
}
