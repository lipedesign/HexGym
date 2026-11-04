// O botão principal do HexGym (seção 6 do design doc, um componente nosso): largura toda, no fill do
// tema com o rótulo no onFill, que encolhe um pouco ao ser apertado, ou só esmaece com Reduzir
// Movimento (Foco da revisão, item 4). O alto contraste vem pela paleta do ambiente: no Ultravioleta,
// #8A88FF com rótulo preto.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: as alturas, o raio, o aperto e o
// desligado.

import SwiftUI

public struct HexPrimaryButtonStyle: ButtonStyle {
  public enum Size: Sendable {
    case regular, large

    // As duas passam do HexTarget.minimum.
    public var minHeight: CGFloat {
      switch self {
      case .regular: 56
      case .large: 72
      }
    }

    // O estilo do rótulo.
    var textStyle: HexTextStyle {
      switch self {
      case .regular: .headline
      case .large: .title
      }
    }
  }

  private let size: Size

  public init(size: Size = .regular) {
    self.size = size
  }

  // O aperto: encolhe para 0,97 com o movimento tap, ou, quando o tap não pode mover nada (Reduzir
  // Movimento), só esmaece para 0,8. A regra do Reduzir Movimento fica no HexMotion.
  nonisolated public static func pressedEffect(reduceMotion: Bool) -> PressedEffect {
    HexMotion.tap.spec(reduceMotion: reduceMotion).allowsMovement
      ? PressedEffect(scale: 0.97, opacity: 1)
      : PressedEffect(scale: 1, opacity: 0.8)
  }

  public func makeBody(configuration: Configuration) -> some View {
    PrimaryButtonBody(configuration: configuration, size: size)
  }
}

// O que o botão faz quando apertado.
public struct PressedEffect: Equatable, Sendable {
  public let scale: CGFloat
  public let opacity: Double

  // Solto: nada muda.
  static let none = PressedEffect(scale: 1, opacity: 1)
}

extension ButtonStyle where Self == HexPrimaryButtonStyle {
  public static var hexPrimary: HexPrimaryButtonStyle { HexPrimaryButtonStyle() }

  public static func hexPrimary(size: HexPrimaryButtonStyle.Size) -> HexPrimaryButtonStyle {
    HexPrimaryButtonStyle(size: size)
  }
}

// O corpo do botão, que lê a paleta, o desligado e o Reduzir Movimento do ambiente.
private struct PrimaryButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let size: HexPrimaryButtonStyle.Size

  @Environment(\.hexPalette) private var palette
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let effect = configuration.isPressed ? HexPrimaryButtonStyle.pressedEffect(reduceMotion: reduceMotion) : .none
    let shape = RoundedRectangle(cornerRadius: HexRadius.button, style: .continuous)
    configuration.label
      .hexFont(size.textStyle)
      .multilineTextAlignment(.center)
      .foregroundStyle(Color(palette.onFill))
      .padding(.horizontal, HexSpacing.l)
      .padding(.vertical, HexSpacing.s)
      .frame(maxWidth: .infinity, minHeight: size.minHeight)
      .background(Color(palette.fill), in: shape)
      .contentShape(shape)
      .scaleEffect(effect.scale)
      .opacity(effect.opacity * (isEnabled ? 1 : 0.4))
      .animation(HexMotion.tap.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
  }
}
