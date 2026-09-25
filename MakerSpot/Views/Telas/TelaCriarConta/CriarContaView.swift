//
//  CriarContaView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct CriarContaView: View {
    @State private var viewModel: CriarContaViewModel
    @State private var itemFotoSelecionado: PhotosPickerItem?
    @FocusState private var campoFocado: Campo?

    private let aoConcluir: (Usuario) -> Void
    private let aoVoltar: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: CriarContaViewModel,
        aoConcluir: @escaping (Usuario) -> Void = { _ in },
        aoVoltar: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.aoConcluir = aoConcluir
        self.aoVoltar = aoVoltar
    }

    init(
        sessao: SessaoUsuario,
        aoConcluir: @escaping (Usuario) -> Void = { _ in },
        aoVoltar: (() -> Void)? = nil
    ) {
        self.init(
            viewModel: CriarContaViewModel(sessao: sessao),
            aoConcluir: aoConcluir,
            aoVoltar: aoVoltar
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        fotoPerfilEditavel
                        .padding(.top, 18)
                        .padding(.bottom, 46)

                        VStack(spacing: 0) {
                            campoTexto(
                                "Nome",
                                texto: $viewModel.nome,
                                campo: .nome,
                                tipoConteudo: .givenName,
                                submitLabel: .next
                            )

                            Divider()

                            campoTexto(
                                "Sobrenome",
                                texto: $viewModel.sobrenome,
                                campo: .sobrenome,
                                tipoConteudo: .familyName,
                                submitLabel: .next
                            )
                        }
                        .padding(.horizontal, 18)
                        .background(
                            Color(.tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )

                        TextField("Adicionar telefone", text: $viewModel.telefonePadrao)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .focused($campoFocado, equals: .telefone)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 54)
                            .background(
                                Color(.tertiarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)

                if viewModel.estaSalvando {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                    ProgressView("Criando perfil…")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: voltar) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Voltar")
                }

                ToolbarItem(placement: .principal) {
                    Text("Criar Conta")
                        .font(.headline)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: concluir) {
                    Text("Criar conta")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(!viewModel.podeConcluir)
                .frame(maxWidth: 520)
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
            }
        }
        .task {
            await viewModel.carregar()
        }
        .alert(
            "Não foi possível criar o perfil",
            isPresented: erroApresentado,
            presenting: viewModel.mensagemDeErro
        ) { _ in
            Button("OK", role: .cancel, action: viewModel.limparErro)
        } message: { mensagem in
            Text(mensagem)
        }
    }

    private func campoTexto(
        _ titulo: String,
        texto: Binding<String>,
        campo: Campo,
        tipoConteudo: UITextContentType,
        submitLabel: SubmitLabel
    ) -> some View {
        TextField(titulo, text: texto)
            .textContentType(tipoConteudo)
            .textInputAutocapitalization(.words)
            .submitLabel(submitLabel)
            .focused($campoFocado, equals: campo)
            .frame(minHeight: 48)
            .onSubmit {
                switch campo {
                case .nome:
                    campoFocado = .sobrenome
                case .sobrenome:
                    campoFocado = .telefone
                case .telefone:
                    campoFocado = nil
                }
            }
    }

    private var fotoPerfilEditavel: some View {
        let estaCarregando = viewModel.estaCarregando

        return PhotosPicker(selection: $itemFotoSelecionado, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                conteudoFotoPerfil
                    .frame(width: 138, height: 138)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }

                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .offset(x: 3, y: 3)
            }
            .overlay {
                if estaCarregando {
                    Circle()
                        .fill(.black.opacity(0.5))
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alterar foto do perfil")
        .onChange(of: itemFotoSelecionado) { _, novoItem in
            carregarFotoSelecionada(novoItem)
        }
    }

    @ViewBuilder
    private var conteudoFotoPerfil: some View {
        if let novaFotoDados = viewModel.novaFotoDados,
           let imagem = UIImage(data: novaFotoDados) {
            Image(uiImage: imagem)
                .resizable()
                .scaledToFill()
        } else if let fotoURL = viewModel.fotoPerfil?.arquivoURL,
                  let imagem = UIImage(contentsOfFile: fotoURL.path) {
            Image(uiImage: imagem)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color.white,
                    LinearGradient(
                        colors: [
                            Color(.systemGray2),
                            Color(.systemGray4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private func carregarFotoSelecionada(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            do {
                guard let dados = try await item.loadTransferable(type: Data.self),
                      !dados.isEmpty else {
                    throw ErroFotoPerfil.dadosIndisponiveis
                }
                viewModel.selecionarFoto(dados)
            } catch is CancellationError {
            } catch {
                viewModel.registrarErroDaFoto(error)
            }
            itemFotoSelecionado = nil
        }
    }

    private var erroApresentado: Binding<Bool> {
        Binding(
            get: { viewModel.mensagemDeErro != nil },
            set: { novoValor in
                if !novoValor { viewModel.limparErro() }
            }
        )
    }

    private func concluir() {
        campoFocado = nil
        Task {
            if let usuario = await viewModel.concluirCadastro() {
                aoConcluir(usuario)
            }
        }
    }

    private func voltar() {
        if let aoVoltar {
            aoVoltar()
        } else {
            dismiss()
        }
    }

    private enum Campo: Hashable {
        case nome
        case sobrenome
        case telefone
    }

    private enum ErroFotoPerfil: LocalizedError {
        case dadosIndisponiveis

        var errorDescription: String? {
            "Não foi possível ler a foto selecionada."
        }
    }
}

#Preview {
    CriarContaView(sessao: SessaoUsuario())
        .preferredColorScheme(.dark)
}
