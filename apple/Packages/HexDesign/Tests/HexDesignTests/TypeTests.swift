// Os testes da tipografia do HexDesign (seções 6 e 10 do design doc, com a decisão 1 de 03/11/2026):
// o registro da Barlow Condensed com a licença, a reserva na SF Pro Compressed no cirílico e no grego,
// as outras escritas sem quadrado vazio, os dígitos tabulares, o Texto em Negrito, o teto dos estilos
// de uma linha e a escala, e o print da escala e do logotipo.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign
//
// Os prints (tipografia.png e logotipo.png) só rodam com HEXDESIGN_PRINTS na frente do comando e
// --filter printTheTypeScale.

import CoreText
import SwiftUI
import Testing
@testable import HexDesign

@Test func registersTheFourWeightsAndShipsTheLicense() throws {
  HexFonts.register(); HexFonts.register()
  for w in HexWeight.allCases {
    #expect(CTFontCopyPostScriptName(CTFontCreateWithName(w.postScriptName as CFString, 20, nil)) as String == w.postScriptName)
  }
  #expect(try String(contentsOf: #require(HexFonts.licenseURL), encoding: .utf8).contains("SIL OPEN FONT LICENSE Version 1.1"))
}
@Test(arguments: HexWeight.allCases)
func cyrillicAndGreekFallBackToSFProCompressed(weight: HexWeight) {      // Foco da revisão 1
  let font = HexFonts.font(weight, size: 40, tabularDigits: false)
  for name in ["ЖИМ ЛЁЖА", "Πιέσεις πάγκου"] {
    for run in runs(name, font) where run.text.contains(where: \.isLetter) {
      #expect(!run.fontName.hasPrefix("BarlowCondensed")); #expect(run.widthTrait < 0)
      #expect(abs(run.weightTrait - weight.reserveWeight) <= 0.15)
    }
  }
  #expect(runs("SUPINO RETO", font).allSatisfy { $0.fontName == weight.postScriptName })
}
@Test func otherScriptsNeverShowAnEmptyBox() {                            // Foco da revisão 1
  let font = HexFonts.font(.bold, size: 40, tabularDigits: false)
  for name in ["ضغط البنش", "卧推", "벤치 프레스", "เบนช์เพรส", "बेंच प्रेस", "বেঞ্চ প্রেস", "Supino 142,5"] {
    #expect(runs(name, font).allSatisfy { !$0.glyphs.contains(0) }, "\(name)")
  }
}
@Test func tabularStylesKeepEveryDigitTheSameWidth() {                    // Foco da revisão 3
  let tabular = HexFonts.font(.extraBold, size: 48, tabularDigits: true)
  let proportional = HexFonts.font(.extraBold, size: 48, tabularDigits: false)
  #expect(abs(width("111,1", tabular) - width("888,8", tabular)) < 0.01)
  #expect(abs(width("1:11:11", tabular) - width("8:88:88", tabular)) < 0.01)
  #expect(abs(width("111,1", proportional) - width("888,8", proportional)) > 1)
}
@Test func boldTextRaisesOneWeight() {                                    // Foco da revisão 2
  #expect(HexWeight.allCases.map(\.boldText) == [.medium, .bold, .extraBold, .extraBold])
}
@Test func oneLineStylesStopAtTheirCap() {                                // Foco da revisão 2
  #expect(HexTextStyle.display.pointSize(scaled: 400) == 132); #expect(HexTextStyle.display.pointSize(scaled: 100) == 100)
  #expect(HexTextStyle.headline.pointSize(scaled: 400) == 400)
}
@Test func theScaleMatchesTheTable() {
  #expect(HexTextStyle.allCases.map(\.baseSize) == [92, 48, 34, 22, 24, 15])
  #expect(HexTextStyle.allCases.map(\.maxSize) == [132, 88, 60, nil, 44, nil])
  #expect(HexTextStyle.allCases.filter(\.tabularDigits) == [.display, .number, .caption])
}
// O grego em caixa alta (#121, achado no QA da PR #86): a regra do grego tira o tonos das maiúsculas. O
// textCase do SwiftUI segue o locale do ambiente, e no iPhone e no Watch em português ou em inglês ele
// deixava "ΠΙΈΣΕΙΣ ΠΆΓΚΟΥ" (no Mac, tira sempre). O HexCase põe cada trecho em grego em maiúsculas com o
// locale do grego, e o resto com o locale de quem lê: no turco, o i do latim continua virando İ.
@Test func greekCapitalsDropTheTonos() {
  for locale in [br, en] {
    #expect(HexCase.uppercased("Πιέσεις πάγκου", locale: locale) == "ΠΙΕΣΕΙΣ ΠΑΓΚΟΥ")
    #expect(HexCase.uppercased("Πιε\u{301}σεις πα\u{301}γκου", locale: locale) == "ΠΙΕΣΕΙΣ ΠΑΓΚΟΥ")
    #expect(HexCase.uppercased("Supino reto", locale: locale) == "SUPINO RETO")
    #expect(HexCase.uppercased("Жим лёжа", locale: locale) == "ЖИМ ЛЁЖА")
  }
  #expect(HexCase.uppercased("pilates με αλτήρα 12,5", locale: Locale(identifier: "tr")) == "PİLATES ΜΕ ΑΛΤΗΡΑ 12,5")
  #expect(HexCase.uppercased("", locale: br) == "")
}
// O HexText chega à tela com o grego sem o tonos, num estilo em caixa alta, e deixa como está um estilo
// sem caixa alta.
@MainActor @Test func theHexTextShowsGreekCapitalsWithoutTheTonos() {
  for locale in [br, en] {
    #expect(pixels(HexText("Πιέσεις πάγκου", style: .title), locale) != nil)
    #expect(pixels(HexText("Πιέσεις πάγκου", style: .title), locale) == pixels(Text(verbatim: "ΠΙΕΣΕΙΣ ΠΑΓΚΟΥ").hexFont(.title), locale))
    #expect(pixels(HexText("Supino reto", style: .title), locale) == pixels(Text(verbatim: "Supino reto").hexFont(.title), locale))
    #expect(pixels(HexText("Πιέσεις 12", style: .number), locale) == pixels(Text(verbatim: "Πιέσεις 12").hexFont(.number), locale))
  }
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheTypeScale() throws {   // tipografia.png e logotipo.png
  try writePrint(TypeScale(), named: "tipografia")
  try writePrint(Wordmarks(), named: "logotipo")
}

// Um trecho de uma linha do CoreText: o texto, o nome PostScript da fonte que o desenha, os traços de
// largura e de peso dessa fonte e os glifos. O glifo 0 é o quadrado vazio (.notdef).
private struct TextRun {
  let text: String, fontName: String, widthTrait: CGFloat, weightTrait: CGFloat, glyphs: [CGGlyph]
}

// Os bytes da view desenhada no locale pedido, para comparar duas views pixel a pixel.
@MainActor private func pixels(_ view: some View, _ locale: Locale) -> Data? {
  image(view.environment(\.locale, locale))?.dataProvider?.data as Data?
}

// O texto numa linha do CoreText, com a fonte.
private func line(_ text: String, _ font: CTFont) -> CTLine {
  CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
}

// Os trechos da linha. Onde a fonte não tem o caractere, o trecho sai na fonte que a cascata achou.
private func runs(_ text: String, _ font: CTFont) -> [TextRun] {
  let glyphRuns = CTLineGetGlyphRuns(line(text, font)) as? [CTRun] ?? []
  return glyphRuns.map { run in
    let range = CTRunGetStringRange(run)
    let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
    let traits = CTFontCopyTraits(runFont) as NSDictionary
    var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
    return TextRun(
      text: (text as NSString).substring(with: NSRange(location: range.location, length: range.length)),
      fontName: CTFontCopyPostScriptName(runFont) as String,
      widthTrait: (traits[kCTFontWidthTrait as String] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0,
      weightTrait: (traits[kCTFontWeightTrait as String] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0,
      glyphs: glyphs)
  }
}

// A largura tipográfica do texto numa linha com a fonte, em pontos.
private func width(_ text: String, _ font: CTFont) -> CGFloat {
  CGFloat(CTLineGetTypographicBounds(line(text, font), nil, nil, nil))
}

// O print da escala: um estilo por linha, com o tamanho, o peso, o estilo do sistema que ele segue, o
// teto e o resto, e a mesma amostra sem e com Texto em Negrito; depois, os nomes em outras escritas no
// title e os dígitos tabulares no number.
private struct TypeScale: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        Text("A escala de texto").font(.system(size: 26, weight: .bold))
        Text("A Barlow Condensed nos números e nos títulos, sobre o Dynamic Type. O cirílico e o grego saem na SF Pro Compressed, e as outras escritas, na fonte do sistema.")
          .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: 860, alignment: .leading)
      HStack(spacing: 24) {
        Color.clear.frame(width: 250, height: 1)
        heading("Normal").frame(width: 280, alignment: .leading)
        heading("Com Texto em Negrito").frame(width: 280, alignment: .leading)
      }
      ForEach(HexTextStyle.allCases, id: \.self) { style in
        HStack(spacing: 24) {
          VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(style)").font(.system(size: 17, weight: .semibold))
            Text(verbatim: details(style)).font(.system(size: 12)).foregroundStyle(.secondary)
          }
          .frame(width: 250, alignment: .leading)
          Text(verbatim: sample(style)).hexFont(style).frame(width: 280, alignment: .leading)
          Text(verbatim: sample(style)).hexFont(style).environment(\.legibilityWeight, .bold).frame(width: 280, alignment: .leading)
        }
      }
      VStack(alignment: .leading, spacing: 8) {
        heading("Outras escritas, no title")
        HStack(alignment: .firstTextBaseline, spacing: 28) {
          Text(verbatim: "ЖИМ ЛЁЖА").hexFont(.title)
          Text(verbatim: "Πιέσεις πάγκου").hexFont(.title)
          Text(verbatim: "卧推").hexFont(.title)
        }
        note("O cirílico e o grego na SF Pro Compressed, no peso do estilo, e o chinês na fonte do sistema.")
      }
      .padding(.top, 8)
      VStack(alignment: .leading, spacing: 8) {
        heading("Dígitos tabulares, no number")
        HStack(alignment: .top, spacing: 48) {
          digits("Com dígitos tabulares", font: Font(HexFonts.font(.extraBold, size: 48, tabularDigits: true)))
          digits("Sem, como a Barlow vem", font: Font(HexFonts.font(.extraBold, size: 48, tabularDigits: false)))
        }
        note("Com os dígitos tabulares, um número que muda não pula de largura.")
      }
      .padding(.top, 8)
    }
    .padding(28)
  }

  private func heading(_ text: String) -> some View {
    Text(verbatim: text).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
  }

  private func note(_ text: String) -> some View {
    Text(verbatim: text).font(.system(size: 12)).foregroundStyle(.secondary)
  }

  // Os números uns sobre os outros, cada um com um fundo da largura dele.
  private func digits(_ title: String, font: Font) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      note(title)
      ForEach(["111,1", "888,8", "1:11:11", "8:88:88"], id: \.self) { number in
        Text(verbatim: number).font(font).background(Color.white.opacity(0.12))
      }
    }
  }
}

// O que cada estilo mostra no print, em português.
private func sample(_ style: HexTextStyle) -> String {
  switch style {
  case .display, .number: "142,5"
  case .title: "Supino reto"
  case .headline, .caption: "Série 3 de 5"
  case .unit: "kg"
  }
}

// A linha da tabela da escala, escrita a partir do próprio estilo.
private func details(_ style: HexTextStyle) -> String {
  var parts = ["\(Int(style.baseSize)) pt", "peso \(style.weight.rawValue)", "segue o \(systemStyle(style.relativeTo))"]
  parts.append(style.maxSize.map { "teto de \(Int($0)) pt" } ?? "sem teto")
  if style.tabularDigits { parts.append("dígitos tabulares") }
  if style.uppercase { parts.append("caixa alta") }
  if style.tracking != 0 { parts.append("tracking de \(Double(style.tracking).formatted(.number.locale(br)))") }
  return parts.joined(separator: ", ")
}

private func systemStyle(_ style: Font.TextStyle) -> String {
  switch style {
  case .largeTitle: ".largeTitle"
  case .title: ".title"
  case .title2: ".title2"
  case .title3: ".title3"
  case .headline: ".headline"
  case .footnote: ".footnote"
  default: "outro estilo"
  }
}

// O print do logotipo, em 44 e em 88.
private struct Wordmarks: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      VStack(alignment: .leading, spacing: 6) {
        Text("O logotipo").font(.system(size: 26, weight: .bold))
        Text("HEX no peso 800 e gym no 200, do mesmo tamanho e na mesma linha de base, com 0,06 do tamanho entre os dois. Ele não segue o Dynamic Type.")
          .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: 520, alignment: .leading)
      ForEach([44, 88] as [CGFloat], id: \.self) { size in
        VStack(alignment: .leading, spacing: 8) {
          Text(verbatim: "\(Int(size)) pt").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
          HexWordmark(size: size)
        }
      }
    }
    .padding(28)
  }
}
