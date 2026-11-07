// Os testes do HexEngine, o motor do openGym num JSContext dentro de um ator (seção 8.2 do design
// doc). Os casos gravados no Node, que conferem o JavaScriptCore fuso por fuso, estão em
// RecordedCasesTests.swift.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine

import CryptoKit
import Foundation
import Testing
@testable import HexEngine

// O documento, ou a resposta de um call, lido como objeto JSON.
func object(_ data: Data) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// Um motor já carregado, na língua do aparelho pedida.
func loaded(_ language: String = "en") async throws -> HexEngine {
  let engine = HexEngine(language: language)
  _ = try await engine.load()
  return engine
}

// A versão do openGym, lida do frontend/package.json. Este arquivo fica em
// apple/Packages/HexEngine/Tests/HexEngineTests, seis pastas abaixo da raiz do repositório.
func openGymVersion() -> String {
  var root = URL(fileURLWithPath: #filePath)
  for _ in 0..<6 { root.deleteLastPathComponent() }
  let file = root.appending(path: "frontend/package.json")
  guard let data = try? Data(contentsOf: file),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let version = json["version"] as? String
  else { return "(sem versão em \(file.path))" }
  return version
}

@Test func loadsTheCatalogueAndTheOpenGymVersion() async throws {
  let info = try await HexEngine().load()
  #expect(info.exercises > 5000); #expect(info.openGymVersion == openGymVersion())
}
@Test func theBundledScriptMatchesItsSha256() throws {
  let (script, sha256) = try HexEngine.bundledScript()
  #expect(SHA256.hash(data: script).map { String(format: "%02x", $0) }.joined() + "\n" == sha256)
}
@Test func callsBeforeLoadFail() async {
  await #expect(throws: EngineError.notLoaded) { try await HexEngine().document() }
}
@Test func loadingTwiceKeepsTheSameContext() async throws {
  let e = try await loaded(); _ = try await e.evaluate("globalThis.marca = 7"); _ = try await e.load()
  #expect(try await e.evaluate("String(globalThis.marca)") == "7")
}
// Sem lang, em qualquer língua do aparelho: o HexGym nunca grava o idioma no documento (escolha 4 do
// plano da fase 2).
@Test func freshDocumentIsTheWebAppFirstRun() async throws {
  let d = try object(await loaded("pt-BR").freshDocument())
  #expect(d["lang"] == nil); #expect(d["langAuto"] as? Bool == true); #expect(d["gifSize"] as? String == "mini")
  #expect(try object(await loaded("ar-EG").freshDocument())["lang"] == nil)
}
@Test func restoreKeepsKeysTheAppDoesNotKnow() async throws {                      // Foco da revisão 2
  let e = try await loaded()
  try await e.restore(Data(#"{"chaveDoFuturo":{"x":[1,2]},"unit":"lb"}"#.utf8))
  let d = try object(await e.document())
  #expect(d["chaveDoFuturo"] as? NSDictionary == ["x": [1, 2]] as NSDictionary); #expect(d["unit"] as? String == "lb")
}
@Test func aHalfEmojiSurvivesTheEngine() async throws {                           // Foco da revisão 2
  let e = try await loaded()
  try await e.restore(Data(#"{"dayNotes":{"2026-10-31":{"text":"\ud83d"}}}"#.utf8))
  #expect(String(decoding: try await e.document(), as: UTF8.self).contains(#""text":"\ud83d""#))
}
@Test func eachDocumentBringsItsOwnCustomExercises() async throws {
  let e = try await loaded(), find = Data(#"["c1"]"#.utf8)
  func found() async throws -> [String: Any]? { try object(await e.call("frontend/src/lib/exercises.js#exerciseOf", json: find))["returned"] as? [String: Any] }
  try await e.restore(Data(#"{"customEx":[{"id":"c1","n":"Remada do HexGym","bp":"back"}]}"#.utf8))
  #expect(try await found()?["n"] as? String == "Remada do HexGym")
  try await e.restore(Data("{}".utf8))
  #expect(try await found()?["$undefined"] as? Bool == true)
}
@Test func anErrorInTheEngineIsThrownAndTheEngineKeepsWorking() async throws {     // Foco da revisão 3
  let e = try await loaded()
  for bad in ["[1]", "{", ""] {
    let error = await #expect(throws: EngineError.self) { try await e.restore(Data(bad.utf8)) }
    #expect(error.map { if case .javaScript(let m) = $0 { !m.isEmpty } else { false } } == true)
  }
  let missing = await #expect(throws: EngineError.self) { _ = try await e.call("frontend/src/lib/nope.js#x", json: Data("[]".utf8)) }
  #expect("\(String(describing: missing))".contains("nope.js#x"))
  try await e.restore(Data("{}".utf8)); #expect(try object(await e.document())["workouts"] != nil)
}
@Test func timersFireOnceAndCanBeCancelled() async throws {
  let e = try await loaded()
  _ = try await e.evaluate("globalThis.hits = 0; setTimeout(() => hits++, 20); clearTimeout(setTimeout(() => hits += 10, 20)); setTimeout(() => { throw new Error('timer') }, 5); 0")
  try await Task.sleep(for: .milliseconds(300))
  #expect(try await e.evaluate("String(hits)") == "1")
}
@Test func consoleAndStructuredCloneWork() async throws {
  #expect(try await loaded().evaluate("console.log('oi'); console.error(new Error('x')); JSON.stringify(structuredClone({ a: [1, { b: 2 }], d: new Date(0) }))")
          == #"{"a":[1,{"b":2}],"d":"1970-01-01T00:00:00.000Z"}"#)
}
@Test func webGlobalsTheEngineDoesNotHaveYet() async throws {
  // URL: cleanUrl, em media-refs.js. fetch: import-hevy.js. TextEncoder, TextDecoder e Blob: zip.js. Cada um tem issue na fase 5.
  #expect(try await loaded().evaluate("[typeof URL, typeof fetch, typeof TextEncoder, typeof TextDecoder, typeof Blob].join()")
          == "undefined,undefined,undefined,undefined,undefined")
}
