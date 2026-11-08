// A tela do treino sem tela (Task 8 do plano da fase 3, issue #137). O WorkoutScreenModel monta, do treino
// em andamento que o motor dá (o ActiveWorkout da Task 4) e da série que a pessoa tocou, tudo o que a tela
// mostra e o que o VoiceOver diz: o cabeçalho ("5 de 13 séries" e o tempo), um cartão por exercício com
// as séries em linhas curtas, o superset ("Superset A, 1 de 2"), e o painel da série atual ("Supino com
// barra · Série 2 de 3", as entradas pelo modo e pela escala do esforço, e o botão). O WorkoutScreen é o
// estado da tela: a série tocada e as ações, mandadas ao motor pelo WorkoutSession, uma de cada vez, na
// ordem dos toques. A tela não calcula nada no body.
//
// Toda regra do treino fica no motor (seção 8.2): a série que o "Registrar série" marca (o next), a linha
// curta de cada série ("60 kg × 8", ou o texto do setLabel do openGym nas séries com lados, no drop set, no
// rest-pause, no cardio e na série com tempo), as contas da barra, a letra do superset e o passo de cada
// entrada. Aqui só se escolhe o texto, a ordem e o que cada toque manda.
//
// Os textos que o openGym já tem são os dele (o pacote pt-BR, que herda do pt), com a chave em inglês
// dele: "Série 2 de 3" ('Set {0} of {1}', o rótulo da Live Activity do openGym), "Aquecimento 1" ('Warm-up'
// e o número, também de lá), "Série 2" ('Set {0}'), "Série 2 concluída" ('Set {0} done', o rótulo da marca
// de feita da linha), "Registrar série" ('Log set', o botão da Live Activity do openGym), "Próxima série"
// ('Next set'), "Todas as séries feitas" ('All sets done') e "Ainda sem exercícios." ('No exercises yet.').
// A fala da carga e das repetições é a das entradas do HexDesign (WorkoutFormat), uma só no app.
//
// Escolhas recomendadas, com a delegação do Lipe de 03/11/2026: tocar numa linha põe o painel nela até
// ela ser marcada, ou até o "Próxima série", que aparece no lugar do "Registrar série" quando a linha
// tocada já está feita; o aquecimento conta à parte, como o openGym numera ("Aquecimento 1" e depois
// "Série 1"); um alvo que o motor escreveu com "undefined" (um alvo sem séries, vindo de outro aparelho)
// não aparece no cartão.

import Foundation
import HexDesign
import HexEngine
import Observation
import os
import SwiftUI

// A série de uma entrada, pelas posições do treino. O SetRef do motor não tem um init público para o app.
nonisolated struct WorkoutRef: Hashable, Sendable {
  let entry: Int, set: Int

  init(entry: Int, set: Int) {
    (self.entry, self.set) = (entry, set)
  }

  init(_ ref: SetRef) {
    self.init(entry: ref.entry, set: ref.set)
  }
}

// Os textos que o modelo usa, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct WorkoutText: Sendable {
  let locale: Locale
  // O idioma dos textos do app (o catálogo tem só o português e o inglês), para as falas da carga.
  let textLocale: Locale
  let logSet, nextSet, allDone, noExercises: String
  private let setOfFormat, warmupFormat, setFormat, setDoneFormat, warmupDoneFormat, doneFormat, warmupSpokenDoneFormat,
      supersetFormat, supersetPlaceFormat: String

  @MainActor init(locale: Locale) {
    self.locale = locale
    let portuguese = locale.language.languageCode == .portuguese
    textLocale = Locale(identifier: portuguese ? "pt-BR" : "en")
    func text(_ key: String) -> String { AppText.text(key, locale: locale) }
    logSet = text("Log set")
    nextSet = text("Next set")
    allDone = text("All sets done")
    noExercises = text("No exercises yet.")
    setOfFormat = text("Set %lld of %lld")
    warmupFormat = text("Warm-up %lld")
    setFormat = text("Set %lld")
    setDoneFormat = text("Set %lld done")
    warmupDoneFormat = text("Warm-up %lld done")
    doneFormat = text("%@, done")
    // O "feito" do aquecimento é masculino em português; em inglês, o "done" é o mesmo da série.
    warmupSpokenDoneFormat = portuguese ? text("%@, done (warm-up)") : doneFormat
    supersetFormat = text("Superset %@")
    supersetPlaceFormat = text("Superset %@, %lld of %lld")
  }

  // "Série 2 de 3".
  func setOf(_ number: Int, _ total: Int) -> String { String(format: setOfFormat, locale: locale, number, total) }
  // "Aquecimento 1" e "Série 2": o nome de uma linha.
  func label(_ number: Int, warmup: Bool) -> String { String(format: warmup ? warmupFormat : setFormat, locale: locale, number) }
  // "Série 2 concluída" e "Aquecimento 1 concluído": o rótulo da marca de feita.
  func markLabel(_ number: Int, warmup: Bool) -> String {
    String(format: warmup ? warmupDoneFormat : setDoneFormat, locale: locale, number)
  }
  // "Série 2, 60 quilogramas, 8 repetições, feita".
  func spokenDone(_ spoken: String, warmup: Bool) -> String {
    String(format: warmup ? warmupSpokenDoneFormat : doneFormat, locale: locale, spoken)
  }
  func superset(_ letter: String) -> String { String(format: supersetFormat, locale: locale, letter) }
  // "Superset A, 1 de 2".
  func supersetPlace(_ letter: String, _ position: Int, _ count: Int) -> String {
    String(format: supersetPlaceFormat, locale: locale, letter, position, count)
  }
}

// O que a marca de feita de uma linha manda: a série no estado contrário ao de agora (o controlador
// recebe o estado, e não um "inverte", pelo Foco da revisão 3).
nonisolated struct WorkoutSetMark: Equatable, Sendable {
  let entry: Int, set: Int
  let done: Bool

  var action: SessionAction { .markSet(entry: entry, set: set, done: done) }
}

// Uma linha de série: o número (o aquecimento conta à parte), a linha curta do motor, a marca de feita, se
// é a do painel, e as falas.
nonisolated struct WorkoutRow: Identifiable, Equatable, Sendable {
  let ref: WorkoutRef
  let number: String
  let warmup: Bool
  // "60 kg × 8", ou o texto do motor; vazio numa série que o motor não leu.
  let line: String
  let done: Bool
  // A série do painel.
  let current: Bool
  // "Série 2, 60 quilogramas, 8 repetições, feita".
  let spoken: String
  // "Série 2 concluída", o rótulo da marca, que o VoiceOver lê com o estado dela.
  let markLabel: String
  let mark: WorkoutSetMark
  var id: WorkoutRef { ref }
}

// O lugar de um exercício no superset dele.
nonisolated struct WorkoutSuperset: Equatable, Sendable {
  let letter: String, position: Int, count: Int
  // "Superset A", em cima do primeiro cartão do grupo.
  let label: String
  // "Superset A, 1 de 2", no VoiceOver de cada cartão.
  let spoken: String
  var first: Bool { position == 1 }
  var last: Bool { position == count }
}

// Um cartão de exercício: o nome (com a primeira letra em maiúscula), o alvo, o superset e as séries.
nonisolated struct WorkoutCard: Identifiable, Equatable, Sendable {
  let entry: Int
  let name: String
  // false: o exercício não existe neste aparelho ("Exercício desconhecido").
  let known: Bool
  // "3 × 8 · 60 kg"; nil quando o motor não deu um alvo que se leia.
  let target: String?
  let superset: WorkoutSuperset?
  let rows: [WorkoutRow]
  // O exercício da série do painel.
  let current: Bool
  var id: Int { entry }
}

// As entradas do painel: a carga e as repetições (e o esforço, na escala do perfil), os segundos de uma
// série com tempo, ou só o texto do motor, nas séries que esta fase marca inteiras (o drop set, o
// rest-pause, a série com lados e o cardio, escolha 12 do plano).
nonisolated enum PanelInputs: Equatable, Sendable { case reps(effort: EffortScale?), time, line }

// O painel da série atual.
nonisolated struct WorkoutPanel: Equatable, Sendable {
  // O botão: marcar a série, ou voltar para a próxima série quando a linha tocada já está feita.
  enum Action: Equatable, Sendable { case log, next }

  let ref: WorkoutRef
  // "Supino com barra · Série 2 de 3".
  let title: String
  let inputs: PanelInputs
  let load: Double, reps: Int, seconds: Int
  let effort: Double?
  let unit: WeightUnit
  // O texto do motor, para as séries sem entradas.
  let line: String
  // "0:45" e "45 segundos", na série com tempo.
  let secondsText: String
  let spokenSeconds: String
  // nil: a linha tocada está feita e não há próxima série; o painel só mostra a série.
  let action: Action?
  let buttonLabel: String
}

nonisolated struct WorkoutScreenModel: Equatable, Sendable {
  let name: String
  let start: Date?
  let done: Int, total: Int
  // "5 de 13 séries".
  let progress: String
  let cards: [WorkoutCard]
  let panel: WorkoutPanel?
  // Sem painel: "Todas as séries feitas", ou, no treino livre sem exercício, "Ainda sem exercícios.".
  let emptyPanel: String?

  // O language é o idioma dos nomes dos exercícios, o do motor: a primeira letra de cada nome vai em
  // maiúscula nesse idioma, como no Início e no editor de rotina ("Supino com barra").
  init(workout: ActiveWorkout, selection: WorkoutRef?, text: WorkoutText, language: Locale? = nil) {
    name = workout.name
    start = workout.start
    done = workout.done
    total = workout.total
    progress = SlantedSegments.spokenValue(total: workout.total, done: workout.done, locale: text.textLocale)
    let language = language ?? text.textLocale
    let scale = Self.scale(workout.effort)
    let unit: WeightUnit = workout.unit == "lb" ? .lb : .kg
    let next = workout.next.map(WorkoutRef.init).flatMap { Self.exists($0, in: workout) ? $0 : nil }
    let current = selection.flatMap { Self.exists($0, in: workout) ? $0 : nil } ?? next

    // O lugar de cada exercício no superset dele, pela letra que o motor deu.
    var counts: [String: Int] = [:]
    for entry in workout.entries { if let letter = entry.sgLetter { counts[letter, default: 0] += 1 } }
    var seen: [String: Int] = [:]

    cards = workout.entries.enumerated().map { position, entry in
      let numbers = Self.numbers(entry.sets)
      let rows = entry.sets.enumerated().map { index, set in
        let ref = WorkoutRef(entry: position, set: index)
        let label = text.label(numbers[index], warmup: set.warmup)
        let spoken = Self.spoken(set, label: label, mode: entry.mode, unit: unit, text: text)
        return WorkoutRow(
          ref: ref, number: String(numbers[index]), warmup: set.warmup, line: set.line, done: set.done, current: ref == current,
          spoken: set.done ? text.spokenDone(spoken, warmup: set.warmup) : spoken,
          markLabel: text.markLabel(numbers[index], warmup: set.warmup),
          mark: WorkoutSetMark(entry: position, set: index, done: !set.done))
      }
      let superset = entry.sgLetter.map { letter -> WorkoutSuperset in
        let place = (seen[letter] ?? 0) + 1
        seen[letter] = place
        let count = counts[letter] ?? place
        return WorkoutSuperset(letter: letter, position: place, count: count, label: text.superset(letter),
                               spoken: text.supersetPlace(letter, place, count))
      }
      return WorkoutCard(entry: position, name: LibraryNames.capitalized(entry.name, language: language), known: entry.known,
                         target: Self.readable(entry.target), superset: superset, rows: rows, current: current?.entry == position)
    }

    if let current {
      let entry = workout.entries[current.entry]
      let set = entry.sets[current.set]
      let title = LibraryNames.capitalized(entry.name, language: language) + LibraryNames.separator
        + Self.setTitle(entry.sets, at: current.set, text: text)
      let seconds = max(0, set.sec ?? 0)
      let action: WorkoutPanel.Action? = !set.done ? .log : next != nil ? .next : nil
      panel = WorkoutPanel(
        ref: current, title: title, inputs: Self.inputs(mode: entry.mode, kind: set.kind, scale: scale),
        load: set.w ?? 0, reps: set.r ?? 0, seconds: seconds,
        effort: scale == .rir ? set.rir : scale == .rpe ? set.rpe : nil, unit: unit, line: set.line,
        secondsText: Self.elapsed(TimeInterval(seconds)), spokenSeconds: Self.spokenSeconds(seconds, locale: text.textLocale),
        action: action, buttonLabel: action == .next ? text.nextSet : text.logSet)
      emptyPanel = nil
    } else {
      panel = nil
      emptyPanel = workout.entries.isEmpty ? text.noExercises : text.allDone
    }
  }

  // O tempo que passa desde o começo do treino, e o de uma série com tempo: "12:04" abaixo de uma hora e
  // "1:02:10" acima. O mesmo relógio do Início.
  static func elapsed(_ seconds: TimeInterval) -> String {
    HomeModel.elapsed(seconds)
  }

  // A fala do tempo: "12 minutos e 4 segundos".
  static func spokenElapsed(_ seconds: TimeInterval, locale: Locale) -> String {
    HomeModel.spokenElapsed(seconds, locale: locale)
  }

  // A escala do esforço do perfil, ou nil sem esforço.
  static func scale(_ effort: String) -> EffortScale? {
    switch effort {
    case "rir": .rir
    case "rpe": .rpe
    default: nil
    }
  }

  // As entradas pelo modo do exercício e pelo tipo da série.
  static func inputs(mode: String, kind: String, scale: EffortScale?) -> PanelInputs {
    guard kind == "normal" else { return .line }
    switch mode {
    case "reps": return .reps(effort: scale)
    case "time": return .time
    default: return .line
    }
  }

  // O número de cada linha, como o setNumberAt do openGym (views/Workout.jsx:850): o aquecimento e as de
  // trabalho contam cada um à parte.
  private static func numbers(_ sets: [ActiveWorkout.SetRow]) -> [Int] {
    var warm = 0, work = 0
    return sets.map { set in
      if set.warmup { warm += 1; return warm }
      work += 1
      return work
    }
  }

  // "Série 2 de 3", contando só as de trabalho, ou "Aquecimento 1", como a Live Activity do openGym
  // (lib/live-activity.js:90).
  private static func setTitle(_ sets: [ActiveWorkout.SetRow], at index: Int, text: WorkoutText) -> String {
    let set = sets[index]
    let same = sets[...index].filter { $0.warmup == set.warmup }.count
    if set.warmup { return text.label(same, warmup: true) }
    return text.setOf(same, sets.filter { !$0.warmup }.count)
  }

  // A fala de uma linha, sem o "feita": a série, e a carga e as repetições da série comum de repetições,
  // os segundos (e a carga, quando há) da série com tempo, ou o texto do motor nas outras. O esforço
  // registrado entra no fim.
  private static func spoken(_ set: ActiveWorkout.SetRow, label: String, mode: String, unit: WeightUnit, text: WorkoutText) -> String {
    var parts = [label]
    let locale = text.textLocale
    switch (mode, set.kind) {
    case ("reps", "normal"):
      if let w = set.w { parts.append(WorkoutFormat.spokenLoad(w, unit: unit, locale: locale)) }
      if let r = set.r { parts.append(WorkoutFormat.spokenReps(r, locale: locale)) }
    case ("time", "normal"):
      if let sec = set.sec { parts.append(spokenSeconds(sec, locale: locale)) }
      if let w = set.w, w > 0 { parts.append(WorkoutFormat.spokenLoad(w, unit: unit, locale: locale)) }
    default:
      if !set.line.isEmpty { parts.append(set.line) }
    }
    if let rir = set.rir {
      parts.append(WorkoutFormat.spokenEffort(rir, scale: .rir, locale: locale))
    } else if let rpe = set.rpe {
      parts.append(WorkoutFormat.spokenEffort(rpe, scale: .rpe, locale: locale))
    }
    return parts.joined(separator: ", ")
  }

  // "45 segundos".
  private static func spokenSeconds(_ seconds: Int, locale: Locale) -> String {
    Measurement(value: Double(seconds), unit: UnitDuration.seconds)
      .formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))).locale(locale))
  }

  // O alvo, quando ele se lê: o exLine do openGym escreve "undefined" num alvo sem séries ou sem
  // repetições, que um aparelho antigo pode ter deixado.
  private static func readable(_ target: String) -> String? {
    let trimmed = target.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !trimmed.contains("undefined"), !trimmed.contains("NaN") else { return nil }
    return trimmed
  }

  private static func exists(_ ref: WorkoutRef, in workout: ActiveWorkout) -> Bool {
    workout.entries.indices.contains(ref.entry) && workout.entries[ref.entry].sets.indices.contains(ref.set)
  }
}

// O estado da tela do treino: a série tocada e o modelo, lido de novo a cada treino que o WorkoutSession
// publica, e as ações, que vão ao motor pelo WorkoutSession (a gravação e os efeitos dele) uma de cada vez,
// cada uma esperando a de antes: o motor recebe cada toque na ordem, nenhum se perde e nenhum vira dois,
// e a série de cada toque é a que a tela mostrava na hora dele. Mora fora da view, no RootView: a tela
// recomeça quando o Reduzir Movimento muda com ela aberta (StartWorkoutTransition), e a série tocada fica.
@Observable @MainActor final class WorkoutScreen {
  private(set) var model: WorkoutScreenModel?
  // A linha tocada, até ser marcada ou até o "Próxima série".
  private(set) var selection: WorkoutRef?

  @ObservationIgnored let text: WorkoutText
  @ObservationIgnored let session: WorkoutSession
  @ObservationIgnored private let engine: HexEngine
  @ObservationIgnored private var language: Locale?
  @ObservationIgnored private var loading: Task<Void, Never>?
  // A última ação mandada, que a próxima espera.
  @ObservationIgnored private var last: Task<Void, Never>?
  // O treino da série tocada: num treino novo, ela não vale mais.
  @ObservationIgnored private var workoutID: String?

  private static let logger = Logger(subsystem: "app.hexgym", category: "treino")

  init(app: AppModel, locale: Locale = .current) {
    session = app.session
    engine = app.engine
    text = WorkoutText(locale: locale)
    watch()
    rebuild()
    // O idioma dos nomes, o do motor, lido uma vez.
    let engine = engine
    loading = Task { [weak self] in
      let language = (try? await engine.load().language).map(Locale.init(identifier:))
      guard let self else { return }
      self.language = language
      rebuild()
    }
  }

  // Volta quando o idioma dos nomes já chegou e as ações mandadas já foram aplicadas.
  func ready() async {
    await loading?.value
    await last?.value
    rebuild()
  }

  // O "Registrar série": marca a série do painel e, quando ela era a tocada, o painel volta à série que o
  // motor diz (o next). Com a linha tocada já feita, o botão é o "Próxima série", que só volta.
  @discardableResult func log() -> Task<Void, Never> {
    guard let panel = model?.panel, let action = panel.action else { return Task {} }
    guard action == .log else {
      selection = nil
      rebuild()
      return Task {}
    }
    let ref = panel.ref
    return send(.markSet(entry: ref.entry, set: ref.set, done: true)) { [weak self] in
      guard let self else { return }
      if selection == ref { selection = nil; rebuild() }
      // A série atual nova é anunciada, para quem não vê o painel mudar.
      if let title = model?.panel?.title { AccessibilityNotification.Announcement(title).post() }
    }
  }

  // Um toque numa linha: ela vai para o painel, e o exercício dela passa a ser o atual no motor (o focus).
  @discardableResult func select(_ ref: WorkoutRef) -> Task<Void, Never> {
    selection = ref
    rebuild()
    return send(.focus(entry: ref.entry))
  }

  // A marca de feita de uma linha: o contrário do que ela está. Marcada, a linha tocada deixa o painel.
  @discardableResult func mark(_ row: WorkoutRow) -> Task<Void, Never> {
    let mark = row.mark
    return send(mark.action) { [weak self] in
      guard let self, mark.done, selection == row.ref else { return }
      selection = nil
      rebuild()
    }
  }

  // Um passo de uma entrada do painel, na série que o painel mostra na hora do toque. A entrada não decide
  // o passo: o motor aplica a regra do openGym.
  @discardableResult func step(_ field: SetField, _ direction: StepDirection) -> Task<Void, Never> {
    guard let ref = model?.panel?.ref else { return Task {} }
    return send(.stepSet(entry: ref.entry, set: ref.set, field: field, direction: direction == .up ? .up : .down))
  }

  // Manda a ação depois da de antes, e lê o modelo de novo com o treino que ela deu. Um erro do motor vai
  // para o log, e nada muda.
  private func send(_ action: SessionAction, then: (@MainActor () -> Void)? = nil) -> Task<Void, Never> {
    let previous = last
    let task = Task { [weak self] in
      await previous?.value
      guard let self else { return }
      do {
        _ = try await session.perform(action)
        rebuild()
        then?()
      } catch {
        Self.logger.error("a ação do treino não foi aplicada (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
        rebuild()
      }
    }
    last = task
    return task
  }

  private func rebuild() {
    guard let workout = session.workout else {
      model = nil
      selection = nil
      workoutID = nil
      return
    }
    if let id = workoutID, id != workout.id { selection = nil }
    workoutID = workout.id
    model = WorkoutScreenModel(workout: workout, selection: selection, text: text, language: language)
  }

  // Um treino novo no WorkoutSession (uma ação, uma revision de fora, o refresh da volta para a frente)
  // lê o modelo de novo. O withObservationTracking avisa uma vez só, e por isso recomeça a cada aviso.
  private func watch() {
    withObservationTracking { _ = session.workout } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.watch()
        self?.rebuild()
      }
    }
  }
}
