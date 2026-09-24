import SwiftUI
import UIKit

/// Componente de apresentação: o carregamento das fotos pertence ao ViewModel da tela.
struct CarrosselFotosSpot: View {
    let fotos: [FotoDisponivel]
    var estaCarregando = false

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(0..<max(fotos.count, 3), id: \.self) { indice in
                    Group {
                        if fotos.indices.contains(indice),
                           let imagem = UIImage(
                            contentsOfFile: fotos[indice].arquivoURL.path
                           ) {
                            Image(uiImage: imagem)
                                .resizable()
                                .scaledToFill()
                        } else {
                            fotoPlaceholder
                        }
                    }
                    .frame(height: 320)
                    .containerRelativeFrame(
                        .horizontal,
                        count: 10,
                        span: 9,
                        spacing: 8
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .overlay {
            if estaCarregando {
                ProgressView()
            }
        }
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
    CarrosselFotosSpot(fotos: [])
}
