// A biblioteca sem tela (Task 9 do plano da fase 2): o catálogo do motor guardado uma vez, num
// dicionário por id, a busca e os filtros de agora (a LibraryQuery), as linhas do resultado e o estado
// da lista. Toda a regra da busca fica no motor (library.js, com o searchExercises do openGym): o texto
// sem acento, nos dois idiomas, os grupos, o equipamento, a categoria e os favoritos primeiro. Aqui só
// se espera a pessoa parar de digitar, se pede a busca e se monta o que a tela mostra.
//
// A busca sai 150 ms depois da última letra; uma letra nova cancela a espera da anterior, e uma
// resposta que chega depois de outra busca pedida não vale (só a última resposta vale). As linhas vêm
// prontas para a tela: o nome, o grupo e o equipamento, e o rótulo do VoiceOver, montados fora da
// thread principal quando o catálogo chega. A linha não calcula nada no body.
//
// O catálogo é pedido de novo cada vez que a lista aparece (load), antes da busca: o catalogue() do
// motor monta o índice da busca quando o idioma ou os apelidos do documento mudaram, e a primeira
// busca depois de um documento reaberto fica dentro da meta de 100 ms (achado do QA do PR #108). Uma
// ação que mudou o documento (o revision do AppModel sobe) pede o catálogo de novo (refresh), para a
// estrela de um favorito marcado em outra tela aparecer, e a ordem fica a mesma até a próxima busca.
//
// Uma estrela tocada fica como a pessoa deixou até a ação dela chegar ao motor e o catálogo de depois
// chegar (pending): um refresh() que leu o catálogo antes dela não apaga a estrela (QA do PR #112).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a estrela muda na hora e a linha fica
// onde está; os favoritos sobem para o topo na próxima busca, na próxima troca de filtro ou quando a
// lista abre de novo, para a linha não pular de baixo do dedo. Os nomes começam com letra maiúscula (o
// openGym guarda os nomes em minúsculas e põe a maiúscula na tela); o resto do nome fica como o
// pacote do idioma diz, e o alemão continua com a grafia dele.

import Foundation
import HexEngine
import Observation
import os

@Observable @MainActor final class LibraryModel {
  enum Phase: Equatable { case loading, ready, failed }

  // A espera depois da última letra.
  static let searchDelay = Duration.milliseconds(150)

  private(set) var phase = Phase.loading
  // A busca e os filtros de agora, que o campo e a tela dos filtros mostram na hora.
  private(set) var query = LibraryQuery()
  // As linhas do resultado da última busca que valeu, na ordem do motor.
  private(set) var results: [LibraryRow] = []
  // As opções da tela dos filtros, com os nomes prontos.
  private(set) var options = LibraryFilterOptions.empty

  // Não há resultado: a busca ou os filtros não deixaram nada.
  var isEmpty: Bool { phase == .ready && results.isEmpty }

  // Quantos filtros estão ligados: cada grupo, equipamento e categoria escolhidos contam um, e "Só
  // favoritos", mais um. O texto da busca não conta.
  var activeFilterCount: Int {
    query.muscles.count + query.equipment.count + query.categories.count + (query.favouritesOnly ? 1 : 0)
  }

  // O valor do botão dos filtros para o VoiceOver, pronto: "Nenhum filtro ligado", "Um filtro ligado",
  // "2 filtros ligados".
  var filtersValue: String { LibraryText.filtersOn(activeFilterCount, locale: locale) }

  // O revision do documento, lido pela tela para pedir o catálogo de novo depois de uma ação.
  var documentRevision: Int { revision() }

  @ObservationIgnored let engine: HexEngine
  @ObservationIgnored private let locale: Locale
  @ObservationIgnored private let debounce: Duration
  @ObservationIgnored private let revision: () -> Int
  @ObservationIgnored private let perform: (EngineAction) async throws -> ActionOutcome
  @ObservationIgnored private var summaries: [String: ExerciseSummary] = [:]
  @ObservationIgnored private var rows: [String: LibraryRow] = [:]
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  // Sobe a cada busca pedida; só a resposta da última vale.
  @ObservationIgnored private var searchGeneration = 0
  // Sobe a cada catálogo pedido; só o último vale.
  @ObservationIgnored private var catalogueGeneration = 0
  // O catálogo já chegou uma vez. Antes dele, uma busca pedida espera o load(), que busca o de agora.
  @ObservationIgnored private var hasCatalogue = false
  // As estrelas tocadas cuja ação ainda não chegou ao catálogo: o valor que a pessoa deixou, o toque
  // (para um segundo toque na mesma estrela valer sobre o primeiro) e, depois da ação, o catálogo pedido
  // por último até ali. Um catálogo pedido depois dele já traz a ação, e a estrela sai daqui.
  @ObservationIgnored private var pending: [String: Pending] = [:]
  @ObservationIgnored private var taps = 0

  private struct Pending {
    let on: Bool
    let tap: Int
    var doneAt: Int?
  }

  private static let logger = Logger(subsystem: "app.hexgym", category: "library")

  init(engine: HexEngine, locale: Locale = .current, debounce: Duration = LibraryModel.searchDelay,
       revision: @escaping () -> Int = { 0 }, perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.engine = engine
    self.locale = locale
    self.debounce = debounce
    self.revision = revision
    self.perform = perform
  }

  // O app de verdade: o motor e as ações do AppModel, e o revision dele.
  convenience init(app: AppModel) {
    self.init(engine: app.engine, revision: { app.revision }, perform: { try await app.perform($0) })
  }

  func summary(_ id: String) -> ExerciseSummary? { summaries[id] }

  // O estado do detalhe de um exercício (Task 10), com o mesmo motor, o mesmo idioma, as mesmas ações e o
  // mesmo revision da lista.
  func detail(_ id: String) -> ExerciseDetailScreen {
    ExerciseDetailScreen(id: id, engine: engine, locale: locale, revision: revision, perform: perform)
  }

  // O catálogo, as opções dos filtros e a busca de agora, sem esperar: é o que a lista pede quando
  // aparece. Volta com o resultado na tela. Um refresh() que começou enquanto o catálogo vinha fica
  // com a última palavra sobre as linhas, e a busca daqui sai do mesmo jeito: a resposta dela é
  // montada com as linhas de quando chega.
  func load() async {
    await readCatalogue()
    guard hasCatalogue else { return }
    search(after: .zero)
    await settled()
  }

  // O catálogo de novo, depois de uma ação: as linhas trocam (a estrela de um favorito), e a ordem
  // fica a de agora até a próxima busca. Antes da primeira busca (uma ação de outra tela enquanto a
  // lista abria), a busca sai daqui.
  func refresh() async {
    await readCatalogue()
    if phase == .ready {
      results = results.compactMap { rows[$0.id] }
    } else if hasCatalogue {
      search(after: .zero)
      await settled()
    }
  }

  // A busca ou um filtro mudou: a tela mostra a escolha na hora, e a busca sai depois da espera.
  func update(query next: LibraryQuery) {
    guard next != query else { return }
    query = next
    if hasCatalogue { search(after: debounce) }
  }

  // Todos os filtros desligados; o texto da busca fica.
  func clearFilters() {
    var next = LibraryQuery()
    next.query = query.query
    update(query: next)
  }

  // Espera a busca pedida por último responder, inclusive uma pedida enquanto se esperava.
  func settled() async {
    while let task = searchTask {
      await task.value
      if searchTask == task { return }
    }
  }

  // A estrela muda na hora; se a ação falhar, ela volta, e o erro vai para o log. Até o catálogo de
  // depois da ação chegar, a estrela fica como a pessoa deixou (pending).
  func toggleFavourite(_ id: String) async {
    guard let row = rows[id] else { return }
    taps += 1
    let tap = taps
    pending[id] = Pending(on: !row.favourite, tap: tap)
    replace(row.favouriting(!row.favourite))
    do {
      _ = try await perform(.toggleFavourite(id: id))
      if pending[id]?.tap == tap { pending[id]?.doneAt = catalogueGeneration }
    } catch {
      guard pending[id]?.tap == tap else { return }
      pending[id] = nil
      replace(row)
      Self.logger.error("não deu para favoritar (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
    }
  }

  // Lê o catálogo e as opções dos filtros e monta as linhas, fora da thread principal. Quando outro
  // catálogo foi pedido depois, este não vale, e fica o de lá.
  private func readCatalogue() async {
    catalogueGeneration += 1
    let mine = catalogueGeneration
    do {
      let language = Locale(identifier: try await engine.load().language)
      let list = try await engine.catalogue()
      let facets = try await engine.facets()
      let built = await LibraryBuild.make(list, facets: facets, text: LibraryText(locale: locale), language: language)
      guard mine == catalogueGeneration else { return }
      var fresh = built.rows
      for (id, star) in pending {
        if let done = star.doneAt, mine > done {
          pending[id] = nil
        } else {
          fresh[id] = fresh[id]?.favouriting(star.on)
        }
      }
      (summaries, rows, options) = (built.summaries, fresh, built.options)
      hasCatalogue = true
    } catch {
      guard mine == catalogueGeneration else { return }
      Self.logger.error("não deu para ler o catálogo (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      if phase == .loading { phase = .failed }
    }
  }

  // Pede a busca de agora depois da espera, cancelando a espera de antes. A resposta só vale se
  // nenhuma outra busca foi pedida enquanto o motor respondia.
  private func search(after delay: Duration) {
    searchTask?.cancel()
    searchGeneration += 1
    let mine = searchGeneration
    let asked = query
    searchTask = Task { [weak self] in
      if delay > .zero {
        do { try await Task.sleep(for: delay) } catch { return }
      }
      guard let self, mine == self.searchGeneration else { return }
      do {
        let ids = try await self.engine.search(asked)
        guard mine == self.searchGeneration else { return }
        self.results = ids.compactMap { self.rows[$0] }
        self.phase = .ready
      } catch {
        guard mine == self.searchGeneration else { return }
        Self.logger.error("não deu para buscar (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
        if self.phase == .loading { self.phase = .failed }
      }
    }
  }

  // Troca uma linha no dicionário e no resultado, no mesmo lugar.
  private func replace(_ row: LibraryRow) {
    rows[row.id] = row
    if let index = results.firstIndex(where: { $0.id == row.id }) { results[index] = row }
  }
}

// Uma linha da lista, pronta para a tela: o nome, o grupo principal e o equipamento ("Peito · Barra"),
// a estrela e o rótulo do VoiceOver, que junta os três e "favorito" ("Supino com barra, Peito, Barra,
// favorito"). O nome vai inteiro, sem corte, em qualquer tamanho.
nonisolated struct LibraryRow: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  // O grupo e o equipamento, separados por um ponto no meio; vazio quando o exercício não tem nenhum.
  let detail: String
  let favourite: Bool
  let spoken: String
  // O rótulo sem o "favorito", e a palavra, para a estrela trocar sem montar a linha de novo.
  private let spokenBase: String
  private let favouriteWord: String

  init(_ summary: ExerciseSummary, names: LibraryNames, text: LibraryText, language: Locale) {
    let name = LibraryNames.capitalized(summary.name, language: language)
    let group = summary.bp.isEmpty ? nil : LibraryNames.capitalized(names.bodyParts[summary.bp] ?? summary.bp, language: language)
    let equipment = summary.equipment.map { LibraryNames.capitalized(names.equipment[$0] ?? $0, language: language) }
    let parts = [group].compactMap { $0 } + equipment
    self.init(id: summary.id, name: name, detail: parts.joined(separator: LibraryNames.separator), favourite: summary.favourite,
              spokenBase: ([name] + parts).joined(separator: ", "), favouriteWord: text.favourite)
  }

  private init(id: String, name: String, detail: String, favourite: Bool, spokenBase: String, favouriteWord: String) {
    (self.id, self.name, self.detail, self.favourite) = (id, name, detail, favourite)
    (self.spokenBase, self.favouriteWord) = (spokenBase, favouriteWord)
    spoken = favourite ? "\(spokenBase), \(favouriteWord)" : spokenBase
  }

  // A mesma linha com a estrela trocada.
  func favouriting(_ on: Bool) -> LibraryRow {
    LibraryRow(id: id, name: name, detail: detail, favourite: on, spokenBase: spokenBase, favouriteWord: favouriteWord)
  }
}

// Os nomes do grupo principal (o bp) e do equipamento, do facets() do motor, no idioma dele.
nonisolated struct LibraryNames: Sendable {
  let bodyParts: [String: String]
  let equipment: [String: String]

  init(bodyParts: [String: String], equipment: [String: String]) {
    (self.bodyParts, self.equipment) = (bodyParts, equipment)
  }

  init(_ facets: LibraryFacets) {
    let named = { (list: [LibraryFacet]) in Dictionary(list.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }) }
    self.init(bodyParts: named(facets.bodyParts), equipment: named(facets.equipment))
  }

  // O separador do grupo e do equipamento na linha, e do equipamento e da categoria no detalhe: o espaço
  // antes do ponto não quebra, para o ponto nunca começar uma linha nos tamanhos grandes (QA do PR #113).
  static let separator = "\u{00A0}· "

  // A primeira letra em maiúscula, na regra do idioma dos nomes; o resto fica como veio.
  static func capitalized(_ text: String, language: Locale) -> String {
    guard let first = text.first else { return text }
    return String(first).uppercased(with: language) + text.dropFirst()
  }
}

// Os textos do app que as linhas usam, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct LibraryText: Sendable {
  let favourite: String

  @MainActor init(locale: Locale) {
    favourite = AppText.text("favorite", locale: locale)
  }

  // O valor do botão dos filtros para o VoiceOver.
  @MainActor static func filtersOn(_ count: Int, locale: Locale) -> String {
    switch count {
    case 0: AppText.text("No filters on", locale: locale)
    case 1: AppText.text("One filter on", locale: locale)
    default: String(format: AppText.text("%lld filters on", locale: locale), locale: locale, count)
    }
  }
}

// Uma opção da tela dos filtros: o id que vai na LibraryQuery e o nome pronto.
nonisolated struct LibraryFilterOption: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
}

// As opções da tela dos filtros, na ordem do motor: os grupos musculares, o equipamento (do mais comum
// ao menos) e as categorias.
nonisolated struct LibraryFilterOptions: Equatable, Sendable {
  let muscles, equipment, categories: [LibraryFilterOption]

  static let empty = LibraryFilterOptions(muscles: [], equipment: [], categories: [])
}

// O que o catálogo vira, montado fora da thread principal: 5.632 linhas custam alguns milissegundos,
// que na thread principal seriam quadros perdidos.
nonisolated enum LibraryBuild {
  struct Built: Sendable {
    let summaries: [String: ExerciseSummary]
    let rows: [String: LibraryRow]
    let options: LibraryFilterOptions
  }

  @concurrent static func make(_ list: [ExerciseSummary], facets: LibraryFacets, text: LibraryText, language: Locale) async -> Built {
    let names = LibraryNames(facets)
    var summaries: [String: ExerciseSummary] = [:], rows: [String: LibraryRow] = [:]
    summaries.reserveCapacity(list.count)
    rows.reserveCapacity(list.count)
    for summary in list {
      summaries[summary.id] = summary
      rows[summary.id] = LibraryRow(summary, names: names, text: text, language: language)
    }
    let option = { (facet: LibraryFacet) in LibraryFilterOption(id: facet.id, name: LibraryNames.capitalized(facet.name, language: language)) }
    let options = LibraryFilterOptions(
      muscles: facets.muscles.map(option), equipment: facets.equipment.map(option), categories: facets.categories.map(option))
    return Built(summaries: summaries, rows: rows, options: options)
  }
}
