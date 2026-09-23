//
//  onboarding.swift
//  MakerSpot
//
//  Created by Maria Júlia Alves Sales on 22/09/26.
//

import SwiftUI

struct Onboarding1: View {
    let imagem: String
    let texto1:String
    let texto2:String

    var body: some View {
        ZStack(alignment: .topLeading) {

            Image(imagem)
                .resizable()
                .scaledToFit()
                .containerRelativeFrame([.horizontal, .vertical])
                .ignoresSafeArea()

            // Texto de cima
            VStack(alignment: .leading) {
                Color.clear
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.09 }

                Text(texto1)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.leading)
                    .containerRelativeFrame(.horizontal) { length, _ in length * 0.6 }
            }

            // Texto de baixo
            VStack {
                Spacer()

                HStack{
                    Spacer()
                    Text(texto2)
                        .font(.title3.bold())
                        .multilineTextAlignment(.trailing)
                        .containerRelativeFrame(.horizontal) { length, _ in length * 0.55 }
                }

                Color.clear
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.07 }
            }

//            BotaoView(nome: "Continuar", acao: { })
        }
        .containerRelativeFrame([.horizontal, .vertical])
        .ignoresSafeArea()
    }
}

struct Onboarding2: View {
    let imagem: String
    let texto1:String
    let texto2:String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            Image(imagem)
                .resizable()
                .scaledToFit()
                .containerRelativeFrame([.horizontal, .vertical])
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Color.clear
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.07 }
                
                Text(texto1)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.leading)
                    .containerRelativeFrame(.horizontal) { length, _ in length * 0.6 }
                    .padding(.leading)
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    Text(texto2)
                        .font(.title3.bold())
                        .multilineTextAlignment(.trailing)
                        .containerRelativeFrame(.horizontal) { length, _ in length * 0.55 }
                }
                
                Color.clear
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.07 }
            }
        }
        .containerRelativeFrame([.horizontal, .vertical])
        .ignoresSafeArea()
    }
    
}
    #Preview {
        Onboarding1(imagem:"ONBOARDING 1", texto1: "Bem-vindo \nao Makerspot", texto2: "Encontre espaços e \neventos para criar e \nconectar.")
    }
    
    #Preview {
        Onboarding2 (imagem:"ONBOARDING 2", texto1: "Compartilhe, \nColabore, \nTransforme", texto2: "Ofereça experiências\ne fortaleça\na comunidade maker")
    }
    

