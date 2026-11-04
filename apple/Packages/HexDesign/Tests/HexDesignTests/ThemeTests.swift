// Os testes do tema do HexDesign (seção 8.12 do design doc): a escolha guardada no aparelho, na chave
// hexgym.theme, o modelo da troca ao vivo, a paleta do ambiente (Foco da revisão 4) e os nomes dos
// temas nas duas línguas.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter ThemeTests
//
// O colorSchemeContrast do ambiente é só de leitura e não dá para mudar no teste: o caminho dele fica
// para a galeria, no simulador (Task 10), e a prévia prova a mesma troca.

import Foundation
import SwiftUI
import Testing
@testable import HexDesign

// O Swift Testing cria a suíte de novo para cada teste e solta no fim: cada teste tem o próprio domínio
// dos UserDefaults, e o deinit apaga esse domínio, passe ou falhe o teste. A suíte é ~Copyable porque
// só assim uma struct tem deinit.
@Suite struct ThemeTests: ~Copyable {
  // Um caminho absoluto no temporário, e não um nome solto: o cfprefsd grava um plist vazio do domínio
  // depois do fim do processo, e no temporário quem limpa é o sistema, longe de Library/Preferences.
  private let suite = FileManager.default.temporaryDirectory.appendingPathComponent("hexdesign-\(UUID().uuidString)").path

  // Os UserDefaults só deste teste, que começam vazios.
  func fresh() -> UserDefaults {
    UserDefaults(suiteName: suite)!
  }

  // Apaga as chaves do domínio.
  deinit {
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
  }

  @Test func aFreshDeviceStartsOnUltraviolet() { #expect(ThemeStore(defaults: fresh()).load() == .ultraviolet) }
  @Test func aSavedThemeComesBack() {
    let d = fresh(); ThemeStore(defaults: d).save(.copper)
    #expect(ThemeStore(defaults: d).load() == .copper); #expect(d.string(forKey: ThemeStore.key) == "copper")
  }
  @Test func anUnknownOrBrokenValueFallsBackToUltraviolet() {
    let d = fresh()
    d.set("aurora", forKey: ThemeStore.key); #expect(ThemeStore(defaults: d).load() == .ultraviolet)
    d.set(42, forKey: ThemeStore.key); #expect(ThemeStore(defaults: d).load() == .ultraviolet)
  }
  @MainActor @Test func changingTheModelSavesAndKeepsThePreviewOut() {
    let d = fresh(), model = ThemeModel(store: ThemeStore(defaults: d))
    model.theme = .cyan; model.contrastPreview = true
    #expect(d.string(forKey: ThemeStore.key) == "cyan")
    #expect(d.dictionaryRepresentation().keys.filter { $0.hasPrefix("hexgym.") } == ["hexgym.theme"])
  }
  @Test func thePaletteFollowsTheEnvironment() {                            // Foco da revisão 4
    var env = EnvironmentValues(); env.colorScheme = .dark; env.hexTheme = .ultraviolet
    #expect(env.hexPalette.fill == HexRGB(0x6F5CFF))
    env.hexContrastPreview = true; #expect(env.hexPalette.fill == HexRGB(0x8A88FF))
    env.colorScheme = .light; #expect(env.hexPalette.fill == HexRGB(0x5339DB))
  }
  @Test func themeNamesInBothLanguages() {
    #expect(HexTheme.allCases.map { $0.displayName(locale: br) } == ["Ultravioleta", "Giz & Ferro", "Ciano Glacial", "Cobre Forjado"])
    #expect(HexTheme.allCases.map { $0.displayName(locale: en) } == ["Ultraviolet", "Chalk & Iron", "Glacial Cyan", "Forged Copper"])
  }
}
