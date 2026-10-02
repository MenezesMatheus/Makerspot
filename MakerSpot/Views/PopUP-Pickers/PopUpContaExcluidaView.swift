import SwiftUI

struct PopUpContaExcluidaView: View {
    let aoFechar: () -> Void

    private let passos = [
        "Abra o app Ajustes.",
        "Toque no seu nome, no topo da tela.",
        "Toque em “Iniciar sessão com a Apple”.",
        "Selecione MakerSpot, toque em “Apagar” e confirme que deseja parar de usar."
    ]

    var body: some View {
        GeometryReader { geometria in
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ViewThatFits(in: .vertical) {
                    VStack(spacing: 20) {
                        instrucoes
                        botaoFechar
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 20) {
                        ScrollView {
                            instrucoes
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        botaoFechar
                    }
                }
                .padding(24)
                .frame(maxWidth: 380)
                .background(
                    Color(.secondarySystemBackground).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, aoFechar)
            }
            .frame(width: geometria.size.width, height: geometria.size.height)
        }
    }

    private var instrucoes: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Conta excluída")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Text("Sua conta no MakerSpot foi excluída. Para também desvincular o app da sua Conta Apple, siga os passos abaixo:")
                .foregroundStyle(.secondary)

            ForEach(passos.indices, id: \.self) { indice in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(indice + 1).")
                        .fontWeight(.semibold)
                    Text(passos[indice])
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var botaoFechar: some View {
        Button("Entendi", action: aoFechar)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    PopUpContaExcluidaView(aoFechar: { })
        .preferredColorScheme(.dark)
}
