//
//  ServicoLocalizacao.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import MapKit

enum ErroLocalizacao: LocalizedError {
    case enderecoVazio
    case enderecoNaoEncontrado
    case coordenadasInvalidas
    case falhaNaBusca(descricao: String)

    var errorDescription: String? {
        switch self {
        case .enderecoVazio:
            return "Informe um endereço para localizar o Spot."
        case .enderecoNaoEncontrado:
            return "Não foi possível encontrar esse endereço."
        case .coordenadasInvalidas:
            return "As coordenadas encontradas são inválidas."
        case .falhaNaBusca(let descricao):
            return descricao
        }
    }
}

final class ServicoLocalizacao {
    func buscarCoordenadas(para endereco: Endereco) async throws -> Coordenadas {
        let texto = textoDeBusca(para: endereco)
        guard !texto.isEmpty else {
            throw ErroLocalizacao.enderecoVazio
        }

        let requisicao = MKLocalSearch.Request(naturalLanguageQuery: texto)
        requisicao.resultTypes = .address

        do {
            let resposta = try await MKLocalSearch(request: requisicao).start()
            guard let coordenada = resposta.mapItems.first?.location.coordinate else {
                throw ErroLocalizacao.enderecoNaoEncontrado
            }
            guard CLLocationCoordinate2DIsValid(coordenada) else {
                throw ErroLocalizacao.coordenadasInvalidas
            }
            return Coordenadas(
                latitude: coordenada.latitude,
                longitude: coordenada.longitude
            )
        } catch let erro as ErroLocalizacao {
            throw erro
        } catch {
            throw ErroLocalizacao.falhaNaBusca(descricao: error.localizedDescription)
        }
    }

    func abrirNoMapas(localizacao: Localizacao, nome: String) throws {
        let coordenada = CLLocationCoordinate2D(
            latitude: localizacao.coordenadas.latitude,
            longitude: localizacao.coordenadas.longitude
        )
        
        guard CLLocationCoordinate2DIsValid(coordenada) else {
            throw ErroLocalizacao.coordenadasInvalidas
        }

        let item = MKMapItem(
            location: CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude),
            address: nil
        )
        item.name = nome
        item.openInMaps()
    }

    private func textoDeBusca(para endereco: Endereco) -> String {
        [
            endereco.logradouro,
            endereco.numero,
            endereco.complemento,
            endereco.bairro,
            endereco.cidade,
            endereco.estado,
            endereco.codigoPostal,
            endereco.codigoPais
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}
