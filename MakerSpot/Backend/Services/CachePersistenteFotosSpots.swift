import Foundation

@MainActor
final class CachePersistenteFotosSpots {
    enum Tipo: String {
        case capa
        case detalhes
    }

    private struct FotoPersistida: Codable {
        let foto: Foto
        let extensao: String
    }

    private struct Entrada: Codable {
        let ids: [UUID]
        let fotos: [FotoPersistida]
        let expiraEm: Date
    }

    private let gerenciadorArquivos: FileManager
    private let diretorioRaiz: URL?

    init(gerenciadorArquivos: FileManager = .default, diretorioRaiz: URL? = nil) {
        self.gerenciadorArquivos = gerenciadorArquivos
        self.diretorioRaiz = diretorioRaiz
    }

    func carregar(
        para spot: Spot,
        usuarioID: UUID,
        tipo: Tipo,
        agora: Date = Date()
    ) -> (fotos: [FotoDisponivel], expiraEm: Date)? {
        guard let url = urlMetadados(spotID: spot.id, usuarioID: usuarioID, tipo: tipo),
              let dados = try? Data(contentsOf: url) else { return nil }
        guard let entrada = try? JSONDecoder().decode(Entrada.self, from: dados) else {
            try? gerenciadorArquivos.removeItem(at: url)
            return nil
        }

        let idsEsperados = ids(para: spot, tipo: tipo)
        guard entrada.expiraEm > agora,
              entrada.ids == idsEsperados,
              entrada.fotos.map(\.foto.id) == idsEsperados,
              let diretorioFotos = diretorioFotos() else {
            try? gerenciadorArquivos.removeItem(at: url)
            return nil
        }

        var fotos: [FotoDisponivel] = []
        for persistida in entrada.fotos {
            guard case .spot(let destinoID) = persistida.foto.destino,
                  destinoID == spot.id,
                  extensaoValida(persistida.extensao) else {
                try? gerenciadorArquivos.removeItem(at: url)
                return nil
            }
            let arquivo = diretorioFotos
                .appendingPathComponent(persistida.foto.id.uuidString.lowercased())
                .appendingPathExtension(persistida.extensao)
            guard gerenciadorArquivos.fileExists(atPath: arquivo.path) else {
                try? gerenciadorArquivos.removeItem(at: url)
                return nil
            }
            fotos.append(FotoDisponivel(foto: persistida.foto, arquivoURL: arquivo))
        }
        return (fotos, entrada.expiraEm)
    }

    func guardar(
        _ fotos: [FotoDisponivel],
        para spot: Spot,
        usuarioID: UUID,
        tipo: Tipo,
        expiraEm: Date
    ) {
        let idsEsperados = ids(para: spot, tipo: tipo)
        guard fotos.map(\.foto.id) == idsEsperados,
              let diretorioFotos = diretorioFotos(),
              let url = urlMetadados(spotID: spot.id, usuarioID: usuarioID, tipo: tipo) else {
            return
        }

        var persistidas: [FotoPersistida] = []
        for disponivel in fotos {
            let extensao = disponivel.arquivoURL.pathExtension.lowercased()
            let arquivoEsperado = diretorioFotos
                .appendingPathComponent(disponivel.foto.id.uuidString.lowercased())
                .appendingPathExtension(extensao)
            guard case .spot(let destinoID) = disponivel.foto.destino,
                  destinoID == spot.id,
                  extensaoValida(extensao),
                  disponivel.arquivoURL.standardizedFileURL == arquivoEsperado.standardizedFileURL,
                  gerenciadorArquivos.fileExists(atPath: arquivoEsperado.path) else {
                return
            }
            persistidas.append(FotoPersistida(foto: disponivel.foto, extensao: extensao))
        }

        let entrada = Entrada(ids: idsEsperados, fotos: persistidas, expiraEm: expiraEm)
        guard let dados = try? JSONEncoder().encode(entrada) else { return }
        do {
            try gerenciadorArquivos.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try dados.write(to: url, options: .atomic)
        } catch {
            // A falha no disco não impede o cache em memória nem a foto remota.
        }
    }

    func remover(spotID: UUID, usuarioID: UUID) {
        for tipo in [Tipo.capa, .detalhes] {
            guard let url = urlMetadados(spotID: spotID, usuarioID: usuarioID, tipo: tipo) else {
                continue
            }
            try? gerenciadorArquivos.removeItem(at: url)
        }
    }

    func removerConta(_ usuarioID: UUID?) {
        guard let usuarioID,
              let diretorio = diretorioMetadados(usuarioID: usuarioID) else { return }
        try? gerenciadorArquivos.removeItem(at: diretorio)
    }

    private func ids(para spot: Spot, tipo: Tipo) -> [UUID] {
        switch tipo {
        case .capa: return Array(spot.fotoIDs.prefix(1))
        case .detalhes: return spot.fotoIDs
        }
    }

    private func extensaoValida(_ extensao: String) -> Bool {
        !extensao.isEmpty && extensao.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    private func diretorioFotos() -> URL? {
        if let diretorioRaiz { return diretorioRaiz }
        return gerenciadorArquivos.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("FotosMakerSpot", isDirectory: true)
    }

    private func diretorioMetadados(usuarioID: UUID) -> URL? {
        diretorioFotos()?
            .appendingPathComponent("Metadados", isDirectory: true)
            .appendingPathComponent(usuarioID.uuidString.lowercased(), isDirectory: true)
    }

    private func urlMetadados(spotID: UUID, usuarioID: UUID, tipo: Tipo) -> URL? {
        diretorioMetadados(usuarioID: usuarioID)?
            .appendingPathComponent("\(tipo.rawValue)-\(spotID.uuidString.lowercased())")
            .appendingPathExtension("json")
    }
}
