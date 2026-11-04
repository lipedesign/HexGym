// Os quatro temas do HexGym (seção 6 do design doc, com a decisão 3 de 03/11/2026): as cores de cada
// um no escuro, no escuro com alto contraste e no claro, e o accent próprio do Watch e da ilha. O
// teste de cada par contra a sua regra de contraste da WCAG 2.2 está em ColorTests.swift: quem mudar
// uma cor vê o teste cair.

import SwiftUI

// O rawValue é o que fica guardado no aparelho (Task 4).
public enum HexTheme: String, CaseIterable, Sendable {
  case ultraviolet, chalk, cyan, copper
  public static let standard: HexTheme = .ultraviolet
}

// Onde a cor aparece. A ilha é a Dynamic Island e a Live Activity.
public enum HexSurface: Sendable { case app, watch, island }

public struct HexPalette: Equatable, Sendable {
  // O destaque (texto, ícones e traços), o botão principal com o rótulo e o ouro do recorde com o
  // texto dele.
  public let accent, fill, onFill, record, onRecord: HexRGB
  // A cor de apoio do brilho; nil no alto contraste.
  public let support: HexRGB?
  // O brilho que respira, já em Display P3; nil no claro.
  public let glow: HexP3?

  // As cores de um tema no esquema, no contraste e na superfície do aparelho. No claro, o accent e o
  // botão são a coluna clara, com rótulo branco. A superfície só muda o accent do Ultravioleta no
  // escuro sem alto contraste; nos outros casos, vale o do app.
  public static func resolve(_ theme: HexTheme, scheme: ColorScheme, contrast: ColorSchemeContrast, surface: HexSurface = .app) -> HexPalette {
    let row = ThemeColors.of(theme), increased = contrast == .increased
    let support = increased ? nil : row.support
    if scheme == .light {
      let light = increased ? row.lightIncreased : row.light
      return HexPalette(
        accent: light, fill: light, onFill: .white, record: increased ? HexRGB(0x765200) : HexRGB(0x8A6100), onRecord: .white,
        support: support, glow: nil)
    }
    var accent = increased ? row.accentIncreased : row.accent
    if !increased, surface != .app, let watchAccent = row.watchAccent { accent = watchAccent }
    return HexPalette(
      accent: accent, fill: increased ? row.fillIncreased : row.fill, onFill: increased ? row.onFillIncreased : row.onFill,
      record: HexRGB(0xFFC94D), onRecord: .black, support: support, glow: row.glow)
  }

  // O erro é sempre o vermelho do sistema (Color.red, o systemRed), em todo tema.
  public static let error: Color = .red
}

// Uma linha da tabela da seção 6: o escuro, o escuro com alto contraste, o claro (o mesmo valor no
// accent e no botão), a cor de apoio, o brilho e o accent do Watch e da ilha, quando é outro.
struct ThemeColors {
  let accent, accentIncreased: HexRGB
  let fill, onFill, fillIncreased, onFillIncreased: HexRGB
  let light, lightIncreased: HexRGB
  let support: HexRGB?
  let glow: HexP3
  let watchAccent: HexRGB?

  static func of(_ theme: HexTheme) -> ThemeColors {
    switch theme {
    case .ultraviolet:
      // #71: com alto contraste, o accent sobe para #ABA5FF, que chega a 7 também no cardIncreased.
      ThemeColors(
        accent: HexRGB(0x8B7BFF), accentIncreased: HexRGB(0xABA5FF),
        fill: HexRGB(0x6F5CFF), onFill: .white, fillIncreased: HexRGB(0x8A88FF), onFillIncreased: .black,
        light: HexRGB(0x5B45E6), lightIncreased: HexRGB(0x5339DB), support: nil,
        glow: HexP3(red: 0.4221, green: 0.3535, blue: 0.9822, opacity: 0.85), watchAccent: HexRGB(0x9D8CFF))
    case .chalk:
      // Decisão 3: o Giz fica sem P3 vivo, e o brilho é o cinza #8D8A84 no mesmo ponto.
      ThemeColors(
        accent: HexRGB(0xF2EFE9), accentIncreased: HexRGB(0xF2EFE9),
        fill: HexRGB(0xF2EFE9), onFill: .black, fillIncreased: HexRGB(0xF2EFE9), onFillIncreased: .black,
        light: HexRGB(0x1D1D1F), lightIncreased: HexRGB(0x1D1D1F), support: nil,
        glow: HexP3(HexRGB(0x8D8A84), opacity: 0.55), watchAccent: nil)
    case .cyan:
      ThemeColors(
        accent: HexRGB(0x4FD8FF), accentIncreased: HexRGB(0x4FD8FF),
        fill: HexRGB(0x4FD8FF), onFill: .black, fillIncreased: HexRGB(0x4FD8FF), onFillIncreased: .black,
        light: HexRGB(0x00739E), lightIncreased: HexRGB(0x005F84), support: HexRGB(0x5E6BFF),
        glow: HexP3(red: 0.2302, green: 0.6551, blue: 0.8761, opacity: 0.8), watchAccent: nil)
    case .copper:
      // #71: com alto contraste, o accent sobe para #F5976C, que chega a 7 também no cardIncreased.
      ThemeColors(
        accent: HexRGB(0xF2895A), accentIncreased: HexRGB(0xF5976C),
        fill: HexRGB(0xF2895A), onFill: .black, fillIncreased: HexRGB(0xF2895A), onFillIncreased: .black,
        light: HexRGB(0xB0521F), lightIncreased: HexRGB(0x973D00), support: HexRGB(0x8EA4BF),
        glow: HexP3(red: 0.8374, green: 0.3918, blue: 0.1830, opacity: 0.8), watchAccent: nil)
    }
  }
}
