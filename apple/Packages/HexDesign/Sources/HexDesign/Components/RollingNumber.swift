// O número que rola (seção 6 do design doc, com a decisão 2 de 03/11/2026: da Apple, com a marca): a
// transição numericText da Apple, com a nossa tipografia. Com Reduzir Movimento, o número só troca
// por opacidade (Foco da revisão, item 4).

import SwiftUI

public struct RollingNumber: View {
  private let value: Double
  private let text: String
  private let style: HexTextStyle

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // value dá o sentido da rolagem (para cima quando cresce); text é o que aparece, já formatado.
  public init(value: Double, text: String, style: HexTextStyle = .number) {
    self.value = value
    self.text = text
    self.style = style
  }

  // A transição: o numericText, ou só opacidade com Reduzir Movimento.
  nonisolated public static func transition(for value: Double, reduceMotion: Bool) -> ContentTransition {
    reduceMotion ? .opacity : .numericText(value: value)
  }

  public var body: some View {
    Text(verbatim: text)
      .hexFont(style)
      .contentTransition(Self.transition(for: value, reduceMotion: reduceMotion))
      .animation(HexMotion.change.animation(reduceMotion: reduceMotion), value: value)
  }
}
