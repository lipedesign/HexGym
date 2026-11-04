// O idioma do motor (seção 8.9 do design doc; escolhas 4 e 5 do plano da fase 2, escolha
// recomendada, com a delegação do Lipe de 03/11/2026): o idioma segue o do aparelho e nunca é
// gravado no documento. Os pacotes, gerados por scripts/build-hexgym-langs.mjs, ficam em
// Resources/langs, um por idioma, comprimidos em DEFLATE cru como o script do motor, com o
// index.json, que diz para cada idioma do LANGS do openGym o arquivo e o sha256 do texto. Um idioma
// derivado (de-CH) aponta para o arquivo da base (de), e o setLanguage do motor faz a derivação.
// Cada pacote carregado é conferido contra o sha256 do index.json.

import CryptoKit
import Foundation

public enum EngineLanguage {
  // O idioma de LANGS do openGym para as línguas do aparelho, na ordem da lista; para cada uma, a tag
  // inteira ("pt-BR", "de-CH"), depois o chinês pelo script ("zh-Hant-TW" e "zh-Hant-HK" viram
  // "zh-TW", "zh-Hans-CN" vira "zh"), depois a base ("pt-PT" vira "pt"); "en" quando nenhuma serve.
  // Os idiomas que servem são os do index.json dos pacotes.
  public static func tag(for preferred: [String]) -> String {
    tag(for: preferred, among: available)
  }

  static func tag(for preferred: [String], among available: Set<String>) -> String {
    // A forma do LANGS ("pt-BR", "zh-TW") pelo texto em minúsculas, para "pt-br" ou "PT-BR" servirem.
    let known = Dictionary(available.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    for raw in preferred {
      // Sem a extensão do iOS ("en-US@rg=brzzzz") e com - no lugar de _.
      let clean = raw.split(separator: "@").first.map(String.init) ?? ""
      let parts = clean.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
      guard let language = parts.first, !language.isEmpty else { continue }
      let rest = parts.dropFirst()
      let script = rest.first { $0.count == 4 }
      let region = rest.first { $0.count == 2 || ($0.count == 3 && Int($0) != nil) }
      if let whole = known[parts.joined(separator: "-")] { return whole }
      // O chinês com script decide pelo script, antes da região: "zh-Hans-TW" (o simplificado com a
      // região Taiwan) é "zh", e "zh-Hant", sem região, é "zh-TW".
      if language == "zh", let script, let chinese = known[script == "hant" ? "zh-tw" : "zh"] { return chinese }
      if let region, let regional = known["\(language)-\(region)"] { return regional }
      // Sem script, a região: Taiwan, Hong Kong e Macau usam o tradicional.
      if language == "zh", let chinese = known[["tw", "hk", "mo"].contains(region ?? "") ? "zh-tw" : "zh"] { return chinese }
      if let base = known[language] { return base }
    }
    return "en"
  }

  // Uma linha do index.json: o arquivo do pacote e o sha256 do texto descomprimido.
  struct PackEntry: Decodable, Equatable {
    let file: String
    let sha256: String
  }

  // A pasta langs do Bundle.module do HexEngine (o alvo de teste tem o próprio Bundle.module).
  static let directory = Bundle.module.url(forResource: "langs", withExtension: nil)

  // O index.json lido uma vez. Quando ele falta ou não lê, o erro fica guardado, e o load() lança
  // ele ao pedir o primeiro pacote, em vez de seguir com um índice vazio.
  private static let index = Result { try readIndex(in: directory) }

  static var available: Set<String> { Set(((try? index.get()) ?? [:]).keys) }

  // O index.json de uma pasta de pacotes, ou o erro que diz por que ele não serve.
  static func readIndex(in directory: URL?) throws -> [String: PackEntry] {
    guard let directory else { throw EngineError.languagePack("HexEngine: a pasta langs dos pacotes de idioma falta no pacote") }
    let url = directory.appending(path: "index.json")
    guard let data = try? Data(contentsOf: url)
    else { throw EngineError.languagePack("HexEngine: o index.json dos pacotes de idioma falta (\(url.path))") }
    do {
      return try JSONDecoder().decode([String: PackEntry].self, from: data)
    } catch {
      throw EngineError.languagePack("HexEngine: o index.json dos pacotes de idioma não lê (\(url.path)): \(error)")
    }
  }

  // O texto do pacote de um idioma do índice, descomprimido e conferido contra o sha256 do índice,
  // como o hexengine.js.sha256 confere o script do motor.
  static func packText(_ tag: String) throws -> String {
    try packText(tag, index: index.get(), in: directory)
  }

  static func packText(_ tag: String, index: [String: PackEntry], in directory: URL?) throws -> String {
    guard let entry = index[tag] else { throw EngineError.languagePack("HexEngine: o index.json não tem o idioma \(tag)") }
    guard let url = directory?.appending(path: entry.file), let packed = try? Data(contentsOf: url)
    else { throw EngineError.languagePack("HexEngine: o pacote \(entry.file) do idioma \(tag) falta") }
    guard let text = try? (packed as NSData).decompressed(using: .zlib) as Data
    else { throw EngineError.languagePack("HexEngine: o pacote \(entry.file) do idioma \(tag) não descomprime") }
    let sum = SHA256.hash(data: text).map { String(format: "%02x", $0) }.joined()
    guard sum == entry.sha256
    else { throw EngineError.languagePack("HexEngine: o pacote \(entry.file) do idioma \(tag) não bate com o sha256 do index.json") }
    return String(decoding: text, as: UTF8.self)
  }
}
