//
//  CardSimplesView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

// card geral - de terceiros - com botao de salvar

struct CardSpotView: View {
    let tipo: TipoSpot
    let titulo: String
    let nomeImagem: String
    let textoInfo: String
    let localCidade: String
    let estaSalvo: Bool
    let aoAlternarSalvo: () -> Void
    
    var body: some View {
        CardBaseSpot(
            tipo: tipo,
            titulo: titulo,
            nomeImagem: nomeImagem,
            textoInfo: textoInfo,
            localCidade: localCidade
        ) {
            Button(action: aoAlternarSalvo) {
                Image(systemName: estaSalvo ? "bookmark.fill" : "bookmark")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(white: 0.12))
            .clipShape(Circle())
        }
    }
}

struct CardMeuSpotView: View {
    let tipo: TipoSpot
    let titulo: String
    let nomeImagem: String
    let textoInfo: String
    let localCidade: String
    let estaAtivo: Bool
    let aoAlternarAtivo: (Bool) -> Void
 
    var body: some View {
        CardBaseSpot(
            tipo: tipo,
            titulo: titulo,
            nomeImagem: nomeImagem,
            textoInfo: textoInfo,
            localCidade: localCidade
        ) {
            Toggle(
                "",
                isOn: Binding(
                    get: { estaAtivo },
                    set: { novoValor in aoAlternarAtivo(novoValor) }
                )
            )
            .labelsHidden()
            .tint(tipo.corDestaque)
        }
    }
}
 
// estrutura comum dos cards

private struct CardBaseSpot<ConteudoFinal: View>: View {
    let tipo: TipoSpot
    let titulo: String
    let nomeImagem: String
    let textoInfo: String
    let localCidade: String
    @ViewBuilder let conteudoFinal: () -> ConteudoFinal
 
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nomeImagem)
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 16))
 
            VStack(alignment: .leading, spacing: 8) {
                Text(titulo)
                    .font(.title2.bold())
                    .foregroundColor(tipo.corDestaque)
 
                Text(tipo.rotulo)
                    .font(.subheadline)
                    .foregroundColor(.gray)
 
                InfoRow(icon: tipo.iconeInfo, text: textoInfo, cor: tipo.corDestaque)
                InfoRow(icon: "mappin.and.ellipse", text: localCidade, cor: tipo.corDestaque)
            }
 
            Spacer()
 
            conteudoFinal()
        }
        .padding()
        .frame(width: 361, height: 136)
        .background(Color(white: 0.12))
        .cornerRadius(24)
    }
}
 
private struct InfoRow: View {
    let icon: String
    let text: String
    let cor: Color
 
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(cor)
            Text(text)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}
 
// estilo dos cards por tipo de spot
 
private extension TipoSpot {
    var corDestaque: Color {
        switch self {
        case .evento: return .orange
        case .espaco: return .blue
        }
    }
 
    var rotulo: String {
        switch self {
        case .evento: return "Eventos"
        case .espaco: return "Espaço"
        }
    }
 
    var iconeInfo: String {
        switch self {
        case .evento: return "calendar"
        case .espaco: return "clock"
        }
    }
}


#Preview("Meus Spots - Espaço") {
   CardMeuSpotView(
       tipo: .espaco,
       titulo: "Fab lab",
       nomeImagem: "fablab",
       textoInfo: "Aberto 08h-18h",
       localCidade: "Recife, PE",
       estaAtivo: true,
       aoAlternarAtivo: { _ in }
   )
   .padding()
   .background(Color.black)


CardSpotView(
       tipo: .evento,
       titulo: "Mobile-se",
       nomeImagem: "mobilese",
       textoInfo: "23.09 10h",
       localCidade: "Recife, PE",
       estaSalvo: false,
       aoAlternarSalvo: {}
   )
   .padding()
   .background(Color.black)
}
