//
//  EditarSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class EditarSpotViewModel {
    private(set) var spot: Spot
    let tipo: TipoSpot
    let fusoHorario: TimeZone
    let telefoneSugerido: String?
    let paises = OpcoesFormularioSpot.paises

    var titulo: String
    var descricao: String
    var endereco: Endereco
    var mostraEndereco = true
    var mostraTelefone: Bool
    var telefone: String
    var mostraURL: Bool
    var textoURL: String
    var inicio: Date
    var termino: Date
    var horariosFuncionamento: [HorarioFuncionamentoCadastro]

    private(set) var fotosExistentes: [FotoDisponivel] = []
    private(set) var fotosNovas: [FotoCadastroSpot] = []
    private(set) var estaCarregandoFotos = false
    private(set) var estaImportandoFotos = false
    private(set) var estaSalvando = false
    private(set) var estaExcluindo = false
    private(set) var mensagemDeErro: String?
    private(set) var deveFechar = false
    private(set) var foiExcluido = false

    var mostraConfirmacao = false
    var mostraConfirmacaoExclusao = false

    @ObservationIgnored private let buscarFotosDoSpot: (Spot) async throws -> [FotoDisponivel]
    @ObservationIgnored private let editarSpot: (UUID, DadosSpot) async throws -> Spot
    @ObservationIgnored private let enviarFoto: (URL, UUID) async throws -> ResultadoEnvioFotoSpot
    @ObservationIgnored private let excluirFoto: (UUID, UUID) async throws -> Spot
    @ObservationIgnored private let excluirSpot: (UUID) async throws -> Void
    @ObservationIgnored private var dadosOriginais: DadosSpot
    private var fotosRemovidas: Set<UUID> = []
    @ObservationIgnored private var fotosEnviadasNestaEdicao: [FotoCadastroSpot] = []
    @ObservationIgnored private var carregouFotos = false

    init(
        spot: Spot,
        telefoneSugerido: String? = nil,
        buscarFotos: @escaping (Spot) async throws -> [FotoDisponivel],
        editarSpot: @escaping (UUID, DadosSpot) async throws -> Spot,
        enviarFoto: @escaping (URL, UUID) async throws -> ResultadoEnvioFotoSpot,
        excluirFoto: @escaping (UUID, UUID) async throws -> Spot,
        excluirSpot: @escaping (UUID) async throws -> Void
    ) {
        let fusoHorario: TimeZone
        let inicio: Date
        let termino: Date
        let horarios: [HorarioFuncionamentoCadastro]

        switch spot.detalhes {
        case .evento(let evento):
            fusoHorario = TimeZone(identifier: evento.fusoHorarioID) ?? .current
            inicio = evento.inicio
            termino = evento.termino
            horarios = []
        case .espaco(let espaco):
            fusoHorario = TimeZone(identifier: espaco.funcionamento.fusoHorarioID) ?? .current
            inicio = Date()
            termino = Date().addingTimeInterval(3_600)
            horarios = Self.horariosEditaveis(
                de: espaco.funcionamento,
                fusoHorario: fusoHorario
            )
        }

        self.spot = spot
        self.tipo = spot.tipo
        self.fusoHorario = fusoHorario
        self.telefoneSugerido = ApoioCRUD.textoOpcional(telefoneSugerido)
        self.titulo = spot.nome
        self.descricao = spot.descricao
        self.endereco = spot.localizacao.endereco
        self.mostraTelefone = !spot.telefone.isEmpty
        self.telefone = spot.telefone
        self.mostraURL = spot.link != nil
        self.textoURL = spot.link?.absoluteString ?? ""
        self.inicio = inicio
        self.termino = termino
        self.horariosFuncionamento = horarios
        self.buscarFotosDoSpot = buscarFotos
        self.editarSpot = editarSpot
        self.enviarFoto = enviarFoto
        self.excluirFoto = excluirFoto
        self.excluirSpot = excluirSpot
        self.dadosOriginais = Self.dados(de: spot)
    }

    convenience init(
        spot: Spot,
        spotCRUD: SpotCRUD,
        fotoCRUD: FotoCRUD,
        telefoneSugerido: String? = nil
    ) {
        self.init(
            spot: spot,
            telefoneSugerido: telefoneSugerido,
            buscarFotos: { try await fotoCRUD.buscarFotos(para: $0) },
            editarSpot: { try await spotCRUD.editar(id: $0, com: $1) },
            enviarFoto: { try await fotoCRUD.enviarParaSpot(arquivoURL: $0, spotID: $1) },
            excluirFoto: { try await fotoCRUD.excluirDoSpot(fotoID: $0, spotID: $1) },
            excluirSpot: { try await spotCRUD.excluir(id: $0) }
        )
    }

    convenience init(spot: Spot, sessao: SessaoUsuario) {
        self.init(
            spot: spot,
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao),
            telefoneSugerido: sessao.usuarioAtual?.telefonePadrao
        )
    }

    var nomeTipo: String { tipo == .evento ? "evento" : "espaço" }
    var nomeTipoCapitalizado: String { tipo == .evento ? "Evento" : "Espaço" }
    var estaOcupado: Bool { estaSalvando || estaExcluindo || estaImportandoFotos }
    var mostraPopup: Bool { mostraConfirmacao || mostraConfirmacaoExclusao }
    var bloqueiaInteracao: Bool { estaOcupado || mostraPopup || deveFechar }

    var textoProgresso: String {
        if estaImportandoFotos { return "Preparando fotos…" }
        if estaExcluindo { return "Excluindo Spot…" }
        return "Salvando alterações…"
    }

    var fotosVisiveis: [FotoDisponivel] {
        fotosExistentes.filter { !fotosRemovidas.contains($0.foto.id) }
    }

    var possuiFotosVisiveis: Bool {
        !fotosVisiveis.isEmpty || !fotosNovas.isEmpty
    }

    var podeSalvar: Bool {
        guard !estaOcupado, !deveFechar,
              (try? dadosDoFormulario()) != nil else { return false }
        return !alteracoesPendentes.isEmpty
    }

    var alteracoesPendentes: [String] {
        guard let dados = try? dadosDoFormulario() else { return [] }
        var alteracoes = Self.descreverAlteracoes(de: dadosOriginais, para: dados)

        if !fotosRemovidas.isEmpty {
            alteracoes.append(Self.textoQuantidade(
                fotosRemovidas.count,
                singular: "foto removida",
                plural: "fotos removidas"
            ))
        }
        if !fotosNovas.isEmpty {
            alteracoes.append(Self.textoQuantidade(
                fotosNovas.count,
                singular: "foto adicionada",
                plural: "fotos adicionadas"
            ))
        }
        if let primeiraOriginal = spot.fotoIDs.first,
           fotosRemovidas.contains(primeiraOriginal),
           possuiFotosVisiveis {
            alteracoes.append("A foto de capa será alterada.")
        }
        return alteracoes
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

    func carregarFotos() async {
        guard !carregouFotos, !estaCarregandoFotos else { return }
        guard !spot.fotoIDs.isEmpty else {
            carregouFotos = true
            return
        }
        estaCarregandoFotos = true
        mensagemDeErro = nil
        defer { estaCarregandoFotos = false }

        do {
            fotosExistentes = try await buscarFotosDoSpot(spot)
            carregouFotos = true
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func solicitarConfirmacao() {
        guard podeSalvar else { return }
        mostraConfirmacao = true
    }

    func solicitarExclusao() {
        guard !estaOcupado else { return }
        mostraConfirmacaoExclusao = true
    }

    @discardableResult
    func salvar() async -> Bool {
        guard !estaOcupado, !deveFechar else { return false }
        mostraConfirmacao = false
        estaSalvando = true
        mensagemDeErro = nil
        defer { estaSalvando = false }

        do {
            let dados = try dadosDoFormulario()
            if dados != dadosOriginais {
                spot = try await editarSpot(spot.id, dados)
                dadosOriginais = dados
            }

            let existentesParaRemover = fotosExistentes.filter {
                fotosRemovidas.contains($0.foto.id)
            }
            for foto in existentesParaRemover {
                try Task.checkCancellation()
                spot = try await excluirFoto(foto.foto.id, spot.id)
                fotosRemovidas.remove(foto.foto.id)
                fotosExistentes.removeAll { $0.foto.id == foto.foto.id }
            }

            let novasParaEnviar = fotosNovas
            for foto in novasParaEnviar {
                try Task.checkCancellation()
                let resultado = try await enviarFoto(foto.arquivoURL, spot.id)
                spot = resultado.spotAtualizado
                fotosExistentes.append(FotoDisponivel(
                    foto: resultado.foto,
                    arquivoURL: foto.miniaturaURL
                ))
                fotosEnviadasNestaEdicao.append(foto)
                fotosNovas.removeAll { $0.id == foto.id }
            }

            deveFechar = true
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func excluir() async -> Bool {
        guard !estaOcupado, !deveFechar else { return false }
        mostraConfirmacaoExclusao = false
        estaExcluindo = true
        mensagemDeErro = nil
        defer { estaExcluindo = false }

        do {
            try await excluirSpot(spot.id)
            foiExcluido = true
            deveFechar = true
            return true
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    func adicionarHorario() {
        guard !bloqueiaInteracao else { return }
        horariosFuncionamento.append(HorarioFuncionamentoCadastro(fusoHorario: fusoHorario))
    }

    func removerHorario(id: UUID) {
        guard !bloqueiaInteracao else { return }
        horariosFuncionamento.removeAll { $0.id == id }
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

    func removerFotoExistente(id: UUID) {
        guard !estaOcupado else { return }
        fotosRemovidas.insert(id)
    }

    func removerFotoNova(_ foto: FotoCadastroSpot) {
        guard !estaOcupado else { return }
        apagarArquivos(da: foto)
        fotosNovas.removeAll { $0.id == foto.id }
    }

    func importarFotos(_ itens: [PhotosPickerItem]) async {
        guard !itens.isEmpty, !estaOcupado else { return }
        estaImportandoFotos = true
        defer { estaImportandoFotos = false }

        for item in itens {
            do {
                try Task.checkCancellation()
                guard let importada = try await item.loadTransferable(
                    type: FotoImportadaCadastro.self
                ) else {
                    throw ErroCRUD.dadosInvalidos(
                        descricao: "Não foi possível ler a imagem selecionada."
                    )
                }
                if Task.isCancelled {
                    apagarArquivos(da: importada.foto)
                    return
                }
                fotosNovas.append(importada.foto)
            } catch is CancellationError {
                return
            } catch {
                mensagemDeErro = "Não foi possível adicionar uma das fotos. \(error.localizedDescription)"
            }
        }
    }

    func ehCapaExistente(_ id: UUID) -> Bool {
        fotosVisiveis.first?.foto.id == id
    }

    func ehCapaNova(_ id: UUID) -> Bool {
        fotosVisiveis.isEmpty && fotosNovas.first?.id == id
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func descartarArquivosTemporarios() {
        for foto in fotosNovas + fotosEnviadasNestaEdicao {
            apagarArquivos(da: foto)
        }
        fotosNovas = []
        fotosEnviadasNestaEdicao = []
    }

    func dadosDoFormulario() throws -> DadosSpot {
        guard mostraEndereco else {
            throw ErroCRUD.dadosInvalidos(descricao: "Adicione o endereço do \(nomeTipo).")
        }

        let detalhes: DetalhesSpot
        switch tipo {
        case .evento:
            detalhes = .evento(Evento(
                inicio: inicio,
                termino: termino,
                fusoHorarioID: fusoHorario.identifier
            ))
        case .espaco:
            detalhes = .espaco(Espaco(funcionamento: try funcionamentoSemanal()))
        }

        return try ValidadorSpotCRUD.validarENormalizar(DadosSpot(
            nome: titulo,
            descricao: descricao,
            endereco: endereco,
            telefone: mostraTelefone ? telefone : "",
            link: try urlInformada(),
            redesSociais: spot.redesSociais,
            detalhes: detalhes
        ))
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

        let dias = DiaSemana.allCases.compactMap { dia -> FuncionamentoDia? in
            let intervalos = horariosFuncionamento
                .filter { $0.dias.contains(dia) }
                .map { $0.intervalo(fusoHorario: fusoHorario) }
                .sorted { Self.minutos($0.abertura) < Self.minutos($1.abertura) }
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

    private func apagarArquivos(da foto: FotoCadastroSpot) {
        try? FileManager.default.removeItem(at: foto.arquivoURL)
        try? FileManager.default.removeItem(at: foto.miniaturaURL)
    }

    private static func dados(de spot: Spot) -> DadosSpot {
        DadosSpot(
            nome: spot.nome,
            descricao: spot.descricao,
            endereco: spot.localizacao.endereco,
            telefone: spot.telefone,
            link: spot.link,
            redesSociais: spot.redesSociais,
            detalhes: spot.detalhes
        )
    }

    private static func descreverAlteracoes(
        de anterior: DadosSpot,
        para novo: DadosSpot
    ) -> [String] {
        var alteracoes: [String] = []

        if anterior.nome != novo.nome {
            alteracoes.append("Título: “\(anterior.nome)” → “\(novo.nome)”.")
        }
        if anterior.descricao != novo.descricao {
            alteracoes.append(descreverCampo(
                nome: "Descrição",
                anterior: anterior.descricao,
                novo: novo.descricao,
                exibirValores: false,
                feminino: true
            ))
        }
        if anterior.endereco != novo.endereco {
            alteracoes.append("Endereço atualizado.")
        }
        if anterior.telefone != novo.telefone {
            alteracoes.append(descreverCampo(
                nome: "Telefone",
                anterior: anterior.telefone,
                novo: novo.telefone,
                exibirValores: true,
                feminino: false
            ))
        }
        if anterior.link != novo.link {
            alteracoes.append(descreverCampo(
                nome: "URL",
                anterior: anterior.link?.absoluteString ?? "",
                novo: novo.link?.absoluteString ?? "",
                exibirValores: true,
                feminino: true
            ))
        }
        if anterior.detalhes != novo.detalhes {
            switch novo.detalhes {
            case .evento:
                alteracoes.append("Data ou horário do evento atualizado.")
            case .espaco:
                alteracoes.append("Dias ou horários de funcionamento atualizados.")
            }
        }
        return alteracoes
    }

    private static func descreverCampo(
        nome: String,
        anterior: String,
        novo: String,
        exibirValores: Bool,
        feminino: Bool
    ) -> String {
        if anterior.isEmpty { return "\(nome) \(feminino ? "adicionada" : "adicionado")." }
        if novo.isEmpty { return "\(nome) \(feminino ? "removida" : "removido")." }
        if exibirValores { return "\(nome): “\(anterior)” → “\(novo)”." }
        return "\(nome) \(feminino ? "atualizada" : "atualizado")."
    }

    private static func textoQuantidade(
        _ quantidade: Int,
        singular: String,
        plural: String
    ) -> String {
        "\(quantidade) \(quantidade == 1 ? singular : plural)."
    }

    private static func horariosEditaveis(
        de funcionamento: FuncionamentoSemanal,
        fusoHorario: TimeZone
    ) -> [HorarioFuncionamentoCadastro] {
        struct Chave: Hashable {
            let aberturaHora: Int
            let aberturaMinuto: Int
            let fechamentoHora: Int
            let fechamentoMinuto: Int
            let diaSeguinte: Bool
        }

        var diasPorHorario: [Chave: Set<DiaSemana>] = [:]
        for dia in funcionamento.dias {
            for intervalo in dia.intervalos {
                let chave = Chave(
                    aberturaHora: intervalo.abertura.hora,
                    aberturaMinuto: intervalo.abertura.minuto,
                    fechamentoHora: intervalo.fechamento.hora,
                    fechamentoMinuto: intervalo.fechamento.minuto,
                    diaSeguinte: intervalo.terminaNoDiaSeguinte
                )
                diasPorHorario[chave, default: []].insert(dia.dia)
            }
        }

        return diasPorHorario.map { chave, dias in
            var horario = HorarioFuncionamentoCadastro(fusoHorario: fusoHorario)
            horario.dias = dias
            horario.abertura = dataHorario(
                hora: chave.aberturaHora,
                minuto: chave.aberturaMinuto,
                fusoHorario: fusoHorario
            )
            horario.fechamento = dataHorario(
                hora: chave.fechamentoHora,
                minuto: chave.fechamentoMinuto,
                fusoHorario: fusoHorario
            )
            return horario
        }.sorted {
            let primeiroDia0 = $0.dias.compactMap {
                DiaSemana.allCases.firstIndex(of: $0)
            }.min() ?? 7
            let primeiroDia1 = $1.dias.compactMap {
                DiaSemana.allCases.firstIndex(of: $0)
            }.min() ?? 7
            if primeiroDia0 != primeiroDia1 { return primeiroDia0 < primeiroDia1 }
            return minutosDaData($0.abertura, fusoHorario: fusoHorario)
                < minutosDaData($1.abertura, fusoHorario: fusoHorario)
        }
    }

    private static func dataHorario(
        hora: Int,
        minuto: Int,
        fusoHorario: TimeZone
    ) -> Date {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fusoHorario
        return calendario.date(from: DateComponents(
            year: 2001,
            month: 1,
            day: 15,
            hour: hora,
            minute: minuto
        ))!
    }

    private static func minutosDaData(_ data: Date, fusoHorario: TimeZone) -> Int {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fusoHorario
        let componentes = calendario.dateComponents([.hour, .minute], from: data)
        return (componentes.hour ?? 0) * 60 + (componentes.minute ?? 0)
    }

    private static func minutos(_ horario: HorarioLocal) -> Int {
        horario.hora * 60 + horario.minuto
    }
}
