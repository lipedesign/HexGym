// Os testes das cores do HexDesign (seção 6 do design doc, com a decisão 3 de 03/11/2026): o
// contraste da WCAG 2.2, a conversão do sRGB aprovado para o Display P3, as regras de contraste de
// cada tema, com e sem alto contraste, e o print das amostras.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign
//
// O print (cores.png) só roda com HEXDESIGN_PRINTS na frente do comando e --filter printTheSwatches.

import SwiftUI
import Testing
@testable import HexDesign

@Test func contrastFollowsWCAG() {
  #expect(HexRGB.white.contrast(with: .black) == 21)
  #expect(abs(HexRGB(0x8B7BFF).contrast(with: .black) - 6.37) < 0.01)
  #expect(abs(HexRGB(0x6F5CFF).contrast(with: .white) - 4.52) < 0.01)
  #expect(HexRGB(0x6F5CFF).contrast(with: .white) == HexRGB.white.contrast(with: HexRGB(0x6F5CFF)))
}
@Test func displayP3KeepsTheApprovedColor() {
  let cases: [(UInt32, [Double])] = [(0x8B7BFF, [0.5346, 0.4846, 0.9682]), (0xFFC94D, [0.9668, 0.7965, 0.3914]), (0x4FD8FF, [0.4687, 0.8359, 0.9829])]
  for (hex, p3) in cases {
    let c = HexRGB(hex).displayP3
    #expect(zip([c.red, c.green, c.blue], p3).allSatisfy { abs($0 - $1) < 0.0005 }, "\(String(hex, radix: 16))")
  }
}
@Test(arguments: HexTheme.allCases, [false, true])
func everyPairMeetsItsRule(theme: HexTheme, increased: Bool) {
  let text = increased ? 7.0 : 4.5, contrast: ColorSchemeContrast = increased ? .increased : .standard
  let dark = HexPalette.resolve(theme, scheme: .dark, contrast: contrast)
  let light = HexPalette.resolve(theme, scheme: .light, contrast: contrast)
  // No escuro, o fundo da tela e o cartão do sistema; com Aumentar Contraste, o cartão fica #242426.
  let backgrounds: [HexRGB] = increased ? [.black, .card, .cardIncreased] : [.black, .card]
  for background in backgrounds {
    #expect(dark.accent.contrast(with: background) >= text); #expect(dark.fill.contrast(with: background) >= 3)
    #expect(dark.record.contrast(with: background) >= text)
  }
  #expect(dark.onFill.contrast(with: dark.fill) >= text); #expect(dark.onRecord.contrast(with: dark.record) >= text)
  #expect(light.accent.contrast(with: .white) >= text); #expect(light.onFill.contrast(with: light.fill) >= text)
  #expect(light.fill.contrast(with: .white) >= 3); #expect(light.record.contrast(with: .white) >= text)
  #expect(light.onRecord.contrast(with: light.record) >= text)
  for surface in [HexSurface.watch, .island] {
    #expect(HexPalette.resolve(theme, scheme: .dark, contrast: contrast, surface: surface).accent.contrast(with: .black) >= text)
  }
}
@Test func increasedContrastSwapsTheUltravioletButton() {
  let p = HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased)
  #expect(p.fill == HexRGB(0x8A88FF)); #expect(p.onFill == .black); #expect(p.accent == HexRGB(0xABA5FF))
}
@Test func increasedContrastTextClearsTheSystemCard() {  // #71: o texto passa de 7 no cartão do alto contraste
  #expect(HexRGB.cardIncreased == HexRGB(0x242426))
  #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased).accent == HexRGB(0xABA5FF))
  #expect(HexPalette.resolve(.copper, scheme: .dark, contrast: .increased).accent == HexRGB(0xF5976C))
}
@Test func lightUsesTheLightColumnWithAWhiteLabel() {
  let p = HexPalette.resolve(.copper, scheme: .light, contrast: .standard)
  #expect(p.accent == HexRGB(0xB0521F)); #expect(p.fill == HexRGB(0xB0521F)); #expect(p.onFill == .white)
  #expect(p.record == HexRGB(0x8A6100)); #expect(p.glow == nil)
}
@Test func theWatchAndTheIslandUseTheirOwnUltraviolet() {
  for surface in [HexSurface.watch, .island] {
    #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .standard, surface: surface).accent == HexRGB(0x9D8CFF))
    #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased, surface: surface).accent == HexRGB(0xABA5FF))
    #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard, surface: surface).accent == HexRGB(0x4FD8FF))
  }
}
@Test func increasedContrastDropsTheGradientSupport() {
  #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard).support == HexRGB(0x5E6BFF))
  #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .increased).support == nil)
}
@Test func chalkHasNoVividGlow() {                       // decisão 3: o Giz fica sem P3 vivo
  let gray = HexRGB(0x8D8A84).displayP3
  #expect(HexPalette.resolve(.chalk, scheme: .dark, contrast: .standard).glow
          == HexP3(red: gray.red, green: gray.green, blue: gray.blue, opacity: 0.55))
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheSwatches() throws {   // cores.png
  try writePrint(Swatches(), named: "cores")
}

// O print das cores: uma linha por modo do aparelho e uma coluna por tema.
private struct Mode: Hashable {
  let title: String, scheme: ColorScheme, contrast: ColorSchemeContrast
}
private let modes = [
  Mode(title: "Escuro", scheme: .dark, contrast: .standard),
  Mode(title: "Escuro com alto contraste", scheme: .dark, contrast: .increased),
  Mode(title: "Claro", scheme: .light, contrast: .standard),
]

// Os nomes dos temas na seção 6.
private func name(_ theme: HexTheme) -> String {
  switch theme {
  case .ultraviolet: "Ultravioleta"
  case .chalk: "Giz & Ferro"
  case .cyan: "Ciano Glacial"
  case .copper: "Cobre Forjado"
  }
}

private func hex(_ rgb: HexRGB) -> String { String(format: "#%06X", rgb.hex) }

private let br = Locale(identifier: "pt_BR")

private struct Swatches: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        Text("As cores dos quatro temas").font(.system(size: 26, weight: .bold))
        Text("Os valores aprovados em sRGB, no mesmo ponto em Display P3. Só o brilho usa o P3 vivo, e o Giz fica sem ele.")
          .font(.system(size: 14)).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        Color.clear.frame(width: 132, height: 1)
        ForEach(HexTheme.allCases, id: \.self) { theme in
          Text(name(theme)).font(.system(size: 18, weight: .semibold)).frame(width: 220, alignment: .leading)
        }
      }
      ForEach(modes, id: \.self) { mode in
        HStack(alignment: .top, spacing: 12) {
          Text(mode.title).font(.system(size: 15, weight: .semibold)).frame(width: 132, alignment: .leading)
          ForEach(HexTheme.allCases, id: \.self) { theme in
            Swatch(palette: .resolve(theme, scheme: mode.scheme, contrast: mode.contrast), scheme: mode.scheme, contrast: mode.contrast)
          }
        }
      }
    }
    .padding(28)
  }
}

// As amostras de um tema num modo: o accent no fundo (e, no escuro, no cartão do sistema), o botão
// no fill com o onFill escrito, o recorde com o onRecord e o brilho, quando há.
private struct Swatch: View {
  let palette: HexPalette, scheme: ColorScheme, contrast: ColorSchemeContrast

  // O cartão que o sistema desenha no modo: com Aumentar Contraste, o cardIncreased.
  private var card: HexRGB { contrast == .increased ? .cardIncreased : .card }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      caption("Destaque")
      Text(hex(palette.accent)).font(.system(size: 24, weight: .bold)).foregroundStyle(Color(palette.accent))
      if scheme == .dark {
        Text("no cartão").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(palette.accent))
          .frame(maxWidth: .infinity, minHeight: 34).background(Color(card), in: .rect(cornerRadius: 10))
      }
      caption("Botão").padding(.top, 6)
      Text(hex(palette.fill)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(palette.onFill))
        .frame(maxWidth: .infinity, minHeight: 48).background(Color(palette.fill), in: .rect(cornerRadius: 14))
      caption("Recorde").padding(.top, 6)
      Text(hex(palette.record)).font(.system(size: 15, weight: .bold)).foregroundStyle(Color(palette.onRecord))
        .frame(maxWidth: .infinity, minHeight: 34).background(Color(palette.record), in: .capsule)
      caption("Brilho").padding(.top, 6)
      glow
    }
    .padding(14)
    .frame(width: 220, alignment: .topLeading)
    .background(scheme == .dark ? Color.black : Color.white, in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(scheme == .dark ? 0.18 : 0)) }
    .environment(\.colorScheme, scheme)
  }

  private func caption(_ text: String) -> some View {
    Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
  }

  // O brilho no preto, do glow (com a opacidade dele) até sumir, passando pelo support quando há.
  @ViewBuilder private var glow: some View {
    if let glow = palette.glow {
      let support = palette.support.map { [Color($0).opacity(glow.opacity / 2)] } ?? []
      RadialGradient(colors: [Color(glow)] + support + [Color(glow).opacity(0)], center: .top, startRadius: 0, endRadius: 130)
        .frame(height: 84).background(Color.black).clipShape(.rect(cornerRadius: 12))
      let p3 = [glow.red, glow.green, glow.blue].map { $0.formatted(.number.precision(.fractionLength(4)).locale(br)) }
      Text("P3 \(p3.joined(separator: " ")); \(glow.opacity.formatted(.percent.locale(br)))")
        .font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
      if let rgb = palette.support {
        Text("apoio \(hex(rgb))").font(.system(size: 12)).foregroundStyle(.secondary)
      }
    } else {
      Text("Sem brilho no claro").font(.system(size: 13)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 84).background(Color.black.opacity(0.05), in: .rect(cornerRadius: 12))
    }
  }
}
