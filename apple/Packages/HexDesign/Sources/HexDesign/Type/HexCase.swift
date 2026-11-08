// A caixa alta com o locale de cada escrita (#121, achado no QA da PR #86). A regra do grego tira o
// tonos das maiúsculas ("Πιέσεις πάγκου" vira "ΠΙΕΣΕΙΣ ΠΑΓΚΟΥ"), e quem sabe disso é o locale do grego.
// O textCase do SwiftUI põe em maiúsculas com o locale do ambiente: no iPhone e no Watch em português ou
// em inglês, o grego ficava com o tonos ("ΠΙΈΣΕΙΣ ΠΆΓΚΟΥ"), medido no simulador do Watch. No Mac dos
// testes, ele tira o tonos com qualquer locale.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: pôr em maiúsculas com o locale do próprio
// texto nos trechos em grego, e o resto com o locale de quem lê.

import SwiftUI

public enum HexCase {
  // O texto em maiúsculas, um trecho de cada escrita por vez: cada trecho em grego com o locale do grego,
  // e o resto com o locale pedido (o de quem lê). O que não é letra (espaço, número, pontuação) fica no
  // trecho em que está, e as regras que olham a palavra inteira continuam vendo a palavra inteira.
  public static func uppercased(_ text: String, locale: Locale) -> String {
    var result = "", run = "", runIsGreek = false, runHasLetters = false
    for character in text {
      if character.isLetter {
        let greek = isGreek(character)
        if runHasLetters, greek != runIsGreek {
          result += run.uppercased(with: runIsGreek ? Self.greek : locale)
          run = ""
        }
        runIsGreek = greek
        runHasLetters = true
      }
      run.append(character)
    }
    return result + run.uppercased(with: runIsGreek ? Self.greek : locale)
  }

  // O locale das maiúsculas do grego.
  static let greek = Locale(identifier: "el")

  // Uma letra grega: a primeira parte dela está no bloco do grego ou do grego estendido. Um acento
  // separado (U+0301, por exemplo) vem junto da letra, no mesmo Character.
  static func isGreek(_ character: Character) -> Bool {
    guard let first = character.unicodeScalars.first else { return false }
    return (0x0370...0x03FF).contains(first.value) || (0x1F00...0x1FFF).contains(first.value)
  }
}

// Um texto da escala com a caixa alta certa em toda escrita, para o texto que pode vir em grego (o nome
// de um exercício, por exemplo). Num estilo em caixa alta, ou com a caixa alta vinda de fora, o texto já
// chega em maiúsculas pelo HexCase, no locale do ambiente; o textCase do hexFont por cima não muda mais
// nada, porque uma maiúscula continua a mesma. Num estilo sem caixa alta, o texto fica como veio.
public struct HexText: View {
  private let text: String
  private let style: HexTextStyle

  @Environment(\.locale) private var locale
  @Environment(\.textCase) private var inheritedCase

  public init(_ text: String, style: HexTextStyle) {
    self.text = text
    self.style = style
  }

  public var body: some View {
    let upper = style.uppercase || inheritedCase == .uppercase
    Text(verbatim: upper ? HexCase.uppercased(text, locale: locale) : text).hexFont(style)
  }
}
