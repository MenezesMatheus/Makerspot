import CloudKit
import Foundation

final class SpotsRestritosCRUD {
    private let cliente: ClienteCloudKit

    init(cliente: ClienteCloudKit = ClienteCloudKit()) {
        self.cliente = cliente
    }

    func listarAtivos(para proprietarioID: UUID) async throws -> [SpotRestrito] {
        let resultado = try await cliente.consultarTodos(
            tipo: .spotRestrito,
            predicado: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.SpotRestrito.proprietarioID,
                    proprietarioID.uuidString.lowercased()
                ),
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.SpotRestrito.status,
                    StatusRestricaoSpot.restrito.rawValue
                )
            ])
        )
        try ApoioCRUD.exigirSemFalhas(resultado.falhas)
        return try resultado.registros
            .map { try ConversorRegistroCloudKit.spotRestrito(de: $0) }
            .sorted { $0.criadoEm < $1.criadoEm }
    }

    func estaRestrito(_ spotID: UUID) async throws -> Bool {
        let pagina = try await cliente.consultarPrimeiraPagina(
            tipo: .spotRestrito,
            predicado: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.SpotRestrito.spotID,
                    spotID.uuidString.lowercased()
                ),
                NSPredicate(
                    format: "%K == %@",
                    CampoCloudKit.SpotRestrito.status,
                    StatusRestricaoSpot.restrito.rawValue
                )
            ]),
            limite: 1
        )
        try ApoioCRUD.exigirSemFalhas(pagina.falhas)
        return !pagina.registros.isEmpty
    }
}
