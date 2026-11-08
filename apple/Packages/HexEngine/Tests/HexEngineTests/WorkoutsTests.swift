// Os testes do histórico (workouts.js) do lado do Swift: a página e o detalhe decodificados no
// JavaScriptCore com o Codable dos modelos de Workouts.swift, e o EngineAction.deleteWorkout. As
// regras têm os testes em JS/workouts.test.mjs.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexEngine --filter WorkoutsTests

import Foundation
import Testing
@testable import HexEngine

// Sexta-feira, 6 de novembro de 2026, 18 h em UTC, e um dia em segundos.
private let friday = Date(timeIntervalSince1970: 1_794_074_400)
private let day: TimeInterval = 86_400

// Um treino salvo em ms, como o buildCompletedWorkout grava, com 50 minutos; sem id quando é antigo.
private func saved(_ id: String?, _ start: Date, _ entries: [[String: Any]] = [], prs: [String] = []) -> [String: Any] {
  let ms = (start.timeIntervalSince1970 * 1000).rounded()
  var w: [String: Any] = [
    "d": ISO8601DateFormatter.string(from: start, timeZone: .current, formatOptions: [.withFullDate]),
    "start": ms, "end": ms + 50 * 60_000, "name": "Treino \(id ?? "antigo")", "routineIds": [], "entries": entries, "prs": prs,
  ]
  if let id { w["id"] = id }
  return w
}

// Um motor em pt-BR com o documento do primeiro uso e os treinos por cima.
private func withWorkouts(_ workouts: [[String: Any]]) async throws -> HexEngine {
  let engine = try await loaded("pt-BR")
  var doc = try object(try await engine.freshDocument())
  doc["workouts"] = workouts
  try await engine.restore(JSONSerialization.data(withJSONObject: doc))
  return engine
}

private func bench() -> [String: Any] { [
  "id": "0025", "target": ["sets": 3, "reps": 8, "weight": 60],
  "sets": [["w": 40, "r": 8, "done": true, "warmup": true], ["w": 60, "r": 8, "done": true], ["w": 62.5, "r": 8, "done": true]],
] }

@Test func historyAndDetailDecodeInJavaScriptCore() async throws {
  let old = saved(nil, friday - 2 * day)
  let engine = try await withWorkouts([old, saved("w2", friday - day), saved("w3", friday, [bench()], prs: ["0025"])])
  let first = try await engine.history(before: nil, limit: 2)
  #expect(first.items.map(\.key) == ["w3", "w2"]); #expect(first.more)
  let top = first.items[0]
  #expect(top.id == "w3"); #expect(top.name == "Treino w3"); #expect(top.start == friday); #expect(top.end == friday + 3000)
  #expect(top.durationMs == 3_000_000); #expect(top.sets == WorkoutSummary.Sets(done: 3, work: 2))
  #expect(top.volume == 60 * 8 + 62.5 * 8); #expect(top.unit == "kg"); #expect(top.prs == ["0025"])

  // A página seguinte traz o treino antigo, sem id, pela chave do legacySyncKey.
  let next = try await engine.history(before: "w2", limit: 2)
  #expect(!next.more); #expect(next.items.count == 1)
  let legacy = try #require(next.items.first)
  #expect(legacy.id == nil); #expect(legacy.key == "\(old["d"]!)|\(Int(old["start"] as! Double))")
  #expect(try await engine.workoutDetail(legacy.key)?.name == "Treino antigo")

  let detail = try #require(try await engine.workoutDetail("w3"))
  #expect(detail.key == "w3"); #expect(detail.start == friday); #expect(detail.durationMs == 3_000_000); #expect(detail.prs == ["0025"])
  #expect(detail.note == nil); #expect(detail.bw == nil)
  let entry = try #require(detail.entries.first)
  #expect(entry.name == "supino com barra"); #expect(entry.known); #expect(entry.pr); #expect(entry.sgLetter == nil)
  #expect(entry.sets == [
    WorkoutDetail.SetLine(line: "40 kg × 8", done: true, warmup: true, pr: false),
    WorkoutDetail.SetLine(line: "60 kg × 8", done: true, warmup: false, pr: false),
    WorkoutDetail.SetLine(line: "62,5 kg × 8", done: true, warmup: false, pr: true),
  ])
  #expect(try await engine.workoutDetail("nao-existe") == nil)
  // Uma página depois de uma chave que não existe volta como o TypeError do motor.
  await #expect(throws: EngineError.self) { try await engine.history(before: "nao-existe", limit: 2) }
}

@Test func deleteWorkoutTakesTheWorkoutOut() async throws {
  let engine = try await withWorkouts([saved(nil, friday - 2 * day), saved(nil, friday - day), saved("w3", friday)])
  #expect(try JSONSerialization.jsonObject(with: JSONEncoder().encode(EngineAction.deleteWorkout(key: "w3"))) as? NSDictionary
    == ["type": "workout.delete", "key": "w3"] as NSDictionary)
  let page = try await engine.history(before: nil, limit: 10)
  let legacy = page.items[1].key
  let out = try await engine.apply(.deleteWorkout(key: legacy), now: friday + day)
  #expect(out.changed)
  // Só o treino da chave sai; o outro antigo, também sem id, fica.
  #expect(try await engine.history(before: nil, limit: 10).items.map(\.key) == [page.items[0].key, page.items[2].key])
  #expect(try await engine.workoutDetail(legacy) == nil)
  let doc = try object(try await engine.document())
  #expect((doc["deleted"] as? [String: Any])?["workouts"] as? [String: Double] == [legacy: (friday + day).timeIntervalSince1970 * 1000])
  // A mesma chave de novo já não existe, e lança.
  await #expect(throws: EngineError.self) { try await engine.apply(.deleteWorkout(key: legacy), now: friday + day) }
}
