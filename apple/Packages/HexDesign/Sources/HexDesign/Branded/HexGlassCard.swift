// O cartão de vidro do HexGym (seção 6 do design doc, a camada "Da Apple, com a marca"): o vidro da
// Apple, com o comportamento dela, tingido pelo accent do tema. Com Aumentar Contraste, ou com a
// prévia de alto contraste da galeria, o vidro fica sem tinta (Foco da revisão, item 4), do mesmo
// jeito que a paleta do ambiente decide o alto contraste. Com Reduzir Transparência, o sistema já
// deixa o vidro opaco.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o vidro tingido com o accent a 18%, sem
// tinta no alto contraste.

import SwiftUI

public enum HexGlass {
  // A opacidade da tinta do accent no vidro: 0,18, ou nenhuma tinta com alto contraste.
  public static func tintOpacity(contrast: ColorSchemeContrast) -> Double? {
    contrast == .increased ? nil : 0.18
  }
}

public struct HexGlassCard<Content: View>: View {
  private let content: Content

  @Environment(\.hexPalette) private var palette
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexContrastPreview) private var contrastPreview

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .padding(HexSpacing.m)
      .glassEffect(glass, in: RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
  }

  // O vidro regular, com a tinta do accent quando o contraste deixa.
  private var glass: Glass {
    let increased = contrast == .increased || contrastPreview
    guard let opacity = HexGlass.tintOpacity(contrast: increased ? .increased : .standard) else { return .regular }
    return .regular.tint(Color(palette.accent).opacity(opacity))
  }
}
