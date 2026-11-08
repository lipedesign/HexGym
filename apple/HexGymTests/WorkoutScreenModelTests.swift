// Os testes da tela do treino sem tela (Task 8 do plano da fase 3, issue #137), os seis do passo 1 de lá:
// o título do painel e "Série 2 de 3"; o tempo abaixo e acima de uma hora; a fala de uma linha feita e
// de uma por fazer, em kg e em lb; as entradas por modo (repetições, tempo) e escala (nenhuma, RIR,
// RPE); a fala do superset; e, com o veio-do-opengym, toda linha com texto e marca, sem que uma linha
// estranha derrube o modelo (Foco da revisão 4). O sétimo é o da issue #161: a série com tempo por lado em
// pares, com o lado, como o openGym mostra, e a faixa "8-12" com o hífen comum.
//
// O primeiro, o sexto e o sétimo usam o motor de verdade, com os documentos preparados (FixtureLoader). O
// primeiro também confere, pelo WorkoutScreen, que o painel acompanha a série que o motor diz depois
// de "Registrar série" e que toques rápidos nas entradas chegam todos ao motor, um por um, na ordem.
//
// Os textos que o openGym já tem vêm dele (o pacote pt-BR, que herda do pt): "Série 2 de 3" ('Set {0}
// of {1}'), "Aquecimento", "Série 2" ('Set {0}'), "Série 2 concluída" ('Set {0} done'), "Registrar
// série" ('Log set'), "Próxima série" ('Next set'), "Todas as séries feitas" ('All sets done') e "Ainda
// sem exercícios." ('No exercises yet.').
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO \
//     -only-testing:HexGymTests/WorkoutScreenModelTests test

import Foundation
import HexDesign
import HexEngine
import HexStore
import Testing
@testable import HexGym

@Suite @MainActor struct WorkoutScreenModelTests {
  let portuguese = WorkoutText(locale: Locale(identifier: "pt-BR"))
  let english = WorkoutText(locale: Locale(identifier: "en"))
  let language = Locale(identifier: "pt-BR")

  // O AppModel aberto no documento preparado, levado para agora, numa pasta temporária.
  func opened(_ fixture: String, folder: TemporaryFolder) async throws -> AppModel {
    try FixtureLoader.document(named: fixture).write(to: folder.url.appending(path: "state.json"))
    let model = AppModel(engine: HexEngine(language: "pt-BR"), store: DocumentStore(directory: folder.url))
    await model.start()
    #expect(model.state.origin == .opened)
    await model.session.refresh()
    return model
  }

  // Um treino como o motor manda, com as entradas dadas em JSON; as horas em ms.
  static func workout(unit: String = "kg", effort: String = "none", cur: Int = 0, next: String = #"{"entry":0,"set":1}"#,
                      done: Int = 1, total: Int = 3, entries: [String]) throws -> ActiveWorkout {
    let text = #"""
      {"id":"w","name":"Push","start":1794224040000,"unit":"\#(unit)","effort":"\#(effort)","cur":\#(cur),"done":\#(done),
       "total":\#(total),"rest":null,"next":\#(next),"entries":[\#(entries.joined(separator: ","))]}
      """#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return try decoder.decode(ActiveWorkout.self, from: Data(text.utf8))
  }

  // Uma entrada, com as séries dadas.
  static func entry(_ index: Int, name: String = "supino com barra", mode: String = "reps", sg: String? = nil, letter: String? = nil,
                    target: String = "3 × 8 · 60 kg", known: Bool = true, sets: [String]) -> String {
    let sg = sg.map { #""\#($0)""# } ?? "null", letter = letter.map { #""\#($0)""# } ?? "null"
    return #"""
      {"index":\#(index),"id":"e\#(index)","name":"\#(name)","known":\#(known),"mode":"\#(mode)","sg":\#(sg),"sgLetter":\#(letter),
       "target":"\#(target)","increment":2.5,"sets":[\#(sets.joined(separator: ","))]}
      """#
  }

  // Uma série; o line é o que o motor escreve, e o side, o lado de uma série com tempo por lado (L ou R).
  static func set(_ index: Int, w: String = "60", r: String = "8", sec: String = "null", rir: String = "null", rpe: String = "null",
                  done: Bool = false, warmup: Bool = false, kind: String = "normal", side: String? = nil,
                  line: String = "60 kg × 8") -> String {
    let side = side.map { #""\#($0)""# } ?? "null"
    return #"""
      {"index":\#(index),"w":\#(w),"r":\#(r),"sec":\#(sec),"rir":\#(rir),"rpe":\#(rpe),"done":\#(done),"warmup":\#(warmup),
       "kind":"\#(kind)","side":\#(side),"line":"\#(line)"}
      """#
  }

  func model(_ workout: ActiveWorkout, selection: WorkoutRef? = nil, _ text: WorkoutText? = nil) -> WorkoutScreenModel {
    WorkoutScreenModel(workout: workout, selection: selection, text: text ?? portuguese, language: language)
  }

  @Test func thePanelSaysTheExerciseAndSetNOfMAndFollowsTheNextSet() async throws {
    // O supino com três séries de trabalho e a segunda por fazer: "Supino com barra · Série 2 de 3",
    // com a primeira letra do nome em maiúscula no idioma do motor.
    let three = try Self.workout(entries: [Self.entry(0, sets: [Self.set(0, done: true), Self.set(1), Self.set(2)])])
    #expect(model(three).panel?.title == "Supino com barra\u{00A0}· Série 2 de 3")
    #expect(model(three, english).panel?.title == "Supino com barra\u{00A0}· Set 2 of 3")
    #expect(model(three).panel?.ref == WorkoutRef(entry: 0, set: 1))
    #expect(model(three).panel?.buttonLabel == "Registrar série"); #expect(model(three).panel?.action == .log)
    // O aquecimento não conta nas séries de trabalho: "Aquecimento 1", e a de trabalho, "Série 1 de 2".
    let warm = try Self.workout(next: #"{"entry":0,"set":0}"#, entries: [Self.entry(0, sets: [
      Self.set(0, w: "40", r: "5", warmup: true, line: "40 kg × 5"), Self.set(1), Self.set(2)])])
    #expect(model(warm).panel?.title == "Supino com barra\u{00A0}· Aquecimento 1")
    #expect(model(warm, selection: WorkoutRef(entry: 0, set: 1)).panel?.title == "Supino com barra\u{00A0}· Série 1 de 2")
    #expect(model(warm, selection: WorkoutRef(entry: 0, set: 2), english).panel?.title == "Supino com barra\u{00A0}· Set 2 of 2")
    // Na tela, o título vai em duas linhas: o nome, e "Série 2 de 3" ou "Aquecimento 1" numa linha própria,
    // que nunca quebra no meio (achado 6 do QA da #160).
    #expect(model(three).panel?.exercise == "Supino com barra"); #expect(model(three).panel?.setLabel == "Série 2 de 3")
    #expect(model(warm).panel?.exercise == "Supino com barra"); #expect(model(warm).panel?.setLabel == "Aquecimento 1")
    #expect(model(warm, selection: WorkoutRef(entry: 0, set: 2), english).panel?.setLabel == "Set 2 of 2")
    // Uma linha tocada é a série do painel, e a linha atual da lista; uma feita leva o botão de volta para
    // a próxima série.
    let tapped = model(three, selection: WorkoutRef(entry: 0, set: 0))
    #expect(tapped.panel?.title == "Supino com barra\u{00A0}· Série 1 de 3")
    #expect(tapped.panel?.action == .next); #expect(tapped.panel?.buttonLabel == "Próxima série")
    #expect(tapped.cards[0].rows.map(\.current) == [true, false, false])
    #expect(model(three).cards[0].rows.map(\.current) == [false, true, false])

    // Com o motor de verdade: o treino-em-andamento tem a segunda volta do superset por fazer.
    let folder = try TemporaryFolder()
    let app = try await opened("treino-em-andamento", folder: folder)
    let screen = WorkoutScreen(app: app, locale: Locale(identifier: "pt-BR"))
    await screen.ready()
    #expect(screen.model?.panel?.title == "Rosca bíceps com halteres\u{00A0}· Série 2 de 2")
    // "Registrar série" marca a série do painel, e o painel vai para a próxima que o motor diz: o supino
    // inclinado, a outra metade do superset.
    await screen.log().value
    #expect(app.session.workout?.done == 6)
    #expect(screen.model?.panel?.title == "Supino inclinado com barra\u{00A0}· Série 2 de 2")
    #expect(app.session.haptic == .setLogged)
    // Uma linha tocada (o desenvolvimento) passa a ser a do painel e o exercício atual no motor.
    await screen.select(WorkoutRef(entry: 3, set: 1)).value
    #expect(app.session.workout?.cur == 3)
    #expect(screen.model?.panel?.title == "Desenvolvimento militar em pé com barra\u{00A0}· Série 2 de 3")
    // Seis toques rápidos de "+" na carga, sem esperar a tela: o motor recebe os seis, nem um a mais nem
    // um a menos, como seis toques com a tela esperando um por um num documento igual.
    let before = try #require(app.session.workout?.entries[3].sets[1].w)
    var taps: [Task<Void, Never>] = []
    for _ in 0..<6 { taps.append(screen.step(.w, .up)) }
    for tap in taps { await tap.value }
    let other = try TemporaryFolder()
    let calm = try await opened("treino-em-andamento", folder: other)
    for _ in 0..<6 { _ = try await calm.session.perform(.stepSet(entry: 3, set: 1, field: .w, direction: .up)) }
    let expected = try #require(calm.session.workout?.entries[3].sets[1].w)
    #expect(expected > before)
    #expect(app.session.workout?.entries[3].sets[1].w == expected)
    #expect(screen.model?.panel?.load == expected)
    // Dois toques seguidos em "Registrar série" marcam a série do painel uma vez só (Foco da revisão 3):
    // o segundo chega com a mesma série, já feita, e o motor não muda nada.
    let done = try #require(app.session.workout?.done)
    let first = screen.log(), second = screen.log()
    await first.value; await second.value
    #expect(app.session.workout?.done == done + 1)
    #expect(screen.model?.panel?.title == "Desenvolvimento militar em pé com barra\u{00A0}· Série 1 de 3")
  }

  @Test func theClockShowsMinutesUnderAnHourAndHoursAbove() throws {
    #expect(WorkoutScreenModel.elapsed(0) == "0:00")
    #expect(WorkoutScreenModel.elapsed(59.9) == "0:59")
    #expect(WorkoutScreenModel.elapsed(724) == "12:04")
    #expect(WorkoutScreenModel.elapsed(3599) == "59:59")
    #expect(WorkoutScreenModel.elapsed(3600) == "1:00:00")
    #expect(WorkoutScreenModel.elapsed(3730) == "1:02:10")
    #expect(WorkoutScreenModel.elapsed(36_000 + 5) == "10:00:05")
    // Um começo no futuro (o relógio do aparelho mudou) fica em 0, nunca negativo.
    #expect(WorkoutScreenModel.elapsed(-30) == "0:00")
    // A fala do tempo, por extenso.
    #expect(WorkoutScreenModel.spokenElapsed(724, locale: Locale(identifier: "pt-BR")) == "12 minutos e 4 segundos")
    #expect(WorkoutScreenModel.spokenElapsed(3730, locale: Locale(identifier: "en")) == "1 hour, 2 minutes, 10 seconds")
    // O segundo do tempo de uma série com tempo usa o mesmo relógio.
    let timed = try Self.workout(next: #"{"entry":0,"set":0}"#, entries: [Self.entry(0, name: "prancha", mode: "time", target: "1 × 0:45", sets: [
      Self.set(0, w: "0", r: "null", sec: "45", line: "0:45")])])
    #expect(model(timed).panel?.secondsText == "0:45")
  }

  @Test func aRowSaysItsSetLoadRepsAndWhetherItIsDoneInKgAndLb() throws {
    let kg = try Self.workout(entries: [Self.entry(0, sets: [
      Self.set(0, w: "40", r: "5", done: true, warmup: true, line: "40 kg × 5"),
      Self.set(1, done: true), Self.set(2, w: "62.5", line: "62,5 kg × 8"), Self.set(3, rir: "2")])])
    let rows = model(kg).cards[0].rows
    #expect(rows.map(\.number) == ["1", "1", "2", "3"])
    #expect(rows.map(\.warmup) == [true, false, false, false])
    #expect(rows[0].spoken == "Aquecimento 1, 40 quilogramas, 5 repetições, feito")
    #expect(rows[1].spoken == "Série 1, 60 quilogramas, 8 repetições, feita")
    #expect(rows[2].spoken == "Série 2, 62,5 quilogramas, 8 repetições")
    // O esforço registrado entra na fala, na escala da série.
    #expect(rows[3].spoken == "Série 3, 60 quilogramas, 8 repetições, RIR 2")
    #expect(rows.map(\.line) == ["40 kg × 5", "60 kg × 8", "62,5 kg × 8", "60 kg × 8"])
    // A marca diz a série, e manda o contrário do que ela está.
    #expect(rows[1].markLabel == "Série 1 concluída"); #expect(rows[0].markLabel == "Aquecimento 1 concluído")
    #expect(rows[1].mark == WorkoutSetMark(entry: 0, set: 1, done: false))
    #expect(rows[2].mark == WorkoutSetMark(entry: 0, set: 2, done: true))

    let lb = try Self.workout(unit: "lb", entries: [Self.entry(0, target: "3 × 5 · 135 lb", sets: [
      Self.set(0, w: "135", r: "5", done: true, line: "135 lb × 5"), Self.set(1, w: "1", r: "1", line: "1 lb × 1")])])
    #expect(model(lb).cards[0].rows.map(\.spoken) == ["Série 1, 135 libras, 5 repetições, feita", "Série 2, 1 libra, 1 repetição"])
    #expect(model(lb, english).cards[0].rows.map(\.spoken) == ["Set 1, 135 pounds, 5 repetitions, done", "Set 2, 1 pound, 1 repetition"])
    #expect(model(kg, english).cards[0].rows[0].spoken == "Warm-up 1, 40 kilograms, 5 repetitions, done")
    #expect(model(kg, english).cards[0].rows[1].markLabel == "Set 1 done")
    #expect(model(lb).panel?.unit == .lb); #expect(model(kg).panel?.unit == .kg)
    // No cardio, o VoiceOver não lê o "@" do texto do motor como "arroba": "20 min a 9 km/h" (achado 8 do
    // QA da #160). A linha na tela fica como o motor escreve.
    let cardio = try Self.workout(entries: [Self.entry(0, name: "esteira", mode: "cardio", target: "1 × 20 min @ 9 km/h", sets: [
      Self.set(0, w: "null", r: "null", kind: "cardio", line: "20 min @ 9 km/h · 2% de inclinação")])])
    #expect(model(cardio).cards[0].rows[0].spoken == "Série 1, 20 min a 9 km/h · 2% de inclinação")
    #expect(model(cardio, english).cards[0].rows[0].spoken == "Set 1, 20 min at 9 km/h · 2% de inclinação")
    #expect(model(cardio).cards[0].rows[0].line == "20 min @ 9 km/h · 2% de inclinação")
  }

  @Test func thePanelShowsTheInputsForTheModeAndTheScale() throws {
    let sets = [Self.set(0, done: true), Self.set(1, rir: "2", rpe: "8.5")]
    // Repetições: a carga e as repetições, e o esforço só quando o perfil usa, na escala dele, com o valor
    // da série.
    let none = model(try Self.workout(effort: "none", entries: [Self.entry(0, sets: sets)])).panel
    #expect(none?.inputs == .reps(effort: nil)); #expect(none?.load == 60); #expect(none?.reps == 8)
    let rir = model(try Self.workout(effort: "rir", entries: [Self.entry(0, sets: sets)])).panel
    #expect(rir?.inputs == .reps(effort: .rir)); #expect(rir?.effort == 2)
    let rpe = model(try Self.workout(effort: "rpe", entries: [Self.entry(0, sets: sets)])).panel
    #expect(rpe?.inputs == .reps(effort: .rpe)); #expect(rpe?.effort == 8.5)
    // Sem esforço registrado, a entrada fica vazia.
    let empty = model(try Self.workout(effort: "rpe", entries: [Self.entry(0, sets: [Self.set(0, done: true), Self.set(1)])])).panel
    #expect(empty?.inputs == .reps(effort: .rpe)); #expect(empty?.effort == nil)
    // Tempo: os segundos, sem carga nem esforço, também com o perfil usando esforço.
    let time = model(try Self.workout(effort: "rir", next: #"{"entry":0,"set":0}"#, entries: [Self.entry(0, name: "prancha", mode: "time", sets: [
      Self.set(0, w: "0", r: "null", sec: "60", line: "1:00")])])).panel
    #expect(time?.inputs == .time); #expect(time?.seconds == 60); #expect(time?.secondsText == "1:00")
    #expect(time?.spokenSeconds == "60 segundos")
    // O cardio, o drop set, o rest-pause e a série com lados mostram o texto do motor, sem entradas.
    for (mode, kind) in [("cardio", "normal"), ("reps", "drop"), ("reps", "restpause"), ("reps", "sides")] {
      let line = model(try Self.workout(effort: "rir", next: #"{"entry":0,"set":0}"#, entries: [Self.entry(0, mode: mode, sets: [
        Self.set(0, kind: mode == "cardio" ? "cardio" : kind, line: "80×4 ↘ 60×4")])])).panel
      #expect(line?.inputs == .line, "\(mode) \(kind)"); #expect(line?.line == "80×4 ↘ 60×4")
    }
  }

  @Test func aSupersetSaysItsLetterAndItsPlace() throws {
    let pair = [Self.set(0, done: true), Self.set(1)]
    let workout = try Self.workout(next: #"{"entry":1,"set":1}"#, entries: [
      Self.entry(0, sets: pair),
      Self.entry(1, name: "rosca", sg: "g1", letter: "A", sets: pair), Self.entry(2, name: "tríceps", sg: "g1", letter: "A", sets: pair),
      Self.entry(3, name: "remada", sets: pair),
      Self.entry(4, name: "elevação", sg: "g2", letter: "B", sets: pair), Self.entry(5, name: "crucifixo", sg: "g2", letter: "B", sets: pair),
      Self.entry(6, name: "abdominal", sg: "g2", letter: "B", sets: pair),
    ])
    let cards = model(workout).cards
    #expect(cards.map { $0.superset?.spoken } == [nil, "Superset A, 1 de 2", "Superset A, 2 de 2", nil,
                                                    "Superset B, 1 de 3", "Superset B, 2 de 3", "Superset B, 3 de 3"])
    #expect(cards.map { $0.superset?.label } == [nil, "Superset A", "Superset A", nil, "Superset B", "Superset B", "Superset B"])
    #expect(cards.map { $0.superset?.first } == [nil, true, false, nil, true, false, false])
    #expect(cards.map { $0.superset?.last } == [nil, false, true, nil, false, false, true])
    #expect(model(workout, english).cards[2].superset?.spoken == "Superset A, 2 of 2")
    // O cartão da série do painel é o atual.
    #expect(cards.map(\.current) == [false, true, false, false, false, false, false])
    // Um sg sozinho (sem o vizinho, a letra do motor nula) não é superset.
    let alone = try Self.workout(entries: [Self.entry(0, sg: "g1", letter: nil, sets: pair)])
    #expect(model(alone).cards[0].superset == nil)
  }

  @Test func everyRowFromOpenGymHasTextAndAMarkAndNothingOddBreaksTheModel() async throws {   // Foco da revisão 4
    let folder = try TemporaryFolder()
    let app = try await opened("veio-do-opengym", folder: folder)
    let workout = try #require(app.session.workout)
    let built = model(workout)
    let rows = built.cards.flatMap(\.rows)
    #expect(rows.count == 10)
    for row in rows {
      #expect(!row.line.isEmpty, "\(row.ref)"); #expect(!row.spoken.isEmpty, "\(row.ref)"); #expect(!row.markLabel.isEmpty, "\(row.ref)")
      #expect(row.mark == WorkoutSetMark(entry: row.ref.entry, set: row.ref.set, done: !row.done))
    }
    // O aquecimento, o drop set, o rest-pause, os lados, o cardio, a série com tempo e o exercício que não
    // existe neste aparelho, cada um com o texto do motor.
    #expect(built.cards.map(\.known) == [true, true, true, true, true, false])
    #expect(built.cards[5].name == "Exercício desconhecido")
    #expect(rows[0].spoken == "Aquecimento 1, 40 quilogramas, 5 repetições, feito")
    #expect(rows[3].line == "80×4 ↘ 60×4"); #expect(rows[3].spoken == "Série 3, 80×4 ↘ 60×4")
    #expect(rows[4].spoken == "Série 1, 60×5+3")
    // O lado ainda não feito vem com o hífen comum, e não com a meia-risca do setLabel do openGym (issue #161).
    #expect(rows[5].spoken == "Série 1, E 10×8 · D -"); #expect(rows[5].line == "E 10×8 · D -")
    #expect(rows[7].spoken == "Série 1, 20 min a 9 km/h · 2% de inclinação")
    #expect(rows[8].spoken == "Série 1, 45 segundos")
    // O alvo sem repetições, que o exLine do openGym escrevia "1 × undefined · 0/lado", vem do motor sem as
    // repetições (issue #161).
    #expect(built.cards[2].target == "1 série · por lado"); #expect(built.cards[0].target == "8 · 6 · 4")
    #expect(built.cards.allSatisfy { $0.target.map { !$0.contains("undefined") && !$0.contains("NaN") } ?? false })
    // O painel abre na série que o motor diz, a de 70 kg com RIR 2, com as entradas.
    #expect(built.panel?.title == "Agachamento completo com barra\u{00A0}· Série 2 de 3")
    #expect(built.panel?.inputs == .reps(effort: nil))
    // Cada linha estranha no painel: o drop set e os lados com o texto; o tempo com os segundos.
    #expect(model(workout, selection: WorkoutRef(entry: 0, set: 3)).panel?.inputs == .line)
    #expect(model(workout, selection: WorkoutRef(entry: 2, set: 0)).panel?.inputs == .line)
    #expect(model(workout, selection: WorkoutRef(entry: 4, set: 0)).panel?.inputs == .time)

    // O que não devia vir, e não derruba: uma série que o motor não leu (sem linha), uma escolha que não
    // existe mais, uma entrada sem séries, tudo feito e o treino livre sem exercício.
    let odd = try Self.workout(next: "null", entries: [
      Self.entry(0, sets: [Self.set(0, w: "null", r: "null", done: true, line: "")]), Self.entry(1, sets: []),
    ])
    let oddModel = model(odd, selection: WorkoutRef(entry: 7, set: 2))
    #expect(oddModel.cards[0].rows[0].line.isEmpty); #expect(oddModel.cards[0].rows[0].spoken == "Série 1, feita")
    #expect(oddModel.cards[1].rows.isEmpty)
    #expect(oddModel.panel == nil); #expect(oddModel.emptyPanel == "Todas as séries feitas")
    let freestyle = try Self.workout(next: "null", done: 0, total: 0, entries: [])
    #expect(model(freestyle).panel == nil); #expect(model(freestyle).emptyPanel == "Ainda sem exercícios.")
    #expect(model(freestyle).progress == "0 de 0 séries")
  }

  @Test func aTimedPerSideSetShowsItsPairsWithTheSideLikeOpenGym() async throws {   // issue #161
    // Uma prancha lateral de 2 × 0:30 por lado: quatro linhas, o par esquerdo e direito de cada série com o
    // mesmo número (o setNumberAt do openGym), o lado em cada linha (o sideTagOf, "Esquerda" e "Direita") e
    // "Série 1 de 2", que conta os pares.
    let sides = ["L", "R", "L", "R"]
    let plank = try Self.workout(next: #"{"entry":0,"set":1}"#, done: 1, total: 4, entries: [
      Self.entry(0, name: "prancha lateral", mode: "time", target: "2 × 0:30 · por lado", sets: sides.enumerated().map { i, side in
        Self.set(i, w: "0", r: "null", sec: "30", done: i == 0, side: side, line: "0:30")
      }),
    ])
    let rows = model(plank).cards[0].rows
    #expect(rows.map(\.number) == ["1", "1", "2", "2"])
    #expect(rows.map(\.side) == ["Esquerda", "Direita", "Esquerda", "Direita"])
    #expect(model(plank, english).cards[0].rows.map(\.side) == ["Left", "Right", "Left", "Right"])
    #expect(rows[0].spoken == "Série 1 (Esquerda), 30 segundos, feita")
    #expect(rows[1].spoken == "Série 1 (Direita), 30 segundos")
    #expect(rows[1].markLabel == "Série 1 (Direita) concluída")
    #expect(model(plank, english).cards[0].rows[3].markLabel == "Set 2 (Right) done")
    let panel = model(plank).panel
    #expect(panel?.title == "Prancha lateral\u{00A0}· Série 1 de 2 (Direita)"); #expect(panel?.setLabel == "Série 1 de 2 (Direita)")
    #expect(panel?.inputs == .time)
    #expect(model(plank, selection: WorkoutRef(entry: 0, set: 2), english).panel?.setLabel == "Set 2 of 2 (Left)")
    // As outras séries não têm lado, e contam uma por linha.
    let plain = try Self.workout(entries: [Self.entry(0, sets: [Self.set(0, done: true), Self.set(1)])])
    #expect(model(plain).cards[0].rows.map(\.side) == [nil, nil]); #expect(model(plain).cards[0].rows.map(\.number) == ["1", "2"])

    // Com o motor de verdade: o lados-e-faixa tem o lado esquerdo da primeira prancha feito, e o supino na
    // faixa 8-12 da progressão dupla, com o hífen comum.
    let folder = try TemporaryFolder()
    let app = try await opened("lados-e-faixa", folder: folder)
    let built = model(try #require(app.session.workout))
    #expect(built.cards[0].rows.map(\.number) == ["1", "1", "2", "2"])
    #expect(built.cards[0].rows.map(\.side) == ["Esquerda", "Direita", "Esquerda", "Direita"])
    #expect(built.panel?.title == "Prancha lateral\u{00A0}· Série 1 de 2 (Direita)")
    #expect(built.cards.map(\.target) == ["2 × 0:30 · por lado", "3 × 8-12 · 60 kg", "3 × 16-20 · 10 kg · 8-10/lado", "10 · 8 · 6 · 80 kg"])
  }
}
