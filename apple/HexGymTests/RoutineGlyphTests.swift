// Os testes do ícone da rotina (Task 11 do plano da fase 2, issue #98, escolha 9): os três do passo 1
// do plano. Todo glyph que o seletor do openGym oferece e todo glyph antigo tem o SF Symbol da tabela do
// plano, e cada símbolo existe no simulador (UIImage(systemName:)); um emoji antigo segue o mapa LEGACY
// do glyphOf do openGym, com o mesmo corte do seletor de variação; e só um desconhecido cai no ícone
// padrão.
//
// O alvo roda dentro do app (TEST_HOST).
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Testing
import UIKit
@testable import HexGym

@Suite @MainActor struct RoutineGlyphTests {
  // A tabela da Task 11 do plano, copiada aqui de propósito: o teste não lê a tabela do app.
  static let pickable: [(glyph: String, symbol: String)] = [
    ("figureStrength", "figure.strengthtraining.traditional"), ("arm", "figure.arms.open"), ("abs", "figure.core.training"),
    ("legs", "figure.step.training"), ("pullup", "figure.climbing"),
    ("dumbbell", "dumbbell"), ("barbell", "figure.strengthtraining.functional"), ("kettlebell", "scalemass"),
    ("plate", "circle.circle"), ("machine", "gearshape.2"),
    ("figureRun", "figure.run"), ("bike", "figure.outdoor.cycle"), ("swim", "figure.pool.swim"), ("boxing", "figure.boxing"),
    ("timer", "timer"),
    ("stretch", "figure.flexibility"), ("moon", "moon"), ("heart", "heart"), ("flame", "flame"), ("bolt", "bolt"),
  ]
  static let legacy: [(glyph: String, symbol: String)] = [
    ("trophy", "trophy"), ("medal", "medal"), ("crown", "crown"), ("flag", "flag"), ("star", "star"), ("target", "target"),
    ("shield", "shield"),
  ]
  static let defaultSymbol = "figure.strengthtraining.traditional"

  @Test func everyGlyphHasASymbolThatExists() {
    // Os 20 do seletor, na ordem do GLYPHS do openGym (lib/glyphs.js), que é a do ROUTINE_GLYPHS do motor.
    #expect(RoutineGlyph.groups.flatMap(\.glyphs) == Self.pickable.map(\.glyph))
    for (glyph, symbol) in Self.pickable + Self.legacy {
      #expect(RoutineGlyph.symbol(for: glyph) == symbol, "o símbolo do \(glyph)")
      #expect(UIImage(systemName: symbol) != nil, "o SF Symbol \(symbol) existe")
      // Cada um tem nome para o VoiceOver e o menu, nos dois idiomas, e o nome não é a chave.
      for locale in [Locale(identifier: "pt-BR"), Locale(identifier: "en")] {
        let name = RoutineGlyph.name(of: glyph, locale: locale)
        #expect(!name.isEmpty && name != glyph, "o nome do \(glyph) em \(locale.identifier)")
      }
    }
  }

  @Test func anOldEmojiFollowsTheOpenGymMap() {
    let arm = "figure.arms.open"
    #expect(RoutineGlyph.key(for: "💪") == "arm")
    #expect(RoutineGlyph.symbol(for: "💪") == arm)
    // Com um tom de pele, o mapa não acha, e o glyphOf tenta de novo com o primeiro caractere.
    #expect(RoutineGlyph.symbol(for: "💪🏽") == arm)
    // Com e sem o seletor de variação, e com o ZWJ.
    #expect(RoutineGlyph.key(for: "🏋️") == "dumbbell")
    #expect(RoutineGlyph.key(for: "🏋") == "dumbbell")
    #expect(RoutineGlyph.key(for: "🏋️‍♂️") == "dumbbell")
    #expect(RoutineGlyph.key(for: "🦵") == "legs")
    #expect(RoutineGlyph.key(for: "🏆") == "trophy")
    #expect(RoutineGlyph.symbol(for: "🏆") == "trophy")
  }

  @Test func onlyAnUnknownGlyphFallsBackToTheDefault() {
    for unknown in ["", "nao-existe", "🐙", "Peito"] {
      #expect(RoutineGlyph.key(for: unknown) == "figureStrength", "\(unknown)")
      #expect(RoutineGlyph.symbol(for: unknown) == Self.defaultSymbol, "\(unknown)")
    }
    // Um glyph conhecido nunca cai no padrão, nem o que tem o mesmo símbolo dele.
    #expect(RoutineGlyph.key(for: "moon") == "moon")
  }
}
