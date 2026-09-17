//
//  CardDestaqueView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//


import SwiftUI

struct CardEvento: View {
    let imageEvento: String
    let titulo: String
    let localizacao: String
    let data: String
    let hora: String
    @State private var isSaved: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            
            // Imagem superior
            Image(imageEvento)
                .resizable()
                .scaledToFill()
                .frame(height: 260)
               

            // retangulo escuro
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(titulo)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)

                    Spacer()

//                    Button {
//                        isSaved.toggle()
//                    } label: {
//                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
//                            .font(.system(size: 22))
//                            .foregroundColor(.white)
//                    }
                }

                HStack{
                    Label {
                        Text(localizacao)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.orange)
                    }

                    HStack{
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                        Text("\(data) \(hora)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemGray6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))

        
        .padding(.horizontal)
    }
}

struct CardEvento_Previews: PreviewProvider {
    static var previews: some View {
        CardEvento(
                    imageEvento: "fablab",
                    titulo: "Makerday",
                    localizacao: "Recife, PE",
                    data: "23.09",
                    hora: "10h"
                )
    }
}
