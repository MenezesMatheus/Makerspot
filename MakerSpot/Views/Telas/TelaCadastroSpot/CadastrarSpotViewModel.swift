//
//  CadastrarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

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

struct FotoImportadaCadastro {
    let foto: FotoCadastroSpot

    static func importar(_ dados: Data) async throws -> Self {
        guard !dados.isEmpty, dados.count <= 30 * 1_024 * 1_024 else {
            throw ErroCRUD.dadosInvalidos(descricao: "Cada foto deve ter até 30 MB.")
        }

        guard let fonte = CGImageSourceCreateWithData(dados as CFData, nil),
              CGImageSourceGetCount(fonte) > 0,
              let propriedades = CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil)
                as? [CFString: Any],
              let largura = propriedades[kCGImagePropertyPixelWidth] as? NSNumber,
              let altura = propriedades[kCGImagePropertyPixelHeight] as? NSNumber,
              largura.intValue > 0,
              altura.intValue > 0,
              largura.intValue <= 20_000,
              altura.intValue <= 20_000 else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Selecione uma imagem válida com dimensões de até 20.000 pixels."
            )
        }

        let extensao: String
        if let tipoFonte = CGImageSourceGetType(fonte) {
            extensao = UTType(tipoFonte as String)?.preferredFilenameExtension
                ?? "img"
        } else {
            extensao = "img"
        }
        let gerenciador = FileManager.default
        let base = gerenciador.temporaryDirectory
            .appendingPathComponent(UUID().uuidString.lowercased())
        let arquivo = base.appendingPathExtension(extensao)
        let miniatura = base.appendingPathExtension("thumb.jpg")

        do {
            try dados.write(to: arquivo, options: .atomic)
            // A foto só ganha miniatura e entra no formulário após a análise.
            try await ModeracaoFotos().validarParaAnexar(em: arquivo)
            guard let imagem = CGImageSourceCreateThumbnailAtIndex(fonte, 0, [
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
            let imagemSemAlfa = try ImagemOpacaJPEG.converter(imagem)
            CGImageDestinationAddImage(destino, imagemSemAlfa, nil)
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
    private(set) var estaCadastrando = false
    private(set) var estaImportandoFotos = false
    private(set) var mensagemDeErro: String?
    private(set) var mostrarPendencias = false
    private var etapa: EtapaCadastro = .formulario

    private enum EtapaCadastro {
        case formulario, confirmacao, concluido
    }

    var mostraConfirmacao: Bool {
        get { etapa == .confirmacao }
        set { if !newValue && etapa == .confirmacao { etapa = .formulario } }
    }

    var deveFechar: Bool { etapa == .concluido }
    var mostraPopup: Bool { mostraConfirmacao || mensagemDeErro != nil }
    var bloqueiaInteracao: Bool { estaOcupado || mostraPopup || deveFechar }
    var nomeTipo: String { tipoSelecionado == .evento ? "evento" : "espaço" }
    var tituloPendente: Bool { mostrarPendencias && textoAusente(titulo) }
    var telefonePendente: Bool {
        mostrarPendencias && (!mostraTelefone || textoAusente(telefone))
    }
    var enderecoPendente: Bool { mostrarPendencias && !mostraEndereco }
    var ruaPendente: Bool { mostrarPendencias && textoAusente(endereco.logradouro) }
    var numeroPendente: Bool { mostrarPendencias && textoAusente(endereco.numero) }
    var bairroPendente: Bool { mostrarPendencias && textoAusente(endereco.bairro ?? "") }
    var cidadePendente: Bool { mostrarPendencias && textoAusente(endereco.cidade) }
    var estadoPendente: Bool { mostrarPendencias && textoAusente(endereco.estado) }
    var cepPendente: Bool { mostrarPendencias && textoAusente(endereco.codigoPostal ?? "") }
    var paisPendente: Bool { mostrarPendencias && textoAusente(endereco.codigoPais) }
    var funcionamentoPendente: Bool {
        mostrarPendencias && tipoSelecionado == .espaco &&
            (horariosFuncionamento.isEmpty || horariosFuncionamento.contains { $0.dias.isEmpty })
    }
    var fotoPendente: Bool { mostrarPendencias && fotos.isEmpty }

    var camposObrigatoriosAusentes: [String] {
        var campos: [String] = []
        if spotCriado == nil {
            if textoAusente(titulo) { campos.append("título") }
            if !mostraTelefone || textoAusente(telefone) { campos.append("telefone") }
            if !mostraEndereco {
                campos.append("endereço")
            } else {
                if textoAusente(endereco.logradouro) { campos.append("rua") }
                if textoAusente(endereco.numero) { campos.append("número") }
                if textoAusente(endereco.bairro ?? "") { campos.append("bairro") }
                if textoAusente(endereco.cidade) { campos.append("cidade") }
                if textoAusente(endereco.estado) { campos.append("estado") }
                if textoAusente(endereco.codigoPostal ?? "") { campos.append("CEP") }
                if textoAusente(endereco.codigoPais) { campos.append("país") }
            }
            if tipoSelecionado == .espaco &&
                (horariosFuncionamento.isEmpty || horariosFuncionamento.contains(where: { $0.dias.isEmpty })) {
                campos.append("dias de funcionamento")
            }
        }
        if fotos.isEmpty { campos.append("foto") }
        return campos
    }

    var tituloConfirmacao: String {
        let nome = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Deseja cadastrar o \(nomeTipo) \(nome)?"
    }

    @ObservationIgnored private let criarSpot: (DadosSpot, UUID) async throws -> Spot
    @ObservationIgnored private let registrarFotos: (Spot, [FotoCadastroSpot]) throws -> Void
    @ObservationIgnored private var aoConcluirCadastro: ((Spot) -> Void)?
    @ObservationIgnored private var dadosEnviados: DadosSpot?
    @ObservationIgnored private var dadosDaTentativa: DadosSpot?
    @ObservationIgnored private var idDaTentativa: UUID?

    init(
        telefoneSugerido: String? = nil,
        agora: Date = Date(),
        fusoHorario: TimeZone = .current,
        criarSpot: @escaping (DadosSpot, UUID) async throws -> Spot,
        registrarFotos: @escaping (Spot, [FotoCadastroSpot]) throws -> Void
    ) {
        self.telefoneSugerido = ApoioCRUD.textoOpcional(telefoneSugerido)
        self.inicio = agora
        self.termino = agora.addingTimeInterval(3_600)
        self.fusoHorario = fusoHorario
        self.criarSpot = criarSpot
        self.registrarFotos = registrarFotos
    }

    convenience init(sessao: SessaoUsuario) {
        let spotCRUD = SpotCRUD(sessao: sessao)
        self.init(
            telefoneSugerido: sessao.usuarioAtual?.telefonePadrao,
            criarSpot: { dados, id in try await spotCRUD.criar(dados, id: id) },
            registrarFotos: { spot, fotos in
                try sessao.enviosFotosCadastro.registrar(spot: spot, fotos: fotos)
            }
        )
        aoConcluirCadastro = { [weak sessao] spot in
            sessao?.alteracoesSpots.confirmarCadastro(spot)
            sessao?.enviosFotosCadastro.retomarPendentes()
        }
    }

    var estaOcupado: Bool { estaCadastrando || estaImportandoFotos }

    var textoProgresso: String {
        if estaImportandoFotos { return "Verificando fotos…" }
        return "Salvando \(nomeTipo)…"
    }

    var podeCadastrar: Bool {
        !estaOcupado && !mostraPopup && !deveFechar
    }

    func solicitarConfirmacao() {
        guard podeCadastrar else { return }
        mostrarPendencias = true
        guard camposObrigatoriosAusentes.isEmpty else { return }
        do {
            _ = try dadosEnviados ?? dadosDoFormulario()
        } catch {
            mensagemDeErro = error.localizedDescription
            return
        }
        etapa = .confirmacao
    }

    func confirmarCadastro() async {
        guard podeCadastrar else { return }
        etapa = .formulario
        if await cadastrarFormulario() != nil { etapa = .concluido }
    }

    func notificarCadastroConcluido() {
        guard deveFechar, let spotCriado else { return }
        aoConcluirCadastro?(spotCriado)
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
        return try ValidadorSpotCRUD.validarCadastro(DadosSpot(
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
        guard !estaOcupado, !deveFechar else { return false }
        estaImportandoFotos = true
        return true
    }

    private func adicionarFoto(_ foto: FotoCadastroSpot) { fotos.append(foto) }

    func removerFoto(_ foto: FotoCadastroSpot) {
        guard !estaOcupado, !deveFechar else { return }
        apagarArquivos(da: foto)
        fotos.removeAll { $0.id == foto.id }
    }

    private func registrarErroDaFoto(_ error: Error) {
        if case ErroModeracaoFotos.analiseDesativada = error {
            mensagemDeErro = error.localizedDescription
        } else {
            mensagemDeErro = "Não foi possível adicionar uma das fotos. \(error.localizedDescription)"
        }
    }

    func importarFotos(_ itens: [PhotosPickerItem]) async {
        guard !itens.isEmpty, iniciarImportacao() else { return }
        defer { estaImportandoFotos = false }
        for item in itens {
            do {
                try Task.checkCancellation()
                guard let dados = try await item.loadTransferable(type: Data.self) else {
                    throw ErroCRUD.dadosInvalidos(descricao: "Não foi possível ler a imagem selecionada.")
                }
                let importada = try await FotoImportadaCadastro.importar(dados)
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
        guard !estaOcupado, !deveFechar else { return nil }
        do {
            let dados = try dadosEnviados ?? dadosDoFormulario()
            return await cadastrar(dados: dados, fotos: fotos)
        } catch {
            mensagemDeErro = error.localizedDescription
            return nil
        }
    }

    // Só aguarda os dados do Spot; o envio das fotos continua após sair do formulário.
    @discardableResult
    func cadastrar(dados: DadosSpot, fotos: [FotoCadastroSpot] = []) async -> Spot? {
        guard !estaOcupado else { return nil }
        guard !fotos.isEmpty else {
            mostrarPendencias = true
            mensagemDeErro = "Adicione ao menos uma foto para cadastrar o \(nomeTipo)."
            return nil
        }
        estaCadastrando = true
        mensagemDeErro = nil
        defer { estaCadastrando = false }

        do {
            if let dadosEnviados, dadosEnviados != dados {
                throw ErroCRUD.dadosInvalidos(
                    descricao: "Conclua o cadastro antes de editar este \(nomeTipo)."
                )
            }
            let spot: Spot
            if let existente = spotCriado {
                spot = existente
            } else {
                if dadosDaTentativa != dados {
                    dadosDaTentativa = dados
                    idDaTentativa = UUID()
                }
                let id = idDaTentativa ?? UUID()
                idDaTentativa = id
                spot = try await criarSpot(dados, id)
                spotCriado = spot
                dadosEnviados = dados
            }
            try registrarFotos(spot, fotos)
            return spot
        } catch {
            let motivo = error is CancellationError ? "O cadastro foi interrompido." : error.localizedDescription
            if spotCriado == nil {
                mensagemDeErro = motivo
            } else {
                mensagemDeErro = "O \(nomeTipo) foi salvo, mas não foi possível preparar as fotos. \(motivo) Tente novamente ou adicione fotos depois em Editar Spot."
            }
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

    private func textoAusente(_ valor: String) -> Bool {
        valor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func apagarArquivos(da foto: FotoCadastroSpot) {
        try? FileManager.default.removeItem(at: foto.arquivoURL)
        try? FileManager.default.removeItem(at: foto.miniaturaURL)
    }
}
