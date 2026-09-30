import CloudKit
import Foundation

enum MudancaSpotSalvo: Equatable, Sendable {
    case ignorada
    case atualizado(Spot)
    case removido(UUID)
}

/// A interface usa exclusivamente o estado durável local. O ModelContainer
/// espelha as gravações no CloudKit sem fazer o botão aguardar a rede.
@MainActor
final class SalvosCRUD {
    private let sessao: SessaoUsuario
    private let cliente: ClienteCloudKit
    private let assinaturas: AssinaturasCloudKit
    private var locais: SalvosLocais { sessao.salvosLocais }

    init(
        cliente: ClienteCloudKit? = nil,
        sessao: SessaoUsuario,
        assinaturas: AssinaturasCloudKit? = nil
    ) {
        self.cliente = cliente ?? ClienteCloudKit()
        self.sessao = sessao
        self.assinaturas = assinaturas ?? AssinaturasCloudKit()
    }

    var avisoSincronizacao: String? { locais.avisoICloud ?? locais.avisoImportacao }

    @discardableResult
    func alternar(spot: Spot) throws -> Bool {
        try locais.alternar(spot)
    }

    func dessalvar(spotID: UUID) throws {
        try locais.definir(false, spotID: spotID)
    }

    func estaSalvo(spotID: UUID) throws -> Bool {
        try locais.estaSalvo(spotID)
    }

    func listar() throws -> [SpotSalvo] {
        try locais.estados().values.filter(\.estaSalvo).map(\.registro)
            .sorted { $0.salvoEm > $1.salvoEm }
    }

    func listarComSpots() throws -> [ItemSpotSalvo] {
        try locais.estados().values.compactMap { estado in
            guard estado.estaSalvo, let spot = estado.spot else { return nil }
            return ItemSpotSalvo(registro: estado.registro, spot: spot)
        }.sorted { $0.registro.salvoEm > $1.registro.salvoEm }
    }

    func marcarComoVisualizado(spotID: UUID) throws -> SpotSalvo? {
        try locais.marcarComoVisualizado(spotID)
    }

    func atualizarSnapshot(_ spot: Spot) throws {
        try locais.atualizarSnapshots([spot])
    }

    func atualizarEmSegundoPlano() {
        locais.atualizarEmSegundoPlano()
    }

    func processarNotificacao(_ dados: [AnyHashable: Any]) async throws -> MudancaSpotSalvo {
        guard let spotID = assinaturas.interpretarNotificacao(dados),
              try estaSalvo(spotID: spotID) else { return .ignorada }
        let usuario = sessao.usuarioAtual?.id
        do {
            let spot = try ApoioCRUD.spotValido(de: await cliente.buscar(
                IdentificadorCloudKit.spot(spotID), tipo: .spot
            ))
            guard sessao.usuarioAtual?.id == usuario,
                  try estaSalvo(spotID: spotID) else { return .ignorada }
            try atualizarSnapshot(spot)
            return .atualizado(spot)
        } catch ErroCloudKit.registroNaoEncontrado {
            guard sessao.usuarioAtual?.id == usuario,
                  try estaSalvo(spotID: spotID) else { return .ignorada }
            if var spot = try locais.estados()[spotID]?.spot {
                spot.estaAtivo = false
                try atualizarSnapshot(spot)
            }
            return .removido(spotID)
        }
    }
}
