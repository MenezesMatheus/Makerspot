//
//  PickerView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct PickerAcao: Identifiable {
    let id = UUID()
    let titulo: String
    let subtitulo: String?
    let nomeDoSimbolo: String?
    let papel: ButtonRole?
    let acao: () -> Void

    init(
        titulo: String,
        subtitulo: String? = nil,
        nomeDoSimbolo: String? = nil,
        papel: ButtonRole? = nil,
        acao: @escaping () -> Void
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.nomeDoSimbolo = nomeDoSimbolo
        self.papel = papel
        self.acao = acao
    }
}

/// Conteúdo reutilizável para menus de ações.
struct PickerView: View {
    private let acoes: [PickerAcao]

    init(acoes: [PickerAcao]) {
        self.acoes = acoes
    }

    var body: some View {
        ForEach(acoes) { item in
            Button(role: item.papel, action: item.acao) {
                if let nomeDoSimbolo = item.nomeDoSimbolo {
                    Label {
                        textos(para: item)
                    } icon: {
                        Image(systemName: nomeDoSimbolo)
                    }
                } else {
                    textos(para: item)
                }
            }
        }
    }

    @ViewBuilder
    private func textos(para item: PickerAcao) -> some View {
        if let subtitulo = item.subtitulo, !subtitulo.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.titulo)
                Text(subtitulo)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(item.titulo)
                .lineLimit(1)
        }
    }
}

private struct PickerAoPressionarModifier: ViewModifier {
    let acoes: [PickerAcao]
    let acaoPrincipal: () -> Void

    func body(content: Content) -> some View {
        Menu {
            PickerView(acoes: acoes)
        } label: {
            content
        } primaryAction: {
            acaoPrincipal()
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, .dark)
    }
}

extension View {
    func pickerAoPressionar(
        acoes: [PickerAcao],
        acaoPrincipal: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            PickerAoPressionarModifier(
                acoes: acoes,
                acaoPrincipal: acaoPrincipal
            )
        )
    }
}

#Preview("Ações do perfil") {
    VStack(alignment: .leading, spacing: 24) {
        HStack {
            Text("Perfil")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            Menu {
                PickerView(
                    acoes: [
                        PickerAcao(
                            titulo: "Editar perfil",
                            nomeDoSimbolo: "pencil",
                            acao: {}
                        ),
                        PickerAcao(
                            titulo: "Finalizar sessão",
                            nomeDoSimbolo: "rectangle.portrait.and.arrow.right",
                            acao: {}
                        ),
                        PickerAcao(
                            titulo: "Apagar conta",
                            nomeDoSimbolo: "trash",
                            papel: .destructive,
                            acao: {}
                        )
                    ]
                )
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Ações do perfil")
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Ações do Spot") {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 150)
            .pickerAoPressionar(
                acoes: [
                    PickerAcao(
                        titulo: "Editar",
                        nomeDoSimbolo: "pencil",
                        acao: {}
                    ),
                    PickerAcao(
                        titulo: "Apagar Spot",
                        nomeDoSimbolo: "trash",
                        papel: .destructive,
                        acao: {}
                    )
                ],
                acaoPrincipal: {}
            )
    }
    .padding()
    .preferredColorScheme(.dark)
}
