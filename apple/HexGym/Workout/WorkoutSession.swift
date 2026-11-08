// O treino em andamento no app (Task 6 do plano da fase 3). Toda a regra do treino mora no motor
// (Session.swift do HexEngine e o controlador do openGym): o WorkoutSession passa a ação pelo
// AppModel, que aplica no motor e grava com a gravação de 0,5 s, lê de novo o treino e executa os
// efeitos da ação pelo SessionEffects, na ordem em que vieram. As telas leem o workout, o lastFinish
// e o háptico daqui, e tocam o háptico com .sensoryFeedback(trigger: hapticTick).
//
// O workout é lido de novo depois de cada ação e de cada revision do AppModel (uma ação de fora do
// treino, como trocar o nome de um exercício próprio, muda o que a tela mostra). Uma leitura que
// terminou depois de outra ação já ter mudado o documento não fica: quem mudou lê de novo.
//
// O refresh é o que o app chama ao abrir e ao voltar para a frente: lê o treino e acerta o aviso do
// descanso pelo endsAt gravado (Foco da revisão 1), sem repetir um aviso que já tocou.

import Foundation
import HexDesign
import HexEngine
import Observation
import os

@Observable @MainActor final class WorkoutSession {
  private(set) var workout: ActiveWorkout?
  private(set) var lastFinish: FinishSummary?
  // O último háptico que um efeito pediu, e o número que sobe a cada um, para o trigger mudar mesmo
  // quando o háptico é o mesmo de antes.
  private(set) var haptic: HexHaptic?
  private(set) var hapticTick = 0

  // O AppModel guarda o WorkoutSession dele; o contrário não guarda, para não prender os dois. Sem o
  // AppModel, nada mais roda.
  @ObservationIgnored private weak var model: AppModel?
  private let effects: SessionEffects
  // A revision em que o workout foi lido pela última vez.
  @ObservationIgnored private var readRevision: Int?
  // Os perform em andamento: enquanto há um, quem lê de novo depois da revision é ele.
  @ObservationIgnored private var performing = 0

  private static let logger = Logger(subsystem: "app.hexgym", category: "treino")

  init(model: AppModel, alerts: any RestAlerts, activity: any WorkoutActivityControlling) {
    self.model = model
    self.effects = SessionEffects(alerts: alerts, activity: activity)
    watchRevision()
  }

  // Lê o treino e acerta o aviso do descanso: agenda o resto do descanso que ainda conta e, se ele
  // já acabou ou não há descanso, cancela o aviso que tenha ficado agendado. Antes de o documento
  // abrir, não faz nada.
  func refresh() async {
    guard let model, case .ready = model.state else { return }
    await reload()
    await effects.resume(workout, now: .now)
  }

  // Aplica a ação no motor (pelo AppModel, que grava), lê o treino de novo, guarda o resumo do
  // finish e executa os efeitos. Uma ação inválida lança o erro do motor, e nada muda.
  func perform(_ action: SessionAction) async throws -> SessionOutcome {
    guard let model else { throw EngineError.notLoaded }
    performing += 1
    defer { performing -= 1 }
    let now = Date.now
    let outcome = try await model.perform(action, now: now)
    if let summary = try model.engine.finishSummary(from: outcome) { lastFinish = summary }
    if outcome.changed { await reload() }
    await effects.run(outcome.effects, workout: workout, now: now, live: liveModel) { [weak self] haptic in
      guard let self else { return }
      self.haptic = haptic
      self.hapticTick += 1
    }
    return outcome
  }

  private func liveModel() async -> LiveActivityModel? {
    guard let model else { return nil }
    do { return try await model.engine.liveActivity() } catch {
      Self.logger.error("não deu para ler a Live Activity: \(String(describing: error), privacy: .private)")
      return nil
    }
  }

  // Lê o treino. Se o documento mudou enquanto a leitura esperava o motor, ela não fica: quem mudou
  // lê de novo, e a leitura dele é a mais nova.
  private func reload() async {
    guard let model else { return }
    let revision = model.revision
    do {
      let read = try await model.engine.activeWorkout()
      guard model.revision == revision else { return }
      workout = read
      readRevision = revision
    } catch {
      Self.logger.error("não deu para ler o treino: \(String(describing: error), privacy: .private)")
    }
  }

  // Uma revision nova, de uma ação de fora do treino, lê o treino de novo. O withObservationTracking
  // avisa uma vez só, e por isso a observação recomeça a cada aviso.
  private func watchRevision() {
    guard let model else { return }
    withObservationTracking { _ = model.revision } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.revisionChanged() }
    }
  }

  private func revisionChanged() {
    watchRevision()
    guard let model, performing == 0, readRevision != model.revision else { return }
    Task { await reload() }
  }
}

// O argumento de início da tela do treino, para os prints e os testes: com -HexGymWorkout YES, o app
// abre na tela do treino quando há um em andamento. Vem do domínio dos argumentos dos UserDefaults
// padrão, que não fica gravado. Quem abre a tela é o WorkoutLauncher (Task 8), uma vez, sem animação.
enum WorkoutLaunch {
  static func opensWorkout(_ defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: "HexGymWorkout")
  }

  // Com -HexGymWorkoutTop YES junto (Task 8), a tela abre no topo, com o cabeçalho, sem rolar até a série
  // do painel: só para os prints.
  static func opensAtTop(_ defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: "HexGymWorkoutTop")
  }

  // Com -HexGymWorkoutEntry <n> junto (Task 8), a tela abre com a última série do exercício n (contando
  // do 0) logo acima do painel, para o print do superset mostrar os dois cartões do grupo.
  static func entry(_ defaults: UserDefaults = .standard) -> Int? {
    defaults.object(forKey: "HexGymWorkoutEntry") == nil ? nil : defaults.integer(forKey: "HexGymWorkoutEntry")
  }

  // Com -HexGymWorkoutPanel YES junto (Task 8), nos tamanhos de acessibilidade, a tela abre no fim do
  // painel, que fica na lista, para o print das entradas empilhadas e do botão.
  static func opensAtPanelEnd(_ defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: "HexGymWorkoutPanel")
  }

  // Com -HexGymWorkoutDemo inicio ou rotina (Task 8), o roteiro de um vídeo do PR: do Início
  // (WorkoutLauncher.runDemo) ou do editor de rotina (RoutineEditorView), aberto com -HexGymTab rotinas
  // -HexGymRoutine <id>.
  static func demo(_ defaults: UserDefaults = .standard) -> String? {
    defaults.string(forKey: "HexGymWorkoutDemo")
  }
}
