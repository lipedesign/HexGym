// Uma cor aprovada do HexGym, em sRGB (0xRRGGBB), com o mesmo ponto no Display P3 e o contraste da
// WCAG 2.2 (seção 6 do design doc). O sRGB é o valor aprovado e a base das contas; na tela, a cor
// sempre vai em Display P3, pelo Color(_:) do fim deste arquivo. Assim ela aparece igual à aprovada,
// e o P3 vivo fica só onde foi escolhido: o brilho (HexP3), que já vem em Display P3.

import SwiftUI

public struct HexRGB: Hashable, Sendable {
  public let hex: UInt32

  // Só os 24 bits de baixo contam: 0xRRGGBB.
  public init(_ hex: UInt32) {
    self.hex = hex & 0xFF_FFFF
  }

  // Os componentes de 0 a 1.
  public struct Components: Equatable, Sendable {
    public let red, green, blue: Double
  }

  public var srgb: Components {
    Components(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }

  // O mesmo ponto, no espaço Display P3: tira a curva do sRGB, passa do sRGB linear para o Display
  // P3 linear e põe de volta a mesma curva, que o Display P3 também usa.
  public var displayP3: Components {
    let c = srgb, rgb = [Self.linear(c.red), Self.linear(c.green), Self.linear(c.blue)]
    let p3 = Self.toDisplayP3.map { row in Self.encoded(row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]) }
    return Components(red: p3[0], green: p3[1], blue: p3[2])
  }

  // A luminância relativa da WCAG 2.2, nos componentes lineares.
  public var luminance: Double {
    let c = srgb
    return 0.2126 * Self.linear(c.red) + 0.7152 * Self.linear(c.green) + 0.0722 * Self.linear(c.blue)
  }

  // A razão de contraste da WCAG 2.2, de 1 a 21, a mesma nos dois sentidos.
  public func contrast(with other: HexRGB) -> Double {
    let (a, b) = (luminance, other.luminance)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
  }

  // O preto e o branco, e o cartão do sistema no escuro (o secondarySystemBackground).
  public static let black = HexRGB(0x000000), white = HexRGB(0xFFFFFF), card = HexRGB(0x1C1C1E)

  // A curva do sRGB, de um componente para a luz linear, com o limiar 0,04045 da WCAG 2.2.
  static func linear(_ component: Double) -> Double {
    component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
  }

  // A volta da curva, com o limiar correspondente (0,04045 / 12,92). Um sRGB sempre cabe no Display
  // P3, mas a linha do vermelho da matriz soma 1,0000001, e o branco passaria de 1 por pouco: o
  // resultado fica entre 0 e 1.
  static func encoded(_ light: Double) -> Double {
    let component = light <= 0.0031308 ? light * 12.92 : 1.055 * pow(light, 1 / 2.4) - 0.055
    return min(max(component, 0), 1)
  }

  // Do sRGB linear para o Display P3 linear, os dois com o branco D65.
  static let toDisplayP3: [[Double]] = [
    [0.8224621, 0.1775380, 0],
    [0.0331941, 0.9668058, 0],
    [0.0170827, 0.0723974, 0.9105199],
  ]
}

// Uma cor já em Display P3, com a opacidade: o brilho que respira.
public struct HexP3: Equatable, Sendable {
  public let red, green, blue, opacity: Double
}

extension HexP3 {
  // O mesmo ponto de uma cor aprovada, sem P3 vivo (o brilho do Giz).
  init(_ rgb: HexRGB, opacity: Double) {
    let c = rgb.displayP3
    self.init(red: c.red, green: c.green, blue: c.blue, opacity: opacity)
  }
}

extension Color {
  // A cor aprovada na tela, no Display P3.
  public init(_ rgb: HexRGB) {
    let c = rgb.displayP3
    self.init(.displayP3, red: c.red, green: c.green, blue: c.blue)
  }

  public init(_ p3: HexP3) {
    self.init(.displayP3, red: p3.red, green: p3.green, blue: p3.blue, opacity: p3.opacity)
  }
}
