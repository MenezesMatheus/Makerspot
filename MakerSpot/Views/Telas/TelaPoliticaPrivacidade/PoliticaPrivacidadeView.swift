import SwiftUI

struct PoliticaPrivacidadeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(PoliticaPrivacidade.titulo)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text(PoliticaPrivacidade.ultimaAtualizacao)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PoliticaPrivacidade.introducao, id: \.self) { texto in
                        Text(texto)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                ForEach(PoliticaPrivacidade.secoes, id: \.titulo) { secao in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(secao.titulo)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)

                        ForEach(Array(secao.blocos.enumerated()), id: \.offset) { _, bloco in
                            conteudo(bloco)
                        }
                    }
                }

                Text(PoliticaPrivacidade.ultimaAtualizacaoNoRodape)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .font(.body)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(Color(.systemBackground))
        .navigationTitle(PoliticaPrivacidade.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func conteudo(_ bloco: PoliticaPrivacidade.Bloco) -> some View {
        switch bloco {
        case .paragrafo(let texto):
            Text(texto)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .subtitulo(let texto):
            Text(texto)
                .font(.headline)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)

        case .lista(let itens):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(itens, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .accessibilityHidden(true)
                        Text(item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PoliticaPrivacidadeView()
    }
    .preferredColorScheme(.dark)
}
