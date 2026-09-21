//
//  TabBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct TabBarView: View {
    
    @State private var searchText = ""
    
    var body: some View {
        TabView {
            
            Tab("Spots", image: "SFspoticone" ) {
                SpotsView()
            }
            
            Tab("Salvos", systemImage: "bookmark") {
                SalvosView()
            }
            
            Tab("Perfil", systemImage: "person.fill") {
                PerfilView(sessao: SessaoUsuario()) //COLOQUEI ISSO AQUI POR ENQUANTO, PRA CONSEGUIR CONSTRUIR A TELA. Matheus depois resolve o b.o la
            }
            
            Tab(role: .search) {
               BuscaView()
            }
        }
        .searchable(text: $searchText)
      
    }
}

#Preview {
  TabBarView()
        .preferredColorScheme(.dark)
}

