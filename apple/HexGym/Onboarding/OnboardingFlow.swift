// A primeira abertura sem tela (Task 7 do plano da fase 2): os três passos, unidade, tema e corpo, o
// passo atual, o "Continuar" (next) e o "Pular" (skip), e o que vai para o documento no fim. A tela
// (OnboardingView) só mostra e manda os toques para cá.
//
// Ela aparece quando o documento foi criado agora ou quando este aparelho nunca a viu (shouldShow). A
// marca de que o aparelho já viu fica no aparelho, nos UserDefaults do App Group, na chave
// hexgym.onboarded, e nunca no documento, como o tema (seção 8.12). A unidade e o corpo vão para o
// documento no fim, numa ação do motor cada, e só se mudaram; o tema vai pelo ThemeModel, na hora, e
// nunca para o documento.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a escolha 2 do plano (os três passos com
// "Pular" em cada um e os padrões, kg e masculino, do DEF do openGym, e o Ultravioleta) e o "Pular" que
// fica com o valor de antes do passo: num documento novo, o padrão; num documento que veio de outro
// aparelho, o que ele já tem.

import Foundation
import HexDesign
import HexEngine

struct OnboardingFlow: Equatable, Sendable {
  enum Step: Int, CaseIterable, Sendable {
    case unit = 1, theme, body
  }

  private(set) var step = Step.unit
  // O "Começar" ou o "Pular" do último passo já foram tocados.
  private(set) var isFinished = false

  // O que está marcado agora em cada passo.
  var unit: WeightUnit
  var theme: HexTheme
  var body: BodyChoice

  // O que estava marcado quando a primeira abertura começou: o "Pular" volta a isso, e o fim só grava o
  // que ficou diferente.
  private let startUnit: WeightUnit
  private let startTheme: HexTheme
  private let startBody: BodyChoice

  // Os padrões: kg e masculino, do DEF do openGym, e o tema padrão do HexGym.
  init(unit: WeightUnit = .kg, theme: HexTheme = .standard, body: BodyChoice = .male) {
    self.unit = unit
    self.theme = theme
    self.body = body
    startUnit = unit
    startTheme = theme
    startBody = body
  }

  // A unidade e o corpo do documento (engine.settings()), e o tema do aparelho.
  init(settings: DocumentSettings, theme: HexTheme) {
    let values = SettingsValues(settings)
    self.init(unit: values.unit, theme: theme, body: values.body)
  }

  // Mostra quando o documento foi criado agora, ou quando este aparelho nunca viu a primeira abertura
  // (um aparelho novo com um documento que veio do backup ainda escolhe o tema).
  static func shouldShow(origin: AppModel.Origin, seen: Bool) -> Bool {
    origin == .created || !seen
  }

  static let stepCount = Step.allCases.count

  var isLastStep: Bool { step == Step.allCases.last }

  // "Continuar", e "Começar" no último passo: fica com a escolha e avança.
  mutating func next() {
    guard !isFinished else { return }
    if let following = Step(rawValue: step.rawValue + 1) {
      step = following
    } else {
      isFinished = true
    }
  }

  // "Pular": o passo volta ao valor de antes e avança.
  mutating func skip() {
    guard !isFinished else { return }
    switch step {
    case .unit: unit = startUnit
    case .theme: theme = startTheme
    case .body: body = startBody
    }
    next()
  }

  // O que o fim grava no documento: a unidade e o corpo, nessa ordem, só os que mudaram. O tema não
  // está aqui: ele fica no ThemeModel.
  var changes: [SettingChange] {
    var changes: [SettingChange] = []
    if unit != startUnit { changes.append(.unit(unit.rawValue)) }
    if body != startBody { changes.append(.body(body.rawValue)) }
    return changes
  }

  // Grava o que mudou, uma ação por vez, pelo AppModel.perform; o primeiro erro para e volta.
  @MainActor func save(using model: AppModel) async throws {
    for change in changes {
      _ = try await model.perform(.setSetting(change))
    }
  }
}

// A marca de que este aparelho já viu a primeira abertura: true na chave hexgym.onboarded dos
// UserDefaults do App Group, que o app, o Watch e os widgets dividem, como o tema.
struct OnboardingMark {
  static let key = "hexgym.onboarded"

  private let defaults: UserDefaults

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  // Os UserDefaults do App Group; sem eles, os padrão, como o ThemeStore.
  static func appGroup() -> OnboardingMark {
    OnboardingMark(defaults: UserDefaults(suiteName: ThemeStore.appGroup) ?? .standard)
  }

  var seen: Bool { defaults.bool(forKey: Self.key) }

  func markSeen() {
    defaults.set(true, forKey: Self.key)
  }
}

// Os argumentos de início da primeira abertura, para os prints e os testes de interface, do domínio dos
// argumentos dos UserDefaults padrão (xcrun simctl launch ... -HexGymSkipOnboarding YES), que não fica
// gravado:
//   -HexGymOnboarding YES          mostra a primeira abertura, mesmo num aparelho que já viu
//   -HexGymSkipOnboarding YES      nunca mostra, e ganha do -HexGymOnboarding
//   -HexGymOnboardingStep theme    com ela aberta, começa num passo (theme ou body)
//   -HexGymOnboardingScript demo   o roteiro do vídeo do PR: o caminho inteiro, com os toques dele
enum OnboardingLaunch {
  static func shouldShow(origin: AppModel.Origin, seen: Bool, launch: UserDefaults = .standard) -> Bool {
    if launch.bool(forKey: "HexGymSkipOnboarding") { return false }
    if launch.bool(forKey: "HexGymOnboarding") { return true }
    return OnboardingFlow.shouldShow(origin: origin, seen: seen)
  }

  static var step: OnboardingFlow.Step? {
    switch UserDefaults.standard.string(forKey: "HexGymOnboardingStep") {
    case "theme": .theme
    case "body": .body
    default: nil
    }
  }

  static var script: String? { UserDefaults.standard.string(forKey: "HexGymOnboardingScript") }
}

// Os textos da primeira abertura que a tela lê como texto pronto, no idioma pedido, como o SettingsRows.
struct OnboardingText {
  let locale: Locale

  // O que o VoiceOver diz no topo de cada passo: "Passo 1 de 3".
  func position(_ step: OnboardingFlow.Step) -> String {
    String(format: AppText.text("Step %lld of %lld", locale: locale), locale: locale, step.rawValue, OnboardingFlow.stepCount)
  }
}
