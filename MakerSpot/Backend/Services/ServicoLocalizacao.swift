//
//  ServicoLocalizacao.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import Foundation
import CoreLocation
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

@MainActor
final class ServicoLocalizacaoUsuario: NSObject, CLLocationManagerDelegate {
    private let gerenciador = CLLocationManager()
    private var continuacao: CheckedContinuation<Coordenadas?, Never>?

    override init() {
        super.init()
        gerenciador.delegate = self
        gerenciador.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func obterCoordenadas() async -> Coordenadas? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }

        if let localizacao = gerenciador.location {
            return Self.coordenadas(de: localizacao)
        }

        guard continuacao == nil else { return nil }

        return await withCheckedContinuation { continuacao in
            self.continuacao = continuacao

            switch gerenciador.authorizationStatus {
            case .notDetermined:
                gerenciador.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                gerenciador.requestLocation()
            case .denied, .restricted:
                concluir(com: nil)
            @unknown default:
                concluir(com: nil)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuacao != nil else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            concluir(com: nil)
        case .notDetermined:
            break
        @unknown default:
            concluir(com: nil)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        concluir(com: locations.last.map(Self.coordenadas(de:)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        concluir(com: nil)
    }

    private func concluir(com coordenadas: Coordenadas?) {
        continuacao?.resume(returning: coordenadas)
        continuacao = nil
    }

    private static func coordenadas(de localizacao: CLLocation) -> Coordenadas {
        Coordenadas(
            latitude: localizacao.coordinate.latitude,
            longitude: localizacao.coordinate.longitude
        )
    }
}
