// O anel de descanso (seção 6 do design doc, componentes nossos): 60 traços curtos em volta de um
// círculo, cada um inclinado 18° em relação ao raio e sem pontas redondas, com o tempo que falta no
// centro. Assim ele não parece um anel de atividade da Apple, que é uma faixa contínua com pontas
// redondas. O tempo usa os dígitos tabulares do number, e o anel tem o diâmetro do Dynamic Type, não
// o do texto: 59:59 virando 1:00:00 não muda o tamanho de nada (Foco da revisão, item 3).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o anel em 60 traços inclinados, sem
// pontas redondas, na cor do tema.

import SwiftUI

public enum RestRingModel {
  public static let ticks = 60

  // Quantos traços ficam acesos: a parte do descanso que falta, em 60 traços, entre 0 e 60.
  public static func litTicks(total: Int, remaining: Int) -> Int {
    guard total > 0 else { return 0 }
    let lit = (Double(ticks) * Double(remaining) / Double(total)).rounded()
    return Int(min(max(lit, 0), Double(ticks)))
  }

  // m:ss abaixo de uma hora e h:mm:ss a partir dela; negativo dá 0:00.
  public static func time(_ seconds: Int) -> String {
    let seconds = max(seconds, 0)
    let (hours, minutes, rest) = (seconds / 3600, seconds % 3600 / 60, seconds % 60)
    return hours > 0 ? "\(hours):\(twoDigits(minutes)):\(twoDigits(rest))" : "\(minutes):\(twoDigits(rest))"
  }

  // O tempo como o VoiceOver fala, no idioma: "1 minuto e 30 segundos", "1 minute, 30 seconds". O
  // CLDR do português põe o 0 na forma one, e o formato da Apple diria "0 segundo" justo quando o
  // descanso acaba: o 0 em português vem da tabela Progress, no plural, como o da carga (QA da PR #78).
  public static func spokenTime(_ seconds: Int, locale: Locale = .current) -> String {
    let seconds = max(seconds, 0)
    if seconds == 0, HexStrings.isPortuguese(locale) { return HexStrings.text("rest.zero", table: "Progress", locale: locale) }
    return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))
  }

  private static func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}

public struct RestRing: View {
  private let total: Int
  private let remaining: Int

  @Environment(\.hexPalette) private var palette
  @Environment(\.locale) private var locale
  // O diâmetro: 220 pt no tamanho de texto padrão, crescendo com o Dynamic Type.
  @ScaledMetric(relativeTo: .title) private var diameter: CGFloat = 220

  // total e remaining em segundos.
  public init(total: Int, remaining: Int) {
    self.total = total
    self.remaining = remaining
  }

  public var body: some View {
    let lit = RestRingModel.litTicks(total: total, remaining: remaining)
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      ZStack {
        RestTicks(range: 0..<(RestRingModel.ticks - lit)).fill(.tertiary)
        RestTicks(range: (RestRingModel.ticks - lit)..<RestRingModel.ticks).fill(Color(palette.accent))
        RollingNumber(value: Double(remaining), text: RestRingModel.time(remaining))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(width: side * RestTicks.innerRadius * 2 * 0.86)
      }
      .frame(width: side, height: side)
      .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
    }
    // Nunca passa da largura que tem: o quadrado cabe no espaço oferecido, até o diâmetro.
    .frame(idealWidth: diameter, maxWidth: diameter, idealHeight: diameter, maxHeight: diameter)
    .aspectRatio(1, contentMode: .fit)
    .sensoryFeedback(HexHaptic.restDone.feedback(), trigger: remaining) { old, new in old > 0 && new <= 0 }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: HexStrings.text("rest", table: "Progress", locale: locale)))
    .accessibilityValue(Text(verbatim: RestRingModel.spokenTime(remaining, locale: locale)))
    .accessibilityAddTraits(.updatesFrequently)
  }
}

// Os traços do anel, de cima, no sentido do relógio. O tempo que passa apaga os traços na mesma
// direção, como um ponteiro: os acesos são os últimos da volta.
struct RestTicks: Shape {
  let range: Range<Int>

  // Em frações do raio: onde o traço começa e a espessura dele.
  static let innerRadius: CGFloat = 0.82
  static let thickness: CGFloat = 0.028
  static let slant = 18.0

  func path(in rect: CGRect) -> Path {
    let radius = min(rect.width, rect.height) / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let (inner, width) = (radius * Self.innerRadius, radius * Self.thickness)
    let slant = Self.slant * .pi / 180
    var path = Path()
    for index in range {
      // O ângulo do raio, a partir do alto; o traço segue o raio girado 18°, e o comprimento é o que
      // cabe entre o círculo de dentro e o de fora.
      let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(RestRingModel.ticks)
      let start = CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle))
      let direction = angle + slant
      let length = Self.length(inner: inner, outer: radius - width, slant: slant)
      let end = CGPoint(x: start.x + length * cos(direction), y: start.y + length * sin(direction))
      // Um retângulo fino de start até end: pontas retas, sem arredondar.
      let (nx, ny) = (-sin(direction) * width / 2, cos(direction) * width / 2)
      path.move(to: CGPoint(x: start.x + nx, y: start.y + ny))
      path.addLine(to: CGPoint(x: end.x + nx, y: end.y + ny))
      path.addLine(to: CGPoint(x: end.x - nx, y: end.y - ny))
      path.addLine(to: CGPoint(x: start.x - nx, y: start.y - ny))
      path.closeSubpath()
    }
    return path
  }

  // O comprimento de um traço que sai do círculo de dentro, girado do raio, até tocar o de fora.
  static func length(inner: CGFloat, outer: CGFloat, slant: Double) -> CGFloat {
    let along = inner * cos(slant)
    return -along + (along * along + outer * outer - inner * inner).squareRoot()
  }
}
