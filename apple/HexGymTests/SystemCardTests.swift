// O cartão do sistema (QA da PR #70 e a #71): o HexDesign testa o contraste do texto na cor do tema
// contra dois cinzas escritos à mão, o HexRGB.card e o HexRGB.cardIncreased. Aqui, no simulador, o
// secondarySystemBackground do iOS, resolvido no escuro, precisa dar esses mesmos dois cinzas: sem e
// com Aumentar Contraste. Cada componente é arredondado para 8 bits antes de comparar.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import HexDesign
import Testing
import UIKit

@Suite @MainActor struct SystemCardTests {
  // O secondarySystemBackground no escuro, no contraste pedido, como 0xRRGGBB em sRGB.
  func card(_ contrast: UIAccessibilityContrast) -> HexRGB? {
    let traits = UITraitCollection { traits in
      traits.userInterfaceStyle = .dark
      traits.accessibilityContrast = contrast
      traits.userInterfaceLevel = .base
    }
    let color = UIColor.secondarySystemBackground.resolvedColor(with: traits)
    var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), alpha == 1 else { return nil }
    let byte = { (component: CGFloat) in UInt32((component * 255).rounded()) }
    return HexRGB(byte(red) << 16 | byte(green) << 8 | byte(blue))
  }

  @Test func theSystemCardIsTheOneTheColorsAreTestedOn() {
    #expect(card(.normal) == HexRGB.card)                       // #1C1C1E
    #expect(card(.high) == HexRGB.cardIncreased)                // #242426, a #71
  }
}
