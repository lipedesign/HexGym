// Os testes da tela inicial sem tela (Task 7 do plano da fase 3, issue #136), os cinco do passo 1 de lá:
// o título e o botão para cada status de hoje; com um treino em andamento, "Continuar treino" e "5 de 18
// séries"; o singular e o plural da sequência, dos treinos e do último treino nos dois idiomas; as letras
// e a fala da semana com o weekStart 0 e 1, pelo motor de verdade; e o app vazio, sem rotinas e sem
// histórico (Foco da revisão 5), também pelo motor de verdade.
//
// Os textos que o openGym já tem vêm dele (views/Home.jsx e o pacote pt-BR, que herda do pt): "Dia de
// descanso", "Próxima sessão: Quarta, Pull", "Escolher outro treino", "Push (em andamento)", "Push
// (concluído)", "Sequência de 3 semanas" e "12 treinos no total"; a duração do último treino é a do fmtDur
// dele, em minutos inteiros para baixo, e some abaixo de 1 minuto (o durPart).
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct HomeModelTests {
  let portuguese = HomeText(locale: Locale(identifier: "pt-BR"))
  let english = HomeText(locale: Locale(identifier: "en"))

  // As três rotinas do PPL, com os nomes dos exercícios como o motor manda.
  let routines: [RoutineSummary] = [
    routine("r-push", "Push", "barbell", ["Supino reto", "Crucifixo", "Desenvolvimento", "Elevação lateral", "Tríceps na polia", "Paralelas"]),
    routine("r-pull", "Pull", "pullup", ["Barra fixa", "Remada curvada"]),
    // O motor manda alguns nomes em minúscula ("agachamento"): o cartão põe a primeira letra em maiúscula.
    routine("r-legs", "Legs", "squat", ["agachamento"]),
  ].compactMap { $0 }

  // Um resumo do motor, com o hoje, o treino em andamento, a semana, a sequência e o último treino
  // pedidos. As horas vão em ms, como o motor manda.
  func summary(status: String = "planned", today: [String] = ["r-push"], date: String = "2026-11-09",
               active: String = "null", week: String? = nil, streak: Int = 3, weekCount: Int = 2, total: Int = 12,
               last: String = "null", next: String = "null") throws -> HomeSummary {
    let names = ["r-push": "Push", "r-pull": "Pull", "r-legs": "Legs"]
    let todays = today.map { #"{"id":"\#($0)","name":"\#(names[$0] ?? $0)","glyph":"barbell"}"# }.joined(separator: ",")
    let days = week ?? Self.week(weekStart: 1, today: 1, trained: [], planned: [1, 3, 5])
    let text = #"""
      {"today":{"date":"\#(date)","status":"\#(status)","routines":[\#(todays)]},"active":\#(active),"week":\#(days),
       "streakWeeks":\#(streak),"weekCount":\#(weekCount),"total":\#(total),"last":\#(last),"next":\#(next)}
      """#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return try decoder.decode(HomeSummary.self, from: Data(text.utf8))
  }

  // A semana como o motor manda: os sete dias na ordem do weekStart, de 9 a 15 de novembro de 2026 com a
  // semana na segunda.
  static func week(weekStart: Int, today: Int, trained: Set<Int>, planned: Set<Int>) -> String {
    let order = (0..<7).map { (weekStart + $0) % 7 }
    let cells = order.enumerated().map { offset, day in
      #"{"day":\#(day),"date":"2026-11-\#(9 + offset)","trained":\#(trained.contains(day)),"planned":\#(planned.contains(day)),"today":\#(day == today)}"#
    }
    return "[" + cells.joined(separator: ",") + "]"
  }

  func model(_ summary: HomeSummary, _ text: HomeText? = nil) -> HomeModel {
    HomeModel(summary: summary, routines: routines, text: text ?? portuguese)
  }

  @Test func theTitleAndTheButtonFollowTodaysStatus() throws {
    // Dia de treino: o nome da rotina, os exercícios dela e "Começar treino" com as rotinas de hoje; o
    // "Escolher outro treino" ao lado, com as outras rotinas e o treino livre.
    let planned = model(try summary())
    #expect(planned.eyebrow == "Hoje\u{00A0}· segunda")
    #expect(planned.title == "Push")
    #expect(planned.detail == "Supino reto, Crucifixo, Desenvolvimento, Elevação lateral e mais 2")
    #expect(planned.primary == .start(["r-push"]))
    #expect(planned.primaryLabel == "Começar treino")
    #expect(planned.offersChooser)
    #expect(planned.chooserLabel == "Escolher outro treino")
    #expect(planned.chooser.map(\.id) == ["r-pull", "r-legs"])
    #expect(planned.freestyleLabel == "Treino livre (escolha durante o treino)")
    #expect(planned.nextSession == nil)
    // Duas rotinas no dia: juntas por " + ", como o todayName do openGym, e os exercícios das duas.
    let two = model(try summary(today: ["r-pull", "r-legs"]))
    #expect(two.title == "Pull + Legs")
    #expect(two.detail == "Barra fixa, Remada curvada e Agachamento")
    #expect(two.primary == .start(["r-pull", "r-legs"]))
    #expect(two.chooser.map(\.id) == ["r-push"])

    // Dia de descanso: "Dia de descanso", como o openGym, com a próxima sessão do motor embaixo; um dia sem
    // nada marcado: "Nada marcado para hoje". Nos dois, o único botão é o "Escolher outro treino", com
    // todas as rotinas.
    let wednesday = #"{"weekday":3,"name":"Pull"}"#
    let rest = model(try summary(status: "rest", today: [], next: wednesday))
    #expect(rest.title == "Dia de descanso")
    #expect(rest.nextSession == "Próxima sessão: Quarta, Pull")
    let none = model(try summary(status: "none", today: []))
    #expect(none.title == "Nada marcado para hoje")
    #expect(none.nextSession == nil)
    #expect(model(try summary(status: "none", today: [], next: wednesday)).nextSession == "Próxima sessão: Quarta, Pull")
    for free in [rest, none] {
      #expect(free.detail == nil, "\(free.title)")
      #expect(free.primary == .choose)
      #expect(free.primaryLabel == "Escolher outro treino")
      #expect(!free.offersChooser)
      #expect(free.chooser.map(\.id) == ["r-push", "r-pull", "r-legs"])
    }

    // O treino de hoje feito: o nome do último treino do dia, "(concluído)"; sem treino com nome no dia,
    // "Treino concluído". O próximo treino do dia fica no "Escolher outro treino".
    let lastToday = #"{"key":"w1","id":"w1","name":"Push","d":"2026-11-09","durationMs":3120000,"sets":18}"#
    let done = model(try summary(status: "done", last: lastToday, next: wednesday))
    #expect(done.title == "Push (concluído)")
    // Com o treino de hoje feito, a próxima sessão não aparece, como no openGym (o next && !doneToday).
    #expect(done.nextSession == nil)
    #expect(done.primary == .choose)
    #expect(done.chooser.map(\.id) == ["r-push", "r-pull", "r-legs"])
    let lastYesterday = #"{"key":"w0","id":"w0","name":"Legs","d":"2026-11-08","durationMs":3120000,"sets":18}"#
    #expect(model(try summary(status: "done", last: lastYesterday)).title == "Treino concluído")

    // Em inglês, as chaves do openGym.
    #expect(model(try summary(), english).primaryLabel == "Start workout")
    #expect(model(try summary(), english).eyebrow == "Today\u{00A0}· Monday")
    #expect(model(try summary(status: "rest", today: []), english).title == "Rest day")
    #expect(model(try summary(status: "none", today: []), english).title == "Nothing planned for today")
    #expect(model(try summary(status: "rest", today: [], next: wednesday), english).nextSession == "Next session: Wednesday, Pull")
    #expect(model(try summary(status: "done", last: lastToday), english).title == "Push (done)")
    #expect(model(try summary(status: "rest", today: []), english).primaryLabel == "Choose a different workout")
  }

  @Test func aWorkoutInProgressSaysContinueAndCountsTheSets() throws {
    let active = #"{"name":"Push","start":1794225600000,"done":5,"total":18}"#
    let model = model(try summary(active: active))
    #expect(model.title == "Push (em andamento)")
    #expect(model.primary == .resume)
    #expect(model.primaryLabel == "Continuar treino")
    // Com o treino em andamento, o openGym não oferece outro treino: começar um apagaria o de agora.
    #expect(!model.offersChooser)
    #expect(model.detail == nil)
    let card = try #require(model.active)
    #expect(card.progress == "5 de 18 séries")
    #expect(card.done == 5); #expect(card.total == 18)
    #expect(card.start == Date(timeIntervalSince1970: 1_794_225_600))
    let english = self.model(try summary(active: active), english)
    #expect(english.title == "Push (in progress)")
    #expect(english.primaryLabel == "Continue workout")
    #expect(english.active?.progress == "5 of 18 sets")
    // O tempo que passa: abaixo de uma hora, minutos e segundos; acima, as horas na frente.
    #expect(HomeModel.elapsed(0) == "0:00")
    #expect(HomeModel.elapsed(5) == "0:05")
    #expect(HomeModel.elapsed(23 * 60 + 14) == "23:14")
    #expect(HomeModel.elapsed(3600 + 2 * 60 + 10) == "1:02:10")
    #expect(HomeModel.elapsed(-3) == "0:00")
  }

  @Test func theStreakTheTotalsAndTheLastWorkoutAreSingularOrPluralInBothLanguages() throws {
    let one = #"{"key":"w1","id":"w1","name":"Leg Day","d":"2026-11-06","durationMs":2940000,"sets":1}"#
    let many = #"{"key":"w2","id":"w2","name":"Leg Day","d":"2026-11-06","durationMs":4320000,"sets":18}"#
    let single = model(try summary(streak: 1, weekCount: 1, total: 1, last: one))
    #expect(single.streak == "Sequência de 1 semana")
    #expect(single.tally == "1 esta semana\u{00A0}· 1 treino no total")
    let plural = model(try summary(streak: 3, weekCount: 2, total: 12, last: many))
    #expect(plural.streak == "Sequência de 3 semanas")
    #expect(plural.tally == "2 esta semana\u{00A0}· 12 treinos no total")

    let singleLast = try #require(single.last)
    #expect(singleLast.key == "w1")
    #expect(singleLast.name == "Leg Day")
    #expect(singleLast.detail == "sex., 6 de nov.\u{00A0}· 49 min\u{00A0}· 1 série")
    let pluralLast = try #require(plural.last)
    #expect(pluralLast.detail == "sex., 6 de nov.\u{00A0}· 1 h 12 min\u{00A0}· 18 séries")
    #expect(pluralLast.spoken == "Leg Day, sexta-feira, 6 de novembro, 1 hora e 12 minutos, 18 séries")

    let en1 = model(try summary(streak: 1, weekCount: 1, total: 1, last: one), english)
    #expect(en1.streak == "1 week streak")
    #expect(en1.tally == "1 this week\u{00A0}· 1 workout total")
    #expect(en1.last?.detail == "Fri, Nov 6\u{00A0}· 49 min\u{00A0}· 1 set")
    let enMany = model(try summary(streak: 3, weekCount: 2, total: 12, last: many), english)
    #expect(enMany.streak == "3 week streak")
    #expect(enMany.tally == "2 this week\u{00A0}· 12 workouts total")
    #expect(enMany.last?.detail == "Fri, Nov 6\u{00A0}· 1h 12m\u{00A0}· 18 sets")

    // A duração do fmtDur do openGym: os minutos para baixo (59 min e 40 s dão "59 min"), e nada sem
    // relógio, abaixo de 1 minuto (o durPart), nem na fala.
    let almost = #"{"key":"w3","id":"w3","name":"Leg Day","d":"2026-11-06","durationMs":3580000,"sets":18}"#
    #expect(model(try summary(last: almost)).last?.detail == "sex., 6 de nov.\u{00A0}· 59 min\u{00A0}· 18 séries")
    let clockless = #"{"key":"w4","id":"w4","name":"Leg Day","d":"2026-11-06","durationMs":59999,"sets":18}"#
    let noClock = try #require(model(try summary(last: clockless)).last)
    #expect(noClock.detail == "sex., 6 de nov.\u{00A0}· 18 séries")
    #expect(noClock.spoken == "Leg Day, sexta-feira, 6 de novembro, 18 séries")

    // Com histórico e sem semana seguida, a sequência some e os totais ficam.
    let broken = model(try summary(streak: 0, weekCount: 0, total: 12))
    #expect(broken.streak == nil)
    #expect(broken.tally == "0 esta semana\u{00A0}· 12 treinos no total")
  }

  @Test func theWeekLettersAndSpeechFollowTheWeekStart() async throws {
    // O semana-ppl no instante dele (segunda, 9 de novembro): Push na segunda, que é hoje, Pull na quarta
    // e Legs na sexta, e nenhum treino ainda nesta semana.
    let now = Date(timeIntervalSince1970: 1_794_225_600)
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    try await engine.restore(try FixtureLoader.document(named: "semana-ppl", now: now))
    let routines = try await engine.routines()

    let monday = HomeModel(summary: try await engine.home(now: now), routines: routines, text: portuguese)
    #expect(monday.week.map(\.day) == [1, 2, 3, 4, 5, 6, 0])
    #expect(monday.week.map(\.letter) == ["S", "T", "Q", "Q", "S", "S", "D"])
    #expect(monday.week.map(\.today) == [true, false, false, false, false, false, false])
    #expect(monday.week.map(\.planned) == [true, false, true, false, true, false, false])
    // Sem "Semana" na frente: o título em cima da semana já diz.
    #expect(monday.weekSpoken == "segunda, hoje, planejado; terça, descanso; quarta, planejado; quinta, descanso; "
      + "sexta, planejado; sábado, descanso; domingo, descanso")

    _ = try await engine.apply(.setSetting(.weekStart(0)), now: now)
    let sunday = HomeModel(summary: try await engine.home(now: now), routines: routines, text: portuguese)
    #expect(sunday.week.map(\.day) == [0, 1, 2, 3, 4, 5, 6])
    #expect(sunday.week.map(\.letter) == ["D", "S", "T", "Q", "Q", "S", "S"])
    #expect(sunday.weekSpoken.hasPrefix("domingo, descanso; segunda, hoje, planejado; terça, descanso"))
    let english = HomeModel(summary: try await engine.home(now: now), routines: routines, text: english)
    #expect(english.week.map(\.letter) == ["S", "M", "T", "W", "T", "F", "S"])
    #expect(english.weekSpoken.hasPrefix("Sunday, rest; Monday, today, planned; Tuesday, rest"))

    // Um dia treinado fala "treinado", também quando estava planejado e quando é hoje.
    let trained = model(try summary(week: Self.week(weekStart: 1, today: 3, trained: [1, 3], planned: [1, 3, 5])))
    #expect(trained.week.map(\.trained) == [true, false, true, false, false, false, false])
    #expect(trained.weekSpoken.hasPrefix("segunda, treinado; terça, descanso; quarta, hoje, treinado; quinta, descanso; sexta, planejado"))
  }

  @Test func anEmptyAppAsksForTheFirstRoutineAndStartsFreestyle() async throws {   // Foco da revisão 5
    // O documento do primeiro uso, sem rotinas e sem histórico, pelo motor de verdade.
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    _ = try await engine.freshDocument()
    let summary = try await engine.home()
    #expect(summary.today.status == "none")
    #expect(summary.last == nil); #expect(summary.total == 0); #expect(summary.streakWeeks == 0)

    let model = HomeModel(summary: summary, routines: try await engine.routines(), text: portuguese)
    #expect(model.title == "Monte a sua primeira rotina")
    #expect(model.detail == "Configure sua rotina semanal para começar, ou pegue um plano inicial já pronto.")
    #expect(model.goesToRoutines)
    #expect(model.routinesLabel == "Ir para Rotinas")
    #expect(model.primary == .freestyle)
    #expect(model.primaryLabel == "Começar treino livre")
    #expect(!model.offersChooser)
    #expect(model.chooser.isEmpty)
    #expect(model.active == nil)
    #expect(model.last == nil)
    // Sem histórico, a sequência e os totais não aparecem: "Sequência de 0 semanas" não diz nada.
    #expect(model.streak == nil); #expect(model.tally == nil)
    #expect(model.week.count == 7)
    #expect(model.week.allSatisfy { !$0.trained && !$0.planned })
    #expect(model.week.filter(\.today).count == 1)

    let english = HomeModel(summary: summary, routines: [], text: english)
    #expect(english.title == "Build your first routine")
    #expect(english.primaryLabel == "Start freestyle workout")
    #expect(english.routinesLabel == "Go to Routines")

    // Com rotinas e sem histórico, o cartão volta a ser o de hoje, e a sequência continua de fora.
    let withRoutines = self.model(try self.summary(status: "none", today: [], streak: 0, weekCount: 0, total: 0))
    #expect(withRoutines.title == "Nada marcado para hoje")
    #expect(!withRoutines.goesToRoutines)
    #expect(withRoutines.primary == .choose)
    #expect(withRoutines.streak == nil)
  }
}

// Uma rotina como o engine.routines() manda, só com o que a tela inicial lê. Uma que não decodifica sai
// da lista, e as contas dos testes caem.
private func routine(_ id: String, _ name: String, _ glyph: String, _ exercises: [String]) -> RoutineSummary? {
  let slots = exercises.enumerated().map { index, name in
    #"{"id":"\#(index)","name":"\#(name)","known":true,"setsReps":"3 × 8","increment":2.5,"repStep":1}"#
  }.joined(separator: ",")
  let text = #"{"id":"\#(id)","name":"\#(name)","glyph":"\#(glyph)","slots":[\#(slots)],"muscles":{},"days":[]}"#
  return try? JSONDecoder().decode(RoutineSummary.self, from: Data(text.utf8))
}
