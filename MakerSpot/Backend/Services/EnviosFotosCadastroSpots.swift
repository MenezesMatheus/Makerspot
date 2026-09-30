import Foundation
import Observation

@MainActor
@Observable
final class EnviosFotosCadastroSpots {
    private struct FotoPendente: Codable {
        let id: UUID
        let nomeArquivo: String
        let criadaEm: Date
    }

    private struct LotePendente: Codable {
        let spotID: UUID
        let nomeSpot: String
        var fotos: [FotoPendente]
    }

    @ObservationIgnored private weak var sessao: SessaoUsuario?
    @ObservationIgnored private let arquivos = FileManager.default
    @ObservationIgnored private var tarefa: Task<Void, Never>?
    @ObservationIgnored private var precisaRetomar = false
    @ObservationIgnored private var geracao = UUID()
    private(set) var mensagemDeErro: String?

    init(sessao: SessaoUsuario) {
        self.sessao = sessao
    }

    func registrar(spot: Spot, fotos: [FotoCadastroSpot]) throws {
        guard let usuarioID = sessao?.usuarioAtual?.id,
              usuarioID == spot.proprietarioID,
              !fotos.isEmpty else {
            throw ErroCRUD.dadosInvalidos(descricao: "Selecione ao menos uma foto para o Spot.")
        }

        let diretorio = try diretorioDoSpot(usuarioID: usuarioID, spotID: spot.id)
        let manifestoURL = diretorio.appendingPathComponent("pendentes.json")
        if arquivos.fileExists(atPath: manifestoURL.path) { return }

        try arquivos.createDirectory(at: diretorio, withIntermediateDirectories: true)
        var movidos: [(origem: URL, destino: URL)] = []
        do {
            let pendentes = try fotos.map { foto -> FotoPendente in
                let nome = foto.id.uuidString.lowercased() + "." + foto.arquivoURL.pathExtension
                let destino = diretorio.appendingPathComponent(nome)
                try arquivos.moveItem(at: foto.arquivoURL, to: destino)
                movidos.append((foto.arquivoURL, destino))
                return FotoPendente(id: foto.id, nomeArquivo: nome, criadaEm: Date())
            }
            let lote = LotePendente(spotID: spot.id, nomeSpot: spot.nome, fotos: pendentes)
            try salvar(lote, em: manifestoURL)
        } catch {
            for movido in movidos.reversed() {
                try? arquivos.moveItem(at: movido.destino, to: movido.origem)
            }
            throw error
        }
    }

    func retomarPendentes() {
        guard let usuarioID = sessao?.usuarioAtual?.id else { return }
        if tarefa != nil {
            precisaRetomar = true
            return
        }
        let geracaoAtual = geracao
        tarefa = Task { [weak self] in
            guard let self else { return }
            await self.processar(usuarioID: usuarioID)
            guard self.geracao == geracaoAtual else { return }
            self.tarefa = nil
            if self.precisaRetomar {
                self.precisaRetomar = false
                self.retomarPendentes()
            }
        }
    }

    func interromper() {
        geracao = UUID()
        tarefa?.cancel()
        tarefa = nil
        precisaRetomar = false
        mensagemDeErro = nil
    }

    func limparErro() { mensagemDeErro = nil }

    private func processar(usuarioID: UUID) async {
        mensagemDeErro = nil
        guard let diretorio = try? diretorioDoUsuario(usuarioID) else { return }
        guard let diretorios = try? arquivos.contentsOfDirectory(
            at: diretorio,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let fotoCRUD: FotoCRUD?
        if let sessao, sessao.usuarioAtual?.id == usuarioID {
            fotoCRUD = FotoCRUD(sessao: sessao)
        } else {
            fotoCRUD = nil
        }
        guard let fotoCRUD else { return }

        for pasta in diretorios.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard !Task.isCancelled, sessao?.usuarioAtual?.id == usuarioID else { return }
            let manifestoURL = pasta.appendingPathComponent("pendentes.json")
            guard let dados = try? Data(contentsOf: manifestoURL),
                  let lote = try? JSONDecoder().decode(LotePendente.self, from: dados) else {
                mensagemDeErro = "Não foi possível recuperar as fotos pendentes. Tente adicioná-las novamente ao Spot."
                continue
            }

            guard !Task.isCancelled, sessao?.usuarioAtual?.id == usuarioID else { return }
            do {
                let fotos = lote.fotos.map { pendente in
                    FotoEnvioCadastroSpot(
                        id: pendente.id,
                        arquivoURL: pasta.appendingPathComponent(pendente.nomeArquivo),
                        criadaEm: pendente.criadaEm
                    )
                }
                if !fotos.isEmpty {
                    _ = try await fotoCRUD.enviarLoteDoCadastro(fotos, spotID: lote.spotID)
                }
                try? arquivos.removeItem(at: pasta)
            } catch ErroCloudKit.registroNaoEncontrado {
                try? arquivos.removeItem(at: pasta)
            } catch is CancellationError {
                return
            } catch {
                mensagemDeErro = "As fotos de \(lote.nomeSpot) ainda não foram enviadas. O app tentará novamente ao abrir. \(error.localizedDescription)"
            }
        }
    }

    private func salvar(_ lote: LotePendente, em url: URL) throws {
        try JSONEncoder().encode(lote).write(to: url, options: .atomic)
    }

    private func diretorioDoSpot(usuarioID: UUID, spotID: UUID) throws -> URL {
        try diretorioDoUsuario(usuarioID)
            .appendingPathComponent(spotID.uuidString.lowercased(), isDirectory: true)
    }

    private func diretorioDoUsuario(_ usuarioID: UUID) throws -> URL {
        guard let suporte = arquivos.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ErroCloudKit.arquivoIndisponivel
        }
        return suporte
            .appendingPathComponent("EnviosFotosCadastroSpots", isDirectory: true)
            .appendingPathComponent(usuarioID.uuidString.lowercased(), isDirectory: true)
    }
}
