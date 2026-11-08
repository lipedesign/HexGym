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
// Achado no QA da PR #86 (#121): com o floor, um toque mínimo para baixo que voltava ao dente dava -1 e
// depois +1, e o mesmo toque para cima não dava nada. Com o arredondamento, o toque mínimo e a volta não
// dão passo nenhum, nos dois sentidos, e meio dente é a fronteira de um passo.
@Test func aNudgeThatComesBackIsNoStep() {
  for path in [[3, 2.99, 3], [3, 3.01, 3], [0, -0.01, 0], [0, 0.01, 0], [-2, -2.01, -2], [-2, -1.99, -2]] {
    #expect(zip(path, path.dropFirst()).flatMap { CrownSteps.steps(from: $0, to: $1) } == [], "\(path)")
  }
  #expect(zip([3, 2.6, 2.4, 2.0], [2.6, 2.4, 2.0]).flatMap { CrownSteps.steps(from: $0, to: $1) } == [.down])
  #expect(zip([3, 3.4, 3.6, 4.0], [3.4, 3.6, 4.0]).flatMap { CrownSteps.steps(from: $0, to: $1) } == [.up])
}
@Test func theWatchButtonIsCompact() { #expect(HexPrimaryButtonStyle.Size.compact.minHeight == 44) }
