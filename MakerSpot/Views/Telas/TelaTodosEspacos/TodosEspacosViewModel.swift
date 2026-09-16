//
//  TodosEspacosViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 16/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class TodosEspacosViewModel {
    private(set) var espacos: [Spot] = []
    private(set) var estaCarregando = false
    private(set) var podeCarregarMais = true
    private(set) var mensagemDeErro: String?
    private(set) var quantidadeRegistrosIgnorados = 0

    private let crud: SpotCRUD
    private let tamanhoDaPagina: Int
    @ObservationIgnored private var cursor: CursorPaginaSpots?
    @ObservationIgnored private var identificadoresCarregados: Set<UUID> = []
    @ObservationIgnored private var carregouPrimeiraPagina = false

    init(crud: SpotCRUD, tamanhoDaPagina: Int = 30) {
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

    func carregarPrimeiraPagina() async {
        guard !estaCarregando else { return }
        redefinirPaginacao()
        await carregarProximaPagina()
    }

    func recarregar() async {
        await carregarPrimeiraPagina()
    }

    func carregarProximaPagina() async {
        guard !estaCarregando, podeCarregarMais else { return }

        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        do {
            let quantidadeAntes = espacos.count
            var paginasPercorridas = 0

            repeat {
                let pagina = try await crud.listarAtivos(
                    tipo: .espaco,
                    limite: tamanhoDaPagina,
                    continuando: cursor
                )

                for espaco in pagina.spots
                where identificadoresCarregados.insert(espaco.id).inserted {
                    espacos.append(espaco)
                }
                quantidadeRegistrosIgnorados += pagina.quantidadeRegistrosIgnorados
                cursor = pagina.proximoCursor
                paginasPercorridas += 1
            } while espacos.count == quantidadeAntes
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
        redefinirPaginacao()
        podeCarregarMais = false
    }

    private func redefinirPaginacao() {
        espacos = []
        cursor = nil
        identificadoresCarregados = []
        quantidadeRegistrosIgnorados = 0
        mensagemDeErro = nil
        carregouPrimeiraPagina = false
        podeCarregarMais = true
    }
}
