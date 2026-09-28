import SwiftUI

struct SheetReportarView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReportarSpotViewModel
    @FocusState private var motivoFocado: Bool

    init(viewModel: ReportarSpotViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {

            // MARK: - Cabeçalho

            ZStack {
                Text(viewModel.denunciaEnviada == nil ? "Denunciar" : "Denúncia")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.estaEnviando)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 16)

            if viewModel.denunciaEnviada != nil {
                confirmacao
            } else {
                formulario
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .interactiveDismissDisabled(viewModel.estaEnviando)
        .alert(
            "Não foi possível enviar a denúncia",
            isPresented: Binding(
                get: { viewModel.mensagemDeErro != nil },
                set: { _ in viewModel.limparErro() }
            )
        ) {
            Button("OK") { viewModel.limparErro() }
        } message: {
            Text(viewModel.mensagemDeErro ?? "")
        }
    }

    private var formulario: some View {
        @Bindable var viewModel = viewModel

        return VStack(spacing: 24) {
            Text("Por que você deseja denunciar este conteúdo?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Descreva", text: $viewModel.texto)
                .focused($motivoFocado)
                .padding(.horizontal, 20)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .disabled(viewModel.estaEnviando)

            Button {
                motivoFocado = false
                Task { await viewModel.enviar() }
            } label: {
                Group {
                    if viewModel.estaEnviando {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Enviar")
                    }
                }
                .font(.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.podeEnviar)
            .opacity(viewModel.podeEnviar || viewModel.estaEnviando ? 1 : 0.5)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private var confirmacao: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Denúncia realizada")
                .font(.title3.weight(.semibold))

            Text("Sua denúncia foi registrada com sucesso.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Concluir") { dismiss() }
                .font(.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SheetReportarView(
        viewModel: ReportarSpotViewModel(
            spotID: UUID(),
            sessao: SessaoUsuario()
        )
    )
}
