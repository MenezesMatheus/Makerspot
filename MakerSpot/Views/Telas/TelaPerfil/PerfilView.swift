//
//  PerfilView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
import PhotosUI

struct PerfilView: View {
    @Bindable private var viewModel: PerfilViewModel
    @State private var itemSelecionado: PhotosPickerItem?
    @State private var mostrandoEdicaoPerfil = false
    @State private var confirmarSaida = false
    @State private var confirmarExclusao = false

    init(viewModel: PerfilViewModel) {
        self.viewModel = viewModel
    }

    init(sessao: SessaoUsuario) {
        self.init(viewModel: PerfilViewModel(sessao: sessao))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [.accent.opacity(0.4),
                             .black,
                             .black.opacity(0.6),
                             .black.opacity(0.6),
                             .black.opacity(0.7),
                             .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack {
                        // Foto + nome
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $itemSelecionado, matching: .images) {
                                fotoView
                            }
                            .disabled(viewModel.estaAlterandoFoto)
                            .onChange(of: itemSelecionado) { _, novoItem in
                                Task {
                                    guard let novoItem else { return }
                                    if let data = try? await novoItem.loadTransferable(type: Data.self) {
                                        let url = FileManager.default.temporaryDirectory
                                            .appendingPathComponent(UUID().uuidString + ".jpg")
                                        try? data.write(to: url)
                                        defer { try? FileManager.default.removeItem(at: url) }
                                        await viewModel.definirFotoPerfil(arquivoURL: url)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.usuario?.nome ?? "")
                                    .font(.system(size: 28, weight: .bold))
                                Text(viewModel.usuario?.sobrenome ?? "")
                                    .font(.system(size: 28, weight: .bold))
                            }
                            .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 16)

        
                        secaoDoUsuario(
                            titulo: "Meus eventos",
                            spots: viewModel.eventos,
                            destino: MeusEventosView()
                        )

                        secaoDoUsuario(
                            titulo: "Meus espaços",
                            spots: viewModel.espacos,
                            destino: MeusEspacosView()
                        )
                    }
                    .padding(.bottom, 32)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)

                if viewModel.estaCarregando, viewModel.usuario == nil {
                    ProgressView("Carregando perfil…")
                }
            }
            .navigationTitle("Perfil")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menuAcoesPerfil
                }
            }
            .disabled(confirmarSaida || confirmarExclusao || viewModel.estaExcluindoConta)
            .overlay {
                PopUpAcaoView(
                    estaApresentado: $confirmarSaida,
                    titulo: "Deseja encerrar sua sessão?",
                    subtitulo: "Você precisará entrar novamente com sua conta Apple.",
                    tituloAcao: "Encerrar Sessão",
                    acaoDestrutiva: true,
                    aoConfirmar: { viewModel.sair() }
                )

                PopUpAcaoView(
                    estaApresentado: $confirmarExclusao,
                    titulo: "Deseja excluir sua conta?",
                    subtitulo: "Seu perfil, seus Spots e seus dados serão removidos definitivamente.",
                    tituloAcao: "Excluir Conta",
                    acaoDestrutiva: true,
                    aoConfirmar: {
                        Task { await viewModel.excluirConta() }
                    }
                )

                if viewModel.estaExcluindoConta {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Excluindo conta…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .sheet(isPresented: $mostrandoEdicaoPerfil) {
                if let editor = viewModel.criarEditorPerfil() {
                    SheetEditarPerfilView(
                        viewModel: editor,
                        aoAtualizar: { usuario in
                            viewModel.aplicarAtualizacao(usuario)
                            Task { await viewModel.carregar() }
                        },
                        aoEncerrarSessao: viewModel.limparPerfil,
                        aoExcluirConta: viewModel.limparPerfil
                    )
                }
            }
            .task {
                await viewModel.carregar()
            }
            .refreshable {
                await viewModel.carregar()
            }
            .alert(
                "Erro",
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

    private var menuAcoesPerfil: some View {
        Menu {
            PickerView(acoes: [
                PickerAcao(
                    titulo: "Editar perfil",
                    nomeDoSimbolo: "pencil",
                    acao: { mostrandoEdicaoPerfil = true }
                ),
                PickerAcao(
                    titulo: "Finalizar sessão",
                    nomeDoSimbolo: "rectangle.portrait.and.arrow.right",
                    acao: { confirmarSaida = true }
                ),
                PickerAcao(
                    titulo: "Apagar conta",
                    nomeDoSimbolo: "trash",
                    papel: .destructive,
                    acao: { confirmarExclusao = true }
                )
            ])
            .disabled(viewModel.usuario == nil)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.primary)
        }
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .accessibilityLabel("Ações do perfil")
    }

    private func secaoDoUsuario<Destino: View>(
        titulo: String,
        spots: [Spot],
        destino: Destino
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(destination: destino) {
                HStack {
                    Text(titulo)
                        .font(.title.bold())

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(spots) { spot in
                CardSimplesView(
                    dados: CardSimplesDados(
                        spot: spot,
                        imagem: imagem(do: spot)
                    ),
                    modo: .proprietario(
                        estaAtivo: spot.estaAtivo,
                        estaProcessando: viewModel.spotEmAlteracao == spot.id,
                        aoAlternar: { estaAtivo in
                            Task {
                                await viewModel.definirAtivo(
                                    estaAtivo,
                                    para: spot
                                )
                            }
                        }
                    ),
                    aoSelecionar: {}
                )
                .task {
                    await viewModel.fotosSpots.carregarFotoPrincipal(do: spot)
                }
            }
        }
    }

    private func imagem(do spot: Spot) -> ImagemCardSimples {
        guard let foto = viewModel.fotosSpots.fotoPrincipal(do: spot) else {
            return .placeholder
        }
        return .arquivo(foto.arquivoURL)
    }

    @ViewBuilder
    private var fotoView: some View {
        Group {
            if viewModel.estaAlterandoFoto {
                ProgressView()
                    .tint(.white)
            } else if let foto = viewModel.fotoPerfil {
                AsyncImage(url: foto.arquivoURL) { fase in
                    switch fase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }
}

#Preview {
    PerfilView(sessao: SessaoUsuario())
        .preferredColorScheme(.dark)
}
