// Os testes do idioma do motor: a escolha pelas línguas do aparelho (EngineLanguage.tag(for:)) e a
// carga do pacote no load().
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine --filter LanguageTests

import Foundation
import Testing
@testable import HexEngine

@Test(arguments: zip(
  [["pt-BR"], ["pt-PT"], ["de-CH"], ["fr-CA"], ["nl-NL", "es-MX"], ["nl"], [], ["zh-Hant-TW"], ["zh-Hans-CN"]],
  ["pt-BR", "pt", "de-CH", "fr", "es", "en", "en", "zh-TW", "zh"]
))
func theTagFollowsTheDeviceLanguages(_ preferred: [String], _ expected: String) {
  #expect(EngineLanguage.tag(for: preferred) == expected)
}

@Test func loadsThePackOfTheDeviceLanguage() async throws {
  let engine = HexEngine(languages: ["pt-BR"])
  #expect(try await engine.load().language == "pt-BR")
  let modules = "HexEngine.__modules"
  let name = try await engine.evaluate(
    "\(modules)['frontend/src/lib/i18n-core.js'].exerciseNameFor(\(modules)['frontend/src/lib/exercises.js'].exerciseOf('0025'))")
  #expect(name == "supino com barra")
}
