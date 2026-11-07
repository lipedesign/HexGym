// Os testes do catálogo de regiões do HexBody (Task 8 do plano da fase 2, issue #95): as 36 regiões,
// as do supino reto com os pesos 1 e 0,4, um id que não existe e os nomes nos dois idiomas.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexBody
//
// Eles leem o exercise-regions.json do pacote, o mesmo que o app lê; o --check do gerador confere
// que ele bate com o catálogo.

import Foundation
import Testing
@testable import HexBody

private let br = Locale(identifier: "pt-BR")
private let en = Locale(identifier: "en_US")

@Suite struct RegionCatalogTests {
  let catalog = RegionCatalog.bundled

  // A região pelo id, para os testes.
  func region(_ id: String) throws -> BodyRegion {
    try #require(catalog.regions.first { $0.id == id }, "a região \(id) existe")
  }

  @Test func theBundledCatalogHasThe36Regions() {
    #expect(catalog.regions.count == 36)
    #expect(Set(catalog.regions.map(\.id)).count == 36)
    // A ordem é a do regions_v2.json, e o pescoço não tem grupo no Watch.
    #expect(catalog.regions.first?.id == "upperTrapezius")
    #expect(catalog.regions.filter { $0.watchGroup == nil }.map(\.id) == ["sternocleidomastoid", "neckBack"])
  }

  @Test func theBenchPressLightsTheChestAndTheTricepsAtFortyPercent() throws {
    let bench = try #require(catalog.regions(for: "0025"))
    let chest = try region("chest"), triceps = try region("triceps")
    #expect(bench.primary.contains(chest))
    #expect(bench.secondary.contains(triceps))
    #expect(bench.weight(of: chest) == 1)
    #expect(bench.weight(of: triceps) == 0.4)
    #expect(bench.weight(of: try region("calves")) == 0)
    // O desenho feminino do supino (2440) entra pelo id dele, com as mesmas regiões.
    #expect(catalog.regions(for: "2440") == bench)
    // O init público, como nos testes do app: o mesmo exercício montado à mão dá os mesmos pesos.
    let fixture = ExerciseRegions(primary: [chest], secondary: [triceps], emphasis: [])
    #expect(fixture.weight(of: chest) == 1 && fixture.weight(of: triceps) == 0.4)
  }

  @Test func anUnknownExerciseHasNoRegions() {
    #expect(catalog.regions(for: "não-existe") == nil)
    #expect(catalog.regions(for: "") == nil)
  }

  @Test func everyRegionHasANameInBothLanguages() throws {
    for region in catalog.regions {
      for locale in [br, en] {
        let name = catalog.name(of: region, locale: locale)
        #expect(!name.isEmpty && name != region.id, "\(region.id) sem nome em \(locale.identifier)")
      }
    }
    let chest = try region("chest")
    #expect(catalog.name(of: chest, locale: br) == "Peito médio")
    #expect(catalog.name(of: chest, locale: en) == "Mid chest")
    #expect(catalog.name(of: chest, locale: Locale(identifier: "pt-PT")) == "Peito médio")
    #expect(catalog.name(of: chest, locale: Locale(identifier: "ja_JP")) == "Mid chest")
  }
}
