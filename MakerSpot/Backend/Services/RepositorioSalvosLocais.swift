import Foundation
import CryptoKit
import SwiftData

@Model
final class RegistroSalvoLocal {
    var usuarioID: String = ""
    var spotID: String = ""
    var dispositivoID: String = ""
    var conteudo: Data?

    init(usuarioID: UUID, spotID: UUID, dispositivoID: String, conteudo: Data) {
        self.usuarioID = usuarioID.uuidString
        self.spotID = spotID.uuidString
        self.dispositivoID = dispositivoID
        self.conteudo = conteudo
    }
}

struct EstadoSalvoLocal: Codable, Equatable {
    var registro: SpotSalvo
    var spot: Spot?
    var estaSalvo: Bool
    var alteradoEm: Date
    var operacaoID: UUID

    func precede(_ outro: Self) -> Bool {
        if alteradoEm != outro.alteradoEm { return alteradoEm < outro.alteradoEm }
        return operacaoID.uuidString < outro.operacaoID.uuidString
    }
}

@MainActor
final class RepositorioSalvosLocais {
    let container: ModelContainer
    private let dispositivoID: String

    init(container: ModelContainer, dispositivoID: String) {
        self.container = container
        self.dispositivoID = dispositivoID
    }

    static func abrir(contaCloudKit: String, dispositivoID: String) throws -> RepositorioSalvosLocais {
        let diretorio = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("SalvosSwiftData", isDirectory: true)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        let conta = SHA256.hash(data: Data(contaCloudKit.utf8)).map { String(format: "%02x", $0) }.joined()
        let configuracao = ModelConfiguration(
            "SalvosMakerSpot",
            url: diretorio.appendingPathComponent("\(conta).store"),
            cloudKitDatabase: .private("iCloud.br.ufpe.cin.mmcm2.MakerSpot")
        )
        let container = try ModelContainer(for: RegistroSalvoLocal.self, configurations: configuracao)
        return RepositorioSalvosLocais(container: container, dispositivoID: dispositivoID)
    }

    func estados(usuarioID: UUID) throws -> [UUID: EstadoSalvoLocal] {
        let contexto = novoContexto()
        return try consolidar(buscar(usuarioID: usuarioID, no: contexto))
    }

    func excluirDados(usuarioID: UUID) throws {
        let contexto = novoContexto()
        for linha in try buscar(usuarioID: usuarioID, no: contexto) { contexto.delete(linha) }
        try contexto.save()
    }

    func estado(spotID: UUID, usuarioID: UUID) throws -> EstadoSalvoLocal? {
        let contexto = novoContexto()
        return try consolidar(buscar(usuarioID: usuarioID, spotID: spotID, no: contexto))[spotID]
    }

    @discardableResult
    func definir(
        _ salvo: Bool, spotID: UUID, spot: Spot?, usuarioID: UUID, agora: Date = Date()
    ) throws -> EstadoSalvoLocal {
        let contexto = novoContexto()
        let linhas = try buscar(usuarioID: usuarioID, spotID: spotID, no: contexto)
        let anterior = try consolidar(linhas)[spotID]
        let data = max(agora, anterior?.alteradoEm.addingTimeInterval(0.001) ?? agora)
        let estado = EstadoSalvoLocal(
            registro: SpotSalvo(
                usuarioID: usuarioID, spotID: spotID,
                salvoEm: anterior.flatMap { $0.estaSalvo ? $0.registro.salvoEm : nil } ?? agora,
                ultimaVersaoConhecida: max(anterior?.registro.ultimaVersaoConhecida ?? 0, spot?.versao ?? 0)
            ),
            spot: salvo ? (spot ?? anterior?.spot) : nil,
            estaSalvo: salvo, alteradoEm: data, operacaoID: UUID()
        )
        try gravar(estado, linhas: linhas, no: contexto)
        try contexto.save()
        return estado
    }

    func importar(_ legados: [SpotSalvo], usuarioID: UUID) throws {
        let contexto = novoContexto()
        let existentes = try consolidar(buscar(usuarioID: usuarioID, no: contexto))
        for legado in legados where legado.usuarioID == usuarioID && existentes[legado.spotID] == nil {
            let estado = EstadoSalvoLocal(
                registro: legado, spot: nil, estaSalvo: true,
                alteradoEm: .distantPast, operacaoID: legado.spotID
            )
            contexto.insert(RegistroSalvoLocal(
                usuarioID: usuarioID, spotID: legado.spotID, dispositivoID: "legado",
                conteudo: try JSONEncoder().encode(estado)
            ))
        }
        try contexto.save()
    }

    func atualizarSpots(_ spots: [Spot], usuarioID: UUID) throws {
        let contexto = novoContexto()
        for spot in spots {
            let linhas = try buscar(usuarioID: usuarioID, spotID: spot.id, no: contexto)
            guard var estado = try consolidar(linhas)[spot.id],
                  estado.estaSalvo,
                  estado.spot != spot,
                  (estado.spot?.versao ?? 0) <= spot.versao else { continue }
            estado.spot = spot
            // Atualizar conteúdo não é uma nova intenção de salvar/dessalvar.
            try gravar(estado, linhas: linhas, no: contexto)
        }
        try contexto.save()
    }

    func marcarComoVisualizado(spotID: UUID, usuarioID: UUID) throws -> SpotSalvo? {
        let contexto = novoContexto()
        let linhas = try buscar(usuarioID: usuarioID, spotID: spotID, no: contexto)
        guard var estado = try consolidar(linhas)[spotID], estado.estaSalvo else { return nil }
        estado.registro.ultimaVersaoConhecida = max(
            estado.registro.ultimaVersaoConhecida, estado.spot?.versao ?? 0
        )
        try gravar(estado, linhas: linhas, no: contexto)
        try contexto.save()
        return estado.registro
    }

    private func novoContexto() -> ModelContext {
        // Um contexto curto também enxerga importações do CloudKit já concluídas.
        let contexto = ModelContext(container)
        contexto.autosaveEnabled = false
        return contexto
    }

    private func buscar(usuarioID: UUID, spotID: UUID? = nil, no contexto: ModelContext) throws -> [RegistroSalvoLocal] {
        let usuario = usuarioID.uuidString
        if let spotID {
            let spot = spotID.uuidString
            return try contexto.fetch(FetchDescriptor<RegistroSalvoLocal>(predicate: #Predicate {
                $0.usuarioID == usuario && $0.spotID == spot
            }))
        }
        return try contexto.fetch(FetchDescriptor<RegistroSalvoLocal>(predicate: #Predicate {
            $0.usuarioID == usuario
        }))
    }

    private func consolidar(_ linhas: [RegistroSalvoLocal]) throws -> [UUID: EstadoSalvoLocal] {
        var estados: [UUID: EstadoSalvoLocal] = [:]
        var snapshots: [UUID: Spot] = [:]
        var versoesLidas: [UUID: Int] = [:]
        for linha in linhas {
            guard let dados = linha.conteudo else { continue }
            let estado = try JSONDecoder().decode(EstadoSalvoLocal.self, from: dados)
            let id = estado.registro.spotID
            if estados[id].map({ $0.precede(estado) }) ?? true { estados[id] = estado }
            versoesLidas[id] = max(versoesLidas[id] ?? 0, estado.registro.ultimaVersaoConhecida)
            if let spot = estado.spot {
                if let anterior = snapshots[id] {
                    if snapshot(anterior, precede: spot) { snapshots[id] = spot }
                } else {
                    snapshots[id] = spot
                }
            }
        }

        for id in Array(estados.keys) {
            guard var estado = estados[id] else { continue }
            estado.spot = estado.estaSalvo ? snapshots[id] : nil
            estado.registro.ultimaVersaoConhecida = versoesLidas[id] ?? 0
            estados[id] = estado
        }
        return estados
    }

    private func snapshot(_ primeiro: Spot, precede segundo: Spot) -> Bool {
        if primeiro.versao != segundo.versao { return primeiro.versao < segundo.versao }
        if primeiro.estaAtivo != segundo.estaAtivo { return primeiro.estaAtivo }
        return primeiro.atualizadoEm < segundo.atualizadoEm
    }

    private func gravar(_ estado: EstadoSalvoLocal, linhas: [RegistroSalvoLocal], no contexto: ModelContext) throws {
        let dados = try JSONEncoder().encode(estado)
        let locais = linhas.filter { $0.dispositivoID == dispositivoID }
        if let linha = locais.first {
            linha.conteudo = dados
            for duplicada in locais.dropFirst() { contexto.delete(duplicada) }
        } else {
            contexto.insert(RegistroSalvoLocal(
                usuarioID: estado.registro.usuarioID, spotID: estado.registro.spotID,
                dispositivoID: dispositivoID, conteudo: dados
            ))
        }
    }
}
