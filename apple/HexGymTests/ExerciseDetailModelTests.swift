// Os testes do detalhe do exercício sem tela (Task 10 do plano da fase 2, issue #97). Os quatro do
// passo 1 do plano: o supino (0025) em português do Brasil, com o "Principal" e o "Também trabalha" do
// exercise-regions.json; o texto do VoiceOver de uma fixture, na ordem do RegionCatalog; um exercício
// sem regiões, que cai nos grupos do motor; e o desconhecido. Os três das Notas da issue: um exercício
// de cardio do HexBody, que só tem o secundário, não mostra nem fala um "Principal" vazio; o JSON do
// HexBody que não se lê não derruba a tela, que cai nos grupos do motor; e o "Adicionar à rotina", com
// "Nova rotina" e uma rotina que já existe, e a confirmação "Adicionado a <rotina>".
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexBody
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct ExerciseDetailModelTests {
  let portuguese = Locale(identifier: "pt-BR")
  let catalog = RegionCatalog.bundled

  // Um motor em pt-BR com o documento do primeiro uso.
  func engine() async throws -> HexEngine {
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    _ = try await engine.freshDocument()
    return engine
  }

  // A tela de um exercício, carregada no motor, com as ações indo direto ao motor.
  func screen(_ id: String, engine: HexEngine,
              regions: @escaping () throws -> RegionCatalog = { try RegionCatalog.loadBundled() }) async -> ExerciseDetailScreen {
    let screen = ExerciseDetailScreen(id: id, engine: engine, locale: portuguese, regions: regions) { try await engine.apply($0) }
    await screen.load()
    return screen
  }

  func region(_ id: String) throws -> BodyRegion {
    try #require(catalog.regions.first { $0.id == id }, "a região \(id) existe")
  }

  // Um detalhe montado à mão, no JSON que o motor manda.
  func detail(_ id: String, muscles: String, muscleNames: String = "{}", favourite: Bool = false, known: Bool = true) throws -> ExerciseDetail {
    let json = #"{"id":"\#(id)","name":"exercício de teste","nameEnglish":"test exercise","bp":"chest","equipment":["barbell"],"category":"strength","muscles":\#(muscles),"muscleNames":\#(muscleNames),"instructions":["deite no banco.","empurre a barra."],"description":"Um exercício de teste.","favourite":\#(favourite),"custom":false,"known":\#(known)}"#
    return try JSONDecoder().decode(ExerciseDetail.self, from: Data(json.utf8))
  }

  let names = ExerciseDetailNames(
    muscles: [("deltoids", "ombros"), ("chest", "peito"), ("triceps", "tríceps"), ("abs", "abdômen")],
    equipment: ["barbell": "barra"], categories: ["strength": "força"])

  @Test func theBenchPressShowsTheChestAsPrimaryAndTheTricepsAsAlsoWorks() async throws {
    let screen = await screen("0025", engine: try await engine())
    let model = try #require(screen.model)
    let bench = try #require(catalog.regions(for: "0025"))
    #expect(model.known)
    #expect(model.name.lowercased(with: portuguese).contains("supino"))
    #expect(model.muscles.map(\.title) == ["Principal", "Também trabalha"])
    // As regiões do exercise-regions.json, na ordem do RegionCatalog, pelos nomes do name(of:).
    let ordered = { (list: [BodyRegion]) in
      self.catalog.regions.filter(list.contains).map { self.catalog.name(of: $0, locale: self.portuguese) }
    }
    #expect(model.muscles[0].names == ordered(bench.primary))
    #expect(model.muscles[1].names == ordered(bench.secondary))
    #expect(model.muscles[0].names.contains("Peito médio"))
    #expect(model.muscles[0].names.allSatisfy { $0.hasPrefix("Peito") })
    #expect(model.muscles[1].names.contains("Tríceps, cabeças lateral e medial"))
    #expect(model.musclesSpoken.hasPrefix("Principal: Peito médio; Peito baixo. Também trabalha: "))
    // O resto da tela: o equipamento e a categoria, os passos numerados e a descrição.
    #expect(model.subtitle == "Barra\u{00A0}· Força")
    #expect(!model.steps.isEmpty)
    #expect(model.steps.map(\.number) == Array(1...model.steps.count))
    #expect(model.steps[0].spoken.hasPrefix("Passo 1. "))
    #expect(model.about != nil)
    #expect(model.unknownNote == nil)
  }

  @Test func theVoiceOverTextFollowsTheCatalogOrder() throws {
    // De propósito fora da ordem: o modelo põe na ordem do RegionCatalog.
    let regions = ExerciseRegions(primary: [try region("chest"), try region("upperChest")],
                                  secondary: [try region("triceps"), try region("frontDeltoid")], emphasis: [])
    let model = ExerciseDetailModel(try detail("x1", muscles: #"{"chest":1}"#), regions: regions, catalog: catalog,
                                    names: names, text: ExerciseDetailText(locale: portuguese), language: portuguese)
    #expect(model.muscles.map(\.names) == [["Peito alto", "Peito médio"], ["Deltoide frontal", "Tríceps, cabeças lateral e medial"]])
    #expect(model.musclesSpoken == "Principal: Peito alto; Peito médio. Também trabalha: Deltoide frontal; Tríceps, cabeças lateral e medial.")
    // Em inglês, os mesmos rótulos do catálogo do app.
    let english = Locale(identifier: "en-US")
    let spokenEnglish = ExerciseDetailModel(try detail("x1", muscles: "{}"), regions: regions, catalog: catalog,
                                            names: names, text: ExerciseDetailText(locale: english), language: portuguese).musclesSpoken
    #expect(spokenEnglish == "Primary: Upper chest; Mid chest. Also works: Anterior deltoid; Triceps, lateral and medial heads.")
  }

  @Test func anExerciseWithoutRegionsFallsBackToTheEngineGroups() throws {
    // O peso 0 (a ligação sem crédito do openGym) fica de fora; os grupos vêm na ordem do motor.
    let model = ExerciseDetailModel(try detail("x2", muscles: #"{"triceps":0.4,"chest":1,"deltoids":0.4,"abs":0}"#),
                                    regions: nil, catalog: catalog, names: names,
                                    text: ExerciseDetailText(locale: portuguese), language: portuguese)
    #expect(model.muscles.map(\.title) == ["Principal", "Também trabalha"])
    #expect(model.muscles.map(\.names) == [["Peito"], ["Ombros", "Tríceps"]])
    #expect(model.musclesSpoken == "Principal: Peito. Também trabalha: Ombros; Tríceps.")
    #expect(model.name == "Exercício de teste")
    #expect(model.subtitle == "Barra\u{00A0}· Força")
    #expect(model.steps.map(\.text) == ["Deite no banco.", "Empurre a barra."])
  }

  @Test func anUnknownExerciseShowsTheUnknownScreen() async throws {
    let screen = await screen("nao-existe", engine: try await engine())
    let model = try #require(screen.model)
    #expect(!model.known)
    #expect(model.name == "Exercício desconhecido")
    #expect(model.unknownNote == "Este exercício não está na biblioteca deste aparelho.")
    #expect(model.muscles.isEmpty)
    #expect(model.musclesSpoken.isEmpty)
    #expect(model.steps.isEmpty)
    #expect(model.about == nil)
    #expect(model.subtitle.isEmpty)
  }

  // Notas da issue #97: os 206 exercícios de cardio do HexBody só têm o secundário.
  @Test func aCardioExerciseHasNoEmptyPrimary() async throws {
    let cardio = try #require(catalog.regions(for: "0264"))
    #expect(cardio.primary.isEmpty && !cardio.secondary.isEmpty)
    let screen = await screen("0264", engine: try await engine())
    let model = try #require(screen.model)
    #expect(model.muscles.map(\.title) == ["Também trabalha"])
    #expect(!model.muscles[0].names.isEmpty)
    #expect(model.musclesSpoken.hasPrefix("Também trabalha: "))
    #expect(!model.musclesSpoken.contains("Principal"))
  }

  // Notas da issue #97: sem o JSON do HexBody, o cartão cai nos grupos do motor, e a tela abre.
  @Test func anUnreadableRegionFileFallsBackToTheEngineGroups() async throws {
    let screen = await screen("0025", engine: try await engine(), regions: { try RegionCatalog.load(contentsOf: nil) })
    let model = try #require(screen.model)
    #expect(model.known)
    #expect(model.muscles.map(\.title) == ["Principal", "Também trabalha"])
    #expect(model.muscles[0].names == ["Peito"])
    #expect(model.musclesSpoken.hasPrefix("Principal: Peito. Também trabalha: "))
  }

  // QA do PR #113: o botão da barra do UIKit não leva o traço de selecionado, então o rótulo da estrela
  // diz o estado: o que um toque faz, com o texto do deslizar da lista para tirar.
  @Test func theStarLabelSaysWhatATapDoes() throws {
    var model = ExerciseDetailModel(try detail("x3", muscles: "{}"), regions: nil, catalog: catalog, names: names,
                                    text: ExerciseDetailText(locale: portuguese), language: portuguese)
    #expect(model.favouriteLabel == "Adicionar aos favoritos")
    model.favourite = true
    #expect(model.favouriteLabel == "Tirar dos favoritos")
    let on = ExerciseDetailModel(try detail("x3", muscles: "{}", favourite: true), regions: nil, catalog: catalog, names: names,
                                 text: ExerciseDetailText(locale: Locale(identifier: "en-US")), language: portuguese)
    #expect(on.favouriteLabel == "Remove from favorites")
  }

  // QA do PR #113: um grupo fora dos 18 do facets(), como o "cardiovascular system" do burpee (1160) e
  // de um personalizado de cardio do openGym, sai com o nome do motor, e não com o id em inglês.
  @Test func aGroupOutsideTheEighteenHasItsNameFromTheEngine() async throws {
    let fixture = ExerciseDetailModel(
      try detail("x4", muscles: #"{"cardiovascular system":1,"chest":0.4}"#,
                 muscleNames: #"{"cardiovascular system":"sistema cardiovascular","chest":"Peito"}"#),
      regions: nil, catalog: catalog, names: names, text: ExerciseDetailText(locale: portuguese), language: portuguese)
    #expect(fixture.muscles.map(\.names) == [["Sistema cardiovascular"], ["Peito"]])
    // O burpee de verdade, sem o JSON do HexBody, no caminho dos grupos do motor.
    let burpee = await screen("1160", engine: try await engine(), regions: { try RegionCatalog.load(contentsOf: nil) })
    let model = try #require(burpee.model)
    #expect(model.muscles.first?.names == ["Sistema cardiovascular"])
    #expect(!model.musclesSpoken.lowercased().contains("cardiovascular system"))
  }

  @Test func addToRoutineAddsTheExerciseAndConfirms() async throws {
    let engine = try await engine()
    let screen = await screen("0025", engine: engine)
    #expect(screen.routines.isEmpty)
    // "Nova rotina": cria a rotina com o nome padrão do openGym e põe o exercício nela.
    await screen.addToNewRoutine()
    let created = try #require(try await engine.routines().first)
    #expect(created.name == "Nova rotina")
    #expect(created.slots.map(\.id) == ["0025"])
    #expect(screen.confirmation == "Adicionado a Nova rotina")
    #expect(screen.confirmations == 1)
    #expect(screen.routines.map(\.id) == [created.id])
    // Uma rotina que já existe ganha o exercício no fim.
    await screen.add(to: created.id)
    #expect(try await engine.routines().first?.slots.map(\.id) == ["0025", "0025"])
    #expect(screen.confirmations == 2)
    // A estrela muda na hora e vai ao motor.
    #expect(screen.model?.favourite == false)
    await screen.toggleFavourite()
    #expect(screen.model?.favourite == true)
    #expect(try await engine.exercise("0025").favourite)
  }
}
