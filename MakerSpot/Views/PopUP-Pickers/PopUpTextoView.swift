//
//  PopUpTextoView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct PopUpTextoView: View {
    @Binding private var estaApresentado: Bool

    private let titulo: String
    private let subtitulo: String?

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    init(
        estaApresentado: Binding<Bool>,
        titulo: String,
        subtitulo: String? = nil
    ) {
        _estaApresentado = estaApresentado
        self.titulo = titulo
        self.subtitulo = subtitulo
    }

    var body: some View {
        if estaApresentado {
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: fechar)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(titulo)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    if let subtitulo, !subtitulo.isEmpty {
                        Text(subtitulo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: 360)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture { }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
            }
            .environment(\.colorScheme, .dark)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, fechar)
        }
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

#Preview {
    PopUpTextoView(
        estaApresentado: .constant(true),
        titulo: "Seu perfil foi alterado com sucesso!"
    )
    .preferredColorScheme(.dark)
}
