//
//  TabBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct TabBarView: View {
    @State private var mostraExclusao = false
    @State private var spotsViewModel: SpotsViewModel
    @State private var perfilViewModel: PerfilViewModel
    @State private var buscaViewModel: BuscaViewModel 
    private let sessao: SessaoUsuario

    init(sessao: SessaoUsuario) {
        self.sessao = sessao
        _spotsViewModel = State(initialValue: SpotsViewModel(sessao: sessao))
        _perfilViewModel = State(initialValue: PerfilViewModel(sessao: sessao))
        _buscaViewModel = State(initialValue: BuscaViewModel(sessao: sessao))
    }

    var body: some View {
        
        
        TabView {
            Tab("Spots", image: "SFspoticone") {
                SpotsView(viewModel: spotsViewModel)
            }

            Tab("Salvos", systemImage: "bookmark") {
                SalvosView()
            }

            Tab("Perfil", systemImage: "person.fill") {
                PerfilView(viewModel: perfilViewModel)
            }

            Tab(role: .search) {
                BuscaView(viewModel: buscaViewModel)
            }
        }
        .disabled(mostraExclusao)
        .overlay {
            PopUpTextoView(
                estaApresentado: $mostraExclusao,
                titulo: "Spot excluído com sucesso!"
            )
        }
        .onChange(of: sessao.alteracoesSpots.exclusaoConfirmada) { _, id in
            if id != nil { mostraExclusao = true }
        }
    }
}

#Preview {
    let sessao = SessaoUsuario()
    TabBarView(sessao: sessao)
        .environment(sessao)
        .preferredColorScheme(.dark)
}
