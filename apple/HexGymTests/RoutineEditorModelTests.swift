// Os testes do editor de rotina sem tela (Task 11 do plano da fase 2, issue #98). Os quatro do passo 1
// do plano: o plural de "1 exercício" e "6 exercícios" nos dois idiomas; os dias da rotina na ordem da
// semana do perfil, começando no domingo e na segunda; apagar e desfazer pela tela, com o motor de
// verdade, devolve a rotina e os dias (Foco da revisão 4); e uma rotina com um exercício que não existe
// mais mostra "Exercício desconhecido" na linha, sem derrubar a tela, com o superset dito no rótulo do
// VoiceOver (Foco da revisão 1). Os dois das Notas da issue (achados do QA do PR #108): a nota é cortada
// pelo utf16.count, como o motor mede os 500 do NOTE_MAX; e uma carga acima do limite da unidade abre
// como está, mas o editor só manda de volta um valor dentro do limite. Os do QA do PR #115: duas
// remoções seguidas e as ações depois de mover acham a linha pelo id; as repetições por lado andam de 2
// em 2; o campo da nota volta para o texto cortado; a faixa do desfazer guarda o prazo; e o editor cai
// no estado de erro quando a leitura falha. Os da issue #118: a edição de um exercício acha o slot pelo
// id no motor a cada toque, e um slot que saiu não grava em outro; apagar e reordenar em seguida move a
// rotina certa, e o reordenar acha as rotinas pelo id quando a lista mudou por baixo. O do achado 1 do QA
// do PR #122: com o exercício repetido, a cópia aberta que sai por baixo não leva a edição para a outra.
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexDesign
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct RoutineEditorModelTests {
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

  // A tela da lista de rotinas, com as ações indo direto ao motor.
  func screen(_ engine: HexEngine) -> RoutinesScreen {
    RoutinesScreen(engine: engine, locale: portuguese) { try await engine.apply($0) }
  }

  @Test func theExerciseCountHasItsPluralInBothLanguages() {
    let pt = RoutineEditorText(locale: portuguese), en = RoutineEditorText(locale: english)
    #expect(pt.exercises(1) == "1 exercício")
    #expect(pt.exercises(6) == "6 exercícios")
    #expect(en.exercises(1) == "1 exercise")
    #expect(en.exercises(6) == "6 exercises")
    // Sem exercício, as duas línguas dizem que não há nenhum, e o 0 do português não fica no singular.
    #expect(pt.exercises(0) == "Nenhum exercício")
    #expect(en.exercises(0) == "No exercises")
  }

  @Test func theDaysFollowTheWeekStartOfTheProfile() async throws {
    let engine = try await engine()
    let id = try #require(try await engine.apply(.createRoutine(name: "Peito")).id)
    _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0025", "0043", "0032", "0027", "1162", "0652"], at: nil))
    // Quinta e domingo, gravados nessa ordem.
    _ = try await engine.apply(.setWeekDay(day: 4, routineIDs: [id]))
    _ = try await engine.apply(.setWeekDay(day: 0, routineIDs: [id]))
    for (weekStart, pt, en) in [(0, "Dom, Qui", "Sun, Thu"), (1, "Qui, Dom", "Thu, Sun")] {
      _ = try await engine.apply(.setSetting(.weekStart(weekStart)))
      let routines = try await engine.routines()
      let row = try #require(RoutineEditorModel(routines: routines, weekStart: weekStart, text: RoutineEditorText(locale: portuguese)).rows.first)
      #expect(row.days == pt, "semana começando em \(weekStart)")
      #expect(row.exercises == "6 exercícios")
      #expect(row.spoken.hasPrefix("Peito, 6 exercícios, "), "o VoiceOver diz o nome, a contagem e os dias")
      let english = RoutineEditorModel(routines: routines, weekStart: weekStart, text: RoutineEditorText(locale: english))
      #expect(english.rows.first?.days == en)
    }
  }

  @Test func deletingAndUndoingWithTheRealEngineBringsBackTheRoutineAndItsDays() async throws {  // Foco da revisão 4
    let engine = try await engine()
    #expect(try await engine.routines().isEmpty)
    let id = try #require(try await engine.apply(.createRoutine(name: "Costas")).id)
    _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0027", "0652"], at: nil))
    _ = try await engine.apply(.setWeekDay(day: 1, routineIDs: [id]))
    _ = try await engine.apply(.setWeekDay(day: 4, routineIDs: [id]))
    let before = try await engine.routines()
    let screen = screen(engine)
    await screen.load()
    #expect(screen.rows.map(\.days) == ["Seg, Qui"])

    await screen.delete(id).value
    // Some da lista e dos dias na hora, e a faixa "Rotina apagada" fica com o desfazer.
    #expect(screen.rows.isEmpty)
    #expect(try await engine.routines().isEmpty)
    #expect(try await engine.week().days.allSatisfy { $0.routineIds.isEmpty })
    let undo = try #require(screen.undo)
    #expect(undo.message == "Rotina apagada")
    // O que o "Desfazer" aplica é o restoreRoutine com o snapshot do routine.delete.
    guard case .restoreRoutine = undo.action else { Issue.record("o desfazer não é um restoreRoutine: \(undo.action)"); return }

    await screen.performUndo()
    #expect(screen.undo == nil)
    #expect(try await engine.routines() == before)
    #expect(screen.rows.map(\.name) == ["Costas"])
    #expect(screen.rows.map(\.days) == ["Seg, Qui"])
  }

  @Test func aRoutineWithAnUnknownExerciseShowsUnknownExerciseOnItsRow() async throws {  // Foco da revisão 1
    // Um documento de outro aparelho: um exercício que não existe aqui, em superset com o supino, e uma
    // chave que o HexGym não conhece.
    let engine = try await engine(#"""
      {"x-futuro":1,"routines":[{"id":"r1","name":"Mista","emoji":"💪","ex":[
        {"id":"nao-existe","sets":3,"reps":10,"sg":"sg-0-1"},
        {"id":"0025","sets":3,"reps":8,"weight":60,"sg":"sg-0-1"},
        {"id":"0043","sets":5,"reps":5}]}]}
      """#)
    let model = RoutineEditorModel(routines: try await engine.routines(), weekStart: 1, text: RoutineEditorText(locale: portuguese))
    #expect(model.rows.first?.exercises == "3 exercícios")
    #expect(model.rows.first?.symbol == "figure.arms.open")
    let editor = try #require(model.editor("r1"))
    let unknown = editor.slots[0], bench = editor.slots[1], squat = editor.slots[2]
    #expect(unknown.name == "Exercício desconhecido")
    #expect(!unknown.known)
    #expect(unknown.setsReps == "3 × 10")
    #expect(bench.known)
    // As duas linhas do superset levam a marca na lateral, e o VoiceOver diz com quem.
    #expect(unknown.superset == .first)
    #expect(bench.superset == .last)
    #expect(squat.superset == nil)
    #expect(unknown.spoken == "Exercício desconhecido, 3 × 10, em superset com \(bench.name)")
    // A carga, quando há, vai na linha e no rótulo, por extenso.
    #expect(bench.detail == "3 × 8\u{00A0}· 60 kg")
    #expect(bench.spoken.hasPrefix("\(bench.name), 3 × 8, 60 quilogramas"))
    #expect(bench.spoken.hasSuffix(", em superset com Exercício desconhecido"))
    #expect(squat.spoken == "\(squat.name), 5 × 5")
    // O menu da linha: separar quem está no superset, juntar o último com o próximo.
    #expect(unknown.canSeparate && !unknown.canJoinNext)
    #expect(bench.canSeparate && bench.canJoinNext)
    #expect(!squat.canSeparate && !squat.canJoinNext)
    // A linha do desconhecido abre no editor do exercício como qualquer outra.
    let draft = SlotDraft(try #require(try await engine.routines().first?.slots.first), unit: .kg)
    #expect(draft.sets == 3 && draft.reps == 10)
  }

  @Test func theNoteIsCutByItsUTF16LengthLikeTheEngineMeasuresIt() async throws {
    let engine = try await engine()
    let id = try #require(try await engine.apply(.createRoutine(name: "Nota")).id)
    _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: ["0025"], at: nil))
    var draft = SlotDraft(try #require(try await engine.routines().first?.slots.first), unit: .kg)
    // 499 letras e um emoji: 500 caracteres do Swift, 501 unidades de UTF-16. O emoji não cabe.
    let emoji = String(repeating: "a", count: 499) + "😀"
    #expect(emoji.count == 500 && emoji.utf16.count == 501)
    let cutFields = draft.setNote(emoji)
    let cut = try #require(cutFields?.note)
    #expect(cut == String(repeating: "a", count: 499))
    #expect(draft.note == cut)
    // O acento em NFD: cada "é" é um caractere e duas unidades. Cabem 250, sem partir nenhum.
    let decomposed = String(repeating: "e\u{301}", count: 300)
    let accentFields = draft.setNote(decomposed)
    let accents = try #require(accentFields?.note)
    #expect(accents.utf16.count == 500 && accents.count == 250)
    // O motor aceita a nota cortada e recusa a inteira, com o TypeError do NOTE_MAX.
    _ = try await engine.apply(.updateSlot(routineID: id, index: 0, fields: SlotFields(note: accents)))
    #expect(try await engine.routines().first?.slots.first?.note == accents)
    await #expect(throws: EngineError.self) {
      _ = try await engine.apply(.updateSlot(routineID: id, index: 0, fields: SlotFields(note: decomposed)))
    }
  }

  @Test func aLoadAboveTheUnitLimitOpensButGoesBackWithinIt() async throws {
    // 1000 kg trocados para lb viram 2204,5 lb, acima dos 1.000 do slot.update.
    let engine = try await engine(#"""
      {"unit":"lb","routines":[{"id":"r1","name":"Pesada","emoji":"barbell","ex":[{"id":"0032","sets":3,"reps":5,"weight":2204.5}]}]}
      """#)
    let slot = try #require(try await engine.routines().first?.slots.first)
    #expect(slot.weight == 2204.5)
    var draft = SlotDraft(slot, unit: .lb)
    // Abre como está.
    #expect(draft.weight == 2204.5)
    // Mudar as séries não manda a carga.
    let setsFields = draft.stepSets(.up)
    let sets = try #require(setsFields)
    #expect(sets == SlotFields(sets: 4))
    _ = try await engine.apply(.updateSlot(routineID: "r1", index: 0, fields: sets))
    // Um toque na carga, para cima ou para baixo, volta ao limite, e o motor aceita.
    let downFields = draft.stepLoad(.down)
    let down = try #require(downFields)
    #expect(down == SlotFields(weight: 1000))
    #expect(draft.weight == 1000)
    _ = try await engine.apply(.updateSlot(routineID: "r1", index: 0, fields: down))
    let upFields = draft.stepLoad(.up)
    #expect(upFields == nil, "no limite, o toque para cima não manda nada")
    let after = try #require(try await engine.routines().first?.slots.first)
    #expect(after.weight == 1000 && after.sets == 4)
    // O mesmo valor de fora nunca vai de volta: o motor o recusaria.
    await #expect(throws: EngineError.self) {
      _ = try await engine.apply(.updateSlot(routineID: "r1", index: 0, fields: SlotFields(weight: 2204.5)))
    }
  }

  // Os achados do QA do PR #115.

  // O editor de uma rotina nova com estes exercícios, com as ações indo direto ao motor.
  func editor(_ engine: HexEngine, _ exerciseIDs: [String]) async throws -> RoutineEditorScreen {
    let id = try #require(try await engine.apply(.createRoutine(name: "Teste")).id)
    _ = try await engine.apply(.addExercises(routineID: id, exerciseIDs: exerciseIDs, at: nil))
    let screen = RoutineEditorScreen(id: id, engine: engine, locale: portuguese) { try await engine.apply($0) }
    await screen.load()
    return screen
  }

  @Test func twoRemovalsInARowTakeOutTheTwoRowsTapped() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["1060", "0025", "1048"])
    let rows = try #require(screen.content?.slots)
    #expect(rows.map(\.exerciseID) == ["1060", "0025", "1048"])
    // Dois toques seguidos, sem esperar o motor: o segundo acha o 0025 na posição 0 da tela de agora.
    let first = screen.remove(rows[0].id)
    #expect(screen.content?.slots.map(\.exerciseID) == ["0025", "1048"])
    #expect(screen.position(of: rows[1].id) == 0)
    let second = screen.remove(rows[1].id)
    #expect(screen.content?.slots.map(\.exerciseID) == ["1048"])
    await first?.value
    await second?.value
    #expect(try await engine.routines().first?.slots.map(\.id) == ["1048"])
    #expect(screen.content?.slots.map(\.exerciseID) == ["1048"])
    // Uma linha que já saiu não manda nada.
    #expect(screen.remove(rows[0].id) == nil)
  }

  @Test func theRowActionsFindTheRowByItsIDAfterAMove() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["1060", "0025", "1048"])
    let rows = try #require(screen.content?.slots)
    // O 1048 vai para o começo e, logo depois, sem esperar o motor, o 1060 (que estava na posição 0 e
    // agora está na 1) junta com o próximo, o 0025.
    let moved = screen.move(from: IndexSet(integer: 2), to: 0)
    let joined = screen.joinWithNext(rows[0].id)
    await moved?.value
    await joined?.value
    let slots = try #require(try await engine.routines().first?.slots)
    #expect(slots.map(\.id) == ["1048", "1060", "0025"])
    #expect(slots[0].superset == nil)
    #expect(slots[1].superset != nil && slots[1].superset == slots[2].superset)
    // O SlotEditor abre o exercício da linha, onde ela estiver agora.
    let editor = try #require(await screen.slotEditor(rows[2].id))
    #expect(editor.index == 0)
    #expect(editor.draft.reps == 20)
  }

  @Test func oneSideRepsStepByTwoAndTheOthersByOne() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["1048", "0025"])
    let slots = try #require(try await engine.routines().first?.slots)
    #expect(slots.map(\.repStep) == [2, 1])
    // O 1048 é feito um lado de cada vez: de 20 para 22, e de volta.
    var side = SlotDraft(slots[0], unit: .kg)
    #expect(side.reps == 20)
    let upFields = side.stepReps(.up)
    #expect(upFields == SlotFields(reps: 22))
    let up = try #require(upFields)
    _ = try await engine.apply(.updateSlot(routineID: screen.id, index: 0, fields: up))
    #expect(try await engine.routines().first?.slots.first?.reps == 22)
    let downFields = side.stepReps(.down)
    #expect(downFields == SlotFields(reps: 20))
    // O de dois lados anda de 1 em 1.
    var both = SlotDraft(slots[1], unit: .kg)
    let bothFields = both.stepReps(.up)
    #expect(bothFields == SlotFields(reps: both.reps))
    #expect(both.reps == (slots[1].reps ?? 10) + 1)
    // Um ímpar vindo do openGym anda de 2 em 2 também, como lá; o 100 continua sendo o teto.
    let odd = try await self.engine(#"""
      {"routines":[{"id":"r1","name":"Lados","emoji":"dumbbell","ex":[{"id":"1048","sets":3,"reps":11,"side":true},{"id":"1048","sets":3,"reps":99,"side":true}]}]}
      """#)
    let oddSlots = try #require(try await odd.routines().first?.slots)
    var eleven = SlotDraft(oddSlots[0], unit: .kg)
    let elevenFields = eleven.stepReps(.up)
    #expect(elevenFields == SlotFields(reps: 13))
    var top = SlotDraft(oddSlots[1], unit: .kg)
    let topFields = top.stepReps(.up)
    #expect(topFields == SlotFields(reps: 100))
  }

  @Test func typingPastTheLimitPutsTheCutNoteBackInTheField() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["0025"])
    let full = String(repeating: "a", count: 500)
    let editor = try #require(await screen.slotEditor(at: 0))
    #expect(editor.typeNote(full) == full)
    // Mais três letras no fim: a nota não muda, mas o campo volta para as 500 unidades.
    let typed = full + "bcd"
    let shown = editor.typeNote(typed)
    #expect(shown == full && shown != typed)
    #expect(shown.utf16.count == 500)
    await editor.flush()
    #expect(try await engine.routines().first?.slots.first?.note == full)
  }

  @Test func theUndoBannerKeepsItsDeadlineAcrossALeaveAndComeBack() async throws {
    let now = ContinuousClock.now
    let undo = RoutineUndo(id: 1, message: "Rotina apagada", action: .deleteRoutine(id: "r1"), created: now - .seconds(3))
    // A faixa que volta 3 s depois fica os 2 s que faltavam (12 s com o VoiceOver), e não 5 s de novo.
    #expect(undo.remaining(voiceOver: false, now: now) == .seconds(2))
    #expect(undo.remaining(voiceOver: true, now: now) == .seconds(12))
    // Passado o prazo, sai na hora.
    #expect(undo.remaining(voiceOver: false, now: now + .seconds(5)) == .zero)
    #expect(undo.remaining(voiceOver: true, now: now + .seconds(20)) == .zero)
    // O VoiceOver anuncia a faixa uma vez só.
    let screen = screen(try await engine())
    #expect(screen.shouldAnnounce(1))
    #expect(!screen.shouldAnnounce(1))
    #expect(screen.shouldAnnounce(2))
  }

  // Os da issue #118: a edição de um exercício e a lista de rotinas acham o item pelo id na hora da ação.

  @Test func anEditWithTheSheetOpenGoesToTheSlotWhereverItIsNow() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["1060", "0025", "1048"])
    let rows = try #require(screen.content?.slots)
    let before = try #require(try await engine.routines().first?.slots)
    let editor = try #require(await screen.slotEditor(rows[2].id))
    #expect(editor.index == 2)
    // Com a tela aberta, outro aparelho põe o 1048 no começo: o 0025 fica na posição 2.
    _ = try await engine.apply(.moveSlot(routineID: screen.id, from: 2, to: 0))
    editor.stepSets(.up)
    await editor.flush()
    let after = try #require(try await engine.routines().first?.slots)
    #expect(after.map(\.id) == ["1048", "1060", "0025"])
    #expect(after[0].sets == (before[2].sets ?? 0) + 1, "a série a mais vai para o 1048")
    #expect(after[1].sets == before[0].sets)
    #expect(after[2].sets == before[1].sets, "o 0025, que agora está na posição 2, não muda")
  }

  @Test func anEditToASlotThatIsGoneWritesNothing() async throws {
    let engine = try await engine()
    let screen = try await editor(engine, ["1060", "0025", "1048"])
    let rows = try #require(screen.content?.slots)
    let editor = try #require(await screen.slotEditor(rows[1].id))
    // Com a tela aberta, o 0025 sai da rotina: o 1048 fica na posição 1, a de quando a tela abriu.
    _ = try await engine.apply(.removeSlot(routineID: screen.id, index: 1))
    let before = try #require(try await engine.routines().first?.slots)
    editor.stepSets(.up)
    editor.stepLoad(.up)
    _ = editor.typeNote("Não é este")
    await editor.flush()
    #expect(try await engine.routines().first?.slots == before, "nenhum outro exercício muda")
  }

  @Test func aRepeatedExerciseWhoseOpenCopyLeavesDoesNotWriteToTheOtherCopy() async throws {  // achado 1 do QA do PR #122
    let engine = try await engine()
    let screen = try await editor(engine, ["0025", "1048", "0025"])
    let rows = try #require(screen.content?.slots)
    #expect(rows.map(\.id) == ["0025#0", "1048#0", "0025#1"])
    let editor = try #require(await screen.slotEditor(rows[0].id))
    // Com a tela da primeira cópia aberta, ela sai por baixo: a outra cópia passa a ser a "0025#0".
    _ = try await engine.apply(.removeSlot(routineID: screen.id, index: 0))
    let before = try #require(try await engine.routines().first?.slots)
    editor.stepSets(.up)
    _ = editor.typeNote("Só a primeira")
    await editor.flush()
    #expect(try await engine.routines().first?.slots == before, "a outra cópia não muda")
    // Uma cópia que entra por baixo, antes da aberta, também para a edição, em vez de gravar na cópia
    // que entrou.
    await screen.load()
    #expect(screen.content?.slots.map(\.id) == ["1048#0", "0025#0"])
    let second = try #require(await screen.slotEditor("0025#0"))
    _ = try await engine.apply(.addExercises(routineID: screen.id, exerciseIDs: ["0025"], at: 0))
    let added = try #require(try await engine.routines().first?.slots)
    second.stepSets(.up)
    await second.flush()
    #expect(try await engine.routines().first?.slots == added)
  }

  // Uma tela da lista em que o routine.delete demora a chegar ao motor, como num aparelho lento.
  func slowDeleteScreen(_ engine: HexEngine) -> RoutinesScreen {
    RoutinesScreen(engine: engine, locale: portuguese) { action in
      if case .deleteRoutine = action { try await Task.sleep(for: .milliseconds(150)) }
      return try await engine.apply(action)
    }
  }

  @Test func deletingAndThenReorderingMovesTheRightRoutine() async throws {
    let engine = try await engine()
    var ids: [String] = []
    for name in ["A", "B", "C"] { ids.append(try #require(try await engine.apply(.createRoutine(name: name)).id)) }
    let screen = slowDeleteScreen(engine)
    await screen.load()
    #expect(screen.rows.map(\.name) == ["A", "B", "C"])
    // Apaga o A e, sem esperar o motor, leva o C para o começo da lista que sobrou.
    let deleted = screen.delete(ids[0])
    #expect(screen.rows.map(\.name) == ["B", "C"])
    let moved = screen.move(from: IndexSet(integer: 1), to: 0)
    #expect(screen.rows.map(\.name) == ["C", "B"])
    await deleted.value
    await moved?.value
    #expect(try await engine.routines().map(\.name) == ["C", "B"])
    #expect(screen.rows.map(\.name) == ["C", "B"])
    #expect(screen.undo != nil, "o desfazer do apagar continua valendo")
  }

  @Test func reorderingFindsTheRoutinesByIDWhenTheListChangedUnderneath() async throws {
    let engine = try await engine()
    var ids: [String] = []
    for name in ["A", "B", "C"] { ids.append(try #require(try await engine.apply(.createRoutine(name: name)).id)) }
    let screen = screen(engine)
    await screen.load()
    // Outro aparelho leva o C para o começo, e a tela ainda mostra A, B, C.
    _ = try await engine.apply(.moveRoutine(from: 2, to: 0))
    // A pessoa leva o A para depois do B: no motor, ele vai para depois do B também.
    await screen.move(from: IndexSet(integer: 0), to: 2)?.value
    #expect(try await engine.routines().map(\.name) == ["C", "B", "A"])
    #expect(screen.rows.map(\.name) == ["C", "B", "A"])
  }

  @Test func theMoveTargetComesFromTheNeighboursOnScreen() {
    let ids = ["a", "b", "c", "d"]
    // Para o começo: a posição 0.
    #expect(RoutineEditorModel.routineMove("c", after: nil, before: "a", in: ids) == RoutineMove(from: 2, to: 0))
    // Para depois do vizinho de cima.
    #expect(RoutineEditorModel.routineMove("a", after: "c", before: "d", in: ids) == RoutineMove(from: 0, to: 2))
    // O vizinho de cima não está mais no motor: antes do de baixo.
    #expect(RoutineEditorModel.routineMove("d", after: "x", before: "b", in: ids) == RoutineMove(from: 3, to: 1))
    // A rotina saiu, ou nenhum vizinho ficou, ou já está no lugar: nada vai.
    #expect(RoutineEditorModel.routineMove("x", after: nil, before: "a", in: ids) == nil)
    #expect(RoutineEditorModel.routineMove("a", after: "x", before: "y", in: ids) == nil)
    #expect(RoutineEditorModel.routineMove("b", after: "a", before: "c", in: ids) == nil)
  }

  @Test func theRowIDCountsTheRepeatsOfTheSameExercise() {
    #expect(RoutineEditorModel.position(of: "0025#1", in: ["0025", "1048", "0025"]) == 2)
    #expect(RoutineEditorModel.position(of: "1048#0", in: ["0025", "1048", "0025"]) == 1)
    #expect(RoutineEditorModel.position(of: "0025#2", in: ["0025", "1048", "0025"]) == nil)
    #expect(RoutineEditorModel.rowIDs(["0025", "1048", "0025"]) == ["0025#0", "1048#0", "0025#1"])
  }

  @Test func anEditorWhoseReadFailsShowsTheErrorAndNotTheSpinner() async {
    // Um motor que não carregou: toda leitura falha.
    let engine = HexEngine(language: "pt-BR")
    let screen = RoutineEditorScreen(id: "r1", engine: engine, locale: portuguese) { try await engine.apply($0) }
    #expect(screen.phase == .loading)
    await screen.load()
    #expect(screen.phase == .failed)
  }
}
