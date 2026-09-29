//
//  FotoCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct FotoDisponivel: Equatable, Sendable {
    let foto: Foto
    let arquivoURL: URL
}

struct ResultadoEnvioFotoSpot: Equatable, Sendable {
    let foto: Foto
    let spotAtualizado: Spot
}

struct FotoEnvioCadastroSpot: Sendable {
    let id: UUID
    let arquivoURL: URL
    let criadaEm: Date
}

enum ImagemOpacaJPEG {
    static func converter(_ imagem: CGImage) throws -> CGImage {
        guard let espacoDeCores = CGColorSpace(name: CGColorSpace.sRGB),
              let contexto = CGContext(
                data: nil,
                width: imagem.width,
                height: imagem.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: espacoDeCores,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Não foi possível preparar a imagem selecionada."
            )
        }

        let area = CGRect(x: 0, y: 0, width: imagem.width, height: imagem.height)
        contexto.setFillColor(CGColor(gray: 1, alpha: 1))
        contexto.fill(area)
        contexto.interpolationQuality = .high
        contexto.draw(imagem, in: area)
        guard let resultado = contexto.makeImage() else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Não foi possível preparar a imagem selecionada."
            )
        }
        return resultado
    }
}

final class FotoCRUD {
    private static let limiteBytesOriginais = 30 * 1_024 * 1_024
    private static let limiteBytesPreparados = 10 * 1_024 * 1_024
    private static let limiteMaiorDimensaoOriginal = 20_000
    private static let maiorDimensaoPreparada = 4_096

    private let cliente: ClienteCloudKit
    private let moderacao: ModeracaoFotos
    private let sessao: SessaoUsuario
    private let autorizacao: AutorizacaoCRUD
    private let gerenciadorArquivos: FileManager

    init(
        cliente: ClienteCloudKit = ClienteCloudKit(),
        sessao: SessaoUsuario,
        moderacao: ModeracaoFotos = ModeracaoFotos(),
        gerenciadorArquivos: FileManager = .default
    ) {
        self.cliente = cliente
        self.moderacao = moderacao
        self.sessao = sessao
        self.autorizacao = AutorizacaoCRUD(cliente: cliente, sessao: sessao)
        self.gerenciadorArquivos = gerenciadorArquivos
    }

    func enviarParaSpot(
        arquivoURL: URL,
        spotID: UUID,
        textoAlternativo: String? = nil,
        fotoID: UUID = UUID(),
        criadaEm: Date = Date()
    ) async throws -> ResultadoEnvioFotoSpot {
        let contexto = try await autorizacao.contextoAtual()
        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        var spot = try ConversorRegistroCloudKit.spot(de: registroSpot)
        try autorizacao.validarProprietario(
            do: registroSpot,
            spot: spot,
            contexto: contexto
        )
        guard Set(spot.fotoIDs).count == spot.fotoIDs.count else {
            throw ErroCRUD.respostaInconsistente
        }

        let foto = Foto(
            id: fotoID,
            enviadaPorID: contexto.usuario.id,
            destino: .spot(spot.id),
            textoAlternativo: ApoioCRUD.textoOpcional(textoAlternativo),
            criadaEm: criadaEm
        )
        if spot.fotoIDs.contains(fotoID) {
            return ResultadoEnvioFotoSpot(foto: foto, spotAtualizado: spot)
        }
        let arquivoPreparado = try prepararImagemParaEnvio(arquivoURL)
        defer { try? gerenciadorArquivos.removeItem(at: arquivoPreparado) }
        try await validarSegurancaDaFoto(arquivoPreparado)

        let registroFoto = try ConversorRegistroCloudKit.registro(
            de: foto,
            arquivoURL: arquivoPreparado
        )
        try await salvarFotoSeNecessario(registroFoto, foto: foto)

        spot.fotoIDs.append(foto.id)
        try ApoioCRUD.registrarAlteracao(&spot)
        let registroSpotAtualizado = try ConversorRegistroCloudKit.registro(
            de: spot,
            existente: registroSpot
        )
        let spotAtualizado: Spot
        do {
            spotAtualizado = try ConversorRegistroCloudKit.spot(
                de: try await cliente.salvar(registroSpotAtualizado)
            )
        } catch {
            let erroOriginal = error
            if let registroRemoto = try? await cliente.buscar(
                IdentificadorCloudKit.spot(spot.id),
                tipo: .spot
            ),
            let spotRemoto = try? ConversorRegistroCloudKit.spot(de: registroRemoto),
            spotRemoto.fotoIDs.contains(foto.id) {
                spotAtualizado = spotRemoto
            } else {
                try? await cliente.excluir(registroFoto.recordID, tipo: .fotoSpot)
                throw erroOriginal
            }
        }

        sessao.alteracoesSpots.atualizar(spotAtualizado)
        return ResultadoEnvioFotoSpot(
            foto: foto,
            spotAtualizado: spotAtualizado
        )
    }

    /// Envia todos os assets antes de publicar seus IDs no Spot. Assim o card
    /// e os detalhes só observam uma atualização quando o lote inteiro terminou.
    func enviarLoteDoCadastro(
        _ arquivos: [FotoEnvioCadastroSpot],
        spotID: UUID
    ) async throws -> Spot {
        guard !arquivos.isEmpty,
              Set(arquivos.map(\.id)).count == arquivos.count else {
            throw ErroCRUD.dadosInvalidos(descricao: "Selecione fotos válidas para o Spot.")
        }

        let contexto = try await autorizacao.contextoAtual()
        let registroInicial = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        let spotInicial = try ConversorRegistroCloudKit.spot(de: registroInicial)
        try autorizacao.validarProprietario(
            do: registroInicial,
            spot: spotInicial,
            contexto: contexto
        )
        guard Set(spotInicial.fotoIDs).count == spotInicial.fotoIDs.count else {
            throw ErroCRUD.respostaInconsistente
        }

        let fotosAindaNaoVinculadas = arquivos.filter {
            !spotInicial.fotoIDs.contains($0.id)
        }
        guard !fotosAindaNaoVinculadas.isEmpty else {
            sessao.alteracoesSpots.atualizar(spotInicial)
            return spotInicial
        }

        for arquivo in fotosAindaNaoVinculadas {
            try Task.checkCancellation()
            let preparado = try prepararImagemParaEnvio(arquivo.arquivoURL)
            do {
                try await validarSegurancaDaFoto(preparado)
                let foto = Foto(
                    id: arquivo.id,
                    enviadaPorID: contexto.usuario.id,
                    destino: .spot(spotID),
                    textoAlternativo: nil,
                    criadaEm: arquivo.criadaEm
                )
                let registro = try ConversorRegistroCloudKit.registro(
                    de: foto,
                    arquivoURL: preparado
                )
                try await salvarFotoSeNecessario(registro, foto: foto)
                try? gerenciadorArquivos.removeItem(at: preparado)
            } catch {
                try? gerenciadorArquivos.removeItem(at: preparado)
                throw error
            }
        }

        let idsDoLote = arquivos.map(\.id)
        for tentativa in 0..<3 {
            let registro = tentativa == 0 ? registroInicial : try await cliente.buscar(
                IdentificadorCloudKit.spot(spotID),
                tipo: .spot
            )
            var spot = try ConversorRegistroCloudKit.spot(de: registro)
            try autorizacao.validarProprietario(do: registro, spot: spot, contexto: contexto)
            let faltantes = idsDoLote.filter { !spot.fotoIDs.contains($0) }
            guard !faltantes.isEmpty else {
                sessao.alteracoesSpots.atualizar(spot)
                return spot
            }

            spot.fotoIDs.append(contentsOf: faltantes)
            try ApoioCRUD.registrarAlteracao(&spot)
            let alterado = try ConversorRegistroCloudKit.registro(de: spot, existente: registro)
            do {
                let atualizado = try ConversorRegistroCloudKit.spot(
                    de: try await cliente.salvar(alterado)
                )
                sessao.alteracoesSpots.atualizar(atualizado)
                return atualizado
            } catch ErroCloudKit.conflito where tentativa < 2 {
                continue
            } catch {
                if let remoto = try? await cliente.buscar(
                    IdentificadorCloudKit.spot(spotID),
                    tipo: .spot
                ), let confirmado = try? ConversorRegistroCloudKit.spot(de: remoto),
                   idsDoLote.allSatisfy({ confirmado.fotoIDs.contains($0) }) {
                    sessao.alteracoesSpots.atualizar(confirmado)
                    return confirmado
                }
                throw error
            }
        }
        throw ErroCRUD.respostaInconsistente
    }

    func buscarFotoPrincipal(para spot: Spot) async throws -> FotoDisponivel? {
        var apenasCapa = spot
        apenasCapa.fotoIDs = Array(spot.fotoIDs.prefix(1))
        return try await buscarFotos(para: apenasCapa).first
    }

    func buscarFotos(para spot: Spot) async throws -> [FotoDisponivel] {
        _ = try await autorizacao.contextoAtual()
        guard !spot.fotoIDs.isEmpty else { return [] }
        guard Set(spot.fotoIDs).count == spot.fotoIDs.count else {
            throw ErroCRUD.respostaInconsistente
        }

        let resultadoFotos = try await cliente.buscar(
            spot.fotoIDs.map { IdentificadorCloudKit.foto($0) },
            tipo: .fotoSpot
        )
        let falhasFotos = resultadoFotos.falhas.filter { falha in
            if case .registroNaoEncontrado = falha.erro {
                if let fotoID = IdentificadorCloudKit.fotoDoRegistro(falha.identificador) {
                    removerDoCache(fotoID: fotoID)
                }
                return false
            }
            return true
        }
        try ApoioCRUD.exigirSemFalhas(falhasFotos)

        let fotos = try Dictionary(
            uniqueKeysWithValues: resultadoFotos.registros.map { registro in
                let fotoComArquivo = try ConversorRegistroCloudKit.foto(de: registro)
                return (fotoComArquivo.foto.id, fotoComArquivo)
            }
        )
        return try spot.fotoIDs.compactMap { id in
            guard let fotoComArquivo = fotos[id] else { return nil }
            guard case .spot(let destinoID) = fotoComArquivo.foto.destino,
                  destinoID == spot.id else {
                throw ErroCRUD.respostaInconsistente
            }
            return FotoDisponivel(
                foto: fotoComArquivo.foto,
                arquivoURL: try copiarParaCache(
                    fotoComArquivo.arquivoURL,
                    fotoID: fotoComArquivo.foto.id
                )
            )
        }
    }

    func excluirDoSpot(fotoID: UUID, spotID: UUID) async throws -> Spot {
        let contexto = try await autorizacao.contextoAtual()
        let registroSpot = try await cliente.buscar(
            IdentificadorCloudKit.spot(spotID),
            tipo: .spot
        )
        var spot = try ConversorRegistroCloudKit.spot(de: registroSpot)
        try autorizacao.validarProprietario(
            do: registroSpot,
            spot: spot,
            contexto: contexto
        )
        let identificadorFoto = IdentificadorCloudKit.foto(fotoID)
        var fotoExiste = false
        do {
            let registroFoto = try await cliente.buscar(
                identificadorFoto,
                tipo: .fotoSpot
            )
            let foto = try ConversorRegistroCloudKit.foto(de: registroFoto).foto
            guard foto.enviadaPorID == contexto.usuario.id,
                  case .spot(let destinoID) = foto.destino,
                  destinoID == spot.id else {
                throw ErroCRUD.somenteProprietario
            }
            fotoExiste = true
        } catch ErroCloudKit.registroNaoEncontrado {
        }

        if spot.fotoIDs.contains(fotoID) {
            spot.fotoIDs.removeAll { $0 == fotoID }
            try ApoioCRUD.registrarAlteracao(&spot)
            let registroAtualizado = try ConversorRegistroCloudKit.registro(
                de: spot,
                existente: registroSpot
            )
            spot = try ConversorRegistroCloudKit.spot(
                de: try await cliente.salvar(registroAtualizado)
            )
        } else if !fotoExiste {
            return spot
        }

        if fotoExiste {
            do {
                try await cliente.excluir(identificadorFoto, tipo: .fotoSpot)
            } catch ErroCloudKit.registroNaoEncontrado {
            }
        }
        removerDoCache(fotoID: fotoID)
        sessao.alteracoesSpots.atualizar(spot)
        return spot
    }

    func definirFotoPerfil(arquivoURL: URL) async throws -> FotoDisponivel {
        let arquivoPreparado = try prepararImagemParaEnvio(arquivoURL)
        var manterArquivoTemporario = false
        defer {
            if !manterArquivoTemporario {
                try? gerenciadorArquivos.removeItem(at: arquivoPreparado)
            }
        }

        try await validarSegurancaDaFoto(arquivoPreparado)

        let contexto = try await autorizacao.contextoAtual()
        let registroUsuario = try await cliente.buscar(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        var usuario = try ConversorRegistroCloudKit.usuario(de: registroUsuario)
        let foto = Foto(
            id: UUID(),
            enviadaPorID: contexto.usuario.id,
            destino: .perfil(contexto.usuario.id),
            textoAlternativo: nil,
            criadaEm: Date()
        )
        let fotoAnteriorID = usuario.fotoID
        usuario.fotoID = foto.id
        usuario.atualizadoEm = Date()

        let registroFoto = try ConversorRegistroCloudKit.registro(
            de: foto,
            arquivoURL: arquivoPreparado
        )
        try await salvarFotoSeNecessario(registroFoto, foto: foto)

        let registroUsuarioAtualizado = try ConversorRegistroCloudKit.registro(
            de: usuario,
            existente: registroUsuario
        )
        let usuarioAtualizado: Usuario
        do {
            usuarioAtualizado = try ConversorRegistroCloudKit.usuario(
                de: try await cliente.salvar(registroUsuarioAtualizado)
            )
        } catch {
            let erroOriginal = error
            if let registroRemoto = try? await cliente.buscar(
                IdentificadorCloudKit.usuario(usuario.id),
                tipo: .usuario
            ),
            let usuarioRemoto = try? ConversorRegistroCloudKit.usuario(de: registroRemoto),
            usuarioRemoto.fotoID == foto.id {
                usuarioAtualizado = usuarioRemoto
            } else {
                try? await cliente.excluir(registroFoto.recordID, tipo: .fotoPerfil)
                throw erroOriginal
            }
        }

        sessao.restaurar(usuarioAtualizado)
        // O perfil já foi gravado no CloudKit. Falha no cache local não pode
        // transformar essa gravação bem-sucedida em erro de envio.
        let arquivoEmCache: URL
        if let copiado = try? copiarParaCache(arquivoPreparado, fotoID: foto.id) {
            arquivoEmCache = copiado
        } else {
            manterArquivoTemporario = true
            arquivoEmCache = arquivoPreparado
        }
        if let fotoAnteriorID {
            await excluirFotoPerfilSeExistir(fotoAnteriorID)
            removerDoCache(fotoID: fotoAnteriorID)
        }
        return FotoDisponivel(foto: foto, arquivoURL: arquivoEmCache)
    }

    func buscarFotoPerfilAtual() async throws -> FotoDisponivel? {
        let contexto = try await autorizacao.contextoAtual()
        let registroUsuario = try await cliente.buscar(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        var usuario = try ConversorRegistroCloudKit.usuario(de: registroUsuario)
        guard let fotoID = usuario.fotoID else {
            sessao.restaurar(usuario)
            return nil
        }

        let registroFoto: CKRecord
        do {
            registroFoto = try await cliente.buscar(
                IdentificadorCloudKit.foto(fotoID),
                tipo: .fotoPerfil
            )
        } catch ErroCloudKit.registroNaoEncontrado {

            usuario.fotoID = nil
            usuario.atualizadoEm = Date()
            let registroCorrigido = try ConversorRegistroCloudKit.registro(
                de: usuario,
                existente: registroUsuario
            )
            let registroSalvo = try await cliente.salvar(registroCorrigido)
            sessao.restaurar(
                try ConversorRegistroCloudKit.usuario(de: registroSalvo)
            )
            removerDoCache(fotoID: fotoID)
            return nil
        }
        let fotoComArquivo = try ConversorRegistroCloudKit.foto(de: registroFoto)
        guard case .perfil(let usuarioID) = fotoComArquivo.foto.destino,
              usuarioID == contexto.usuario.id else {
            throw ErroCRUD.respostaInconsistente
        }
        sessao.restaurar(usuario)
        return FotoDisponivel(
            foto: fotoComArquivo.foto,
            arquivoURL: try copiarParaCache(
                fotoComArquivo.arquivoURL,
                fotoID: fotoComArquivo.foto.id
            )
        )
    }

    func removerFotoPerfil() async throws {
        let contexto = try await autorizacao.contextoAtual()
        let registroUsuario = try await cliente.buscar(
            IdentificadorCloudKit.usuario(contexto.usuario.id),
            tipo: .usuario
        )
        var usuario = try ConversorRegistroCloudKit.usuario(de: registroUsuario)
        guard let fotoID = usuario.fotoID else { return }

        usuario.fotoID = nil
        usuario.atualizadoEm = Date()
        let alterado = try ConversorRegistroCloudKit.registro(
            de: usuario,
            existente: registroUsuario
        )
        let registroSalvo = try await cliente.salvar(alterado)
        sessao.restaurar(try ConversorRegistroCloudKit.usuario(de: registroSalvo))
        await excluirFotoPerfilSeExistir(fotoID)
        removerDoCache(fotoID: fotoID)
    }

    private func prepararImagemParaEnvio(_ arquivoURL: URL) throws -> URL {
        guard gerenciadorArquivos.fileExists(atPath: arquivoURL.path) else {
            throw ErroModeracaoFotos.arquivoNaoEncontrado
        }

        let tamanhoOriginal = try? arquivoURL.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize
        guard let tamanhoOriginal,
              tamanhoOriginal > 0,
              tamanhoOriginal <= Self.limiteBytesOriginais else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "A foto original deve ter no máximo 30 MB."
            )
        }

        let opcoesFonte = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let fonte = CGImageSourceCreateWithURL(
            arquivoURL as CFURL,
            opcoesFonte
        ),
        CGImageSourceGetCount(fonte) > 0,
        let propriedades = CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil)
            as? [CFString: Any],
        let largura = propriedades[kCGImagePropertyPixelWidth] as? NSNumber,
        let altura = propriedades[kCGImagePropertyPixelHeight] as? NSNumber,
        largura.intValue > 0,
        altura.intValue > 0,
        largura.intValue <= Self.limiteMaiorDimensaoOriginal,
        altura.intValue <= Self.limiteMaiorDimensaoOriginal else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Selecione uma imagem válida com dimensões de até 20.000 pixels."
            )
        }

        let maiorDimensaoOriginal = max(largura.intValue, altura.intValue)
        let maiorDimensaoDaSaida = min(
            Self.maiorDimensaoPreparada,
            maiorDimensaoOriginal
        )
        let opcoesMiniatura: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maiorDimensaoDaSaida,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let miniatura = CGImageSourceCreateThumbnailAtIndex(
            fonte,
            0,
            opcoesMiniatura as CFDictionary
        ) else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Não foi possível preparar a imagem selecionada."
            )
        }
        let imagem = try ImagemOpacaJPEG.converter(miniatura)

        let diretorio = gerenciadorArquivos.temporaryDirectory
            .appendingPathComponent("UploadsMakerSpot", isDirectory: true)
        do {
            try gerenciadorArquivos.createDirectory(
                at: diretorio,
                withIntermediateDirectories: true
            )
        } catch {
            throw ErroCloudKit.arquivoIndisponivel
        }

        let destino = diretorio
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("jpg")
        guard let gravador = CGImageDestinationCreateWithURL(
            destino as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ErroCloudKit.arquivoIndisponivel
        }

        let propriedadesSaida: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]
        CGImageDestinationAddImage(
            gravador,
            imagem,
            propriedadesSaida as CFDictionary
        )
        guard CGImageDestinationFinalize(gravador),
              let tamanhoPreparado = try? destino.resourceValues(
                forKeys: [.fileSizeKey]
              ).fileSize,
              tamanhoPreparado > 0,
              tamanhoPreparado <= Self.limiteBytesPreparados else {
            try? gerenciadorArquivos.removeItem(at: destino)
            throw ErroCRUD.dadosInvalidos(
                descricao: "Não foi possível reduzir a foto para o limite de 10 MB."
            )
        }
        return destino
    }

    private func copiarParaCache(_ origem: URL, fotoID: UUID) throws -> URL {
        let diretorio = try diretorioDeFotos()
        let extensao = origem.pathExtension.isEmpty ? "img" : origem.pathExtension.lowercased()
        let destino = diretorio
            .appendingPathComponent(fotoID.uuidString.lowercased())
            .appendingPathExtension(extensao)

        if origem.standardizedFileURL == destino.standardizedFileURL {
            return destino
        }
        if gerenciadorArquivos.fileExists(atPath: destino.path) {
            try gerenciadorArquivos.removeItem(at: destino)
        }
        do {
            try gerenciadorArquivos.copyItem(at: origem, to: destino)
            return destino
        } catch {
            throw ErroCloudKit.arquivoIndisponivel
        }
    }

    private func removerDoCache(fotoID: UUID) {
        guard let diretorio = try? diretorioDeFotos(),
              let arquivos = try? gerenciadorArquivos.contentsOfDirectory(
                at: diretorio,
                includingPropertiesForKeys: nil
              ) else {
            return
        }

        let prefixo = fotoID.uuidString.lowercased() + "."
        for arquivo in arquivos where arquivo.lastPathComponent.hasPrefix(prefixo) {
            try? gerenciadorArquivos.removeItem(at: arquivo)
        }
    }

    private func validarSegurancaDaFoto(_ arquivoURL: URL) async throws {
        let triagem: ResultadoTriagemFoto
        do {
            triagem = try await moderacao.analisarImagem(em: arquivoURL)
        } catch {
            throw ErroCRUD.moderacaoLocalIndisponivel
        }

        switch triagem {
        case .bloqueadaPorConteudoSensivel:
            throw ErroCRUD.conteudoFotoNaoPermitido
        case .analiseNaoHabilitadaNoSistema, .conteudoSensivelNaoDetectado:
            return
        }
    }

    private func salvarFotoSeNecessario(
        _ registro: CKRecord,
        foto: Foto
    ) async throws {
        do {
            _ = try await cliente.salvar(registro)
        } catch {
            let erroOriginal = error
            guard let existente = try? await cliente.buscar(
                registro.recordID,
                tipo: tipoRegistro(da: foto)
            ),
            let fotoExistente = try? ConversorRegistroCloudKit.foto(de: existente).foto,
            fotoExistente == foto else {
                throw erroOriginal
            }
        }
    }

    private func tipoRegistro(da foto: Foto) -> TipoRegistroCloudKit {
        switch foto.destino {
        case .spot: return .fotoSpot
        case .perfil: return .fotoPerfil
        }
    }

    private func excluirFotoPerfilSeExistir(_ fotoID: UUID) async {
        try? await cliente.excluir(
            IdentificadorCloudKit.foto(fotoID),
            tipo: .fotoPerfil
        )
    }

    private func diretorioDeFotos() throws -> URL {
        guard let cache = gerenciadorArquivos.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw ErroCloudKit.arquivoIndisponivel
        }
        let diretorio = cache.appendingPathComponent("FotosMakerSpot", isDirectory: true)
        do {
            try gerenciadorArquivos.createDirectory(
                at: diretorio,
                withIntermediateDirectories: true
            )
            return diretorio
        } catch {
            throw ErroCloudKit.arquivoIndisponivel
        }
    }

}
