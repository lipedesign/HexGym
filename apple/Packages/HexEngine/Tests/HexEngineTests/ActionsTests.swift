// Os testes das ações sobre o documento (actions.js) do lado do Swift: o JSON que cada EngineAction
// vira, e o caminho de ponta a ponta no JavaScriptCore com o Codable dos modelos de Actions.swift. As
// regras de cada ação têm os testes em JS/actions.test.mjs.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine --filter ActionsTests

import Foundation
import Testing
@testable import HexEngine

// O JSON de cada ação, lido de volta como objeto, para comparar sem depender da ordem das chaves.
private func json(_ action: EngineAction) throws -> NSDictionary {
  try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(action)) as? NSDictionary)
}

@Test func eachActionEncodesToTheJSONTheEngineExpects() throws {
  let snapshot = RoutineSnapshot(.object(["routine": .object(["id": .string("r1")]), "index": .number(0)]))
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
  for (action, expected) in cases {
    #expect(try json(action) == expected as NSDictionary, "\(action)")
  }
  // O índice do snapshot volta inteiro, sem ".0": o restoreRoutine confere com Number.isInteger.
  let text = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
  #expect(text.contains(#""index":0"#))
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
