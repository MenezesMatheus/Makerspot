//
//  SpotsView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct SpotsView: View {
    @Bindable private var viewModel: SpotsViewModel

    init(viewModel: SpotsViewModel) {
        self.viewModel = viewModel
    }

    init(sessao: SessaoUsuario) {
        self.init(viewModel: SpotsViewModel(sessao: sessao))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                fundo
                conteudo

                if viewModel.spots.isEmpty, viewModel.estaCarregando {
                    ProgressView("Carregando Spots…")
                }
            }
            .navigationTitle("Spots")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adicionar Spot", systemImage: "plus") {
                        viewModel.iniciarCadastro()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.extraLarge)
                    .tint(.accentColor)
                    .accessibilityLabel("Adicionar Spot")
                }
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
                guard viewModel.spots.isEmpty else { return }
                await viewModel.carregarPrimeiraPagina()
            }
            .alert(
                "Não foi possível carregar os Spots",
                isPresented: Binding(
                    get: { viewModel.mensagemDeErro != nil },
                    set: { _ in viewModel.limparErro() }
                )
            ) {
                Button("Tentar novamente") {
                    Task { await viewModel.recarregar() }
                }
                Button("OK", role: .cancel) {
                    viewModel.limparErro()
                }
            } message: {
                Text(viewModel.mensagemDeErro ?? "")
            }
        }
    }

    private var fundo: some View {
        LinearGradient(
            colors: [.accent.opacity(0.4),
                     .black,
                     .black.opacity(0.6),
                     .black.opacity(0.6),
                     .black.opacity(0.7),
                     .black.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var conteudo: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                Text("Encontre eventos e espaços para você.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                secaoEventos
                secaoEspacos
            }
            .padding(.bottom, 12)
        }
        .refreshable {
            await viewModel.recarregar()
        }
    }

    private var secaoEventos: some View {
        VStack(alignment: .leading, spacing: 18) {
            cabecalhoSecao(
                titulo: "Eventos",
                destino: TodosEventosView()
            )

            if !viewModel.eventosEmDestaque.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(viewModel.eventosEmDestaque) { evento in
                            CardEvento(
                                spot: evento,
                                imagem: imagem(do: evento),
                                estaSalvo: viewModel.estaSalvo(evento),
                                estaAlterandoSalvo: viewModel.estaAlterandoSalvo(evento),
                                podeSalvar: viewModel.podeSalvar(evento),
                                aoAlternarSalvo: {
                                    Task { await viewModel.alternarSalvo(do: evento) }
                                }
                            )
                            .task {
                                await viewModel.fotosSpots.carregarFotoPrincipal(do: evento)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var secaoEspacos: some View {
        VStack(alignment: .leading, spacing: 18) {
            cabecalhoSecao(
                titulo: "Espaços",
                destino: TodosEspacosView()
            )

            if !viewModel.espacosEmDestaque.isEmpty {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.espacosEmDestaque) { espaco in
                        CardSimplesView(
                            dados: CardSimplesDados(
                                spot: espaco,
                                imagem: imagem(do: espaco)
                            ),
                            modo: .visitante(
                                estaSalvo: viewModel.estaSalvo(espaco),
                                estaProcessando: viewModel.estaAlterandoSalvo(espaco),
                                podeSalvar: viewModel.podeSalvar(espaco),
                                aoAlternar: {
                                    Task { await viewModel.alternarSalvo(do: espaco) }
                                }
                            ),
                            aoSelecionar: {}
                        )
                        .task {
                            await viewModel.fotosSpots.carregarFotoPrincipal(do: espaco)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func cabecalhoSecao<Destino: View>(
        titulo: String,
        destino: Destino
    ) -> some View {
        NavigationLink(destination: destino) {
            HStack(spacing: 8) {
                Text(titulo)
                    .font(.title.bold())

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func imagem(do spot: Spot) -> ImagemCardSimples {
        guard let foto = viewModel.fotosSpots.fotoPrincipal(do: spot) else {
            return .placeholder
        }
        return .arquivo(foto.arquivoURL)
    }
}

#Preview {
    SpotsView(sessao: SessaoUsuario())
        .preferredColorScheme(.dark)
}
