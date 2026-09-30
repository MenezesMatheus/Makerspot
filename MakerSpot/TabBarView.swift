//
//  TabBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct TabBarView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostraExclusao = false
    @State private var mostraCadastro = false
    @State private var tituloCadastro = ""
    @State private var abaSelecionada: Aba = .spots
    @State private var versaoNavegacaoSpots = UUID()
    @State private var spotsViewModel: SpotsViewModel
    @State private var salvosViewModel: SalvosViewModel
    @State private var perfilViewModel: PerfilViewModel
    @State private var buscaViewModel: BuscaViewModel 
    private let sessao: SessaoUsuario

    init(sessao: SessaoUsuario) {
        self.sessao = sessao
        _spotsViewModel = State(initialValue: SpotsViewModel(sessao: sessao))
        _salvosViewModel = State(initialValue: SalvosViewModel(sessao: sessao))
        _perfilViewModel = State(initialValue: PerfilViewModel(sessao: sessao))
        _buscaViewModel = State(initialValue: BuscaViewModel(sessao: sessao))
    }

    var body: some View {
        
        
        TabView(selection: $abaSelecionada) {
            Tab("Spots", image: "SFspoticone", value: Aba.spots) {
                SpotsView(viewModel: spotsViewModel)
                    .id(versaoNavegacaoSpots)
            }

            Tab("Salvos", systemImage: "bookmark", value: Aba.salvos) {
                SalvosView(viewModel: salvosViewModel)
            }

            Tab("Perfil", systemImage: "person.fill", value: Aba.perfil) {
                PerfilView(viewModel: perfilViewModel)
            }

            Tab(value: Aba.busca, role: .search) {
                BuscaView(viewModel: buscaViewModel)
            }
        }
        .disabled(mostraExclusao || mostraCadastro || sessao.enviosFotosCadastro.mensagemDeErro != nil)
        .overlay {
            PopUpTextoView(
                estaApresentado: $mostraExclusao,
                titulo: "Spot excluído com sucesso!"
            )
            PopUpTextoView(
                estaApresentado: $mostraCadastro,
                titulo: tituloCadastro,
                subtitulo: "As fotos aparecerão assim que o envio terminar.",
                fecharApos: .seconds(1.5)
            )
            PopUpTextoView(
                estaApresentado: Binding(
                    get: {
                        !mostraCadastro && sessao.enviosFotosCadastro.mensagemDeErro != nil
                    },
                    set: {
                        if !$0 { sessao.enviosFotosCadastro.limparErro() }
                    }
                ),
                titulo: "Fotos ainda não enviadas",
                subtitulo: sessao.enviosFotosCadastro.mensagemDeErro
            )
        }
        .onChange(of: sessao.alteracoesSpots.exclusaoConfirmada) { _, id in
            if id != nil { mostraExclusao = true }
        }
        .onChange(of: abaSelecionada) { _, aba in
            Task { await atualizarAba(aba) }
        }
        .onChange(of: scenePhase) { _, fase in
            guard fase == .active else { return }
            Task { await atualizarAba(abaSelecionada) }
        }
        .onChange(of: sessao.alteracoesSpots.cadastroConfirmado) { _, spot in
            guard let spot else { return }
            spotsViewModel.encerrarCadastro()
            abaSelecionada = .spots
            versaoNavegacaoSpots = UUID()
            tituloCadastro = spot.tipo == .evento
                ? "Evento cadastrado com sucesso!"
                : "Espaço cadastrado com sucesso!"

            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled,
                      sessao.alteracoesSpots.cadastroConfirmado?.id == spot.id else { return }
                mostraCadastro = true
            }
        }
    }

    @MainActor
    private func atualizarAba(_ aba: Aba) async {
        switch aba {
        case .spots:
            await spotsViewModel.recarregar()
        case .salvos:
            await salvosViewModel.carregar()
        case .perfil:
            await perfilViewModel.carregar()
        case .busca:
            await buscaViewModel.recarregar()
        }
    }

    private enum Aba: Hashable {
        case spots, salvos, perfil, busca
    }
}

#Preview {
    let sessao = SessaoUsuario()
    TabBarView(sessao: sessao)
        .environment(sessao)
        .preferredColorScheme(.dark)
}
