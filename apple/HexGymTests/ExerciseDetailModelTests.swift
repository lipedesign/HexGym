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

  // Um detalhe montado à mão, no JSON que o motor manda. O translated é o par instructionsTranslated e
  // descriptionTranslated; nil deixa as duas chaves de fora, como um JSON de antes da issue #114.
  func detail(_ id: String, muscles: String, muscleNames: String = "{}", favourite: Bool = false, known: Bool = true,
              translated: (steps: Bool, description: Bool)? = (true, true), custom: Bool = false,
              description: String = "Um exercício de teste.") throws -> ExerciseDetail {
    let flags = translated.map { #""instructionsTranslated":\#($0.steps),"descriptionTranslated":\#($0.description),"# } ?? ""
    let json = #"{"id":"\#(id)","name":"exercício de teste","nameEnglish":"test exercise","bp":"chest","equipment":["barbell"],"category":"strength","muscles":\#(muscles),"muscleNames":\#(muscleNames),"instructions":["deite no banco.","empurre a barra."],"description":"\#(description)",\#(flags)"favourite":\#(favourite),"custom":\#(custom),"known":\#(known)}"#
    return try JSONDecoder().decode(ExerciseDetail.self, from: Data(json.utf8))
  }

  // O modelo de um detalhe montado à mão, sem regiões, no idioma do motor e no da tela.
  func model(_ detail: ExerciseDetail, language: Locale? = nil, screen: Locale? = nil) -> ExerciseDetailModel {
    ExerciseDetailModel(detail, regions: nil, catalog: catalog, names: names,
                        text: ExerciseDetailText(locale: screen ?? portuguese), language: language ?? portuguese)
  }

  // O inglês que a tela marca no texto, para o typesettingLanguage e a voz do VoiceOver.
  let english = Locale.Language(identifier: "en")

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

  // Issue #114: um aviso só, perto de "Como fazer", quando os passos estão em inglês e a tela não; ele
  // cobre a descrição também, quando ela está em inglês.
  @Test func theNoticeSitsAtTheStepsAndCoversTheDescriptionInEnglish() throws {
    let both = model(try detail("x5", muscles: "{}", translated: (false, false)))
    #expect(both.englishNotice == EnglishNotice(place: .steps, text: "Instruções e descrição em inglês"))
    let steps = model(try detail("x5", muscles: "{}", translated: (false, true)))
    #expect(steps.englishNotice == EnglishNotice(place: .steps, text: "Instruções em inglês"))
    // Sem descrição, o aviso fala só dos passos.
    let noDescription = model(try detail("x5", muscles: "{}", translated: (false, false), description: ""))
    #expect(noDescription.about == nil)
    #expect(noDescription.englishNotice == EnglishNotice(place: .steps, text: "Instruções em inglês"))
    // A tela em inglês, com o motor em alemão: o aviso no idioma da tela.
    let german = model(try detail("x5", muscles: "{}", translated: (false, false)), language: Locale(identifier: "de"),
                       screen: Locale(identifier: "en-US"))
    #expect(german.englishNotice == EnglishNotice(place: .steps, text: "Instructions and description in English"))
  }

  // Issue #114: com os passos traduzidos e a descrição em inglês (todo exercício em pt-BR, que não tem
  // descrições), o aviso vai para "Sobre o exercício".
  @Test func onlyTheDescriptionInEnglishMovesTheNoticeToTheDescription() throws {
    let model = model(try detail("x6", muscles: "{}", translated: (true, false)))
    #expect(model.englishNotice == EnglishNotice(place: .about, text: "Descrição em inglês"))
    #expect(model.steps.allSatisfy { $0.textLanguage == nil })
    #expect(model.aboutLanguage == english)
  }

  // Issue #114: nada de aviso nem de marca quando o texto está no idioma, quando o motor está em inglês,
  // num personalizado (o texto é da pessoa) e num JSON de antes da issue, sem as duas chaves.
  @Test func noNoticeWhenTheTextIsInTheLanguageOfTheScreen() throws {
    let english = Locale(identifier: "en-US")
    let cases = [
      model(try detail("x7", muscles: "{}", translated: (true, true))),
      model(try detail("x7", muscles: "{}", translated: (false, false)), language: english, screen: english),
      model(try detail("x7", muscles: "{}", translated: (false, false)), language: Locale(identifier: "en"), screen: portuguese),
      model(try detail("x7", muscles: "{}", translated: (false, false), custom: true)),
      model(try detail("x7", muscles: "{}", translated: nil)),
    ]
    for model in cases {
      #expect(model.englishNotice == nil)
      #expect(!model.steps.isEmpty && model.steps.allSatisfy { $0.textLanguage == nil })
      #expect(model.about != nil && model.aboutLanguage == nil)
    }
  }

  // Issue #114: o VoiceOver lê o passo em inglês com a voz do inglês, e o "Passo 1." no idioma da tela:
  // o rótulo é o spokenNumber, sem marca, e o texto, marcado com o inglês.
  @Test func theEnglishTextIsMarkedForVoiceOver() throws {
    let model = model(try detail("x8", muscles: "{}", translated: (false, false)))
    let first = try #require(model.steps.first)
    #expect(first.spoken == "Passo 1. Deite no banco.")
    #expect(first.spokenNumber == "Passo 1. ")
    #expect(first.text == "Deite no banco.")
    #expect(model.steps.map(\.textLanguage) == [english, english])
    #expect(model.aboutLanguage == english)
  }

  // Issue #114, com o motor de verdade em pt-BR: o supino tem os passos traduzidos e o aviso só na
  // descrição; o polichinelo cruzado (0264), os dois em inglês, com o aviso em "Como fazer". Com o
  // motor em inglês, nenhum aviso.
  @Test func theRealEngineWarnsAboutTheJumpingJacksStepsAndNotTheBenchPress() async throws {
    let engine = try await engine()
    let bench = try #require(await screen("0025", engine: engine).model)
    #expect(bench.englishNotice == EnglishNotice(place: .about, text: "Descrição em inglês"))
    #expect(!bench.steps.isEmpty && bench.steps.allSatisfy { $0.textLanguage == nil })
    #expect(bench.aboutLanguage == english)
    let jacks = try #require(await screen("0264", engine: engine).model)
    #expect(jacks.englishNotice == EnglishNotice(place: .steps, text: "Instruções e descrição em inglês"))
    #expect(!jacks.steps.isEmpty && jacks.steps.allSatisfy { $0.textLanguage == english })
    let inEnglish = HexEngine(language: "en")
    _ = try await inEnglish.load()
    _ = try await inEnglish.freshDocument()
    let englishJacks = try #require(await screen("0264", engine: inEnglish).model)
    #expect(englishJacks.englishNotice == nil)
    #expect(englishJacks.steps.allSatisfy { $0.textLanguage == nil } && englishJacks.aboutLanguage == nil)
  }
}
