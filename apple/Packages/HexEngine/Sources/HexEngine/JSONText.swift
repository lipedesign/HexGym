// Um trecho de um texto JSON, achado sem decodificar o texto (issue #117). O JSONDecoder e o
// JSONSerialization passam todo objeto por um dicionário, que não guarda a ordem das chaves, e o
// JSONEncoder escreve de volta na ordem que quiser. Para o motor receber de volta exatamente o que
// escreveu, o Swift guarda os bytes do valor como estão no texto, e este leitor só acha onde o valor
// começa e onde acaba.

import Foundation

enum JSONText {
  // Os bytes do valor no caminho de chaves, como estão no texto: ["result", "snapshot"] é o
  // result.snapshot do topo. Nil quando uma chave falta, quando o caminho passa por algo que não é
  // objeto ou quando o texto não é JSON até ali.
  static func value(at path: [String], in data: Data) -> Data? {
    let bytes = [UInt8](data)
    var reader = Reader(bytes: bytes)
    guard let range = reader.member(path[...]) else { return nil }
    return Data(bytes[range])
  }

  private struct Reader {
    let bytes: [UInt8]
    var at = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    // O intervalo do valor no caminho, a partir do valor que começa em at.
    mutating func member(_ path: ArraySlice<String>) -> Range<Int>? {
      skipSpace()
      guard let key = path.first else {
        let start = at
        return skipValue() ? start..<at : nil
      }
      guard byte == UInt8(ascii: "{") else { return nil }
      at += 1
      skipSpace()
      if byte == UInt8(ascii: "}") { return nil }
      while true {
        skipSpace()
        let start = at
        guard skipString(), let name = Self.name(bytes[start..<at]) else { return nil }
        skipSpace()
        guard byte == UInt8(ascii: ":") else { return nil }
        at += 1
        // O JSON.stringify do motor nunca repete uma chave; a primeira que bate é a única.
        if name == key { return member(path.dropFirst()) }
        skipSpace()
        guard skipValue() else { return nil }
        skipSpace()
        switch byte {
        case UInt8(ascii: ","): at += 1
        default: return nil  // o "}" do fim, sem a chave, ou um texto que não é JSON
        }
      }
    }

    // O byte em at, ou 0 depois do fim, que nenhuma regra aceita.
    private var byte: UInt8 { at < bytes.count ? bytes[at] : 0 }

    private mutating func skipSpace() {
      while at < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[at]) { at += 1 }
    }

    // Pula um valor inteiro: um objeto ou uma lista, com o que vai dentro, um texto, ou um número,
    // true, false e null até o próximo separador. Falso num texto que acaba no meio.
    private mutating func skipValue() -> Bool {
      switch byte {
      case UInt8(ascii: "\""): return skipString()
      case UInt8(ascii: "{"), UInt8(ascii: "["):
        let close = byte == UInt8(ascii: "{") ? UInt8(ascii: "}") : UInt8(ascii: "]")
        at += 1
        skipSpace()
        if byte == close { at += 1; return true }
        while true {
          skipSpace()
          if close == UInt8(ascii: "}") {
            guard skipString() else { return false }
            skipSpace()
            guard byte == UInt8(ascii: ":") else { return false }
            at += 1
            skipSpace()
          }
          guard skipValue() else { return false }
          skipSpace()
          if byte == UInt8(ascii: ",") { at += 1; continue }
          guard byte == close else { return false }
          at += 1
          return true
        }
      default:
        let start = at
        while at < bytes.count, !Self.ends.contains(bytes[at]) { at += 1 }
        return at > start
      }
    }

    // Pula um texto entre aspas, com os escapes (\" e os outros) dentro.
    private mutating func skipString() -> Bool {
      guard byte == UInt8(ascii: "\"") else { return false }
      at += 1
      while at < bytes.count {
        switch bytes[at] {
        case UInt8(ascii: "\""): at += 1; return true
        case UInt8(ascii: "\\"): at += 2
        default: at += 1
        }
      }
      return false
    }

    // O que acaba um número, um true, um false ou um null.
    private static let ends: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D, UInt8(ascii: ","), UInt8(ascii: "}"), UInt8(ascii: "]")]

    // O nome de uma chave, com as aspas. Sem barra, são os bytes de dentro; com uma, o JSONDecoder
    // lê os escapes.
    private static func name(_ quoted: ArraySlice<UInt8>) -> String? {
      guard quoted.contains(UInt8(ascii: "\\")) else { return String(decoding: quoted.dropFirst().dropLast(), as: UTF8.self) }
      return try? JSONDecoder().decode(String.self, from: Data(quoted))
    }
  }
}
