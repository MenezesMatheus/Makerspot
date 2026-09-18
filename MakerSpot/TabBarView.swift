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
                PerfilView()
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
