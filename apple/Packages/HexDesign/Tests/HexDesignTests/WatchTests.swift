// Os testes do design system no Watch (Task 11 do plano da fase 1): a Coroa Digital dá um passo por
// dente cruzado, e o botão principal do Watch é o compacto, de 44 pt.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter WatchTests
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o botão compacto de 44 pt e um passo por
// dente da Coroa Digital.

import Testing
@testable import HexDesign

@Test func eachCrownDetentIsOneStep() {
  #expect(CrownSteps.steps(from: 0, to: 3) == [.up, .up, .up]); #expect(CrownSteps.steps(from: 3, to: 2) == [.down])
  #expect(CrownSteps.steps(from: 0, to: 0.4) == []); #expect(CrownSteps.steps(from: 0.4, to: 1.2) == [.up])
  #expect(CrownSteps.steps(from: 1.2, to: -0.6) == [.down, .down])
}
@Test func theWatchButtonIsCompact() { #expect(HexPrimaryButtonStyle.Size.compact.minHeight == 44) }
