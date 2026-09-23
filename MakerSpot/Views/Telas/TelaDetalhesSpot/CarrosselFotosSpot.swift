//
//  CarrosselFotosSpot.swift
//  MakerSpot
//
//  Created by Bianca Duarte de Moraes Guerra on 22/09/26.
//

import Foundation
import SwiftUI

struct CarrosselFotosSpot: View {
    let quantidadeFotos: Int

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(0..<quantidadeFotos, id: \.self) { _ in
                    fotoPlaceholder
                        .containerRelativeFrame(
                            .horizontal,
                            count: 10,
                            span: 9,
                            spacing: 8
                        )
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private var fotoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .frame(height: 320)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    CarrosselFotosSpot(quantidadeFotos: 4)
}
