import SwiftUI

struct TermosDeUsoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(TermosDeUso.titulo)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text(TermosDeUso.ultimaAtualizacao)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                paragrafos(TermosDeUso.introducao)

                ForEach(TermosDeUso.secoes, id: \.titulo) { secao in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(secao.titulo)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)

                        paragrafos(secao.paragrafos)

                        if !secao.itens.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(secao.itens, id: \.self) { item in
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

                Text(TermosDeUso.ultimaAtualizacao)
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
        .navigationTitle("Termos de Uso")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paragrafos(_ textos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(textos, id: \.self) { texto in
                Text(texto)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TermosDeUsoView()
    }
    .preferredColorScheme(.dark)
}
