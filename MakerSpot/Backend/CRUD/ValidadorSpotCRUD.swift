//
//  ValidadorSpotCRUD.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 15/09/26.
//

import Foundation

enum ValidadorSpotCRUD {
    static func validarENormalizar(_ dados: DadosSpot) throws -> DadosSpot {
        var resultado = dados
        resultado.nome = try ApoioCRUD.textoObrigatorio(
            dados.nome,
            nome: "o nome do Spot"
        )
        resultado.descricao = ApoioCRUD.textoOpcional(dados.descricao) ?? ""
        resultado.telefone = ApoioCRUD.textoOpcional(dados.telefone) ?? ""
        resultado.endereco = try normalizar(dados.endereco)
        try ApoioCRUD.validarURLWeb(dados.link, nome: "divulgação")
        resultado.redesSociais = try dados.redesSociais.map { rede in
            let nome = try ApoioCRUD.textoObrigatorio(
                rede.nome,
                nome: "o nome da rede social"
            )
            try ApoioCRUD.validarURLWeb(rede.url, nome: nome)
            return RedeSocial(nome: nome, url: rede.url)
        }
        try validar(dados.detalhes)
        return resultado
    }

    static func validarRecebido(_ spot: Spot) throws {
        _ = try ApoioCRUD.textoObrigatorio(
            spot.nomePublicador,
            nome: "o nome de quem publicou"
        )
        guard spot.versao >= 1,
              spot.criadoEm <= spot.atualizadoEm else {
            throw ErroCRUD.respostaInconsistente
        }
        guard Set(spot.fotoIDs).count == spot.fotoIDs.count else {
            throw ErroCRUD.respostaInconsistente
        }
        guard spot.localizacao.coordenadas.latitude.isFinite,
              spot.localizacao.coordenadas.longitude.isFinite,
              (-90...90).contains(spot.localizacao.coordenadas.latitude),
              (-180...180).contains(spot.localizacao.coordenadas.longitude) else {
            throw ErroCRUD.respostaInconsistente
        }

        _ = try validarENormalizar(
            DadosSpot(
                nome: spot.nome,
                descricao: spot.descricao,
                endereco: spot.localizacao.endereco,
                telefone: spot.telefone,
                link: spot.link,
                redesSociais: spot.redesSociais,
                detalhes: spot.detalhes
            )
        )
    }

    static func validarFuncionamento(_ funcionamento: FuncionamentoSemanal) throws {
        try validar(.espaco(Espaco(funcionamento: funcionamento)))
    }

    private static func normalizar(_ endereco: Endereco) throws -> Endereco {
        Endereco(
            logradouro: try ApoioCRUD.textoObrigatorio(
                endereco.logradouro,
                nome: "o logradouro"
            ),
            numero: try ApoioCRUD.textoObrigatorio(endereco.numero, nome: "o número"),
            complemento: ApoioCRUD.textoOpcional(endereco.complemento),
            bairro: ApoioCRUD.textoOpcional(endereco.bairro),
            cidade: try ApoioCRUD.textoObrigatorio(endereco.cidade, nome: "a cidade"),
            estado: try ApoioCRUD.textoObrigatorio(endereco.estado, nome: "o estado"),
            codigoPostal: ApoioCRUD.textoOpcional(endereco.codigoPostal),
            codigoPais: try ApoioCRUD.textoObrigatorio(
                endereco.codigoPais,
                nome: "o código do país"
            )
        )
    }

    private static func validar(_ detalhes: DetalhesSpot) throws {
        switch detalhes {
        case .evento(let evento):
            guard evento.inicio < evento.termino else {
                throw ErroCRUD.dadosInvalidos(
                    descricao: "O término do evento precisa ocorrer depois do início."
                )
            }
            try validarFusoHorario(evento.fusoHorarioID)

        case .espaco(let espaco):
            try validarFusoHorario(espaco.funcionamento.fusoHorarioID)
            guard !espaco.funcionamento.dias.isEmpty else {
                throw ErroCRUD.dadosInvalidos(
                    descricao: "Informe ao menos um dia de funcionamento."
                )
            }

            let dias = espaco.funcionamento.dias.map(\.dia)
            guard Set(dias).count == dias.count else {
                throw ErroCRUD.dadosInvalidos(
                    descricao: "Cada dia da semana deve aparecer somente uma vez."
                )
            }
            var faixasDaSemana: [Range<Int>] = []
            for dia in espaco.funcionamento.dias {
                guard let indiceDia = DiaSemana.allCases.firstIndex(of: dia.dia) else {
                    throw ErroCRUD.respostaInconsistente
                }
                let inicioDoDia = indiceDia * 24 * 60
                faixasDaSemana.append(
                    contentsOf: try validarIntervalos(dia.intervalos).map { faixa in
                        (faixa.lowerBound + inicioDoDia)..<(faixa.upperBound + inicioDoDia)
                    }
                )
            }
            try validarSobreposicoesNaSemana(faixasDaSemana)
        }
    }

    private static func validarFusoHorario(_ identificador: String) throws {
        guard TimeZone(identifier: identificador) != nil else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "O fuso horário informado não é válido."
            )
        }
    }

    private static func validarIntervalos(
        _ intervalos: [IntervaloFuncionamento]
    ) throws -> [Range<Int>] {
        guard !intervalos.isEmpty else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Informe ao menos um intervalo de funcionamento."
            )
        }

        return try intervalos.map { intervalo -> Range<Int> in
            let abertura = try minutos(intervalo.abertura)
            let fechamentoLocal = try minutos(intervalo.fechamento)
            let fechamento: Int

            if intervalo.terminaNoDiaSeguinte {
                guard fechamentoLocal <= abertura else {
                    throw ErroCRUD.dadosInvalidos(
                        descricao: "Um horário que termina no dia seguinte não pode ultrapassar 24 horas."
                    )
                }
                fechamento = fechamentoLocal + 24 * 60
            } else {
                guard fechamentoLocal > abertura else {
                    throw ErroCRUD.dadosInvalidos(
                        descricao: "O fechamento precisa ocorrer depois da abertura."
                    )
                }
                fechamento = fechamentoLocal
            }
            return abertura..<fechamento
        }
    }

    private static func validarSobreposicoesNaSemana(
        _ faixas: [Range<Int>]
    ) throws {
        let ordenadas = faixas.sorted { $0.lowerBound < $1.lowerBound }
        let sobrepoeNaSemana = zip(ordenadas, ordenadas.dropFirst()).contains {
            $0.overlaps($1)
        }
        let sobrepoeNaVirada: Bool
        if let primeira = ordenadas.first, let ultima = ordenadas.last {
            sobrepoeNaVirada = ultima.upperBound > primeira.lowerBound + 7 * 24 * 60
        } else {
            sobrepoeNaVirada = false
        }
        guard !sobrepoeNaSemana, !sobrepoeNaVirada else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Existem horários de funcionamento sobrepostos."
            )
        }
    }

    private static func minutos(_ horario: HorarioLocal) throws -> Int {
        guard (0...23).contains(horario.hora),
              (0...59).contains(horario.minuto) else {
            throw ErroCRUD.dadosInvalidos(
                descricao: "Os horários precisam usar horas de 0 a 23 e minutos de 0 a 59."
            )
        }
        return horario.hora * 60 + horario.minuto
    }
}
