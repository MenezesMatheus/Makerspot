import SwiftUI

private struct PopUpAnaliseFotosView: View {
    let mensagem: String
    let aoFechar: () -> Void

    private var paragrafos: [String] {
        mensagem.components(separatedBy: "\n\n")
    }

    var body: some View {
        GeometryReader { geometria in
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ViewThatFits(in: .vertical) {
                    VStack(spacing: 24) {
                        instrucoes
                        botaoFechar
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 24) {
                        ScrollView { instrucoes }
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
                .padding(16)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, aoFechar)
            }
            .frame(width: geometria.size.width, height: geometria.size.height)
        }
        .environment(\.colorScheme, .dark)
    }

    private var instrucoes: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Análise de conteúdo sensível desativada")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            if let introducao = paragrafos.first {
                Text(introducao)
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            ForEach(Array(paragrafos.dropFirst().enumerated()), id: \.offset) { _, topico in
                Text(topicoFormatado(topico))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func topicoFormatado(_ texto: String) -> AttributedString {
        var topico = AttributedString(texto)
        for nome in ["Ajustes", "Privacidade e Segurança", "Aviso de Conteúdo Sensível"] {
            if let intervalo = topico.range(of: nome) {
                topico[intervalo].font = .subheadline.bold()
            }
        }
        return topico
    }

    private var botaoFechar: some View {
        Button(action: aoFechar) {
            Text("OK")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AvisoAnaliseFotosDesativada: ViewModifier {
    let mensagem: String?
    let aoFechar: () -> Void

    private var estaApresentado: Bool {
        ErroModeracaoFotos.ehAvisoAnaliseDesativada(mensagem)
    }

    func body(content: Content) -> some View {
        content
            .disabled(estaApresentado)
            .accessibilityHidden(estaApresentado)
            .overlay {
                if estaApresentado, let mensagem {
                    PopUpAnaliseFotosView(mensagem: mensagem, aoFechar: aoFechar)
                }
            }
            .interactiveDismissDisabled(estaApresentado)
    }
}

extension View {
    func avisoAnaliseFotosDesativada(
        mensagem: String?,
        aoFechar: @escaping () -> Void
    ) -> some View {
        modifier(AvisoAnaliseFotosDesativada(mensagem: mensagem, aoFechar: aoFechar))
    }
}

#Preview {
    Color.black
        .avisoAnaliseFotosDesativada(
            mensagem: ErroModeracaoFotos.analiseDesativada.errorDescription,
            aoFechar: { }
        )
}
