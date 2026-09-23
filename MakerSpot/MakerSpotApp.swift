//
//  MakerSpotApp.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

@main
struct MakerSpotApp: App {
    var body: some Scene {
        WindowGroup {
            FluxoPrincipalView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct FluxoPrincipalView: View {
    @State private var sessao = SessaoUsuario()
    @State private var etapa: Etapa = .restaurando
    

    var body: some View {
        Group {
            switch etapa {
            case .restaurando:
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    ProgressView("Carregando…")
                }

            case .login:
                LoginView(sessao: sessao) {
                    etapa = .criandoPerfil
                }

            case .criandoPerfil:
                CriarContaView(
                    sessao: sessao,
                    aoConcluir: { _ in etapa = .principal },
                    aoVoltar: voltarAoLogin
                )

            case .principal:
                TabBarView()
            }
        }
        .task {
            guard etapa == .restaurando else { return }
            let login = LoginViewModel(sessao: sessao)
            guard await login.restaurarSessao(),
                  let usuario = sessao.usuarioAtual else {
                etapa = .login
                return
            }

            etapa = usuario.atualizadoEm <= usuario.criadoEm
                ? .criandoPerfil
                : .principal
        }
        .onChange(of: sessao.estaAutenticado) { _, estaAutenticado in
            if !estaAutenticado, etapa == .principal {
                etapa = .login
            }
        }
        .environment(sessao)
    }

    private func voltarAoLogin() {
        try? sessao.encerrar()
        etapa = .login
    }

    private enum Etapa: Equatable {
        case restaurando
        case login
        case criandoPerfil
        case principal
    }
}
