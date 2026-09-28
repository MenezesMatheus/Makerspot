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
    @State private var avisosRestricao: [SpotRestrito] = []
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
                    continuarAposAutenticacao()
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
            guard await login.restaurarSessao() else {
                etapa = .login
                return
            }

            continuarAposAutenticacao()
        }
        .task(id: etapa) {
            guard etapa == .principal else { return }
            await verificarRestricoes()
        }
        .task(id: etapa) {
            guard etapa == .principal else { return }
            await coordenadorNotificacoes.configurar(sessao: sessao)
        }
        .onChange(of: sessao.estaAutenticado) { _, estaAutenticado in
            if !estaAutenticado, etapa == .principal || etapa == .criandoPerfil {
                avisosRestricao = []
                etapa = .login
            }
        }
        .onChange(of: scenePhase) { _, novaFase in
            guard novaFase == .active,
                  etapa == .principal || etapa == .criandoPerfil else { return }
            Task {
                try? await UsuarioCRUD(sessao: sessao).verificarBanimentoDaSessaoAtual()
                if etapa == .principal, sessao.estaAutenticado {
                    await verificarRestricoes()
                }
            }
            if etapa == .principal {
                Task { await coordenadorNotificacoes.configurar(sessao: sessao) }
            }
        }
        .onChange(of: roteador.atualizacaoRestricaoSpot) { _, _ in
            guard etapa == .principal else { return }
            Task { await verificarRestricoes() }
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
        .overlay {
            if etapa == .principal, let aviso = avisoRestricaoParaExibir {
                PopUpTextoView(
                    estaApresentado: Binding(
                        get: { avisoRestricaoParaExibir != nil },
                        set: { if !$0 { dispensarAvisoRestricao() } }
                    ),
                    titulo: "Spot restringido",
                    subtitulo: aviso.mensagemParaCriador
                )
            }
        }
        .environment(sessao)
    }

    private var avisoRestricaoParaExibir: SpotRestrito? {
        guard let usuarioID = sessao.usuarioAtual?.id else { return nil }
        return roteador.avisosRestricaoSpotPendentes.first {
            $0.proprietarioID == usuarioID
        } ?? avisosRestricao.first
    }

    private func verificarRestricoes() async {
        guard let usuarioID = sessao.usuarioAtual?.id else { return }
        do {
            let restricoes = try await SpotsRestritosCRUD()
                .listarAtivos(para: usuarioID)
            guard sessao.usuarioAtual?.id == usuarioID else { return }
            let vistos = Set(UserDefaults.standard.stringArray(
                forKey: chaveAvisosVistos(usuarioID)
            ) ?? [])
            avisosRestricao = restricoes.filter { !vistos.contains($0.id) }
        } catch is CancellationError {
            return
        } catch {
            // A próxima abertura ou ativação do app tentará novamente.
        }
    }

    private func dispensarAvisoRestricao() {
        guard let aviso = avisoRestricaoParaExibir,
              let usuarioID = sessao.usuarioAtual?.id else { return }
        let chave = chaveAvisosVistos(usuarioID)
        var vistos = Set(UserDefaults.standard.stringArray(forKey: chave) ?? [])
        vistos.insert(aviso.id)
        UserDefaults.standard.set(Array(vistos), forKey: chave)
        roteador.avisosRestricaoSpotPendentes.removeAll { $0.id == aviso.id }
        avisosRestricao.removeAll { $0.id == aviso.id }
    }

    private func chaveAvisosVistos(_ usuarioID: UUID) -> String {
        "makerspot.spotsRestritos.vistos.\(usuarioID.uuidString.lowercased())"
    }

    private func continuarAposAutenticacao() {
        guard let usuario = sessao.usuarioAtual else {
            etapa = .login
            return
        }

        etapa = usuario.precisaCompletarPerfil ? .criandoPerfil : .principal
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
