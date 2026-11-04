// Os testes do idioma do motor: a escolha pelas línguas do aparelho (EngineLanguage.tag(for:)) e a
// carga do pacote no load().
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine --filter LanguageTests

import Foundation
import Testing
@testable import HexEngine

@Test(arguments: zip(
  [["pt-BR"], ["pt-PT"], ["de-CH"], ["fr-CA"], ["nl-NL", "es-MX"], ["nl"], [], ["zh-Hant-TW"], ["zh-Hans-CN"], ["zh-Hans-TW"]],
  ["pt-BR", "pt", "de-CH", "fr", "es", "en", "en", "zh-TW", "zh", "zh"]
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

  // O load() confere cada pacote contra o index.json, numa cópia da pasta langs: o index.json que
  // falta ou não lê é um erro que diz isso, e não um índice vazio; um pacote cujo texto não bate com
  // o sha256 do índice também.
  let langs = try #require(EngineLanguage.directory)
  let copy = FileManager.default.temporaryDirectory.appending(path: "hexgym-langs-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: copy) }
  let said = { (error: (any Error)?) in error.map { "\($0)" } ?? "" }
  #expect(said(#expect(throws: EngineError.self) { try EngineLanguage.readIndex(in: copy) }).contains("index.json"))
  try Data("{".utf8).write(to: copy.appending(path: "index.json"))
  #expect(said(#expect(throws: EngineError.self) { try EngineLanguage.readIndex(in: copy) }).contains("index.json"))
  try FileManager.default.copyItem(at: langs.appending(path: "en.json.deflate"), to: copy.appending(path: "en.json.deflate"))
  let index = try EngineLanguage.readIndex(in: langs)
  #expect(try EngineLanguage.packText("en", index: index, in: copy).hasPrefix("{"))
  let wrong = ["en": EngineLanguage.PackEntry(file: "en.json.deflate", sha256: String(repeating: "0", count: 64))]
  #expect(said(#expect(throws: EngineError.self) { try EngineLanguage.packText("en", index: wrong, in: copy) }).contains("sha256"))
}
