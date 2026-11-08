// Os testes das ações sobre o documento (actions.js) do lado do Swift: o JSON que cada EngineAction
// vira, e o caminho de ponta a ponta no JavaScriptCore com o Codable dos modelos de Actions.swift. As
// regras de cada ação têm os testes em JS/actions.test.mjs.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine --filter ActionsTests

import Foundation
import Testing
@testable import HexEngine

// Um texto JSON lido de volta como objeto, para comparar sem depender da ordem das chaves.
private func object(_ text: Data) throws -> NSDictionary {
  try #require(JSONSerialization.jsonObject(with: text) as? NSDictionary)
}

@Test func eachActionEncodesToTheJSONTheEngineExpects() throws {
  let snapshot = try RoutineSnapshot(.object(["routine": .object(["id": .string("r1")]), "index": .number(0)]))
  let cases: [(EngineAction, [String: Any])] = [
    (.createRoutine(name: "Peito"), ["type": "routine.create", "name": "Peito"]),
    (.renameRoutine(id: "r1", name: "A"), ["type": "routine.rename", "id": "r1", "name": "A"]),
    (.setRoutineGlyph(id: "r1", glyph: "heart"), ["type": "routine.glyph", "id": "r1", "glyph": "heart"]),
    (.duplicateRoutine(id: "r1"), ["type": "routine.duplicate", "id": "r1"]),
    (.moveRoutine(from: 0, to: 2), ["type": "routine.move", "from": 0, "to": 2]),
    (.deleteRoutine(id: "r1"), ["type": "routine.delete", "id": "r1"]),
    (.restoreRoutine(snapshot: snapshot), ["type": "routine.restore", "snapshot": ["routine": ["id": "r1"], "index": 0]]),
    (.addExercises(routineID: "r1", exerciseIDs: ["0025"], at: nil), ["type": "slot.add", "routineId": "r1", "exerciseIds": ["0025"]]),
    (.addExercises(routineID: "r1", exerciseIDs: ["0025", "0047"], at: 1),
     ["type": "slot.add", "routineId": "r1", "exerciseIds": ["0025", "0047"], "at": 1]),
    (.removeSlot(routineID: "r1", index: 2), ["type": "slot.remove", "routineId": "r1", "index": 2]),
    (.moveSlot(routineID: "r1", from: 0, to: 1), ["type": "slot.move", "routineId": "r1", "from": 0, "to": 1]),
    (.replaceSlot(routineID: "r1", index: 0, exerciseID: "0047"), ["type": "slot.replace", "routineId": "r1", "index": 0, "exerciseId": "0047"]),
    (.superset(routineID: "r1", index: 0), ["type": "slot.superset", "routineId": "r1", "index": 0]),
    (.unsuperset(routineID: "r1", index: 1), ["type": "slot.unsuperset", "routineId": "r1", "index": 1]),
    (.updateSlot(routineID: "r1", index: 0, fields: SlotFields(sets: 4, weight: 62.5, note: "banco 4")),
     ["type": "slot.update", "routineId": "r1", "index": 0, "fields": ["sets": 4, "weight": 62.5, "note": "banco 4"]]),
    (.setWeekDay(day: 1, routineIDs: ["r1"]), ["type": "week.set", "day": 1, "routineIds": ["r1"]]),
    (.loadStarterPlan(id: "ppl"), ["type": "plan.starter", "planId": "ppl"]),
    (.setSetting(.unit("lb")), ["type": "settings.set", "key": "unit", "value": "lb"]),
    (.setSetting(.body("female")), ["type": "settings.set", "key": "body", "value": "female"]),
    (.setSetting(.weekStart(0)), ["type": "settings.set", "key": "weekStart", "value": 0]),
    (.setSetting(.restSec(120)), ["type": "settings.set", "key": "restSec", "value": 120]),
    (.setSetting(.effort("rir")), ["type": "settings.set", "key": "effort", "value": "rir"]),
    (.toggleFavourite(id: "0025"), ["type": "favourite.toggle", "id": "0025"]),
  ]
  // O mesmo pelo Encodable e pelo texto que o apply manda.
  for (action, expected) in cases {
    #expect(try object(JSONEncoder().encode(action)) == expected as NSDictionary, "\(action)")
    #expect(try object(action.text()) == expected as NSDictionary, "\(action)")
  }
  // O índice do snapshot volta inteiro, sem ".0": o restoreRoutine confere com Number.isInteger.
  let text = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
  #expect(text.contains(#""index":0"#))
}

@Test func theSnapshotGoesBackToTheEngineAsTheTextItCameIn() throws {  // issue #117
  // Uma resposta do apply com as chaves fora da ordem alfabética, um número com casas, um texto com
  // escapes e espaços entre as partes: o snapshot sai e volta nos mesmos bytes.
  let snapshot = #"{"routine":{"name":"A \"b\" \\ }","id":"r1","ex":[{"weight":62.5,"id":"0025"}]},"index":1,"week":{"4":0,"1":2},"marks":{}}"#
  let response = Data(#"{"changed":true,"result":{ "id" : "x}" , "snapshot" : \#(snapshot) }}"#.utf8)
  let outcome = try JSONDecoder().decode(ActionOutcome.self, from: response)
  let kept = try RoutineSnapshot(response: response)
  #expect(String(decoding: kept.json, as: UTF8.self) == snapshot)
  #expect(outcome.snapshot != nil)
  let text = String(decoding: try EngineAction.restoreRoutine(snapshot: kept).text(), as: UTF8.self)
  #expect(text == #"{"type":"routine.restore","snapshot":"# + snapshot + "}")
  // Sem snapshot, ou com um que não é objeto, é erro do motor.
  #expect(throws: EngineError.self) { try RoutineSnapshot(response: Data(#"{"changed":true,"result":{}}"#.utf8)) }
  #expect(throws: EngineError.self) { try RoutineSnapshot(response: Data(#"{"changed":true,"result":{"snapshot":[1]}}"#.utf8)) }
}

@Test func theReaderFindsAValueByItsPathWithoutDecodingTheText() {  // issue #117
  let text = Data(#"{"a":[1,{"b":"]"}],"c\u0061t":{"d":-1.5e3,"e":null},"f":"\\","g":{}}"#.utf8)
  let value = { (path: [String]) in JSONText.value(at: path, in: text).map { String(decoding: $0, as: UTF8.self) } }
  #expect(value(["a"]) == #"[1,{"b":"]"}]"#)
  #expect(value(["cat"]) == #"{"d":-1.5e3,"e":null}"#)  // a chave com escape é lida como "cat"
  #expect(value(["cat", "d"]) == "-1.5e3")
  #expect(value(["cat", "e"]) == "null")
  #expect(value(["f"]) == #""\\""#)
  #expect(value(["g"]) == "{}")
  #expect(value([]) == String(decoding: text, as: UTF8.self))
  // Uma chave que falta, um caminho que passa por algo que não é objeto e um texto cortado.
  #expect(value(["x"]) == nil)
  #expect(value(["g", "x"]) == nil)
  #expect(value(["a", "b"]) == nil)
  #expect(JSONText.value(at: ["b"], in: Data(#"{"a":"sem fim"#.utf8)) == nil)
  #expect(JSONText.value(at: ["a"], in: Data(#"{"a":[1,2"#.utf8)) == nil)
  // A chave é comparada pelos códigos, como o JavaScript, e não pela equivalência do Unicode: o "é"
  // decomposto (e e U+0301) e o composto (U+00E9) são duas chaves.
  let accents = Data("{\"e\u{301}\":13,\"\u{E9}\":14}".utf8)
  #expect(JSONText.value(at: ["\u{E9}"], in: accents).map { String(decoding: $0, as: UTF8.self) } == "14")
  #expect(JSONText.value(at: ["e\u{301}"], in: accents).map { String(decoding: $0, as: UTF8.self) } == "13")
  // Até 512 níveis, contando o objeto do topo, como o JSONDecoder; mais que isso dá nil.
  let deep = { (lists: Int) in Data(("{\"a\":" + String(repeating: "[", count: lists) + String(repeating: "]", count: lists) + "}").utf8) }
  #expect(JSONText.value(at: ["a"], in: deep(511))?.count == 1022)
  #expect(JSONText.value(at: ["a"], in: deep(512)) == nil)
}

@Test func aRoutineCreatedInTheEngineReadsBackAndSurvivesDeleteAndUndo() async throws {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  let created = try await engine.apply(.createRoutine(name: ""))
  #expect(created.changed)
  let id = try #require(created.id)
  _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0025"], at: nil))
  _ = try await engine.apply(.setWeekDay(day: 1, routineIDs: [id]))
  let routine = try #require(try await engine.routines().first)
  #expect(routine.id == id); #expect(routine.name == "Nova rotina"); #expect(routine.glyph == "figureStrength")
  #expect(routine.slots.map(\.id) == ["0025"]); #expect(routine.slots[0].known); #expect(routine.days == [1])
  #expect(routine.muscles["chest"] ?? 0 > 0)
  // Uma ação inválida volta como o TypeError do motor, e nada muda.
  await #expect(throws: EngineError.self) { try await engine.apply(.setSetting(.restSec(5000))) }
  #expect(try await engine.settings() == DocumentSettings(unit: "kg", body: "male", weekStart: 1, restSec: 90, effort: "none"))
  // O snapshot vai e volta pelo Swift como veio, e o desfazer devolve a rotina e o dia.
  let deleted = try await engine.apply(.deleteRoutine(id: id))
  let snapshot = try #require(deleted.snapshot)
  #expect(try await engine.routines().isEmpty)
  #expect(try await engine.apply(.restoreRoutine(snapshot: snapshot)).changed)
  #expect(try await engine.week().days.first == WeekPlan.Day(day: 1, routineIds: [id]))
  #expect(try await engine.starterPlans().map(\.id) == ["ppl", "upper-lower", "full-body", "5x5"])
}

// O texto do documento como um literal de JS, para o JSON.parse do próprio motor.
private func literal(_ document: Data) throws -> String {
  String(decoding: try JSONEncoder().encode(String(decoding: document, as: UTF8.self)), as: UTF8.self)
}

// Um campo do topo do documento, no texto que o JSON.stringify do motor escreve. O JSON.parse e o
// JSON.stringify do JavaScriptCore guardam a ordem das chaves, e assim o texto sai igual ao trecho
// do documento, byte a byte, sem passar por um dicionário do Swift.
private func field(_ key: String, of document: Data, in engine: HexEngine) async throws -> String {
  let name = String(decoding: try JSONEncoder().encode(key), as: UTF8.self)
  return try await engine.evaluate("JSON.stringify(JSON.parse(\(try literal(document)))[\(name)])")
}

// As chaves do topo do documento, na ordem do texto.
private func keys(of document: Data, in engine: HexEngine) async throws -> [String] {
  try await engine.evaluate("JSON.stringify(Object.keys(JSON.parse(\(try literal(document)))))")
    .data(using: .utf8).map { try JSONDecoder().decode([String].self, from: $0) } ?? []
}

// Os carimbos do topo que o desfazer do openGym também muda, e por isso ficam fora da comparação.
// O _ts é a hora da última mudança do documento (stampChange). O edited guarda a hora de cada dia da
// semana que a remoção e a volta mexeram (stampEdits), e o undone, os dias que o markUndone marcou
// como desfeitos. O deleted leva a remoção da rotina e, depois do desfazer, a volta dela
// (stampDeletions).
private let undoStamps: Set<String> = ["_ts", "edited", "undone", "deleted"]

@Test func deleteAndUndoGiveBackTheRoutinesAndTheWeekByteForByte() async throws {  // issue #117
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  // Três rotinas, e a do meio, a que é apagada, com muitas chaves: o glyph, exercícios com séries,
  // carga, nota, tempo e superset, e dois dias da semana, num deles entre as outras duas.
  var ids: [String] = []
  for name in ["Peito", "Costas", "Pernas"] {
    ids.append(try #require(try await engine.apply(.createRoutine(name: name)).id))
  }
  let id = ids[1]
  _ = try await engine.apply(.setRoutineGlyph(id: id, glyph: "heart"))
  _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0025", "0047", "0652"], at: nil))
  _ = try await engine.apply(.updateSlot(routineID: id, index: 0, fields: SlotFields(sets: 4, reps: 8, repsMin: 6, weight: 62.5, note: "banco 4")))
  _ = try await engine.apply(.updateSlot(routineID: id, index: 2, fields: SlotFields(mode: "time")))
  _ = try await engine.apply(.superset(routineID: id, index: 0))
  _ = try await engine.apply(.setWeekDay(day: 1, routineIDs: [ids[0], id, ids[2]]))
  _ = try await engine.apply(.setWeekDay(day: 4, routineIDs: [id]))
  let before = try await engine.document()

  let deleted = try await engine.apply(.deleteRoutine(id: id))
  #expect(try await engine.routines().map(\.id) == [ids[0], ids[2]])
  #expect(try await engine.apply(.restoreRoutine(snapshot: try #require(deleted.snapshot))).changed)
  let after = try await engine.document()

  // O routines e o week, os dois que o desfazer põe de volta, e depois o resto do documento, que
  // também fica igual, menos os carimbos do desfazer.
  let rest = try await keys(of: before, in: engine).filter { !undoStamps.contains($0) }
  #expect(rest.contains("routines") && rest.contains("week"))
  #expect(try await keys(of: after, in: engine).filter { !undoStamps.contains($0) } == rest)
  for key in ["routines", "week"] + rest.filter({ $0 != "routines" && $0 != "week" }) {
    let was = try await field(key, of: before, in: engine), now = try await field(key, of: after, in: engine)
    #expect(now == was, "\(key)")
  }
}
