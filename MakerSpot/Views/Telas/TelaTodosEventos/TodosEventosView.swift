//
//  MeusEspacosView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
 
struct TodosEventosView: View {
    @Environment(\.dismiss) private var dismiss
 
    @State private var viewModel: TodosEventosViewModel
    @State private var idsSalvos: Set<UUID> = []
    @State private var idsAlternandoSalvo: Set<UUID> = []
    @State private var mostrarErro = false
    @State private var mostrarCriarEspaco = false
 
    private let salvosCRUD: SalvosCRUD
 
    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: TodosEventosViewModel(sessao: sessao))
        self.salvosCRUD = SalvosCRUD(sessao: sessao)
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
            await viewModel.carregarPrimeiraPagina()
            await sincronizarSalvos()
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
            // apresentar a tela de cadastro de evento quando disponivel
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
            Text("Eventos")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
 
            Text("Participe e Compartilhe")
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
                ForEach(viewModel.eventos) { spot in
                    CardSpotView(
                        tipo: spot.tipo,
                        titulo: spot.nome,
                        nomeImagem: nomeImagem(para: spot),
                        textoInfo: textoInfo(para: spot),
                        localCidade: localCidade(para: spot),
                        estaSalvo: idsSalvos.contains(spot.id),
                        aoAlternarSalvo: { alternarSalvo(spot: spot) }
                    )
                    .onAppear {
                        if spot.id == viewModel.eventos.last?.id {
                            Task { await viewModel.carregarProximaPagina() }
                        }
                    }
                }
 
                if viewModel.estaCarregando && !viewModel.eventos.isEmpty {
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
            await sincronizarSalvos()
        }
    }
 
    // salvos
 
    private func sincronizarSalvos() async {
        do {
            let salvos = try await salvosCRUD.listar()
            idsSalvos = Set(salvos.map(\.spotID))
        } catch {
            // mantem o estado atual dos salvos em caso de falha silenciosa
        }
    }
 
    private func alternarSalvo(spot: Spot) {
        guard !idsAlternandoSalvo.contains(spot.id) else { return }
        let estavaSalvo = idsSalvos.contains(spot.id)
 
        idsAlternandoSalvo.insert(spot.id)
        if estavaSalvo {
            idsSalvos.remove(spot.id)
        } else {
            idsSalvos.insert(spot.id)
        }
 
        Task {
            defer { idsAlternandoSalvo.remove(spot.id) }
            do {
                if estavaSalvo {
                    try await salvosCRUD.dessalvar(spotID: spot.id)
                } else {
                    _ = try await salvosCRUD.salvar(spotID: spot.id)
                }
            } catch {
                // reverte a alteração otimista em caso de falha
                if estavaSalvo {
                    idsSalvos.insert(spot.id)
                } else {
                    idsSalvos.remove(spot.id)
                }
            }
        }
    }
 
    // formatacao do card
 
    private func localCidade(para spot: Spot) -> String {
        "\(spot.localizacao.endereco.cidade), \(spot.localizacao.endereco.estado)"
    }
 
    private func textoInfo(para spot: Spot) -> String {
        switch spot.detalhes {
        case .espaco:
            // ajustar para o nome real da propriedade de horário na entidade de espaco
            return spot.telefone
        case .evento(let evento):
            let formatador = DateFormatter()
            formatador.dateFormat = "dd.MM HH'h'"
            return formatador.string(from: evento.inicio)
        }
    }
 
    private func nomeImagem(para spot: Spot) -> String {
        spot.tipo == .espaco ? "espaco_placeholder" : "evento_placeholder"
    }
}
 
#Preview {
    NavigationStack {
        TodosEventosView(sessao: SessaoUsuario())
    }
}
