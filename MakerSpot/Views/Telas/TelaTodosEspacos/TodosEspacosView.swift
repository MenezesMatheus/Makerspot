//
//  TodosEspacosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct TodosEspacosView: View {
    @State private var viewModel: TodosEspacosViewModel

    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: TodosEspacosViewModel(sessao: sessao))
    }

    var body: some View {
        ZStack(alignment: .top) {
            fundo

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text("Do it yourself colaborativamente")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    conteudo
                }
                .padding(.bottom, 32)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .refreshable {
                await viewModel.recarregar()
            }

            if viewModel.estaCarregando, viewModel.espacos.isEmpty {
                ProgressView("Carregando espaços…")
                    .padding(.top, 96)
            }
        }
        .navigationTitle("Espaços")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Adicionar espaço", systemImage: "plus") {
                    viewModel.iniciarCadastro()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.extraLarge)
                .tint(.accentColor)
                .accessibilityLabel("Adicionar espaço")
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
            guard viewModel.espacos.isEmpty else { return }
            await viewModel.carregarPrimeiraPagina()
        }
        .alert(
            "Não foi possível carregar",
            isPresented: Binding(
                get: { viewModel.mensagemDeErro != nil },
                set: { if !$0 { viewModel.limparErro() } }
            )
        ) {
            Button("Tentar novamente") {
                Task { await viewModel.recarregar() }
            }
            Button("OK", role: .cancel) {
                viewModel.limparErro()
            }
        } message: {
            Text(viewModel.mensagemDeErro ?? "Tente novamente em instantes.")
        }
    }

    private var fundo: some View {
        LinearGradient(
            colors: [
                Color("CorEspaco").opacity(0.4),
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
        if viewModel.espacos.isEmpty && viewModel.estaCarregando {
            Color.clear.frame(height: 120)
        } else if viewModel.espacos.isEmpty {
            estadoVazio
        } else {
            listaDeEspacos
        }
    }

    private var estadoVazio: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Nenhum espaço encontrado")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Novos espaços aparecem aqui assim que forem publicados.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 48)
    }

    private var listaDeEspacos: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.espacos) { spot in
                CardSimplesView(
                    dados: CardSimplesDados(
                        spot: spot,
                        imagem: imagem(do: spot)
                    ),
                    modo: .visitante(
                        estaSalvo: viewModel.estaSalvo(spot),
                        estaProcessando: viewModel.estaAlterandoSalvo(spot),
                        podeSalvar: viewModel.podeSalvar(spot),
                        aoAlternar: {
                            Task { await viewModel.alternarSalvo(do: spot) }
                        }
                    ),
                    aoSelecionar: {}
                )
                .task {
                    await viewModel.fotosSpots.carregarFotoPrincipal(do: spot)
                }
                .onAppear {
                    if spot.id == viewModel.espacos.last?.id {
                        Task { await viewModel.carregarProximaPagina() }
                    }
                }
            }

            if viewModel.estaCarregando && !viewModel.espacos.isEmpty {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 12)
            }
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
        TodosEspacosView(sessao: sessao)
    }
    .environment(sessao)
    .preferredColorScheme(.dark)
}
