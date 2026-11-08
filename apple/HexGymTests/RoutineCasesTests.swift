// A prova de paridade das duas regras do openGym que o editor de rotina copiou para o Swift (issue
// #116): o passo da carga do SlotDraft contra o addStep de frontend/src/lib/progression.js, e o mapa
// dos emojis antigos do RoutineGlyph contra o LEGACY e o glyphOf de frontend/src/lib/glyphs.js. Os
// casos saem do código do openGym no Node, pelo scripts/hexgym/record-routine-cases.mjs, e ficam em
// RoutineCases.json, nesta pasta: ela é um grupo sincronizado do Xcode, então o arquivo entra no
// bundle deste alvo sozinho. O --check do gravador, no check.mjs, falha quando o openGym muda e o
// arquivo fica velho; este teste falha quando a cópia em Swift não bate com o arquivo.
//
// Para regravar: node scripts/hexgym/record-routine-cases.mjs
//
// O alvo roda dentro do app (TEST_HOST).
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test \
//     -only-testing:HexGymTests/RoutineCasesTests

import Foundation
import HexDesign
import HexEngine
import Testing
@testable import HexGym

// O arquivo gravado. Cada caso do addStep é [carga, um passo para cima, um passo para baixo].
private nonisolated struct RoutineCases: Decodable {
  struct Group: Decodable { let unit: String, increment: Double, cases: [[Double]] }
  struct Legacy: Decodable { let emoji: String, codes: String, key: String }
  struct Glyph: Decodable { let input: String, codes: String, key: String }
  let addStep: [Group]
  let legacy: [Legacy]
  let glyphOf: [Glyph]
}

// Uma classe deste alvo, para achar o bundle dos testes: o Bundle.main é o do app.
private nonisolated final class CasesBundle {}

@Suite @MainActor struct RoutineCasesTests {
  // No máximo tantas diferenças por teste no relatório, para uma cópia toda errada não encher a tela.
  static let shown = 10

  fileprivate func cases() throws -> RoutineCases {
    let url = try #require(Bundle(for: CasesBundle.self).url(forResource: "RoutineCases", withExtension: "json"),
                           "RoutineCases.json não está no bundle dos testes. Rode: node scripts/hexgym/record-routine-cases.mjs")
    return try JSONDecoder().decode(RoutineCases.self, from: Data(contentsOf: url))
  }

  // O texto dos pontos de código, como o gravador escreve: hexadecimal maiúsculo, separado por espaço.
  static func codes(_ text: String) -> String {
    text.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: " ")
  }

  // O texto de volta dos pontos de código.
  static func text(_ codes: String) throws -> String {
    var text = ""
    for code in codes.split(separator: " ") {
      let scalar = try #require(UInt32(code, radix: 16).flatMap(Unicode.Scalar.init), "ponto de código \(code)")
      text.unicodeScalars.append(scalar)
    }
    return text
  }

  // Um rascunho com esta carga e este incremento, pelo SlotSummary que o motor manda.
  static func draft(_ load: Double, _ increment: Double, unit: WeightUnit) throws -> SlotDraft {
    let json = #"{"id":"0025","name":"x","known":true,"setsReps":"3×10","increment":\#(increment),"repStep":1,"weight":\#(load)}"#
    return SlotDraft(try JSONDecoder().decode(SlotSummary.self, from: Data(json.utf8)), unit: unit)
  }

  @Test func theLoadStepIsOpenGymsAddStep() throws {
    let file = try cases()
    #expect(Set(file.addStep.map(\.unit)) == ["kg", "lb"])
    var count = 0, wrong: [String] = []
    for group in file.addStep {
      for row in group.cases {
        try #require(row.count == 3, "um caso do addStep de \(group.unit) \(group.increment) sem as três cargas")
        let (load, up, down) = (row[0], row[1], row[2])
        let gotUp = SlotDraft.addStep(load, group.increment, group.increment)
        let gotDown = SlotDraft.addStep(load, -group.increment, group.increment)
        if gotUp != up { wrong.append("\(group.unit) \(group.increment): \(load) para cima deu \(gotUp), e o openGym \(up)") }
        if gotDown != down { wrong.append("\(group.unit) \(group.increment): \(load) para baixo deu \(gotDown), e o openGym \(down)") }
        count += 2
      }
    }
    #expect(count > 10_000, "só \(count) casos do addStep")
    #expect(wrong.isEmpty, "\(wrong.count) de \(count) casos diferentes do openGym:\n\(wrong.prefix(Self.shown).joined(separator: "\n"))")
  }

  // O toque do editor é o addStep e, depois, o limite de 0 a 1.000 do slot.update; no limite, ele não
  // manda nada.
  @Test func aLoadTapIsTheAddStepWithinTheLimit() throws {
    let file = try cases()
    var count = 0, wrong: [String] = []
    for group in file.addStep {
      let unit = try #require(WeightUnit(rawValue: group.unit))
      for row in group.cases {
        let load = row[0]
        for (direction, step) in [(StepDirection.up, row[1]), (.down, row[2])] {
          var draft = try Self.draft(load, group.increment, unit: unit)
          try #require(draft.weight == load && draft.increment == group.increment)
          let expected = min(max(step, SlotDraft.loadRange.lowerBound), SlotDraft.loadRange.upperBound)
          let fields = draft.stepLoad(direction)
          let ok = expected == load ? fields == nil && draft.weight == load : fields == SlotFields(weight: expected) && draft.weight == expected
          if !ok { wrong.append("\(group.unit) \(group.increment): \(load), \(direction), deu \(draft.weight), e o esperado era \(expected)") }
          count += 1
        }
      }
    }
    #expect(wrong.isEmpty, "\(wrong.count) de \(count) toques errados:\n\(wrong.prefix(Self.shown).joined(separator: "\n"))")
  }

  @Test func theOldEmojiMapIsOpenGyms() throws {
    let file = try cases()
    #expect(file.legacy.count == 42)
    for entry in file.legacy {
      #expect(Self.codes(entry.emoji) == entry.codes, "o emoji de \(entry.codes) no arquivo")
      let emoji = try Self.text(entry.codes)
      #expect(RoutineGlyph.legacy[emoji] == entry.key, "\(entry.emoji) (\(entry.codes))")
    }
    // Nenhuma entrada a mais no Swift, comparadas pelos pontos de código, e não pela igualdade do String.
    #expect(Set(RoutineGlyph.legacy.keys.map(Self.codes)) == Set(file.legacy.map(\.codes)))
  }

  @Test func anOldEmojiGetsTheKeyOfOpenGymsGlyphOf() throws {
    let file = try cases()
    #expect(file.glyphOf.count > file.legacy.count)
    for entry in file.glyphOf {
      #expect(Self.codes(entry.input) == entry.codes, "a entrada de \(entry.codes) no arquivo")
      let input = try Self.text(entry.codes)
      #expect(RoutineGlyph.key(for: input) == entry.key, "\(entry.input) (\(entry.codes))")
    }
  }
}
