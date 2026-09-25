//
//  TabBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct TabBarView: View {
    @State private var spotsViewModel: SpotsViewModel
    @State private var perfilViewModel: PerfilViewModel

    init(sessao: SessaoUsuario) {
        _spotsViewModel = State(initialValue: SpotsViewModel(sessao: sessao))
        _perfilViewModel = State(initialValue: PerfilViewModel(sessao: sessao))
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
                BuscaView()
            }
        }
    }
}

#Preview {
    let sessao = SessaoUsuario()
    TabBarView(sessao: sessao)
        .environment(sessao)
        .preferredColorScheme(.dark)
}
