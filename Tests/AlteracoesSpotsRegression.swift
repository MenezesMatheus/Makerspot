import Combine
import Foundation

// Executável de regressão sem CloudKit. Compila junto às entidades e ao
// AlteracoesSpots usados pelo app; não cria registros na conta do usuário.
@main
struct AlteracoesSpotsRegression {
    @MainActor
    static func main() {
        let alteracoes = AlteracoesSpots()
        let dono = UUID()
        let outroDono = UUID()
        let original = criarSpot(dono: dono)
        var atualizado = original
        atualizado.nome = "Nome editado"
        atualizado.fotoIDs = [UUID()]
        atualizado.versao = 2

        // Telas abertas recebem o evento e telas abertas depois recuperam o estado.
        var eventosRecebidos = 0
        let observador = alteracoes.atualizacoes.sink { eventosRecebidos += 1 }
        alteracoes.atualizar(atualizado)
        precondition(eventosRecebidos == 1)
        precondition(alteracoes.consolidar([]) { $0.estaAtivo } == [atualizado])
        precondition(alteracoes.consolidar([original]) { $0.estaAtivo } == [atualizado])
        precondition(alteracoes.consolidar([original, original]) { _ in true }.count == 1)
        precondition(alteracoes.consolidar([]) { $0.proprietarioID == outroDono }.isEmpty)
        precondition(alteracoes.consolidar([]) { $0.tipo == .espaco }.isEmpty)

        // Disponibilidade atualiza descoberta e perfil, com filtros diferentes.
        var indisponivel = atualizado
        indisponivel.estaAtivo = false
        indisponivel.versao = 3
        alteracoes.atualizar(indisponivel)
        precondition(alteracoes.consolidar([original]) { $0.estaAtivo }.isEmpty)
        precondition(alteracoes.consolidar([original]) { $0.proprietarioID == dono } == [indisponivel])
        var remotoMaisNovo = indisponivel
        remotoMaisNovo.versao = 4
        remotoMaisNovo.nome = "Edição em outro dispositivo"
        precondition(alteracoes.consolidar([remotoMaisNovo]) { _ in true } == [remotoMaisNovo])

        // Salvar em uma tela aparece na outra, inclusive antes do índice remoto.
        let salvo = SpotSalvo(usuarioID: outroDono, spotID: original.id,
                              salvoEm: Date(), ultimaVersaoConhecida: 1)
        alteracoes.salvar(salvo, spot: indisponivel)
        precondition(alteracoes.consolidarSalvos([]) == [original.id])
        let itens = alteracoes.consolidarItensSalvos([])
        precondition(itens.count == 1 && itens[0].spot == indisponivel)
        precondition(itens[0].foiAtualizado)
        alteracoes.dessalvar(original.id)
        alteracoes.marcarComoVisualizado(salvo, spot: indisponivel)
        precondition(alteracoes.consolidarSalvos([original.id]).isEmpty)
        precondition(alteracoes.consolidarItensSalvos(itens).isEmpty)

        // Exclusão não pode ser revertida por respostas antigas em andamento.
        alteracoes.salvar(salvo, spot: indisponivel)
        alteracoes.excluir(original.id)
        alteracoes.atualizar(original)
        alteracoes.salvar(salvo, spot: original)
        precondition(alteracoes.consolidar([original]) { _ in true }.isEmpty)
        precondition(alteracoes.consolidarItensSalvos(itens).isEmpty)
        precondition(alteracoes.exclusaoConfirmada == original.id)

        // Troca de sessão não reaproveita alterações da conta anterior.
        alteracoes.limpar()
        precondition(alteracoes.excluidos.isEmpty && alteracoes.salvos.isEmpty)
        precondition(alteracoes.exclusaoConfirmada == nil)
        precondition(alteracoes.consolidar([original]) { _ in true } == [original])
        withExtendedLifetime(observador) {}
        print("PASS: propagação, filtros, fotos, versões, salvos, exclusão e limpeza de sessão")
    }

    static func criarSpot(dono: UUID) -> Spot {
        Spot(id: UUID(), proprietarioID: dono, nomePublicador: "Teste",
             nome: "Original", descricao: "Teste",
             localizacao: Localizacao(
                endereco: Endereco(logradouro: "Rua", numero: "1", complemento: nil,
                                   bairro: nil, cidade: "Recife", estado: "PE",
                                   codigoPostal: nil, codigoPais: "BR"),
                coordenadas: Coordenadas(latitude: -8, longitude: -34)),
             telefone: "", link: nil,
             detalhes: .evento(Evento(inicio: Date(), termino: Date().addingTimeInterval(3600),
                                      fusoHorarioID: "America/Recife")),
             criadoEm: Date(), atualizadoEm: Date())
    }
}
