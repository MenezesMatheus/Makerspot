//
//  BuscaView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//


import SwiftUI

struct BuscaView: View {
   @Bindable var viewModel: BuscaViewModel
   var aoSelecionarSpot: (Spot) -> Void = { _ in }

   var body: some View {
       NavigationStack {
           ScrollView {
               LazyVStack(spacing: 12) {
//                   filtroTipo
                   
                   ForEach(viewModel.resultados) { spot in
                       CardSimplesView(
                           dados: CardSimplesDados(
                               spot: spot,
                               imagem: imagem(para: spot)
                           ),
                           modo: .visitante(
                               estaSalvo: viewModel.estaSalvo(spot),
                               estaProcessando: viewModel.estaAlterandoSalvo(spot),
                               podeSalvar: viewModel.podeSalvar(spot),
                               aoAlternar: {
                                   Task { await viewModel.alternarSalvo(do: spot) }
                               }
                           ),
                           aoSelecionar: { aoSelecionarSpot(spot) }
                       )
                       .task {
                           await viewModel.fotosSpots.carregarFotoPrincipal(do: spot)
                           await carregarMaisSeNecessario(spot)
                       }
                   }

                   if viewModel.estaCarregando {
                       ProgressView()
                           .padding(.vertical, 24)
                   }
               }
               .padding(.horizontal)
               .padding(.top, 8)
           }
           .navigationTitle("Buscar")
           .searchable(text: $viewModel.texto, prompt: "Eventos, Espaços e mais")
           .overlay {
               if viewModel.resultados.isEmpty && !viewModel.estaCarregando {
                   ContentUnavailableView.search(text: viewModel.texto)
               }
           }
           .refreshable {
               await viewModel.recarregar()
           }
           .task {
               if viewModel.spotsCarregados.isEmpty {
                   await viewModel.carregarPrimeiraPagina()
               }
           }
           .alert(
               "Ops",
               isPresented: Binding(
                   get: { viewModel.mensagemDeErro != nil },
                   set: { novoValor in if !novoValor { viewModel.limparErro() } }
               ),
               presenting: viewModel.mensagemDeErro
           ) { _ in
               Button("OK") { viewModel.limparErro() }
           } message: { mensagem in
               Text(mensagem)
           }
       }
   }

//   private var filtroTipo: some View {
//       Picker(
//           "Tipo",
//           selection: Binding(
//               get: { viewModel.tipoSelecionado },
//               set: { novoTipo in Task { await viewModel.definirTipo(novoTipo) } }
//           )
//       ) {
//           Text("Todos").tag(TipoSpot?.none)
//           ForEach(TipoSpot.allCases, id: \.self) { tipo in
//               Text(tipo == .evento ? "Eventos" : "Espaços")
//                   .tag(TipoSpot?.some(tipo))
//           }
//       }
//       .pickerStyle(.segmented)
//   }

   private func imagem(para spot: Spot) -> ImagemCardSimples {
       guard let foto = viewModel.fotosSpots.fotoPrincipal(do: spot) else {
           return .placeholder
       }
       return .arquivo(foto.arquivoURL)
   }

   private func carregarMaisSeNecessario(_ spot: Spot) async {
       guard spot.id == viewModel.resultados.last?.id else { return }
       await viewModel.carregarProximaPagina()
   }
}

// MARK: - Preview
 
// Preview "burro": sem usuário logado e sem mocks de CRUD, então a tela
// tende a ficar em loading ou mostrar erro (sem sessão/rede reais nesse
// ambiente). Serve só pra conferir layout, não pra ver dados de verdade.
// Quando quiser previews com dados reais, vale criar mocks de
// SpotCRUD/SalvosCRUD/FotoCRUD.
#Preview {
    BuscaView(viewModel: BuscaViewModel(sessao: SessaoUsuario()))
}
 

