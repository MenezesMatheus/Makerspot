import Foundation

enum StatusRestricaoSpot: String, Sendable {
    case restrito
    case reativado
}

struct SpotRestrito: Identifiable, Equatable, Sendable {
    let id: String
    let spotID: UUID
    let proprietarioID: UUID
    let nomeSpot: String
    let status: StatusRestricaoSpot
    let criadoEm: Date

    var mensagemParaCriador: String {
        "O Spot \"\(nomeSpot)\" foi restringido pela moderação. Se você acredita que isso aconteceu por engano e deseja reativá-lo, entre em contato pelo e-mail \(Notificacoes.emailSuporte)."
    }
}
