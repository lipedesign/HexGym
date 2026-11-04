// O Dynamic Type de verdade, que só existe no simulador (Foco da revisão, item 2): no Mac, o
// @ScaledMetric dá o mesmo valor em todo tamanho de texto, e por isso estes testes moram no app. Cada
// um desenha Text("142,5").hexFont(style) com o ImageRenderer, no tamanho de texto e no peso de
// legibilidade pedidos, e compara a altura ou a largura da imagem.
//
// O alvo roda dentro do app (TEST_HOST) e vê o HexDesign pelo app, sem uma segunda cópia dele.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import HexDesign
import SwiftUI
import Testing

@Suite @MainActor struct DynamicTypeTests {
  // O tamanho, em pontos, do número desenhado no estilo, no tamanho de texto e, com bold, com o Texto
  // em Negrito. Um ImageRenderer novo a cada medida: um renderer reaproveitado não desenha de novo
  // depois de trocar o ambiente (QA da PR #75).
  func measure(_ style: HexTextStyle, _ size: DynamicTypeSize, bold: Bool = false) -> CGSize {
    let view = Text("142,5").hexFont(style).fixedSize()
      .environment(\.dynamicTypeSize, size)
      .environment(\.legibilityWeight, bold ? .bold : .regular)
    guard let image = ImageRenderer(content: view).cgImage else {
      Issue.record("o ImageRenderer não desenhou \(style) em \(size)")
      return .zero
    }
    return CGSize(width: image.width, height: image.height)
  }

  @Test func displayGrowsUpToItsCap() {                                     // Foco da revisão 2
    let cap = ImageRenderer(content: Text("142,5").font(Font(HexFonts.font(.extraBold, size: 132, tabularDigits: true))).fixedSize()).cgImage!.height
    #expect(measure(.display, .accessibility5).height > measure(.display, .large).height)
    #expect(measure(.display, .accessibility5).height <= CGFloat(cap) + 1)
  }

  @Test func headlinesKeepGrowing() {                                       // Foco da revisão 2
    #expect(measure(.headline, .accessibility5).height > 1.5 * measure(.headline, .large).height)
  }

  @Test func boldTextIsWider() {                                            // Foco da revisão 2
    #expect(measure(.headline, .large, bold: true).width > measure(.headline, .large).width)
  }
}
