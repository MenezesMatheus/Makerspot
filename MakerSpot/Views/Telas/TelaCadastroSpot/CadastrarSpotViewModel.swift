//
//  CadastrarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CoreTransferable
import Foundation
import ImageIO
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct FotoCadastroSpot: Identifiable, Equatable {
    let id = UUID()
    let arquivoURL: URL
    let miniaturaURL: URL
}

struct FotoImportadaCadastro: Transferable {
    let foto: FotoCadastroSpot

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { recebido in
            let gerenciador = FileManager.default
            let tamanho = try recebido.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard tamanho > 0, tamanho <= 30 * 1_024 * 1_024 else {
                throw ErroCRUD.dadosInvalidos(descricao: "Cada foto deve ter até 30 MB.")
            }

            let base = gerenciador.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let extensao = recebido.file.pathExtension.isEmpty ? "img" : recebido.file.pathExtension
            let arquivo = base.appendingPathExtension(extensao)
            let miniatura = base.appendingPathExtension("thumb.jpg")

            do {
                try gerenciador.copyItem(at: recebido.file, to: arquivo)
                guard let fonte = CGImageSourceCreateWithURL(arquivo as CFURL, nil),
                      let imagem = CGImageSourceCreateThumbnailAtIndex(fonte, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 480
                      ] as CFDictionary),
                      let destino = CGImageDestinationCreateWithURL(
                        miniatura as CFURL,
                        UTType.jpeg.identifier as CFString,
                        1,
                        nil
                      ) else {
                    throw ErroCRUD.dadosInvalidos(descricao: "Selecione uma imagem válida.")
                }
                CGImageDestinationAddImage(destino, imagem, nil)
                guard CGImageDestinationFinalize(destino) else {
                    throw ErroCRUD.dadosInvalidos(
                        descricao: "Não foi possível preparar a foto."
                    )
                }
                try Task.checkCancellation()
                return Self(foto: FotoCadastroSpot(
                    arquivoURL: arquivo,
                    miniaturaURL: miniatura
                ))
            } catch {
                try? gerenciador.removeItem(at: arquivo)
                try? gerenciador.removeItem(at: miniatura)
                throw error
            }
        }
    }
}

struct HorarioFuncionamentoCadastro: Identifiable {
    let id = UUID()
    var dias: Set<DiaSemana> = []
    var abertura: Date
    var fechamento: Date

    init(fusoHorario: TimeZone) {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fusoHorario
        abertura = calendario.date(from: DateComponents(
            year: 2001,
            month: 1,
            day: 15,
            hour: 9
        ))!
        fechamento = calendario.date(from: DateComponents(
            year: 2001,
            month: 1,
            day: 15,
            hour: 18
        ))!
    }

    var resumoDias: String {
        if dias.isEmpty { return "Selecionar" }
        if dias.count == 7 { return "Todos os dias" }
        if dias == Set([.segunda, .terca, .quarta, .quinta, .sexta]) {
            return "Seg. a sex."
        }
        return DiaSemana.allCases
            .filter { dias.contains($0) }
            .map(Self.nomeAbreviado)
            .joined(separator: ", ")
    }

    func intervalo(fusoHorario: TimeZone) -> IntervaloFuncionamento {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fusoHorario
        let inicio = calendario.dateComponents([.hour, .minute], from: abertura)
        let fim = calendario.dateComponents([.hour, .minute], from: fechamento)
        let horaInicio = inicio.hour ?? 0
        let minutoInicio = inicio.minute ?? 0
        let horaFim = fim.hour ?? 0
        let minutoFim = fim.minute ?? 0
        return IntervaloFuncionamento(
            abertura: HorarioLocal(hora: horaInicio, minuto: minutoInicio),
            fechamento: HorarioLocal(hora: horaFim, minuto: minutoFim),
            terminaNoDiaSeguinte: horaFim * 60 + minutoFim < horaInicio * 60 + minutoInicio
        )
    }

    nonisolated private static func nomeAbreviado(_ dia: DiaSemana) -> String {
        switch dia {
        case .segunda: return "Seg."
        case .terca: return "Ter."
        case .quarta: return "Qua."
        case .quinta: return "Qui."
        case .sexta: return "Sex."
        case .sabado: return "Sáb."
        case .domingo: return "Dom."
        }
    }
}

struct OpcaoPaisSpot: Identifiable, Sendable {
    let codigo: String
    let nome: String

    var id: String { codigo }
}

enum OpcoesFormularioSpot {
    static let paises: [OpcaoPaisSpot] = {
        let locale = Locale(identifier: "pt_BR")
        return Locale.Region.isoRegions.compactMap { regiao in
            guard regiao.identifier.count == 2,
                  let nome = locale.localizedString(forRegionCode: regiao.identifier) else {
                return nil
            }
            return OpcaoPaisSpot(codigo: regiao.identifier, nome: nome)
        }
        .sorted { $0.nome.localizedCompare($1.nome) == .orderedAscending }
    }()
}

@MainActor
@Observable
final class CadastrarSpotViewModel {
    var tipoSelecionado: TipoSpot = .evento
    var titulo = ""
    var descricao = ""
    var endereco = Endereco(
        logradouro: "", numero: "", complemento: nil, bairro: nil,
        cidade: "", estado: "", codigoPostal: nil, codigoPais: "BR"
    )
    var mostraEndereco = false
    var mostraTelefone = false
    var telefone = ""
    var mostraURL = false
    var textoURL = ""
    var inicio: Date
    var termino: Date
    var horariosFuncionamento: [HorarioFuncionamentoCadastro] = []
    let fusoHorario: TimeZone
    let telefoneSugerido: String?
    let paises = OpcoesFormularioSpot.paises

    private(set) var fotos: [FotoCadastroSpot] = []
    private(set) var spotCriado: Spot?
    private(set) var quantidadeFotosProcessadas = 0
    private(set) var estaCadastrando = false
    private(set) var estaImportandoFotos = false
    private(set) var mensagemDeErro: String?
    private var etapa: EtapaCadastro = .formulario

    private enum EtapaCadastro {
        case formulario, confirmacao, sucesso, concluido
    }

    var mostraConfirmacao: Bool {
        get { etapa == .confirmacao }
        set { if !newValue && etapa == .confirmacao { etapa = .formulario } }
    }

    var mostraSucesso: Bool {
        get { etapa == .sucesso }
        set { if !newValue && etapa == .sucesso { etapa = .concluido } }
    }

    var deveFechar: Bool { etapa == .concluido }
    var mostraPopup: Bool { mostraConfirmacao || mostraSucesso }
    var bloqueiaInteracao: Bool { estaOcupado || mostraPopup || deveFechar }
    var temFotosPendentes: Bool {
        spotCriado != nil && fotos.contains { !fotoFoiEnviada($0) }
    }

    var nomeTipo: String { tipoSelecionado == .evento ? "evento" : "espaço" }
    var nomeTipoCapitalizado: String { tipoSelecionado == .evento ? "Evento" : "Espaço" }
    var tituloSucesso: String { "\(nomeTipoCapitalizado) cadastrado com sucesso!" }

    var tituloConfirmacao: String {
        if spotCriado != nil {
            return "Deseja concluir o envio das fotos do \(nomeTipo)?"
        }
        let nome = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Deseja cadastrar o \(nomeTipo) \(nome)?"
    }

    @ObservationIgnored private let criarSpot: (DadosSpot) async throws -> Spot
    @ObservationIgnored private let enviarFoto: (URL, UUID) async throws -> Spot
    @ObservationIgnored private var arquivosEnviados: Set<URL> = []
    @ObservationIgnored private var dadosEnviados: DadosSpot?

    init(
        telefoneSugerido: String? = nil,
        agora: Date = Date(),
        fusoHorario: TimeZone = .current,
        criarSpot: @escaping (DadosSpot) async throws -> Spot,
        enviarFoto: @escaping (URL, UUID) async throws -> Spot
    ) {
        self.telefoneSugerido = ApoioCRUD.textoOpcional(telefoneSugerido)
        self.inicio = agora
        self.termino = agora.addingTimeInterval(3_600)
        self.fusoHorario = fusoHorario
        self.criarSpot = criarSpot
        self.enviarFoto = enviarFoto
    }

    convenience init(
        spotCRUD: SpotCRUD,
        fotoCRUD: FotoCRUD,
        telefoneSugerido: String? = nil
    ) {
        self.init(
            telefoneSugerido: telefoneSugerido,
            criarSpot: { try await spotCRUD.criar($0) },
            enviarFoto: { arquivo, id in
                try await fotoCRUD.enviarParaSpot(arquivoURL: arquivo, spotID: id).spotAtualizado
            }
        )
    }

    convenience init(sessao: SessaoUsuario) {
        self.init(
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao),
            telefoneSugerido: sessao.usuarioAtual?.telefonePadrao
        )
    }

    var estaOcupado: Bool { estaCadastrando || estaImportandoFotos }

    var textoProgresso: String {
        if estaImportandoFotos { return "Preparando fotos…" }
        return "Salvando \(nomeTipo)… \(quantidadeFotosProcessadas)/\(fotos.count) fotos"
    }

    var podeCadastrar: Bool {
        !estaOcupado && !mostraSucesso && !deveFechar
            && (spotCriado != nil || (try? dadosDoFormulario()) != nil)
    }

    func solicitarConfirmacao() {
        guard podeCadastrar else { return }
        etapa = .confirmacao
    }

    func confirmarCadastro() async {
        guard podeCadastrar else { return }
        etapa = .formulario
        if await cadastrarFormulario() != nil { etapa = .sucesso }
    }

    func dadosDoFormulario() throws -> DadosSpot {
        guard mostraEndereco else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Adicione o endereço do \(nomeTipo)."
            )
        }

        let detalhes: DetalhesSpot
        switch tipoSelecionado {
        case .evento:
            detalhes = .evento(Evento(
                inicio: inicio,
                termino: termino,
                fusoHorarioID: fusoHorario.identifier
            ))
        case .espaco:
            detalhes = .espaco(Espaco(funcionamento: try funcionamentoSemanal()))
        }

        let url = try urlInformada()
        return try ValidadorSpotCRUD.validarENormalizar(DadosSpot(
            nome: titulo,
            descricao: descricao,
            endereco: endereco,
            telefone: mostraTelefone ? telefone : "",
            link: url,
            redesSociais: [],
            detalhes: detalhes
        ))
    }

    func adicionarHorario() {
        guard !bloqueiaInteracao, spotCriado == nil else { return }
        horariosFuncionamento.append(
            HorarioFuncionamentoCadastro(fusoHorario: fusoHorario)
        )
    }

    func removerHorario(id: UUID) {
        guard !bloqueiaInteracao, spotCriado == nil else { return }
        horariosFuncionamento.removeAll { $0.id == id }
    }

    var erroFuncionamento: String? {
        guard !horariosFuncionamento.isEmpty else { return nil }
        do {
            _ = try funcionamentoSemanal()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func usarTelefoneDaConta() {
        guard let telefoneSugerido else { return }
        mostraTelefone = true
        telefone = telefoneSugerido
    }

    func removerTelefone() {
        telefone = ""
        mostraTelefone = false
    }

    func removerURL() {
        textoURL = ""
        mostraURL = false
    }

    private func iniciarImportacao() -> Bool {
        guard !estaOcupado, spotCriado == nil else { return false }
        estaImportandoFotos = true
        return true
    }

    func adicionarFoto(_ foto: FotoCadastroSpot) { fotos.append(foto) }

    func fotoFoiEnviada(_ foto: FotoCadastroSpot) -> Bool {
        arquivosEnviados.contains(foto.arquivoURL)
    }

    func removerFoto(_ foto: FotoCadastroSpot) {
        guard !estaOcupado, !fotoFoiEnviada(foto) else { return }
        apagarArquivos(da: foto)
        fotos.removeAll { $0.id == foto.id }
    }

    private func registrarErroDaFoto(_ error: Error) {
        mensagemDeErro = "Não foi possível adicionar uma das fotos. \(error.localizedDescription)"
    }

    func importarFotos(_ itens: [PhotosPickerItem]) async {
        guard !itens.isEmpty, iniciarImportacao() else { return }
        defer { estaImportandoFotos = false }
        for item in itens {
            do {
                try Task.checkCancellation()
                guard let importada = try await item.loadTransferable(type: FotoImportadaCadastro.self) else {
                    throw ErroCRUD.dadosInvalidos(descricao: "Não foi possível ler a imagem selecionada.")
                }
                if Task.isCancelled {
                    apagarArquivos(da: importada.foto)
                    return
                }
                adicionarFoto(importada.foto)
            } catch is CancellationError {
                return
            } catch {
                registrarErroDaFoto(error)
            }
        }
    }

    @discardableResult
    func cadastrarFormulario() async -> Spot? {
        guard !estaOcupado, !mostraSucesso, !deveFechar else { return nil }
        do {
            let dados = try dadosEnviados ?? dadosDoFormulario()
            return await cadastrar(dados: dados, fotos: fotos.map(\.arquivoURL))
        } catch {
            mensagemDeErro = error.localizedDescription
            return nil
        }
    }

    // Guarda o Spot e os uploads concluídos para retomar falhas parciais sem duplicá-los.
    @discardableResult
    func cadastrar(dados: DadosSpot, fotos: [URL] = []) async -> Spot? {
        guard !estaOcupado else { return nil }
        estaCadastrando = true
        mensagemDeErro = nil
        defer { estaCadastrando = false }

        do {
            if let dadosEnviados, dadosEnviados != dados {
                throw ErroCRUD.dadosInvalidos(
                    descricao: "Conclua o envio das fotos antes de editar este \(nomeTipo)."
                )
            }
            var spot: Spot
            if let existente = spotCriado {
                spot = existente
            } else {
                spot = try await criarSpot(dados)
                spotCriado = spot
                dadosEnviados = dados
            }
            for arquivo in fotos where !arquivosEnviados.contains(arquivo) {
                try Task.checkCancellation()
                spot = try await enviarFoto(arquivo, spot.id)
                spotCriado = spot
                arquivosEnviados.insert(arquivo)
                quantidadeFotosProcessadas = arquivosEnviados.count
            }
            return spot
        } catch {
            let motivo = error is CancellationError ? "O envio foi interrompido." : error.localizedDescription
            mensagemDeErro = spotCriado == nil ? motivo
                : "O \(nomeTipo) já foi criado, mas ainda há fotos pendentes. \(motivo) Tente novamente ou remova a foto pendente."
            return nil
        }
    }

    func limparErro() { mensagemDeErro = nil }

    func descartarArquivosTemporarios() {
        for foto in fotos { apagarArquivos(da: foto) }
        fotos = []
    }

    private func urlInformada() throws -> URL? {
        guard mostraURL else { return nil }
        let texto = textoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return nil }
        guard !texto.contains(where: \.isWhitespace), let url = URL(string: texto) else {
            throw ErroCRUD.dadosInvalidos(descricao: "Informe uma URL válida.")
        }
        try ApoioCRUD.validarURLWeb(url, nome: "divulgação")
        return url
    }

    private func funcionamentoSemanal() throws -> FuncionamentoSemanal {
        guard !horariosFuncionamento.isEmpty else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Adicione os dias e horários de funcionamento."
            )
        }
        guard horariosFuncionamento.allSatisfy({ !$0.dias.isEmpty }) else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Selecione os dias de cada horário de funcionamento."
            )
        }

        // Agrupa os intervalos por dia para respeitar o formato do CRUD.
        let dias = DiaSemana.allCases.compactMap { dia -> FuncionamentoDia? in
            let intervalos = horariosFuncionamento
                .filter { $0.dias.contains(dia) }
                .map { $0.intervalo(fusoHorario: fusoHorario) }
                .sorted { minutos($0.abertura) < minutos($1.abertura) }
            guard !intervalos.isEmpty else { return nil }
            return FuncionamentoDia(dia: dia, intervalos: intervalos)
        }
        let funcionamento = FuncionamentoSemanal(
            fusoHorarioID: fusoHorario.identifier,
            dias: dias
        )
        try ValidadorSpotCRUD.validarFuncionamento(funcionamento)
        return funcionamento
    }

    private func minutos(_ horario: HorarioLocal) -> Int {
        horario.hora * 60 + horario.minuto
    }

    private func apagarArquivos(da foto: FotoCadastroSpot) {
        try? FileManager.default.removeItem(at: foto.arquivoURL)
        try? FileManager.default.removeItem(at: foto.miniaturaURL)
    }
}
