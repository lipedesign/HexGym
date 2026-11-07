// Os testes da biblioteca sem tela (Task 9 do plano da fase 2), com o motor de verdade e o documento do
// primeiro uso em português do Brasil: o catálogo inteiro, a busca "supino", a última busca que vale,
// a contagem dos filtros, o estado vazio e o rótulo do VoiceOver de uma linha. O teste do rótulo prende
// o Foco da revisão 5: um nome com 70 letras vai inteiro no rótulo, sem corte. O Foco da revisão 2 (a
// busca sem acento e nos dois idiomas) é do motor (library.test.mjs); aqui, a busca "supino" passa pelo
// modelo da tela.
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct LibraryModelTests {
  let portuguese = Locale(identifier: "pt-BR")

  // Um motor em pt-BR com o documento do primeiro uso, e a biblioteca carregada nele. Os testes não
  // favoritam nada, e a ação nunca roda.
  func loaded(debounce: Duration = LibraryModel.searchDelay) async throws -> (LibraryModel, HexEngine) {
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    _ = try await engine.freshDocument()
    let model = LibraryModel(engine: engine, locale: portuguese, debounce: debounce) { _ in
      Issue.record("nenhuma ação devia rodar")
      throw EngineError.notLoaded
    }
    await model.load()
    return (model, engine)
  }

  func text(_ value: String) -> LibraryQuery {
    var query = LibraryQuery()
    query.query = value
    return query
  }

  @Test func theCatalogueLoadsEveryExercise() async throws {
    let (model, _) = try await loaded()
    #expect(model.phase == .ready)
    #expect(model.results.count == 5632)
    #expect(model.summary("0025")?.id == "0025")
    #expect(model.summary("nao-existe") == nil)
    #expect(model.activeFilterCount == 0)
  }

  @Test func supinoFindsABenchPressFirst() async throws {
    let (model, _) = try await loaded()
    model.update(query: text("supino"))
    await model.settled()
    #expect(!model.results.isEmpty)
    let first = try #require(model.results.first)
    #expect(first.name.lowercased(with: portuguese).contains("supino"))
    #expect(model.summary(first.id)?.name.lowercased(with: portuguese).contains("supino") == true)
  }

  @Test func onlyTheLastOfTwoSearchesCounts() async throws {
    let (model, engine) = try await loaded()
    let supino = try await engine.search(text("supino"))
    let sup = try await engine.search(text("sup"))
    #expect(sup != supino)
    // Antes dos 150 ms: a busca de "sup" é cancelada e nem chega ao motor.
    model.update(query: text("sup"))
    model.update(query: text("supino"))
    await model.settled()
    #expect(model.query.query == "supino")
    #expect(model.results.map(\.id) == supino)
    // Sem a espera, as duas chegam ao motor, e a resposta de "sup" não vale depois que "supino" foi
    // pedida.
    let (quick, _) = try await loaded(debounce: .zero)
    quick.update(query: text("sup"))
    await Task.yield()
    quick.update(query: text("supino"))
    await quick.settled()
    #expect(quick.results.map(\.id) == supino)
  }

  @Test func aChestFilterCountsAsOne() async throws {
    let (model, _) = try await loaded()
    var query = LibraryQuery()
    query.muscles = ["chest"]
    model.update(query: query)
    #expect(model.activeFilterCount == 1)
    await model.settled()
    #expect(!model.results.isEmpty)
    #expect(model.results.count < 5632)
    // Todo resultado liga o peito: com crédito, ou na ligação sem crédito (peso 0) do openGym.
    #expect(model.results.allSatisfy { model.summary($0.id)?.muscles["chest"] != nil })
    // Mais um grupo, um equipamento e os favoritos: cada escolha conta uma.
    query.muscles.append("triceps")
    query.equipment = ["barbell"]
    query.favouritesOnly = true
    model.update(query: query)
    #expect(model.activeFilterCount == 4)
  }

  @Test func aSearchWithNoResultLeavesTheEmptyState() async throws {
    let (model, _) = try await loaded()
    #expect(!model.isEmpty)
    model.update(query: text("xqzwvk"))
    await model.settled()
    #expect(model.results.isEmpty)
    #expect(model.isEmpty)
    #expect(model.phase == .ready)
  }

  @Test func theVoiceOverLabelJoinsNameGroupEquipmentAndFavourite() throws {           // Foco da revisão 5
    let name = "supino inclinado com halteres e pegada neutra no banco de trinta graus"
    #expect(name.count == 70)
    let json = #"{"id":"x1","name":"\#(name)","bp":"chest","equipment":["dumbbell"],"category":"strength","muscles":{"chest":1},"favourite":true,"custom":false}"#
    let summary = try JSONDecoder().decode(ExerciseSummary.self, from: Data(json.utf8))
    let names = LibraryNames(bodyParts: ["chest": "peito"], equipment: ["dumbbell": "haltere"])
    let row = LibraryRow(summary, names: names, text: LibraryText(locale: portuguese), language: portuguese)
    #expect(row.name == "Supino inclinado com halteres e pegada neutra no banco de trinta graus")
    #expect(row.detail == "Peito · Haltere")
    #expect(row.spoken == "Supino inclinado com halteres e pegada neutra no banco de trinta graus, Peito, Haltere, favorito")
    // Sem favorito, o rótulo para no equipamento; em inglês, "favorite".
    #expect(row.favouriting(false).spoken == "Supino inclinado com halteres e pegada neutra no banco de trinta graus, Peito, Haltere")
    let english = LibraryRow(summary, names: names, text: LibraryText(locale: Locale(identifier: "en-US")), language: portuguese)
    #expect(english.spoken.hasSuffix(", Peito, Haltere, favorite"))
  }
}
