// O logotipo do HexGym (seção 6 do design doc): HEX na Barlow Condensed pesada, seguido de gym fino,
// em branco.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o gym no peso 200.

import SwiftUI

public struct HexWordmark: View {
  private let size: CGFloat

  // O tamanho das duas partes, em pontos. O logotipo não segue o Dynamic Type.
  public init(size: CGFloat = 44) {
    self.size = size
  }

  // HEX no peso 800 e gym no 200, do mesmo tamanho e alinhados pela linha de base, com 0,06 do
  // tamanho entre os dois. O VoiceOver lê um elemento só, "HexGym", escrito sem passar pela tradução,
  // por ser o nome da marca (QA da PR #73).
  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0.06 * size) {
      Text(verbatim: "HEX").font(Font(HexFonts.font(.extraBold, size: size, tabularDigits: false)))
      Text(verbatim: "gym").font(Font(HexFonts.font(.extraLight, size: size, tabularDigits: false)))
    }
    .foregroundStyle(Color.white)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "HexGym"))
  }
}
