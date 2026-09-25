//
//  MeusEspacosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
 
struct MeusEspacosView: View {
    @Environment(\.dismiss) private var dismiss
 
    @State private var viewModel: MeusEspacosViewModel
    @State private var mostrarErro = false
    @State private var mostrarCriarEspaco = false
    @State private var idParaExcluir: UUID?
    @State private var mostrarConfirmacaoExclusao = false
 
    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: MeusEspacosViewModel(sessao: sessao))
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
            await viewModel.carregar()
        }
        .onChange(of: viewModel.mensagemDeErro) { _, novoValor in
            mostrarErro = novoValor != nil
        }
        .alert("Não foi possível carregar", isPresented: $mostrarErro) {
            Button("Tentar novamente") {
                Task { await viewModel.carregar() }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.mensagemDeErro ?? "Tente novamente em instantes.")
        }
        .alert("Excluir espaço?", isPresented: $mostrarConfirmacaoExclusao) {
            Button("Excluir", role: .destructive) {
                guard let id = idParaExcluir else { return }
                Task { await viewModel.excluir(id: id) }
            }
            Button("Cancelar", role: .cancel) {
                idParaExcluir = nil
            }
        } message: {
            Text("Essa ação não pode ser desfeita.")
        }
        .sheet(isPresented: $mostrarCriarEspaco) {
            // TODO: apresentar a tela de criação de espaço quando estiver disponível
        }
    }
 
    // MARK: - Cabeçalho
 
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
            Text("Meus Espaços")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
 
            Text("Gerencie os espaços e mantenha tudo atualizado")
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
            Text("Você ainda não publicou espaços")
                .font(.headline)
                .foregroundColor(.white)
            Text("Toque em + para cadastrar seu primeiro espaço.")
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
                        modo: .proprietario(
                            estaAtivo: spot.estaAtivo,
                            estaProcessando: viewModel.spotEmAlteracao == spot.id,
                            aoAlternar: { novoValor in
                                Task { await viewModel.definirAtivo(novoValor, para: spot.id) }
                            }
                        ),
                        aoSelecionar: {}
                    )
                    .task {
                        await viewModel.fotosSpots.carregarFotoPrincipal(do: spot)
                    }
                    .opacity(viewModel.spotEmAlteracao == spot.id ? 0.5 : 1)
                    .disabled(viewModel.spotEmAlteracao == spot.id)
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
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.carregar()
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
        MeusEspacosView(sessao: SessaoUsuario())
    }
}
