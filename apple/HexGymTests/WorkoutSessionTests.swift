// Os testes do WorkoutSession, o treino em andamento no app (Task 6 do plano da fase 3), um por item
// do passo 1 de lá: com o motor de verdade, o documento preparado (FixtureLoader) num DocumentStore
// numa pasta temporária, e um aviso do descanso e uma Live Activity falsos, que guardam as chamadas.
// Os marcados com o Foco da revisão prendem o item 1 dele: o app morto no meio do descanso.

import Foundation
import HexDesign
import HexEngine
import HexStore
import Testing
@testable import HexGym

@Suite @MainActor struct WorkoutSessionTests {
  let folder: TemporaryFolder
  let alerts = RecordedAlerts()
  let activity = RecordedActivity()

  init() throws {
    folder = try TemporaryFolder()
  }

  // O AppModel aberto no documento preparado, levado para o now, gravado como o state.json da pasta.
  func opened(_ fixture: String, now: Date = .now, in folder: TemporaryFolder? = nil) async throws -> AppModel {
    let url = (folder ?? self.folder).url
    try FixtureLoader.document(named: fixture, now: now).write(to: url.appending(path: "state.json"))
    let model = AppModel(engine: HexEngine(language: "pt-BR"), store: DocumentStore(directory: url), alerts: alerts, activity: activity)
    await model.start()
    #expect(model.state.origin == .opened)
    return model
  }

  func read(_ name: String) -> Data {
    do { return try Data(contentsOf: folder.url.appending(path: name)) } catch {
      Issue.record(error, "não deu para ler \(name)")
      return Data()
    }
  }

  @Test func startPublishesTheWorkoutAndStartsTheLiveActivity() async throws {
    let model = try await opened("semana-ppl")
    let session = model.session
    #expect(session.workout == nil)
    let outcome = try await session.perform(.start(routineIDs: ["r-push"], id: "w-hoje"))
    #expect(outcome.effects == [.activityStart])
    let workout = try #require(session.workout)
    #expect(workout.id == "w-hoje"); #expect(workout.name == "Push"); #expect(workout.done == 0); #expect(workout.total == 13)
    let live = try #require(try await model.engine.liveActivity())
    #expect(activity.calls == [.start(live, workoutID: "w-hoje", start: try #require(workout.start))])
    #expect(alerts.calls.isEmpty)
  }

  @Test func markSetPlaysSetLoggedAndSchedulesTheAlertAtEndsAt() async throws {
    let model = try await opened("semana-ppl")
    let session = model.session
    _ = try await session.perform(.start(routineIDs: ["r-push"], id: "w-hoje"))
    #expect(session.haptic == nil); #expect(session.hapticTick == 0)
    let next = try #require(session.workout?.next)
    let outcome = try await session.perform(.markSet(entry: next.entry, set: next.set, done: true))
    #expect(session.haptic == .setLogged); #expect(session.hapticTick == 1)
    let rest = try #require(session.workout?.rest)
    #expect(rest.total == 90); #expect(session.workout?.done == 1)
    #expect(outcome.effects == [.haptic("setLogged"), .restStarted(endsAt: rest.endsAt, total: 90, kind: "rest"), .activityUpdate])
    #expect(alerts.calls == [.schedule(at: rest.endsAt, title: SessionEffects.alertTitle(kind: "rest"), body: "")])
    // A Live Activity recebe o modelo lido depois da ação: a série seguinte e o descanso que começou. O
    // restAfter dele fica de fora: o motor simula a marcação no now da leitura, e numa leitura no mesmo
    // milissegundo em que o descanso começou ele sai 0 (achado para a Task 13, no PR).
    let live = try #require(try await model.engine.liveActivity())
    #expect(activity.calls.count == 2)
    guard case .update(let sent) = activity.calls.last else { Issue.record("sem update: \(activity.calls)"); return }
    #expect(sent.done == 1); #expect(sent.done == live.done); #expect(sent.restEndsAt == rest.endsAt)
    #expect(sent.cur?.entry == live.cur?.entry); #expect(sent.cur?.set == live.cur?.set)
    #expect(sent.ahead.map(\.set) == live.ahead.map(\.set))
  }

  @Test func skipRestCancelsTheAlert() async throws {
    let model = try await opened("descanso")
    let session = model.session
    await session.refresh()
    #expect(session.workout?.rest != nil)
    let outcome = try await session.perform(.skipRest)
    #expect(outcome.effects == [.restCleared, .activityUpdate])
    #expect(session.workout?.rest == nil as ActiveWorkout.Rest?)
    #expect(alerts.calls.last == .cancel)
  }

  @Test func finishClearsTheWorkoutKeepsTheSummaryAndEndsTheActivity() async throws {
    let model = try await opened("treino-em-andamento")
    let session = model.session
    await session.refresh()
    #expect(session.workout?.done == 5); #expect(session.lastFinish == nil)
    let outcome = try await session.perform(.finish)
    #expect(session.workout == nil)
    let summary = try #require(session.lastFinish)
    #expect(summary.id == "w-2026-11-09-push"); #expect(summary.sets.done == 5)
    #expect(summary.prs.map(\.id).contains("0025"))           // o supino de 70 kg passa dos 67,5 kg
    #expect(outcome.effects.last == .activityEnd); #expect(activity.calls == [.end])
    #expect(try await model.engine.home().last?.id == "w-2026-11-09-push")
  }

  // O app abre com o descanso que ficou gravado: ainda contando, o aviso é agendado para o endsAt; já
  // acabado (o app ficou morto mais que o descanso), nenhum aviso é agendado, e o que a Live Activity
  // tenha deixado é cancelado.
  @Test func refreshSchedulesARunningRestAndCancelsOneThatEnded() async throws {      // Foco da revisão 1
    let now = Date.now
    let first = try await opened("descanso", now: now)
    let running = first.session
    await running.refresh()
    let rest = try #require(running.workout?.rest)
    #expect(rest.endsAt > now); #expect(rest.remaining > 60)
    #expect(alerts.calls == [.schedule(at: rest.endsAt, title: SessionEffects.alertTitle(kind: "rest"), body: "")])

    // O mesmo documento, gravado 100 s antes: o descanso acabou há 25 s.
    let late = RecordedAlerts()
    let other = try TemporaryFolder()
    try FixtureLoader.document(named: "descanso", now: now.addingTimeInterval(-100)).write(to: other.url.appending(path: "state.json"))
    let model = AppModel(engine: HexEngine(language: "pt-BR"), store: DocumentStore(directory: other.url), alerts: late, activity: activity)
    await model.start()
    await model.session.refresh()
    let ended = try #require(model.session.workout?.rest)
    #expect(ended.endsAt < now); #expect(ended.remaining == 0)
    #expect(late.calls == [.cancel])
  }

  // Duas séries marcadas bem antes de 0,5 s saem numa gravação só, a mesma das outras ações: o save
  // guarda o state.json de antes como cópia anterior, e ela é o documento aberto, e não o de depois
  // da primeira série.
  @Test func twoMarksWithinHalfASecondSaveOnce() async throws {
    let model = try await opened("treino-em-andamento")
    let session = model.session
    await session.refresh()
    let before = read("state.json")
    let first = try #require(session.workout?.next)
    _ = try await session.perform(.markSet(entry: first.entry, set: first.set, done: true))
    let second = try #require(session.workout?.next)
    #expect(second != first)
    _ = try await session.perform(.markSet(entry: second.entry, set: second.set, done: true))
    #expect(model.revision == 2); #expect(session.workout?.done == 7)
    #expect(read("state.json") == before)
    let previous = folder.url.appending(path: "state.previous.json").path(percentEncoded: false)
    for _ in 0..<40 where !FileManager.default.fileExists(atPath: previous) { try await Task.sleep(for: .milliseconds(50)) }
    try await Task.sleep(for: AppModel.saveDelay)                 // uma segunda gravação teria tempo de sair
    #expect(read("state.previous.json") == before)
    #expect(read("state.json") == (try await model.engine.document()))
  }
}

// O aviso do descanso falso: guarda as chamadas, na ordem, no ator principal dos testes.
@MainActor final class RecordedAlerts: RestAlerts {
  enum Call: Equatable { case schedule(at: Date, title: String, body: String), cancel }
  private(set) var calls: [Call] = []

  @MainActor func schedule(at: Date, title: String, body: String) async { calls.append(.schedule(at: at, title: title, body: body)) }
  @MainActor func cancel() async { calls.append(.cancel) }
}

// A Live Activity falsa: guarda as chamadas, na ordem, no ator principal dos testes.
@MainActor final class RecordedActivity: WorkoutActivityControlling {
  enum Call: Equatable { case start(LiveActivityModel, workoutID: String, start: Date), update(LiveActivityModel), end }
  private(set) var calls: [Call] = []

  @MainActor func start(_ model: LiveActivityModel, workoutID: String, start: Date) async { calls.append(.start(model, workoutID: workoutID, start: start)) }
  @MainActor func update(_ model: LiveActivityModel) async { calls.append(.update(model)) }
  @MainActor func end() async { calls.append(.end) }
}
