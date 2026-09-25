//
//  SalvosView.swift
//  MakerSpot
//

import SwiftUI

struct SalvosView: View {
        
    @State private var categoriaSelecionada: CategoriaSalvos = .espacos
    
    
    @State private var espacosSalvos: [CardSimplesDados] = [
       
    ]
    
    // Deixe [] para testar a tela vazia
    @State private var eventosSalvos: [CardSimplesDados] = [
        CardSimplesDados(
            tipo: .evento,
            titulo: "Mobile-se",
            imagem: .asset("mobilese"),
            textoInfo: "23.09 10h",
            localCidade: "Recife, PE"
        ),
        CardSimplesDados(
            tipo: .evento,
            titulo: "Mobile-se",
            imagem: .asset("mobilese"),
            textoInfo: "23.09 10h",
            localCidade: "Recife, PE"
        ),
        CardSimplesDados(
            tipo: .evento,
            titulo: "Mobile-se",
            imagem: .asset("mobilese"),
            textoInfo: "23.09 10h",
            localCidade: "Recife, PE"
        )
    ]
    
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            
            cabecalho
            
            seletor
            
            conteudo
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }
    
    
    // MARK: - Cabeçalho
    
    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text("Salvos")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Tudo o que você quer acompanhar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    
    // MARK: - Segmented Control
    
    private var seletor: some View {
        Picker(
            "Categoria",
            selection: $categoriaSelecionada
        ) {
            Text("Espaços")
                .tag(CategoriaSalvos.espacos)
            
            Text("Eventos")
                .tag(CategoriaSalvos.eventos)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.top, 22)
    }
    
    
    // MARK: - Conteúdo
    
    @ViewBuilder
    private var conteudo: some View {
        switch categoriaSelecionada {
            
        case .espacos:
            if espacosSalvos.isEmpty {
                estadoVazioEspacos
            } else {
                listaSalvos(espacosSalvos)
            }
            
        case .eventos:
            if eventosSalvos.isEmpty {
                estadoVazioEventos
            } else {
                listaSalvos(eventosSalvos)
            }
        }
    }
    
    
    // MARK: - Lista
    
    private func listaSalvos(
        _ itens: [CardSimplesDados]
    ) -> some View {
        
        ScrollView {
            LazyVStack(spacing: 16) {
                
                ForEach(itens) { item in
                    
                    CardSimplesView(
                        dados: item,
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
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
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
            // Navegar para Spots
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
            // Navegar para Spots
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
    
    private func removerDosSalvos(
        _ item: CardSimplesDados
    ) {
        
        switch item.tipo {
            
        case .espaco:
            withAnimation {
                espacosSalvos.removeAll {
                    $0.id == item.id
                }
            }
            
        case .evento:
            withAnimation {
                eventosSalvos.removeAll {
                    $0.id == item.id
                }
            }
        }
    }
}


// MARK: - Categoria

private enum CategoriaSalvos {
    case espacos
    case eventos
}


// MARK: - Preview

#Preview {
    NavigationStack {
        SalvosView()
    }
    .environment(SessaoUsuario())
}
