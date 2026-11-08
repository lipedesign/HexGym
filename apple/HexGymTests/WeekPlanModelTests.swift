// Os testes do plano da semana sem tela (Task 12 do plano da fase 2, issue #99). Os quatro do passo 1
// do plano: a ordem dos dias com a semana começando no domingo (0) e na segunda (1), com os rótulos
// curtos e por extenso; um dia sem rotina diz "Descanso", na linha e no VoiceOver; com o motor de
// verdade, o plano PPL deixa segunda, quarta e sexta com as rotinas dele e os outros dias como estavam;
// e o aviso de um plano pronto diz só os dias que ele troca de fato, conferido contra o que o motor faz
// em cada um dos quatro planos (e os dias de cada plano, contra os dias que o plano preenche). E o da
// nota 4 do QA do PR #119: o anúncio "Plano <nome> carregado" sai só depois de um atraso, quando a tela
// dos planos já fechou, para a troca de foco não cortar a fala do VoiceOver. E o da nota 3 do mesmo QA
// (issue #120): num documento com um item nulo no ex de uma rotina, o aviso cita o dia que o motor troca,
// porque os dias do aviso vêm da leitura do motor (engine.starterPlanChanges).
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct WeekPlanModelTests {
  let portuguese = Locale(identifier: "pt-BR")
  let english = Locale(identifier: "en")

  // Um motor em pt-BR com o documento do primeiro uso, ou com o documento dado por cima do DEF.
  func engine(_ document: String? = nil) async throws -> HexEngine {
    let engine = HexEngine(language: "pt-BR")
    _ = try await engine.load()
    _ = try await engine.freshDocument()
    if let document { try await engine.restore(Data(document.utf8)) }
    return engine
  }

  // O modelo pelo mesmo caminho da tela (WeekPlanScreen.load).
  func model(_ engine: HexEngine, locale: Locale? = nil) async throws -> WeekPlanModel {
    try await WeekPlanModel.read(engine, text: WeekPlanText(locale: locale ?? portuguese))
  }

  @Test func theDaysFollowTheWeekStartWithShortAndSpokenLabels() async throws {
    let engine = try await engine()
    for (weekStart, order) in [(0, [0, 1, 2, 3, 4, 5, 6]), (1, [1, 2, 3, 4, 5, 6, 0])] {
      _ = try await engine.apply(.setSetting(.weekStart(weekStart)))
      let model = try await model(engine)
      #expect(model.days.map(\.day) == order, "semana começando em \(weekStart)")
      #expect(model.days.count == 7)
    }
    // Com a semana na segunda: o primeiro é a segunda, o último o domingo.
    let pt = try await model(engine), en = try await model(engine, locale: english)
    #expect(pt.days.map(\.short) == ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"])
    #expect(pt.days.first?.full == "Segunda-feira")
    #expect(pt.days.last?.full == "Domingo")
    #expect(en.days.map(\.short) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    #expect(en.days.first?.full == "Monday")
  }

  @Test func aDayWithoutARoutineSaysRest() async throws {
    // A segunda com duas rotinas, a terça com um id que não é mais rotina (de outro aparelho), o resto
    // vazio. O motor deixa o id velho de fora, e a terça fica como descanso, como no openGym.
    let engine = try await engine(#"""
      {"weekStart":1,"routines":[{"id":"r1","name":"Peito","emoji":"arm","ex":[{"id":"0025","sets":3,"reps":10}]},
        {"id":"r2","name":"Costas","emoji":"pullup","ex":[]}],
       "week":{"1":["r1","r2"],"2":["nao-existe"]}}
      """#)
    let model = try await model(engine)
    let monday = try #require(model.day(1)), tuesday = try #require(model.day(2))
    #expect(monday.routines == "Peito e Costas")
    #expect(!monday.isRest)
    #expect(monday.routineIDs == ["r1", "r2"])
    #expect(monday.spoken == "Segunda-feira, Peito e Costas")
    #expect(tuesday.isRest)
    #expect(tuesday.routines == "Descanso")
    #expect(tuesday.spoken == "Terça-feira, Descanso")
    #expect(model.days.filter(\.isRest).count == 6)
    #expect(try #require(try await self.model(engine, locale: english).day(3)).spoken == "Wednesday, Rest")
    // A escolha da segunda: o descanso desmarcado, as duas rotinas marcadas, e o VoiceOver diz qual está.
    let choices = model.choices(for: 1)
    #expect(choices.map(\.id) == ["r1", "r2"])
    #expect(choices.allSatisfy { $0.isOn })
    #expect(choices.first?.spoken == "Peito, 1 exercício")
    #expect(model.choices(for: 2).allSatisfy { !$0.isOn })
    // Marcar e desmarcar, pelo id: a que sai some, e a que entra vai para o fim, como no openGym.
    #expect(WeekPlanModel.toggled(["r1", "r2"], "r1") == ["r2"])
    #expect(WeekPlanModel.toggled(["r2"], "r1") == ["r2", "r1"])
  }

  @Test func thePPLPlanFillsMondayWednesdayAndFridayAndLeavesTheOtherDays() async throws {
    // Uma rotina na segunda (que o plano troca) e na terça e no sábado (que ele não toca).
    let engine = try await engine(#"""
      {"weekStart":1,"routines":[{"id":"r1","name":"Peito","emoji":"arm","ex":[{"id":"0025","sets":3,"reps":10}]}],
       "week":{"1":["r1"],"2":["r1"],"6":["r1"]}}
      """#)
    let screen = WeekPlanScreen(engine: engine, locale: portuguese) { try await engine.apply($0) }
    await screen.load()
    let before = try #require(screen.model)
    #expect(await screen.loadPlan("ppl"))
    let after = try #require(screen.model)
    #expect(try #require(after.day(1)).routines == "Push Day")
    #expect(try #require(after.day(3)).routines == "Pull Day")
    #expect(try #require(after.day(5)).routines == "Leg Day")
    for day in [0, 2, 4, 6] {
      #expect(after.day(day) == before.day(day), "o dia \(day) fica como estava")
    }
    #expect(try #require(after.day(2)).routines == "Peito")
    #expect(try #require(after.day(4)).isRest)
    // A rotina de antes continua, e as três do plano entram uma vez só.
    let names = try await engine.routines().map(\.name)
    #expect(names == ["Peito", "Push Day", "Pull Day", "Leg Day"])
    #expect(await screen.loadPlan("ppl"))
    #expect(try await engine.routines().map(\.name) == names)
  }

  @Test func theWarningSaysOnlyTheDaysThePlanReallyChanges() async throws {
    // A segunda e a terça com rotinas, e a quarta com um id velho, que o motor lê como descanso.
    let document = #"""
      {"weekStart":1,"routines":[{"id":"r1","name":"Peito","emoji":"arm","ex":[{"id":"0025","sets":3,"reps":10}]},
        {"id":"r2","name":"Costas","emoji":"pullup","ex":[{"id":"0027","sets":3,"reps":10}]}],
       "week":{"1":["r1"],"2":["r2"],"3":["nao-existe"]}}
      """#
    let engine = try await engine(document)
    let model = try await model(engine)
    #expect(model.warning(forPlan: "ppl") == "Este plano troca segunda.")
    #expect(model.warning(forPlan: "upper-lower") == "Este plano troca segunda e terça.")
    #expect(try await self.model(engine, locale: english).warning(forPlan: "upper-lower") == "This plan changes Monday and Tuesday.")
    // Os planos com os dias que ocupam, na ordem do motor.
    #expect(model.plans.map(\.id) == ["ppl", "upper-lower", "full-body", "5x5"])
    #expect(model.plans.map(\.name) == ["Empurrar, puxar, pernas", "Superior e inferior", "Corpo inteiro", "5×5"])
    #expect(model.plans.first?.days == [1, 3, 5])
    #expect(model.plans.first?.detail == "3 dias por semana\u{00A0}· Seg, Qua, Sex")

    // Com o PPL carregado, carregar o PPL de novo não troca nada (as rotinas iguais voltam aos mesmos
    // dias), e o corpo inteiro troca os três dias dele.
    _ = try await engine.apply(.loadStarterPlan(id: "ppl"))
    let loaded = try await self.model(engine)
    #expect(loaded.warning(forPlan: "ppl") == nil)
    #expect(loaded.replacedDays(byPlan: "ppl").isEmpty)
    #expect(loaded.warning(forPlan: "full-body") == "Este plano troca segunda, quarta e sexta.")

    // Contra o motor, nos quatro planos e em três documentos: os dias que o aviso diz são os dias que
    // tinham rotina e mudaram depois do plan.starter. Na semana vazia, nenhum dia é trocado, e os dias
    // que o plano preenche são os dias da linha dele.
    let empty = #"{"weekStart":1}"#
    for start in [document, nil, empty] {
      for row in model.plans {
        let engine = try await self.engine(start)
        if start == nil { _ = try await engine.apply(.loadStarterPlan(id: "ppl")) }
        let predicted = try await self.model(engine)
        let before = try await engine.week().days
        _ = try await engine.apply(.loadStarterPlan(id: row.id))
        let after = try await engine.week().days
        let changed = zip(before, after).filter { !$0.routineIds.isEmpty && $0.routineIds != $1.routineIds }.map(\.0.day)
        let label = start == nil ? "depois do ppl" : start == empty ? "na semana vazia" : "com as duas rotinas"
        #expect(predicted.replacedDays(byPlan: row.id) == changed, "\(row.id), \(label)")
        #expect((predicted.warning(forPlan: row.id) == nil) == changed.isEmpty, "\(row.id), \(label)")
        if start == empty {
          #expect(after.filter { !$0.routineIds.isEmpty }.map(\.day) == row.days, "\(row.id)")
        }
      }
    }
  }

  @Test func aNullItemInARoutineStillWarnsAboutTheDayTheEngineChanges() async throws {  // nota 3 do QA do PR #119
    // O Push Day de um documento quebrado: os exercícios do PPL e um nulo no fim. A lista das rotinas
    // deixa o nulo de fora e mostra a rotina igual à do plano, mas o plan.starter conta o nulo, cria outro
    // Push Day e troca a segunda. O aviso diz a segunda, e o plano não entra no primeiro toque.
    let push = ["0025", "0047", "0426", "0334", "0241", "0251"]
      .map { #"{"id":"\#($0)","sets":4,"reps":8,"weight":0}"# }.joined(separator: ",")
    let engine = try await engine(#"""
      {"weekStart":1,"routines":[{"id":"r1","name":"Push Day","emoji":"barbell","ex":[\#(push),null]}],
       "week":{"1":["r1"]}}
      """#)
    #expect(try await engine.routines().first?.slots.count == 6)
    let model = try await model(engine)
    #expect(model.replacedDays(byPlan: "ppl") == [1])
    #expect(model.warning(forPlan: "ppl") == "Este plano troca segunda.")
    // E o motor troca mesmo a segunda.
    _ = try await engine.apply(.loadStarterPlan(id: "ppl"))
    #expect(try await engine.week().days.first { $0.day == 1 }?.routineIds != ["r1"])
    // A mesma rotina sem o nulo é reaproveitada, e o ppl não troca dia nenhum.
    let clean = try await self.engine(#"""
      {"weekStart":1,"routines":[{"id":"r1","name":"Push Day","emoji":"barbell","ex":[\#(push)]}],
       "week":{"1":["r1"]}}
      """#)
    #expect(try await self.model(clean).warning(forPlan: "ppl") == nil)
  }

  @Test func theLoadedAnnouncementWaitsUntilTheSheetHasClosed() async throws {  // nota 4 do QA do PR #119
    let pt = WeekPlanText(locale: portuguese), en = WeekPlanText(locale: english)
    #expect(pt.loaded("Empurrar, puxar, pernas") == "Plano Empurrar, puxar, pernas carregado")
    #expect(en.loaded("Push / Pull / Legs") == "Push / Pull / Legs plan loaded")
    // O título do aviso, pelo mesmo catálogo.
    #expect(pt.loadTitle("Corpo inteiro") == "Carregar o plano Corpo inteiro?")
    #expect(en.loadTitle("Full Body") == "Load the Full Body plan?")
    // A fala não sai na hora: só depois do atraso, que dá tempo de a tela fechar e o foco assentar.
    #expect(PlanLoadedAnnouncement.delay >= .milliseconds(500))
    let spoken = Spoken()
    let clock = ContinuousClock(), start = clock.now
    let task = PlanLoadedAnnouncement.schedule("Plano 5×5 carregado") { spoken.lines.append($0) }
    #expect(spoken.lines.isEmpty, "o anúncio não sai antes de a tela fechar")
    await task.value
    #expect(spoken.lines == ["Plano 5×5 carregado"])
    #expect(clock.now - start >= PlanLoadedAnnouncement.delay)
  }

  // O que o VoiceOver teria dito, no lugar do anúncio de verdade.
  @MainActor final class Spoken {
    var lines: [String] = []
  }
}
