//
//  SpotsView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct SpotsView: View {
    var body: some View {
        
        ZStack {
                   LinearGradient(
                    colors: [.accent.opacity(0.3),
                        .black.opacity(0.6), .black.opacity(0.6), .black.opacity(0.6), .black.opacity(0.7),  .black.opacity(0.8)],
                       startPoint: .top,
                       endPoint: .bottom
                   )
                   .ignoresSafeArea()
        }
    }
}

#Preview {
    SpotsView()
}
