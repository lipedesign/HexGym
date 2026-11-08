// O editor de rotina sem tela (Task 11 do plano da fase 2, issue #98). O RoutineEditorModel monta, das
// rotinas do motor (engine.routines()), tudo o que a lista e o editor mostram e o que o VoiceOver diz: o
// ícone, o nome, "6 exercícios" com o plural, os dias "Seg, Qui" na ordem da semana do perfil, as linhas
// dos exercícios com a marca do superset e o rótulo que diz com quem. O SlotDraft é o exercício aberto no
// SlotEditor: os valores na tela e o que cada toque manda ao motor, dentro dos limites do slot.update. O
// RoutinesScreen e o RoutineEditorScreen são o estado das duas telas: leem no motor, mudam a tela na hora
// e mandam a ação pelo perform. A tela não calcula nada no body.
//
// Toda regra continua no motor (seção 8.2): o nome padrão, o superset (pairAdjacent e cleanupSg), o
// apagar com o snapshot e o desfazer (restoreRoutine e markUndone), os limites. Aqui só se confere o que
// a tela manda, para nunca mandar um valor que o motor recusaria: a nota é cortada pelo utf16.count, como
// o motor mede os 500 do NOTE_MAX (o .length do JS); e uma carga acima do limite da unidade (1000 kg que
// viram 2204,5 lb na troca de unidade) abre como está, mas um toque nela manda o valor já dentro do
// limite (Notas da issue #98, achados do QA do PR #108). O passo da carga é o addStep do openGym
// (lib/progression.js), copiado aqui: o motor não tem leitura para ele, e a regra é de cinco linhas.
//
// No log, como no AppModel, o tipo do erro fica público e o detalhe, privado, porque a mensagem do motor
// pode trazer um pedaço do documento.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: "Nenhum exercício" no lugar de "0
// exercícios"; os dias curtos na linha e por extenso no VoiceOver; a carga ao lado do setsReps na linha
// do exercício, quando há; o rótulo "em superset com <nome>" no VoiceOver; a faixa "Rotina apagada" por
// 5 s, e por 15 s com o VoiceOver ligado, para dar tempo de chegar ao "Desfazer".

import Foundation
import HexDesign
import HexEngine
import Observation
import os

// Os textos que o modelo usa, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct RoutineEditorText: Sendable {
  let locale: Locale
  private let one, many, none, supersetWith: String
  // Os dias pelo getDay() (0 é o domingo), curtos para a linha e por extenso para o VoiceOver.
  private let shortDays, fullDays: [String]
  let deleted: String
  // Os nomes de cada ícone e os títulos dos grupos do seletor.
  private let glyphNames: [String: String]
  let groupTitles: [String: String]

  @MainActor init(locale: Locale) {
    self.locale = locale
    one = AppText.text("1 exercise", locale: locale)
    many = AppText.text("%lld exercises", locale: locale)
    none = AppText.text("No exercises", locale: locale)
    supersetWith = AppText.text("in a superset with %@", locale: locale)
    shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map { AppText.text($0, locale: locale) }
    fullDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].map { AppText.text($0, locale: locale) }
    deleted = AppText.text("Routine deleted", locale: locale)
    let glyphs = RoutineGlyph.groups.flatMap(\.glyphs) + ["trophy", "medal", "crown", "flag", "star", "target", "shield"]
    glyphNames = Dictionary(uniqueKeysWithValues: glyphs.map { ($0, RoutineGlyph.name(of: $0, locale: locale)) })
    groupTitles = Dictionary(uniqueKeysWithValues: RoutineGlyph.groups.map { ($0.title, RoutineGlyph.title(of: $0, locale: locale)) })
  }

  // "1 exercício", "6 exercícios" e, sem nenhum, "Nenhum exercício": o CLDR do português põe o 0 no
  // singular, e "0 exercício" não é como se fala.
  func exercises(_ count: Int) -> String {
    switch count {
    case 0: none
    case 1: one
    default: String(format: many, locale: locale, count)
    }
  }

  // Os dias na ordem da semana do perfil, que começa no domingo (0) ou na segunda (1).
  func ordered(_ days: [Int], weekStart: Int) -> [Int] {
    days.filter { (0...6).contains($0) }.sorted { ($0 - weekStart + 7) % 7 < ($1 - weekStart + 7) % 7 }
  }

  // "Seg, Qui".
  func days(_ days: [Int], weekStart: Int) -> String {
    ordered(days, weekStart: weekStart).map { shortDays[$0] }.joined(separator: ", ")
  }

  // "Segunda e Quinta".
  func spokenDays(_ days: [Int], weekStart: Int) -> String {
    ordered(days, weekStart: weekStart).map { fullDays[$0] }.formatted(.list(type: .and).locale(locale))
  }

  // "em superset com Supino reto e Remada curvada".
  func superset(with names: [String]) -> String {
    String(format: supersetWith, locale: locale, names.formatted(.list(type: .and).locale(locale)))
  }

  func glyphName(_ glyph: String) -> String {
    glyphNames[RoutineGlyph.key(for: glyph)] ?? glyphNames[RoutineGlyph.defaultGlyph] ?? glyph
  }
}

// Uma rotina na lista: o ícone, o nome, "6 exercícios", os dias e o rótulo do VoiceOver, que junta os
// três ("Peito, 6 exercícios, Segunda e Quinta").
nonisolated struct RoutineRow: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let symbol: String
  let exercises: String
  // Vazio quando a rotina não está em nenhum dia.
  let days: String
  // A contagem e os dias, separados por um ponto no meio, na segunda linha.
  let detail: String
  let spoken: String
}

// A rotina aberta no editor.
nonisolated struct RoutineEditorContent: Equatable, Sendable {
  let id: String
  let name: String
  // A chave do ícone (um emoji antigo já traduzido), o SF Symbol e o nome dele.
  let glyph: String
  let symbol: String
  let glyphName: String
  let slots: [SlotRow]
}

// Um exercício da rotina, pronto para a linha do editor.
nonisolated struct SlotRow: Identifiable, Equatable, Sendable {
  // Onde a linha fica num superset, para a marca da lateral.
  enum Mark: Sendable { case first, middle, last }

  // O id do exercício e quantas vezes ele já apareceu antes na rotina ("0025#0"): o mesmo exercício
  // pode estar duas vezes, e a linha não muda de identidade quando outra sai ou troca de lugar. As ações
  // da linha acham a posição dela por este id, na hora (RoutineEditorScreen.position).
  let id: String
  let exerciseID: String
  let name: String
  let known: Bool
  let setsReps: String
  // O setsReps e, quando há, a carga ("3 × 10 · 60 kg").
  let detail: String
  let superset: Mark?
  // O menu da linha: "Juntar com o próximo" quando há um próximo fora deste superset; "Separar" quando
  // a linha está num superset.
  let canJoinNext: Bool
  let canSeparate: Bool
  let spoken: String
}

nonisolated struct RoutineEditorModel: Sendable {
  let rows: [RoutineRow]
  private let summaries: [String: RoutineSummary]
  private let unit: WeightUnit
  private let text: RoutineEditorText
  private let language: Locale

  // O language é o idioma dos nomes, o do motor: a primeira letra do nome de um exercício sobe pela
  // regra dele, como na biblioteca. Sem ele, o idioma da tela.
  init(routines: [RoutineSummary], weekStart: Int, unit: WeightUnit = .kg, text: RoutineEditorText, language: Locale? = nil) {
    self.unit = unit
    self.text = text
    self.language = language ?? text.locale
    summaries = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    rows = routines.map { routine in
      let exercises = text.exercises(routine.slots.count)
      let days = text.days(routine.days, weekStart: weekStart)
      let spokenDays = text.spokenDays(routine.days, weekStart: weekStart)
      return RoutineRow(
        id: routine.id, name: routine.name, symbol: RoutineGlyph.symbol(for: routine.glyph), exercises: exercises, days: days,
        detail: ([exercises] + (days.isEmpty ? [] : [days])).joined(separator: LibraryNames.separator),
        spoken: ([routine.name, exercises] + (spokenDays.isEmpty ? [] : [spokenDays])).joined(separator: ", "))
    }
  }

  // O editor de uma rotina, ou nil quando ela não existe mais.
  func editor(_ id: String) -> RoutineEditorContent? {
    guard let routine = summaries[id] else { return nil }
    let slots = routine.slots
    var seen: [String: Int] = [:]
    let rows = slots.indices.map { index -> SlotRow in
      let slot = slots[index]
      let occurrence = seen[slot.id, default: 0]
      seen[slot.id] = occurrence + 1
      let group = Self.group(around: index, in: slots)
      let mark: SlotRow.Mark? = group.count < 2 ? nil
        : index == group.first ? .first : index == group.last ? .last : .middle
      let partners = group.filter { $0 != index }.map { LibraryNames.capitalized(slots[$0].name, language: language) }
      let name = LibraryNames.capitalized(slot.name, language: language)
      let load = Self.load(slot, unit: unit, locale: text.locale)
      var spoken = [name, slot.setsReps]
      if let load { spoken.append(load.spoken) }
      if !partners.isEmpty { spoken.append(text.superset(with: partners)) }
      return SlotRow(
        id: "\(slot.id)#\(occurrence)", exerciseID: slot.id, name: name, known: slot.known,
        setsReps: slot.setsReps, detail: ([slot.setsReps] + (load.map { [$0.text] } ?? [])).joined(separator: LibraryNames.separator),
        superset: mark, canJoinNext: index + 1 < slots.count && !group.contains(index + 1), canSeparate: mark != nil,
        spoken: spoken.joined(separator: ", "))
    }
    let key = RoutineGlyph.key(for: routine.glyph)
    return RoutineEditorContent(id: routine.id, name: routine.name, glyph: key, symbol: RoutineGlyph.symbol(for: key),
                                glyphName: text.glyphName(key), slots: rows)
  }

  // O que o "Desfazer" aplica depois de um routine.delete: o restoreRoutine com o snapshot dele.
  static func undo(after outcome: ActionOutcome) -> EngineAction? {
    outcome.snapshot.map { .restoreRoutine(snapshot: $0) }
  }

  // A posição final de um item que o .onMove da List leva para antes do offset, como o routine.move e o
  // slot.move do motor recebem (tira de from e põe em to).
  static func moveTarget(from: Int, offset: Int) -> Int {
    offset > from ? offset - 1 : offset
  }

  // Os índices do superset em volta de um exercício: os vizinhos seguidos com o mesmo superset, como o
  // contiguousSgGroup do openGym. Fora de superset, só ele.
  private static func group(around index: Int, in slots: [SlotSummary]) -> [Int] {
    guard let id = slots[index].superset else { return [index] }
    var first = index, last = index
    while first > 0, slots[first - 1].superset == id { first -= 1 }
    while last + 1 < slots.count, slots[last + 1].superset == id { last += 1 }
    return Array(first...last)
  }

  // A carga escrita e falada, quando há.
  private static func load(_ slot: SlotSummary, unit: WeightUnit, locale: Locale) -> (text: String, spoken: String)? {
    guard let weight = slot.weight, weight > 0 else { return nil }
    return ("\(WorkoutFormat.load(weight, locale: locale)) \(unit.rawValue)", WorkoutFormat.spokenLoad(weight, unit: unit, locale: locale))
  }
}

// O modo de um exercício da rotina. O cardio do openGym só é lido nesta fase.
nonisolated enum SlotMode: String, Sendable { case reps, time, cardio }

// O exercício aberto no SlotEditor: os valores que a tela mostra e o que cada toque manda ao motor. Cada
// passo devolve os campos que mudaram, ou nil quando o toque não muda nada (no limite), e o valor da tela
// já é o novo. Os limites são os do slot.update (Task 5); os segundos andam de 5 em 5, a partir de 5.
nonisolated struct SlotDraft: Equatable, Sendable {
  static let setsRange = 1...20
  static let repsRange = 1...100
  static let secondsRange = 5...3600
  static let secondsStep = 5
  static let loadRange = 0.0...1000.0
  // O NOTE_MAX do openGym, em unidades de UTF-16, como o .length do JS.
  static let noteMax = 500

  private(set) var sets: Int
  private(set) var reps: Int
  private(set) var repsMin: Int?
  private(set) var seconds: Int
  private(set) var weight: Double
  private(set) var mode: SlotMode
  private(set) var note: String
  let increment: Double
  // O passo das repetições do motor: 2 num exercício por lado, 1 nos outros.
  let repStep: Int
  let unit: WeightUnit

  // Os padrões de um campo que o slot não tem são os do openGym (setsRepsOf e o salvar da sheet): 1
  // série, 10 repetições, 45 s.
  init(_ slot: SlotSummary, unit: WeightUnit) {
    sets = slot.sets ?? 1
    reps = slot.reps ?? 10
    repsMin = slot.repsMin
    seconds = slot.sec ?? 45
    weight = slot.weight ?? 0
    mode = slot.mode.flatMap(SlotMode.init(rawValue:)) ?? .reps
    note = slot.note ?? ""
    increment = slot.increment
    repStep = max(1, slot.repStep)
    self.unit = unit
  }

  mutating func stepSets(_ direction: StepDirection) -> SlotFields? {
    let next = Self.clamp(sets + direction.sign, Self.setsRange)
    guard next != sets else { return nil }
    sets = next
    return SlotFields(sets: next)
  }

  // Um passo do repStep: de 2 em 2 num exercício por lado (20, 22, 24), como o Stepper da sheet do
  // openGym. Um valor ímpar que veio do openGym anda do mesmo jeito (11, 13, 15), como lá, que só soma o
  // passo; os limites de 1 e 100 ficam. Uma faixa (8 a 12) desce junto quando o topo fica abaixo do
  // começo dela: o motor recusa um repsMin acima das repetições.
  mutating func stepReps(_ direction: StepDirection) -> SlotFields? {
    let next = Self.clamp(reps + direction.sign * repStep, Self.repsRange)
    guard next != reps else { return nil }
    reps = next
    var fields = SlotFields(reps: next)
    if let low = repsMin, low > next {
      repsMin = next
      fields.repsMin = next
    }
    return fields
  }

  mutating func stepSeconds(_ direction: StepDirection) -> SlotFields? {
    let next = Self.clamp(seconds + direction.sign * Self.secondsStep, Self.secondsRange)
    guard next != seconds else { return nil }
    seconds = next
    return SlotFields(sec: next)
  }

  // Um passo do increment pelo addStep do openGym e, depois, o limite: uma carga acima dele volta ao
  // limite no primeiro toque, para cima ou para baixo.
  mutating func stepLoad(_ direction: StepDirection) -> SlotFields? {
    let next = min(max(Self.addStep(weight, Double(direction.sign) * increment, increment), Self.loadRange.lowerBound),
                   Self.loadRange.upperBound)
    guard next != weight else { return nil }
    weight = next
    return SlotFields(weight: next)
  }

  // Repetições ou tempo; o cardio não se escolhe aqui.
  mutating func setMode(_ next: SlotMode) -> SlotFields? {
    guard next != .cardio, next != mode else { return nil }
    mode = next
    return SlotFields(mode: next.rawValue)
  }

  // A nota cortada no NOTE_MAX, sem partir um caractere.
  mutating func setNote(_ text: String) -> SlotFields? {
    let next = Self.limitedNote(text)
    guard next != note else { return nil }
    note = next
    return SlotFields(note: next)
  }

  // O texto até 500 unidades de UTF-16, de caractere em caractere: um emoji ou um acento em NFD que não
  // cabem inteiros ficam de fora.
  static func limitedNote(_ text: String) -> String {
    guard text.utf16.count > noteMax else { return text }
    var kept = "", used = 0
    for character in text {
      let size = character.utf16.count
      if used + size > noteMax { break }
      kept.append(character)
      used += size
    }
    return kept
  }

  // O addStep do openGym (lib/progression.js): de uma carga na grade do increment, a soma volta para a
  // grade; fora dela, o passo só soma. Arredondado a 0,1, nunca abaixo de 0. O Math.round do JS é o
  // (x + 0,5) para baixo.
  static func addStep(_ value: Double, _ step: Double, _ increment: Double) -> Double {
    func round(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
    func round1(_ x: Double) -> Double { round(x * 10) / 10 }
    let onGrid = increment > 0 && abs(value - round(value / increment) * increment) <= 0.1
    let next = value + step
    return max(0, onGrid ? round1(round(next / increment) * increment) : round1(next))
  }

  private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
    min(max(value, range.lowerBound), range.upperBound)
  }
}

extension StepDirection {
  nonisolated var sign: Int { self == .up ? 1 : -1 }
}

// O desfazer de uma rotina apagada, enquanto a faixa aparece: o texto, a ação e o instante em que a
// rotina saiu. O prazo conta desse instante: a faixa que volta (outra aba, o editor por cima) fica só o
// que faltava, e não começa de novo.
nonisolated struct RoutineUndo: Identifiable, Sendable {
  static let shown = Duration.seconds(5)
  // Com o VoiceOver, mais tempo para chegar ao botão.
  static let shownWithVoiceOver = Duration.seconds(15)

  // Sobe a cada rotina apagada: a faixa de uma remoção nova recomeça a contar.
  let id: Int
  let message: String
  let action: EngineAction
  var created = ContinuousClock.now

  func deadline(voiceOver: Bool) -> ContinuousClock.Instant {
    created + (voiceOver ? Self.shownWithVoiceOver : Self.shown)
  }

  // O que falta do prazo; zero quando ele já passou.
  func remaining(voiceOver: Bool, now: ContinuousClock.Instant = .now) -> Duration {
    max(.zero, deadline(voiceOver: voiceOver) - now)
  }
}

// Os ajustes que as telas das rotinas leem: a semana e a unidade.
nonisolated struct RoutineSettings: Equatable, Sendable {
  var weekStart = 1
  var unit = WeightUnit.kg

  init() {}

  init(_ settings: DocumentSettings) {
    weekStart = settings.weekStart
    unit = settings.unit == "lb" ? .lb : .kg
  }
}

// O estado da lista das rotinas: as linhas, o desfazer de uma rotina apagada e as ações da lista. Lê
// tudo no motor, fora da thread principal, e muda o documento só pelas ações (perform).
@Observable @MainActor final class RoutinesScreen {
  enum Phase: Equatable { case loading, ready, failed }

  private(set) var phase = Phase.loading
  private(set) var rows: [RoutineRow] = []
  // A faixa "Rotina apagada", enquanto o "Desfazer" vale.
  private(set) var undo: RoutineUndo?

  // O revision do documento, lido pela tela para ler as rotinas de novo depois de uma ação.
  var documentRevision: Int { revision() }

  @ObservationIgnored let engine: HexEngine
  @ObservationIgnored let locale: Locale
  @ObservationIgnored private let revision: () -> Int
  @ObservationIgnored let perform: (EngineAction) async throws -> ActionOutcome
  // O plano da semana no topo da aba (Task 12), com o mesmo motor, o mesmo idioma e as mesmas ações.
  @ObservationIgnored let week: WeekPlanScreen
  @ObservationIgnored private var undos = 0
  @ObservationIgnored private var announced: Int?

  private static let logger = Logger(subsystem: "app.hexgym", category: "routines")

  init(engine: HexEngine, locale: Locale = .current, revision: @escaping () -> Int = { 0 },
       perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.engine = engine
    self.locale = locale
    self.revision = revision
    self.perform = perform
    week = WeekPlanScreen(engine: engine, locale: locale, perform: perform)
  }

  // O app de verdade: o motor e as ações do AppModel, e o revision dele.
  convenience init(app: AppModel) {
    self.init(engine: app.engine, revision: { app.revision }, perform: { try await app.perform($0) })
  }

  func load() async {
    do {
      let settings = RoutineSettings(try await engine.settings())
      let language = Locale(identifier: try await engine.load().language)
      let model = RoutineEditorModel(routines: try await engine.routines(), weekStart: settings.weekStart, unit: settings.unit,
                                     text: RoutineEditorText(locale: locale), language: language)
      rows = model.rows
      phase = .ready
    } catch {
      Self.log("não deu para ler as rotinas", error)
      if phase == .loading { phase = .failed }
    }
  }

  // "Nova rotina": a rotina nova no fim, com o nome padrão do openGym. Devolve o id, para a tela abrir o
  // editor dela.
  func create() async -> String? {
    do {
      let id = try await perform(.createRoutine(name: "")).id
      await load()
      return id
    } catch {
      Self.log("não deu para criar a rotina", error)
      return nil
    }
  }

  func duplicate(_ id: String) async {
    await run("não deu para duplicar a rotina", .duplicateRoutine(id: id))
  }

  // A linha sai na hora, antes de a ação sair (o deslizar da List não volta a linha); depois da ação, a
  // faixa "Rotina apagada" fica com o desfazer. A tarefa devolvida acaba com a lista lida de novo.
  @discardableResult func delete(_ id: String) -> Task<Void, Never> {
    rows.removeAll { $0.id == id }
    return Task { await deleteInEngine(id) }
  }

  private func deleteInEngine(_ id: String) async {
    do {
      let outcome = try await perform(.deleteRoutine(id: id))
      if let action = RoutineEditorModel.undo(after: outcome) {
        undos += 1
        undo = RoutineUndo(id: undos, message: RoutineEditorText(locale: locale).deleted, action: action)
      }
    } catch {
      Self.log("não deu para apagar a rotina", error)
    }
    await load()
  }

  // O "Desfazer": a rotina volta, com os dias dela, e a faixa sai.
  func performUndo() async {
    guard let action = undo?.action else { return }
    undo = nil
    await run("não deu para desfazer", action)
  }

  // A faixa saiu sem o desfazer (o tempo dela acabou).
  func dismissUndo(_ id: Int) {
    if undo?.id == id { undo = nil }
  }

  // Se a faixa desse desfazer ainda não foi anunciada ao VoiceOver; marca como anunciada. A faixa que
  // volta não anuncia de novo.
  func shouldAnnounce(_ id: Int) -> Bool {
    guard announced != id else { return false }
    announced = id
    return true
  }

  // O reordenar da List: a linha muda de lugar na hora, e a ação vai ao motor.
  @discardableResult func move(from source: IndexSet, to offset: Int) -> Task<Void, Never>? {
    guard let from = source.first, source.count == 1, rows.indices.contains(from) else { return nil }
    let to = RoutineEditorModel.moveTarget(from: from, offset: offset)
    guard from != to, rows.indices.contains(to) else { return nil }
    rows.insert(rows.remove(at: from), at: to)
    return Task { await run("não deu para mover a rotina", .moveRoutine(from: from, to: to)) }
  }

  // O editor de uma rotina, com o mesmo motor, o mesmo idioma, as mesmas ações e o mesmo revision.
  func editor(_ id: String, isNew: Bool = false) -> RoutineEditorScreen {
    RoutineEditorScreen(id: id, isNew: isNew, engine: engine, locale: locale, revision: revision, perform: perform)
  }

  private func run(_ what: String, _ action: EngineAction) async {
    do {
      _ = try await perform(action)
    } catch {
      Self.log(what, error)
    }
    await load()
  }

  static func log(_ what: String, _ error: any Error) {
    logger.error("\(what, privacy: .public) (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
  }
}

// O estado do editor de uma rotina: o nome no campo, o ícone e os exercícios, e as ações sobre eles. A
// tela muda na hora (a ordem, uma linha que sai) e lê de novo do motor depois de cada ação.
@Observable @MainActor final class RoutineEditorScreen {
  enum Phase: Equatable { case loading, ready, gone, failed }

  let id: String
  private(set) var phase = Phase.loading
  private(set) var content: RoutineEditorContent?
  private(set) var settings = RoutineSettings()
  // O texto do campo do nome. Numa rotina que acabou de ser criada, começa vazio, com o "Nome da
  // rotina" de dica, e o nome padrão do motor fica se a pessoa não escrever nada.
  var name = ""
  // O campo do nome está com o foco: uma leitura nova não troca o que a pessoa está escrevendo.
  var editingName = false
  let text: RoutineEditorText

  var documentRevision: Int { revision() }

  @ObservationIgnored private let isNew: Bool
  @ObservationIgnored private var loadedName = false
  @ObservationIgnored let engine: HexEngine
  @ObservationIgnored let locale: Locale
  @ObservationIgnored private let revision: () -> Int
  @ObservationIgnored let perform: (EngineAction) async throws -> ActionOutcome
  // A última ação mandada: cada uma espera a de antes, para o motor receber na ordem dos toques, e a
  // posição de cada linha, achada na tela na hora do toque, valer no motor também.
  @ObservationIgnored private var last: Task<Void, Never>?
  // As ações ainda no caminho: enquanto houver alguma, uma leitura do motor não troca a tela, que já
  // mostra o resultado delas.
  @ObservationIgnored private var pending = 0

  init(id: String, isNew: Bool = false, engine: HexEngine, locale: Locale = .current, revision: @escaping () -> Int = { 0 },
       perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.id = id
    self.isNew = isNew
    self.engine = engine
    self.locale = locale
    self.revision = revision
    self.perform = perform
    text = RoutineEditorText(locale: locale)
  }

  func load() async {
    guard pending == 0 else { return }
    do {
      settings = RoutineSettings(try await engine.settings())
      let language = Locale(identifier: try await engine.load().language)
      let model = RoutineEditorModel(routines: try await engine.routines(), weekStart: settings.weekStart, unit: settings.unit, text: text,
                                     language: language)
      // Uma ação saiu enquanto o motor era lido: a tela já mostra o resultado dela, e a leitura do fim
      // dela vem depois.
      guard pending == 0 else { return }
      guard let content = model.editor(id) else {
        phase = .gone
        return
      }
      self.content = content
      if !editingName {
        name = isNew && !loadedName ? "" : content.name
      }
      loadedName = true
      phase = .ready
    } catch {
      RoutinesScreen.log("não deu para ler a rotina", error)
      if phase == .loading { phase = .failed }
    }
  }

  // O nome vai ao motor quando o campo perde o foco ou a pessoa confirma. Vazio, o nome de antes fica.
  func commitName() async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let content, !trimmed.isEmpty else {
      name = content?.name ?? name
      return
    }
    guard trimmed != content.name else { return }
    await run("não deu para renomear a rotina", .renameRoutine(id: id, name: trimmed))
  }

  func setGlyph(_ glyph: String) async {
    guard glyph != content?.glyph else { return }
    await run("não deu para trocar o ícone", .setRoutineGlyph(id: id, glyph: glyph))
  }

  // Os escolhidos na biblioteca, no fim, na ordem dos toques.
  func add(_ exerciseIDs: [String]) async {
    guard !exerciseIDs.isEmpty else { return }
    await run("não deu para pôr os exercícios", .addExercises(routineID: id, exerciseIDs: exerciseIDs, at: nil))
  }

  // A posição de agora de uma linha, pelo id dela: a tela pode já ter tirado ou mudado de lugar outras
  // linhas, e o index da linha fica velho até a leitura do motor chegar.
  func position(of rowID: String) -> Int? {
    content?.slots.firstIndex { $0.id == rowID }
  }

  // A linha sai na hora, e a ação vai ao motor.
  @discardableResult func remove(_ rowID: String) -> Task<Void, Never>? {
    guard let content, let index = position(of: rowID) else { return nil }
    self.content = content.removing(index)
    return send("não deu para tirar o exercício", .removeSlot(routineID: id, index: index))
  }

  @discardableResult func replace(_ rowID: String, with exerciseID: String) -> Task<Void, Never>? {
    guard let index = position(of: rowID) else { return nil }
    return send("não deu para trocar o exercício", .replaceSlot(routineID: id, index: index, exerciseID: exerciseID))
  }

  @discardableResult func joinWithNext(_ rowID: String) -> Task<Void, Never>? {
    guard let index = position(of: rowID) else { return nil }
    return send("não deu para juntar o superset", .superset(routineID: id, index: index))
  }

  @discardableResult func separate(_ rowID: String) -> Task<Void, Never>? {
    guard let index = position(of: rowID) else { return nil }
    return send("não deu para separar o superset", .unsuperset(routineID: id, index: index))
  }

  // A linha muda de lugar na hora, e a ação vai ao motor. As posições do .onMove são as da tela de agora.
  @discardableResult func move(from source: IndexSet, to offset: Int) -> Task<Void, Never>? {
    guard let content, let from = source.first, source.count == 1, content.slots.indices.contains(from) else { return nil }
    let to = RoutineEditorModel.moveTarget(from: from, offset: offset)
    guard from != to, content.slots.indices.contains(to) else { return nil }
    self.content = content.moving(from: from, to: to)
    return send("não deu para mover o exercício", .moveSlot(routineID: id, from: from, to: to))
  }

  // O SlotEditor de um exercício, com o que o motor tem dele agora: depois das ações no caminho, na
  // posição de agora da linha.
  func slotEditor(_ rowID: String) async -> SlotEditorScreen? {
    await last?.value
    guard let index = position(of: rowID), let row = content?.slots[index] else { return nil }
    do {
      guard let slot = try await engine.routines().first(where: { $0.id == id })?.slots[safe: index] else { return nil }
      return SlotEditorScreen(routineID: id, index: index, row: row, slot: slot, unit: settings.unit, locale: locale, perform: perform)
    } catch {
      RoutinesScreen.log("não deu para abrir o exercício", error)
      return nil
    }
  }

  // O SlotEditor da linha dessa posição, para os argumentos de início e o roteiro do vídeo.
  func slotEditor(at index: Int) async -> SlotEditorScreen? {
    guard let row = content?.slots[safe: index] else { return nil }
    return await slotEditor(row.id)
  }

  // A ação vai ao motor depois da de antes; a tela lê o motor de novo quando a última chega.
  private func send(_ what: String, _ action: EngineAction) -> Task<Void, Never> {
    let previous = last
    pending += 1
    let task = Task {
      await previous?.value
      do {
        _ = try await perform(action)
      } catch {
        RoutinesScreen.log(what, error)
      }
      pending -= 1
      await load()
    }
    last = task
    return task
  }

  private func run(_ what: String, _ action: EngineAction) async {
    await send(what, action).value
  }
}

extension RoutineEditorContent {
  // A mesma rotina com uma linha a menos, até a leitura do motor chegar.
  nonisolated func removing(_ index: Int) -> RoutineEditorContent {
    var slots = slots
    if slots.indices.contains(index) { slots.remove(at: index) }
    return RoutineEditorContent(id: id, name: name, glyph: glyph, symbol: symbol, glyphName: glyphName, slots: slots)
  }

  // A mesma rotina com uma linha em outro lugar: sai de from e fica em to, como o slot.move.
  nonisolated func moving(from: Int, to: Int) -> RoutineEditorContent {
    var slots = slots
    slots.insert(slots.remove(at: from), at: to)
    return RoutineEditorContent(id: id, name: name, glyph: glyph, symbol: symbol, glyphName: glyphName, slots: slots)
  }
}

extension Array {
  nonisolated subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
