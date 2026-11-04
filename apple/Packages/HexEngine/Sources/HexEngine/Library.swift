// A biblioteca do motor (Task 4 do plano da fase 2): o catálogo, a busca, os filtros e o detalhe de
// cada exercício, do library.js. Toda a regra fica no JS do openGym (seção 8.2 do design doc): a
// busca sem acento e nos dois idiomas, os grupos, os favoritos primeiro e o "Exercício
// desconhecido". O Swift só manda a pergunta e decodifica a resposta nestes modelos pequenos.

import Foundation

// Uma linha da lista de exercícios. O bp é o grupo principal que a lista mostra; o equipamento vem
// vazio num personalizado antigo, e a categoria, nil num personalizado. Os pesos dos grupos são os
// do openGym: 1 no primário, 0,4 no secundário, e 0 numa ligação sem crédito.
public struct ExerciseSummary: Codable, Hashable, Identifiable, Sendable {
  public let id: String, name: String, bp: String, equipment: [String], category: String?
  public let muscles: [String: Double], favourite: Bool, custom: Bool
}

// A busca e os filtros. Cada filtro aceita qualquer um dos escolhidos; vazio é sem filtro.
public struct LibraryQuery: Codable, Equatable, Sendable {
  public var query: String = "", muscles: [String] = [], equipment: [String] = [], categories: [String] = []
  public var favouritesOnly = false
  public init() {}
}

// O detalhe de um exercício. Um id que não existe vem com known false e o nome "Exercício
// desconhecido" no idioma.
public struct ExerciseDetail: Codable, Equatable, Sendable {
  public let id: String, name: String, nameEnglish: String, bp: String, equipment: [String], category: String?
  public let muscles: [String: Double], instructions: [String], description: String?
  public let favourite: Bool, custom: Bool, known: Bool
}

// Uma opção de filtro: o id que vai na LibraryQuery e o nome no idioma.
public struct LibraryFacet: Codable, Hashable, Identifiable, Sendable { public let id: String, name: String }

// As opções dos filtros: os grupos musculares, o equipamento, as categorias e as partes do corpo.
public struct LibraryFacets: Codable, Equatable, Sendable { public let muscles, equipment, categories, bodyParts: [LibraryFacet] }

extension HexEngine {
  // Todos os exercícios do documento aberto, os personalizados primeiro.
  public func catalogue() throws -> [ExerciseSummary] {
    try decoded(run("catalogue", []))
  }

  // Os ids que a busca e os filtros deixam, com os favoritos primeiro.
  public func search(_ query: LibraryQuery) throws -> [String] {
    let text = String(decoding: try JSONEncoder().encode(query), as: UTF8.self)
    let found: Found = try decoded(run("search", [text]))
    return found.ids
  }

  public func exercise(_ id: String) throws -> ExerciseDetail {
    try decoded(run("exercise", [id]))
  }

  public func facets() throws -> LibraryFacets {
    try decoded(run("facets", []))
  }

  private struct Found: Decodable { let ids: [String] }

  // A resposta do motor num modelo. Um texto que não decodifica é erro do motor, com o que faltou.
  private func decoded<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw EngineError.javaScript("HexEngine: a resposta não é um \(T.self): \(error)")
    }
  }
}
