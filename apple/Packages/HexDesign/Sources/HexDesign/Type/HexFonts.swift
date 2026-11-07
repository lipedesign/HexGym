// A Barlow Condensed do HexGym (decisão 1 de 03/11/2026, a tipografia final da seção 10 do design
// doc): os quatro pesos, registrados no processo a partir dos arquivos do pacote, e as fontes da marca
// em CoreText, com a reserva na SF Pro Compressed no cirílico e no grego. As outras escritas caem na
// fonte do sistema daquela escrita, pela cascata do próprio CoreText. Os arquivos vêm de um commit
// fixado do google/fonts, sob a SIL OFL 1.1 (Resources/Fonts/OFL.txt).
//
// A reserva é a fonte do sistema com largura compressed, pelo UIFont no iPhone e no Watch e pelo
// NSFont no Mac (que só existe para o swift test). As chamadas são as mesmas nos dois.

import CoreText
import Foundation
#if canImport(UIKit)
import UIKit
private typealias SystemFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias SystemFont = NSFont
#endif

public enum HexWeight: Int, CaseIterable, Sendable {
  case extraLight = 200, medium = 500, bold = 700, extraBold = 800

  // O nome PostScript do arquivo da Barlow Condensed nesse peso.
  public var postScriptName: String {
    switch self {
    case .extraLight: "BarlowCondensed-ExtraLight"
    case .medium: "BarlowCondensed-Medium"
    case .bold: "BarlowCondensed-Bold"
    case .extraBold: "BarlowCondensed-ExtraBold"
    }
  }

  // O peso de quem liga o Texto em Negrito: um acima, e o 800 fica no 800.
  public var boldText: HexWeight {
    switch self {
    case .extraLight: .medium
    case .medium: .bold
    case .bold, .extraBold: .extraBold
    }
  }

  // O peso da SF Pro Compressed na reserva, como o rawValue do peso do sistema: o 200 é o thin, o 500
  // é o medium, o 700 é o bold e o 800 é o heavy.
  var reserveWeight: CGFloat {
    switch self {
    case .extraLight: SystemFont.Weight.thin.rawValue
    case .medium: SystemFont.Weight.medium.rawValue
    case .bold: SystemFont.Weight.bold.rawValue
    case .extraBold: SystemFont.Weight.heavy.rawValue
    }
  }
}

public enum HexFonts {
  // Registra os quatro pesos no processo. Só a primeira chamada registra; as outras não fazem nada.
  public static func register() {
    _ = registration
  }

  // A fonte da marca no peso e no tamanho, com dígitos tabulares quando pedido. Registra as fontes na
  // primeira chamada e guarda as que já fez, porque o body das views pede a mesma fonte a cada mudança.
  public static func font(_ weight: HexWeight, size: CGFloat, tabularDigits: Bool) -> CTFont {
    register()
    return cache.font(FontKey(weight: weight, size: size, tabularDigits: tabularDigits))
  }

  // O texto da SIL OFL 1.1, que vai junto com a fonte. A tela de licenças do app o mostra daqui.
  public static var licenseURL: URL? {
    Bundle.module.url(forResource: "OFL", withExtension: "txt", subdirectory: "Fonts")
  }

  // O registro, feito uma vez só. No escopo do processo, o CTFontManagerRegisterFontURLs termina antes
  // de voltar, em qualquer thread. Os erros ficam sem tratamento de propósito: o "já registrada" (105)
  // não atrapalha, e um peso que não registrar sai noutra fonte, o que o teste
  // registersTheFourWeightsAndShipsTheLicense pega.
  private static let registration: Void = {
    let urls = HexWeight.allCases.compactMap { Bundle.module.url(forResource: $0.postScriptName, withExtension: "ttf", subdirectory: "Fonts") }
    CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
  }()

  private static let cache = FontCache()

  // A fonte de uma chave. O descritor leva o nome PostScript do peso, o conjunto de caracteres da
  // Barlow sem os blocos do grego e do cirílico, a cascata com a SF Pro Compressed no mesmo tamanho e
  // no peso de reserva e, com tabularDigits, o recurso OpenType tnum, porque os dígitos da Barlow são
  // proporcionais. O corte no conjunto de caracteres é preciso porque a Barlow, que não tem cirílico,
  // tem quatro letras gregas (Δ, Ω, μ e π, para a matemática): sem ele, o π de "πάγκου" sairia na
  // Barlow, no meio de uma palavra na SF Pro Compressed.
  fileprivate static func make(_ key: FontKey) -> CTFont {
    let barlow = CTFontCreateWithName(key.weight.postScriptName as CFString, key.size, nil)
    var characters = CTFontCopyCharacterSet(barlow) as CharacterSet
    for block in reserveBlocks { characters.remove(charactersIn: block) }
    let reserve = SystemFont.systemFont(ofSize: key.size, weight: SystemFont.Weight(rawValue: key.weight.reserveWeight), width: .compressed)
    var attributes: [CFString: Any] = [
      kCTFontNameAttribute: key.weight.postScriptName,
      kCTFontCharacterSetAttribute: characters as NSCharacterSet,
      kCTFontCascadeListAttribute: [CTFontCopyFontDescriptor(reserve as CTFont)],
    ]
    if key.tabularDigits {
      attributes[kCTFontFeatureSettingsAttribute] = [[kCTFontOpenTypeFeatureTag: "tnum", kCTFontOpenTypeFeatureValue: 1]]
    }
    return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attributes as CFDictionary), key.size, nil)
  }

  // Os blocos do Unicode que sempre saem na reserva: o grego e o cirílico.
  private static let reserveBlocks: [ClosedRange<Unicode.Scalar>] = [
    "\u{0370}"..."\u{03FF}",  // grego e copta
    "\u{1F00}"..."\u{1FFF}",  // grego estendido
    "\u{0400}"..."\u{052F}",  // cirílico e o suplemento
    "\u{1C80}"..."\u{1C8F}",  // cirílico estendido C
    "\u{2DE0}"..."\u{2DFF}",  // cirílico estendido A
    "\u{A640}"..."\u{A69F}",  // cirílico estendido B
  ]
}

// O que distingue uma fonte da outra no cache.
fileprivate struct FontKey: Hashable, Sendable {
  let weight: HexWeight, size: CGFloat, tabularDigits: Bool
}

// As fontes já feitas. O CTFont é imutável e pode ser usado de qualquer thread, mas o SDK não o marca
// como Sendable: o lock protege o dicionário, e por isso a classe é @unchecked Sendable.
private final class FontCache: @unchecked Sendable {
  private let lock = NSLock()
  private var fonts: [FontKey: CTFont] = [:]

  func font(_ key: FontKey) -> CTFont {
    lock.withLock {
      if let font = fonts[key] { return font }
      let font = HexFonts.make(key)
      fonts[key] = font
      return font
    }
  }
}
