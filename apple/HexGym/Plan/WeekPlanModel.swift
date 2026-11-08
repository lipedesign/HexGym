// O plano da semana sem tela (Task 12 do plano da fase 2, issue #99). O WeekPlanModel monta, da semana e
// das rotinas do motor (engine.week() e engine.routines()), tudo o que a semana no topo da aba Rotinas, a
// escolha das rotinas de um dia e os planos prontos mostram e o que o VoiceOver diz: os sete dias na
// ordem da semana do perfil, com o rótulo curto ("Seg") e por extenso ("Segunda-feira"), as rotinas de
// cada dia ou "Descanso", as rotinas marcadas na escolha de um dia, os quatro planos prontos com os dias
// que ocupam e o aviso dos dias que um plano troca ("Este plano troca segunda, quarta e sexta."). O
// WeekPlanScreen é o estado da tela: lê no motor, muda a tela na hora e manda a ação pelo perform. A
// tela não calcula nada no body.
//
// Toda regra continua no motor (seção 8.2): o week.set e o plan.starter, que é o loadStarterPlan do
// sheets.jsx. As ações acham as rotinas pelo id, nunca pela posição na tela. O que fica aqui é a conta
// do aviso, que o motor não tem como leitura: o plan.starter reaproveita a rotina que já existe com o
// mesmo nome e os mesmos exercícios e põe uma rotina só em cada dia do plano, e os outros dias ficam como
// estavam. Um dia do plano é trocado de fato quando tinha alguma rotina (um id que não é mais rotina não
// conta, como o "taken" do StarterPlanChooser do openGym) e vai ficar com outra coisa. Um dia vazio que o
// plano preenche não é trocado, e o openGym também não avisa por ele. Para a conta, o StarterPlanCatalog
// leva os nomes, os exercícios e os dias dos quatro planos, copiados do lib/starter.js; os testes
// (WeekPlanModelTests) conferem a tabela e o aviso contra o motor de verdade, nos quatro planos.
//
// No log, como no AppModel, o tipo do erro fica público e o detalhe, privado, porque a mensagem do motor
// pode trazer um pedaço do documento.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: as rotinas de um dia juntas por "e"
// ("Peito e Costas"), como o VoiceOver diz; os dias de um plano na segunda linha, depois de "3 dias por
// semana"; o aviso só quando o plano troca um dia que tinha rotina, como o openGym, e sem aviso, o plano
// entra no primeiro toque.

import Foundation
import HexEngine
import Observation
import os

// Os textos que o modelo usa, lidos uma vez, na thread principal, no idioma da tela.
nonisolated struct WeekPlanText: Sendable {
  let locale: Locale
  // Os dias pelo getDay() (0 é o domingo): curtos ("Seg"), por extenso para o VoiceOver
  // ("Segunda-feira") e no meio de uma frase ("segunda").
  private let shortDays, fullDays, sentenceDays: [String]
  let rest: String
  let restDay: String
  private let oneDay, manyDays, changesFormat, loadedFormat, loadTitleFormat: String
  private let names, abouts: [String: String]
  let routines: RoutineEditorText

  @MainActor init(locale: Locale) {
    self.locale = locale
    let portuguese = locale.language.languageCode == .portuguese
    shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map { AppText.text($0, locale: locale) }
    // Os nomes inteiros do calendário, no idioma dos textos do app (o catálogo tem só o português e o
    // inglês): "segunda-feira" em português, com a primeira letra em maiúscula.
    var calendar = Calendar(identifier: .gregorian)
    let textLocale = Locale(identifier: portuguese ? "pt-BR" : "en")
    calendar.locale = textLocale
    fullDays = calendar.standaloneWeekdaySymbols.map { $0.prefix(1).uppercased(with: textLocale) + $0.dropFirst() }
    // "Segunda" do catálogo e, no meio da frase em português, "segunda"; em inglês, "Monday".
    sentenceDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].map {
      let name = AppText.text($0, locale: locale)
      return portuguese ? name.lowercased(with: textLocale) : name
    }
    rest = AppText.text("Rest", locale: locale)
    restDay = AppText.text("Rest day", locale: locale)
    oneDay = AppText.text("1 day per week", locale: locale)
    manyDays = AppText.text("%lld days per week", locale: locale)
    changesFormat = AppText.text("This plan changes %@.", locale: locale)
    loadedFormat = AppText.text("%@ plan loaded", locale: locale)
    loadTitleFormat = AppText.text("Load the %@ plan?", locale: locale)
    // Os nomes e as descrições do PLAN_COPY do sheets.jsx, no catálogo do app.
    names = [
      "ppl": AppText.text("Push / Pull / Legs", locale: locale),
      "upper-lower": AppText.text("Upper / Lower", locale: locale),
      "full-body": AppText.text("Full Body", locale: locale),
      "5x5": AppText.text("5×5", locale: locale),
    ]
    abouts = [
      "ppl": AppText.text("Push, pull and legs each get their own day.", locale: locale),
      "upper-lower": AppText.text("Upper body twice, lower body twice.", locale: locale),
      "full-body": AppText.text("Three sessions, the whole body each time.", locale: locale),
      "5x5": AppText.text("Five sets of five on the main barbell lifts.", locale: locale),
    ]
    routines = RoutineEditorText(locale: locale)
  }

  func short(_ day: Int) -> String { shortDays[day] }
  func full(_ day: Int) -> String { fullDays[day] }

  // "Peito e Costas".
  func list(_ items: [String]) -> String {
    items.formatted(.list(type: .and).locale(locale))
  }

  // "Este plano troca segunda, quarta e sexta."
  func changes(_ days: [Int]) -> String {
    String(format: changesFormat, locale: locale, list(days.map { sentenceDays[$0] }))
  }

  // "Plano Empurrar, puxar, pernas carregado", o anúncio do VoiceOver.
  func loaded(_ planName: String) -> String {
    String(format: loadedFormat, locale: locale, planName)
  }

  // "Carregar o plano Corpo inteiro?", o título do aviso.
  func loadTitle(_ planName: String) -> String {
    String(format: loadTitleFormat, locale: locale, planName)
  }

  func daysPerWeek(_ count: Int) -> String {
    count == 1 ? oneDay : String(format: manyDays, locale: locale, count)
  }

  func planName(_ id: String) -> String? { names[id] }
  func planAbout(_ id: String) -> String? { abouts[id] }
}

// Um dia da semana, pronto para a linha: o rótulo curto, as rotinas dele ("Peito e Costas") ou
// "Descanso", e o rótulo do VoiceOver ("Segunda-feira, Peito e Costas").
nonisolated struct WeekDayRow: Identifiable, Equatable, Sendable {
  // O getDay() do dia: 0 é o domingo.
  let day: Int
  let short: String
  let full: String
  // As rotinas do dia, pelos ids, na ordem do documento.
  let routineIDs: [String]
  let routines: String
  let isRest: Bool
  let spoken: String

  var id: Int { day }
}

// Uma rotina na escolha de um dia: o ícone, o nome, "6 exercícios" e a marca.
nonisolated struct DayChoice: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let symbol: String
  let detail: String
  let isOn: Bool
  // O nome e a contagem; a marca vai no traço de escolhido do botão.
  let spoken: String
}

// Um plano pronto, pronto para a linha: o nome, a descrição, os dias que ele ocupa e o rótulo do
// VoiceOver.
nonisolated struct StarterPlanRow: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let about: String
  // Os dias do plano, na ordem da semana do perfil.
  let days: [Int]
  // "3 dias por semana · Seg, Qua, Sex".
  let detail: String
  let spoken: String
}

// Os quatro planos do lib/starter.js do openGym: em cada dia, o nome da rotina e os exercícios dela, na
// ordem. É o que o plan.starter compara para reaproveitar uma rotina que já existe (o sameLift do
// sheets.jsx). Os testes conferem a tabela contra as rotinas que o motor cria.
nonisolated enum StarterPlanCatalog {
  struct Entry: Equatable, Sendable {
    let day: Int
    let name: String
    let exercises: [String]
  }

  static func schedule(of id: String) -> [Entry]? { plans[id] }

  private static let plans: [String: [Entry]] = [
    "ppl": [
      Entry(day: 1, name: "Push Day", exercises: ["0025", "0047", "0426", "0334", "0241", "0251"]),
      Entry(day: 3, name: "Pull Day", exercises: ["2330", "0027", "1323", "0031", "0313"]),
      Entry(day: 5, name: "Leg Day", exercises: ["0043", "0085", "0739", "0585", "0586", "0605"]),
    ],
    "upper-lower": [
      Entry(day: 1, name: "Upper A", exercises: ["0025", "2330", "0047", "1323", "0334", "0241", "0031"]),
      Entry(day: 2, name: "Lower A", exercises: ["0043", "0085", "0739", "0586", "0605"]),
      Entry(day: 4, name: "Upper B", exercises: ["0047", "0027", "0426", "2330", "0334", "0241", "0313"]),
      Entry(day: 5, name: "Lower B", exercises: ["0739", "0085", "0585", "0586", "0605"]),
    ],
    "full-body": [
      Entry(day: 1, name: "Full Body A", exercises: ["0043", "0025", "2330", "0586", "0334", "0031"]),
      Entry(day: 3, name: "Full Body B", exercises: ["0085", "0047", "1323", "0585", "0334", "0241"]),
      Entry(day: 5, name: "Full Body C", exercises: ["0739", "0025", "0027", "0426", "0586", "0605"]),
    ],
    "5x5": [
      Entry(day: 1, name: "5×5 A", exercises: ["0043", "0025", "0027"]),
      Entry(day: 3, name: "5×5 B", exercises: ["0085", "0426", "2330"]),
      Entry(day: 5, name: "5×5 C", exercises: ["0739", "0047", "1323"]),
    ],
  ]
}

nonisolated struct WeekPlanModel: Sendable {
  let weekStart: Int
  let days: [WeekDayRow]
  let plans: [StarterPlanRow]
  private let order: [Int]
  private let assigned: [Int: [String]]
  private let routines: [RoutineSummary]
  private let options: [StarterPlanOption]
  private let text: WeekPlanText

  // As rotinas de cada dia vêm do week(), que já deixa de fora o id que não é mais rotina.
  init(week: WeekPlan, routines: [RoutineSummary], plans: [StarterPlanOption] = [], text: WeekPlanText) {
    self.init(weekStart: week.weekStart, order: week.days.map(\.day),
              assigned: Dictionary(week.days.map { ($0.day, $0.routineIds) }, uniquingKeysWith: { first, _ in first }),
              routines: routines, options: plans, text: text)
  }

  private init(weekStart: Int, order: [Int], assigned: [Int: [String]], routines: [RoutineSummary], options: [StarterPlanOption],
               text: WeekPlanText) {
    self.weekStart = weekStart
    self.order = order
    self.assigned = assigned
    self.routines = routines
    self.options = options
    self.text = text
    let names = Dictionary(routines.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    days = order.map { day in
      let ids = (assigned[day] ?? []).filter { names[$0] != nil }
      let routines = ids.isEmpty ? text.rest : text.list(ids.compactMap { names[$0] })
      return WeekDayRow(day: day, short: text.short(day), full: text.full(day), routineIDs: ids, routines: routines,
                        isRest: ids.isEmpty, spoken: "\(text.full(day)), \(routines)")
    }
    plans = options.compactMap { option in
      guard let schedule = StarterPlanCatalog.schedule(of: option.id), let name = text.planName(option.id),
            let about = text.planAbout(option.id) else { return nil }
      let planDays = order.filter { day in schedule.contains { $0.day == day } }
      let count = text.daysPerWeek(option.days)
      return StarterPlanRow(
        id: option.id, name: name, about: about, days: planDays,
        detail: ([count] + [planDays.map(text.short).joined(separator: ", ")]).joined(separator: LibraryNames.separator),
        spoken: [name, count, text.list(planDays.map(text.full)), about].joined(separator: ", "))
    }
  }

  func day(_ day: Int) -> WeekDayRow? {
    days.first { $0.day == day }
  }

  // A escolha das rotinas de um dia: todas, na ordem da lista, com a marca nas do dia.
  func choices(for day: Int) -> [DayChoice] {
    let on = Set(self.day(day)?.routineIDs ?? [])
    return routines.map { routine in
      let count = text.routines.exercises(routine.slots.count)
      return DayChoice(id: routine.id, name: routine.name, symbol: RoutineGlyph.symbol(for: routine.glyph), detail: count,
                       isOn: on.contains(routine.id), spoken: "\(routine.name), \(count)")
    }
  }

  // Marcar ou desmarcar uma rotina no dia, pelo id: a que já estava sai, e a nova vai para o fim, como
  // o DayAssign do openGym.
  static func toggled(_ ids: [String], _ id: String) -> [String] {
    ids.contains(id) ? ids.filter { $0 != id } : ids + [id]
  }

  // A mesma semana com um dia mudado, até a leitura do motor chegar.
  func setting(_ day: Int, to ids: [String]) -> WeekPlanModel {
    var assigned = assigned
    assigned[day] = ids
    return WeekPlanModel(weekStart: weekStart, order: order, assigned: assigned, routines: routines, options: options, text: text)
  }

  // Os dias que o plano troca de fato, na ordem da semana do perfil: os dias dele que tinham rotina e que
  // vão ficar com outra. O plan.starter põe em cada dia do plano só a rotina dele: a que já existe com o
  // mesmo nome e os mesmos exercícios ou, sem ela, uma nova.
  func replacedDays(byPlan id: String) -> [Int] {
    guard let schedule = StarterPlanCatalog.schedule(of: id) else { return [] }
    return order.filter { day in
      guard let entry = schedule.first(where: { $0.day == day }), let current = self.day(day)?.routineIDs, !current.isEmpty
      else { return false }
      let reused = routines.first { $0.name == entry.name && $0.slots.map(\.id) == entry.exercises }
      return reused.map { current != [$0.id] } ?? true
    }
  }

  // "Este plano troca segunda, quarta e sexta.", ou nil quando ele não troca nenhum dia.
  func warning(forPlan id: String) -> String? {
    let days = replacedDays(byPlan: id)
    return days.isEmpty ? nil : text.changes(days)
  }

  func planName(_ id: String) -> String {
    text.planName(id) ?? id
  }
}

// O anúncio de um plano carregado ("Plano Empurrar, puxar, pernas carregado") sai só depois de um
// atraso, quando a tela dos planos já fechou e o foco do VoiceOver já assentou na aba: um anúncio feito
// junto com a troca de foco pode ser cortado por ela (nota 4 do QA do PR #119). A tela passa quem fala
// (o AccessibilityNotification.Announcement), e o teste, quem escuta.
nonisolated enum PlanLoadedAnnouncement {
  static let delay = Duration.milliseconds(700)

  @MainActor @discardableResult
  static func schedule(_ message: String, after delay: Duration = PlanLoadedAnnouncement.delay,
                       post: @escaping @MainActor (String) -> Void) -> Task<Void, Never> {
    Task { @MainActor in
      do { try await Task.sleep(for: delay) } catch { return }
      post(message)
    }
  }
}

// O estado do plano da semana: a semana, a escolha de um dia e os planos prontos. Lê tudo no motor, fora
// da thread principal, e muda o documento só pelas ações (perform), com os ids das rotinas.
@Observable @MainActor final class WeekPlanScreen {
  enum Phase: Equatable { case loading, ready, failed }

  private(set) var phase = Phase.loading
  private(set) var model: WeekPlanModel?
  let text: WeekPlanText

  @ObservationIgnored let engine: HexEngine
  @ObservationIgnored let perform: (EngineAction) async throws -> ActionOutcome
  // A última ação mandada: cada uma espera a de antes, para o motor receber na ordem dos toques.
  @ObservationIgnored private var last: Task<Void, Never>?
  // As ações ainda no caminho: enquanto houver alguma, uma leitura do motor não troca a tela, que já
  // mostra o resultado delas.
  @ObservationIgnored private var pending = 0

  private static let logger = Logger(subsystem: "app.hexgym", category: "week")

  init(engine: HexEngine, locale: Locale = .current, perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.engine = engine
    self.perform = perform
    text = WeekPlanText(locale: locale)
  }

  func load() async {
    guard pending == 0 else { return }
    do {
      let model = WeekPlanModel(week: try await engine.week(), routines: try await engine.routines(),
                                plans: try await engine.starterPlans(), text: text)
      guard pending == 0 else { return }
      self.model = model
      phase = .ready
    } catch {
      Self.log("não deu para ler a semana", error)
      if phase == .loading { phase = .failed }
    }
  }

  // Marca ou desmarca uma rotina no dia: a tela muda na hora, e o dia inteiro vai ao motor.
  @discardableResult func toggle(_ routineID: String, on day: Int) -> Task<Void, Never>? {
    guard let current = model?.day(day) else { return nil }
    return set(day, to: WeekPlanModel.toggled(current.routineIDs, routineID))
  }

  // O dia de descanso: o dia fica sem rotina.
  @discardableResult func rest(_ day: Int) -> Task<Void, Never>? {
    guard let current = model?.day(day), !current.isRest else { return nil }
    return set(day, to: [])
  }

  // Aplica um plano pronto e lê a semana de novo. Devolve se deu certo.
  func loadPlan(_ id: String) async -> Bool {
    await last?.value
    do {
      _ = try await perform(.loadStarterPlan(id: id))
      await load()
      return true
    } catch {
      Self.log("não deu para carregar o plano", error)
      await load()
      return false
    }
  }

  private func set(_ day: Int, to ids: [String]) -> Task<Void, Never> {
    model = model?.setting(day, to: ids)
    let previous = last
    pending += 1
    let task = Task {
      await previous?.value
      do {
        _ = try await perform(.setWeekDay(day: day, routineIDs: ids))
      } catch {
        Self.log("não deu para mudar o dia", error)
      }
      pending -= 1
      await load()
    }
    last = task
    return task
  }

  static func log(_ what: String, _ error: any Error) {
    logger.error("\(what, privacy: .public) (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
  }
}
