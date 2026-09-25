//
//  TodosEspacosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
 
struct TodosEspacosView: View {
    @Environment(\.dismiss) private var dismiss
 
    @State private var viewModel: TodosEspacosViewModel
    @State private var mostrarErro = false
    @State private var mostrarCriarEspaco = false
 
    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: TodosEspacosViewModel(sessao: sessao))
    }
 
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.15, blue: 0.4),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
 
            VStack(alignment: .leading, spacing: 24) {
                barraSuperior
 
                cabecalho
 
                conteudo
            }
            .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard viewModel.espacos.isEmpty else { return }
            await viewModel.carregarPrimeiraPagina()
        }
        .onChange(of: viewModel.mensagemDeErro) { _, novoValor in
            mostrarErro = novoValor != nil
        }
        .alert("Não foi possível carregar", isPresented: $mostrarErro) {
            Button("Tentar novamente") {
                Task { await viewModel.recarregar() }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.mensagemDeErro ?? "Tente novamente em instantes.")
        }
        .sheet(isPresented: $mostrarCriarEspaco) {
            // apresentar a tela de cadastro de espaço quando disponivel
        }
    }
 
    // cabecalho
 
    private var barraSuperior: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.12))
                    .clipShape(Circle())
            }
 
            Spacer()
 
            Button(action: { mostrarCriarEspaco = true }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.85, green: 0.1, blue: 0.47))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }
 
    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Espaços")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
 
            Text("Do it yourself colaborativamente")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
 
    // conteudo da tela
 
    @ViewBuilder
    private var conteudo: some View {
        if viewModel.espacos.isEmpty && viewModel.estaCarregando {
            Spacer()
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
            Spacer()
        } else if viewModel.espacos.isEmpty {
            Spacer()
            estadoVazio
            Spacer()
        } else {
            listaDeEspacos
        }
    }
 
    private var estadoVazio: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text("Nenhum espaço encontrado")
                .font(.headline)
                .foregroundColor(.white)
            Text("Novos espaços aparecem aqui assim que forem publicados.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
 
    private var listaDeEspacos: some View {
        ScrollView {
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
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.recarregar()
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
    NavigationStack {
        TodosEspacosView(sessao: SessaoUsuario())
    }
}
