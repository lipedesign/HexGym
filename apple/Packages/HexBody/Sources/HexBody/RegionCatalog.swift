// As regiões do corpo que cada exercício acende (seção 9 do design doc e Task 8 do plano da fase 2):
// as 36 regiões pintadas do modelo v2, o primário, o secundário e a ênfase de cada exercício, e os
// nomes das regiões em português do Brasil e em inglês.
//
// Os dados vêm do exercise-regions.json do pacote, que o gerador de scripts/hexbody/regions/ grava
// a partir do texto do catálogo do openGym (o --check dele confere que o arquivo está em dia). A
// mídia dos exercícios e as regiões se ligam só pelo id do exercício. Só Foundation.

import Foundation

// O corpo que a pessoa escolheu na primeira abertura. Os dois desenhos usam as mesmas regiões.
public enum BodyFigure: String, CaseIterable, Sendable {
  case male, female
}

// Uma das 36 regiões pintadas: o id do modelo v2, o grupo dela no boneco e o grupo que o Watch e o
// widget mostram (nil no pescoço, que fica inerte neles).
public struct BodyRegion: Hashable, Identifiable, Sendable {
  public let id: String
  public let group: String
  public let watchGroup: String?
}

// As regiões de um exercício. A ênfase são as do primário que o texto do exercício destaca.
public struct ExerciseRegions: Equatable, Sendable {
  public let primary: [BodyRegion]
  public let secondary: [BodyRegion]
  public let emphasis: [BodyRegion]

  // As regiões vêm do RegionCatalog.bundled.regions, porque só o catálogo cria regiões. É público
  // para os testes do app montarem um exercício sem o @testable.
  public init(primary: [BodyRegion], secondary: [BodyRegion], emphasis: [BodyRegion]) {
    self.primary = primary
    self.secondary = secondary
    self.emphasis = emphasis
  }

  // O peso da região no desenho, os da pesquisa: 1 no primário (a cor do tema), 0,4 no secundário
  // (40% dela) e 0 fora do exercício.
  public func weight(of region: BodyRegion) -> Double {
    if primary.contains(region) { return 1 }
    if secondary.contains(region) { return 0.4 }
    return 0
  }
}

// O catálogo das regiões, lido uma vez do pacote.
public final class RegionCatalog: Sendable {
  // O catálogo do exercise-regions.json do pacote. Um arquivo que falta ou não se lê é um erro do
  // build, e não do aparelho: o app para com o motivo.
  public static let bundled: RegionCatalog = {
    do {
      guard let url = Bundle.module.url(forResource: "exercise-regions", withExtension: "json") else {
        throw RegionCatalogError.missingFile
      }
      return try RegionCatalog(data: Data(contentsOf: url))
    } catch {
      fatalError("HexBody: não deu para ler o exercise-regions.json do pacote (\(error))")
    }
  }()

  // As 36 regiões, na ordem do regions_v2.json.
  public let regions: [BodyRegion]

  // As três listas de cada exercício pelo id, com os índices das regiões, como no arquivo. As
  // regiões saem delas a cada pedido, o que custa pouco e guarda menos na memória.
  private let exercises: [String: [[Int]]]

  // Lê o JSON do gerador, conferindo que cada exercício tem as três listas e que todo índice é de
  // uma região que existe.
  init(data: Data) throws {
    let file = try JSONDecoder().decode(RegionFile.self, from: data)
    regions = file.regions.map { BodyRegion(id: $0.id, group: $0.group, watchGroup: $0.watchGroup) }
    for (id, lists) in file.exercises {
      guard lists.count == 3, lists.joined().allSatisfy(file.regions.indices.contains) else {
        throw RegionCatalogError.badExercise(id)
      }
    }
    exercises = file.exercises
  }

  // As regiões do exercício, ou nil quando o catálogo não tem o id (um exercício personalizado, por
  // exemplo). Os desenhos femininos têm o id deles, com as regiões do exercício de que são o desenho.
  public func regions(for exerciseID: String) -> ExerciseRegions? {
    guard let lists = exercises[exerciseID] else { return nil }
    let pick = { (list: [Int]) in list.map { self.regions[$0] } }
    return ExerciseRegions(primary: pick(lists[0]), secondary: pick(lists[1]), emphasis: pick(lists[2]))
  }

  // O nome da região no idioma pedido, da tabela Regions: português de qualquer região lê o
  // pt-BR.lproj, e o resto lê o en.lproj, como os textos do HexDesign. As views passam o
  // @Environment(\.locale), e os testes, o idioma que querem.
  public func name(of region: BodyRegion, locale: Locale = .current) -> String {
    RegionStrings.bundle(for: locale).localizedString(forKey: region.id, value: nil, table: "Regions")
  }
}

// O formato do exercise-regions.json.
private struct RegionFile: Decodable {
  struct Row: Decodable {
    let id: String
    let group: String
    let watchGroup: String?
  }
  let regions: [Row]
  let exercises: [String: [[Int]]]
}

enum RegionCatalogError: Error {
  case missingFile
  case badExercise(String)
}

// As pastas .lproj do pacote, como bundles, abertas uma vez só. Sem uma delas, o bundle do pacote.
private enum RegionStrings {
  static func bundle(for locale: Locale) -> Bundle {
    locale.language.languageCode == .portuguese ? portuguese : english
  }

  private static let portuguese = localization("pt-BR")
  private static let english = localization("en")

  private static func localization(_ name: String) -> Bundle {
    Bundle.module.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
  }
}
