//
//  MeusEventosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
import Combine

struct MeusEventosView: View {
    @State private var viewModel: MeusEventosViewModel
    @State private var jaApareceu = false
    @State private var idParaExcluir: UUID?
    @State private var mostrarConfirmacaoExclusao = false

    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: MeusEventosViewModel(sessao: sessao))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .top) {
            fundo

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text("Gerencie os eventos e mantenha tudo atualizado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker(
                        "Disponibilidade",
                        selection: $viewModel.filtroSelecionado
                    ) {
                        ForEach(FiltroMeusEventos.allCases) { filtro in
                            Text(filtro.rawValue).tag(filtro)
                        }
                    }
                    .pickerStyle(.segmented)

                    conteudo
                }
                .padding(.bottom, 32)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .refreshable {
                await viewModel.carregar()
            }

            if viewModel.estaCarregando, viewModel.eventos.isEmpty {
                ProgressView("Carregando eventos…")
                    .padding(.top, 96)
            }
        }
        .navigationTitle("Meus Eventos")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BotaoAdicionarToolbar(titulo: "Adicionar evento", cor: Color("CorEvento")) {
                    viewModel.iniciarCadastro()
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.cadastro != nil },
            set: { if !$0 { viewModel.encerrarCadastro() } }
        )) {
            if let cadastro = viewModel.cadastro {
                CadastrarSpotView(viewModel: cadastro)
            }
        }
        .task {
            guard !viewModel.carregouDados else { return }
            await viewModel.carregar()
        }
        .onAppear {
            viewModel.atualizarDisponibilidade()
            defer { jaApareceu = true }
            guard jaApareceu else { return }
            Task { await viewModel.carregar() }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            viewModel.atualizarDisponibilidade()
        }
        .overlay {
            PopUpTextoView(
                estaApresentado: Binding(
                    get: { viewModel.avisoAtivacao != nil },
                    set: { if !$0 { viewModel.limparAvisoAtivacao() } }
                ),
                titulo: viewModel.avisoAtivacao?.titulo ?? "",
                subtitulo: viewModel.avisoAtivacao?.mensagem
            )
        }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { viewModel.mensagemDeErro != nil },
                set: { if !$0 { viewModel.limparErro() } }
            )
        ) {
            Button("Tentar novamente") {
                Task { await viewModel.carregar() }
            }
            Button("OK", role: .cancel) {
                viewModel.limparErro()
            }
        } message: {
            Text(viewModel.mensagemDeErro ?? "Tente novamente em instantes.")
        }
        .alert("Excluir evento?", isPresented: $mostrarConfirmacaoExclusao) {
            Button("Excluir", role: .destructive) {
                guard let id = idParaExcluir else { return }
                Task {
                    _ = await viewModel.excluir(id: id)
                    idParaExcluir = nil
                }
            }
            Button("Cancelar", role: .cancel) {
                idParaExcluir = nil
            }
        } message: {
            Text("Essa ação não pode ser desfeita.")
        }
    }

    private var fundo: some View {
        LinearGradient(
            colors: [
                Color("CorEvento").opacity(0.4),
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
    }

    @ViewBuilder
    private var conteudo: some View {
        if viewModel.eventos.isEmpty && viewModel.estaCarregando {
            Color.clear.frame(height: 120)
        } else if viewModel.eventosFiltrados.isEmpty {
            estadoVazio
        } else {
            listaDeEventos
        }
    }

    private var estadoVazio: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(tituloEstadoVazio)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(mensagemEstadoVazio)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 48)
    }

    private var listaDeEventos: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.eventosFiltrados) { spot in
                CardSimplesView(
                    dados: CardSimplesDados(
                        spot: spot,
                        imagem: imagem(do: spot)
                    ),
                    modo: .proprietario(
                        estaAtivo: spot.estaDisponivel(em: viewModel.agora),
                        estaProcessando: viewModel.spotEmAlteracao == spot.id,
                        podeAlterar: !spot.eventoEncerrado(em: viewModel.agora),
                        aoAlternar: { novoValor in
                            Task {
                                await viewModel.definirAtivo(
                                    novoValor,
                                    para: spot.id
                                )
                            }
                        }
                    ),
                    aoSelecionar: {}
                )
                .task(id: spot.fotoIDs) {
                    await viewModel.fotosSpots.carregarFotoPrincipal(do: spot)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        idParaExcluir = spot.id
                        mostrarConfirmacaoExclusao = true
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var tituloEstadoVazio: String {
        switch viewModel.filtroSelecionado {
        case .disponiveis:
            return "Você ainda não publicou eventos disponíveis"
        case .indisponiveis:
            return "Nenhum evento indisponível"
        }
    }

    private var mensagemEstadoVazio: String {
        switch viewModel.filtroSelecionado {
        case .disponiveis:
            return "Toque em + para cadastrar seu primeiro evento."
        case .indisponiveis:
            return "Os eventos desativados aparecerão aqui."
        }
    }

    private func imagem(do spot: Spot) -> ImagemCardSimples {
        guard let foto = viewModel.fotosSpots.fotoPrincipal(do: spot) else {
            return .placeholder
        }
        return .arquivo(foto.arquivoURL)
    }
}

#Preview {
    let sessao = SessaoUsuario()
    NavigationStack {
        MeusEventosView(sessao: sessao)
    }
    .environment(sessao)
    .preferredColorScheme(.dark)
}
