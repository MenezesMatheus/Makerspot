import Foundation

struct UsuarioPublico: Identifiable, Codable, Equatable, Sendable {
    let usuarioHash: String
    // Opcional apenas para ler registros antigos; novas publicações sempre incluem o ID.
    let appleUserID: String?
    let nomePublico: String
    let criadoEm: Date

    var id: String { usuarioHash }

    init(usuario: Usuario) {
        usuarioHash = IdentificadorCloudKit.hashUsuarioPublico(usuario.id)
        appleUserID = usuario.appleUserID
        nomePublico = ApoioCRUD.nomePublico(do: usuario)
        criadoEm = usuario.criadoEm
    }

    init(usuarioHash: String, appleUserID: String?, nomePublico: String, criadoEm: Date) {
        self.usuarioHash = usuarioHash
        self.appleUserID = appleUserID
        self.nomePublico = nomePublico
        self.criadoEm = criadoEm
    }
}
