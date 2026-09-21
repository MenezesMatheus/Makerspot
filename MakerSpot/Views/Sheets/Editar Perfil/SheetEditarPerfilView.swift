//
//  SheetEditarPerfilView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct SheetEditarPerfilView: View {
    @State private var viewModel: EditarPerfilViewModel
    @State private var itemFotoSelecionado: PhotosPickerItem?
    @State private var confirmarAlteracoes = false
    @State private var confirmarSaida = false
    @State private var confirmarExclusao = false
    @State private var detentSelecionado: PresentationDetent = .large
    @FocusState private var campoFocado: Campo?

    private let aoAtualizar: (Usuario) -> Void
    private let aoEncerrarSessao: () -> Void
    private let aoExcluirConta: () -> Void
    private let carregarAoAparecer: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: EditarPerfilViewModel,
        carregarAoAparecer: Bool = true,
        aoAtualizar: @escaping (Usuario) -> Void = { _ in },
        aoEncerrarSessao: @escaping () -> Void = { },
        aoExcluirConta: @escaping () -> Void = { }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.aoAtualizar = aoAtualizar
        self.aoEncerrarSessao = aoEncerrarSessao
        self.aoExcluirConta = aoExcluirConta
        self.carregarAoAparecer = carregarAoAparecer
    }

    init(
        usuario: Usuario,
        sessao: SessaoUsuario,
        carregarAoAparecer: Bool = true,
        aoAtualizar: @escaping (Usuario) -> Void = { _ in },
        aoEncerrarSessao: @escaping () -> Void = { },
        aoExcluirConta: @escaping () -> Void = { }
    ) {
        self.init(
            viewModel: EditarPerfilViewModel(usuario: usuario, sessao: sessao),
            carregarAoAparecer: carregarAoAparecer,
            aoAtualizar: aoAtualizar,
            aoEncerrarSessao: aoEncerrarSessao,
            aoExcluirConta: aoExcluirConta
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            NavigationStack {
                GeometryReader { geometria in
                    ScrollView {
                        VStack(spacing: 0) {
                            fotoPerfilEditavel
                            .padding(.top, 18)
                            .padding(.bottom, 24)

                            camposDeNome(
                                nome: $viewModel.nome,
                                sobrenome: $viewModel.sobrenome
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Número de telefone")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 18)

                                TextField(
                                    "Adicionar número de telefone",
                                    text: $viewModel.telefonePadrao
                                )
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                                .focused($campoFocado, equals: .telefone)
                                .padding(.horizontal, 20)
                                .frame(minHeight: 58)
                                .background(
                                    Color(.tertiarySystemBackground),
                                    in: RoundedRectangle(
                                        cornerRadius: 22,
                                        style: .continuous
                                    )
                                )
                            }
                            .padding(.top, 30)

                            Spacer(minLength: 80)

                            VStack(spacing: 18) {
                                Button(role: .destructive) {
                                    campoFocado = nil
                                    confirmarSaida = true
                                } label: {
                                    Text("Encerrar Sessão")
                                        .font(.body.weight(.medium))
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .controlSize(.large)
                                .tint(.red)

                                Button("Excluir Conta", role: .destructive) {
                                    campoFocado = nil
                                    confirmarExclusao = true
                                }
                                .font(.body)
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                            .padding(.bottom, 34)
                        }
                        .frame(maxWidth: 520)
                        .frame(minHeight: geometria.size.height)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .background(corDeFundoDoSheet)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    TopBar(
                        type: .closeConfirm,
                        action1: solicitarSalvamento,
                        backAction: cancelar,
                        isActionDisabled: !viewModel.podeSalvar || !viewModel.temAlteracoes
                    )
                }
            }
            .disabled(
                confirmarAlteracoes
                    || confirmarSaida
                    || confirmarExclusao
            )

            PopUpAcaoView(
                estaApresentado: $confirmarAlteracoes,
                titulo: "Deseja salvar as alterações?",
                subtitulo: viewModel.descricaoAlteracoesParaConfirmacao,
                tituloAcao: "Confirmar",
                aoConfirmar: salvar
            )

            PopUpAcaoView(
                estaApresentado: $confirmarSaida,
                titulo: "Deseja encerrar sua sessão?",
                subtitulo: "Você precisará entrar novamente com sua conta Apple.",
                tituloAcao: "Encerrar Sessão",
                acaoDestrutiva: true,
                aoConfirmar: encerrarSessao
            )

            PopUpAcaoView(
                estaApresentado: $confirmarExclusao,
                titulo: "Deseja excluir sua conta?",
                subtitulo: "Seu perfil, seus Spots e seus dados serão removidos definitivamente.",
                tituloAcao: "Excluir Conta",
                acaoDestrutiva: true,
                aoConfirmar: excluirConta
            )

            if viewModel.estaSalvando || viewModel.estaExcluindoConta {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView(
                    viewModel.estaExcluindoConta
                        ? "Excluindo conta…"
                        : "Salvando perfil…"
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .task {
            if carregarAoAparecer {
                await viewModel.carregarFoto()
            }
        }
        .presentationDetents(
            [.medium, .large],
            selection: $detentSelecionado
        )
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .presentationCornerRadius(36)
        .presentationBackground(corDeFundoDoSheet)
        .interactiveDismissDisabled(
            viewModel.estaSalvando
                || viewModel.estaExcluindoConta
                || confirmarAlteracoes
                || confirmarSaida
                || confirmarExclusao
        )
        .alert(
            "Não foi possível atualizar o perfil",
            isPresented: erroApresentado,
            presenting: viewModel.mensagemDeErro
        ) { _ in
            Button("OK", role: .cancel, action: viewModel.limparErro)
        } message: { mensagem in
            Text(mensagem)
        }
    }

    private var corDeFundoDoSheet: Color {
        Color(
            uiColor: UIColor { caracteristicas in
                if caracteristicas.userInterfaceStyle == .dark {
                    return UIColor(
                        red: 0.08,
                        green: 0.08,
                        blue: 0.085,
                        alpha: 1
                    )
                }
                return .secondarySystemBackground
            }
        )
    }

    private var fotoPerfilEditavel: some View {
        let estaCarregando = viewModel.estaCarregando

        return PhotosPicker(selection: $itemFotoSelecionado, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                conteudoFotoPerfil
                    .frame(width: 146, height: 146)
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

    private func camposDeNome(
        nome: Binding<String>,
        sobrenome: Binding<String>
    ) -> some View {
        HStack(spacing: 5) {
            TextField("Nome", text: nome)
                .textContentType(.givenName)
                .multilineTextAlignment(.trailing)
                .focused($campoFocado, equals: .nome)
                .submitLabel(.next)
                .onSubmit { campoFocado = .sobrenome }

            TextField("Sobrenome", text: sobrenome)
                .textContentType(.familyName)
                .multilineTextAlignment(.leading)
                .focused($campoFocado, equals: .sobrenome)
                .submitLabel(.next)
                .onSubmit { campoFocado = .telefone }
        }
        .font(.title3.weight(.semibold))
        .textInputAutocapitalization(.words)
    }

    private var erroApresentado: Binding<Bool> {
        Binding(
            get: { viewModel.mensagemDeErro != nil },
            set: { novoValor in
                if !novoValor { viewModel.limparErro() }
            }
        )
    }

    private func cancelar() {
        viewModel.descartarAlteracoes()
        dismiss()
    }

    private func solicitarSalvamento() {
        campoFocado = nil
        guard viewModel.descricaoAlteracoesParaConfirmacao != nil else { return }
        confirmarAlteracoes = true
    }

    private func salvar() {
        Task {
            if let usuario = await viewModel.salvar() {
                aoAtualizar(usuario)
                dismiss()
            }
        }
    }

    private func encerrarSessao() {
        if viewModel.sair() {
            dismiss()
            aoEncerrarSessao()
        }
    }

    private func excluirConta() {
        Task {
            if await viewModel.excluirConta() {
                dismiss()
                aoExcluirConta()
            }
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
    @Previewable @State var estaApresentado = true
    let sessao = SessaoUsuario()
    let agora = Date()
    let usuario = Usuario(
        id: UUID(),
        appleUserID: "preview",
        cloudKitUserRecordName: "preview",
        nome: "Adalino",
        sobrenome: "da Silva",
        fotoID: nil,
        telefonePadrao: "+55 81 99002-8922",
        criadoEm: agora,
        atualizadoEm: agora
    )
    let viewModel = EditarPerfilViewModel(
        usuario: usuario,
        crud: UsuarioCRUD(sessao: sessao),
        fotoCRUD: FotoCRUD(sessao: sessao)
    )

    Color(.systemBackground)
        .ignoresSafeArea()
        .sheet(isPresented: $estaApresentado) {
            SheetEditarPerfilView(
                viewModel: viewModel,
                carregarAoAparecer: false
            )
        }
        .preferredColorScheme(.dark)
}
