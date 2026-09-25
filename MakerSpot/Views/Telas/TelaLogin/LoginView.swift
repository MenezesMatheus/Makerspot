//
//  LoginView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel

    private let aoEntrar: () -> Void

    init(
        viewModel: LoginViewModel,
        aoEntrar: @escaping () -> Void = { }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.aoEntrar = aoEntrar
    }

    init(
        sessao: SessaoUsuario,
        aoEntrar: @escaping () -> Void = { }
    ) {
        self.init(
            viewModel: LoginViewModel(sessao: sessao),
            aoEntrar: aoEntrar
        )
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 80)

                ilustracao

                Spacer()

                SignInWithAppleButton(
                    .signIn,
                    onRequest: viewModel.configurar,
                    onCompletion: receberResultado
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(viewModel.estaCarregando)
                .accessibilityHint("Usa seu nome da conta Apple para iniciar a criação do perfil")
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 32)
            .padding(.bottom, 28)

            if viewModel.estaCarregando {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                ProgressView("Entrando…")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .alert(
            "Não foi possível entrar",
            isPresented: erroApresentado,
            presenting: viewModel.mensagemDeErro
        ) { _ in
            Button("OK", role: .cancel, action: viewModel.limparErro)
        } message: { mensagem in
            Text(mensagem)
        }
    }

    private var ilustracao: some View {
        Image("SVG-Login")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 307)
            .frame(height: 227)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("MakerSpot")
    }

    private var erroApresentado: Binding<Bool> {
        Binding(
            get: { viewModel.mensagemDeErro != nil },
            set: { novoValor in
                if !novoValor { viewModel.limparErro() }
            }
        )
    }

    private func receberResultado(_ resultado: Result<ASAuthorization, Error>) {
        switch resultado {
        case .success(let autorizacao):
            Task {
                if await viewModel.entrar(com: autorizacao) {
                    aoEntrar()
                }
            }
        case .failure(let erro):
            viewModel.registrarFalhaDaApple(erro)
        }
    }
}

#Preview {
    LoginView(sessao: SessaoUsuario())
        .preferredColorScheme(.dark)
}
