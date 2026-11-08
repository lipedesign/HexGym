// O que o app faz ao abrir (seção 9 do design doc e Task 10 do plano da fase 0): carrega o motor e
// abre o documento de dados do App Group; a raiz (RootView) mostra as abas, ou o erro.
//
// O motor (HexEngine) e o armazenamento (DocumentStore) são atores: cada chamada a eles roda fora da
// thread principal, e só o state muda aqui, no ator principal.
//
// A ordem do start(), pelo que o store.load() achou:
//   - nada: o motor cria o documento, que é gravado como veio, origem .created. O documento novo não
//     leva horário: um carimbo de agora ganharia, numa sincronização futura, de um documento de
//     verdade do servidor;
//   - o state.json: o motor abre o documento, e nada é gravado, origem .opened;
//   - a cópia anterior: o motor abre e os mesmos bytes são gravados, para o próximo início abrir
//     normal, origem .recovered.
// Qualquer erro, inclusive um documento que o HexStore aceita e o JSON.parse do motor recusa, vira
// .failed, com o detalhe no log, e depois dele nada é gravado: o app nunca começa do zero em silêncio
// (Foco da revisão 1). Sem o App Group, o app mostra o erro e não grava nada, nunca numa pasta
// inventada.
//
// Depois de aberto, toda mudança do documento é uma ação do motor (perform, Task 5 do plano da fase
// 2): o motor muda e carimba o documento, e o app grava pelo DocumentStore. A gravação junta as ações
// de 0,5 s numa só, e o flush() grava na hora, quando o app vai para o fundo (HexGymApp). As telas
// leem pelo engine e leem de novo quando o revision sobe.
//
// O treino em andamento (Task 6 do plano da fase 3) é o session, o WorkoutSession deste AppModel: as
// ações do treino passam pelo perform(_: SessionAction), com a mesma gravação das outras ações, e o
// session executa os efeitos delas (o háptico, o aviso do descanso e a Live Activity).
//
// Com -HexGymFixture <nome>, só no build Debug, o live() abre um documento preparado numa pasta
// temporária nova, nunca no App Group (FixtureLoader).

import Foundation
import HexEngine
import HexStore
import Observation
import os

@Observable @MainActor final class AppModel {
  // Em failed, o detalhe do erro, para o log e os testes. A tela não mostra.
  enum State: Equatable { case starting, ready(Status), failed(String) }
  struct Status: Equatable { var exercises: Int; var origin: Origin }
  enum Origin: Equatable { case created, opened, recovered }

  private(set) var state: State = .starting
  // Sobe a cada ação que mudou o documento, para as telas lerem de novo.
  private(set) var revision = 0

  // O motor, para as leituras das telas (engine.routines(), engine.catalogue()). Toda mudança passa
  // pelo perform.
  let engine: HexEngine
  // nil: o App Group não abriu.
  private let store: DocumentStore?
  // O start() roda uma vez só, mesmo que a janela peça de novo.
  private var started = false

  // O aviso do descanso e a Live Activity do treino, que o session usa.
  private let alerts: any RestAlerts
  private let activity: any WorkoutActivityControlling
  // O treino em andamento, criado na primeira vez que alguém pede.
  @ObservationIgnored private(set) lazy var session = WorkoutSession(model: self, alerts: alerts, activity: activity)

  // As ações de 0,5 s viram uma gravação só.
  static let saveDelay = Duration.milliseconds(500)
  // Há mudança no motor que ainda não foi gravada.
  private var dirty = false
  // A gravação marcada para daqui a 0,5 s, enquanto não saiu.
  private var pendingSave: Task<Void, Never>?
  // A última gravação, para a seguinte esperar por ela e o flush() só voltar com tudo no disco.
  private var lastWrite: Task<Void, Never>?
  // Os perform que ainda esperam o engine.apply, e quem espera eles acabarem (o flush()).
  private var applying = 0
  private var applyWaiters: [CheckedContinuation<Void, Never>] = []

  private static let logger = Logger(subsystem: "app.hexgym", category: "app")

  // O aviso do descanso e a Live Activity que não fazem nada são os do app até as Tasks 9 e 13.
  init(engine: HexEngine, store: DocumentStore?,
       alerts: any RestAlerts = SilentRestAlerts(), activity: any WorkoutActivityControlling = SilentWorkoutActivity()) {
    self.engine = engine
    self.store = store
    self.alerts = alerts
    self.activity = activity
  }

  func start() async {
    guard !started else { return }
    started = true
    guard let store else {
      fail("o App Group não abriu, e nada foi gravado", kind: "appGroupUnavailable")
      return
    }
    do {
      let info = try await engine.load()
      let origin: Origin
      switch try await store.load() {
      case .empty:
        try await store.save(try await engine.freshDocument())
        origin = .created
      case .current(let document):
        try await engine.restore(document)
        origin = .opened
      case .recovered(let document):
        try await engine.restore(document)
        try await store.save(document)
        origin = .recovered
      }
      state = .ready(Status(exercises: info.exercises, origin: origin))
    } catch {
      fail(String(describing: error), kind: String(describing: type(of: error)))
    }
  }

  // Aplica a ação no motor e, se ela mudou o documento, sobe o revision e pede a gravação, que sai
  // 0,5 s depois da primeira ação ainda não gravada, com todas as que vieram até lá. Antes do
  // documento abrir, ou depois de uma falha ao abrir, nenhuma ação roda: o app nunca grava por cima de
  // um documento que não leu (Foco da revisão 1). Uma ação inválida lança o erro do motor, e nada
  // muda. Devolve o resultado da ação.
  func perform(_ action: EngineAction) async throws -> ActionOutcome {
    try await change(changed: \ActionOutcome.changed) { try await engine.apply(action) }
  }

  // Uma ação do treino, com a mesma gravação: o motor roda o controlador do treino e carimba o
  // documento com o now, que é também o instante da ação (a hora da série marcada, o começo do
  // descanso). Quem executa os efeitos é o session.
  func perform(_ action: SessionAction, now: Date = .now) async throws -> SessionOutcome {
    try await change(changed: \SessionOutcome.changed) { try await engine.session(action, now: now) }
  }

  // O caminho de toda ação: nada antes de o documento abrir, o revision e a gravação quando ela
  // mudou o documento, e o flush() esperando por ela enquanto roda no motor.
  private func change<Outcome>(changed: (Outcome) -> Bool, _ run: () async throws -> Outcome) async throws -> Outcome {
    guard case .ready = state else { throw EngineError.notLoaded }
    applying += 1
    defer { finishApply() }
    let outcome = try await run()
    if changed(outcome) {
      revision += 1
      dirty = true
      scheduleSave()
    }
    return outcome
  }

  // Grava na hora o que ainda não foi gravado e só volta com tudo no disco, inclusive uma gravação
  // que já estava saindo e uma ação que ainda rodava no motor: sem esperar por ela, o flush() acharia
  // o documento gravado, e a mudança dela ficaria para a gravação de 0,5 s, que pode não sair antes
  // de o sistema suspender o app. É o que o app chama ao ir para o fundo.
  func flush() async {
    if applying > 0 { await withCheckedContinuation { applyWaiters.append($0) } }
    pendingSave?.cancel()
    pendingSave = nil
    await write()
  }

  // Um perform acabou, com a mudança já marcada para gravar; o último solta quem esperava.
  private func finishApply() {
    applying -= 1
    guard applying == 0 else { return }
    let waiters = applyWaiters
    applyWaiters = []
    for waiter in waiters { waiter.resume() }
  }

  private func scheduleSave() {
    guard pendingSave == nil else { return }
    pendingSave = Task { [weak self] in
      // Cancelada pelo flush(), que grava ele mesmo.
      do { try await Task.sleep(for: Self.saveDelay) } catch { return }
      guard let self, !Task.isCancelled else { return }
      self.pendingSave = nil
      await self.write()
    }
  }

  // Uma gravação por vez, na ordem: cada uma espera a de antes e grava o documento de agora, se há o
  // que gravar. Um erro vai para o log e deixa o documento como não gravado, para a próxima ação ou
  // o próximo flush() tentar de novo.
  private func write() async {
    let previous = lastWrite
    let task = Task { [weak self] in
      await previous?.value
      await self?.writeIfDirty()
    }
    lastWrite = task
    await task.value
  }

  private func writeIfDirty() async {
    guard dirty, let store else { return }
    dirty = false
    do {
      try await store.save(try await engine.document())
      // Só a hora, para conferir no simulador quem gravou: a gravação de 0,5 s ou o flush() do fundo.
      Self.logger.info("documento gravado")
    } catch {
      dirty = true
      Self.logger.error("não deu para gravar o documento (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
    }
  }

  // O app de verdade: o documento na pasta do App Group. Quando ela não abre, o store é nil, e o
  // appGroupDirectory já disse no log por quê.
  static func live() -> AppModel {
    #if DEBUG
    if let fixture = FixtureLoader.requested() {
      return AppModel(engine: HexEngine(), store: FixtureLoader.store(named: fixture))
    }
    #endif
    let store = (try? DocumentStore.appGroupDirectory()).map { DocumentStore(directory: $0) }
    return AppModel(engine: HexEngine(), store: store)
  }

  // O erro vai para o log e para o state. O tipo do erro fica público no log; o detalhe, privado,
  // porque a mensagem do motor pode trazer um pedaço do documento.
  private func fail(_ detail: String, kind: String) {
    Self.logger.error("não deu para abrir os dados (\(kind, privacy: .public)): \(detail, privacy: .private)")
    state = .failed(detail)
  }
}
