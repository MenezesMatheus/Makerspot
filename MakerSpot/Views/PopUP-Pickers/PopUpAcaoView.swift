//
//  PopUpAcaoView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct PopUpAcaoView: View {
    @Binding private var estaApresentado: Bool

    private let titulo: String
    private let subtitulo: String?
    private let alteracoes: [String]?
    private let tituloCancelar: String
    private let tituloAcao: String
    private let acaoDestrutiva: Bool
    private let aoCancelar: (() -> Void)?
    private let aoConfirmar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(
        estaApresentado: Binding<Bool>,
        titulo: String,
        subtitulo: String? = nil,
        alteracoes: [String]? = nil,
        tituloCancelar: String = "Cancelar",
        tituloAcao: String,
        acaoDestrutiva: Bool = false,
        aoCancelar: (() -> Void)? = nil,
        aoConfirmar: @escaping () -> Void
    ) {
        _estaApresentado = estaApresentado
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.alteracoes = alteracoes
        self.tituloCancelar = tituloCancelar
        self.tituloAcao = tituloAcao
        self.acaoDestrutiva = acaoDestrutiva
        self.aoCancelar = aoCancelar
        self.aoConfirmar = aoConfirmar
    }

    var body: some View {
        if estaApresentado {
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cancelar)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: possuiDetalhes ? 28 : 40) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(titulo)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        if let subtitulo, !subtitulo.isEmpty {
                            Text(subtitulo)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.72))
                        }

                        if let alteracoes, !alteracoes.isEmpty {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(alteracoes.indices, id: \.self) { indice in
                                        Text(alteracoes[indice])
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                            .scrollIndicators(.visible)
                            .accessibilityLabel("Alterações realizadas")
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            if acaoDestrutiva {
                                botaoCancelar
                                botaoDeAcao
                            } else {
                                botaoDeAcao
                                botaoCancelar
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .frame(maxWidth: 360)
                .background(
                    Color(.secondarySystemBackground).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 40, style: .continuous)
                )
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
                .padding(.horizontal, 28)
            }
            .environment(\.colorScheme, .dark)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, cancelar)
        }
    }

    private var possuiDetalhes: Bool {
        !(subtitulo?.isEmpty ?? true) || !(alteracoes?.isEmpty ?? true)
    }

    private var botaoCancelar: some View {
        Button(role: .cancel, action: cancelar) {
            Text(tituloCancelar)
                .font(.title3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    @ViewBuilder
    private var botaoDeAcao: some View {
        if acaoDestrutiva {
            Button(role: .destructive, action: confirmar) {
                Text(tituloAcao)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

        } else {
            Button(action: confirmar) {
                Text(tituloAcao)
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    private func cancelar() {
        fechar()
        aoCancelar?()
    }

    private func confirmar() {
        fechar()
        aoConfirmar()
    }

    private func fechar() {
        if reduzirMovimento {
            estaApresentado = false
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                estaApresentado = false
            }
        }
    }
}

#Preview("Alterações") {
    PopUpAcaoView(
        estaApresentado: .constant(true),
        titulo: "Deseja concluir suas alterações?",
        subtitulo: "Revise as mudanças antes de confirmar.",
        alteracoes: [
            "Nome: Oficina Criativa → Maker Lab",
            "Categoria: Artes → Tecnologia",
            "Horário: 18h → 19h30"
        ],
        tituloAcao: "Confirmar",
        aoConfirmar: { }
    )
    .preferredColorScheme(.dark)
}

#Preview("Confirmação") {
    PopUpAcaoView(
        estaApresentado: .constant(true),
        titulo: "Deseja cadastrar o spot: FabLab?",
        tituloAcao: "Confirmar",
        aoConfirmar: { }
    )
    .preferredColorScheme(.dark)
}

#Preview("Ação destrutiva") {
    PopUpAcaoView(
        estaApresentado: .constant(true),
        titulo: "Deseja sair da sua conta?",
        tituloAcao: "Sair",
        acaoDestrutiva: true,
        aoConfirmar: { }
    )
    .preferredColorScheme(.dark)
}
