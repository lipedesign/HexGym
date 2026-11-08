// A tela inicial sem tela (Task 7 do plano da fase 3, issue #136). O HomeModel monta, do resumo do motor
// (engine.home(), o HomeSummary da Task 4) e das rotinas (engine.routines()), tudo o que o Início mostra e
// o que o VoiceOver diz: o cartão de hoje, o botão principal, o "Escolher outro treino" com as rotinas e o
// treino livre, o treino em andamento ("5 de 18 séries"), a semana com as letras e a fala, a sequência de
// semanas, os treinos da semana e do histórico, e o último treino. O HomeScreen é o estado da tela: lê no
// motor, fora da thread principal, e começa o treino pelo WorkoutSession. A tela não calcula nada no body.
//
// Toda regra fica no motor (seção 8.2): o status de hoje (planned, rest, none ou done), as rotinas do dia
// pelo effectiveRoutineIds, a semana na ordem do weekStart, o streakWeeks, o weekTally e o último treino
// pelo byNewest. Aqui só se escolhe o texto e a ordem dos itens do menu.
//
// Os textos que o openGym já tem são os dele (views/Home.jsx e o pacote pt-BR, que herda do pt), com a
// chave em inglês dele: no cartão, "Hoje" em cima e, no título, as rotinas de hoje juntas por " + " (o
// todayName), "Dia de descanso", "Push (em andamento)", "Push (concluído)" ou "Treino concluído", e, num
// dia de descanso ou sem nada marcado, "Próxima sessão: Segunda, Push" (o next do motor, a linha do
// views/Home.jsx:145); "Começar treino", "Continuar treino", "Escolher outro treino" e "Treino livre
// (escolha durante o treino)"; "Sequência de 3 semanas" e "2 esta semana · 12 treinos no total"; "Último
// treino"; e, na fala da semana, "treinado", "planejado", "descanso" e "hoje". A duração do último treino
// é a do fmtDur do openGym, em minutos inteiros para baixo, e some sem relógio (o durPart, abaixo de 1
// minuto). Onde o openGym não tem o texto, ficam os do plano: "Monte a sua primeira rotina" (a mesma chave
// da aba Rotinas vazia), "Começar treino livre" e "Ir para Rotinas".
//
// Escolhas recomendadas, com a delegação do Lipe de 03/11/2026: no dia de treino, o botão principal
// começa as rotinas de hoje, e o "Escolher outro treino" fica embaixo dele, com as outras rotinas e o
// treino livre; num dia de descanso, sem nada marcado ou com o treino de hoje feito, não há botão grande,
// só o "Escolher outro treino" no estilo secundário, com todas as rotinas, porque o openGym não empurra um
// segundo treino no mesmo dia; com o treino em andamento, não há outro treino, como no openGym; o cartão
// diz até quatro exercícios, e "e mais 2" depois; o dia sem nada marcado diz "Nada marcado para hoje" (o
// openGym diz "Dia de descanso" também nele); a sequência só aparece com pelo menos uma semana, porque
// "Sequência de 0 semanas" não diz nada, e os totais, com qualquer histórico; a fala da semana não repete
// "Semana", que o título em cima dela já diz.

import Foundation
import HexDesign
import HexEngine
import Observation
import os

// Os textos que o modelo usa, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct HomeText: Sendable {
  let locale: Locale
  // O idioma dos textos do app (o catálogo tem só o português e o inglês), para o calendário e as datas.
  let textLocale: Locale
  private let portuguese: Bool
  let today, restDay, nothingPlanned, workoutDone, startWorkout, continueWorkout, chooseWorkout, freestyle, startFreestyle,
      firstRoutine, firstRoutineDetail, goToRoutines, trained, planned, rest, todayWord, oneWeekStreak,
      oneWorkoutTotal, oneSet: String
  private let inProgressFormat, doneFormat, moreFormat, weekStreakFormat, thisWeekFormat, workoutsTotalFormat,
      setsFormat, minutesFormat, hoursFormat, nextFormat: String
  // Os dias pelo getDay() (0 é o domingo): a letra embaixo da semana ("S"), o nome no meio de uma frase
  // ("segunda") e o nome sozinho ("Segunda", na "Próxima sessão"). A grafia é a do catálogo do HexGym, a
  // chave Monday da fase 2: o t(DAYN[d]) do openGym diz "Segunda-feira" (pt.js:48).
  private let letters, sentenceDays, dayNames: [String]

  @MainActor init(locale: Locale) {
    self.locale = locale
    portuguese = locale.language.languageCode == .portuguese
    textLocale = Locale(identifier: portuguese ? "pt-BR" : "en")
    func text(_ key: String) -> String { AppText.text(key, locale: locale) }
    today = text("Today")
    restDay = text("Rest day")
    nothingPlanned = text("Nothing planned for today")
    workoutDone = text("Workout done")
    startWorkout = text("Start workout")
    continueWorkout = text("Continue workout")
    chooseWorkout = text("Choose a different workout")
    freestyle = text("Freestyle workout (pick as you go)")
    startFreestyle = text("Start freestyle workout")
    firstRoutine = text("Build your first routine")
    firstRoutineDetail = text("Set up your weekly routine to get going, or grab a ready-made starter plan.")
    goToRoutines = text("Go to Routines")
    oneWeekStreak = text("1 week streak")
    oneWorkoutTotal = text("1 workout total")
    oneSet = text("1 set")
    inProgressFormat = text("%@ (in progress)")
    doneFormat = text("%@ (done)")
    moreFormat = text("%@ and %lld more")
    weekStreakFormat = text("%lld week streak")
    thisWeekFormat = text("%lld this week")
    workoutsTotalFormat = text("%lld workouts total")
    setsFormat = text("%lld sets")
    minutesFormat = text("%lld min")
    hoursFormat = text("%lldh %lldm")
    nextFormat = text("Next session: %@, %@")
    // No meio da fala, as palavras do estado do dia em minúscula: "segunda, hoje, planejado".
    let textLocale = textLocale
    func word(_ key: String) -> String { text(key).lowercased(with: textLocale) }
    trained = word("Trained")
    planned = word("Planned")
    rest = word("Rest")
    todayWord = word("Today")
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = textLocale
    letters = calendar.veryShortStandaloneWeekdaySymbols
    let portuguese = portuguese
    dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].map(text)
    sentenceDays = dayNames.map { portuguese ? $0.lowercased(with: textLocale) : $0 }
  }

  func letter(_ day: Int) -> String { letters.indices.contains(day) ? letters[day] : "" }
  func sentenceDay(_ day: Int) -> String { sentenceDays.indices.contains(day) ? sentenceDays[day] : "" }

  // "Próxima sessão: Quarta, Pull".
  func next(weekday: Int, name: String) -> String {
    String(format: nextFormat, locale: locale, dayNames.indices.contains(weekday) ? dayNames[weekday] : "", name)
  }

  func inProgress(_ name: String) -> String { String(format: inProgressFormat, locale: locale, name) }
  func done(_ name: String) -> String { String(format: doneFormat, locale: locale, name) }

  // "Supino reto, Crucifixo e Agachamento" ou, com mais de quatro, "Supino reto, ..., Elevação lateral e
  // mais 2".
  func exercises(_ names: [String]) -> String? {
    guard !names.isEmpty else { return nil }
    let shown = 4
    guard names.count > shown else { return names.formatted(.list(type: .and).locale(textLocale)) }
    return String(format: moreFormat, locale: locale, names.prefix(shown).joined(separator: ", "), names.count - shown)
  }

  // "Sequência de 1 semana" e "Sequência de 3 semanas": o openGym tem só o plural ("{0} week streak").
  func streak(_ weeks: Int) -> String {
    weeks == 1 ? oneWeekStreak : String(format: weekStreakFormat, locale: locale, weeks)
  }

  // "2 esta semana · 12 treinos no total", a linha de baixo da sequência no openGym.
  func tally(week: Int, total: Int) -> String {
    let totals = total == 1 ? oneWorkoutTotal : String(format: workoutsTotalFormat, locale: locale, total)
    return String(format: thisWeekFormat, locale: locale, week) + LibraryNames.separator + totals
  }

  func sets(_ count: Int) -> String {
    count == 1 ? oneSet : String(format: setsFormat, locale: locale, count)
  }

  // "52 min" e "1 h 12 min", como o fmtDur do openGym ('{0} min' e '{0}h {1}m'); os minutos vêm inteiros,
  // para baixo, do lastWorkout.
  func duration(minutes: Int) -> String {
    minutes < 60 ? String(format: minutesFormat, locale: locale, minutes)
      : String(format: hoursFormat, locale: locale, minutes / 60, minutes % 60)
  }
}

// Uma rotina no "Escolher outro treino": o id, o nome e o símbolo do ícone dela.
nonisolated struct HomeChoice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let symbol: String
}

// O treino em andamento no cartão: o começo, para o tempo que passa, e as séries.
nonisolated struct HomeActiveCard: Equatable, Sendable {
  let start: Date?
  let done: Int, total: Int
  // "5 de 18 séries".
  let progress: String
}

// Um dia da semana: a letra, cheio quando treinou, contornado quando estava planejado, e o hoje.
nonisolated struct HomeDay: Identifiable, Equatable, Sendable {
  let day: Int
  let letter: String
  let trained: Bool, planned: Bool, today: Bool
  var id: Int { day }
}

// O último treino: a chave do Histórico (que abre o detalhe a partir da Task 12), o nome, a linha de
// baixo ("sex., 6 de nov. · 52 min · 18 séries") e a fala.
nonisolated struct HomeLastWorkout: Equatable, Sendable {
  let key: String
  let name: String
  let detail: String
  let spoken: String
}

nonisolated struct HomeModel: Equatable, Sendable {
  // O que o botão principal faz: continuar o treino em andamento, começar as rotinas de hoje, começar o
  // treino livre (sem rotinas) ou abrir o "Escolher outro treino".
  enum Primary: Equatable, Sendable { case resume, start([String]), freestyle, choose }

  // "Hoje · segunda".
  let eyebrow: String
  let title: String
  // "Próxima sessão: Segunda, Push", num dia de descanso ou sem nada marcado, quando há um dia com treino
  // nos próximos sete.
  let nextSession: String?
  // Os exercícios das rotinas de hoje, ou, no app vazio, a frase do openGym.
  let detail: String?
  let primary: Primary
  let primaryLabel: String
  // O "Escolher outro treino" embaixo do botão principal, no dia de treino. Com o primary .choose, ele é
  // o único botão, no estilo secundário: o botão grande fica para o dia de treino, o treino em andamento
  // e o app vazio.
  let offersChooser: Bool
  let chooserLabel: String
  // As rotinas do menu, na ordem da lista; o treino livre vem no fim.
  let chooser: [HomeChoice]
  let freestyleLabel: String
  // Só no app vazio: o botão para a aba Rotinas, no cartão.
  let goesToRoutines: Bool
  let routinesLabel: String
  let active: HomeActiveCard?
  let week: [HomeDay]
  // "segunda, hoje, planejado; terça, descanso; ...", embaixo do título "Semana".
  let weekSpoken: String
  // A sequência, só com pelo menos uma semana; os totais, com qualquer histórico.
  let streak: String?
  let tally: String?
  let last: HomeLastWorkout?

  // O language é o idioma dos nomes dos exercícios, o do motor: o primeiro caractere de cada nome vai em
  // maiúscula nesse idioma, como no editor de rotina ("Supino com barra").
  init(summary: HomeSummary, routines: [RoutineSummary], text: HomeText, language: Locale? = nil) {
    let today = summary.today
    let todayIDs = today.routines.map(\.id)
    let byID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let weekday = summary.week.first(where: \.today)?.day ?? Self.weekday(of: today.date)
    eyebrow = [text.today, weekday.map(text.sentenceDay)].compactMap { $0 }.joined(separator: LibraryNames.separator)

    chooserLabel = text.chooseWorkout
    freestyleLabel = text.freestyle
    routinesLabel = text.goToRoutines
    let choices = routines.map { HomeChoice(id: $0.id, name: $0.name, symbol: RoutineGlyph.symbol(for: $0.glyph)) }

    if let running = summary.active {
      title = text.inProgress(running.name)
      nextSession = nil
      detail = nil
      primary = .resume
      primaryLabel = text.continueWorkout
      offersChooser = false
      chooser = []
      goesToRoutines = false
      active = HomeActiveCard(start: running.start, done: running.done, total: running.total,
                              progress: SlantedSegments.spokenValue(total: running.total, done: running.done, locale: text.textLocale))
    } else if routines.isEmpty {
      // O app vazio (Foco da revisão 5): sem rotina para começar, o treino livre.
      title = text.firstRoutine
      nextSession = nil
      detail = text.firstRoutineDetail
      primary = .freestyle
      primaryLabel = text.startFreestyle
      offersChooser = false
      chooser = []
      goesToRoutines = true
      active = nil
    } else if today.status == "planned", !todayIDs.isEmpty {
      title = today.routines.map(\.name).joined(separator: " + ")
      nextSession = nil
      let language = language ?? text.textLocale
      detail = text.exercises(todayIDs.flatMap { byID[$0]?.slots.map { LibraryNames.capitalized($0.name, language: language) } ?? [] })
      primary = .start(todayIDs)
      primaryLabel = text.startWorkout
      offersChooser = true
      chooser = choices.filter { !todayIDs.contains($0.id) }
      goesToRoutines = false
      active = nil
    } else {
      // Feito, descanso ou nada marcado. A próxima sessão não aparece com o treino de hoje feito, como no
      // openGym (o next && !doneToday).
      if today.status == "done" {
        let name = summary.last.flatMap { $0.d == today.date && !$0.name.isEmpty ? $0.name : nil }
        title = name.map(text.done) ?? text.workoutDone
        nextSession = nil
      } else {
        title = today.status == "none" ? text.nothingPlanned : text.restDay
        nextSession = summary.next.map { text.next(weekday: $0.weekday, name: $0.name) }
      }
      detail = nil
      primary = .choose
      primaryLabel = text.chooseWorkout
      offersChooser = false
      chooser = choices
      goesToRoutines = false
      active = nil
    }

    week = summary.week.map { HomeDay(day: $0.day, letter: text.letter($0.day), trained: $0.trained, planned: $0.planned, today: $0.today) }
    weekSpoken = summary.week.map { day in
      let state = day.trained ? text.trained : day.planned ? text.planned : text.rest
      return ([text.sentenceDay(day.day)] + (day.today ? [text.todayWord] : []) + [state]).joined(separator: ", ")
    }.joined(separator: "; ")

    let hasHistory = summary.total > 0
    streak = summary.streakWeeks >= 1 ? text.streak(summary.streakWeeks) : nil
    tally = hasHistory ? text.tally(week: summary.weekCount, total: summary.total) : nil
    last = summary.last.map { Self.lastWorkout($0, text: text) }
  }

  // O tempo que passa desde o começo do treino: "23:14" abaixo de uma hora, "1:02:10" acima.
  static func elapsed(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
  }

  // A fala do tempo que passa: "23 minutos e 14 segundos".
  static func spokenElapsed(_ seconds: TimeInterval, locale: Locale) -> String {
    spokenDuration(max(0, seconds.rounded(.down)), units: [.hour, .minute, .second], locale: locale)
  }

  // O getDay() de um dia "2026-11-09", no calendário gregoriano.
  static func weekday(of iso: String) -> Int? {
    day(iso).map { utc.component(.weekday, from: $0) - 1 }
  }

  private static func lastWorkout(_ last: HomeSummary.Last, text: HomeText) -> HomeLastWorkout {
    // O fmtDur do openGym: os minutos inteiros, para baixo (59 min e 40 s dão "59 min"), e nada abaixo de
    // 1 minuto, o treino sem relógio (o durPart).
    let minutes = last.durationMs >= 60_000 ? Int((last.durationMs / 60_000).rounded(.down)) : nil
    let date = last.d.flatMap(day)
    let short = date?.formatted(Date.FormatStyle(locale: text.textLocale, calendar: utc, timeZone: .gmt)
      .weekday(.abbreviated).day().month(.abbreviated))
    let long = date?.formatted(Date.FormatStyle(locale: text.textLocale, calendar: utc, timeZone: .gmt)
      .weekday(.wide).day().month(.wide))
    let sets = text.sets(last.sets)
    let detail = ([short, minutes.map(text.duration), sets].compactMap { $0 }).joined(separator: LibraryNames.separator)
    let spokenMinutes = minutes.map { spokenDuration(TimeInterval($0 * 60), units: [.hour, .minute], locale: text.textLocale) }
    let spoken = ([last.name, long, spokenMinutes, sets]
      .compactMap { $0 }).joined(separator: ", ")
    return HomeLastWorkout(key: last.key, name: last.name, detail: detail, spoken: spoken)
  }

  // Os dias do documento são datas de calendário, sem hora: lidos e escritos em UTC, para nenhum fuso
  // mudar o dia.
  private static let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  private static func day(_ iso: String) -> Date? {
    let parts = iso.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
  }

  private static func spokenDuration(_ seconds: TimeInterval, units: NSCalendar.Unit, locale: Locale) -> String {
    let formatter = DateComponentsFormatter()
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    formatter.calendar = calendar
    formatter.allowedUnits = units
    formatter.unitsStyle = .full
    formatter.zeroFormattingBehavior = .dropAll
    return formatter.string(from: seconds) ?? ""
  }
}

// O estado da tela inicial: o modelo, lido no motor fora da thread principal, e o começo de um treino
// pelo WorkoutSession (o motor e a gravação do AppModel). A tela lê de novo a cada revision do documento,
// e ao voltar para a frente (o dia pode ter virado).
@Observable @MainActor final class HomeScreen {
  enum Phase: Equatable { case loading, ready, failed }

  private(set) var phase = Phase.loading
  private(set) var model: HomeModel?
  // Um treino sendo começado, para um segundo toque não começar outro.
  private(set) var starting = false

  // O revision do documento, lido pela tela para ler de novo depois de uma ação.
  var documentRevision: Int { revision() }

  @ObservationIgnored let text: HomeText
  @ObservationIgnored private let engine: HexEngine
  @ObservationIgnored private let revision: () -> Int
  @ObservationIgnored private let perform: (SessionAction) async throws -> SessionOutcome

  private static let logger = Logger(subsystem: "app.hexgym", category: "home")

  init(engine: HexEngine, locale: Locale = .current, revision: @escaping () -> Int = { 0 },
       perform: @escaping (SessionAction) async throws -> SessionOutcome) {
    self.engine = engine
    self.revision = revision
    self.perform = perform
    text = HomeText(locale: locale)
  }

  // O app de verdade: o motor, o revision e o treino do AppModel.
  convenience init(app: AppModel) {
    self.init(engine: app.engine, revision: { app.revision }, perform: { try await app.session.perform($0) })
  }

  func load() async {
    do {
      let summary = try await engine.home()
      let routines = try await engine.routines()
      let language = Locale(identifier: try await engine.load().language)
      model = HomeModel(summary: summary, routines: routines, text: text, language: language)
      phase = .ready
    } catch {
      Self.log("não deu para ler a tela inicial", error)
      if phase == .loading { phase = .failed }
    }
  }

  // Começa o treino das rotinas dadas, ou o treino livre, sem rotina. O id do treino vem daqui (a escolha
  // 12 do plano: o uid() do openGym não entra no motor). Até a Task 8, nenhuma tela abre: o Início passa
  // a mostrar o treino em andamento.
  func start(_ routineIDs: [String]) async {
    guard !starting else { return }
    starting = true
    defer { starting = false }
    let before = revision()
    do {
      _ = try await perform(.start(routineIDs: routineIDs, id: UUID().uuidString.lowercased()))
    } catch {
      Self.log("não deu para começar o treino", error)
    }
    // Com o documento mudado, o revision sobe e a tela já lê de novo (o onChange do HomeView): ler aqui
    // também seria ler o motor duas vezes.
    if revision() == before { await load() }
  }

  private static func log(_ what: String, _ error: any Error) {
    logger.error("\(what, privacy: .public) (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
  }
}
