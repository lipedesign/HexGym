// O que as linhas dos Ajustes mostram e o que cada escolha faz, sem tela (Task 6 do plano da fase 2):
// as opções e os rótulos de cada linha, em português do Brasil e em inglês, e o caminho de cada
// escolha. Tudo o que é do documento vira uma ação do motor (SettingChange), que a tela manda pelo
// AppModel.perform; o tema fica no ThemeModel, no aparelho, e não gera ação nenhuma (seção 8.12).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o descanso de 30 s a 5 min, de 15 em
// 15 s, com o valor do documento como mais uma opção quando ele está fora da lista; o rótulo m:ss,
// como o anel de descanso, e "1 min 30 s" no VoiceOver.

import Foundation
import HexDesign
import HexEngine

// A escala de esforço do documento: nenhuma, RIR ou RPE (o effortOf do openGym).
enum EffortChoice: String, CaseIterable, Sendable { case none, rir, rpe }

// O primeiro dia da semana, como o getDay(): 0 é o domingo e 1, a segunda.
enum WeekStart: Int, CaseIterable, Sendable { case sunday = 0, monday = 1 }

// O corpo do mapa dos músculos.
enum BodyChoice: String, CaseIterable, Sendable { case male, female }

// Uma escolha feita numa linha dos Ajustes.
enum SettingsChoice: Equatable, Sendable {
  case unit(WeightUnit), rest(Int), effort(EffortChoice), weekStart(WeekStart), body(BodyChoice), theme(HexTheme)
}

struct SettingsRows {
  let locale: Locale

  // De 30 s a 5 min, de 15 em 15 s.
  static let restSteps = Array(stride(from: 30, through: 300, by: 15))

  // As opções do descanso: os passos e, quando o valor do documento não é um deles (um documento do
  // openGym pode ter de 0, sem descanso, a 15 min, e fora do passo de 15 s), ele também, na ordem.
  static func restOptions(current: Int) -> [Int] {
    restSteps.contains(current) ? restSteps : (restSteps + [current]).sorted()
  }

  // O caminho de uma escolha: o tema vai para o ThemeModel e volta nil, sem ação no motor; o resto
  // volta como a ação que a tela manda pelo AppModel.perform.
  @MainActor static func change(for choice: SettingsChoice, theme: ThemeModel) -> SettingChange? {
    switch choice {
    case .unit(let unit): return .unit(unit.rawValue)
    case .rest(let seconds): return .restSec(seconds)
    case .effort(let effort): return .effort(effort.rawValue)
    case .weekStart(let day): return .weekStart(day.rawValue)
    case .body(let body): return .body(body.rawValue)
    case .theme(let next):
      theme.theme = next
      return nil
    }
  }

  // O descanso na linha: m:ss, como o anel de descanso, e "Desligado" no 0.
  func rest(_ seconds: Int) -> String {
    seconds <= 0 ? text("Off") : RestRingModel.time(seconds)
  }

  // O descanso que o VoiceOver diz: "1 min 30 s", "45 s", "5 min".
  func spokenRest(_ seconds: Int) -> String {
    guard seconds > 0 else { return text("Off") }
    let (minutes, rest) = (seconds / 60, seconds % 60)
    switch (minutes, rest) {
    case (0, _): return format("%lld s", rest)
    case (_, 0): return format("%lld min", minutes)
    default: return format("%lld min %lld s", minutes, rest)
    }
  }

  func unit(_ unit: WeightUnit) -> String {
    text(unit == .kg ? "Kilograms (kg)" : "Pounds (lb)")
  }

  // RIR e RPE são as siglas, iguais nos dois idiomas.
  func effort(_ effort: EffortChoice) -> String {
    effort == .none ? text("None") : effort.rawValue.uppercased()
  }

  func weekStart(_ day: WeekStart) -> String {
    text(day == .sunday ? "Sunday" : "Monday")
  }

  func body(_ body: BodyChoice) -> String {
    text(body == .male ? "Male" : "Female")
  }

  // A versão do app e o build: "0.1.0 (1)".
  static func version(_ info: [String: Any]? = Bundle.main.infoDictionary) -> String {
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }

  private func text(_ key: String) -> String { AppText.text(key, locale: locale) }

  private func format(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: text(key), locale: locale, arguments: arguments)
  }
}

// Os valores que a tela dos Ajustes mostra, lidos do documento pelo engine.settings() e trocados na
// hora a cada escolha, antes da ação voltar do motor (o toque reflete em menos de 100 ms).
struct SettingsValues: Equatable, Sendable {
  var unit: WeightUnit
  var restSec: Int
  var effort: EffortChoice
  var weekStart: WeekStart
  var body: BodyChoice

  init(_ settings: DocumentSettings) {
    unit = settings.unit == "lb" ? .lb : .kg
    restSec = settings.restSec
    effort = settings.effort.flatMap(EffortChoice.init(rawValue:)) ?? .none
    weekStart = WeekStart(rawValue: settings.weekStart) ?? .monday
    body = settings.body == "female" ? .female : .male
  }

  // O tema não está aqui: ele fica no ThemeModel.
  mutating func apply(_ choice: SettingsChoice) {
    switch choice {
    case .unit(let value): unit = value
    case .rest(let value): restSec = value
    case .effort(let value): effort = value
    case .weekStart(let value): weekStart = value
    case .body(let value): body = value
    case .theme: break
    }
  }
}

// Os textos do catálogo do app (Localizable.xcstrings) num idioma pedido: português de qualquer
// região lê o pt-BR.lproj, e o resto fica no inglês, que é a própria chave, como o HexStrings do
// HexDesign. As telas passam o @Environment(\.locale), e os testes, o idioma que querem. As chaves
// lidas só por aqui ficam no catálogo como "manual", porque o Xcode não as acha no código.
enum AppText {
  static func text(_ key: String, locale: Locale) -> String {
    guard locale.language.languageCode == .portuguese else { return key }
    return portuguese.localizedString(forKey: key, value: key, table: nil)
  }

  private static let portuguese: Bundle =
    Bundle.main.path(forResource: "pt-BR", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
}
