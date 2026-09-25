//
//  MeusEventosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
 
struct MeusEventosView: View {
    @Environment(\.dismiss) private var dismiss
 
    @State private var viewModel: MeusEventosViewModel
    @State private var mostrarErro = false
    @State private var mostrarCriarEvento = false
    @State private var idParaExcluir: UUID?
    @State private var mostrarConfirmacaoExclusao = false
 
    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: MeusEventosViewModel(sessao: sessao))
    }
 
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.22, blue: 0.06),
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
            guard viewModel.eventos.isEmpty else { return }
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
        .alert("Excluir evento?", isPresented: $mostrarConfirmacaoExclusao) {
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
        .sheet(isPresented: $mostrarCriarEvento) {
            // checar tela de sheet de cadastro de espaco
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
 
            Button(action: { mostrarCriarEvento = true }) {
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
            Text("Meus Eventos")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
 
            Text("Gerencie os eventos e mantenha tudo atualizado")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
 
    // conteudo da tela
 
    @ViewBuilder
    private var conteudo: some View {
        if viewModel.eventos.isEmpty && viewModel.estaCarregando {
            Spacer()
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
            Spacer()
        } else if viewModel.eventos.isEmpty {
            Spacer()
            estadoVazio
            Spacer()
        } else {
            listaDeEventos
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
 
    private var listaDeEventos: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.eventos) { spot in
                    CardMeuSpotView(
                        tipo: spot.tipo,
                        titulo: spot.nome,
                        nomeImagem: nomeImagem(para: spot),
                        textoInfo: textoInfo(para: spot),
                        localCidade: localCidade(para: spot),
                        estaAtivo: spot.estaAtivo,
                        aoAlternarAtivo: { novoValor in
                            Task { await viewModel.definirAtivo(novoValor, para: spot.id) }
                        }
                    )
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
 
    // formatacao do card
 
    private func localCidade(para spot: Spot) -> String {
        "\(spot.localizacao.endereco.cidade), \(spot.localizacao.endereco.estado)"
    }
 
    private func textoInfo(para spot: Spot) -> String {
        switch spot.detalhes {
        case .espaco:
            return spot.telefone
        case .evento(let evento):
            let formatador = DateFormatter()
            formatador.dateFormat = "dd.MM HH'h'"
            return formatador.string(from: evento.inicio)
        }
    }
 
    private func nomeImagem(para spot: Spot) -> String {
        spot.tipo == .evento ? "evento_placeholder" : "evento_placeholder"
    }
}
 
#Preview {
    NavigationStack {
        MeusEventosView(sessao: SessaoUsuario())
    }
}
