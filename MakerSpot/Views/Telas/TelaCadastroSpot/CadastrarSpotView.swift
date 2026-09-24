//
//  CadastrarSpotView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CoreTransferable
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// Copia a imagem do PhotosPicker porque a URL recebida existe apenas durante a transferência.
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
                        miniatura as CFURL, UTType.jpeg.identifier as CFString, 1, nil
                      ) else {
                    throw ErroCRUD.dadosInvalidos(descricao: "Selecione uma imagem válida.")
                }
                CGImageDestinationAddImage(destino, imagem, nil)
                guard CGImageDestinationFinalize(destino) else {
                    throw ErroCRUD.dadosInvalidos(descricao: "Não foi possível preparar a foto.")
                }
                try Task.checkCancellation()
                return Self(foto: FotoCadastroSpot(arquivoURL: arquivo, miniaturaURL: miniatura))
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
            year: 2001, month: 1, day: 15, hour: 9
        ))!
        fechamento = calendario.date(from: DateComponents(
            year: 2001, month: 1, day: 15, hour: 18
        ))!
    }

    var resumoDias: String {
        if dias.isEmpty { return "Selecionar" }
        if dias.count == 7 { return "Todos os dias" }
        if dias == Set([.segunda, .terca, .quarta, .quinta, .sexta]) { return "Seg. a sex." }
        return DiaSemana.allCases
            .filter { dias.contains($0) }
            .map(\.nomeAbreviado)
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
}

struct CadastrarSpotView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CadastrarSpotViewModel
    @State private var itensSelecionados: [PhotosPickerItem] = []
    @FocusState private var campoFocado: Bool

    init(viewModel: CadastrarSpotViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init(sessao: SessaoUsuario) {
        self.init(viewModel: CadastrarSpotViewModel(sessao: sessao))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            Picker("Tipo de Spot", selection: $viewModel.tipoSelecionado) {
                Text("Espaços").tag(TipoSpot.espaco)
                Text("Eventos").tag(TipoSpot.evento)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .disabled(viewModel.estaOcupado || viewModel.spotCriado != nil)

            formulario
        }
        .background(Color(.systemBackground))
        .navigationTitle("Novo Spot")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.bloqueiaInteracao)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    campoFocado = false
                    viewModel.solicitarConfirmacao()
                } label: {
                    if viewModel.estaCadastrando {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.accentColor)
                .disabled(!viewModel.podeCadastrar || viewModel.mostraPopup)
                .accessibilityLabel(viewModel.spotCriado == nil ? "Cadastrar \(viewModel.nomeTipo)" : "Concluir envio das fotos")
            }
        }
        .disabled(viewModel.bloqueiaInteracao)
        .accessibilityHidden(viewModel.mostraPopup)
        .overlay {
            PopUpAcaoView(
                estaApresentado: $viewModel.mostraConfirmacao,
                titulo: viewModel.tituloConfirmacao,
                tituloAcao: "Confirmar",
                aoConfirmar: {
                    Task { await viewModel.confirmarCadastro() }
                }
            )
            PopUpTextoView(
                estaApresentado: $viewModel.mostraSucesso,
                titulo: viewModel.tituloSucesso
            )
        }
        .interactiveDismissDisabled(viewModel.bloqueiaInteracao)
        .onChange(of: viewModel.deveFechar) { _, deveFechar in
            if deveFechar { dismiss() }
        }
        .alert("Cadastro de \(viewModel.nomeTipo)", isPresented: Binding(
            get: { viewModel.mensagemDeErro != nil },
            set: { if !$0 { viewModel.limparErro() } }
        )) {
            Button("OK", role: .cancel, action: viewModel.limparErro)
        } message: {
            Text(viewModel.mensagemDeErro ?? "")
        }
        .task(id: itensSelecionados) {
            await viewModel.importarFotos(itensSelecionados)
            itensSelecionados = []
        }
        .onDisappear { viewModel.descartarArquivosTemporarios() }
    }

    private var formulario: some View {
        @Bindable var viewModel = viewModel

        return Form {
            Section {
                TextField("Título do \(viewModel.nomeTipo)", text: $viewModel.titulo)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Título do \(viewModel.nomeTipo), obrigatório")
                TextField("Descrição (opcional)", text: $viewModel.descricao, axis: .vertical)
                    .lineLimit(1...8)
            }
            .disabled(viewModel.spotCriado != nil)

            secaoEndereco
                .disabled(viewModel.spotCriado != nil)

            if viewModel.tipoSelecionado == .evento {
                secaoHorarioEvento
                    .disabled(viewModel.spotCriado != nil)
            } else {
                FuncionamentoEspacoView(viewModel: viewModel)
                    .disabled(viewModel.spotCriado != nil)
            }

            secaoTelefone
                .disabled(viewModel.spotCriado != nil)
            secaoURL
                .disabled(viewModel.spotCriado != nil)
            secaoFotos

            if viewModel.estaOcupado {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(viewModel.estaImportandoFotos ? "Preparando fotos…" :
                            "Salvando \(viewModel.nomeTipo)… \(viewModel.quantidadeFotosProcessadas)/\(viewModel.fotos.count) fotos")
                            .font(.footnote)
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color.clear)
            } else if viewModel.temFotosPendentes {
                Section {
                    Text("\(viewModel.nomeTipoCapitalizado) criado. Confirme para concluir o envio das fotos pendentes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 12, for: .scrollContent)
        .listSectionSpacing(20)
        .scrollDismissesKeyboard(.interactively)
        .focused($campoFocado)
        .disabled(viewModel.estaOcupado)
    }

    private var secaoHorarioEvento: some View {
        @Bindable var viewModel = viewModel

        return Section {
            DatePicker("Começa", selection: $viewModel.inicio, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Termina", selection: $viewModel.termino, in: viewModel.inicio..., displayedComponents: [.date, .hourAndMinute])
        } footer: {
            if viewModel.termino <= viewModel.inicio {
                Text("O término deve ocorrer depois do início.").foregroundStyle(.red)
            }
        }
        .datePickerStyle(.compact)
        .environment(\.timeZone, viewModel.fusoHorario)
    }

    private var secaoEndereco: some View {
        @Bindable var viewModel = viewModel

        return Section {
            if viewModel.mostraEndereco {
                TextField("Rua", text: $viewModel.endereco.logradouro)
                    .textContentType(.streetAddressLine1)
                    .accessibilityLabel("Rua, obrigatória")
                TextField("Número", text: $viewModel.endereco.numero)
                    .accessibilityLabel("Número, obrigatório. Use s/n se não houver número.")
                TextField("Complemento (opcional)", text: textoOpcional($viewModel.endereco.complemento))
                    .textContentType(.streetAddressLine2)
                TextField("Bairro", text: textoOpcional($viewModel.endereco.bairro))
                    .textContentType(.sublocality)
                TextField("Cidade", text: $viewModel.endereco.cidade)
                    .textContentType(.addressCity)
                    .accessibilityLabel("Cidade, obrigatória")
                TextField("Estado", text: $viewModel.endereco.estado)
                    .textContentType(.addressState)
                    .accessibilityLabel("Estado, obrigatório")
                TextField("CEP", text: textoOpcional($viewModel.endereco.codigoPostal))
                    .textContentType(.postalCode)
                    .textInputAutocapitalization(.characters)
                Picker("País", selection: $viewModel.endereco.codigoPais) {
                    ForEach(Self.paises, id: \.codigo) { pais in
                        Text(pais.nome).tag(pais.codigo)
                    }
                }
                Button(role: .destructive) { viewModel.mostraEndereco = false } label: {
                    Label("Remover endereço", systemImage: "minus.circle.fill")
                        .foregroundStyle(Color.red)
                }
            } else {
                Button { viewModel.mostraEndereco = true } label: {
                    rotuloAdicionar("Adicionar endereço")
                }
                .accessibilityHint("Obrigatório para cadastrar o \(viewModel.nomeTipo)")
            }
        }
    }

    private var secaoTelefone: some View {
        @Bindable var viewModel = viewModel

        return Section {
            if viewModel.mostraTelefone {
                HStack {
                    botaoRemover("Remover telefone", acao: viewModel.removerTelefone)
                    TextField("Telefone (opcional)", text: $viewModel.telefone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                if let telefone = viewModel.telefoneSugerido {
                    Button { viewModel.usarTelefoneDaConta() } label: {
                        Label("Usar telefone da conta: \(telefone)", systemImage: "person.crop.circle")
                            .font(.subheadline)
                    }
                }
            } else {
                Menu {
                    if let telefone = viewModel.telefoneSugerido {
                        Button("Usar telefone da conta: \(telefone)", systemImage: "person.crop.circle") {
                            viewModel.usarTelefoneDaConta()
                        }
                    }
                    Button("Digitar outro telefone", systemImage: "phone") {
                        viewModel.mostraTelefone = true
                    }
                } label: {
                    rotuloAdicionar("Adicionar telefone")
                }
            }
        }
    }

    private var secaoURL: some View {
        @Bindable var viewModel = viewModel

        return Section {
            if viewModel.mostraURL {
                HStack {
                    botaoRemover("Remover URL", acao: viewModel.removerURL)
                    TextField("https://exemplo.com", text: $viewModel.textoURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("URL de divulgação")
                }
            } else {
                Button { viewModel.mostraURL = true } label: {
                    rotuloAdicionar("Adicionar URL")
                }
            }
        }
    }

    private var secaoFotos: some View {
        Section {
            if viewModel.fotos.isEmpty {
                seletorFotos(compacto: false)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 18)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.fotos) { foto in
                            miniatura(foto)
                        }
                        if viewModel.spotCriado == nil {
                            seletorFotos(compacto: true)
                                .frame(width: 120, height: 140)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
            }
        } footer: {
            Text("A primeira foto será a capa do \(viewModel.nomeTipo). Você pode adicionar quantas fotos quiser.")
                .padding(.top, 16)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func seletorFotos(compacto: Bool) -> some View {
        PhotosPicker(
            selection: $itensSelecionados,
            maxSelectionCount: nil,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            VStack(spacing: 16) {
                Image(systemName: "photo.badge.plus")
                    .font(compacto ? .title : .largeTitle)
                    .foregroundStyle(.secondary)
                Text(compacto ? "Adicionar foto" : "Adicionar fotos")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adicionar fotos do \(viewModel.nomeTipo)")
    }

    private func miniatura(_ foto: FotoCadastroSpot) -> some View {
        ZStack(alignment: .topTrailing) {
            if let imagem = UIImage(contentsOfFile: foto.miniaturaURL.path) {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 140)
                    .clipped()
            }
            if !viewModel.fotoFoiEnviada(foto) {
                Button(role: .destructive) { viewModel.removerFoto(foto) } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.primary)
                .padding(6)
                .accessibilityLabel("Remover foto \((viewModel.fotos.firstIndex(of: foto) ?? 0) + 1)")
            }
        }
        .overlay(alignment: .bottomLeading) {
            if viewModel.fotos.first?.id == foto.id {
                Text("Capa")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func rotuloAdicionar(_ texto: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.green)
            Text(texto).fontWeight(.semibold).foregroundStyle(Color.primary)
        }
        .padding(.vertical, 4)
    }

    private func botaoRemover(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: acao) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(Color.red)
                .frame(minWidth: 32, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(titulo)
    }

    private func textoOpcional(_ texto: Binding<String?>) -> Binding<String> {
        Binding(get: { texto.wrappedValue ?? "" }, set: { texto.wrappedValue = $0 })
    }

    private static let paises: [(codigo: String, nome: String)] = {
        let locale = Locale(identifier: "pt_BR")
        return Locale.Region.isoRegions.compactMap { regiao in
            guard regiao.identifier.count == 2,
                  let nome = locale.localizedString(forRegionCode: regiao.identifier) else { return nil }
            return (codigo: regiao.identifier, nome: nome)
        }.sorted { $0.nome.localizedCompare($1.nome) == .orderedAscending }
    }()
}

private struct FuncionamentoEspacoView: View {
    @Bindable var viewModel: CadastrarSpotViewModel

    var body: some View {
        if viewModel.horariosFuncionamento.isEmpty {
            Section {
                Button(action: viewModel.adicionarHorario) {
                    rotuloAdicionar("Dia e hora")
                }
                .accessibilityHint("Adicione os dias e horários de funcionamento do espaço")
            }
        } else {
            ForEach($viewModel.horariosFuncionamento) { $horario in
                SecaoHorarioEspaco(
                    horario: $horario,
                    fusoHorario: viewModel.fusoHorario,
                    aoRemover: { viewModel.removerHorario(id: horario.id) }
                )
            }
            Section {
                Button(action: viewModel.adicionarHorario) {
                    rotuloAdicionar("Adicionar outro horário")
                }
            } footer: {
                if let erro = viewModel.erroFuncionamento {
                    Text(erro).foregroundStyle(.red)
                }
            }
        }
    }

    private func rotuloAdicionar(_ texto: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.green)
            Text(texto).fontWeight(.semibold).foregroundStyle(Color.primary)
        }
        .padding(.vertical, 4)
    }
}

private struct SecaoHorarioEspaco: View {
    @Binding var horario: HorarioFuncionamentoCadastro
    let fusoHorario: TimeZone
    let aoRemover: () -> Void
    @State private var mostraDias = false

    var body: some View {
        Section {
            Button { mostraDias = true } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text("Dias de funcionamento").foregroundStyle(Color.primary)
                        Spacer(minLength: 0)
                        resumoDias
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dias de funcionamento").foregroundStyle(Color.primary)
                        resumoDias
                    }
                }
            }
            .accessibilityLabel("Dias de funcionamento")
            .accessibilityValue(horario.resumoDias)

            DatePicker("Começa", selection: $horario.abertura, displayedComponents: .hourAndMinute)
            DatePicker("Termina", selection: $horario.fechamento, displayedComponents: .hourAndMinute)

            Button(role: .destructive, action: aoRemover) {
                Label("Remover horário", systemImage: "minus.circle.fill")
                    .foregroundStyle(Color.red)
            }
        } footer: {
            if horario.intervalo(fusoHorario: fusoHorario).terminaNoDiaSeguinte {
                Text("O fechamento ocorre no dia seguinte aos dias selecionados.")
            }
        }
        .datePickerStyle(.compact)
        .environment(\.timeZone, fusoHorario)
        .sheet(isPresented: $mostraDias) {
            SelecaoDiasFuncionamento(dias: $horario.dias)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var resumoDias: some View {
        HStack(spacing: 6) {
            Text(horario.resumoDias)
                .font(.subheadline)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }
}

private struct SelecaoDiasFuncionamento: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dias: Set<DiaSemana>

    var body: some View {
        NavigationStack {
            List {
                ForEach(DiaSemana.allCases, id: \.self) { dia in
                    Button {
                        if dias.contains(dia) {
                            dias.remove(dia)
                        } else {
                            dias.insert(dia)
                        }
                    } label: {
                        HStack {
                            Text(dia.nomeCompleto).foregroundStyle(Color.primary)
                            Spacer()
                            if dias.contains(dia) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityValue(dias.contains(dia) ? "Selecionado" : "Não selecionado")
                    .accessibilityAddTraits(dias.contains(dia) ? [.isSelected] : [])
                }
            }
            .navigationTitle("Dias de funcionamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluído") { dismiss() }
                }
            }
        }
    }
}

private extension DiaSemana {
    var nomeCompleto: String {
        switch self {
        case .segunda: return "Segunda-feira"
        case .terca: return "Terça-feira"
        case .quarta: return "Quarta-feira"
        case .quinta: return "Quinta-feira"
        case .sexta: return "Sexta-feira"
        case .sabado: return "Sábado"
        case .domingo: return "Domingo"
        }
    }

    var nomeAbreviado: String {
        switch self {
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

#Preview("Cadastrar") {
    NavigationStack {
        CadastrarSpotView(sessao: SessaoUsuario())
    }
    .preferredColorScheme(.dark)
}
