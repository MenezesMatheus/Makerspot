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
    let estaSalvo: Bool
    let estaAlterandoSalvo: Bool
    let podeSalvar: Bool
    private let aoAlternarSalvo: () -> Void

    init(
        imageEvento: String,
        titulo: String,
        localizacao: String,
        data: String,
        hora: String,
        estaSalvo: Bool,
        estaAlterandoSalvo: Bool,
        podeSalvar: Bool,
        aoAlternarSalvo: @escaping () -> Void
    ) {
        self.imageEvento = imageEvento
        self.titulo = titulo
        self.localizacao = localizacao
        self.data = data
        self.hora = hora
        self.estaSalvo = estaSalvo
        self.estaAlterandoSalvo = estaAlterandoSalvo
        self.podeSalvar = podeSalvar
        self.aoAlternarSalvo = aoAlternarSalvo
    }

    var body: some View {
        VStack(spacing: 0) {
                
            // Imagem superior
            Image(imageEvento)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 273)
//                .frame(height: 273)
                .clipped()

            // retangulo escuro
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(titulo)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                        .lineLimit(1)

                    Spacer()

                    Button(action: aoAlternarSalvo) {
                        Group {
                            if estaAlterandoSalvo {
                                ProgressView()
                            } else {
                                Image(
                                    systemName: estaSalvo
                                        ? "bookmark.fill"
                                        : "bookmark"
                                )
                                .font(.system(size: 22))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(!podeSalvar || estaAlterandoSalvo)
                    .opacity(podeSalvar ? 1 : 0.45)
                    .accessibilityLabel(
                        estaSalvo ? "Remover dos salvos" : "Salvar evento"
                    )
                    .accessibilityValue(
                        estaAlterandoSalvo ? "Atualizando" : ""
                    )
                }

                HStack{
                    Label {
                        Text(localizacao)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
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
                            .lineLimit(1)
                    }
                }
            }
           .frame(width: 280)
            .padding(20)
            .background(Color(.systemGray6))
        }
//        .frame(width: 491, height: 327)
        .clipShape(RoundedRectangle(cornerRadius: 24))


        
        .padding(.horizontal)
    }
}

struct CardEvento_Previews: PreviewProvider {
    static var previews: some View {
       // NavigationStack{
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
      //  }
    }
}
