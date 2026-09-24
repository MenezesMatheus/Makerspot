//
//  DetalhesSpotView.swift
//  MakerSpot
//

import SwiftUI

struct DetalhesSpotView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DetalhesSpotViewModel
    @State private var viewModelDenuncia: ReportarSpotViewModel?
    @State private var mostrarEditor = false
    @State private var confirmarExclusao = false
    @State private var iniciouCarregamento = false

    init(spotID: UUID, sessao: SessaoUsuario) {
        _viewModel = State(
            initialValue: DetalhesSpotViewModel(
                spotID: spotID,
                sessao: sessao
            )
        )
    }

    var body: some View {
        Group {
            if let spot = viewModel.spot {
                conteudo(spot)
            } else if viewModel.estaCarregando || !iniciouCarregamento {
                ProgressView("Carregando Spot…")
            } else {
                ContentUnavailableView(
                    "Spot indisponível",
                    systemImage: "mappin.slash",
                    description: Text("Não foi possível carregar este Spot.")
                )
            }
        }
        .toolbar { barraDeAcoes }
        .sheet(item: $viewModelDenuncia) { denuncia in
            SheetReportarView(viewModel: denuncia)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $mostrarEditor) {
            EditarSpotView()
        }
        .disabled(confirmarExclusao || viewModel.estaExcluindo)
        .overlay {
            PopUpAcaoView(
                estaApresentado: $confirmarExclusao,
                titulo: "Deseja excluir este Spot?",
                subtitulo: "Esta ação não pode ser desfeita.",
                tituloAcao: "Excluir Spot",
                acaoDestrutiva: true,
                aoConfirmar: {
                    Task {
                        if await viewModel.excluir() {
                            dismiss()
                        }
                    }
                }
            )

            if viewModel.estaExcluindo {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Excluindo Spot…")
                    .padding(24)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 20)
                    )
            }
        }
        .task {
            iniciouCarregamento = true
            await viewModel.carregar()
        }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { viewModel.mensagemDeErro != nil },
                set: { _ in viewModel.limparErro() }
            )
        ) {
            Button("OK") { viewModel.limparErro() }
        } message: {
            Text(viewModel.mensagemDeErro ?? "")
        }
    }

    private func conteudo(_ spot: Spot) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    corDestaque(para: spot).opacity(0.4),
                    .black,
                    .black.opacity(0.6),
                    .black.opacity(0.6),
                    .black.opacity(0.7),
                    .black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                // MARK: - Título

                Text(spot.nome)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // MARK: - Fotos

                CarrosselFotosSpot(
                    fotos: viewModel.fotos,
                    estaCarregando: viewModel.estaCarregando
                )
                .padding(.bottom, 24)

                // MARK: - Descrição

                Text(spot.descricao)
                    .font(.body)
                    .padding(.horizontal, 16)

                // MARK: - Link

                if let link = spot.link {
                    Link(destination: link) {
                        Text(link.absoluteString)
                            .font(.body)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // MARK: - Informações

                VStack(alignment: .leading, spacing: 10) {
                    switch spot.detalhes {
                    case .evento(let evento):
                        LinhaInformacaoSpot(
                            icone: "calendar",
                            texto: textoDataEvento(evento),
                            cor: corDestaque
                        )

                    case .espaco(let espaco):
                        LinhaInformacaoSpot(
                            icone: "clock",
                            texto: textoFuncionamentoEspaco(espaco),
                            cor: corDestaque
                        )
                    }

                    LinhaInformacaoSpot(
                        icone: "phone",
                        texto: spot.telefone,
                        cor: corDestaque
                    )

                    LinhaInformacaoSpot(
                        icone: "mappin.and.ellipse",
                        texto: textoEndereco(spot),
                        cor: corDestaque
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                // MARK: - Publicador

                HStack(spacing: 12) {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }

                    Text(spot.nomePublicador)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // MARK: - Divisor

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // MARK: - Aviso

                Text("Para mais informações entre em contato com o organizador do spot.")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var barraDeAcoes: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if viewModel.spot != nil {
                if viewModel.ehProprietario {
                    Button("Editar Spot", systemImage: "pencil") {
                        mostrarEditor = true
                    }
                    .labelStyle(.iconOnly)

                    Button(
                        "Excluir Spot",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        confirmarExclusao = true
                    }
                    .labelStyle(.iconOnly)
                } else {
                    Button(
                        "Denunciar Spot",
                        systemImage: "exclamationmark.bubble"
                    ) {
                        viewModelDenuncia = viewModel.criarDenuncia()
                    }
                    .labelStyle(.iconOnly)

                    Button {
                        Task { await viewModel.alternarSalvo() }
                    } label: {
                        if viewModel.estaAlterandoSalvo {
                            ProgressView()
                        } else {
                            Label(
                                viewModel.estaSalvo
                                    ? "Remover dos salvos"
                                    : "Salvar Spot",
                                systemImage: viewModel.estaSalvo
                                    ? "bookmark.fill"
                                    : "bookmark"
                            )
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(
                        viewModel.estaAlterandoSalvo
                            || !viewModel.carregouEstadoSalvo
                    )
                }
            }
        }
    }

    private var corDestaque: Color {
        guard let spot = viewModel.spot else { return .accentColor }
        return corDestaque(para: spot)
    }

    private func corDestaque(para spot: Spot) -> Color {
        switch spot.tipo {
        case .evento: return Color("CorEvento")
        case .espaco: return Color("CorEspaco")
        }
    }

    private func textoEndereco(_ spot: Spot) -> String {
        let endereco = spot.localizacao.endereco
        var texto = "\(endereco.logradouro), nº \(endereco.numero)"

        if let complemento = endereco.complemento,
           !complemento.isEmpty {
            texto += " - \(complemento)"
        }

        texto += " - \(endereco.cidade), \(endereco.estado)"
        return texto
    }

    private func textoDataEvento(_ evento: Evento) -> String {
        let calendario = Calendar.current
        let mesmoDia = calendario.isDate(
            evento.inicio,
            inSameDayAs: evento.termino
        )

        let formatadorData = DateFormatter()
        formatadorData.locale = Locale(identifier: "pt_BR")
        formatadorData.dateFormat = "dd.MM"

        let formatadorHorario = DateFormatter()
        formatadorHorario.locale = Locale(identifier: "pt_BR")
        formatadorHorario.dateFormat = "HH'h'"

        let dataInicio = formatadorData.string(from: evento.inicio)
        let dataTermino = formatadorData.string(from: evento.termino)
        let horaInicio = formatadorHorario.string(from: evento.inicio)
        let horaTermino = formatadorHorario.string(from: evento.termino)

        if mesmoDia {
            return "\(dataInicio) \(horaInicio) - \(horaTermino)"
        }

        return "\(dataInicio) \(horaInicio) - \(dataTermino) \(horaTermino)"
    }

    private func textoFuncionamentoEspaco(_ espaco: Espaco) -> String {
        let diasComFuncionamento = espaco.funcionamento.dias.filter {
            !$0.intervalos.isEmpty
        }

        guard !diasComFuncionamento.isEmpty,
              let primeiroDia = diasComFuncionamento.first,
              let ultimoDia = diasComFuncionamento.last,
              let primeiroIntervalo = primeiroDia.intervalos.first else {
            return "Horário não informado"
        }

        let abertura = textoHorario(primeiroIntervalo.abertura)
        let fechamento = textoHorario(primeiroIntervalo.fechamento)

        if diasComFuncionamento.count == 1 {
            return "Aberto \(abertura) às \(fechamento) - \(abreviacaoDia(primeiroDia.dia))"
        }

        return "Aberto \(abertura) às \(fechamento) - \(abreviacaoDia(primeiroDia.dia)) a \(abreviacaoDia(ultimoDia.dia))"
    }

    private func textoHorario(_ horario: HorarioLocal) -> String {
        if horario.minuto == 0 {
            return String(format: "%02dh", horario.hora)
        }
        return String(format: "%02dh%02d", horario.hora, horario.minuto)
    }

    private func abreviacaoDia(_ dia: DiaSemana) -> String {
        switch dia {
        case .segunda: return "seg"
        case .terca: return "ter"
        case .quarta: return "qua"
        case .quinta: return "qui"
        case .sexta: return "sex"
        case .sabado: return "sáb"
        case .domingo: return "dom"
        }
    }
}

private struct LinhaInformacaoSpot: View {

    let icone: String
    let texto: String
    let cor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icone)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(cor)
                .frame(width: 18)

            Text(texto)
                .font(.body)
                .fontWeight(.semibold)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        DetalhesSpotView(
            spotID: UUID(),
            sessao: SessaoUsuario()
        )
    }
    .preferredColorScheme(.dark)
}
