//
//  CadastrarSpotView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import PhotosUI
import SwiftUI

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
                        Text(viewModel.textoProgresso)
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
                    ForEach(viewModel.paises) { pais in
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

            if let erro = viewModel.erroFuncionamento {
                Section {
                    Text(erro)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Color.clear)
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
                .presentationDetents([.large])
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
}

#Preview("Cadastrar") {
    NavigationStack {
        CadastrarSpotView(sessao: SessaoUsuario())
    }
    .preferredColorScheme(.dark)
}
