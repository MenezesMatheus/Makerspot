//
//  CardSimplesView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI
import UIKit

enum ImagemCardSimples {
    case asset(String)
    case arquivo(URL)
    case placeholder
}

private extension TipoSpot {
    var corDestaque: Color {
        switch self {
        case .evento: return .orange
        case .espaco: return .blue
        }
    }

    var rotulo: String {
        switch self {
        case .evento: return "Evento"
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

enum CardSimplesModo {
    case visitante(
        estaSalvo: Bool,
        estaProcessando: Bool,
        podeSalvar: Bool,
        aoAlternar: () -> Void
    )
    case proprietario(
        estaAtivo: Bool,
        estaProcessando: Bool,
        aoAlternar: (Bool) -> Void
    )
}

struct CardSimplesDados: Identifiable {
    let id: UUID
    let tipo: TipoSpot
    let titulo: String
    let imagem: ImagemCardSimples
    let textoInfo: String
    let localCidade: String
    
    init(
        id: UUID = UUID(),
        tipo: TipoSpot,
        titulo: String,
        imagem: ImagemCardSimples = .placeholder,
        textoInfo: String,
        localCidade: String
    ) {
        self.id = id
        self.tipo = tipo
        self.titulo = titulo
        self.imagem = imagem
        self.textoInfo = textoInfo
        self.localCidade = localCidade
    }

    init(
        spot: Spot,
        imagem: ImagemCardSimples = .placeholder,
        agora: Date = Date()
    ) {
        self.id = spot.id
        self.tipo = spot.tipo
        self.titulo = spot.nome
        self.imagem = imagem
        self.localCidade = Self.localizacaoResumida(spot.localizacao)

        switch spot.detalhes {
        case .evento(let evento):
            self.textoInfo = Self.descricao(evento: evento)
        case .espaco(let espaco):
            self.textoInfo = Self.descricao(espaco: espaco, agora: agora)
        }
    }

    private static func localizacaoResumida(_ localizacao: Localizacao) -> String {
        "\(localizacao.endereco.cidade), \(localizacao.endereco.estado)"
    }

    private static func descricao(evento: Evento) -> String {
        let formatador = DateFormatter()
        formatador.locale = Locale(identifier: "pt_BR")
        formatador.timeZone = TimeZone(identifier: evento.fusoHorarioID) ?? .current
        formatador.dateFormat = "dd.MM HH'h'"
        return formatador.string(from: evento.inicio)
    }

    private static func descricao(espaco: Espaco, agora: Date) -> String {
        let fusoHorario = TimeZone(
            identifier: espaco.funcionamento.fusoHorarioID
        ) ?? .current
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = fusoHorario

        let diaAtual = diaSemana(
            para: calendario.component(.weekday, from: agora)
        )
        guard let funcionamentoHoje = espaco.funcionamento.dias.first(
            where: { $0.dia == diaAtual }
        ), !funcionamentoHoje.intervalos.isEmpty else {
            return "Fechado hoje"
        }

        let intervalos = funcionamentoHoje.intervalos.map { intervalo in
            let abertura = horarioFormatado(intervalo.abertura)
            let fechamento = horarioFormatado(intervalo.fechamento)
            return "\(abertura)–\(fechamento)"
        }
            .joined(separator: ", ")

        return "Aberto \(intervalos)"
    }

    private static func diaSemana(para valorDoCalendario: Int) -> DiaSemana {
        switch valorDoCalendario {
        case 1: return .domingo
        case 2: return .segunda
        case 3: return .terca
        case 4: return .quarta
        case 5: return .quinta
        case 6: return .sexta
        default: return .sabado
        }
    }

    private static func horarioFormatado(_ horario: HorarioLocal) -> String {
        if horario.minuto == 0 {
            return String(format: "%02dh", horario.hora)
        }
        return String(format: "%02dh%02d", horario.hora, horario.minuto)
    }
}

struct CardSimplesView: View {
    let dados: CardSimplesDados
    let modo: CardSimplesModo
    let aoSelecionar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ImagemCardSimplesView(imagem: dados.imagem)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dados.titulo)
                            .font(.title2.bold())
                            .foregroundStyle(dados.tipo.corDestaque)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(dados.tipo.rotulo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    controleFinal
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 6) {
                    InfoCardSimples(
                        icon: dados.tipo.iconeInfo,
                        text: dados.textoInfo,
                        cor: dados.tipo.corDestaque,
                        peso: pesoInformacoes
                    )
                    InfoCardSimples(
                        icon: "mappin.and.ellipse",
                        text: dados.localCidade,
                        cor: dados.tipo.corDestaque,
                        peso: pesoInformacoes
                    )
                }
            }
            .frame(height: 104)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .contentShape(RoundedRectangle(cornerRadius: 28))
        .onTapGesture(perform: aoSelecionar)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Abrir detalhes", aoSelecionar)
    }

    private var pesoInformacoes: Font.Weight {
        switch modo {
        case .visitante: return .semibold
        case .proprietario: return .regular
        }
    }

    @ViewBuilder
    private var controleFinal: some View {
        switch modo {
        case let .visitante(
            estaSalvo,
            estaProcessando,
            podeSalvar,
            aoAlternar
        ):
            Button(action: aoAlternar) {
                Group {
                    if estaProcessando {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: estaSalvo ? "bookmark.fill" : "bookmark")
                    }
                }
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(!podeSalvar || estaProcessando)
            .opacity(podeSalvar ? 1 : 0.45)
            .accessibilityLabel(
                estaSalvo ? "Remover dos salvos" : "Salvar Spot"
            )
            .accessibilityValue(estaProcessando ? "Atualizando" : "")

        case let .proprietario(
            estaAtivo,
            estaProcessando,
            aoAlternar
        ):
            ZStack {
                Toggle(
                    "Oferta ativa",
                    isOn: Binding(
                        get: { estaAtivo },
                        set: { novoValor in
                            guard !estaProcessando else { return }
                            aoAlternar(novoValor)
                        }
                    )
                )
                .labelsHidden()
                .tint(dados.tipo.corDestaque)
                .disabled(estaProcessando)
                .opacity(estaProcessando ? 0 : 1)
                .accessibilityLabel("Oferta ativa")
                .accessibilityValue(estaAtivo ? "Ativada" : "Desativada")

                if estaProcessando {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Atualizando oferta")
                }
            }
            .frame(minWidth: 52, minHeight: 44)
        }
    }
}

private struct ImagemCardSimplesView: View {
    let imagem: ImagemCardSimples

    var body: some View {
        conteudo
            .frame(width: 104, height: 104)
            .background(Color(white: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var conteudo: some View {
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
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
    }
}

private struct InfoCardSimples: View {
    let icon: String
    let text: String
    let cor: Color
    let peso: Font.Weight

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(cor)
            Text(text)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .font(.subheadline.weight(peso))
    }
}

// MARK: - Previews

#Preview("Evento - visitante") {
    CardSimplesView(
        dados: CardSimplesDados(
            tipo: .evento,
            titulo: "Mobile-se",
            imagem: .asset("mobilese"),
            textoInfo: "23.09 10h",
            localCidade: "Recife, PE"
        ),
        modo: .visitante(
            estaSalvo: false,
            estaProcessando: false,
            podeSalvar: true,
            aoAlternar: {}
        ),
        aoSelecionar: { print("Abrir detalhes") }
    )
    .padding()
    .background(.black)
}

#Preview("Espaço - visitante") {
    CardSimplesView(
        dados: CardSimplesDados(
            tipo: .espaco,
            titulo: "Fab Lab",
            imagem: .asset("fablab"),
            textoInfo: "Aberto 08h–18h",
            localCidade: "Recife, PE"
        ),
        modo: .visitante(
            estaSalvo: true,
            estaProcessando: false,
            podeSalvar: true,
            aoAlternar: {}
        ),
        aoSelecionar: { print("Abrir detalhes") }
    )
    .padding()
    .background(.black)
}

#Preview("Evento - proprietário") {
    CardSimplesView(
        dados: CardSimplesDados(
            tipo: .evento,
            titulo: "Makerday",
            textoInfo: "30.09 14h",
            localCidade: "Recife, PE"
        ),
        modo: .proprietario(
            estaAtivo: true,
            estaProcessando: false,
            aoAlternar: { _ in }
        ),
        aoSelecionar: { print("Abrir detalhes") }
    )
    .padding()
    .background(.black)
}

#Preview("Espaço - proprietário") {
    CardSimplesView(
        dados: CardSimplesDados(
            tipo: .espaco,
            titulo: "Oficina Criativa",
            textoInfo: "Aberto 09h–17h",
            localCidade: "Olinda, PE"
        ),
        modo: .proprietario(
            estaAtivo: true,
            estaProcessando: false,
            aoAlternar: { _ in }
        ),
        aoSelecionar: { print("Abrir detalhes") }
    )
    .padding()
    .background(.black)
}
