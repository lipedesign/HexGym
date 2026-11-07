// Os testes do editor de rotina sem tela (Task 11 do plano da fase 2, issue #98). Os quatro do passo 1
// do plano: o plural de "1 exercício" e "6 exercícios" nos dois idiomas; os dias da rotina na ordem da
// semana do perfil, começando no domingo e na segunda; apagar e desfazer pela tela, com o motor de
// verdade, devolve a rotina e os dias (Foco da revisão 4); e uma rotina com um exercício que não existe
// mais mostra "Exercício desconhecido" na linha, sem derrubar a tela, com o superset dito no rótulo do
// VoiceOver (Foco da revisão 1). Os dois das Notas da issue (achados do QA do PR #108): a nota é cortada
// pelo utf16.count, como o motor mede os 500 do NOTE_MAX; e uma carga acima do limite da unidade abre
// como está, mas o editor só manda de volta um valor dentro do limite.
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
}
