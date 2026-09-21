//
//  PerfilView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
import PhotosUI

struct PerfilView: View {
    @State private var viewModel: PerfilViewModel
    @State private var itemSelecionado: PhotosPickerItem?

    init(sessao: SessaoUsuario) {
        _viewModel = State(initialValue: PerfilViewModel(sessao: sessao))
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
                .toolbar {
                    TopBar(
                        type: .mainScreens,
                        symbol: "plus",
                        action1: { print("Adicionar") }
                    )
                }

                
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
                        .padding()

        
                        NavigationLink(destination: MeusEventosView()) {
                            HStack {
                                Text("Meus eventos")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)

    //aqui entra os cards de eventos

                        NavigationLink(destination: MeusEspacosView()) {
                            HStack {
                                Text("Meus espaços")
                                    .font(.system(size: 34, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
    //aqui entra os cards de espaços
                    }
                }
            }
        }
        //MATHEUS VER ISSO AQUI 
        //        .navigationTitle("Perfil")
        .task {
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
}
