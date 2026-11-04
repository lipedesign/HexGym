// O brilho que respira (seção 6 do design doc, com a decisão 2 de 03/11/2026: entra como nosso): o
// fundo preto da tela, com um gradiente radial no alto, na cor do brilho do tema em Display P3, que
// cresce e encolhe devagar. Com Reduzir Transparência ele apaga; com alto contraste, a força cai à
// metade; com Reduzir Movimento, e no Watch, ele fica parado (Foco da revisão, item 4). O claro não
// tem brilho.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o brilho com a metade da força no alto
// contraste, apagado com Reduzir Transparência e parado no Watch.

import SwiftUI

public struct GlowSpec: Equatable, Sendable {
  // A cor do brilho, com a opacidade já resolvida.
  public let color: HexP3
  // A cor de apoio, no meio do gradiente; nil quando o tema não tem ou com alto contraste.
  public let support: HexRGB?
  public let breathes: Bool

  // O brilho do aparelho: nil quando a paleta não tem brilho (o claro) ou com Reduzir Transparência;
  // com alto contraste, metade da opacidade; parado com Reduzir Movimento e no Watch.
  public static func resolve(
    palette: HexPalette, contrast: ColorSchemeContrast, reduceTransparency: Bool, reduceMotion: Bool, surface: HexSurface = .app
  ) -> GlowSpec? {
    guard let glow = palette.glow, !reduceTransparency else { return nil }
    let opacity = contrast == .increased ? glow.opacity / 2 : glow.opacity
    // A regra do Reduzir Movimento fica no HexMotion: o breathe só repete sem ele.
    let breathes = HexMotion.breathe.spec(reduceMotion: reduceMotion).repeats && surface != .watch
    return GlowSpec(
      color: HexP3(red: glow.red, green: glow.green, blue: glow.blue, opacity: opacity), support: palette.support, breathes: breathes)
  }
}

public struct BreathingGlow: View {
  @Environment(\.hexPalette) private var palette
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexContrastPreview) private var contrastPreview
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // Se o brilho está no alto da respiração. O State vai escrito sem o @: neste SDK o @State é um
  // macro, e as Command Line Tools não têm o plugin SwiftUIMacros.
  private let inhaled = State(initialValue: false)

  public init() {}

  // O brilho deste aparelho, com o alto contraste do sistema ou da prévia, como na paleta do ambiente.
  // A superfície vem do HexPlatform.current, a mesma dos hápticos: no Watch, o brilho fica parado.
  private var spec: GlowSpec? {
    let increased = contrast == .increased || contrastPreview
    return GlowSpec.resolve(
      palette: palette, contrast: increased ? .increased : .standard, reduceTransparency: reduceTransparency,
      reduceMotion: reduceMotion, surface: HexPlatform.current.surface)
  }

  public var body: some View {
    let spec = spec, breathes = spec?.breathes ?? false
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        Color.black
        if let spec {
          RadialGradient(stops: GlowBreath.stops(spec), center: .top, startRadius: 0, endRadius: proxy.size.width * GlowBreath.reach)
            .scaleEffect(GlowBreath.scale(breathes: breathes, inhaled: inhaled.wrappedValue), anchor: .top)
            // Quando ele para de respirar, a escala volta a 1 sem animação, mesmo vindo de uma mudança
            // animada do ambiente.
            .transaction(value: breathes) { transaction in
              if !breathes { transaction = GlowBreath.transaction(breathes: false) }
            }
        }
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { breathe(breathes) }
    .onChange(of: breathes) { _, now in breathe(now) }
  }

  // Começa a respirar com o breathe, que vai e volta para sempre, ou para na escala 1 sem animação: um
  // repeatForever em curso não para só porque a animação vira nil.
  private func breathe(_ breathes: Bool) {
    withTransaction(GlowBreath.transaction(breathes: breathes)) { inhaled.wrappedValue = breathes }
  }
}

// As contas do brilho, fora da view para os testes.
enum GlowBreath {
  // O alcance do gradiente: 60% da largura da tela, a partir do meio do alto.
  static let reach: CGFloat = 0.6

  // A escala: entre os dois lados de HexBreathing.scale enquanto respira, e 1 parado.
  static func scale(breathes: Bool, inhaled: Bool) -> CGFloat {
    guard breathes else { return 1 }
    return inhaled ? HexBreathing.scale.upperBound : HexBreathing.scale.lowerBound
  }

  // A transação da troca: o breathe para respirar; para parar, nenhuma animação, nem as de fora.
  static func transaction(breathes: Bool) -> Transaction {
    if breathes { return Transaction(animation: HexMotion.breathe.animation(reduceMotion: false)) }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    return transaction
  }

  // Da cor do brilho, na opacidade resolvida, até zero, passando pelo apoio a meia força quando há.
  static func stops(_ spec: GlowSpec) -> [Gradient.Stop] {
    let glow = Color(spec.color)
    let fade = Color(HexP3(red: spec.color.red, green: spec.color.green, blue: spec.color.blue, opacity: 0))
    guard let support = spec.support else { return [.init(color: glow, location: 0), .init(color: fade, location: 1)] }
    return [
      .init(color: glow, location: 0),
      .init(color: Color(support).opacity(spec.color.opacity / 2), location: 0.55),
      .init(color: Color(support).opacity(0), location: 1),
    ]
  }
}
