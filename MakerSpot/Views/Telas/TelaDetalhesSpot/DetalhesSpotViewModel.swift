//
//  DetalhesSpotViewModel.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DetalhesSpotViewModel {
    private(set) var spot: Spot?
    private(set) var fotos: [FotoDisponivel] = []
    private(set) var estaSalvo = false
    private(set) var estaCarregando = false
    private(set) var estaAlterandoSalvo = false
    private(set) var estaExcluindo = false
    private(set) var carregouEstadoSalvo = false
    private(set) var mensagemDeErro: String?
    private(set) var estadoNotificacoes: EstadoPermissaoNotificacoes = .naoSolicitada

    let spotID: UUID

    private let sessao: SessaoUsuario
    private let spotCRUD: SpotCRUD
    private let fotoCRUD: FotoCRUD
    private let salvosCRUD: SalvosCRUD
    private let localizacao: ServicoLocalizacao
    private let notificacoes: Notificacoes

    var ehProprietario: Bool {
        guard let usuarioID = sessao.usuarioAtual?.id else { return false }
        return spot?.proprietarioID == usuarioID
    }

    init(
        spotID: UUID,
        sessao: SessaoUsuario,
        spotCRUD: SpotCRUD,
        fotoCRUD: FotoCRUD,
        salvosCRUD: SalvosCRUD,
        localizacao: ServicoLocalizacao,
        notificacoes: Notificacoes
    ) {
        self.spotID = spotID
        self.sessao = sessao
        self.spotCRUD = spotCRUD
        self.fotoCRUD = fotoCRUD
        self.salvosCRUD = salvosCRUD
        self.localizacao = localizacao
        self.notificacoes = notificacoes
    }

    convenience init(spotID: UUID, sessao: SessaoUsuario) {
        self.init(
            spotID: spotID,
            sessao: sessao,
            spotCRUD: SpotCRUD(sessao: sessao),
            fotoCRUD: FotoCRUD(sessao: sessao),
            salvosCRUD: SalvosCRUD(sessao: sessao),
            localizacao: ServicoLocalizacao(),
            notificacoes: Notificacoes()
        )
    }

    func carregar() async {
        guard !estaCarregando, !estaAlterandoSalvo, !estaExcluindo else { return }
        estaCarregando = true
        mensagemDeErro = nil
        defer { estaCarregando = false }

        carregouEstadoSalvo = false
        do {
            spot = try await spotCRUD.buscar(id: spotID)
        } catch ErroCloudKit.registroNaoEncontrado {
            spot = nil
            fotos = []
            mensagemDeErro = "Este Spot não está mais disponível."
            return
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
            return
        }

        guard let spot else { return }
        // Falhas de fotos e salvos são independentes: uma não deve impedir a outra.
        do {
            if ehProprietario {
                estaSalvo = false
            } else {
                estaSalvo = try await salvosCRUD.estaSalvo(spotID: spot.id)
            }
            carregouEstadoSalvo = true
            if estaSalvo {
                _ = try await salvosCRUD.marcarComoVisualizado(spotID: spot.id)
            }
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }

        do {
            fotos = try await fotoCRUD.buscarFotos(para: spot)
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            fotos = []
            mensagemDeErro = error.localizedDescription
        }
        estadoNotificacoes = await notificacoes.verificarPermissao()
    }

    func alternarSalvo() async {
        guard let spot, !ehProprietario, carregouEstadoSalvo,
              !estaCarregando, !estaAlterandoSalvo, !estaExcluindo else { return }
        estaAlterandoSalvo = true
        mensagemDeErro = nil
        defer { estaAlterandoSalvo = false }

        do {
            if estaSalvo {
                try await salvosCRUD.dessalvar(spotID: spot.id)
                estaSalvo = false
            } else {
                _ = try await salvosCRUD.salvar(spotID: spot.id)
                estaSalvo = true
                await prepararNotificacoes()
            }
        } catch ErroCloudKit.operacaoCancelada {
            return
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func criarDenuncia() -> ReportarSpotViewModel? {
        guard spot != nil, !ehProprietario else { return nil }
        return ReportarSpotViewModel(spotID: spotID, sessao: sessao)
    }

    @discardableResult
    func excluir() async -> Bool {
        guard spot != nil, ehProprietario, !estaCarregando,
              !estaAlterandoSalvo, !estaExcluindo else { return false }
        estaExcluindo = true
        mensagemDeErro = nil
        defer { estaExcluindo = false }
        do {
            try await spotCRUD.excluir(id: spotID)
            spot = nil
            fotos = []
            return true
        } catch ErroCloudKit.operacaoCancelada {
            return false
        } catch is CancellationError {
            return false
        } catch {
            mensagemDeErro = error.localizedDescription
            return false
        }
    }

    var textoEndereco: String {
        guard let endereco = spot?.localizacao.endereco else { return "" }
        return [
            "\(endereco.logradouro), nº \(endereco.numero)",
            endereco.complemento,
            endereco.bairro,
            "\(endereco.cidade), \(endereco.estado)"
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
    }

    var textoHorario: String {
        guard let spot else { return "" }
        switch spot.detalhes {
        case .evento(let evento):
            let formatador = DateFormatter()
            formatador.locale = Locale(identifier: "pt_BR")
            formatador.timeZone = TimeZone(identifier: evento.fusoHorarioID) ?? .current
            formatador.dateFormat = "dd.MM.yyyy HH:mm"
            return "\(formatador.string(from: evento.inicio)) – \(formatador.string(from: evento.termino))"
        case .espaco(let espaco):
            let dias = DiaSemana.allCases.compactMap { dia -> String? in
                guard let funcionamento = espaco.funcionamento.dias.first(where: { $0.dia == dia }),
                      !funcionamento.intervalos.isEmpty else { return nil }
                let intervalos = funcionamento.intervalos.map { intervalo in
                    let abertura = Self.horario(intervalo.abertura)
                    let fechamento = Self.horario(intervalo.fechamento)
                    let complemento = intervalo.terminaNoDiaSeguinte ? " (dia seguinte)" : ""
                    return "\(abertura)–\(fechamento)\(complemento)"
                }.joined(separator: ", ")
                return "\(Self.nomeDia(dia)): \(intervalos)"
            }
            return dias.isEmpty ? "Horário não informado" : dias.joined(separator: "\n")
        }
    }

    private static func horario(_ horario: HorarioLocal) -> String {
        String(format: "%02d:%02d", horario.hora, horario.minuto)
    }

    private static func nomeDia(_ dia: DiaSemana) -> String {
        switch dia {
        case .segunda: return "Seg"
        case .terca: return "Ter"
        case .quarta: return "Qua"
        case .quinta: return "Qui"
        case .sexta: return "Sex"
        case .sabado: return "Sáb"
        case .domingo: return "Dom"
        }
    }

    func abrirNoMapas() {
        guard let spot else { return }
        mensagemDeErro = nil
        do {
            try localizacao.abrirNoMapas(
                localizacao: spot.localizacao,
                nome: spot.nome
            )
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    func limparErro() {
        mensagemDeErro = nil
    }

    func receberAtualizacao(_ spotAtualizado: Spot) {
        guard spotAtualizado.id == spotID else { return }
        spot = spotAtualizado
        fotos = []
        Task { await carregarFotosAtualizadas() }
    }

    private func carregarFotosAtualizadas() async {
        guard let spot else { return }
        do {
            fotos = try await fotoCRUD.buscarFotos(para: spot)
        } catch is CancellationError {
            return
        } catch {
            mensagemDeErro = error.localizedDescription
        }
    }

    private func prepararNotificacoes() async {
        do {
            let autorizada: Bool
            switch await notificacoes.verificarPermissao() {
            case .naoSolicitada:
                autorizada = try await notificacoes.solicitarPermissao()
            case .autorizada, .provisoria:
                autorizada = true
            case .negada:
                autorizada = false
            }

            estadoNotificacoes = await notificacoes.verificarPermissao()
            if autorizada {
                notificacoes.registrarParaNotificacoesRemotas()
            }
        } catch {
            estadoNotificacoes = await notificacoes.verificarPermissao()
        }
    }
}
