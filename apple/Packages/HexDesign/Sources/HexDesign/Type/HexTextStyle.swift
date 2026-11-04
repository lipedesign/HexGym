// A escala de texto do HexGym sobre o Dynamic Type (seções 6 e 10 do design doc, com a decisão 1 de
// 03/11/2026): seis estilos na Barlow Condensed, para os números, os títulos e as unidades, cada um
// seguindo um estilo de texto do sistema. O texto corrido não usa a escala: fica nos estilos do
// sistema (.body, .subheadline e os outros), na SF Pro.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: os tamanhos, os pesos, os tetos e o
// espaçamento entre letras da tabela.

import SwiftUI

public enum HexTextStyle: CaseIterable, Sendable {
  case display, number, title, headline, unit, caption

  // Uma linha da tabela da escala.
  private struct Row {
    let size: CGFloat, weight: HexWeight, relativeTo: Font.TextStyle, maxSize: CGFloat?
    let tabularDigits: Bool, uppercase: Bool, tracking: CGFloat
  }

  // A tabela. Os estilos com teto são os de uma linha só, que estourariam a tela no maior tamanho de
  // texto (AX5); o headline e o caption quebram linha e crescem sem teto.
  private var row: Row {
    switch self {
    case .display: Row(size: 92, weight: .extraBold, relativeTo: .largeTitle, maxSize: 132, tabularDigits: true, uppercase: false, tracking: 0)
    case .number: Row(size: 48, weight: .extraBold, relativeTo: .title, maxSize: 88, tabularDigits: true, uppercase: false, tracking: 0)
    case .title: Row(size: 34, weight: .extraBold, relativeTo: .title2, maxSize: 60, tabularDigits: false, uppercase: true, tracking: 0)
    case .headline: Row(size: 22, weight: .bold, relativeTo: .headline, maxSize: nil, tabularDigits: false, uppercase: true, tracking: 0.4)
    case .unit: Row(size: 24, weight: .bold, relativeTo: .title3, maxSize: 44, tabularDigits: false, uppercase: true, tracking: 0.2)
    case .caption: Row(size: 15, weight: .medium, relativeTo: .footnote, maxSize: nil, tabularDigits: true, uppercase: true, tracking: 0.6)
    }
  }

  // O tamanho no tamanho de texto padrão (Large), em pontos.
  public var baseSize: CGFloat { row.size }
  public var weight: HexWeight { row.weight }
  // O estilo do sistema que o tamanho segue no Dynamic Type.
  public var relativeTo: Font.TextStyle { row.relativeTo }
  // O teto, em pontos; nil nos estilos que quebram linha.
  public var maxSize: CGFloat? { row.maxSize }
  public var tabularDigits: Bool { row.tabularDigits }
  public var uppercase: Bool { row.uppercase }
  // O espaçamento entre letras, em pontos.
  public var tracking: CGFloat { row.tracking }

  // O tamanho que o @ScaledMetric deu, parado no teto do estilo, quando ele tem um.
  public func pointSize(scaled: CGFloat) -> CGFloat {
    maxSize.map { min(scaled, $0) } ?? scaled
  }
}

extension View {
  // O texto no estilo da escala: a Barlow Condensed no tamanho do Dynamic Type até o teto, um peso
  // acima com o Texto em Negrito, com o espaçamento entre letras e, quando o estilo pede, em caixa alta.
  public func hexFont(_ style: HexTextStyle) -> some View {
    modifier(HexFontModifier(style: style))
  }
}

struct HexFontModifier: ViewModifier {
  let style: HexTextStyle
  @ScaledMetric private var scaled: CGFloat
  @Environment(\.legibilityWeight) private var legibilityWeight
  // A caixa que vem de fora, que um estilo sem caixa alta deixa como está.
  @Environment(\.textCase) private var inheritedCase

  init(style: HexTextStyle) {
    self.style = style
    _scaled = ScaledMetric(wrappedValue: style.baseSize, relativeTo: style.relativeTo)
  }

  func body(content: Content) -> some View {
    let weight = legibilityWeight == .bold ? style.weight.boldText : style.weight
    let font = HexFonts.font(weight, size: style.pointSize(scaled: scaled), tabularDigits: style.tabularDigits)
    content
      .font(Font(font))
      .tracking(style.tracking)
      .textCase(style.uppercase ? .uppercase : inheritedCase)
  }
}
