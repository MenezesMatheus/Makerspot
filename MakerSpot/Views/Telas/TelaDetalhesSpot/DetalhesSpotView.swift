//
//  DetalhesSpotView.swift
//  MakerSpot
//

import SwiftUI

struct DetalhesSpotView: View {

    let spot: Spot

    @State private var mostrarSheetReportar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Título

                Text(spot.nome)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // MARK: - Fotos

                CarrosselFotosSpot(
                    quantidadeFotos: max(spot.fotoIDs.count, 3)
                )
                .padding(.bottom, 24)

                // MARK: - Descrição

                Text(spot.descricao)
                    .font(.body)
                    .padding(.horizontal, 16)

                // MARK: - Link

                if let link = spot.link {
                    Link(destination: link) {
                        Text(link.absoluteString)
                            .font(.body)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // MARK: - Informações

                VStack(alignment: .leading, spacing: 10) {

                    switch spot.detalhes {

                    case .evento(let evento):
                        LinhaInformacaoSpot(
                            icone: "calendar",
                            texto: textoDataEvento(evento),
                            cor: corDestaque
                        )

                    case .espaco(let espaco):
                        LinhaInformacaoSpot(
                            icone: "clock",
                            texto: textoFuncionamentoEspaco(espaco),
                            cor: corDestaque
                        )
                    }

                    LinhaInformacaoSpot(
                        icone: "phone",
                        texto: spot.telefone,
                        cor: corDestaque
                    )

                    LinhaInformacaoSpot(
                        icone: "mappin.and.ellipse",
                        texto: textoEndereco,
                        cor: corDestaque
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                // MARK: - Publicador

                HStack(spacing: 12) {

                    Circle()
                        .fill(.quaternary)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }

                    Text(spot.nomePublicador)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // MARK: - Divisor

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // MARK: - Aviso

                Text("Para mais informações entre em contato com o organizador do spot.")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)

        // MARK: - TopBar

        .toolbar {
            TopBar(
                type: .reportSave,
                action1: {
                    mostrarSheetReportar = true
                },
                action2: {
                    print("Salvar Spot")
                }
            )
        }

        // MARK: - Sheet de denúncia

        .sheet(isPresented: $mostrarSheetReportar) {
            SheetReportarView()
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }


    // MARK: - Cor

    private var corDestaque: Color {
        switch spot.tipo {

        case .evento:
            return Color("CorEvento")

        case .espaco:
            return Color("CorEspaco")
        }
    }


    // MARK: - Endereço

    private var textoEndereco: String {

        let endereco = spot.localizacao.endereco

        var texto = "\(endereco.logradouro), nº \(endereco.numero)"

        if let complemento = endereco.complemento,
           !complemento.isEmpty {
            texto += " - \(complemento)"
        }

        texto += " - \(endereco.cidade), \(endereco.estado)"

        return texto
    }


    // MARK: - Evento

    private func textoDataEvento(_ evento: Evento) -> String {

        let calendario = Calendar.current

        let mesmoDia = calendario.isDate(
            evento.inicio,
            inSameDayAs: evento.termino
        )

        let formatadorData = DateFormatter()
        formatadorData.locale = Locale(identifier: "pt_BR")
        formatadorData.dateFormat = "dd.MM"

        let formatadorHorario = DateFormatter()
        formatadorHorario.locale = Locale(identifier: "pt_BR")
        formatadorHorario.dateFormat = "HH'h'"

        let dataInicio = formatadorData.string(from: evento.inicio)
        let dataTermino = formatadorData.string(from: evento.termino)

        let horaInicio = formatadorHorario.string(from: evento.inicio)
        let horaTermino = formatadorHorario.string(from: evento.termino)

        if mesmoDia {
            return "\(dataInicio) \(horaInicio) - \(horaTermino)"
        }

        return "\(dataInicio) \(horaInicio) - \(dataTermino) \(horaTermino)"
    }


    // MARK: - Espaço

    private func textoFuncionamentoEspaco(_ espaco: Espaco) -> String {

        let diasComFuncionamento = espaco.funcionamento.dias.filter {
            !$0.intervalos.isEmpty
        }

        guard !diasComFuncionamento.isEmpty else {
            return "Horário não informado"
        }

        guard
            let primeiroDia = diasComFuncionamento.first,
            let ultimoDia = diasComFuncionamento.last,
            let primeiroIntervalo = primeiroDia.intervalos.first
        else {
            return "Horário não informado"
        }

        let abertura = textoHorario(primeiroIntervalo.abertura)
        let fechamento = textoHorario(primeiroIntervalo.fechamento)

        if diasComFuncionamento.count == 1 {
            return "Aberto \(abertura) às \(fechamento) - \(abreviacaoDia(primeiroDia.dia))"
        }

        return "Aberto \(abertura) às \(fechamento) - \(abreviacaoDia(primeiroDia.dia)) a \(abreviacaoDia(ultimoDia.dia))"
    }


    private func textoHorario(_ horario: HorarioLocal) -> String {

        if horario.minuto == 0 {
            return String(
                format: "%02dh",
                horario.hora
            )
        }

        return String(
            format: "%02dh%02d",
            horario.hora,
            horario.minuto
        )
    }


    private func abreviacaoDia(_ dia: DiaSemana) -> String {

        switch dia {

        case .segunda:
            return "seg"

        case .terca:
            return "ter"

        case .quarta:
            return "qua"

        case .quinta:
            return "qui"

        case .sexta:
            return "sex"

        case .sabado:
            return "sáb"

        case .domingo:
            return "dom"
        }
    }
}


// MARK: - Linha de informação

private struct LinhaInformacaoSpot: View {

    let icone: String
    let texto: String
    let cor: Color

    var body: some View {

        HStack(alignment: .top, spacing: 8) {

            Image(systemName: icone)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(cor)
                .frame(width: 18)

            Text(texto)
                .font(.body)
                .fontWeight(.semibold)

            Spacer()
        }
    }
}


// MARK: - Preview Evento

#Preview("Evento") {

    NavigationStack {

        DetalhesSpotView(
            spot: Spot(
                id: UUID(),
                proprietarioID: UUID(),

                nomePublicador: "Adailton José",

                nome: "Maker School",

                descricao: """
                Bbdasi . aubfa bviabvsa v v avbiasvbaks bv vasv asibca a ciabciasb ciasbias ias viasvb isavv isa vb asa asb cis ias
                """,

                localizacao: Localizacao(
                    endereco: Endereco(
                        logradouro: "Rua das cores",
                        numero: "07",
                        complemento: nil,
                        bairro: "Centro",
                        cidade: "Recife",
                        estado: "PE",
                        codigoPostal: "50000-000",
                        codigoPais: "BR"
                    ),

                    coordenadas: Coordenadas(
                        latitude: -8.0476,
                        longitude: -34.8770
                    )
                ),

                telefone: "81 9 8798-2222",

                link: URL(
                    string: "https://makerschoolnicksaraev.com/"
                ),

                redesSociais: [],

                fotoIDs: [
                    UUID(),
                    UUID(),
                    UUID()
                ],

                detalhes: .evento(
                    Evento(
                        inicio: criarData(
                            dia: 23,
                            mes: 9,
                            ano: 2026,
                            hora: 10
                        ),

                        termino: criarData(
                            dia: 30,
                            mes: 9,
                            ano: 2026,
                            hora: 18
                        ),

                        fusoHorarioID: "America/Recife"
                    )
                ),

                estaAtivo: true,
                versao: 1,

                criadoEm: Date(),
                atualizadoEm: Date()
            )
        )
    }
}


// MARK: - Preview Espaço

#Preview("Espaço") {

    NavigationStack {

        DetalhesSpotView(
            spot: Spot(
                id: UUID(),
                proprietarioID: UUID(),

                nomePublicador: "Adailton José",

                nome: "Makerlab",

                descricao: """
                Bbdasi . aubfa bviabvsa v v avbiasvbaks bv vasv asibca a ciabciasb ciasbias ias viasvb isavv isa vb asa asb cis ias
                """,

                localizacao: Localizacao(
                    endereco: Endereco(
                        logradouro: "Rua robonilda",
                        numero: "88",
                        complemento: nil,
                        bairro: "Centro",
                        cidade: "Recife",
                        estado: "PE",
                        codigoPostal: "50000-000",
                        codigoPais: "BR"
                    ),

                    coordenadas: Coordenadas(
                        latitude: -8.0476,
                        longitude: -34.8770
                    )
                ),

                telefone: "81 9 8798-2222",

                link: URL(
                    string: "https://makerschoolnicksaraev.com/"
                ),

                redesSociais: [],

                fotoIDs: [
                    UUID(),
                    UUID(),
                    UUID()
                ],

                detalhes: .espaco(
                    Espaco(
                        funcionamento: FuncionamentoSemanal(

                            fusoHorarioID: "America/Recife",

                            dias: [
                                criarDia(
                                    .segunda,
                                    abertura: 8,
                                    fechamento: 18
                                ),

                                criarDia(
                                    .terca,
                                    abertura: 8,
                                    fechamento: 18
                                ),

                                criarDia(
                                    .quarta,
                                    abertura: 8,
                                    fechamento: 18
                                ),

                                criarDia(
                                    .quinta,
                                    abertura: 8,
                                    fechamento: 18
                                ),

                                criarDia(
                                    .sexta,
                                    abertura: 8,
                                    fechamento: 18
                                )
                            ]
                        )
                    )
                ),

                estaAtivo: true,
                versao: 1,

                criadoEm: Date(),
                atualizadoEm: Date()
            )
        )
    }
}


// MARK: - Helpers dos Previews

private func criarData(
    dia: Int,
    mes: Int,
    ano: Int,
    hora: Int,
    minuto: Int = 0
) -> Date {

    var componentes = DateComponents()

    componentes.day = dia
    componentes.month = mes
    componentes.year = ano
    componentes.hour = hora
    componentes.minute = minuto

    return Calendar.current.date(
        from: componentes
    ) ?? Date()
}


private func criarDia(
    _ dia: DiaSemana,
    abertura: Int,
    fechamento: Int
) -> FuncionamentoDia {

    FuncionamentoDia(
        dia: dia,

        intervalos: [
            IntervaloFuncionamento(

                abertura: HorarioLocal(
                    hora: abertura,
                    minuto: 0
                ),

                fechamento: HorarioLocal(
                    hora: fechamento,
                    minuto: 0
                ),

                terminaNoDiaSeguinte: false
            )
        ]
    )
}
