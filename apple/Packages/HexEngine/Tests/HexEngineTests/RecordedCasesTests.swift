// Os casos gravados no Node (scripts/hexgym/record-engine-cases.mjs), rodados no JavaScriptCore
// pelo script do motor: o contrato da seção 8.2 do design doc e do Foco da revisão 5 do plano. Há um
// arquivo por fuso em Cases/. O HEXGYM_CASES diz qual, e o TZ do processo tem que ser o mesmo; o
// check.mjs põe os dois. Sem o HEXGYM_CASES, o teste fica pulado, para um swift test comum não
// depender do fuso da máquina.
//
//   TZ=Europe/Zurich HEXGYM_CASES=Europe/Zurich DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) \
//     swift test --package-path apple/Packages/HexEngine --filter RecordedCasesTests

import Foundation
import JavaScriptCore
import Testing
@testable import HexEngine

@Suite struct RecordedCasesTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["HEXGYM_CASES"] != nil))
  func theEngineAnswersWhatNodeRecordedInThisZone() async throws {
    let zone = try #require(ProcessInfo.processInfo.environment["HEXGYM_CASES"])
    let engine = try await loaded()
    // A prova de que o TZ chegou ao JavaScriptCore: sem ela, os casos rodariam no fuso da máquina.
    let seen = try await engine.evaluate("Intl.DateTimeFormat().resolvedOptions().timeZone")
    try #require(seen == zone, "o JavaScriptCore está no fuso \(seen), e os casos são de \(zone)")

    let name = zone.replacingOccurrences(of: "/", with: "_")
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Cases"),
                           "não há casos gravados para \(zone) em Cases/\(name).json")
    let text = try Data(contentsOf: url)
    let file = try #require(JSONSerialization.jsonObject(with: text) as? [String: Any])
    try #require(file["zone"] as? String == zone, "Cases/\(name).json é de \(file["zone"] ?? "nenhum fuso")")
    let cases = try #require(file["cases"] as? [[String: Any]])
    let arguments = try argumentTexts(text)
    try #require(!cases.isEmpty && arguments.count == cases.count)

    for (recorded, args) in zip(cases, arguments) {
      let label = recorded["name"] as? String ?? "(caso sem nome)"
      guard let fn = recorded["fn"] as? String, let result = recorded["result"] else {
        Issue.record("\(label): o caso gravado não tem fn ou result")
        continue
      }
      do {
        // A resposta numa constante antes do JSONSerialization: passada direto, o Swift 6.4 a recusa
        // como um Data que não é Sendable saindo do ator.
        let reply = try await engine.call(fn, json: Data(args.utf8))
        var answer = try JSONSerialization.jsonObject(with: reply)
        for path in recorded["ignore"] as? [String] ?? [] {
          answer = removing(path.split(separator: ".").map(String.init)[...], from: answer)
        }
        if let difference = difference(answer, result, at: "") { Issue.record("\(label): \(difference)") }
      } catch {
        Issue.record("\(label): o motor lançou \(error)")
      }
    }
  }
}

// O args de cada caso no texto em que o Node gravou, com as chaves na mesma ordem: o JSONSerialization
// do Swift não guarda a ordem das chaves, e há funções do lib que comparam objetos pelo
// JSON.stringify. Quem lê o arquivo aqui é um JSContext comum, sem o motor.
private func argumentTexts(_ file: Data) throws -> [String] {
  let context = try #require(JSContext())
  context.setObject(String(decoding: file, as: UTF8.self), forKeyedSubscript: "file" as NSString)
  let texts = context.evaluateScript("JSON.parse(file).cases.map(c => JSON.stringify(c.args))")?.toArray() as? [String]
  try #require(context.exception == nil, "o arquivo de casos não abriu no JavaScriptCore: \(String(describing: context.exception))")
  return try #require(texts)
}

// A resposta sem um caminho de ignore, como "returned.id". Um caminho que não está lá não muda nada.
private func removing(_ path: ArraySlice<String>, from value: Any) -> Any {
  guard let key = path.first, var object = value as? [String: Any], let inner = object[key] else { return value }
  if path.count == 1 { object.removeValue(forKey: key) } else { object[key] = removing(path.dropFirst(), from: inner) }
  return object
}

// A primeira diferença entre o que o JavaScriptCore respondeu (got) e o que o Node gravou (want),
// com o caminho dela, ou nil quando são iguais: a mesma estrutura, os mesmos textos e booleanos, e
// números iguais. Dois inteiros têm que ser iguais; com um número que não é inteiro, vale uma
// diferença relativa de até 1e-9, porque o Math.exp e o Math.pow podem diferir no último bit entre o
// V8 e o JavaScriptCore.
private func difference(_ got: Any, _ want: Any, at path: String) -> String? {
  let here = path.isEmpty ? "a resposta" : path
  switch (got, want) {
  case let (g as [String: Any], w as [String: Any]):
    if Set(g.keys) != Set(w.keys) {
      return "\(here) tem as chaves \(g.keys.sorted()) no JavaScriptCore e \(w.keys.sorted()) no Node"
    }
    for key in w.keys.sorted() {
      if let found = difference(g[key]!, w[key]!, at: path.isEmpty ? key : "\(path).\(key)") { return found }
    }
    return nil
  case let (g as [Any], w as [Any]):
    if g.count != w.count { return "\(here) tem \(g.count) itens no JavaScriptCore e \(w.count) no Node" }
    for (i, (x, y)) in zip(g, w).enumerated() {
      if let found = difference(x, y, at: path.isEmpty ? "\(i)" : "\(path).\(i)") { return found }
    }
    return nil
  case let (g as String, w as String):
    return g == w ? nil : "\(here) é \(String(reflecting: g)) no JavaScriptCore e \(String(reflecting: w)) no Node"
  case let (g as NSNumber, w as NSNumber):
    let (gb, wb) = (CFGetTypeID(g) == CFBooleanGetTypeID(), CFGetTypeID(w) == CFBooleanGetTypeID())
    if gb || wb {
      return gb && wb && g.boolValue == w.boolValue ? nil : "\(here) é \(g) no JavaScriptCore e \(w) no Node"
    }
    let (a, b) = (g.doubleValue, w.doubleValue)
    let same = a == a.rounded() && b == b.rounded() ? a == b : abs(a - b) <= 1e-9 * max(abs(a), abs(b))
    return same ? nil : "\(here) é \(a) no JavaScriptCore e \(b) no Node"
  case (is NSNull, is NSNull):
    return nil
  default:
    return "\(here) é \(got) no JavaScriptCore e \(want) no Node"
  }
}
