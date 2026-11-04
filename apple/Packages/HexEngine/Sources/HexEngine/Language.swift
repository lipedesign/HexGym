// O idioma do motor (seção 8.9 do design doc; escolhas 4 e 5 do plano da fase 2, escolha
// recomendada, com a delegação do Lipe de 03/11/2026): o idioma segue o do aparelho e nunca é
// gravado no documento. Os pacotes, gerados por scripts/build-hexgym-langs.mjs, ficam em
// Resources/langs, um por idioma, comprimidos em DEFLATE cru como o script do motor, com o
// index.json, que diz para cada idioma do LANGS do openGym o arquivo e o sha256 do texto. Um idioma
// derivado (de-CH) aponta para o arquivo da base (de), e o setLanguage do motor faz a derivação.

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

  // O index.json lido uma vez: idioma → arquivo do pacote. Sem ele, nenhum idioma serve, e o load()
  // lança .scriptMissing ao pedir o en.
  private static let index: [String: String] = {
    guard let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "langs"),
          let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
    else { return [:] }
    return json.compactMapValues { $0["file"] }
  }()

  static var available: Set<String> { Set(index.keys) }

  // O texto do pacote de um idioma do índice, descomprimido. O pacote é parte do HexEngine como o
  // script do motor: quando falta ou não descomprime, o pacote Swift está quebrado, e o erro é
  // .scriptMissing.
  static func packText(_ tag: String) throws -> String {
    guard let file = index[tag],
          let url = Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "langs"),
          let packed = try? Data(contentsOf: url),
          let text = try? (packed as NSData).decompressed(using: .zlib) as Data
    else { throw EngineError.scriptMissing }
    return String(decoding: text, as: UTF8.self)
  }
}
