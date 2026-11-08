// O aviso do fim do descanso (Task 6 do plano da fase 3): um aviso local só, com o id hexgym.rest,
// que toca no endsAt do descanso quando o app não está na frente. O WorkoutSession agenda e cancela
// pelo SessionEffects; o aviso de verdade, sobre o UNUserNotificationCenter, é da Task 9
// (SystemRestAlerts), e até lá o app usa o SilentRestAlerts, que não faz nada.
//
// Agendar de novo troca o aviso de antes, porque o id é o mesmo: um descanso que muda (+15 s, por
// exemplo) nunca deixa dois avisos. O mesmo id é o que os botões da Live Activity reagendam com o app
// fechado (Task 14), e por isso o refresh do WorkoutSession cancela por ele.

import Foundation

nonisolated protocol RestAlerts: Sendable {
  func schedule(at: Date, title: String, body: String) async
  func cancel() async
}

nonisolated enum RestAlert {
  // O id do único aviso do descanso, o mesmo no app e nos botões da Live Activity.
  static let id = "hexgym.rest"
}

// O aviso que não faz nada, até a Task 9.
nonisolated struct SilentRestAlerts: RestAlerts {
  func schedule(at: Date, title: String, body: String) async {}
  func cancel() async {}
}
