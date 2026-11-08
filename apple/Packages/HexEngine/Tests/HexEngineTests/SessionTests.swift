// Os testes do treino em andamento (session.js) do lado do Swift: o JSON que cada SessionAction vira,
// e o caminho de ponta a ponta no JavaScriptCore com o Codable dos modelos de Session.swift. As
// regras têm os testes em JS/session.test.mjs e no frontend/src/lib/session-controller.test.js.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexEngine --filter SessionTests

import Foundation
import Testing
@testable import HexEngine

// O JSON de cada ação, lido de volta como objeto, para comparar sem depender da ordem das chaves.
private func json(_ action: SessionAction) throws -> NSDictionary {
  try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(action)) as? NSDictionary)
}

// Segunda-feira, 9 de novembro de 2026, 10 h em UTC.
private let monday = Date(timeIntervalSince1970: 1_794_218_400)

// Um motor em pt-BR com uma rotina de supino, 3 × 8 a 60 kg, e a remada, 2 × 10 a 50 kg.
private func withRoutine() async throws -> (HexEngine, String) {
  let engine = try await loaded("pt-BR")
  _ = try await engine.freshDocument()
  let id = try #require(try await engine.apply(.createRoutine(name: "Push")).id)
  _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0025", "0027"], at: nil))
  _ = try await engine.apply(.updateSlot(routineID: id, index: 0, fields: SlotFields(sets: 3, reps: 8, weight: 60)))
  _ = try await engine.apply(.updateSlot(routineID: id, index: 1, fields: SlotFields(sets: 2, reps: 10, weight: 50)))
  return (engine, id)
}

@Test func eachSessionActionEncodesToTheJSONTheControllerExpects() throws {
  let cases: [(SessionAction, [String: Any])] = [
    (.start(routineIDs: ["r1", "r2"], id: "w1"), ["type": "start", "routineIds": ["r1", "r2"], "id": "w1"]),
    (.markSet(entry: 1, set: 2, done: true), ["type": "set.mark", "entry": 1, "set": 2, "done": true]),
    (.updateSet(entry: 0, set: 1, fields: SetFields(w: 62.5, r: 8)), ["type": "set.update", "entry": 0, "set": 1, "fields": ["w": 62.5, "r": 8]]),
    (.updateSet(entry: 0, set: 0, fields: SetFields(rir: 1.5)), ["type": "set.update", "entry": 0, "set": 0, "fields": ["rir": 1.5]]),
    (.stepSet(entry: 0, set: 0, field: .effort, direction: .down),
     ["type": "set.step", "entry": 0, "set": 0, "field": "effort", "direction": "down"]),
    (.addSet(entry: 2), ["type": "set.add", "entry": 2]),
    (.removeSet(entry: 2, set: 3), ["type": "set.remove", "entry": 2, "set": 3]),
    (.focus(entry: 1), ["type": "focus", "entry": 1]),
    (.addExercises(["0025", "0047"]), ["type": "exercise.add", "exerciseIds": ["0025", "0047"]]),
    (.replaceExercise(entry: 0, exerciseID: "0047", confirmLogged: false, group: nil),
     ["type": "exercise.replace", "entry": 0, "exerciseId": "0047", "confirmLogged": false, "group": NSNull()]),
    (.replaceExercise(entry: 0, exerciseID: "0047", confirmLogged: true, group: "detach"),
     ["type": "exercise.replace", "entry": 0, "exerciseId": "0047", "confirmLogged": true, "group": "detach"]),
    (.removeExercise(entry: 1), ["type": "exercise.remove", "entry": 1]),
    (.adjustRest(by: -15), ["type": "rest.adjust", "by": -15]),
    (.skipRest, ["type": "rest.skip"]),
    (.finish, ["type": "finish"]),
    (.discard, ["type": "discard"]),
  ]
  for (action, expected) in cases {
    #expect(try json(action) == expected as NSDictionary, "\(action)")
  }
  // O toque da Live Activity leva o at em ms e deixa de fora o que não tem.
  let event = LiveEvent(id: "e1", wid: "w1", kind: "set.done", entry: 0, set: 1, exId: "0025", at: Date(timeIntervalSince1970: 12.5))
  let encoded = try #require(JSONSerialization.jsonObject(with: HexEngine.sessionEncoder.encode(event)) as? NSDictionary)
  #expect(encoded == ["id": "e1", "wid": "w1", "kind": "set.done", "entry": 0, "set": 1, "exId": "0025", "at": 12500] as NSDictionary)
}

@Test func startAndMarkSetGiveTheEffectsAndTheWorkoutWithTheSetDone() async throws {
  let (engine, routine) = try await withRoutine()
  #expect(try await engine.activeWorkout(now: monday) == nil)
  let started = try await engine.session(.start(routineIDs: [routine], id: "w1"), now: monday)
  #expect(started.changed); #expect(started.effects == [.activityStart])
  #expect(started.result == .object(["id": .string("w1")]))

  let marked = try await engine.session(.markSet(entry: 0, set: 0, done: true), now: monday + 60)
  #expect(marked.effects == [.haptic("setLogged"), .restStarted(endsAt: monday + 150, total: 90, kind: "rest"), .activityUpdate])
  let w = try #require(try await engine.activeWorkout(now: monday + 70))
  #expect(w.id == "w1"); #expect(w.name == "Push"); #expect(w.start == monday); #expect(w.unit == "kg")
  #expect(w.done == 1); #expect(w.total == 5); #expect(w.next == SetRef(entry: 0, set: 1))
  #expect(w.entries.map(\.name) == ["supino com barra", "remada curvada com barra"])
  #expect(w.entries[0].sets[0].done); #expect(!w.entries[0].sets[1].done); #expect(w.entries[0].sets[0].line == "60 kg × 8")
  #expect(w.entries[0].target == "3 × 8 · 60 kg")
  #expect(w.rest == ActiveWorkout.Rest(endsAt: monday + 150, total: 90, forIdx: 0, forSet: 0, kind: "rest", remaining: 80))

  let home = try await engine.home(now: monday + 70)
  #expect(home.active?.done == 1); #expect(home.week.count == 7)
  let live = try #require(try await engine.liveActivity(now: monday + 70))
  #expect(live.cur?.setLine == "Série 2 de 3 · 60 kg × 8"); #expect(live.cur?.exId == "0025"); #expect(live.restEndsAt == monday + 150)

  // O mesmo toque de novo pela Live Activity não marca outra vez, e uma ação inválida volta como o
  // TypeError do motor.
  let again = LiveEvent(id: "e1", wid: "w1", kind: "set.done", entry: 0, set: 0, exId: "0025", at: monday + 61)
  #expect(try await engine.liveEvents([again], now: monday + 62).isEmpty)
  await #expect(throws: EngineError.self) { try await engine.session(.markSet(entry: 7, set: 0, done: true)) }
}

@Test func finishDecodesTheSummary() async throws {
  let (engine, routine) = try await withRoutine()
  _ = try await engine.session(.start(routineIDs: [routine], id: "w1"), now: monday)
  #expect(try await engine.finishSummary(from: engine.session(.focus(entry: 1), now: monday)) == nil)
  for (k, (entry, set)) in [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)].enumerated() {
    _ = try await engine.session(.markSet(entry: entry, set: set, done: true), now: monday + Double(k + 1) * 120)
  }
  let finished = try await engine.session(.finish, now: monday + 660)
  #expect(finished.effects == [.workoutFinished(id: "w1"), .activityEnd])
  let summary = try #require(try engine.finishSummary(from: finished))
  #expect(summary.id == "w1"); #expect(summary.name == "Push")
  #expect(summary.start == monday); #expect(summary.end == monday + 660); #expect(summary.durationMs == 660_000)
  #expect(summary.sets == FinishSummary.Sets(done: 5, work: 5)); #expect(summary.unit == "kg")
  #expect(summary.volume == 3 * 60 * 8 + 2 * 50 * 10)
  #expect(summary.prs.map(\.id) == ["0025", "0027"]); #expect(summary.prs.map(\.w) == [60, 50])
  #expect(summary.compare.map(\.name) == ["supino com barra", "remada curvada com barra"])
  #expect(summary.compare[0].today.count == 3); #expect(summary.compare[0].last == nil); #expect(summary.compare[0].trend == nil)
  #expect(summary.compare[0].next?.kind == "up")
  #expect(try await engine.activeWorkout(now: monday + 700) == nil)
}
