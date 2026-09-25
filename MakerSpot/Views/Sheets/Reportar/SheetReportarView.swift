import SwiftUI

struct SheetReportarView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReportarSpotViewModel

    init(viewModel: ReportarSpotViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {

            // MARK: - Cabeçalho

            ZStack {
                Text("Denunciar")
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.white)
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

            // MARK: - Pergunta

            Text("Por que você deseja denunciar\neste conteúdo?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)

            // MARK: - Campo

            TextField("Descreva", text: $viewModel.texto)
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .padding(.horizontal, 30)
                .padding(.top, 28)
                .disabled(viewModel.estaEnviando)

            // MARK: - Botão

            Button {
                Task {
                    if await viewModel.enviar() {
                        dismiss()
                    }
                }
            } label: {
                Text("Enviar")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 62)
            .padding(.top, 85)

            Spacer()
        }
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
}

#Preview {
    SheetReportarView(
        viewModel: ReportarSpotViewModel(
            spotID: UUID(),
            sessao: SessaoUsuario()
        )
    )
}
