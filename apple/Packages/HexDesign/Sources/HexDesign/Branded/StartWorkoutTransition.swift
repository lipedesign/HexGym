// A transição de "Começar treino" (seção 6 do design doc e a decisão 2 de 03/11/2026): o zoom da Apple,
// que sai do botão e vira a tela do treino. Com Reduzir Movimento não há zoom, e quem abre a tela o faz
// dentro de withTransaction(StartWorkoutTransition.transaction(reduceMotion:)): a transação desliga as
// animações, e a tela aparece sem se mover (Foco da revisão, item 4). O zoom não existe no macOS, que
// está no pacote só para os testes. A tela do treino de verdade é da fase 3; aqui a transição aparece
// na galeria (Task 10).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: com Reduzir Movimento, a tela do treino
// entrando sem animação, no lugar do zoom.

import SwiftUI

public enum StartWorkoutTransition {
  // O zoom só sem Reduzir Movimento.
  public static func usesZoom(reduceMotion: Bool) -> Bool {
    !reduceMotion
  }

  // A transação para abrir a tela do treino: com Reduzir Movimento, sem animação nenhuma.
  public static func transaction(reduceMotion: Bool) -> Transaction {
    var transaction = Transaction()
    transaction.disablesAnimations = reduceMotion
    return transaction
  }
}

extension View {
  // O botão de onde o zoom sai.
  public func hexStartWorkoutSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
    matchedTransitionSource(id: id, in: namespace)
  }

  // A tela do treino, que entra com o zoom quando o Reduzir Movimento deixa.
  public func hexStartWorkoutDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
    modifier(StartWorkoutDestination(id: id, namespace: namespace))
  }
}

// Lê o Reduzir Movimento do ambiente e só põe o zoom fora do macOS.
private struct StartWorkoutDestination<ID: Hashable>: ViewModifier {
  let id: ID
  let namespace: Namespace.ID

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    #if os(macOS)
    content
    #else
    if StartWorkoutTransition.usesZoom(reduceMotion: reduceMotion) {
      content.navigationTransition(.zoom(sourceID: id, in: namespace))
    } else {
      content
    }
    #endif
  }
}
