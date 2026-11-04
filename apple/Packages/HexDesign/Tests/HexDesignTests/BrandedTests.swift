// Os testes dos componentes da Apple com a marca (seção 6 do design doc e o Foco da revisão, item 4):
// com Aumentar Contraste o vidro fica sem tinta, e com Reduzir Movimento o zoom sai e a tela do
// treino aparece sem se mover. Os prints do vidro e da transição ficam para o simulador (Task 10).
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter BrandedTests

import SwiftUI
import Testing
@testable import HexDesign

@Test func theGlassTakesTheThemeUnlessContrastIsUp() {                    // Foco da revisão 4
  #expect(HexGlass.tintOpacity(contrast: .standard) == 0.18); #expect(HexGlass.tintOpacity(contrast: .increased) == nil)
}
@Test func theZoomStepsAsideForReduceMotion() {                           // Foco da revisão 4
  #expect(StartWorkoutTransition.usesZoom(reduceMotion: false)); #expect(!StartWorkoutTransition.usesZoom(reduceMotion: true))
}
@Test func theWorkoutScreenAppearsStillWithReduceMotion() {
  #expect(StartWorkoutTransition.transaction(reduceMotion: true).disablesAnimations)
  #expect(!StartWorkoutTransition.transaction(reduceMotion: false).disablesAnimations)
}
