//
//  MakerSpotApp.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

@main
struct MakerSpotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateNotificacoes.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            FluxoPrincipalView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct FluxoPrincipalView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessao = SessaoUsuario()
    @State private var etapa: Etapa
    @State private var roteador = RoteadorNotificacoes.compartilhado
    @AppStorage("shouldShowOnBoarding")
    private var shouldShowOnBoarding = true
    private let coordenadorNotificacoes = CoordenadorNotificacoes()

    init() {
        let deveMostrarOnboarding =
            UserDefaults.standard.object(forKey: "shouldShowOnBoarding") == nil ||
            UserDefaults.standard.bool(forKey: "shouldShowOnBoarding")

        _etapa = State(
            initialValue: deveMostrarOnboarding
                ? .onboarding
                : .restaurando
        )
    }

    var body: some View {
        @Bindable var roteador = roteador

        Group {
            switch etapa {
            case .onboarding:
                ONboardingview {
                    shouldShowOnBoarding = false
                    etapa = .restaurando
                }

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
                TabBarView(sessao: sessao)
            }
        }
        .task(id: etapa) {
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
        .task(id: etapa) {
            guard etapa == .principal else { return }
            await coordenadorNotificacoes.configurar(sessao: sessao)
        }
        .onChange(of: sessao.estaAutenticado) { _, estaAutenticado in
            if !estaAutenticado, etapa == .principal {
                etapa = .login
            }
        }
        .onChange(of: scenePhase) { _, novaFase in
            guard novaFase == .active, etapa == .principal else { return }
            Task {
                await coordenadorNotificacoes.configurar(sessao: sessao)
            }
        }
        .alert(item: $roteador.alertaModeracao) { alerta in
            Alert(
                title: Text(alerta.titulo),
                message: Text(alerta.mensagem),
                primaryButton: .default(Text("Solicitar revisão")) {
                    roteador.abrirEmailDeRevisao()
                },
                secondaryButton: .cancel(Text("Fechar"))
            )
        }
        .environment(sessao)
    }

    private func voltarAoLogin() {
        try? sessao.encerrar()
        etapa = .login
    }

    private enum Etapa: Equatable {
        case onboarding
        case restaurando
        case login
        case criandoPerfil
        case principal
    }
}
