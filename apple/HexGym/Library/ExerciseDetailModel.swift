// O detalhe do exercício sem tela (Task 10 do plano da fase 2, issue #97). O ExerciseDetailModel monta
// tudo o que a tela mostra e o que o VoiceOver diz, a partir do ExerciseDetail do motor e das regiões do
// HexBody: o nome, o equipamento e a categoria, as linhas do cartão "Músculos", os passos numerados e a
// descrição. O ExerciseDetailScreen é o estado da tela: lê o detalhe e as rotinas no motor, muda a
// estrela na hora e aplica o "Adicionar à rotina". A tela não calcula nada no body.
//
// O cartão "Músculos", até a Task 14, é uma lista: "Principal" com as regiões do primário e "Também
// trabalha" com as do secundário, na ordem do RegionCatalog, pelos nomes do name(of:). Uma lista vazia
// não aparece: os 206 exercícios de cardio do HexBody só têm o secundário, e nem a tela nem o VoiceOver
// mostram um "Principal" vazio (Notas da issue #97). Sem regiões (um exercício personalizado, ou o JSON
// do HexBody que não se leu), os grupos do muscles do motor: o "Principal" com os de maior peso e o
// "Também trabalha" com os outros que pesam alguma coisa, na ordem dos grupos do openGym.
//
// O texto falado separa as regiões por ponto e vírgula, porque há nomes com vírgula ("Tríceps, cabeças
// lateral e medial"): "Principal: <região>; <região>. Também trabalha: <região>; <região>."
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o texto falado do plano; sem regiões, o
// "Principal" com os grupos de maior peso (no catálogo, o peso 1; num personalizado espalhado pelo
// grupo do corpo, o maior deles); o JSON do HexBody que não se lê não para o app, cai nos grupos do
// motor e vai para o log, com o tipo do erro público e o detalhe privado.

import Foundation
import HexBody
import HexEngine
import Observation
import os

nonisolated struct ExerciseDetailModel: Equatable, Sendable {
  let id: String
  let known: Bool
  // Com a primeira letra em maiúscula, como na lista.
  let name: String
  // O equipamento e a categoria, separados por um ponto no meio; vazio quando não há nenhum.
  let subtitle: String
  // Só no desconhecido: a linha que diz que ele não está na biblioteca deste aparelho.
  let unknownNote: String?
  // As listas do cartão "Músculos", sem nenhuma vazia.
  let muscles: [MuscleSection]
  // O que o VoiceOver diz do cartão inteiro; vazio sem músculos.
  let musclesSpoken: String
  let steps: [ExerciseStep]
  let about: String?
  var favourite: Bool
  // O rótulo da estrela para o VoiceOver, com o que um toque faz: "Adicionar aos favoritos" ou "Tirar
  // dos favoritos". O botão da barra é do UIKit e não leva o traço de selecionado da SwiftUI, então o
  // estado vai no rótulo (QA do PR #113).
  var favouriteLabel: String { favourite ? removeFavouriteLabel : addFavouriteLabel }
  private let addFavouriteLabel: String
  private let removeFavouriteLabel: String

  init(_ detail: ExerciseDetail, regions: ExerciseRegions?, catalog: RegionCatalog?, names: ExerciseDetailNames,
       text: ExerciseDetailText, language: Locale) {
    id = detail.id
    known = detail.known
    name = LibraryNames.capitalized(detail.name, language: language)
    favourite = detail.favourite
    (addFavouriteLabel, removeFavouriteLabel) = (text.addFavourite, text.removeFavourite)
    guard detail.known else {
      (subtitle, unknownNote, muscles, musclesSpoken, steps, about) = ("", text.unknown, [], "", [], nil)
      return
    }
    unknownNote = nil
    let parts = detail.equipment.map { names.equipment[$0] ?? $0 } + [detail.category.map { names.categories[$0] ?? $0 }].compactMap { $0 }
    subtitle = parts.map { LibraryNames.capitalized($0, language: language) }.joined(separator: LibraryNames.separator)

    let lists: (primary: [String], secondary: [String])
    if let regions, let catalog, !(regions.primary.isEmpty && regions.secondary.isEmpty) {
      // Na ordem do catálogo, pelos nomes no idioma da tela.
      let ordered = { (list: [BodyRegion]) in
        catalog.regions.filter(list.contains).map { catalog.name(of: $0, locale: text.locale) }
      }
      lists = (ordered(regions.primary), ordered(regions.secondary))
    } else {
      lists = Self.groups(detail.muscles, engineNames: detail.muscleNames ?? [:], names: names, language: language)
    }
    var sections: [MuscleSection] = []
    if !lists.primary.isEmpty { sections.append(MuscleSection(kind: .primary, title: text.primary, names: lists.primary)) }
    if !lists.secondary.isEmpty { sections.append(MuscleSection(kind: .secondary, title: text.secondary, names: lists.secondary)) }
    muscles = sections
    musclesSpoken = sections.map { section in
      String(format: section.kind == .primary ? text.primarySpoken : text.secondarySpoken, locale: text.locale,
             section.names.joined(separator: "; "))
    }.joined(separator: " ")

    let lines = detail.instructions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    steps = lines.enumerated().map { index, step in
      let line = LibraryNames.capitalized(step, language: language)
      return ExerciseStep(number: index + 1, text: line,
                          spoken: String(format: text.step, locale: text.locale, index + 1) + ". " + line)
    }
    let description = detail.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    about = description.isEmpty ? nil : description
  }

  // Os grupos do motor: o "Principal" com os de maior peso, o "Também trabalha" com os outros acima de
  // 0, na ordem dos grupos do openGym. Um grupo fora dos 18 do facets() vem no fim.
  private static func groups(_ weights: [String: Double], engineNames: [String: String], names: ExerciseDetailNames,
                             language: Locale)
    -> (primary: [String], secondary: [String]) {
    let positive = weights.filter { $0.value > 0 }
    guard let top = positive.values.max() else { return ([], []) }
    let known = names.muscles.map(\.id)
    let order = known + positive.keys.filter { !known.contains($0) }.sorted()
    // Os nomes do facets() e, para um grupo fora dos 18 (o "cardiovascular system" do cardio), o do
    // muscleNames do motor. Só sem nenhum dos dois o id aparece.
    let named = names.muscles.reduce(into: engineNames) { $0[$1.id] = $1.name }
    let pick = { (keep: (Double) -> Bool) in
      order.filter { positive[$0].map(keep) ?? false }.map { LibraryNames.capitalized(named[$0] ?? $0, language: language) }
    }
    return (pick { $0 >= top }, pick { $0 < top })
  }
}

// Uma lista do cartão "Músculos".
nonisolated struct MuscleSection: Identifiable, Equatable, Sendable {
  enum Kind: Sendable { case primary, secondary }
  let kind: Kind
  let title: String
  let names: [String]
  var id: Kind { kind }
}

// Um passo de "Como fazer": o número, o texto e o que o VoiceOver diz ("Passo 1. Deite no banco.").
nonisolated struct ExerciseStep: Identifiable, Equatable, Sendable {
  let number: Int
  let text: String
  let spoken: String
  var id: Int { number }
}

// Os nomes dos grupos musculares (na ordem do motor), do equipamento e das categorias, do facets() do
// motor, no idioma dele.
nonisolated struct ExerciseDetailNames: Sendable {
  let muscles: [(id: String, name: String)]
  let equipment: [String: String]
  let categories: [String: String]

  init(muscles: [(id: String, name: String)], equipment: [String: String], categories: [String: String]) {
    (self.muscles, self.equipment, self.categories) = (muscles, equipment, categories)
  }

  init(_ facets: LibraryFacets) {
    let named = { (list: [LibraryFacet]) in Dictionary(list.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }) }
    self.init(muscles: facets.muscles.map { ($0.id, $0.name) }, equipment: named(facets.equipment), categories: named(facets.categories))
  }
}

// Os textos do app que o modelo usa, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct ExerciseDetailText: Sendable {
  let locale: Locale
  let primary, secondary, primarySpoken, secondarySpoken, step, unknown, addFavourite, removeFavourite: String

  @MainActor init(locale: Locale) {
    self.locale = locale
    primary = AppText.text("Primary", locale: locale)
    secondary = AppText.text("Also works", locale: locale)
    primarySpoken = AppText.text("Primary: %@.", locale: locale)
    secondarySpoken = AppText.text("Also works: %@.", locale: locale)
    step = AppText.text("Step %lld", locale: locale)
    unknown = AppText.text("This exercise isn't in the library on this device.", locale: locale)
    addFavourite = AppText.text("Add to favorites", locale: locale)
    removeFavourite = AppText.text("Remove from favorites", locale: locale)
  }
}

// Uma rotina no menu "Adicionar à rotina". A que já tem o exercício leva a marca da Apple no menu, e o
// VoiceOver diz que ela já tem: um toque põe o exercício de novo, num segundo slot, como o openGym
// deixa (achado do QA do PR #113, feito na Task 11).
struct RoutineChoice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let hasExercise: Bool
  // O nome e, na que já tem, "já tem este exercício".
  let spoken: String
}

// O estado da tela do detalhe: o modelo do exercício, as rotinas do menu e a confirmação da última vez
// que o exercício entrou numa rotina. Lê tudo no motor, fora da thread principal, e muda o documento
// só pelas ações (perform).
@Observable @MainActor final class ExerciseDetailScreen {
  enum Phase: Equatable { case loading, ready, failed }

  let id: String
  private(set) var phase = Phase.loading
  private(set) var model: ExerciseDetailModel?
  private(set) var routines: [RoutineChoice] = []
  // "Adicionado a <rotina>", ou o erro de quando não deu, até a próxima vez.
  private(set) var confirmation: String?
  // A última confirmação foi de sucesso (o símbolo da faixa).
  private(set) var confirmationSucceeded = false
  // Sobe a cada vez que o exercício entrou numa rotina: o gatilho do sensoryFeedback(.success).
  private(set) var confirmations = 0
  // Sobe a cada confirmação nova, de sucesso ou de erro: o gatilho do anúncio do VoiceOver e da faixa.
  private(set) var notices = 0

  // O revision do documento, lido pela tela para ler as rotinas de novo depois de uma ação.
  var documentRevision: Int { revision() }

  @ObservationIgnored private let engine: HexEngine
  @ObservationIgnored private let locale: Locale
  @ObservationIgnored private let regions: () throws -> RegionCatalog
  @ObservationIgnored private let revision: () -> Int
  @ObservationIgnored private let perform: (EngineAction) async throws -> ActionOutcome
  // Sobe a cada toque na estrela; só a falha do último toque desfaz.
  @ObservationIgnored private var taps = 0

  private static let logger = Logger(subsystem: "app.hexgym", category: "exercise")

  init(id: String, engine: HexEngine, locale: Locale = .current,
       regions: @escaping () throws -> RegionCatalog = { try RegionCatalog.loadBundled() },
       revision: @escaping () -> Int = { 0 }, perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.id = id
    self.engine = engine
    self.locale = locale
    self.regions = regions
    self.revision = revision
    self.perform = perform
  }

  // O detalhe, as regiões e as rotinas. Um erro do motor vai para o log, e a tela mostra que não abriu.
  func load() async {
    do {
      let language = Locale(identifier: try await engine.load().language)
      let detail = try await engine.exercise(id)
      let names = ExerciseDetailNames(try await engine.facets())
      let catalog = regionCatalog()
      var built = ExerciseDetailModel(detail, regions: catalog?.regions(for: id), catalog: catalog, names: names,
                                      text: ExerciseDetailText(locale: locale), language: language)
      // Uma estrela tocada enquanto o detalhe vinha fica como a pessoa deixou.
      if let model, taps > 0 { built.favourite = model.favourite }
      model = built
      phase = .ready
      await loadRoutines()
    } catch {
      Self.logger.error("não deu para abrir o exercício (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      if model == nil { phase = .failed }
    }
  }

  // As rotinas do menu, na ordem do documento.
  func loadRoutines() async {
    do {
      let already = AppText.text("%@, already has this exercise", locale: locale)
      routines = try await engine.routines().map { routine in
        let has = routine.slots.contains { $0.id == id }
        return RoutineChoice(id: routine.id, name: routine.name, hasExercise: has,
                             spoken: has ? String(format: already, locale: locale, routine.name) : routine.name)
      }
    } catch {
      Self.logger.error("não deu para ler as rotinas (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
    }
  }

  // A estrela muda na hora; se a ação falhar, ela volta, e o erro vai para o log. Como na lista.
  func toggleFavourite() async {
    guard let before = model?.favourite, model?.known == true else { return }
    taps += 1
    let tap = taps
    model?.favourite = !before
    do {
      _ = try await perform(.toggleFavourite(id: id))
    } catch {
      guard tap == taps else { return }
      model?.favourite = before
      Self.logger.error("não deu para favoritar (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
    }
  }

  // O exercício no fim da rotina, e a confirmação com o nome dela.
  func add(to routineID: String) async {
    do {
      _ = try await perform(.addExercises(routineID: routineID, exerciseIDs: [id], at: nil))
      await confirm(routineID)
    } catch {
      failAdd(error)
    }
  }

  // "Nova rotina": uma rotina nova, com o nome padrão do openGym ("Nova rotina"), e o exercício nela.
  func addToNewRoutine() async {
    do {
      let created = try await perform(.createRoutine(name: ""))
      guard let routineID = created.id else { throw EngineError.javaScript("routine.create sem id") }
      _ = try await perform(.addExercises(routineID: routineID, exerciseIDs: [id], at: nil))
      await confirm(routineID)
    } catch {
      failAdd(error)
    }
  }

  // As rotinas de novo, com o nome de agora, e "Adicionado a <rotina>".
  private func confirm(_ routineID: String) async {
    await loadRoutines()
    let name = routines.first { $0.id == routineID }?.name ?? ""
    confirmation = String(format: AppText.text("Added to %@", locale: locale), locale: locale, name)
    confirmationSucceeded = true
    confirmations += 1
    notices += 1
  }

  private func failAdd(_ error: any Error) {
    confirmation = AppText.text("Couldn't add the exercise.", locale: locale)
    confirmationSucceeded = false
    notices += 1
    Self.logger.error("não deu para pôr o exercício na rotina (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
  }

  // O catálogo das regiões, ou nil quando o JSON do HexBody não se lê: o cartão cai nos grupos do
  // motor, e o erro vai para o log (issue #97).
  private func regionCatalog() -> RegionCatalog? {
    do {
      return try regions()
    } catch {
      Self.logger.error("não deu para ler as regiões do HexBody (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      return nil
    }
  }
}
