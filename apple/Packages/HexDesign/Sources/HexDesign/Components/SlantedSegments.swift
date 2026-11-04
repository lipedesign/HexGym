// Os segmentos inclinados (seção 6 do design doc, componentes nossos): as séries do exercício numa
// linha, um paralelogramo por série. As feitas ficam no accent, a atual no accent a 35% e as outras no
// cinza terciário. Da direita para a esquerda, a linha começa na direita e a inclinação vira junto
// (Foco da revisão, item 1). Para o VoiceOver, a linha é um elemento só, que diz em que série você
// está.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a inclinação de 18°.

import SwiftUI

public struct SlantedSegments: View {
  private let total: Int
  private let done: Int

  @Environment(\.hexPalette) private var palette
  @Environment(\.locale) private var locale
  // A altura da linha acompanha o Dynamic Type.
  @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 10

  public init(total: Int, done: Int) {
    self.total = max(total, 0)
    self.done = done
  }

  // "3 de 5 séries", "1 of 1 set": o plural segue o total, no .stringsdict da tabela Progress.
  nonisolated public static func spokenValue(total: Int, done: Int, locale: Locale = .current) -> String {
    let total = max(total, 0)
    return HexStrings.format("%lld of %lld sets", table: "Progress", locale: locale, min(max(done, 0), total), total)
  }

  public var body: some View {
    HStack(spacing: HexSpacing.xxs) {
      ForEach(0..<total, id: \.self) { index in
        SlantedSegment()
          .fill(fill(at: index))
          .flipsForRightToLeftLayoutDirection(true)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: HexStrings.text("sets", table: "Progress", locale: locale)))
    .accessibilityValue(Text(verbatim: Self.spokenValue(total: total, done: done, locale: locale)))
  }

  // As feitas no accent, a atual no accent a 35% e as outras no cinza terciário.
  private func fill(at index: Int) -> AnyShapeStyle {
    if index < done { return AnyShapeStyle(Color(palette.accent)) }
    if index == done { return AnyShapeStyle(Color(palette.accent).opacity(0.35)) }
    return AnyShapeStyle(.tertiary)
  }
}

// Um paralelogramo inclinado 18°: o alto puxa para a direita.
struct SlantedSegment: Shape {
  static let slant = 18.0

  func path(in rect: CGRect) -> Path {
    let shift = min(rect.height * tan(Self.slant * .pi / 180), rect.width / 2)
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + shift, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - shift, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
