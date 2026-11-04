// Os testes do brilho que respira (seção 6 do design doc, com a decisão 2 de 03/11/2026, e o Foco da
// revisão, item 4): ele apaga com Reduzir Transparência, cai à metade com alto contraste, fica parado
// com Reduzir Movimento e no Watch, e não existe no claro. Quando o Reduzir Movimento liga no meio do
// ciclo, ele volta à escala 1 numa transação sem animação. E o print dos segmentos, do carimbo, do
// anel e do brilho.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter GlowTests
//
// Os prints (segmentos.png, carimbo.png, anel.png e brilho.png) só rodam com HEXDESIGN_PRINTS na frente
// do comando e --filter printTheProgressPieces.

import SwiftUI
import Testing
@testable import HexDesign

@Test func theGlowFollowsAccessibility() {                                // Foco da revisão 4
  let uv = HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .standard)
  func glow(_ contrast: ColorSchemeContrast, transparency: Bool, motion: Bool) -> GlowSpec? {
    GlowSpec.resolve(palette: uv, contrast: contrast, reduceTransparency: transparency, reduceMotion: motion)
  }
  #expect(glow(.standard, transparency: false, motion: false)?.color.opacity == 0.85)
  #expect(glow(.standard, transparency: false, motion: false)?.breathes == true)
  #expect(glow(.increased, transparency: false, motion: false)?.color.opacity == 0.425)
  #expect(glow(.standard, transparency: false, motion: true)?.breathes == false)
  #expect(glow(.standard, transparency: true, motion: false) == nil)
  #expect(glow(.increased, transparency: true, motion: true) == nil)
}
@Test func noGlowOnLightAndAStillGlowOnTheWatch() {
  let light = HexPalette.resolve(.cyan, scheme: .light, contrast: .standard)
  #expect(GlowSpec.resolve(palette: light, contrast: .standard, reduceTransparency: false, reduceMotion: false) == nil)
  let cyan = HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard)
  #expect(GlowSpec.resolve(palette: cyan, contrast: .standard, reduceTransparency: false, reduceMotion: false, surface: .watch)?.breathes == false)
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheProgressPieces() throws { // segmentos, carimbo, anel e brilho
  try writePrint(SegmentSheet(stills: try SegmentCell.all.map { try still($0.view) }), named: "segmentos")
  try writePrint(StampSheet(stills: try StampCell.all.map { try still($0.view) }), named: "carimbo")
  try writePrint(RingSheet(stills: try RingCell.all.map { try still($0.view) }), named: "anel")
  try writePrint(GlowSheet(stills: try GlowCell.all.map { try still($0.view) }), named: "brilho")
}

// Achado no QA da PR #74: um repeatForever em curso não para só porque a animação vira nil. Quando o
// brilho para de respirar, ele volta à escala 1 numa transação que desliga as animações.
@Test func theGlowStopsStillWhenReduceMotionTurnsOn() {                  // Foco da revisão 4
  #expect(GlowBreath.scale(breathes: false, inhaled: true) == 1); #expect(GlowBreath.scale(breathes: false, inhaled: false) == 1)
  #expect(GlowBreath.scale(breathes: true, inhaled: false) == HexBreathing.scale.lowerBound)
  #expect(GlowBreath.scale(breathes: true, inhaled: true) == HexBreathing.scale.upperBound)
  let still = GlowBreath.transaction(breathes: false)
  #expect(still.disablesAnimations); #expect(still.animation == nil)
  let breathing = GlowBreath.transaction(breathes: true)
  #expect(!breathing.disablesAnimations); #expect(breathing.animation == HexMotion.breathe.animation(reduceMotion: false))
}
// O apoio entra no brilho quando o tema tem, e sai com alto contraste, como na paleta.
@Test func theGlowCarriesTheSupportColorUnlessContrastIsUp() {
  let cyan = HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard)
  #expect(GlowSpec.resolve(palette: cyan, contrast: .standard, reduceTransparency: false, reduceMotion: false)?.support == HexRGB(0x5E6BFF))
  let cyanIncreased = HexPalette.resolve(.cyan, scheme: .dark, contrast: .increased)
  #expect(GlowSpec.resolve(palette: cyanIncreased, contrast: .increased, reduceTransparency: false, reduceMotion: false)?.support == nil)
}

// O print dos segmentos: uma coluna por tema, com 0, 3 e 5 de 5 séries e, por último, 1 de 5 da
// direita para a esquerda.
private struct SegmentCell {
  let title: String, done: Int, rightToLeft: Bool

  static let rows = [
    SegmentCell(title: "0 de 5", done: 0, rightToLeft: false),
    SegmentCell(title: "3 de 5", done: 3, rightToLeft: false),
    SegmentCell(title: "5 de 5", done: 5, rightToLeft: false),
    SegmentCell(title: "1 de 5, da direita para a esquerda", done: 1, rightToLeft: true),
  ]
  static let all = rows.flatMap { row in HexTheme.allCases.map { (row, $0) } }.map(Themed.init)

  struct Themed {
    let cell: SegmentCell, theme: HexTheme
    init(_ pair: (SegmentCell, HexTheme)) { (cell, theme) = pair }

    @MainActor var view: some View {
      SlantedSegments(total: 5, done: cell.done)
        .environment(\.layoutDirection, cell.rightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.hexTheme, theme)
        .frame(width: 240)
        .padding(.vertical, 8)
    }
  }
}

private struct SegmentSheet: View {
  let stills: [Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SheetTitle(
        title: "Os segmentos inclinados",
        text: "Um paralelogramo por série, inclinado 18°, com 4 pt entre eles. As feitas no accent, a atual no accent a 35% e as outras no cinza terciário. Da direita para a esquerda, a ordem e a inclinação viram.",
        width: 1180)
      HStack(spacing: 24) {
        Color.clear.frame(width: 160, height: 1)
        ForEach(HexTheme.allCases, id: \.self) { theme in
          Text(verbatim: theme.displayName(locale: br)).font(.system(size: 17, weight: .semibold)).frame(width: 240, alignment: .leading)
        }
      }
      ForEach(SegmentCell.rows.indices, id: \.self) { row in
        HStack(spacing: 24) {
          Text(verbatim: SegmentCell.rows[row].title).font(.system(size: 14, weight: .semibold)).frame(width: 160, alignment: .leading)
          ForEach(HexTheme.allCases.indices, id: \.self) { column in stills[row * HexTheme.allCases.count + column] }
        }
      }
    }
    .padding(28)
  }
}

// O print do carimbo: em português e em inglês. O title já está no peso mais forte da Barlow, então o
// Texto em Negrito não muda o carimbo.
private struct StampCell {
  let title: String, locale: Locale

  static let all = [StampCell(title: "Em português", locale: br), StampCell(title: "Em inglês", locale: en)]

  @MainActor var view: some View {
    RecordStamp(isShown: true)
      .environment(\.locale, locale)
      .frame(width: 280, height: 150)
  }
}

private struct StampSheet: View {
  let stills: [Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SheetTitle(
        title: "O carimbo de recorde",
        text: "Recorde no title, em caixa alta, no ouro do recorde, com contorno de 3 pt no raio do chip, girado 8° para subir à direita. Ele entra caindo de 1,4 vez o tamanho, ou só aparece com Reduzir Movimento.",
        width: 600)
      HStack(spacing: 40) {
        ForEach(StampCell.all.indices, id: \.self) { index in
          VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: StampCell.all[index].title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            stills[index]
          }
        }
      }
    }
    .padding(28)
  }
}

// O print do anel: 1:30 de 2:00, 59:59 e 1:00:00 de uma hora, no Ultravioleta e no Ciano.
private struct RingCell {
  let title: String, total: Int, remaining: Int, theme: HexTheme

  static let all = [
    RingCell(title: "1:30 de 2:00", total: 120, remaining: 90, theme: .ultraviolet),
    RingCell(title: "59:59 de uma hora", total: 3600, remaining: 3599, theme: .ultraviolet),
    RingCell(title: "1:00:00", total: 3600, remaining: 3600, theme: .ultraviolet),
    RingCell(title: "1:30 de 2:00, no Ciano", total: 120, remaining: 90, theme: .cyan),
  ]

  @MainActor var view: some View {
    RestRing(total: total, remaining: remaining).environment(\.hexTheme, theme).padding(10)
  }
}

private struct RingSheet: View {
  let stills: [Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SheetTitle(
        title: "O anel de descanso",
        text: "60 traços curtos, cada um inclinado 18° em relação ao raio, sem pontas redondas: os acesos no accent e os outros no cinza terciário. O tempo no number, com dígitos tabulares: 59:59 e 1:00:00 cabem no mesmo anel, de 220 pt.",
        width: 1000)
      HStack(alignment: .top, spacing: 24) {
        ForEach(RingCell.all.indices, id: \.self) { index in
          VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: RingCell.all[index].title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            stills[index]
          }
        }
      }
    }
    .padding(28)
  }
}

// O print do brilho: uma coluna por tema, sem e com alto contraste, como o alto de uma tela.
private struct GlowCell {
  let theme: HexTheme, contrast: Bool

  static let all = [false, true].flatMap { contrast in HexTheme.allCases.map { GlowCell(theme: $0, contrast: contrast) } }

  @MainActor var view: some View {
    BreathingGlow()
      .environment(\.hexTheme, theme)
      .environment(\.hexContrastPreview, contrast)
      .frame(width: 220, height: 320)
  }
}

private struct GlowSheet: View {
  let stills: [Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SheetTitle(
        title: "O brilho que respira",
        text: "Um gradiente radial no alto da tela, na cor do brilho do tema em Display P3, passando pela cor de apoio quando o tema tem. Com alto contraste, a força cai à metade e o apoio sai. Com Reduzir Transparência ele apaga, e com Reduzir Movimento e no Watch fica parado.",
        width: 960)
      HStack(spacing: 24) {
        Color.clear.frame(width: 120, height: 1)
        ForEach(HexTheme.allCases, id: \.self) { theme in
          Text(verbatim: theme.displayName(locale: br)).font(.system(size: 17, weight: .semibold)).frame(width: 220, alignment: .leading)
        }
      }
      ForEach([false, true], id: \.self) { contrast in
        HStack(alignment: .top, spacing: 24) {
          Text(verbatim: contrast ? "Com alto contraste" : "Normal").font(.system(size: 14, weight: .semibold)).frame(width: 120, alignment: .leading)
          ForEach(HexTheme.allCases.indices, id: \.self) { column in
            stills[(contrast ? HexTheme.allCases.count : 0) + column]
              .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.15), lineWidth: 1))
          }
        }
      }
    }
    .padding(28)
  }
}

// O título e a explicação de uma folha de print.
private struct SheetTitle: View {
  let title: String, text: String, width: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(verbatim: title).font(.system(size: 26, weight: .bold))
      Text(verbatim: text).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: width, alignment: .leading)
  }
}
