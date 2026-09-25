//
//  onboarding.swift
//  MakerSpot
//
//  Created by Maria Júlia Alves Sales on 22/09/26.
//

import SwiftUI

struct Onboarding1: View {
    let imagem: String
    let texto1: String
    let texto2: String

    var body: some View {
        PaginaOnboarding(
            imagem: imagem,
            textoSuperior: texto1,
            textoInferior: texto2
        )
    }
}

struct Onboarding2: View {
    let imagem: String
    let texto1: String
    let texto2: String

    var body: some View {
        PaginaOnboarding(
            imagem: imagem,
            textoSuperior: texto1,
            textoInferior: texto2
        )
    }
}

private struct PaginaOnboarding: View {
    let imagem: String
    let textoSuperior: String
    let textoInferior: String

    var body: some View {
        GeometryReader { geometria in
            let layoutCompacto = geometria.size.height < 650
            let margemHorizontal: CGFloat = layoutCompacto ? 16 : 24
            let alturaImagem = layoutCompacto
                ? max(0, geometria.size.height - 100)
                : geometria.size.height

            ZStack {
                Color.black

                Image(imagem)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometria.size.width,
                        height: alturaImagem
                    )
                    .offset(y: layoutCompacto ? 40 : 0)

                VStack(alignment: .leading, spacing: 0) {
                    Text(textoSuperior)
                        .font(
                            .system(
                                size: layoutCompacto ? 30 : 34,
                                weight: .bold
                            )
                        )
                        .multilineTextAlignment(.leading)
                        .lineSpacing(layoutCompacto ? -2 : 0)
                        .minimumScaleFactor(0.85)
                        .frame(
                            maxWidth: geometria.size.width * 0.68,
                            alignment: .leading
                        )

                    Spacer(minLength: 16)

                    HStack {
                        Spacer(minLength: geometria.size.width * 0.2)

                        Text(textoInferior)
                            .font(
                                .system(
                                    size: layoutCompacto ? 18 : 20,
                                    weight: .bold
                                )
                            )
                            .multilineTextAlignment(.trailing)
                            .lineSpacing(layoutCompacto ? -1 : 0)
                            .minimumScaleFactor(0.85)
                            .frame(
                                maxWidth: geometria.size.width * 0.68,
                                alignment: .trailing
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, margemHorizontal)
                .padding(.top, layoutCompacto ? 20 : 40)
                .padding(.bottom, layoutCompacto ? 12 : 28)
            }
        }
        .clipped()
    }
}

#Preview("Onboarding 1") {
    Onboarding1(
        imagem: "ONBOARDING 1",
        texto1: "Bem-vindo \nao Makerspot",
        texto2: "Encontre espaços e \neventos para criar e \nconectar."
    )
}

#Preview("Onboarding 2") {
    Onboarding2(
        imagem: "ONBOARDING 2",
        texto1: "Compartilhe, \nColabore, \nTransforme",
        texto2: "Ofereça experiências\ne fortaleça\na comunidade maker"
    )
}
