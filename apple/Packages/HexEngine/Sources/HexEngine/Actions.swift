// As ações sobre o documento e as leituras das telas (Task 5 do plano da fase 2), do actions.js. Toda
// a regra fica no JS do openGym (seção 8.2 do design doc): o rascunho, a mudança e o carimbo do
// update() do store/useStore.js, os limites e o que conta como inválido. O Swift só codifica a ação
// no JSON que o actions.js espera e decodifica a resposta nestes modelos pequenos. Uma ação inválida
// volta como EngineError.javaScript("TypeError: …"), e o documento dentro do motor fica como estava.

import Foundation

// Um valor JSON qualquer, com o mesmo conteúdo na volta. Um objeto passa por um dicionário e volta
// com as chaves em outra ordem; por isso o RoutineSnapshot guarda o texto, e não um destes.
public enum JSONValue: Codable, Equatable, Hashable, Sendable {
  case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
    else { self = .object(try c.decode([String: JSONValue].self)) }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let v): try c.encode(v)
    // Um número inteiro sai sem ".0", como o JSON do motor: o índice e as posições do snapshot
    // precisam voltar inteiros (o restoreRoutine confere com Number.isInteger).
    case .number(let v):
      if v.rounded() == v, abs(v) < 9_007_199_254_740_992 { try c.encode(Int64(v)) } else { try c.encode(v) }
    case .string(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    }
  }
}

// O snapshot que o routine.delete devolve (o routineSnapshot do openGym, com as marcas do
// undoMarks), para o restoreRoutine de depois. Guarda o texto JSON como o motor escreveu, e o apply
// devolve esse texto igual no desfazer: a rotina volta com as chaves na ordem de antes, e o
// documento fica igual byte a byte ao de antes de apagar, menos os carimbos (issue #117). O Swift
// não lê o snapshot.
public struct RoutineSnapshot: Codable, Equatable, Sendable {
  // O texto JSON do snapshot, um objeto.
  public let json: Data

  // O snapshot da resposta do apply, { changed, result: { snapshot } }, nos bytes do texto, sem
  // passar por um dicionário (JSONText).
  init(response: Data) throws {
    guard let json = JSONText.value(at: ["result", "snapshot"], in: response), json.first == UInt8(ascii: "{")
    else { throw EngineError.javaScript("HexEngine: a resposta do apply não traz o snapshot como objeto") }
    self.json = json
  }

  // Um snapshot montado à mão, como nos testes, no texto do JSONEncoder.
  public init(_ value: JSONValue) throws { json = try JSONEncoder().encode(value) }

  // O Codable passa pelo JSONValue, sem a ordem das chaves. O apply não usa este caminho: lê o
  // texto do snapshot direto da resposta do motor e manda o texto de volta (EngineAction.text).
  public init(from decoder: Decoder) throws { json = try JSONEncoder().encode(JSONValue(from: decoder)) }
  public func encode(to encoder: Encoder) throws { try JSONDecoder().decode(JSONValue.self, from: json).encode(to: encoder) }
}

// Os campos que o slot.update muda; nil fica de fora do JSON e não muda nada. Os limites são do
// actions.js (séries de 1 a 20, repetições de 1 a 100, o repsMin até as repetições, segundos de 1 a
// 3.600, carga de 0 a 1.000 na unidade do perfil, nota até 500 letras, modo reps ou time).
public struct SlotFields: Codable, Equatable, Sendable {
  public var sets, reps, repsMin: Int?
  public var weight: Double?
  public var sec: Int?
  public var mode: String?
  public var note: String?

  public init(sets: Int? = nil, reps: Int? = nil, repsMin: Int? = nil, weight: Double? = nil, sec: Int? = nil,
              mode: String? = nil, note: String? = nil) {
    (self.sets, self.reps, self.repsMin, self.weight, self.sec, self.mode, self.note) = (sets, reps, repsMin, weight, sec, mode, note)
  }
}

// Um ajuste do documento. O tema, a cor e o idioma não estão aqui de propósito: o HexGym nunca grava
// os três (seção 8.12 e escolha 4 do plano).
public enum SettingChange: Encodable, Equatable, Sendable {
  case unit(String), body(String), weekStart(Int), restSec(Int), effort(String)

  // A chave do documento e o valor, como o settings.set do actions.js recebe.
  var key: String {
    switch self {
    case .unit: "unit"
    case .body: "body"
    case .weekStart: "weekStart"
    case .restSec: "restSec"
    case .effort: "effort"
    }
  }

  var value: JSONValue {
    switch self {
    case .unit(let v), .body(let v), .effort(let v): .string(v)
    case .weekStart(let v), .restSec(let v): .number(Double(v))
    }
  }

  private enum Keys: String, CodingKey { case key, value }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(key, forKey: .key)
    try c.encode(value, forKey: .value)
  }
}

// Uma ação, no JSON do actions.js: { "type": "routine.create", "name": … } e assim por diante.
public enum EngineAction: Encodable, Sendable {
  case createRoutine(name: String)
  case renameRoutine(id: String, name: String)
  case setRoutineGlyph(id: String, glyph: String)
  case duplicateRoutine(id: String)
  case moveRoutine(from: Int, to: Int)
  case deleteRoutine(id: String)
  case restoreRoutine(snapshot: RoutineSnapshot)
  case addExercises(routineID: String, exerciseIDs: [String], at: Int?)
  case removeSlot(routineID: String, index: Int)
  case moveSlot(routineID: String, from: Int, to: Int)
  case replaceSlot(routineID: String, index: Int, exerciseID: String)
  case superset(routineID: String, index: Int)
  case unsuperset(routineID: String, index: Int)
  case updateSlot(routineID: String, index: Int, fields: SlotFields)
  case setWeekDay(day: Int, routineIDs: [String])
  case loadStarterPlan(id: String)
  case setSetting(SettingChange)
  case toggleFavourite(id: String)

  private enum Keys: String, CodingKey {
    case type, name, id, glyph, from, to, snapshot, routineId, exerciseIds, at, index, exerciseId, fields, day, routineIds, planId
    case key, value
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    func type(_ name: String) throws { try c.encode(name, forKey: .type) }
    switch self {
    case .createRoutine(let name):
      try type("routine.create"); try c.encode(name, forKey: .name)
    case .renameRoutine(let id, let name):
      try type("routine.rename"); try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
    case .setRoutineGlyph(let id, let glyph):
      try type("routine.glyph"); try c.encode(id, forKey: .id); try c.encode(glyph, forKey: .glyph)
    case .duplicateRoutine(let id):
      try type("routine.duplicate"); try c.encode(id, forKey: .id)
    case .moveRoutine(let from, let to):
      try type("routine.move"); try c.encode(from, forKey: .from); try c.encode(to, forKey: .to)
    case .deleteRoutine(let id):
      try type("routine.delete"); try c.encode(id, forKey: .id)
    case .restoreRoutine(let snapshot):
      try type("routine.restore"); try c.encode(snapshot, forKey: .snapshot)
    case .addExercises(let routineID, let exerciseIDs, let at):
      try type("slot.add"); try c.encode(routineID, forKey: .routineId); try c.encode(exerciseIDs, forKey: .exerciseIds)
      try c.encodeIfPresent(at, forKey: .at)
    case .removeSlot(let routineID, let index):
      try type("slot.remove"); try c.encode(routineID, forKey: .routineId); try c.encode(index, forKey: .index)
    case .moveSlot(let routineID, let from, let to):
      try type("slot.move"); try c.encode(routineID, forKey: .routineId); try c.encode(from, forKey: .from); try c.encode(to, forKey: .to)
    case .replaceSlot(let routineID, let index, let exerciseID):
      try type("slot.replace"); try c.encode(routineID, forKey: .routineId); try c.encode(index, forKey: .index)
      try c.encode(exerciseID, forKey: .exerciseId)
    case .superset(let routineID, let index):
      try type("slot.superset"); try c.encode(routineID, forKey: .routineId); try c.encode(index, forKey: .index)
    case .unsuperset(let routineID, let index):
      try type("slot.unsuperset"); try c.encode(routineID, forKey: .routineId); try c.encode(index, forKey: .index)
    case .updateSlot(let routineID, let index, let fields):
      try type("slot.update"); try c.encode(routineID, forKey: .routineId); try c.encode(index, forKey: .index)
      try c.encode(fields, forKey: .fields)
    case .setWeekDay(let day, let routineIDs):
      try type("week.set"); try c.encode(day, forKey: .day); try c.encode(routineIDs, forKey: .routineIds)
    case .loadStarterPlan(let id):
      try type("plan.starter"); try c.encode(id, forKey: .planId)
    case .setSetting(let change):
      try type("settings.set"); try c.encode(change.key, forKey: .key); try c.encode(change.value, forKey: .value)
    case .toggleFavourite(let id):
      try type("favourite.toggle"); try c.encode(id, forKey: .id)
    }
  }

  // O texto JSON que o apply manda ao motor. O do desfazer leva o texto do snapshot colado como
  // está, porque o JSONEncoder o passaria por um dicionário e trocaria a ordem das chaves; as outras
  // ações não levam objeto do motor, e vão pelo JSONEncoder.
  func text() throws -> Data {
    guard case .restoreRoutine(let snapshot) = self else { return try JSONEncoder().encode(self) }
    return Data(#"{"type":"routine.restore","snapshot":"#.utf8) + snapshot.json + Data("}".utf8)
  }
}

// O que a ação devolveu. O JS manda { changed, result: { id?, snapshot?, routines? } }; o Decodable lê
// o result por dentro e deixa plano.
public struct ActionOutcome: Decodable, Equatable, Sendable {
  public let changed: Bool
  public let id: String?
  // O apply troca o snapshot decodificado pelo texto dele na resposta (RoutineSnapshot(response:)).
  public internal(set) var snapshot: RoutineSnapshot?
  public let routines: Int?

  private enum Keys: String, CodingKey { case changed, result }
  private enum ResultKeys: String, CodingKey { case id, snapshot, routines }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    changed = try c.decode(Bool.self, forKey: .changed)
    let r = try c.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
    id = try r.decodeIfPresent(String.self, forKey: .id)
    snapshot = try r.decodeIfPresent(RoutineSnapshot.self, forKey: .snapshot)
    routines = try r.decodeIfPresent(Int.self, forKey: .routines)
  }
}

// Uma rotina para as telas: o glyph pelo glyphStr do openGym (um emoji antigo passa como está), os
// exercícios, a carga de cada grupo muscular e os dias da semana, na ordem do perfil.
public struct RoutineSummary: Codable, Hashable, Identifiable, Sendable {
  public let id: String, name: String, glyph: String, slots: [SlotSummary], muscles: [String: Double], days: [Int]
}

// Um exercício da rotina. O known é false num exercício que não existe mais, com o nome "Exercício
// desconhecido"; o increment é o passo da carga na unidade do perfil.
public struct SlotSummary: Codable, Hashable, Sendable {
  public let id: String, name: String, known: Bool, setsReps: String, increment: Double
  public let repStep: Int         // 2 num exercício por lado (o side do openGym), 1 nos outros
  public let sets: Int?, reps: Int?, repsMin: Int?, weight: Double?, sec: Int?
  public let mode: String?        // reps, time ou cardio (o cardio do openGym só é lido nesta fase)
  public let note: String?, superset: String?
}

// A semana fixa: os sete dias, na ordem do weekStart do perfil (0 domingo, 1 segunda).
public struct WeekPlan: Codable, Equatable, Sendable {
  public struct Day: Codable, Equatable, Sendable { public let day: Int, routineIds: [String] }
  public let weekStart: Int, days: [Day]
}

public struct DocumentSettings: Codable, Equatable, Sendable { public let unit: String, body: String, weekStart: Int, restSec: Int, effort: String? }

public struct StarterPlanOption: Codable, Hashable, Identifiable, Sendable { public let id: String, days: Int }

extension HexEngine {
  // Roda a ação no documento aberto, com o instante dela em ms para o carimbo.
  public func apply(_ action: EngineAction, now: Date = .now) throws -> ActionOutcome {
    let text = String(decoding: try action.text(), as: UTF8.self)
    let response = try run("apply", [text, (now.timeIntervalSince1970 * 1000).rounded()])
    var outcome: ActionOutcome = try decodedAction(response)
    if outcome.snapshot != nil { outcome.snapshot = try RoutineSnapshot(response: response) }
    return outcome
  }

  public func routines() throws -> [RoutineSummary] {
    try decodedAction(run("routines", []))
  }

  public func week() throws -> WeekPlan {
    try decodedAction(run("week", []))
  }

  public func settings() throws -> DocumentSettings {
    try decodedAction(run("settings", []))
  }

  public func starterPlans() throws -> [StarterPlanOption] {
    try decodedAction(run("starterPlans", []))
  }

  // A resposta do motor num modelo. Um texto que não decodifica é erro do motor, com o que faltou.
  private func decodedAction<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw EngineError.javaScript("HexEngine: a resposta não é um \(T.self): \(error)")
    }
  }
}
