// O tema escolhido fica no aparelho (seção 8.12 do design doc): nos UserDefaults do App Group, na
// chave hexgym.theme, e nunca no documento compartilhado. O ThemeModel é o que as views observam para
// trocar o tema ao vivo (seção 6).

import Foundation
import Observation

public struct ThemeStore {
  public static let key = "hexgym.theme"
  public static let appGroup = "group.app.hexgym"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  // Os UserDefaults do App Group, que o app, o Watch e os widgets dividem; sem eles, os padrão.
  public static func appGroupStore() -> ThemeStore {
    ThemeStore(defaults: UserDefaults(suiteName: appGroup) ?? .standard)
  }

  // O tema guardado. Um aparelho novo, um valor que não é texto ou um nome que não se reconhece
  // começam no Ultravioleta.
  public func load() -> HexTheme {
    guard let raw = defaults.object(forKey: Self.key) as? String, let theme = HexTheme(rawValue: raw) else { return .standard }
    return theme
  }

  // Grava o rawValue do tema.
  public func save(_ theme: HexTheme) {
    defaults.set(theme.rawValue, forKey: Self.key)
  }
}

@Observable @MainActor public final class ThemeModel {
  // O tema do aparelho. Ao mudar, vai para o store.
  public var theme: HexTheme {
    didSet { if theme != oldValue { store.save(theme) } }
  }

  // A prévia de alto contraste da galeria. Fica só na memória: não é gravada.
  public var contrastPreview = false

  @ObservationIgnored private let store: ThemeStore

  public init(store: ThemeStore) {
    self.store = store
    theme = store.load()
  }
}
