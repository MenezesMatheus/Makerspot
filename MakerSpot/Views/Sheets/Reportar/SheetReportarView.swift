import SwiftUI

struct SheetReportarView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var descricao = ""

    var body: some View {
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

            TextField("Descreva", text: $descricao)
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .padding(.horizontal, 30)
                .padding(.top, 28)

            // MARK: - Botão

            Button {
                enviarDenuncia()
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
    }

    private func enviarDenuncia() {
        print("Denúncia enviada: \(descricao)")
        dismiss()
    }
}

#Preview {
    SheetReportarView()
}

