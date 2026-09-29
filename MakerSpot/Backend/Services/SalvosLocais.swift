import CloudKit
import Combine
import CoreData
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SalvosLocais {
    private(set) var avisoImportacao: String?
    private(set) var avisoICloud: String?
    @ObservationIgnored private weak var sessao: SessaoUsuario?
    @ObservationIgnored private var repositorio: RepositorioSalvosLocais?
    @ObservationIgnored private var usuarioID: UUID?
    @ObservationIgnored private var observadores: Set<AnyCancellable> = []
    @ObservationIgnored private var atualizacao: Task<Void, Never>?
    @ObservationIgnored private var tarefaNotificacoes: Task<Void, Never>?
    @ObservationIgnored private var revisaoNotificacoes = 0
    @ObservationIgnored private var geracao = UUID()
    @ObservationIgnored private var publicados: [UUID: EstadoSalvoLocal] = [:]
    @ObservationIgnored private var cache: [UUID: EstadoSalvoLocal]?
    @ObservationIgnored private var publicou = false
    private let cliente = ClienteCloudKit()
    private let assinaturas = AssinaturasCloudKit()
    private let notificacoes = Notificacoes()

    init(sessao: SessaoUsuario) {
        self.sessao = sessao
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notificacao in
                guard let evento = notificacao.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event,
                      evento.endDate != nil else { return }
                if !evento.succeeded {
                    self?.avisoICloud = "Suas alterações estão neste aparelho. O iCloud tentará sincronizá-las novamente."
                } else {
                    self?.avisoICloud = nil
                    if evento.type == .import { self?.atualizarEmSegundoPlano() }
                }
            }.store(in: &observadores)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.atualizarEmSegundoPlano() }
            .store(in: &observadores)
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // A store é separada por conta; não continue escrevendo após trocar o iCloud.
                try? self?.sessao?.encerrar()
            }.store(in: &observadores)
    }

    func estados() throws -> [UUID: EstadoSalvoLocal] {
        let (repositorio, usuario) = try contexto()
        if let cache { return cache }
        let estados = try repositorio.estados(usuarioID: usuario)
        cache = estados
        return estados
    }

    func estaSalvo(_ spotID: UUID) throws -> Bool {
        try estados()[spotID]?.estaSalvo == true
    }

    func alternar(_ spot: Spot) throws -> Bool {
        let (repositorio, usuario) = try contexto()
        let novoEstado = try repositorio.estado(spotID: spot.id, usuarioID: usuario)?.estaSalvo != true
        try definir(novoEstado, spotID: spot.id, spot: spot)
        return novoEstado
    }

    @discardableResult
    func definir(_ salvo: Bool, spotID: UUID, spot: Spot? = nil) throws -> SpotSalvo {
        let (repositorio, usuario) = try contexto()
        if salvo, let spot {
            guard spot.proprietarioID != usuario else { throw ErroCRUD.spotProprioNaoPodeSerSalvo }
            guard spot.estaDisponivel() else {
                throw ErroCRUD.dadosInvalidos(descricao: "Este Spot não está disponível para salvar.")
            }
        }
        let estado = try repositorio.definir(salvo, spotID: spotID, spot: spot, usuarioID: usuario)
        try publicar()
        return estado.registro
    }

    func marcarComoVisualizado(_ spotID: UUID) throws -> SpotSalvo? {
        let (repositorio, usuario) = try contexto()
        let salvo = try repositorio.marcarComoVisualizado(spotID: spotID, usuarioID: usuario)
        try publicar()
        return salvo
    }

    func atualizarSnapshots(_ spots: [Spot]) throws {
        let (repositorio, usuario) = try contexto()
        try repositorio.atualizarSpots(spots, usuarioID: usuario)
        try publicar()
    }

    func excluirDadosDaConta() throws {
        let (repositorio, usuario) = try contexto()
        geracao = UUID()
        atualizacao?.cancel()
        atualizacao = nil
        tarefaNotificacoes?.cancel()
        tarefaNotificacoes = nil
        try repositorio.excluirDados(usuarioID: usuario)
        try publicar()
    }

    func atualizarEmSegundoPlano() {
        guard sessao?.usuarioAtual != nil else { return }
        do { try publicar() } catch { return }
        agendarNotificacoes()
        guard atualizacao == nil else { return }
        let geracaoAtual = geracao
        atualizacao = Task { [weak self] in
            guard let self else { return }
            defer { if geracao == geracaoAtual { atualizacao = nil } }
            do {
                let (repositorio, usuario) = try contexto()
                guard let sessao else { return }
                let chave = "makerspot.salvos.swiftdata.importado.\(usuario.uuidString)"
                if !UserDefaults.standard.bool(forKey: chave) {
                    let contextoRemoto = try await AutorizacaoCRUD(cliente: cliente, sessao: sessao).contextoAtual()
                    let resultado = try await cliente.consultarTodos(
                        tipo: .spotSalvo,
                        predicado: NSPredicate(format: "%K == %@", CampoCloudKit.SpotSalvo.usuarioID,
                                               contextoRemoto.usuario.id.uuidString.lowercased())
                    )
                    try ApoioCRUD.exigirSemFalhas(resultado.falhas)
                    let legados = try resultado.registros.map { try ConversorRegistroCloudKit.spotSalvo(de: $0) }
                    guard geracao == geracaoAtual, sessao.usuarioAtual?.id == usuario, !Task.isCancelled else { return }
                    try repositorio.importar(legados, usuarioID: usuario)
                    UserDefaults.standard.set(true, forKey: chave)
                    avisoImportacao = nil
                    try publicar()
                }
                try await atualizarConteudo(usuario: usuario, geracaoAtual: geracaoAtual)
            } catch is CancellationError {
                return
            } catch {
                guard geracao == geracaoAtual else { return }
                avisoImportacao = "Não foi possível atualizar os salvos do iCloud. Puxe para tentar novamente; suas alterações locais estão preservadas."
            }
        }
    }

    func interromper() {
        geracao = UUID()
        atualizacao?.cancel()
        atualizacao = nil
        tarefaNotificacoes?.cancel()
        tarefaNotificacoes = nil
        repositorio = nil
        usuarioID = nil
        publicados = [:]
        cache = nil
        publicou = false
        avisoImportacao = nil
        avisoICloud = nil
    }

    private func contexto() throws -> (RepositorioSalvosLocais, UUID) {
        guard let perfil = sessao?.usuarioAtual else { throw ErroCRUD.usuarioNaoAutenticado }
        let usuario = perfil.id
        if usuarioID != usuario || repositorio == nil {
            interromper()
            let chave = "makerspot.salvos.dispositivo"
            let instalacao = UserDefaults.standard.string(forKey: chave) ?? UUID().uuidString
            UserDefaults.standard.set(instalacao, forKey: chave)
            // O identificador do aparelho distingue inclusive uma restauração de backup.
            let aparelho = UIDevice.current.identifierForVendor?.uuidString ?? instalacao
            repositorio = try RepositorioSalvosLocais.abrir(
                contaCloudKit: perfil.cloudKitUserRecordName,
                dispositivoID: "\(aparelho):\(instalacao)"
            )
            usuarioID = usuario
        }
        guard let repositorio else { throw ErroCRUD.respostaInconsistente }
        return (repositorio, usuario)
    }

    private func publicar() throws {
        let (repositorio, usuarioID) = try contexto()
        let novos = try repositorio.estados(usuarioID: usuarioID)
        cache = novos
        guard novos != publicados || !publicou, let sessao else { return }
        publicados = novos
        publicou = true
        let itens = novos.values.compactMap { estado -> ItemSpotSalvo? in
            guard estado.estaSalvo, let spot = estado.spot else { return nil }
            return ItemSpotSalvo(registro: estado.registro, spot: spot)
        }
        let ids = Set(novos.filter { $0.value.estaSalvo }.keys)
        let estadoNotificacoes = EstadoSpotsSalvosNotificacoes.compartilhado
        let removidos = estadoNotificacoes.identificadoresAtuais().subtracting(ids)
        estadoNotificacoes.substituir(ids, usuarioID: usuarioID, consultaIniciadaNa: estadoNotificacoes.sequenciaAtual)
        for id in removidos { notificacoes.cancelarLembretes(spotID: id, papel: .salvo) }
        sessao.alteracoesSpots.substituirSalvos(itens, removidos: Set(novos.filter { !$0.value.estaSalvo }.keys))
        agendarNotificacoes()
    }

    private func atualizarConteudo(usuario: UUID, geracaoAtual: UUID) async throws {
        let ids = try estados().filter { $0.value.estaSalvo }.keys
        guard !ids.isEmpty else { avisoImportacao = nil; return }
        let resultado = try await cliente.buscar(ids.map { IdentificadorCloudKit.spot($0) }, tipo: .spot)
        guard geracao == geracaoAtual, sessao?.usuarioAtual?.id == usuario, !Task.isCancelled else { return }
        let falhas = resultado.falhas.filter {
            if case .registroNaoEncontrado = $0.erro { return false }
            return true
        }
        try ApoioCRUD.exigirSemFalhas(falhas)
        let spots = try resultado.registros.map { try ApoioCRUD.spotValido(de: $0) }
        try atualizarSnapshots(spots)
        // Um conteúdo removido é ocultado, sem transformar uma resposta remota
        // em uma nova intenção do usuário que possa disputar com outro toque.
        for falha in resultado.falhas {
            if case .registroNaoEncontrado = falha.erro,
               let id = IdentificadorCloudKit.spotDoRegistro(falha.identificador),
               var spot = try estados()[id]?.spot {
                spot.estaAtivo = false
                try atualizarSnapshots([spot])
            }
        }
        avisoImportacao = nil
    }

    private func agendarNotificacoes() {
        revisaoNotificacoes += 1
        guard tarefaNotificacoes == nil else { return }
        let geracaoAtual = geracao
        tarefaNotificacoes = Task { [weak self] in
            guard let self else { return }
            defer { if geracao == geracaoAtual { tarefaNotificacoes = nil } }
            do {
                try await Task.sleep(for: .milliseconds(350))
                while !Task.isCancelled, geracao == geracaoAtual {
                    let revisao = revisaoNotificacoes
                    let salvos = try estados().values.filter(\.estaSalvo)
                    try await assinaturas.reconciliarAssinaturas(com: Set(salvos.map { $0.registro.spotID }))
                    guard geracao == geracaoAtual, !Task.isCancelled else { return }
                    // Leia novamente após a espera remota: toques continuam livres.
                    let atuais = try estados().values.filter(\.estaSalvo).compactMap(\.spot)
                    try await notificacoes.sincronizarLembretes(eventos: atuais, papel: .salvo)
                    if revisao == revisaoNotificacoes { return }
                }
            } catch {
                // Assinaturas e lembretes voltam a ser reconciliados na próxima ativação.
            }
        }
    }
}
