//
//  CardDestaqueView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
import UIKit

struct CardEvento: View {
    @Environment(SessaoUsuario.self) private var sessao

    static let proporcaoDaLargura: CGFloat = 0.953
    static let proporcaoDoCard: CGFloat = 344 / 320
    static let alturaDoRodape: CGFloat = 96

    let imagem: ImagemCardSimples
    let tipo: TipoSpot
    let titulo: String
    let localizacao: String
    let informacao: String
    let estaSalvo: Bool
    let estaAlterandoSalvo: Bool
    let podeSalvar: Bool
    private let spotID: UUID?
    private let aoAlternarSalvo: () -> Void

    init(
        imagem: ImagemCardSimples,
        tipo: TipoSpot,
        titulo: String,
        localizacao: String,
        informacao: String,
        estaSalvo: Bool,
        estaAlterandoSalvo: Bool,
        podeSalvar: Bool,
        aoAlternarSalvo: @escaping () -> Void,
        spotID: UUID? = nil
    ) {
        self.imagem = imagem
        self.tipo = tipo
        self.titulo = titulo
        self.localizacao = localizacao
        self.informacao = informacao
        self.estaSalvo = estaSalvo
        self.estaAlterandoSalvo = estaAlterandoSalvo
        self.podeSalvar = podeSalvar
        self.spotID = spotID
        self.aoAlternarSalvo = aoAlternarSalvo
    }

    init(
        spot: Spot,
        imagem: ImagemCardSimples = .placeholder,
        estaSalvo: Bool,
        estaAlterandoSalvo: Bool,
        podeSalvar: Bool,
        aoAlternarSalvo: @escaping () -> Void
    ) {
        let dados = CardSimplesDados(spot: spot, imagem: imagem)
        self.init(
            imagem: imagem,
            tipo: spot.tipo,
            titulo: dados.titulo,
            localizacao: dados.localCidade,
            informacao: dados.textoInfo,
            estaSalvo: estaSalvo,
            estaAlterandoSalvo: estaAlterandoSalvo,
            podeSalvar: podeSalvar,
            aoAlternarSalvo: aoAlternarSalvo,
            spotID: spot.id
        )
    }

    init(
        imageEvento: String,
        titulo: String,
        localizacao: String,
        data: String,
        hora: String,
        estaSalvo: Bool,
        estaAlterandoSalvo: Bool,
        podeSalvar: Bool,
        aoAlternarSalvo: @escaping () -> Void
    ) {
        self.init(
            imagem: imageEvento.isEmpty ? .placeholder : .asset(imageEvento),
            tipo: .evento,
            titulo: titulo,
            localizacao: localizacao,
            informacao: [data, hora].filter { !$0.isEmpty }.joined(separator: " "),
            estaSalvo: estaSalvo,
            estaAlterandoSalvo: estaAlterandoSalvo,
            podeSalvar: podeSalvar,
            aoAlternarSalvo: aoAlternarSalvo
        )
    }

    var body: some View {
        cartao
    }

    private var cartao: some View {
        Color.clear
            .aspectRatio(Self.proporcaoDoCard, contentMode: .fit)
            .overlay {
                conteudoDoCard
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .containerRelativeFrame(.horizontal) { larguraDoContainer, _ in
                larguraDoContainer * Self.proporcaoDaLargura
            }
            .accessibilityElement(children: .contain)
    }

    private var conteudoDoCard: some View {
        VStack(spacing: 0) {
            abrirDetalhes { imagemPrincipal }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    abrirDetalhes {
                        Text(titulo)
                            .font(.title2.bold())
                            .foregroundStyle(corDestaque)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    // Irmão do link, sem uma área de navegação por baixo.
                    botaoSalvar
                }

                abrirDetalhes {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            informacaoLocal
                            informacaoTemporal
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            informacaoLocal
                            informacaoTemporal
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: Self.alturaDoRodape,
                maxHeight: Self.alturaDoRodape,
                alignment: .topLeading
            )
            .background(Color(.secondarySystemBackground))
            .layoutPriority(1)
        }
    }

    @ViewBuilder
    private func abrirDetalhes<Conteudo: View>(@ViewBuilder conteudo: () -> Conteudo) -> some View {
        if let spotID {
            NavigationLink {
                DetalhesSpotView(spotID: spotID, sessao: sessao)
            } label: {
                conteudo().contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir detalhes de \(titulo)")
        } else {
            conteudo()
        }
    }

    private var corDestaque: Color {
        switch tipo {
        case .evento: return Color("CorEvento")
        case .espaco: return Color("CorEspaco")
        }
    }

    private var iconeInformacao: String {
        tipo == .evento ? "calendar" : "clock"
    }

    private var imagemPrincipal: some View {
        Color(.tertiarySystemBackground)
            .overlay {
                conteudoDaImagem
            }
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var conteudoDaImagem: some View {
        switch imagem {
        case .asset(let nome):
            Image(nome)
                .resizable()
                .scaledToFill()

        case .arquivo(let url):
            if let imagem = UIImage(contentsOfFile: url.path) {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }

        case .placeholder:
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: tipo == .evento ? "calendar.badge.clock" : "building.2")
            .font(.system(size: 54, weight: .light))
            .foregroundStyle(.secondary)
    }

    private var informacaoLocal: some View {
        Label {
            Text(localizacao)
                .lineLimit(1)
        } icon: {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(corDestaque)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }

    private var informacaoTemporal: some View {
        Label {
            Text(informacao)
                .lineLimit(1)
        } icon: {
            Image(systemName: iconeInformacao)
                .foregroundStyle(corDestaque)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }

    private var botaoSalvar: some View {
        Button(action: aoAlternarSalvo) {
            Group {
                if !podeSalvar {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.title3)
                } else {
                    Image(systemName: estaSalvo ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                }
            }
            .frame(width: 44, height: 44)
            .foregroundStyle(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!podeSalvar || estaAlterandoSalvo)
        .opacity(podeSalvar ? 1 : 0.45)
        .accessibilityLabel(
            !podeSalvar
                ? "Seu Spot"
                : (estaSalvo ? "Remover dos salvos" : "Salvar Spot")
        )
        .accessibilityValue(estaAlterandoSalvo ? "Atualizando" : "")
    }
}

#Preview {
    ScrollView(.horizontal) {
        LazyHStack {
            CardEvento(
                imageEvento: "fablab",
                titulo: "Makerday",
                localizacao: "Recife, PE",
                data: "23.09",
                hora: "10h",
                estaSalvo: true,
                estaAlterandoSalvo: false,
                podeSalvar: true,
                aoAlternarSalvo: {}
            )
        }
        .scrollTargetLayout()
    }
    .contentMargins(.horizontal, 20, for: .scrollContent)
    .background(.black)
    .environment(SessaoUsuario())
    .preferredColorScheme(.dark)
}
