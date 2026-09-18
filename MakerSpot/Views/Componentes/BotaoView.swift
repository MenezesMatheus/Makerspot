//
//  BotaoView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

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
