import SwiftUI

struct PopUpTermosDeUsoView: View {
    @Binding var aceitouTermos: Bool
    @Binding var aceitouPoliticaPrivacidade: Bool
    let estaSalvando: Bool
    let podeConcluir: Bool
    let aoCancelar: () -> Void
    let aoConfirmar: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Termos e Privacidade")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)

                        Text("Antes de criar sua conta, leia e confirme os Termos e Condições de Uso e a Política de Privacidade do MakerSpot.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            TermosDeUsoView()
                        } label: {
                            Text("Clique aqui para ler os termos de uso")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .underline()
                                .frame(minHeight: 44, alignment: .leading)
                        }

                        Toggle(isOn: $aceitouTermos) {
                            Text("Li e concordo com os Termos e Condições de Uso do MakerSpot.")
                                .font(.subheadline)
                        }
                        .toggleStyle(CheckboxTermosStyle())
                    }
                    .disabled(estaSalvando)

                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            PoliticaPrivacidadeView()
                        } label: {
                            Text("Clique aqui para ler a política de privacidade")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .underline()
                                .frame(minHeight: 44, alignment: .leading)
                        }

                        Toggle(isOn: $aceitouPoliticaPrivacidade) {
                            Text("Li e estou ciente da Política de Privacidade do MakerSpot.")
                                .font(.subheadline)
                        }
                        .toggleStyle(CheckboxTermosStyle())
                    }
                    .disabled(estaSalvando)

                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            Button(action: aoConfirmar) {
                                Text(estaSalvando ? "Criando conta…" : "Concluir cadastro")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 24)
                            }
                            .buttonStyle(.glassProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .tint(.accentColor)
                            .disabled(!aceitouTermos || !aceitouPoliticaPrivacidade || !podeConcluir || estaSalvando)

                            Button(role: .cancel, action: aoCancelar) {
                                Text("Cancelar")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 24)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .disabled(estaSalvando)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 360)
            .background(
                Color(.secondarySystemBackground).opacity(0.96),
                in: RoundedRectangle(cornerRadius: 40, style: .continuous)
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            guard !estaSalvando else { return }
            aoCancelar()
        }
    }
}

private struct CheckboxTermosStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        configuration.isOn ? Color.white : .secondary,
                        Color.accentColor
                    )
                    .accessibilityHidden(true)

                configuration.label
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Marcado" : "Desmarcado")
    }
}

#Preview("Termos e privacidade") {
    @Previewable @State var aceitouTermos = false
    @Previewable @State var aceitouPoliticaPrivacidade = false
    NavigationStack {
        PopUpTermosDeUsoView(
            aceitouTermos: $aceitouTermos,
            aceitouPoliticaPrivacidade: $aceitouPoliticaPrivacidade,
            estaSalvando: false,
            podeConcluir: true,
            aoCancelar: {},
            aoConfirmar: {}
        )
    }
    .preferredColorScheme(.dark)
}
