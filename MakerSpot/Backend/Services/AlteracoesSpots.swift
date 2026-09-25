import Combine
import Foundation
import Observation


@MainActor
@Observable
final class AlteracoesSpots {
    @ObservationIgnored private let emissor = PassthroughSubject<Void, Never>()
    var atualizacoes: AnyPublisher<Void, Never> { emissor.eraseToAnyPublisher() }
    private(set) var spots: [UUID: Spot] = [:]
    private(set) var excluidos: Set<UUID> = []
    private(set) var salvos: [UUID: ItemSpotSalvo] = [:]
    private(set) var removidosDosSalvos: Set<UUID> = []
    var exclusaoConfirmada: UUID?

    func atualizar(_ spot: Spot) {
        guard !excluidos.contains(spot.id),
              spots[spot.id].map({ $0.versao <= spot.versao }) ?? true else { return }
        spots[spot.id] = spot
        if let item = salvos[spot.id] {
            salvos[spot.id] = ItemSpotSalvo(registro: item.registro, spot: spot)
        }
        emissor.send()
    }

    func excluir(_ id: UUID) {
        spots[id] = nil
        excluidos.insert(id)
        salvos[id] = nil
        removidosDosSalvos.insert(id)
        exclusaoConfirmada = id
        emissor.send()
    }

    func salvar(_ salvo: SpotSalvo, spot: Spot) {
        guard !excluidos.contains(spot.id) else { return }
        salvos[spot.id] = ItemSpotSalvo(registro: salvo, spot: spot)
        removidosDosSalvos.remove(spot.id)
        emissor.send()
    }

    func dessalvar(_ id: UUID) {
        salvos[id] = nil
        removidosDosSalvos.insert(id)
        emissor.send()
    }

    func marcarComoVisualizado(_ salvo: SpotSalvo, spot: Spot) {
        // Uma leitura iniciada antes de dessalvar não pode restaurar o favorito.
        guard !removidosDosSalvos.contains(spot.id) else { return }
        salvar(salvo, spot: spot)
    }

    func consolidar(_ lista: [Spot], incluindo: (Spot) -> Bool) -> [Spot] {
        let unicos = Dictionary(lista.map { ($0.id, $0) }, uniquingKeysWith: {
            $0.versao > $1.versao ? $0 : $1
        })
        var resultado = unicos.values.filter { !excluidos.contains($0.id) }
        for spot in spots.values {
            if let indice = resultado.firstIndex(where: { $0.id == spot.id }) {
                if resultado[indice].versao <= spot.versao { resultado[indice] = spot }
            } else if incluindo(spot) {
                resultado.append(spot)
            }
        }
        return resultado.filter(incluindo).sorted {
            if $0.atualizadoEm != $1.atualizadoEm { return $0.atualizadoEm > $1.atualizadoEm }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func consolidarSalvos(_ ids: Set<UUID>) -> Set<UUID> {
        ids.union(salvos.keys).subtracting(removidosDosSalvos).subtracting(excluidos)
    }

    func consolidarItensSalvos(_ itens: [ItemSpotSalvo]) -> [ItemSpotSalvo] {
        var porID = Dictionary(itens.map { ($0.spot.id, $0) }, uniquingKeysWith: { _, novo in novo })
        for (id, item) in salvos { porID[id] = item }
        for id in removidosDosSalvos.union(excluidos) { porID[id] = nil }
        return porID.values.map { item in
            guard let atualizado = spots[item.spot.id], atualizado.versao >= item.spot.versao else {
                return item
            }
            return ItemSpotSalvo(registro: item.registro, spot: atualizado)
        }.sorted { $0.registro.salvoEm > $1.registro.salvoEm }
    }

    func limpar() {
        spots = [:]
        excluidos = []
        salvos = [:]
        removidosDosSalvos = []
        exclusaoConfirmada = nil
    }
}
