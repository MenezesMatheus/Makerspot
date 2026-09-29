//
//  SessaoUsuario.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation
import Security

enum ErroSessaoUsuario: LocalizedError {
    case falhaAoSalvarIdentificador
    case falhaAoLerIdentificador
    case falhaAoRemoverIdentificador

    var errorDescription: String? {
        switch self {
        case .falhaAoSalvarIdentificador:
            return "Não foi possível guardar a sessão com segurança."
        case .falhaAoLerIdentificador:
            return "Não foi possível recuperar a sessão salva."
        case .falhaAoRemoverIdentificador:
            return "Não foi possível encerrar a sessão salva."
        }
    }
}

@MainActor
@Observable
final class SessaoUsuario {
    private struct FotosDetalhesEmCache {
        let ids: [UUID]
        let fotos: [FotoDisponivel]
    }

    let alteracoesSpots = AlteracoesSpots()
    @ObservationIgnored lazy var enviosFotosCadastro = EnviosFotosCadastroSpots(sessao: self)
    @ObservationIgnored private var fotosDetalhesEmCache: [UUID: FotosDetalhesEmCache] = [:]
    @ObservationIgnored private var fotosPublicadoresEmCache: [UUID: FotoDisponivel] = [:]
    @ObservationIgnored private var publicadoresSemFotoAte: [UUID: Date] = [:]
    @ObservationIgnored private var buscasFotosPublicadores: [UUID: Task<FotoDisponivel?, Never>] = [:]
    private(set) var usuarioAtual: Usuario?
    @ObservationIgnored private var nomeContaCloudKitValidado: String?
    @ObservationIgnored private var validacaoCloudKitExpiraEm: Date?
    @ObservationIgnored private var validacaoCloudKitEmAndamento: Task<String, Error>?

    private static let validadeDaContaCloudKit: TimeInterval = 60

    var estaAutenticado: Bool {
        usuarioAtual != nil
    }

    func iniciar(com usuario: Usuario) throws {
        try ChaveiroSessao.salvar(usuario.appleUserID)
        invalidarValidacaoCloudKitSeNecessario(para: usuario)
        usuarioAtual = usuario
        EstadoSpotsSalvosNotificacoes.compartilhado.ativar(usuarioID: usuario.id)
        enviosFotosCadastro.retomarPendentes()
    }

    func restaurar(_ usuario: Usuario) {
        invalidarValidacaoCloudKitSeNecessario(para: usuario)
        usuarioAtual = usuario
        EstadoSpotsSalvosNotificacoes.compartilhado.ativar(usuarioID: usuario.id)
        enviosFotosCadastro.retomarPendentes()
    }

    func identificadorAppleSalvo() throws -> String? {
        try ChaveiroSessao.ler()
    }

    func encerrar() throws {
        try ChaveiroSessao.remover()
        enviosFotosCadastro.interromper()
        fotosDetalhesEmCache = [:]
        fotosPublicadoresEmCache = [:]
        publicadoresSemFotoAte = [:]
        buscasFotosPublicadores = [:]
        invalidarValidacaoCloudKit()
        usuarioAtual = nil
        EstadoSpotsSalvosNotificacoes.compartilhado.limpar()
        alteracoesSpots.limpar()
    }

    func bloquear() {
        try? ChaveiroSessao.remover()
        enviosFotosCadastro.interromper()
        fotosDetalhesEmCache = [:]
        fotosPublicadoresEmCache = [:]
        publicadoresSemFotoAte = [:]
        buscasFotosPublicadores = [:]
        invalidarValidacaoCloudKit()
        usuarioAtual = nil
        EstadoSpotsSalvosNotificacoes.compartilhado.limpar()
        alteracoesSpots.limpar()
    }

    /// Reaproveita e deduplica a validação remota da mesma conta. Uma tela com
    /// vários cards pode solicitar dezenas de fotos simultaneamente; não há
    /// motivo para consultar conta e banimento novamente para cada uma delas.
    func validarContaCloudKit(
        usando validacao: @escaping () async throws -> String
    ) async throws -> String {
        let agora = Date()
        if let nomeContaCloudKitValidado,
           let validacaoCloudKitExpiraEm,
           validacaoCloudKitExpiraEm > agora,
           usuarioAtual?.cloudKitUserRecordName == nomeContaCloudKitValidado {
            return nomeContaCloudKitValidado
        }

        if let validacaoCloudKitEmAndamento {
            return try await validacaoCloudKitEmAndamento.value
        }

        let tarefa = Task { try await validacao() }
        validacaoCloudKitEmAndamento = tarefa
        do {
            let nome = try await tarefa.value
            nomeContaCloudKitValidado = nome
            validacaoCloudKitExpiraEm = Date().addingTimeInterval(
                Self.validadeDaContaCloudKit
            )
            validacaoCloudKitEmAndamento = nil
            return nome
        } catch {
            validacaoCloudKitEmAndamento = nil
            throw error
        }
    }

    func fotosEmCache(para spot: Spot) -> [FotoDisponivel]? {
        guard let entrada = fotosDetalhesEmCache[spot.id],
              entrada.ids == spot.fotoIDs,
              entrada.fotos.allSatisfy({ FileManager.default.fileExists(atPath: $0.arquivoURL.path) }) else {
            return nil
        }
        return entrada.fotos
    }

    func guardarFotosEmCache(_ fotos: [FotoDisponivel], para spot: Spot) {
        guard fotos.map(\.foto.id) == spot.fotoIDs else { return }
        fotosDetalhesEmCache[spot.id] = FotosDetalhesEmCache(ids: spot.fotoIDs, fotos: fotos)
    }

    func removerFotosEmCache(do spotID: UUID) {
        fotosDetalhesEmCache[spotID] = nil
    }

    func fotoPublicadorEmCache(_ usuarioID: UUID) -> FotoDisponivel? {
        guard let foto = fotosPublicadoresEmCache[usuarioID],
              FileManager.default.fileExists(atPath: foto.arquivoURL.path),
              usuarioAtual?.id != usuarioID || usuarioAtual?.fotoID == foto.foto.id else {
            return nil
        }
        return foto
    }

    func guardarFotoPublicadorEmCache(_ foto: FotoDisponivel?, usuarioID: UUID) {
        fotosPublicadoresEmCache[usuarioID] = foto
        publicadoresSemFotoAte[usuarioID] = foto == nil
            ? Date().addingTimeInterval(60)
            : nil
    }

    func carregarFotoPublicador(_ usuarioID: UUID) async -> FotoDisponivel? {
        if let foto = fotoPublicadorEmCache(usuarioID) { return foto }
        if let expiracao = publicadoresSemFotoAte[usuarioID], expiracao > Date() {
            return nil
        }
        if let busca = buscasFotosPublicadores[usuarioID] { return await busca.value }

        let busca = Task { [self] () -> FotoDisponivel? in
            let crud = FotoCRUD(sessao: self)
            if usuarioAtual?.id == usuarioID {
                return try? await crud.buscarFotoPerfilAtual()
            }
            return try? await crud.buscarFotoPublica(para: usuarioID)
        }
        buscasFotosPublicadores[usuarioID] = busca
        let foto = await busca.value
        buscasFotosPublicadores[usuarioID] = nil
        guardarFotoPublicadorEmCache(foto, usuarioID: usuarioID)
        return foto
    }

    private func invalidarValidacaoCloudKitSeNecessario(para usuario: Usuario) {
        guard usuarioAtual?.id != usuario.id
                || usuarioAtual?.cloudKitUserRecordName
                    != usuario.cloudKitUserRecordName else {
            return
        }
        invalidarValidacaoCloudKit()
        alteracoesSpots.limpar()
        fotosDetalhesEmCache = [:]
        fotosPublicadoresEmCache = [:]
        publicadoresSemFotoAte = [:]
        buscasFotosPublicadores = [:]
    }

    private func invalidarValidacaoCloudKit() {
        validacaoCloudKitEmAndamento?.cancel()
        validacaoCloudKitEmAndamento = nil
        nomeContaCloudKitValidado = nil
        validacaoCloudKitExpiraEm = nil
    }
}

private enum ChaveiroSessao {
    private static var consultaBase: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Bundle.main.bundleIdentifier ?? "MakerSpot",
            kSecAttrAccount: "usuarioApple"
        ]
    }

    static func salvar(_ identificador: String) throws {
        let dados = Data(identificador.utf8)
        let consulta = consultaBase

        SecItemDelete(consulta as CFDictionary)

        var novoItem = consulta
        novoItem[kSecValueData] = dados
        novoItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        guard SecItemAdd(novoItem as CFDictionary, nil) == errSecSuccess else {
            throw ErroSessaoUsuario.falhaAoSalvarIdentificador
        }
    }

    static func ler() throws -> String? {
        var consulta = consultaBase
        consulta[kSecReturnData] = true
        consulta[kSecMatchLimit] = kSecMatchLimitOne

        var resultado: CFTypeRef?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let dados = resultado as? Data,
              let identificador = String(data: dados, encoding: .utf8) else {
            throw ErroSessaoUsuario.falhaAoLerIdentificador
        }
        return identificador
    }

    static func remover() throws {
        let consulta = consultaBase

        let status = SecItemDelete(consulta as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ErroSessaoUsuario.falhaAoRemoverIdentificador
        }
    }
}
