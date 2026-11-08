// Os efeitos de uma ação do treino (Task 6 do plano da fase 3), executados na ordem em que o
// controlador do treino os deu (frontend/src/lib/session-controller.js, o step):
//   - haptic: o háptico da tabela do HexDesign (o setLogged, ao marcar a série), que o WorkoutSession
//     publica para as telas tocarem;
//   - rest.started: o aviso do descanso, agendado no endsAt, com o título pelo kind (Descanso acabou,
//     ou Trocar de lado na pausa de trocar de lado). O corpo fica vazio até a Task 9, que escreve o
//     texto do aviso;
//   - rest.cleared: o aviso cancelado;
//   - activity.start, activity.update e activity.end: a Live Activity, com o liveActivity() lido
//     depois da ação (o de verdade é da Task 13; até lá, o SilentWorkoutActivity);
//   - workout.complete e workout.finished não pedem nada do app nesta Task.
//
// O resume é a regra de quando o app abre com um treino em andamento (Foco da revisão 1): um descanso
// que ainda conta agenda o aviso para o resto dele, e um que já acabou, ou nenhum, cancela o aviso
// que a Live Activity possa ter deixado agendado com o app fechado (Task 14).

import Foundation
import HexDesign
import HexEngine

nonisolated protocol WorkoutActivityControlling: Sendable {
  func start(_ model: LiveActivityModel, workoutID: String, start: Date) async
  func update(_ model: LiveActivityModel) async
  func end() async
}

// A Live Activity que não faz nada, até a Task 13.
nonisolated struct SilentWorkoutActivity: WorkoutActivityControlling {
  func start(_ model: LiveActivityModel, workoutID: String, start: Date) async {}
  func update(_ model: LiveActivityModel) async {}
  func end() async {}
}

@MainActor struct SessionEffects {
  let alerts: any RestAlerts
  let activity: any WorkoutActivityControlling

  // Os efeitos, um por um. O workout é o treino lido depois da ação (o id e o começo da Live
  // Activity), o live lê o modelo da Live Activity, uma vez só e só quando um efeito pede, e o play
  // publica o háptico.
  func run(_ effects: [SessionEffect], workout: ActiveWorkout?, now: Date,
           live: () async -> LiveActivityModel?, play: (HexHaptic) -> Void) async {
    var read: LiveActivityModel??
    func liveModel() async -> LiveActivityModel? {
      if let read { return read }
      let model = await live()
      read = .some(model)
      return model
    }
    for effect in effects {
      switch effect {
      case .haptic(let kind):
        if let haptic = Self.haptic(kind) { play(haptic) }
      case .restStarted(let endsAt, _, let kind):
        await alerts.schedule(at: endsAt, title: Self.alertTitle(kind: kind), body: "")
      case .restCleared:
        await alerts.cancel()
      case .activityStart:
        guard let workout, let model = await liveModel() else { continue }
        await activity.start(model, workoutID: workout.id, start: workout.start ?? now)
      case .activityUpdate:
        guard let model = await liveModel() else { continue }
        await activity.update(model)
      case .activityEnd:
        await activity.end()
      case .workoutComplete, .workoutFinished:
        continue
      }
    }
  }

  // O aviso ao abrir o app: agenda o resto do descanso que ainda conta; sem ele, cancela.
  func resume(_ workout: ActiveWorkout?, now: Date) async {
    if let rest = workout?.rest, rest.endsAt > now {
      await alerts.schedule(at: rest.endsAt, title: Self.alertTitle(kind: rest.kind), body: "")
    } else {
      await alerts.cancel()
    }
  }

  // O háptico do efeito, pelo nome do controlador; um nome que esta versão não conhece não toca nada.
  static func haptic(_ kind: String) -> HexHaptic? {
    switch kind {
    case "setLogged": .setLogged
    case "record": .record
    case "restDone": .restDone
    case "increase": .increase
    case "decrease": .decrease
    case "error": .error
    default: nil
    }
  }

  // O título do aviso pelo kind do descanso, como o store/useUI.js:30 do openGym. A Task 9 põe as duas
  // frases no catálogo do app, com o corpo.
  static func alertTitle(kind: String) -> String {
    kind == "switch" ? String(localized: "Switch sides") : String(localized: "Rest's over")
  }
}
