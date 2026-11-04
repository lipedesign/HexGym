// O documento de dados do HexGym (seção 8.3 do design doc): o mesmo documento do openGym, com as
// chaves de gym_state_v1, gravado como JSON no App Group, com a cópia anterior ao lado e a base de
// sincronização num arquivo próprio. O documento é opaco: este pacote só confere que ele é um objeto
// JSON e guarda os bytes como vieram, sem ler nenhuma chave.
//
// Os arquivos, todos no directory:
//   state.json             o documento
//   state.previous.json    a cópia anterior: o state.json de antes da última gravação, quando era bom
//   state.unreadable.json  o último state.json ruim, guardado para alguém olhar
//   sync-base.json         a base de sincronização (rev, ts e wid)
//
// Só um arquivo que não existe conta como falta. Qualquer outro erro de leitura (permissão, disco, um
// aparelho que ligou e ainda não foi desbloqueado) lança .unreadable sem mexer em nada, no load e no
// save: o app nunca começa do zero em silêncio (Foco da revisão 1 do plano da fase 0).

import Foundation
import os

// O que o load achou: nada, no primeiro uso; o state.json; ou a cópia anterior, quando o state.json
// faltava ou estava ruim.
public enum StoredDocument: Equatable, Sendable {
  case empty, current(Data), recovered(Data)
}

// A base de sincronização com um servidor openGym, a mesma que o app web guarda: a revisão do
// servidor, o horário do documento em milissegundos e o id da gravação.
public struct SyncBase: Codable, Equatable, Sendable {
  public var rev: Int
  public var ts: Int64?
  public var wid: String?

  public init(rev: Int, ts: Int64? = nil, wid: String? = nil) {
    self.rev = rev
    self.ts = ts
    self.wid = wid
  }
}

public enum DocumentStoreError: Error, Equatable {
  // O App Group com esse identificador não abriu: falta o entitlement, por exemplo.
  case appGroupUnavailable(String)
  // Um arquivo que existe não abriu, ou nenhuma das duas cópias é um documento.
  case unreadable
  // O documento para gravar não é um objeto JSON.
  case notAnObject
}

public actor DocumentStore {
  static let logger = Logger(subsystem: "app.hexgym", category: "dados")

  private static let document = "state.json"
  private static let previous = "state.previous.json"
  private static let unreadable = "state.unreadable.json"
  private static let syncBaseFile = "sync-base.json"

  private let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  // A pasta do App Group, onde ficam os arquivos. O lookup é o do sistema, e os testes passam outro.
  public static func appGroupDirectory(_ identifier: String = "group.app.hexgym",
                                       lookup: (String) -> URL? = { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }) throws -> URL {
    guard let url = lookup(identifier) else {
      logger.error("o App Group \(identifier, privacy: .public) não abriu")
      throw DocumentStoreError.appGroupUnavailable(identifier)
    }
    return url
  }

  // O documento, nesta ordem (a tabela da Task 8 do plano da fase 0):
  //   - um state.json bom é o .current, e a cópia anterior nem é lida;
  //   - um state.json que falta ou é ruim, com a cópia anterior boa: o ruim, se existe, vai para o
  //     state.unreadable.json, e a cópia volta como .recovered;
  //   - os dois faltando é o .empty;
  //   - qualquer outro caso, inclusive um erro de leitura em qualquer dos dois, lança .unreadable sem
  //     mexer em nada.
  // A recuperação e o erro vão para o log.
  public func load() throws -> StoredDocument {
    let current = try contents(of: Self.document)
    if let current, Self.isObject(current) { return .current(current) }
    let previous = try contents(of: Self.previous)
    if let previous, Self.isObject(previous) {
      if current != nil { try setAside() }
      let why = current == nil ? "faltava" : "estava ruim e foi para o state.unreadable.json"
      Self.logger.warning("o state.json \(why, privacy: .public), e o documento voltou da cópia anterior")
      return .recovered(previous)
    }
    if current == nil, previous == nil { return .empty }
    Self.logger.error("""
      nem o state.json (\(Self.describe(current), privacy: .public)) nem a cópia anterior \
      (\(Self.describe(previous), privacy: .public)) são um documento, e nada foi mexido
      """)
    throw DocumentStoreError.unreadable
  }

  // Grava o documento: confere que é um objeto JSON (senão, .notAnObject), guarda o state.json de
  // agora como cópia anterior, só se ele for bom, e grava o novo. Um state.json que falta ou é ruim não
  // vira cópia, e a cópia boa que já existe fica. Um state.json que existe e não abre lança .unreadable
  // antes de qualquer gravação. As duas gravações são atômicas: um app que morre no meio deixa o
  // arquivo de antes ou o novo, nunca um pedaço. Um erro ao gravar sai como o Foundation lançou.
  public func save(_ document: Data) throws {
    guard Self.isObject(document) else {
      Self.logger.error("o documento para gravar não é um objeto JSON, e nada foi gravado")
      throw DocumentStoreError.notAnObject
    }
    if let current = try contents(of: Self.document), Self.isObject(current) {
      try write(current, to: Self.previous)
    }
    try write(document, to: Self.document)
  }

  // A base de sincronização, ou nil quando o sync-base.json não existe. Como no documento, só a falta
  // vira nil: um arquivo que existe e não abre, ou que não é uma base, lança .unreadable.
  public func syncBase() throws -> SyncBase? {
    guard let data = try contents(of: Self.syncBaseFile) else { return nil }
    do {
      return try JSONDecoder().decode(SyncBase.self, from: data)
    } catch {
      Self.logger.error("o sync-base.json não é uma base de sincronização: \(String(describing: error), privacy: .private)")
      throw DocumentStoreError.unreadable
    }
  }

  // Grava a base de sincronização de uma vez, como o documento, com as chaves em ordem.
  public func saveSyncBase(_ base: SyncBase) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    try write(encoder.encode(base), to: Self.syncBaseFile)
  }

  private func url(_ name: String) -> URL {
    directory.appending(path: name)
  }

  // Os bytes do arquivo, ou nil quando ele não existe: só o NSFileReadNoSuchFileError conta como
  // falta. Qualquer outro erro de leitura vai para o log e lança .unreadable.
  private func contents(of name: String) throws -> Data? {
    do {
      return try Data(contentsOf: url(name))
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return nil
    } catch {
      Self.logger.error("""
        não deu para ler o \(name, privacy: .public) (erro \((error as NSError).code, privacy: .public)): \
        \(String(describing: error), privacy: .private)
        """)
      throw DocumentStoreError.unreadable
    }
  }

  // Grava o arquivo inteiro com Data.write(.atomic): o Foundation grava num arquivo temporário e troca
  // pelo de antes de uma vez. Um erro vai para o log e sai como veio.
  private func write(_ data: Data, to name: String) throws {
    do {
      try data.write(to: url(name), options: .atomic)
    } catch {
      Self.logger.error("""
        não deu para gravar o \(name, privacy: .public) (erro \((error as NSError).code, privacy: .public)): \
        \(String(describing: error), privacy: .private)
        """)
      throw error
    }
  }

  // Move o state.json ruim para o state.unreadable.json, por cima do ruim de antes, com o rename, que
  // troca os dois de uma vez. Sem conseguir guardar o ruim de lado, o load não recupera e lança
  // .unreadable: a gravação seguinte apagaria o arquivo ruim sem ninguém ter olhado.
  private func setAside() throws {
    let from = url(Self.document), to = url(Self.unreadable)
    let failure: Int32 = from.withUnsafeFileSystemRepresentation { from in
      to.withUnsafeFileSystemRepresentation { to in
        guard let from, let to else { return EINVAL }
        return rename(from, to) == 0 ? 0 : errno
      }
    }
    guard failure == 0 else {
      Self.logger.error("não deu para mover o state.json ruim para o state.unreadable.json: \(String(cString: strerror(failure)), privacy: .public)")
      throw DocumentStoreError.unreadable
    }
  }

  // Como o log descreve um arquivo que não serviu.
  private static func describe(_ contents: Data?) -> String {
    contents == nil ? "falta" : "não é um objeto JSON"
  }

  // Se o JSON.parse leria os bytes como um objeto. Antes do JSONSerialization, o bytesToParse recusa
  // o que ele não deve ler e troca cada escape de surrogate sem par pelo escape do U+FFFD: o
  // JSONSerialization recusa um surrogate sozinho, e o JSON.stringify grava um no texto de um emoji
  // cortado ao meio (Foco da revisão 2). A troca serve só para conferir: o que se grava e o que se
  // devolve são sempre os bytes de antes.
  private static func isObject(_ data: Data) -> Bool {
    guard let readable = bytesToParse(data) else { return false }
    return parsesAsObject(readable)
  }

  // Um objeto JSON sai do JSONSerialization como NSDictionary. O erro da leitura quer dizer só que os
  // bytes não são JSON, por isso fica de fora.
  private static func parsesAsObject(_ data: Data) -> Bool {
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return false }
    return object is NSDictionary
  }

  // Quantos níveis de { e [ um documento pode ter. Os documentos de verdade têm uns 7. O
  // JSONSerialization desce um nível por chamada e, na pilha de 512 KiB da thread do ator, derrubava o
  // app a partir de uns 480 (QA do PR #69).
  private static let maxDepth = 128

  private static let backslash = UInt8(ascii: "\\")
  private static let quote = UInt8(ascii: "\"")
  private static let high = 0xD800...0xDBFF
  private static let low = 0xDC00...0xDFFF
  private static let replacement = Array(#"\ufffd"#.utf8)

  // Os bytes para o JSONSerialization ler, ou nil quando o documento já é ruim sem ele, numa varredura
  // só:
  //   - um byte 0, em qualquer lugar, é ruim: um JSON em UTF-8 não tem nenhum, e com ele o
  //     JSONSerialization poderia ler os bytes como UTF-16 ou UTF-32, em que esta varredura não vale;
  //   - fora dos textos, ela conta os níveis de { e [, e passar de maxDepth é ruim;
  //   - dentro dos textos, cada escape de surrogate sem par vira o escape do U+FFFD, seis bytes no
  //     lugar de seis, para os índices não mudarem. Sem par quer dizer um \ud800 a \udbff sem um
  //     \udc00 a \udfff logo depois, ou um destes sem aquele logo antes; um par fica como está.
  // Dentro de um texto, cada barra começa um escape, e um \\ é uma barra escrita, que não começa
  // nenhum. Sem nada trocado, devolve os próprios bytes.
  private static func bytesToParse(_ data: Data) -> Data? {
    let bytes = [UInt8](data)
    guard !bytes.contains(0) else { return nil }
    var copy = bytes, changed = false, depth = 0, inText = false, i = 0
    while i < bytes.count {
      let byte = bytes[i]
      if !inText {
        switch byte {
        case quote: inText = true
        case UInt8(ascii: "{"), UInt8(ascii: "["):
          depth += 1
          if depth > maxDepth { return nil }
        case UInt8(ascii: "}"), UInt8(ascii: "]"): depth = max(depth - 1, 0)
        default: break
        }
        i += 1
        continue
      }
      if byte == quote {
        inText = false
        i += 1
        continue
      }
      guard byte == backslash else { i += 1; continue }
      // \", \\, \n e os outros escapes de dois bytes.
      guard let unit = escapedUnit(bytes, at: i) else { i += 2; continue }
      if high.contains(unit), let next = escapedUnit(bytes, at: i + 6), low.contains(next) {
        i += 12
        continue
      }
      if high.contains(unit) || low.contains(unit) {
        copy.replaceSubrange(i..<(i + 6), with: replacement)
        changed = true
      }
      i += 6
    }
    return changed ? Data(copy) : data
  }

  // O valor do escape \uXXXX que começa em i, ou nil quando ali não começa um.
  private static func escapedUnit(_ bytes: [UInt8], at i: Int) -> Int? {
    guard i + 6 <= bytes.count, bytes[i] == backslash, bytes[i + 1] == UInt8(ascii: "u") else { return nil }
    var unit = 0
    for byte in bytes[(i + 2)..<(i + 6)] {
      guard let digit = hexDigit(byte) else { return nil }
      unit = unit * 16 + digit
    }
    return unit
  }

  private static func hexDigit(_ byte: UInt8) -> Int? {
    switch byte {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): Int(byte - UInt8(ascii: "0"))
    case UInt8(ascii: "a")...UInt8(ascii: "f"): Int(byte - UInt8(ascii: "a")) + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): Int(byte - UInt8(ascii: "A")) + 10
    default: nil
    }
  }
}
