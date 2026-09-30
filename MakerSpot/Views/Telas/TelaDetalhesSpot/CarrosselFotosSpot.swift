import SwiftUI
import UIKit

/// Componente de apresentação: o carregamento das fotos pertence ao ViewModel da tela.
struct CarrosselFotosSpot: View {
    let fotos: [FotoDisponivel]
    var fotoProvisoriaURL: URL? = nil

    private var imagens: [UIImage] {
        let disponiveis = fotos.compactMap {
            UIImage(contentsOfFile: $0.arquivoURL.path)
        }
        if !disponiveis.isEmpty { return disponiveis }
        if let fotoProvisoriaURL,
           let imagem = UIImage(contentsOfFile: fotoProvisoriaURL.path) {
            return [imagem]
        }
        return []
    }

    var body: some View {
        let imagensDisponiveis = imagens
        if !imagensDisponiveis.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(imagensDisponiveis.indices, id: \.self) { indice in
                        Image(uiImage: imagensDisponiveis[indice])
                            .resizable()
                            .scaledToFill()
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
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    CarrosselFotosSpot(fotos: [])
}
