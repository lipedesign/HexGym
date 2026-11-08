// Os testes dos documentos preparados (os cinco da Task 6 do plano da fase 3 e os dois do Início da
// Task 7): os sete abrem no motor de verdade, com o que cada um promete, e o relógio de cada um vai
// para hoje na carga (FixtureLoader).
// O segundo roda sete dias seguidos, um de cada dia da semana, porque o print pode sair em qualquer um.

import Foundation
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct FixtureLoaderTests {
  // A data AAAA-MM-DD do instante no fuso do aparelho, como o motor a lê.
  func iso(_ date: Date, in zone: TimeZone = .current) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = zone
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  @Test func theSevenDocumentsOpenInTheEngine() async throws {
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    let now = Date.now
    #expect(FixtureDocuments.names.count == 7)
    for name in FixtureDocuments.names {
      let data = try FixtureLoader.document(named: name, now: now)
      let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any], "\(name)")
      #expect(object["_fixtureNow"] == nil, "\(name)")
      try await engine.restore(data)
      let home = try await engine.home(now: now)
      let workout = try await engine.activeWorkout(now: now)
      switch name {
      case "semana-ppl":
        #expect(workout == nil); #expect(home.total == 12)
        #expect(home.today.status == "planned"); #expect(home.today.routines.map(\.name) == ["Push"])
        #expect((object["workouts"] as? [[String: Any]])?.filter { !($0["id"] is String) }.count == 1)   // o treino antigo sem id
      case "treino-em-andamento":
        let w = try #require(workout)
        #expect(w.done == 5); #expect(w.total == 13); #expect(w.rest == nil as ActiveWorkout.Rest?); #expect(home.active?.done == 5)
        #expect(w.entries.compactMap(\.sgLetter) == ["A", "A"]); #expect(w.next?.entry == 1); #expect(w.next?.set == 1)
      case "descanso":
        let w = try #require(workout)
        #expect(w.done == 5); #expect(w.total == 13); #expect(w.rest?.remaining == 75); #expect(w.rest?.kind == "rest")
      case "vazio":
        #expect(workout == nil); #expect(home.total == 0); #expect(home.today.status == "none"); #expect(home.last == nil)
      case "veio-do-opengym":
        let w = try #require(workout)
        let rows = w.entries.flatMap(\.sets)
        #expect(Set(rows.map(\.kind)) == ["normal", "drop", "restpause", "sides", "cardio"])
        #expect(rows.contains { $0.warmup }); #expect(w.entries.contains { $0.mode == "time" })
        #expect(w.entries.contains { !$0.known }); #expect(rows.allSatisfy { !$0.line.isEmpty })
        #expect(w.rest == nil as ActiveWorkout.Rest?); #expect(w.start != nil)
      case "dia-de-descanso":
        // O semana-ppl com o hoje de descanso: a próxima sessão é a da semana, e o histórico é o mesmo.
        #expect(workout == nil); #expect(home.total == 12)
        #expect(home.today.status == "rest"); #expect(home.today.routines.isEmpty)
        #expect(home.next != nil)
        #expect((object["dayPlan"] as? [String: String])?.values.sorted() == ["rest"])
      case "nada-marcado":
        #expect(workout == nil); #expect(home.total == 12)
        #expect(home.today.status == "none"); #expect(home.next == nil)
        #expect(home.week.allSatisfy { !$0.planned })
      default:
        Issue.record("documento sem conferência: \(name)")
      }
    }
    #expect(throws: FixtureLoader.Failure.unknown("inventado")) { try FixtureLoader.document(named: "inventado") }
  }

  @Test func theClockMovesEachDocumentToToday() async throws {
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    let calendar = Calendar.current
    for offset in 0..<7 {
      let now = try #require(calendar.date(byAdding: .day, value: offset, to: .now))
      // O descanso tem 75 s pela frente, e o treino é de hoje.
      try await engine.restore(FixtureLoader.document(named: "descanso", now: now))
      let w = try #require(try await engine.activeWorkout(now: now))
      #expect(w.rest?.remaining == 75)
      #expect(abs(try #require(w.rest?.endsAt).timeIntervalSince(now) - 75) < 0.001)
      let text = try await engine.document()
      let active = try JSONSerialization.jsonObject(with: text) as? [String: Any]
      #expect((active?["active"] as? [String: Any])?["d"] as? String == iso(now))

      // O último treino do semana-ppl, o Legs da sexta, fica três dias antes de hoje, e hoje é dia de
      // Push, qualquer que seja o dia da semana.
      try await engine.restore(FixtureLoader.document(named: "semana-ppl", now: now))
      let home = try await engine.home(now: now)
      #expect(home.today.date == iso(now)); #expect(home.today.status == "planned")
      #expect(home.today.routines.map(\.name) == ["Push"])
      #expect(home.last?.name == "Legs")
      #expect(home.last?.d == iso(try #require(calendar.date(byAdding: .day, value: -3, to: now))))
      let lastKey = try #require(home.last?.key)
      let lastStart = try #require(try await engine.workoutDetail(lastKey)?.start)
      #expect(iso(lastStart) == home.last?.d)

      // O dia-de-descanso é dia de descanso qualquer que seja o dia da semana, com a próxima sessão.
      try await engine.restore(FixtureLoader.document(named: "dia-de-descanso", now: now))
      let rest = try await engine.home(now: now)
      #expect(rest.today.status == "rest"); #expect(rest.next != nil)

      // Em qualquer fuso, o start de cada treino do histórico cai no dia do d dele, e a duração fica a
      // mesma (rodada 2 do PR #156).
      for zone in ["Pacific/Auckland", "Europe/Zurich", "America/Sao_Paulo"].compactMap(TimeZone.init(identifier:)) {
        var zoned = Calendar(identifier: .gregorian)
        zoned.timeZone = zone
        let data = try FixtureLoader.document(named: "semana-ppl", now: now, calendar: zoned)
        let workouts = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["workouts"] as? [[String: Any]])
        #expect(workouts.count == 12)
        for w in workouts {
          let start = try #require((w["start"] as? NSNumber)?.doubleValue), end = try #require((w["end"] as? NSNumber)?.doubleValue)
          #expect(iso(Date(timeIntervalSince1970: start / 1000), in: zone) == w["d"] as? String, "\(zone.identifier) \(w["d"] ?? "")")
          #expect(end - start > 20 * 60_000 && end - start < 40 * 60_000)
        }
      }
    }
  }
}
