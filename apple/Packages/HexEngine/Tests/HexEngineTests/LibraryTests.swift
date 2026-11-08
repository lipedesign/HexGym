// Os testes da biblioteca do motor (library.js) de ponta a ponta no JavaScriptCore, com o Codable dos
// modelos de Library.swift. A busca, os filtros e a ordem são do openGym e têm os testes em
// JS/library.test.mjs; aqui fica o caminho até o Swift.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine --filter LibraryTests

import Foundation
import Testing
@testable import HexEngine

@Test func theCatalogueDecodesEveryExerciseAndAnOldCustomOne() async throws {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  #expect(try await engine.catalogue().count == 5632)
  // Um personalizado antigo, sem categoria e sem equipamento, decodifica com category nil.
  try await engine.restore(Data(#"{"customEx":[{"id":"c1","n":"Remada do HexGym","bp":"back"}]}"#.utf8))
  let list = try await engine.catalogue()
  #expect(list.count == 5633)
  let custom = try #require(list.first)
  #expect(custom.id == "c1"); #expect(custom.category == nil); #expect(custom.equipment.isEmpty); #expect(custom.custom)
}

@Test func searchingSupinoFindsSomething() async throws {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  var query = LibraryQuery()
  query.query = "supino"
  let ids = try await engine.search(query)
  #expect(!ids.isEmpty); #expect(ids.contains("0025"))
}

@Test func theDetailOfTheBenchPressHasItsSteps() async throws {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  let detail = try await engine.exercise("0025")
  #expect(detail.known); #expect(!detail.instructions.isEmpty); #expect(detail.muscles["chest"] == 1)
}

// Issue #114: o detalhe diz se os passos e a descrição vieram do pacote do idioma. Em pt-BR, o supino
// tem os passos traduzidos e a descrição em inglês; o polichinelo cruzado (0264), os dois em inglês.
@Test func theDetailSaysWhetherTheStepsAndTheDescriptionCameTranslated() async throws {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  let bench = try await engine.exercise("0025")
  #expect(bench.instructionsTranslated == true); #expect(bench.descriptionTranslated == false)
  let jacks = try await engine.exercise("0264")
  #expect(jacks.instructionsTranslated == false); #expect(jacks.descriptionTranslated == false)
}
