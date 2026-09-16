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
    private(set) var estaCarregando = false
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0
    private(set) var tipoSelecionado: TipoSpot?

    private let crud: SpotCRUD
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    @ObservationIgnored private var carregouPrimeiraPagina = false

    init(
        crud: SpotCRUD,
        tamanhoDaPagina: Int = 30
    ) {
        self.crud = crud
        self.tamanhoDaPagina = max(1, tamanhoDaPagina)
    }

    convenience init(
        sessao: SessaoUsuario,
        tamanhoDaPagina: Int = 30
    ) {
        self.init(
            crud: SpotCRUD(sessao: sessao),
            tamanhoDaPagina: tamanhoDaPagina
        )
    }

    func carregarPrimeiraPagina(tipo: TipoSpot? = nil) async {
        guard !estaCarregando else { return }
        redefinirPaginacao(tipo: tipo)
        await carregarProximaPagina()
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
        podeCarregarMais = false
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
