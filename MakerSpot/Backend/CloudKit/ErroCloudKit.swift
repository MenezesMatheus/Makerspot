//
//  ErroCloudKit.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import CloudKit
import Foundation

enum ErroCloudKit: LocalizedError, Sendable {
    case contaNaoAutenticada
    case contaRestrita
    case estadoDaContaIndeterminado
    case redeIndisponivel
    case servicoTemporariamenteIndisponivel(tentarNovamenteEm: TimeInterval?)
    case resultadoIndeterminado
    case registroNaoEncontrado
    case zonaNaoEncontrada
    case semPermissao
    case conflito(registroDoServidor: CKRecord?)
    case cotaExcedida
    case limiteExcedido
    case arquivoNaoEncontrado
    case arquivoAlteradoDuranteEnvio
    case arquivoIndisponivel
    case configuracaoAusente
    case argumentoInvalido
    case operacaoCancelada
    case respostaInconsistente
    indirect case falhaParcial([String: ErroCloudKit])
    case tipoRegistroIncompativel(esperado: String, recebido: String)
    case identificadorRegistroIncompativel(esperado: String, recebido: String)
    case campoAusente(campo: String, tipoRegistro: String)
    case campoInvalido(campo: String, tipoRegistro: String)
    case dadosInvalidos(descricao: String)
    case desconhecido(descricao: String)

    var errorDescription: String? {
        switch self {
        case .contaNaoAutenticada:
            return "Entre em uma conta do iCloud para continuar."
        case .contaRestrita:
            return "Esta conta do iCloud não pode usar o CloudKit."
        case .estadoDaContaIndeterminado:
            return "Não foi possível verificar a conta do iCloud."
        case .redeIndisponivel:
            return "Não foi possível acessar o iCloud. Verifique sua conexão."
        case .servicoTemporariamenteIndisponivel:
            return "O iCloud está temporariamente indisponível. Tente novamente em instantes."
        case .resultadoIndeterminado:
            return "A conexão foi interrompida antes da confirmação do iCloud. Verifique o item antes de tentar novamente."
        case .registroNaoEncontrado:
            return "O item solicitado não foi encontrado."
        case .zonaNaoEncontrada:
            return "A área de dados do aplicativo não foi encontrada no iCloud."
        case .semPermissao:
            return "Você não tem permissão para realizar esta operação."
        case .conflito:
            return "Este item foi alterado em outro dispositivo. Atualize os dados e tente novamente."
        case .cotaExcedida:
            return "O limite de armazenamento do iCloud foi atingido."
        case .limiteExcedido:
            return "A operação ultrapassou um limite do CloudKit."
        case .arquivoNaoEncontrado:
            return "A foto selecionada não foi encontrada."
        case .arquivoAlteradoDuranteEnvio:
            return "A foto foi alterada durante o envio. Selecione-a novamente."
        case .arquivoIndisponivel:
            return "A foto não está disponível para download."
        case .configuracaoAusente:
            return "O CloudKit ainda não está configurado para este aplicativo."
        case .argumentoInvalido:
            return "O CloudKit recebeu dados inválidos."
        case .operacaoCancelada:
            return "A operação com o iCloud foi cancelada."
        case .respostaInconsistente:
            return "O iCloud retornou uma resposta incompleta. Atualize os dados e tente novamente."
        case .falhaParcial:
            return "Parte da operação não pôde ser concluída."
        case .tipoRegistroIncompativel:
            return "O tipo do registro recebido não corresponde ao dado esperado."
        case .identificadorRegistroIncompativel:
            return "O identificador do registro recebido não corresponde ao dado esperado."
        case .campoAusente(let campo, _):
            return "O campo obrigatório \(campo) não foi encontrado no CloudKit."
        case .campoInvalido(let campo, _):
            return "O campo \(campo) possui um valor inválido no CloudKit."
        case .dadosInvalidos(let descricao), .desconhecido(let descricao):
            return descricao
        }
    }

    static func converter(_ error: Error) -> ErroCloudKit {
        if let erro = error as? ErroCloudKit {
            return erro
        }
        if error is CancellationError {
            return .operacaoCancelada
        }

        guard let erro = error as? CKError else {
            return .desconhecido(descricao: error.localizedDescription)
        }

        switch erro.code {
        case .notAuthenticated:
            return .contaNaoAutenticada
        case .managedAccountRestricted:
            return .contaRestrita
        case .networkUnavailable, .networkFailure:
            return .redeIndisponivel
        case .serverResponseLost:
            return .resultadoIndeterminado
        case .serviceUnavailable, .requestRateLimited, .zoneBusy, .accountTemporarilyUnavailable:
            return .servicoTemporariamenteIndisponivel(
                tentarNovamenteEm: erro.retryAfterSeconds
            )
        case .unknownItem:
            return .registroNaoEncontrado
        case .zoneNotFound, .userDeletedZone:
            return .zonaNaoEncontrada
        case .permissionFailure:
            return .semPermissao
        case .serverRecordChanged:
            return .conflito(registroDoServidor: erro.serverRecord)
        case .quotaExceeded:
            return .cotaExcedida
        case .limitExceeded:
            return .limiteExcedido
        case .assetFileNotFound:
            return .arquivoNaoEncontrado
        case .assetFileModified:
            return .arquivoAlteradoDuranteEnvio
        case .assetNotAvailable:
            return .arquivoIndisponivel
        case .badContainer, .badDatabase, .missingEntitlement:
            return .configuracaoAusente
        case .invalidArguments, .constraintViolation, .referenceViolation:
            return .argumentoInvalido
        case .operationCancelled:
            return .operacaoCancelada
        case .partialFailure:
            let falhas = erro.partialErrorsByItemID?.reduce(into: [String: ErroCloudKit]()) { resultado, item in
                resultado[String(describing: item.key)] = converter(item.value)
            } ?? [:]
            return .falhaParcial(falhas)
        default:
            return .desconhecido(descricao: erro.localizedDescription)
        }
    }
}
