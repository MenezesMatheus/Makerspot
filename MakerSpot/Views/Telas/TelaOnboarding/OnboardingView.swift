//
//  OnboardingView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ZStack {
            Onboarding1(
                imagem: "ONBOARDING 1",
                texto1: "Bem-vindo \nao Makerspot",
                texto2: "Encontre espaços e \neventos para criar e \nconectar."
            )
//            Onboarding2(
//                imagem: "ONBOARDING 2",
//                texto1: "Compartilhe, \nColabore, \nTransforme",
//                texto2: "Ofereça experiências\ne fortaleça\na comunidade maker")
            
    }
    }
}
#Preview {
    OnboardingView()
}

