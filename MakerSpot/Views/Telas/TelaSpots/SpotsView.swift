//
//  SpotsView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct SpotsView: View {
    var body: some View {
        
        NavigationStack {
            ZStack (alignment: .top) {
                LinearGradient(
                    colors: [.accent.opacity(0.4),
                             .black,
                            .black.opacity(0.6), .black.opacity(0.6), .black.opacity(0.7),  .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
               .toolbar {
                    
                }
                
                ScrollView {
                    VStack {
                        NavigationLink(destination: TodosEventosView()) {
                            HStack {
                                Text("Eventos")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        
                        ScrollView(.horizontal) {
                            HStack {
                                CardEvento(
                                            imageEvento: "fablab",
                                            titulo: "Makerday",
                                            localizacao: "Recife, PE",
                                            data: "23.09",
                                            hora: "10h",
                                            estaSalvo: true,
                                            estaAlterandoSalvo: false,
                                            podeSalvar: true,
                                            aoAlternarSalvo: {}
                                        )
                                CardEvento(
                                    imageEvento: "",
                                    titulo: "",
                                    localizacao: "",
                                    data: "",
                                    hora: "",
                                    estaSalvo: false,
                                    estaAlterandoSalvo: false,
                                    podeSalvar: true,
                                    aoAlternarSalvo: {}
                                )
                                CardEvento(
                                    imageEvento: "",
                                    titulo: "",
                                    localizacao: "",
                                    data: "",
                                    hora: "",
                                    estaSalvo: false,
                                    estaAlterandoSalvo: false,
                                    podeSalvar: true,
                                    aoAlternarSalvo: {}
                                )
                            }
                        }
                        }
                       
                        
                        NavigationLink(destination: TodosEspacosView()) {
                            HStack{
                                Text("Espaços")
                                    .font(.system(size: 34, weight: .bold))
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                                
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        // MATHEUS TU VAI VER ISSO DEPOIS
//                .navigationTitle("Spots")
//                .navigationSubtitle("Encontre eventos e espaços para você.")
        }

    }

#Preview {
    SpotsView()
}
