// O tema no ambiente do SwiftUI: as chaves do tema e da prévia de alto contraste, a paleta que sai
// delas e do aparelho (o esquema, o Aumentar Contraste e a superfície), e os textos do pacote em
// português do Brasil e em inglês.
//
// As chaves são EnvironmentKey escritas à mão: as Command Line Tools não têm o macro @Entry.

import Foundation
import SwiftUI

private struct HexThemeKey: EnvironmentKey {
  static let defaultValue: HexTheme = .standard
}

private struct HexContrastPreviewKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  // O tema do aparelho.
  public var hexTheme: HexTheme {
    get { self[HexThemeKey.self] }
    set { self[HexThemeKey.self] = newValue }
  }

  // A prévia de alto contraste da galeria: troca as cores como o Aumentar Contraste.
  public var hexContrastPreview: Bool {
    get { self[HexContrastPreviewKey.self] }
    set { self[HexContrastPreviewKey.self] = newValue }
  }

  // A paleta do ambiente: o tema no esquema do aparelho, com as cores de alto contraste quando o
  // Aumentar Contraste está ligado ou a prévia está ligada, e o accent do Watch no watchOS.
  public var hexPalette: HexPalette {
    let increased = colorSchemeContrast == .increased || hexContrastPreview
    #if os(watchOS)
    let surface = HexSurface.watch
    #else
    let surface = HexSurface.app
    #endif
    return HexPalette.resolve(hexTheme, scheme: colorScheme, contrast: increased ? .increased : .standard, surface: surface)
  }
}

extension View {
  // Põe o tema e a prévia do modelo no ambiente. A view que chama observa o modelo, então a troca
  // aparece na hora.
  public func hexTheme(_ model: ThemeModel) -> some View {
    environment(\.hexTheme, model.theme).environment(\.hexContrastPreview, model.contrastPreview)
  }
}

extension HexTheme {
  // O nome do tema no idioma pedido (a tabela Theme).
  public func displayName(locale: Locale = .current) -> String {
    HexStrings.text(rawValue, table: "Theme", locale: locale)
  }
}

// Os textos do pacote no idioma pedido, das tabelas em Resources/Strings: português de qualquer região
// lê o pt-BR.lproj, e o resto lê o en.lproj. As views passam o @Environment(\.locale), e os testes, o
// idioma que querem. Os plurais vêm do .stringsdict da mesma tabela, pelo format.
enum HexStrings {
  static func text(_ key: String, table: String, locale: Locale) -> String {
    bundle(for: locale).localizedString(forKey: key, value: nil, table: table)
  }

  // O texto como formato, com os números escritos no jeito do idioma. Com um .stringsdict na tabela,
  // o texto que volta já traz as regras de plural, e o String(format:) escolhe a forma pelo número.
  // Quando a tabela é a do en.lproj, o plural segue as regras do inglês: o formato usa o inglês na
  // região do usuário, e não o idioma dele (no japonês, o 1 cairia na forma other).
  static func format(_ key: String, table: String, locale: Locale, _ arguments: CVarArg...) -> String {
    let rules = isPortuguese(locale) ? locale : Locale(languageCode: .english, languageRegion: locale.region)
    return String(format: text(key, table: table, locale: locale), locale: rules, arguments: arguments)
  }

  private static func isPortuguese(_ locale: Locale) -> Bool {
    locale.language.languageCode == .portuguese
  }

  // A pasta .lproj do idioma, como um bundle, aberta uma vez só. Sem ela, o bundle do pacote.
  private static func bundle(for locale: Locale) -> Bundle {
    isPortuguese(locale) ? portuguese : english
  }

  private static let portuguese = localization("pt-BR")
  private static let english = localization("en")

  private static func localization(_ name: String) -> Bundle {
    Bundle.module.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
  }
}
