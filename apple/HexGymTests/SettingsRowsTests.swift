// Os testes dos Ajustes sem tela (Task 6 do plano da fase 2): as opções do descanso, o rótulo dele
// e o que o VoiceOver diz, a troca de unidade por uma ação do motor e o tema, que fica no ThemeModel
// e não gera ação nenhuma (seção 8.12). Os rótulos são conferidos em português do Brasil e em inglês.
// O teste dos rótulos confere também os parágrafos dos textos das licenças, que a linha "Licenças"
// abre (LicenseParagraphs), nos três arquivos que vão no app.
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexDesign
import HexEngine
import Testing
@testable import HexGym

@Suite @MainActor struct SettingsRowsTests {
  let portuguese = SettingsRows(locale: Locale(identifier: "pt-BR"))
  let english = SettingsRows(locale: Locale(identifier: "en-US"))
  // De 30 s a 5 min, de 15 em 15 s.
  let steps = Array(stride(from: 30, through: 300, by: 15))

  // Um ThemeModel com UserDefaults só do teste, para não mexer no tema do simulador.
  func themeModel(_ name: String) -> (ThemeModel, UserDefaults) {
    let suite = "settings-rows-\(name)-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (ThemeModel(store: ThemeStore(defaults: defaults)), defaults)
  }

  @Test func restOptionsRunFrom30To300AndKeepTheDocumentValue() {
    #expect(steps.count == 19)
    #expect(SettingsRows.restOptions(current: 90) == steps)
    // Um documento do openGym com 7 min ganha a opção, no lugar dela na ordem.
    #expect(SettingsRows.restOptions(current: 420) == steps + [420])
    // Fora do passo de 15 s, e o 0 do openGym (sem descanso).
    #expect(SettingsRows.restOptions(current: 100) == [30, 45, 60, 75, 90, 100] + steps.dropFirst(5))
    #expect(SettingsRows.restOptions(current: 0) == [0] + steps)
  }

  @Test func theRestReadsAsMinutesAndSecondsAndVoiceOverSaysTheUnits() {
    #expect(portuguese.rest(90) == "1:30")
    #expect(english.rest(90) == "1:30")
    #expect(portuguese.spokenRest(90) == "1 min 30 s")
    #expect(english.spokenRest(90) == "1 min 30 s")
    #expect(portuguese.rest(45) == "0:45"); #expect(portuguese.spokenRest(45) == "45 s")
    #expect(portuguese.rest(300) == "5:00"); #expect(portuguese.spokenRest(300) == "5 min")
    #expect(portuguese.rest(420) == "7:00")
    #expect(portuguese.rest(0) == "Desligado"); #expect(english.rest(0) == "Off")
    #expect(portuguese.spokenRest(0) == "Desligado")
  }

  @Test func theUnitChangesToPoundsThroughAnEngineAction() {
    let (theme, _) = themeModel("unit")
    #expect(SettingsRows.change(for: .unit(.lb), theme: theme) == .unit("lb"))
    #expect(SettingsRows.change(for: .unit(.kg), theme: theme) == .unit("kg"))
    // Os outros ajustes do documento, cada um na ação dele.
    #expect(SettingsRows.change(for: .rest(420), theme: theme) == .restSec(420))
    #expect(SettingsRows.change(for: .effort(.rpe), theme: theme) == .effort("rpe"))
    #expect(SettingsRows.change(for: .weekStart(.sunday), theme: theme) == .weekStart(0))
    #expect(SettingsRows.change(for: .body(.female), theme: theme) == .body("female"))
    #expect(theme.theme == .ultraviolet)
    #expect(portuguese.unit(.kg) == "Quilos (kg)"); #expect(portuguese.unit(.lb) == "Libras (lb)")
    #expect(english.unit(.kg) == "Kilograms (kg)"); #expect(english.unit(.lb) == "Pounds (lb)")
    #expect(portuguese.effort(.none) == "Nenhuma"); #expect(english.effort(.none) == "None")
    #expect(portuguese.effort(.rir) == "RIR"); #expect(english.effort(.rpe) == "RPE")
    #expect(portuguese.weekStart(.sunday) == "Domingo"); #expect(english.weekStart(.monday) == "Monday")
    #expect(portuguese.body(.female) == "Feminino"); #expect(english.body(.male) == "Male")
    // A linha "Licenças" do Sobre abre os textos das licenças, em parágrafos (LicenseParagraphs): o
    // título de uma seção fica sozinho, e um aviso de garantia em maiúsculas fica inteiro.
    #expect(LicenseParagraphs.split("PREAMBLE\nThe goals of\nthe OFL.\n\nPERMISSION & CONDITIONS\nPermission is\ngranted.\n")
      == ["PREAMBLE", "The goals of the OFL.", "PERMISSION & CONDITIONS", "Permission is granted."])
    #expect(LicenseParagraphs.split("THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED.\n")
      == ["THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED."])
    let ofl = LicenseText(title: "Barlow Condensed", source: .url(HexFonts.licenseURL)).paragraphs()
    #expect(["PREAMBLE", "DEFINITIONS", "PERMISSION & CONDITIONS", "TERMINATION", "DISCLAIMER"].allSatisfy(ofl.contains))
    let mit = LicenseText(title: "MuscleMap", source: .bundle("LICENSE-MuscleMap")).paragraphs()
    #expect(mit.count == 5); #expect(mit.first == "MIT License"); #expect(mit.last?.hasPrefix("THE SOFTWARE IS PROVIDED") == true)
    let agpl = LicenseText(title: "openGym", source: .bundle("LICENSE-openGym")).paragraphs()
    #expect(Array(agpl.prefix(2)) == ["GNU AFFERO GENERAL PUBLIC LICENSE", "Version 3, 19 November 2007"])
    #expect(agpl.contains("TERMS AND CONDITIONS")); #expect(agpl.contains("END OF TERMS AND CONDITIONS"))
  }

  @Test func changingTheThemeMakesNoEngineAction() {
    let (theme, defaults) = themeModel("theme")
    #expect(SettingsRows.change(for: .theme(.copper), theme: theme) == nil)
    #expect(theme.theme == .copper)
    #expect(defaults.string(forKey: ThemeStore.key) == "copper")
  }
}
