// O botão principal do HexGym (seção 6 do design doc, um componente nosso): largura toda, no fill do
// tema com o rótulo no onFill, que encolhe um pouco ao ser apertado, ou só esmaece com Reduzir
// Movimento (Foco da revisão, item 4). O alto contraste vem pela paleta do ambiente: no Ultravioleta,
// #8A88FF com rótulo preto.
//
// No Watch, o tamanho padrão é o compacto, de 44 pt, com o rótulo no headline e margens menores dos
// lados, para caber na tela pequena sem cair abaixo do alvo mínimo de toque.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: as alturas, o raio, o aperto e o
// desligado, e o botão compacto de 44 pt no Watch.

import SwiftUI

public struct HexPrimaryButtonStyle: ButtonStyle {
  public enum Size: Sendable {
    case regular, large, compact

    // O tamanho do init() sem argumento: o compacto no watchOS e o regular no resto.
    public static var platformDefault: Size {
      #if os(watchOS)
      .compact
      #else
      .regular
      #endif
    }

    // Nenhuma fica abaixo do HexTarget.minimum: o compacto é o próprio mínimo.
    public var minHeight: CGFloat {
      switch self {
      case .regular: 56
      case .large: 72
      case .compact: HexTarget.minimum
      }
    }

    // O estilo do rótulo.
    var textStyle: HexTextStyle {
      switch self {
      case .regular, .compact: .headline
      case .large: .title
      }
    }

    // A margem dos lados: no compacto, a menor, porque a tela do Watch é estreita.
    var horizontalPadding: CGFloat {
      switch self {
      case .regular, .large: HexSpacing.l
      case .compact: HexSpacing.s
      }
    }

    // A margem de cima e de baixo.
    var verticalPadding: CGFloat {
      switch self {
      case .regular, .large: HexSpacing.s
      case .compact: HexSpacing.xs
      }
    }
  }

  private let size: Size

  public init(size: Size = .platformDefault) {
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
      .padding(.horizontal, size.horizontalPadding)
      .padding(.vertical, size.verticalPadding)
      .frame(maxWidth: .infinity, minHeight: size.minHeight)
      .background(Color(palette.fill), in: shape)
      .contentShape(shape)
      .scaleEffect(effect.scale)
      .opacity(effect.opacity * (isEnabled ? 1 : 0.4))
      .animation(HexMotion.tap.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
  }
}
