// A marca provisória do HexGym, em todos os alvos do app: HEX em peso heavy e largura condensada,
// seguido de gym em peso thin, branco, com a fonte do sistema. A marca de verdade, com a Barlow do
// HexDesign, entra na fase 1. Para o VoiceOver, ela é uma palavra só: HexGym.
import SwiftUI

struct Wordmark: View {
  // O tamanho cresce com o texto grande do sistema, a partir do tamanho pedido.
  @ScaledMetric private var size: CGFloat

  init(size: CGFloat = 48) {
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      Text(verbatim: "HEX").font(.system(size: size, weight: .heavy)).fontWidth(.condensed)
      Text(verbatim: "gym").font(.system(size: size, weight: .thin))
    }
    .foregroundStyle(.white)
    .lineLimit(1)
    .minimumScaleFactor(0.5)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("HexGym")
  }
}
