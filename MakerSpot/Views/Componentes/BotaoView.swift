//
//  BotaoView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

struct BotaoIconeToolbar: View {
    let titulo: String
    let simbolo: String
    var estaProcessando = false
    var cor: Color = .accentColor
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Group {
                if estaProcessando {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: simbolo)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
            .background(cor, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
    }
}

struct BotaoAdicionarToolbar: View {
    let titulo: String
    var cor: Color = .accentColor
    let acao: () -> Void

    var body: some View {
        BotaoIconeToolbar(titulo: titulo, simbolo: "plus", cor: cor, acao: acao)
    }
}

struct BotaoView: View {
    let nome: String
    private let acao: () -> Void
    
    init(nome: String, acao: @escaping () -> Void) {
        self.nome = nome
        self.acao = acao
    }
    
    var body: some View {
        Button(nome) {
            acao()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .buttonBorderShape(.automatic)
        .tint(.accentColor)
    }
}

struct Botaodestrutivo: View {
    let nome: String
    private let acao: () -> Void
    
    init(nome: String, acao: @escaping () -> Void) {
        self.nome = nome
        self.acao = acao
    }
    
    var body: some View {
        Button(nome, role: .destructive) {
            acao()
        }
            .buttonStyle(.glass)
            .controlSize(.large)
            .buttonBorderShape(.automatic)
            .foregroundStyle(Color.red)
            .tint(Color.secondary)
    }
}

#Preview {
    BotaoView(nome:"Enviar", acao: {})
    Botaodestrutivo(nome:"Confirmar", acao: {})
}
