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

enum AvisoAtivacaoSpot: Equatable {
    case restrito(nomeSpot: String)
    case eventoEncerrado

    var titulo: String {
        switch self {
        case .restrito: return "Spot restringido pela moderação"
        case .eventoEncerrado: return "Não é possível ativar este evento"
        }
    }

    var mensagem: String {
        switch self {
        case .restrito(let nomeSpot):
            return "O Spot \"\(nomeSpot)\" foi restringido pela moderação. Se você acredita que isso aconteceu por engano e deseja reativá-lo, entre em contato pelo e-mail \(Notificacoes.emailSuporte)."
        case .eventoEncerrado:
            return "A data do evento já passou. Edite a data para anunciá-lo novamente."
        }
    }
}
