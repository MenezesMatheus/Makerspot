//
//  SalvosView.swift
//  MakerSpot
//

import SwiftUI
import Combine

struct SalvosView: View {
    @Environment(SessaoUsuario.self) private var sessao
    @Bindable private var viewModel: SalvosViewModel
    @State private var categoriaSelecionada: CategoriaSalvos = .eventos
    @State private var explorarEspacos = false
    @State private var explorarEventos = false
    @State private var jaApareceu = false

    init(viewModel: SalvosViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cabecalho
                if let aviso = viewModel.avisoSincronizacao {
                    Text(aviso)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                seletor
                conteudo
            }
            .background { fundo }
            .foregroundStyle(.white)
            .navigationTitle("Salvos")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $explorarEspacos) {
                TodosEspacosView(sessao: sessao)
            }
            .navigationDestination(isPresented: $explorarEventos) {
                TodosEventosView(sessao: sessao)
            }
            .task {
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
            .alert(
                "Não foi possível carregar os salvos",
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
    
    
    // MARK: - Cabeçalho
    
    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tudo o que você quer acompanhar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
    
    
    // MARK: - Segmented Control
    
    private var seletor: some View {
        Picker(
            "Categoria",
            selection: $categoriaSelecionada
        ) {
            Text("Eventos")
                .tag(CategoriaSalvos.eventos)

            Text("Espaços")
                .tag(CategoriaSalvos.espacos)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }
    
    
    // MARK: - Conteúdo
    
    @ViewBuilder
    private var conteudo: some View {
        switch categoriaSelecionada {
            
        case .espacos:
            if viewModel.espacosSalvos.isEmpty {
                estadoVazioRolavel(estadoVazioEspacos)
            } else {
                listaSalvos(viewModel.espacosSalvos)
            }
            
        case .eventos:
            if viewModel.eventosSalvos.isEmpty {
                estadoVazioRolavel(estadoVazioEventos)
            } else {
                listaSalvos(viewModel.eventosSalvos)
            }
        }
    }
    
    
    // MARK: - Lista

    private func estadoVazioRolavel<Conteudo: View>(_ conteudo: Conteudo) -> some View {
        GeometryReader { geometria in
            ScrollView {
                conteudo.frame(minHeight: geometria.size.height)
            }
            .refreshable { await viewModel.carregar() }
        }
    }
    
    private func listaSalvos(
        _ itens: [ItemSpotSalvo]
    ) -> some View {
        
        ScrollView {
            LazyVStack(spacing: 16) {
                
                ForEach(itens, id: \.spot.id) { item in
                    
                    CardSimplesView(
                        dados: CardSimplesDados(
                            spot: item.spot,
                            imagem: imagem(do: item.spot)
                        ),
                        modo: .visitante(
                            estaSalvo: true,
                            estaProcessando: false,
                            podeSalvar: true,
                            aoAlternar: {
                                removerDosSalvos(item)
                            }
                        ),
                        aoSelecionar: {
                            
                        }
                    )
                    .task(id: item.spot.fotoIDs) {
                        await viewModel.fotosSpots.carregarFotoPrincipal(do: item.spot)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.carregar()
        }
    }
    
    
    // MARK: - Estado vazio Espaços
    
    private var estadoVazioEspacos: some View {
        estadoVazio(
            titulo: "Nenhum espaço salvo",
            descricao:
                "Salve seus espaços favoritos para\n" +
                "encontrá-los rapidamente e\n" +
                "acompanhar suas novidades",
            tituloBotao: "Explorar Espaços"
        ) {
            explorarEspacos = true
        }
    }
    
    
    // MARK: - Estado vazio Eventos
    
    private var estadoVazioEventos: some View {
        estadoVazio(
            titulo: "Nenhum evento salvo",
            descricao:
                "Salve seus eventos favoritos para\n" +
                "encontrá-los rapidamente e\n" +
                "acompanhar suas novidades",
            tituloBotao: "Explorar Eventos"
        ) {
            explorarEventos = true
        }
    }
    
    
    // MARK: - Estado vazio
    
    private func estadoVazio(
        titulo: String,
        descricao: String,
        tituloBotao: String,
        acao: @escaping () -> Void
    ) -> some View {
        
        VStack(spacing: 0) {
            
            Spacer()
            
            
            // MARK: Ilustração
            
            Image("SVG-Login")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
            
            
            // MARK: Textos
            
            VStack(spacing: 4) {
                
                Text(titulo)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(descricao)
                    .font(.body)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            
            Spacer()
            
            
            // MARK: Botão Explorar
            
            Button {
                acao()
            } label: {
                Text(tituloBotao)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
             //       .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    // MARK: - Remover dos salvos
    
    private func removerDosSalvos(_ item: ItemSpotSalvo) {
        viewModel.dessalvar(spotID: item.spot.id)
    }

    private func imagem(do spot: Spot) -> ImagemCardSimples {
        guard let foto = viewModel.fotosSpots.fotoPrincipal(do: spot) else {
            return .placeholder
        }
        return .arquivo(foto.arquivoURL)
    }
}


// MARK: - Categoria

private enum CategoriaSalvos {
    case espacos
    case eventos
}


// MARK: - Preview

#Preview {
    let sessao = SessaoUsuario()
    SalvosView(viewModel: SalvosViewModel(sessao: sessao))
        .environment(sessao)
}
