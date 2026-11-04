// Os botões secundários do HexGym (seção 6 do design doc e a decisão 2 de 03/11/2026): o estilo .glass
// da Apple, com o comportamento dela, tingido pelo accent do tema. O alto contraste vem pela paleta do
// ambiente.

import SwiftUI

extension View {
  // Os botões dentro desta view ficam em .glass, tingidos pelo accent.
  public func hexSecondaryButton() -> some View {
    modifier(SecondaryButtonTint())
  }
}

// Lê o accent do ambiente, que uma função de View sozinha não alcança.
private struct SecondaryButtonTint: ViewModifier {
  @Environment(\.hexPalette) private var palette

  func body(content: Content) -> some View {
    content.buttonStyle(.glass).tint(Color(palette.accent))
  }
}
