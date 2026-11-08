// O histórico (Task 5 do plano da fase 3), do workouts.js: a lista dos treinos feitos, em páginas, e
// o detalhe de um. Toda a regra fica no JS do openGym (seção 8.2 do design doc): a ordem, a chave do
// sameWorkout, a duração, as séries, o volume e as linhas. O Swift só manda a consulta e decodifica a
// resposta nestes modelos pequenos. Apagar um treino é o EngineAction.deleteWorkout, pelo apply.
//
// A chave de um treino é o id dele, ou "<dia>|<começo>" (o legacySyncKey do openGym) quando ele é
// antigo e não tem id. É ela que abre o detalhe, pede a página seguinte e apaga.

import Foundation

// Um treino da lista: a duração em ms (0 num treino sem relógio, como os importados), as séries
// feitas (o aquecimento conta) e as de trabalho, o volume na unidade do perfil e os ids dos
// exercícios com recorde.
public struct WorkoutSummary: Codable, Equatable, Hashable, Sendable {
  public struct Sets: Codable, Equatable, Hashable, Sendable { public let done: Int, work: Int }
  public let key: String
  public let id: String?          // nil num treino antigo, sem id
  public let d: String?           // o dia do treino, "2026-11-06"
  public let name: String
  public let start: Date?, end: Date?
  public let durationMs: Double
  public let sets: Sets
  public let volume: Double
  public let unit: String
  public let prs: [String]
}

// Uma página da lista, do mais novo para o mais antigo; more diz que há treinos depois dela.
public struct HistoryPage: Codable, Equatable, Sendable {
  public let items: [WorkoutSummary]
  public let more: Bool
}

// O detalhe de um treino: só as séries feitas, como o detalhe do openGym. O pr da entrada é o selo do
// exercício com recorde, e o da série é a série que levou a carga do recorde. Um exercício que não
// existe neste aparelho vem com known false e o nome "Exercício desconhecido".
public struct WorkoutDetail: Codable, Equatable, Sendable {
  public struct SetLine: Codable, Equatable, Hashable, Sendable {
    public let line: String         // "60 kg × 8", com a falha, o esforço e o batimento quando há
    public let done: Bool           // false numa série com lados em que só um lado foi feito
    public let warmup: Bool
    public let pr: Bool

    public init(line: String, done: Bool, warmup: Bool, pr: Bool) { (self.line, self.done, self.warmup, self.pr) = (line, done, warmup, pr) }
  }
  public struct Entry: Codable, Equatable, Sendable {
    public let id: String, name: String
    public let known: Bool
    public let sg: String?, sgLetter: String?
    public let pr: Bool
    public let sets: [SetLine]
  }

  public let key: String, name: String
  public let d: String?
  public let start: Date?, end: Date?
  public let durationMs: Double
  public let volume: Double
  public let unit: String
  public let bw: Double?          // o peso do corpo do treino, na unidade do perfil
  public let note: String?
  public let prs: [String]
  public let entries: [Entry]
}

extension HexEngine {
  // Uma página do histórico: os limit treinos depois do de chave before, ou os primeiros sem before.
  // Um before que não existe mais (o treino foi apagado) volta como o TypeError do motor; a tela lê
  // de novo do começo.
  public func history(before: String?, limit: Int) throws -> HistoryPage {
    let query = String(decoding: try JSONEncoder().encode(HistoryQuery(before: before, limit: limit)), as: UTF8.self)
    return try decodedHistory(run("history", [query]))
  }

  // O detalhe do treino da chave, ou nil quando não há treino com ela.
  public func workoutDetail(_ key: String) throws -> WorkoutDetail? {
    try decodedHistory(run("workoutDetail", [key]))
  }

  private struct HistoryQuery: Encodable { let before: String?; let limit: Int }

  // A resposta do motor num modelo, com as horas em ms, como as do treino. Um texto que não decodifica
  // é erro do motor, com o que faltou.
  private func decodedHistory<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try Self.sessionDecoder.decode(T.self, from: data)
    } catch {
      throw EngineError.javaScript("HexEngine: a resposta não é um \(T.self): \(error)")
    }
  }
}
