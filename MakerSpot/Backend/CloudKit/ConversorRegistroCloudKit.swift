//
//  ConversorRegistroCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import CoreLocation
import Foundation

struct FotoComArquivoCloudKit: Sendable {
    let foto: Foto
    let arquivoURL: URL
}

enum ConversorRegistroCloudKit {
    // Usuário

    static func registro(
        de usuario: Usuario,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let registro = try prepararRegistro(
            tipo: .usuario,
            identificador: IdentificadorCloudKit.usuario(usuario.id),
            existente: existente
        )

        registro[CampoCloudKit.id] = texto(usuario.id)
        registro[CampoCloudKit.Usuario.appleUserID] = usuario.appleUserID
        registro[CampoCloudKit.Usuario.cloudKitUserRecordName] = usuario.cloudKitUserRecordName
        registro[CampoCloudKit.Usuario.nome] = usuario.nome
        registro[CampoCloudKit.Usuario.sobrenome] = usuario.sobrenome
        registro[CampoCloudKit.Usuario.fotoID] = usuario.fotoID.map { texto($0) }
        registro[CampoCloudKit.Usuario.telefonePadrao] = usuario.telefonePadrao
        registro[CampoCloudKit.criadoEm] = usuario.criadoEm
        registro[CampoCloudKit.atualizadoEm] = usuario.atualizadoEm
        return registro
    }

    static func usuario(de registro: CKRecord) throws -> Usuario {
        try verificarTipo(.usuario, do: registro)
        return Usuario(
            id: try idValidado(
                do: registro,
                identificador: { IdentificadorCloudKit.usuario($0) }
            ),
            appleUserID: try ler(CampoCloudKit.Usuario.appleUserID, do: registro),
            cloudKitUserRecordName: try ler(
                CampoCloudKit.Usuario.cloudKitUserRecordName,
                do: registro
            ),
            nome: try lerOpcional(CampoCloudKit.Usuario.nome, do: registro),
            sobrenome: try lerOpcional(CampoCloudKit.Usuario.sobrenome, do: registro),
            fotoID: try uuidOpcional(CampoCloudKit.Usuario.fotoID, do: registro),
            telefonePadrao: try lerOpcional(
                CampoCloudKit.Usuario.telefonePadrao,
                do: registro
            ),
            criadoEm: try ler(CampoCloudKit.criadoEm, do: registro),
            atualizadoEm: try ler(CampoCloudKit.atualizadoEm, do: registro)
        )
    }

    // Spot

    static func registro(
        de spot: Spot,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let coordenada = CLLocationCoordinate2D(
            latitude: spot.localizacao.coordenadas.latitude,
            longitude: spot.localizacao.coordenadas.longitude
        )
        guard CLLocationCoordinate2DIsValid(coordenada) else {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "As coordenadas do Spot são inválidas."
            )
        }

        let registro = try prepararRegistro(
            tipo: .spot,
            identificador: IdentificadorCloudKit.spot(spot.id),
            existente: existente
        )

        registro[CampoCloudKit.id] = texto(spot.id)
        registro[CampoCloudKit.Spot.proprietarioID] = texto(spot.proprietarioID)
        registro[CampoCloudKit.Spot.nomePublicador] = spot.nomePublicador
        registro[CampoCloudKit.Spot.tipo] = spot.tipo.rawValue
        registro[CampoCloudKit.Spot.nome] = spot.nome
        registro[CampoCloudKit.Spot.descricao] = spot.descricao
        registro[CampoCloudKit.Spot.telefone] = spot.telefone
        registro[CampoCloudKit.Spot.link] = spot.link?.absoluteString
        registro[CampoCloudKit.Spot.redesSociais] = try codificar(spot.redesSociais)
        registro[CampoCloudKit.Spot.fotoIDs] = spot.fotoIDs.isEmpty
            ? nil
            : spot.fotoIDs.map { texto($0) }
        registro[CampoCloudKit.Spot.estaAtivo] = spot.estaAtivo
        registro[CampoCloudKit.Spot.versao] = spot.versao

        let endereco = spot.localizacao.endereco
        registro[CampoCloudKit.Spot.logradouro] = endereco.logradouro
        registro[CampoCloudKit.Spot.numero] = endereco.numero
        registro[CampoCloudKit.Spot.complemento] = endereco.complemento
        registro[CampoCloudKit.Spot.bairro] = endereco.bairro
        registro[CampoCloudKit.Spot.cidade] = endereco.cidade
        registro[CampoCloudKit.Spot.estado] = endereco.estado
        registro[CampoCloudKit.Spot.codigoPostal] = endereco.codigoPostal
        registro[CampoCloudKit.Spot.codigoPais] = endereco.codigoPais
        registro[CampoCloudKit.Spot.localizacao] = CLLocation(
            latitude: coordenada.latitude,
            longitude: coordenada.longitude
        )

        switch spot.detalhes {
        case .evento(let evento):
            registro[CampoCloudKit.Spot.inicioEvento] = evento.inicio
            registro[CampoCloudKit.Spot.terminoEvento] = evento.termino
            registro[CampoCloudKit.Spot.fusoHorarioID] = evento.fusoHorarioID
            registro[CampoCloudKit.Spot.funcionamento] = nil
        case .espaco(let espaco):
            registro[CampoCloudKit.Spot.inicioEvento] = nil
            registro[CampoCloudKit.Spot.terminoEvento] = nil
            registro[CampoCloudKit.Spot.fusoHorarioID] = nil
            registro[CampoCloudKit.Spot.funcionamento] = try codificar(espaco.funcionamento)
        }

        registro[CampoCloudKit.criadoEm] = spot.criadoEm
        registro[CampoCloudKit.atualizadoEm] = spot.atualizadoEm
        return registro
    }

    static func spot(de registro: CKRecord) throws -> Spot {
        try verificarTipo(.spot, do: registro)

        let tipoTexto: String = try ler(CampoCloudKit.Spot.tipo, do: registro)
        guard let tipo = TipoSpot(rawValue: tipoTexto) else {
            throw campoInvalido(CampoCloudKit.Spot.tipo, do: registro)
        }

        let detalhes: DetalhesSpot
        switch tipo {
        case .evento:
            detalhes = .evento(
                Evento(
                    inicio: try ler(CampoCloudKit.Spot.inicioEvento, do: registro),
                    termino: try ler(CampoCloudKit.Spot.terminoEvento, do: registro),
                    fusoHorarioID: try ler(CampoCloudKit.Spot.fusoHorarioID, do: registro)
                )
            )
        case .espaco:
            let funcionamento: FuncionamentoSemanal = try decodificar(
                CampoCloudKit.Spot.funcionamento,
                do: registro
            )
            detalhes = .espaco(Espaco(funcionamento: funcionamento))
        }

        let local: CLLocation = try ler(CampoCloudKit.Spot.localizacao, do: registro)
        guard CLLocationCoordinate2DIsValid(local.coordinate) else {
            throw campoInvalido(CampoCloudKit.Spot.localizacao, do: registro)
        }
        let textoLink: String? = try lerOpcional(CampoCloudKit.Spot.link, do: registro)
        let link = try textoLink.map { texto in
            guard let url = URL(string: texto) else {
                throw campoInvalido(CampoCloudKit.Spot.link, do: registro)
            }
            return url
        }

        return Spot(
            id: try idValidado(
                do: registro,
                identificador: { IdentificadorCloudKit.spot($0) }
            ),
            proprietarioID: try uuid(CampoCloudKit.Spot.proprietarioID, do: registro),
            nomePublicador: try ler(
                CampoCloudKit.Spot.nomePublicador,
                do: registro
            ),
            nome: try ler(CampoCloudKit.Spot.nome, do: registro),
            descricao: try ler(CampoCloudKit.Spot.descricao, do: registro),
            localizacao: Localizacao(
                endereco: Endereco(
                    logradouro: try ler(CampoCloudKit.Spot.logradouro, do: registro),
                    numero: try ler(CampoCloudKit.Spot.numero, do: registro),
                    complemento: try lerOpcional(
                        CampoCloudKit.Spot.complemento,
                        do: registro
                    ),
                    bairro: try lerOpcional(CampoCloudKit.Spot.bairro, do: registro),
                    cidade: try ler(CampoCloudKit.Spot.cidade, do: registro),
                    estado: try ler(CampoCloudKit.Spot.estado, do: registro),
                    codigoPostal: try lerOpcional(
                        CampoCloudKit.Spot.codigoPostal,
                        do: registro
                    ),
                    codigoPais: try ler(CampoCloudKit.Spot.codigoPais, do: registro)
                ),
                coordenadas: Coordenadas(
                    latitude: local.coordinate.latitude,
                    longitude: local.coordinate.longitude
                )
            ),
            telefone: try ler(CampoCloudKit.Spot.telefone, do: registro),
            link: link,
            redesSociais: try decodificar(CampoCloudKit.Spot.redesSociais, do: registro),
            fotoIDs: try listaUUIDsOpcional(CampoCloudKit.Spot.fotoIDs, do: registro),
            detalhes: detalhes,
            estaAtivo: try booleano(CampoCloudKit.Spot.estaAtivo, do: registro),
            versao: try ler(CampoCloudKit.Spot.versao, do: registro),
            criadoEm: try ler(CampoCloudKit.criadoEm, do: registro),
            atualizadoEm: try ler(CampoCloudKit.atualizadoEm, do: registro)
        )
    }

    // Foto

    static func registro(
        de foto: Foto,
        arquivoURL: URL? = nil,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let tipo: TipoRegistroCloudKit
        switch foto.destino {
        case .spot:
            tipo = .fotoSpot
        case .perfil:
            tipo = .fotoPerfil
        }

        let registro = try prepararRegistro(
            tipo: tipo,
            identificador: IdentificadorCloudKit.foto(foto.id),
            existente: existente
        )

        if let arquivoURL {
            guard FileManager.default.fileExists(atPath: arquivoURL.path) else {
                throw ErroCloudKit.arquivoNaoEncontrado
            }
            registro[CampoCloudKit.Foto.arquivo] = CKAsset(fileURL: arquivoURL)
        } else if registro[CampoCloudKit.Foto.arquivo] == nil {
            throw ErroCloudKit.arquivoNaoEncontrado
        }

        registro[CampoCloudKit.id] = texto(foto.id)
        registro[CampoCloudKit.Foto.enviadaPorID] = texto(foto.enviadaPorID)
        registro[CampoCloudKit.Foto.textoAlternativo] = foto.textoAlternativo
        registro[CampoCloudKit.criadoEm] = foto.criadaEm

        switch foto.destino {
        case .spot(let spotID):
            registro[CampoCloudKit.Foto.destinoTipo] = "spot"
            registro[CampoCloudKit.Foto.destinoID] = texto(spotID)
            registro[CampoCloudKit.Foto.spotReferencia] = CKRecord.Reference(
                recordID: IdentificadorCloudKit.spot(spotID),
                action: .deleteSelf
            )
            registro[CampoCloudKit.Foto.usuarioReferencia] = nil
        case .perfil(let usuarioID):
            registro[CampoCloudKit.Foto.destinoTipo] = "perfil"
            registro[CampoCloudKit.Foto.destinoID] = texto(usuarioID)
            registro[CampoCloudKit.Foto.usuarioReferencia] = CKRecord.Reference(
                recordID: IdentificadorCloudKit.usuario(usuarioID),
                action: .deleteSelf
            )
            registro[CampoCloudKit.Foto.spotReferencia] = nil
        }
        return registro
    }

    static func foto(de registro: CKRecord) throws -> FotoComArquivoCloudKit {
        let tipo: TipoRegistroCloudKit
        switch registro.recordType {
        case TipoRegistroCloudKit.fotoSpot.rawValue:
            tipo = .fotoSpot
        case TipoRegistroCloudKit.fotoPerfil.rawValue:
            tipo = .fotoPerfil
        default:
            throw ErroCloudKit.tipoRegistroIncompativel(
                esperado: "\(TipoRegistroCloudKit.fotoSpot.rawValue) ou \(TipoRegistroCloudKit.fotoPerfil.rawValue)",
                recebido: registro.recordType
            )
        }
        try verificarTipo(tipo, do: registro)

        let destinoID = try uuid(CampoCloudKit.Foto.destinoID, do: registro)
        let destinoTipo: String = try ler(CampoCloudKit.Foto.destinoTipo, do: registro)
        let destino: DestinoFoto

        switch destinoTipo {
        case "spot" where registro.recordType == TipoRegistroCloudKit.fotoSpot.rawValue:
            destino = .spot(destinoID)
            try verificarReferencia(
                CampoCloudKit.Foto.spotReferencia,
                identificador: IdentificadorCloudKit.spot(destinoID),
                acao: .deleteSelf,
                do: registro
            )
            try verificarCampoNulo(CampoCloudKit.Foto.usuarioReferencia, do: registro)
        case "perfil" where registro.recordType == TipoRegistroCloudKit.fotoPerfil.rawValue:
            destino = .perfil(destinoID)
            try verificarReferencia(
                CampoCloudKit.Foto.usuarioReferencia,
                identificador: IdentificadorCloudKit.usuario(destinoID),
                acao: .deleteSelf,
                do: registro
            )
            try verificarCampoNulo(CampoCloudKit.Foto.spotReferencia, do: registro)
        default:
            throw campoInvalido(CampoCloudKit.Foto.destinoTipo, do: registro)
        }

        let asset: CKAsset = try ler(CampoCloudKit.Foto.arquivo, do: registro)
        guard let arquivoURL = asset.fileURL else {
            throw campoInvalido(CampoCloudKit.Foto.arquivo, do: registro)
        }

        return FotoComArquivoCloudKit(
            foto: Foto(
                id: try idValidado(
                    do: registro,
                    identificador: { IdentificadorCloudKit.foto($0) }
                ),
                enviadaPorID: try uuid(CampoCloudKit.Foto.enviadaPorID, do: registro),
                destino: destino,
                textoAlternativo: try lerOpcional(
                    CampoCloudKit.Foto.textoAlternativo,
                    do: registro
                ),
                criadaEm: try ler(CampoCloudKit.criadoEm, do: registro)
            ),
            arquivoURL: arquivoURL
        )
    }

    // Spot salvo

    static func registro(
        de salvo: SpotSalvo,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let registro = try prepararRegistro(
            tipo: .spotSalvo,
            identificador: IdentificadorCloudKit.spotSalvo(salvo),
            existente: existente
        )

        registro[CampoCloudKit.id] = salvo.id
        registro[CampoCloudKit.SpotSalvo.usuarioID] = texto(salvo.usuarioID)
        registro[CampoCloudKit.SpotSalvo.spotID] = texto(salvo.spotID)
        registro[CampoCloudKit.SpotSalvo.salvoEm] = salvo.salvoEm
        registro[CampoCloudKit.SpotSalvo.ultimaVersaoConhecida] = salvo.ultimaVersaoConhecida
        return registro
    }

    static func spotSalvo(de registro: CKRecord) throws -> SpotSalvo {
        try verificarTipo(.spotSalvo, do: registro)
        let salvo = SpotSalvo(
            usuarioID: try uuid(CampoCloudKit.SpotSalvo.usuarioID, do: registro),
            spotID: try uuid(CampoCloudKit.SpotSalvo.spotID, do: registro),
            salvoEm: try ler(CampoCloudKit.SpotSalvo.salvoEm, do: registro),
            ultimaVersaoConhecida: try ler(
                CampoCloudKit.SpotSalvo.ultimaVersaoConhecida,
                do: registro
            )
        )
        let idArmazenado: String = try ler(CampoCloudKit.id, do: registro)
        guard idArmazenado == salvo.id else {
            throw campoInvalido(CampoCloudKit.id, do: registro)
        }
        try verificarIdentificador(IdentificadorCloudKit.spotSalvo(salvo), do: registro)
        return salvo
    }

    // Denúncia

    static func registro(
        de denuncia: Denuncia,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let registro = try prepararRegistro(
            tipo: .denuncia,
            identificador: IdentificadorCloudKit.denuncia(denuncia.id),
            existente: existente
        )

        registro[CampoCloudKit.id] = texto(denuncia.id)
        registro[CampoCloudKit.Denuncia.spotID] = texto(denuncia.spotID)
        registro[CampoCloudKit.Denuncia.spotReferencia] = CKRecord.Reference(
            recordID: IdentificadorCloudKit.spot(denuncia.spotID),
            action: .none
        )
        registro[CampoCloudKit.Denuncia.texto] = denuncia.texto
        registro[CampoCloudKit.Denuncia.criadaEm] = denuncia.criadaEm
        return registro
    }

    static func denuncia(de registro: CKRecord) throws -> Denuncia {
        try verificarTipo(.denuncia, do: registro)
        let id = try idValidado(
            do: registro,
            identificador: { IdentificadorCloudKit.denuncia($0) }
        )
        let spotID = try uuid(CampoCloudKit.Denuncia.spotID, do: registro)
        try verificarReferencia(
            CampoCloudKit.Denuncia.spotReferencia,
            identificador: IdentificadorCloudKit.spot(spotID),
            acao: .none,
            do: registro
        )
        return Denuncia(
            id: id,
            spotID: spotID,
            texto: try ler(CampoCloudKit.Denuncia.texto, do: registro),
            criadaEm: try ler(CampoCloudKit.Denuncia.criadaEm, do: registro)
        )
    }

    // Análise de denúncia

    static func registro(
        de analise: AnaliseDenuncia,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let registro = try prepararRegistro(
            tipo: .analiseDenuncia,
            identificador: IdentificadorCloudKit.analiseDenuncia(analise.id),
            existente: existente
        )

        registro[CampoCloudKit.id] = texto(analise.id)
        registro[CampoCloudKit.AnaliseDenuncia.denunciaID] = texto(analise.denunciaID)
        registro[CampoCloudKit.AnaliseDenuncia.denunciaReferencia] = CKRecord.Reference(
            recordID: IdentificadorCloudKit.denuncia(analise.denunciaID),
            action: .none
        )
        registro[CampoCloudKit.AnaliseDenuncia.status] = analise.status.rawValue
        registro[CampoCloudKit.AnaliseDenuncia.observacao] = analise.observacao
        registro[CampoCloudKit.AnaliseDenuncia.analisadaEm] = analise.analisadaEm
        return registro
    }

    static func analiseDenuncia(de registro: CKRecord) throws -> AnaliseDenuncia {
        try verificarTipo(.analiseDenuncia, do: registro)
        let id = try idValidado(
            do: registro,
            identificador: { IdentificadorCloudKit.analiseDenuncia($0) }
        )
        let denunciaID = try uuid(CampoCloudKit.AnaliseDenuncia.denunciaID, do: registro)
        guard id == denunciaID else {
            throw campoInvalido(CampoCloudKit.AnaliseDenuncia.denunciaID, do: registro)
        }
        try verificarReferencia(
            CampoCloudKit.AnaliseDenuncia.denunciaReferencia,
            identificador: IdentificadorCloudKit.denuncia(id),
            acao: .none,
            do: registro
        )

        let statusTexto: String = try ler(CampoCloudKit.AnaliseDenuncia.status, do: registro)
        guard let status = StatusDenuncia(rawValue: statusTexto) else {
            throw campoInvalido(CampoCloudKit.AnaliseDenuncia.status, do: registro)
        }

        return AnaliseDenuncia(
            denunciaID: id,
            status: status,
            observacao: try lerOpcional(
                CampoCloudKit.AnaliseDenuncia.observacao,
                do: registro
            ),
            analisadaEm: try lerOpcional(
                CampoCloudKit.AnaliseDenuncia.analisadaEm,
                do: registro
            )
        )
    }

    // Banimento

    static func registro(
        de banimento: BanimentoUsuario,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        guard let contaHash = IdentificadorContaCloudKit.normalizarHash(
            banimento.contaHash
        ), contaHash == banimento.contaHash else {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "O identificador da conta banida é inválido."
            )
        }
        let registro = try prepararRegistro(
            tipo: .banimentoUsuario,
            identificador: IdentificadorCloudKit.banimentoUsuario(
                contaHash: contaHash
            ),
            existente: existente
        )

        registro[CampoCloudKit.id] = contaHash
        registro[CampoCloudKit.BanimentoUsuario.contaHash] = contaHash
        registro[CampoCloudKit.BanimentoUsuario.banidoEm] = banimento.banidoEm
        return registro
    }

    static func banimentoUsuario(de registro: CKRecord) throws -> BanimentoUsuario {
        try verificarTipo(.banimentoUsuario, do: registro)
        let id: String = try ler(CampoCloudKit.id, do: registro)
        let contaHash: String = try ler(
            CampoCloudKit.BanimentoUsuario.contaHash,
            do: registro
        )
        guard let hashNormalizado = IdentificadorContaCloudKit.normalizarHash(contaHash),
              hashNormalizado == contaHash,
              id == contaHash else {
            throw campoInvalido(CampoCloudKit.BanimentoUsuario.contaHash, do: registro)
        }
        try verificarIdentificador(
            IdentificadorCloudKit.banimentoUsuario(contaHash: contaHash),
            do: registro
        )

        return BanimentoUsuario(
            contaHash: contaHash,
            banidoEm: try ler(CampoCloudKit.BanimentoUsuario.banidoEm, do: registro)
        )
    }

    // Notificação de moderação

    static func registro(
        de notificacao: NotificacaoModeracao,
        existente: CKRecord? = nil
    ) throws -> CKRecord {
        let registro = try prepararRegistro(
            tipo: .notificacaoModeracao,
            identificador: IdentificadorCloudKit.notificacaoModeracao(notificacao.id),
            existente: existente
        )

        registro[CampoCloudKit.id] = texto(notificacao.id)
        registro[CampoCloudKit.NotificacaoModeracao.destinatarioID] = texto(
            notificacao.destinatarioID
        )
        registro[CampoCloudKit.NotificacaoModeracao.tipoConteudo] =
            notificacao.tipoConteudo.rawValue
        registro[CampoCloudKit.NotificacaoModeracao.conteudoID] =
            notificacao.conteudoID.map { texto($0) }
        registro[CampoCloudKit.NotificacaoModeracao.nomeConteudo] =
            notificacao.nomeConteudo
        registro[CampoCloudKit.NotificacaoModeracao.motivo] = notificacao.motivo
        registro[CampoCloudKit.criadoEm] = notificacao.criadaEm
        return registro
    }

    static func notificacaoModeracao(
        de registro: CKRecord
    ) throws -> NotificacaoModeracao {
        try verificarTipo(.notificacaoModeracao, do: registro)
        let tipoTexto: String = try ler(
            CampoCloudKit.NotificacaoModeracao.tipoConteudo,
            do: registro
        )
        guard let tipo = TipoConteudoModerado(rawValue: tipoTexto) else {
            throw campoInvalido(
                CampoCloudKit.NotificacaoModeracao.tipoConteudo,
                do: registro
            )
        }

        return NotificacaoModeracao(
            id: try idValidado(
                do: registro,
                identificador: { IdentificadorCloudKit.notificacaoModeracao($0) }
            ),
            destinatarioID: try uuid(
                CampoCloudKit.NotificacaoModeracao.destinatarioID,
                do: registro
            ),
            tipoConteudo: tipo,
            conteudoID: try uuidOpcional(
                CampoCloudKit.NotificacaoModeracao.conteudoID,
                do: registro
            ),
            nomeConteudo: try lerOpcional(
                CampoCloudKit.NotificacaoModeracao.nomeConteudo,
                do: registro
            ),
            motivo: try ler(
                CampoCloudKit.NotificacaoModeracao.motivo,
                do: registro
            ),
            criadaEm: try ler(CampoCloudKit.criadoEm, do: registro)
        )
    }

    // Apoio à conversão

    private static func prepararRegistro(
        tipo: TipoRegistroCloudKit,
        identificador: CKRecord.ID,
        existente: CKRecord?
    ) throws -> CKRecord {
        let registro: CKRecord
        if let existente {
            try verificarTipo(tipo, do: existente)
            try verificarIdentificador(identificador, do: existente)
            registro = existente
        } else {
            registro = CKRecord(recordType: tipo.rawValue, recordID: identificador)
        }
        registro[CampoCloudKit.versaoEsquema] = VersaoEsquemaCloudKit.atual
        return registro
    }

    private static func verificarTipo(
        _ tipo: TipoRegistroCloudKit,
        do registro: CKRecord
    ) throws {
        guard registro.recordType == tipo.rawValue else {
            throw ErroCloudKit.tipoRegistroIncompativel(
                esperado: tipo.rawValue,
                recebido: registro.recordType
            )
        }
        let versao: Int = try ler(CampoCloudKit.versaoEsquema, do: registro)
        guard versao == VersaoEsquemaCloudKit.atual else {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "A versão deste registro do CloudKit não é compatível com o aplicativo."
            )
        }
    }

    private static func verificarIdentificador(
        _ esperado: CKRecord.ID,
        do registro: CKRecord
    ) throws {
        guard registro.recordID == esperado else {
            throw ErroCloudKit.identificadorRegistroIncompativel(
                esperado: esperado.recordName,
                recebido: registro.recordID.recordName
            )
        }
    }

    private static func verificarReferencia(
        _ campo: String,
        identificador: CKRecord.ID,
        acao: CKRecord.ReferenceAction,
        do registro: CKRecord
    ) throws {
        let referencia: CKRecord.Reference = try ler(campo, do: registro)
        guard referencia.recordID == identificador,
              referencia.action == acao else {
            throw campoInvalido(campo, do: registro)
        }
    }

    private static func verificarCampoNulo(
        _ campo: String,
        do registro: CKRecord
    ) throws {
        guard registro[campo] == nil else {
            throw campoInvalido(campo, do: registro)
        }
    }

    private static func texto(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    private static func ler<T>(_ campo: String, do registro: CKRecord) throws -> T {
        guard let valor: T = try lerOpcional(campo, do: registro) else {
            throw campoAusente(campo, do: registro)
        }
        return valor
    }

    private static func lerOpcional<T>(
        _ campo: String,
        do registro: CKRecord
    ) throws -> T? {
        guard let valor = registro[campo] else { return nil }
        guard let resultado = valor as? T else {
            throw campoInvalido(campo, do: registro)
        }
        return resultado
    }

    private static func uuid(_ campo: String, do registro: CKRecord) throws -> UUID {
        let valor: String = try ler(campo, do: registro)
        guard let id = UUID(uuidString: valor) else {
            throw campoInvalido(campo, do: registro)
        }
        return id
    }

    private static func idValidado(
        do registro: CKRecord,
        identificador: (UUID) -> CKRecord.ID
    ) throws -> UUID {
        let id = try uuid(CampoCloudKit.id, do: registro)
        try verificarIdentificador(identificador(id), do: registro)
        return id
    }

    private static func uuidOpcional(
        _ campo: String,
        do registro: CKRecord
    ) throws -> UUID? {
        guard let valor: String = try lerOpcional(campo, do: registro) else { return nil }
        guard let id = UUID(uuidString: valor) else {
            throw campoInvalido(campo, do: registro)
        }
        return id
    }

    private static func listaUUIDsOpcional(
        _ campo: String,
        do registro: CKRecord
    ) throws -> [UUID] {
        let textos: [String] = try lerOpcional(campo, do: registro) ?? []

        return try textos.map { texto in
            guard let id = UUID(uuidString: texto) else {
                throw campoInvalido(campo, do: registro)
            }
            return id
        }
    }

    private static func booleano(_ campo: String, do registro: CKRecord) throws -> Bool {
        let valor: Int = try ler(campo, do: registro)
        switch valor {
        case 0: return false
        case 1: return true
        default: throw campoInvalido(campo, do: registro)
        }
    }

    private static func codificar<T: Encodable>(_ valor: T) throws -> Data {
        do {
            return try JSONEncoder().encode(valor)
        } catch {
            throw ErroCloudKit.dadosInvalidos(
                descricao: "Não foi possível preparar os dados para o CloudKit."
            )
        }
    }

    private static func decodificar<T: Decodable>(
        _ campo: String,
        do registro: CKRecord
    ) throws -> T {
        let dados: Data = try ler(campo, do: registro)

        do {
            return try JSONDecoder().decode(T.self, from: dados)
        } catch {
            throw campoInvalido(campo, do: registro)
        }
    }

    private static func campoAusente(
        _ campo: String,
        do registro: CKRecord
    ) -> ErroCloudKit {
        .campoAusente(campo: campo, tipoRegistro: registro.recordType)
    }

    private static func campoInvalido(
        _ campo: String,
        do registro: CKRecord
    ) -> ErroCloudKit {
        .campoInvalido(campo: campo, tipoRegistro: registro.recordType)
    }
}
