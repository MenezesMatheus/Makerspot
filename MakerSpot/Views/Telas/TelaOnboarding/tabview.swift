//
//  tabview.swift
//  MakerSpot
//
//  Created by Maria Júlia Alves Sales on 22/09/26.
//

import SwiftUI

struct tabview: View {
    @State private var paginaAtual = 0
    private let totaldepaginas = 2
    var aoConcluir: () -> Void
    

    var body: some View {
        VStack {
            TabView(selection: $paginaAtual) {
                Onboarding1(imagem: "ONBOARDING 1", texto1: "Bem-vindo \nao Makerspot", texto2: "Encontre espaços e \neventos para criar e \nconectar.")
                    .tag(0)

                Onboarding2(imagem: "ONBOARDING 2", texto1: "Compartilhe, \nColabore, \nTransforme", texto2: "Ofereça experiências\ne fortaleça\na comunidade maker")
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Spacer()
                BotaoView(
                    nome: paginaAtual == totaldepaginas - 1 ? "Próximo" : "Continuar",
                    acao: continuar
                )
                Spacer()
               
            }
            
        }
//        .fullScreenCover(isPresented: $shownext) {
//            LoginView(sessao: SessaoUsuario())
//        }
    }

    private func continuar() {
           if paginaAtual < totaldepaginas - 1 {
               withAnimation {
                   paginaAtual += 1
               }
           } else {
               aoConcluir()
           }
       }
}

#Preview {
    tabview(aoConcluir: {})
}

