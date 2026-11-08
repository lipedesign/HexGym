// O treino em andamento e as leituras das telas (Task 4 do plano da fase 3), do session.js. Toda a
// regra fica no JS do openGym (seção 8.2 do design doc): o controlador do treino
// (frontend/src/lib/session-controller.js), o carimbo do update() do store/useStore.js e os eventos
// da Live Activity. O Swift só codifica a ação no JSON que o controlador espera e decodifica os
// efeitos e as leituras nestes modelos pequenos. Uma ação inválida volta como
// EngineError.javaScript("TypeError: …"), e o documento dentro do motor fica como estava.
//
// Toda hora vai e volta em ms desde 1970 no JSON (o now, o endsAt, o start, o at), e vira Date aqui.

import Foundation

// O passo das entradas do treino. O HexEngine não importa o HexDesign: a tela converte o
// StepDirection das entradas neste.
public enum SessionStep: String, Codable, Sendable { case up, down }

// O campo que o set.step muda; effort é o esforço na escala do perfil (RIR ou RPE).
public enum SetField: String, Codable, Sendable { case w, r, sec, effort }

// Os campos que o set.update muda; nil fica de fora do JSON e não muda nada. Os limites são do
// controlador (carga de 0 a 1.000 na unidade do perfil, repetições de 0 a 100, segundos de 1 a 3.600,
// e o esforço na escala do perfil, de 0,5 em 0,5). O controlador apaga um campo com null, mas nenhuma
// tela desta fase apaga: as entradas do HexDesign só trocam o valor.
public struct SetFields: Codable, Equatable, Sendable {
  public var w: Double?
  public var r: Int?
  public var sec: Int?
  public var rir: Double?
  public var rpe: Double?

  public init(w: Double? = nil, r: Int? = nil, sec: Int? = nil, rir: Double? = nil, rpe: Double? = nil) {
    (self.w, self.r, self.sec, self.rir, self.rpe) = (w, r, sec, rir, rpe)
  }
}

// Uma ação do treino, no JSON do controlador: { "type": "set.mark", "entry": …, "set": …, "done": … }
// e assim por diante. As chaves dos ids levam "Id" (exerciseIds, exerciseId), como o controlador lê.
public enum SessionAction: Encodable, Sendable {
  case start(routineIDs: [String], id: String)
  case markSet(entry: Int, set: Int, done: Bool)
  case updateSet(entry: Int, set: Int, fields: SetFields)
  case stepSet(entry: Int, set: Int, field: SetField, direction: SessionStep)
  case addSet(entry: Int)
  case removeSet(entry: Int, set: Int)
  case focus(entry: Int)
  case addExercises([String])
  // O confirmLogged false é a pergunta do openGym quando o exercício já tem série feita: o result
  // volta { needs: "confirm", grouped }. O group é keep ou detach num superset, e nil fora dele.
  case replaceExercise(entry: Int, exerciseID: String, confirmLogged: Bool, group: String?)
  case removeExercise(entry: Int)
  case adjustRest(by: Int)
  case skipRest, finish, discard

  private enum Keys: String, CodingKey {
    case type, routineIds, id, entry, set, done, fields, field, direction, exerciseIds, exerciseId, confirmLogged, group, by
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    func type(_ name: String) throws { try c.encode(name, forKey: .type) }
    switch self {
    case .start(let routineIDs, let id):
      try type("start"); try c.encode(routineIDs, forKey: .routineIds); try c.encode(id, forKey: .id)
    case .markSet(let entry, let set, let done):
      try type("set.mark"); try c.encode(entry, forKey: .entry); try c.encode(set, forKey: .set); try c.encode(done, forKey: .done)
    case .updateSet(let entry, let set, let fields):
      try type("set.update"); try c.encode(entry, forKey: .entry); try c.encode(set, forKey: .set); try c.encode(fields, forKey: .fields)
    case .stepSet(let entry, let set, let field, let direction):
      try type("set.step"); try c.encode(entry, forKey: .entry); try c.encode(set, forKey: .set)
      try c.encode(field, forKey: .field); try c.encode(direction, forKey: .direction)
    case .addSet(let entry):
      try type("set.add"); try c.encode(entry, forKey: .entry)
    case .removeSet(let entry, let set):
      try type("set.remove"); try c.encode(entry, forKey: .entry); try c.encode(set, forKey: .set)
    case .focus(let entry):
      try type("focus"); try c.encode(entry, forKey: .entry)
    case .addExercises(let ids):
      try type("exercise.add"); try c.encode(ids, forKey: .exerciseIds)
    case .replaceExercise(let entry, let exerciseID, let confirmLogged, let group):
      try type("exercise.replace"); try c.encode(entry, forKey: .entry); try c.encode(exerciseID, forKey: .exerciseId)
      try c.encode(confirmLogged, forKey: .confirmLogged)
      if let group { try c.encode(group, forKey: .group) } else { try c.encodeNil(forKey: .group) }
    case .removeExercise(let entry):
      try type("exercise.remove"); try c.encode(entry, forKey: .entry)
    case .adjustRest(let by):
      try type("rest.adjust"); try c.encode(by, forKey: .by)
    case .skipRest:
      try type("rest.skip")
    case .finish:
      try type("finish")
    case .discard:
      try type("discard")
    }
  }
}

// Um efeito que o app executa, na ordem em que o controlador os deu: o háptico, o aviso do descanso
// (agendar no endsAt, ou cancelar), o fim do treino e a Live Activity. O kind do descanso é rest, ou
// switch na pausa de trocar de lado.
public enum SessionEffect: Decodable, Equatable, Sendable {
  case haptic(String), restStarted(endsAt: Date, total: Int, kind: String), restCleared, workoutComplete
  case activityStart, activityUpdate, activityEnd, workoutFinished(id: String)

  private enum Keys: String, CodingKey { case type, kind, endsAt, total, id }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let type = try c.decode(String.self, forKey: .type)
    switch type {
    case "haptic": self = .haptic(try c.decode(String.self, forKey: .kind))
    case "rest.started":
      self = .restStarted(endsAt: try c.decode(Date.self, forKey: .endsAt), total: try c.decode(Int.self, forKey: .total),
                          kind: try c.decode(String.self, forKey: .kind))
    case "rest.cleared": self = .restCleared
    case "workout.complete": self = .workoutComplete
    case "activity.start": self = .activityStart
    case "activity.update": self = .activityUpdate
    case "activity.end": self = .activityEnd
    case "workout.finished": self = .workoutFinished(id: try c.decode(String.self, forKey: .id))
    default:
      throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "efeito desconhecido: \(type)")
    }
  }
}

// O que a ação deu: se o documento mudou, os efeitos e o result do controlador, guardado como veio
// (o { id } do start, a pergunta do exercise.replace, o resumo do finish).
public struct SessionOutcome: Decodable, Equatable, Sendable {
  public let changed: Bool
  public let effects: [SessionEffect]
  public let result: JSONValue?
}

// O resumo do fim do treino, o result do finish (Task 3): a duração (end − start, em ms), o volume
// na unidade do perfil, as séries feitas e as de trabalho, os recordes de carga e os de 1RM estimado
// (sem arredondar), a comparação com a última vez e a próxima carga de cada exercício, e o que entrou
// no treino e pode ir para a rotina. Um exercício que não existe neste aparelho vem com o id no
// lugar do nome, como no openGym; quem diz "Exercício desconhecido" é a tela.
public struct FinishSummary: Codable, Equatable, Sendable {
  public struct Sets: Codable, Equatable, Sendable { public let done: Int, work: Int }
  public struct Record: Codable, Equatable, Sendable { public let id: String, name: String, w: Double }
  public struct Estimate: Codable, Equatable, Sendable { public let id: String, name: String, e1rm: Double }
  // Uma série de trabalho na comparação; o f diz que ela foi até a falha.
  public struct Lift: Codable, Equatable, Sendable { public let w: Double, r: Int; public let f: Bool? }
  // A próxima carga que a progressão do openGym vai pedir: kind é up, hold, down ou deload.
  public struct Next: Codable, Equatable, Sendable { public let w: Double?, r: Int?, sets: Int?; public let kind: String }
  public struct Compare: Codable, Equatable, Sendable {
    public let id: String, name: String
    public let today: [Lift]
    public let last: [Lift]?
    public let trend: Int?          // -1, 0 ou 1; nil sem a última vez
    public let next: Next?
  }
  // Os exercícios que entraram no treino e não estão na rotina dele; cada um é uma configuração de
  // rotina, guardada como veio.
  public struct Addition: Codable, Equatable, Sendable { public let routineId: String, name: String; public let ex: [JSONValue] }

  public let id: String, name: String
  public let start: Date, end: Date
  public let durationMs: Double
  public let volume: Double
  public let unit: String
  public let sets: Sets
  public let prs: [Record]
  public let e1rm: [Estimate]
  public let compare: [Compare]
  public let additions: [Addition]
}

// A série que o "Série feita" marca.
public struct SetRef: Codable, Equatable, Hashable, Sendable { public let entry: Int, set: Int }

// A tela do treino em andamento. O done e o total são as contas da barra do openGym (o lado de uma
// série com lados conta um). O effort é none, rir ou rpe, a escala do perfil.
public struct ActiveWorkout: Codable, Equatable, Sendable {
  // O descanso que existe agora; o remaining é o que falta em segundos, nunca abaixo de 0 (o descanso
  // comum que acabou fica, como o "Pronto" do openGym, até alguém mexer nele).
  public struct Rest: Codable, Equatable, Sendable {
    public let endsAt: Date
    public let total: Int
    public let forIdx: Int?, forSet: Int?
    public let kind: String         // rest ou switch
    public let remaining: Int
  }
  public struct Entry: Codable, Equatable, Identifiable, Sendable {
    public let index: Int
    public let id: String, name: String
    public let known: Bool          // false num exercício que não existe neste aparelho ("Exercício desconhecido")
    public let mode: String         // reps, time ou cardio
    public let sg: String?, sgLetter: String?
    public let target: String       // "3 × 8 · 60 kg"
    public let increment: Double
    public let sets: [SetRow]
  }
  public struct SetRow: Codable, Equatable, Sendable {
    public let index: Int
    public let w: Double?, r: Int?, sec: Int?, rir: Double?, rpe: Double?
    public let done: Bool, warmup: Bool
    public let kind: String         // normal, drop, restpause, sides ou cardio
    public let line: String         // "60 kg × 8"
  }

  public let id: String, name: String
  public let start: Date?
  public let unit: String, effort: String
  public let cur: Int, done: Int, total: Int
  public let rest: Rest?
  public let next: SetRef?
  public let entries: [Entry]
}

// A tela inicial. O status de hoje é planned, rest, none ou done; a semana tem os 7 dias na ordem do
// weekStart do perfil; o total é o número de treinos do histórico.
public struct HomeSummary: Codable, Equatable, Sendable {
  public struct Routine: Codable, Equatable, Sendable { public let id: String, name: String, glyph: String }
  public struct Today: Codable, Equatable, Sendable { public let date: String, status: String; public let routines: [Routine] }
  public struct Active: Codable, Equatable, Sendable { public let name: String; public let start: Date?; public let done: Int, total: Int }
  public struct Day: Codable, Equatable, Sendable { public let day: Int, date: String; public let trained: Bool, planned: Bool, today: Bool }
  public struct Last: Codable, Equatable, Sendable { public let id: String?, name: String, d: String?; public let durationMs: Double; public let sets: Int }

  public let today: Today
  public let active: Active?
  public let week: [Day]
  public let streakWeeks: Int, weekCount: Int, total: Int
  public let last: Last?
}

// A Live Activity: o cur é a série que o "Série feita" marca, e o ahead são as até 8 que vêm depois
// dela, cada uma com o descanso que vem depois dela e o id do exercício (exId), para um evento achar
// a entrada quando as posições mudaram. O done e o total contam linhas, como a Live Activity do
// openGym. Sem descanso contando (ou na pausa de trocar de lado), restEndsAt e restTotal são nil.
public struct LiveActivityModel: Codable, Equatable, Sendable {
  public struct Item: Codable, Equatable, Hashable, Sendable {
    public let entry: Int, set: Int
    public let exId: String
    public let exercise: String, setLine: String
    public let restAfter: Int
  }
  public let name: String
  public let done: Int, total: Int
  public let restEndsAt: Date?, restTotal: Int?
  public let cur: Item?
  public let ahead: [Item]
}

// Um toque num botão da Live Activity, guardado até o motor aplicar: kind é set.done, rest.skip ou
// rest.adjust. O exId é o do exercício da série, para o motor achar a entrada se as posições mudaram;
// sem ele, vale a posição. O at é a hora do toque.
public struct LiveEvent: Codable, Equatable, Sendable {
  public let id: String, wid: String, kind: String
  public let entry: Int?, set: Int?, by: Int?
  public let exId: String?
  public let at: Date

  public init(id: String, wid: String, kind: String, entry: Int? = nil, set: Int? = nil, by: Int? = nil, exId: String? = nil, at: Date) {
    (self.id, self.wid, self.kind, self.entry, self.set, self.by, self.exId, self.at) = (id, wid, kind, entry, set, by, exId, at)
  }
}

extension HexEngine {
  // Roda a ação no documento aberto, com o instante dela em ms para o controlador e o carimbo.
  public func session(_ action: SessionAction, now: Date = .now) throws -> SessionOutcome {
    let text = String(decoding: try Self.sessionEncoder.encode(action), as: UTF8.self)
    return try decodedSession(run("sessionApply", [text, Self.ms(now)]))
  }

  public func activeWorkout(now: Date = .now) throws -> ActiveWorkout? {
    try decodedSession(run("activeWorkout", [Self.ms(now)]))
  }

  public func home(now: Date = .now) throws -> HomeSummary {
    try decodedSession(run("home", [Self.ms(now)]))
  }

  public func liveActivity(now: Date = .now) throws -> LiveActivityModel? {
    try decodedSession(run("liveActivity", [Self.ms(now)]))
  }

  // Aplica os toques da Live Activity, cada um uma vez só, e devolve os efeitos para o app executar.
  public func liveEvents(_ events: [LiveEvent], now: Date = .now) throws -> [SessionEffect] {
    let text = String(decoding: try Self.sessionEncoder.encode(events), as: UTF8.self)
    let reply: LiveReply = try decodedSession(run("liveEvents", [text, Self.ms(now)]))
    return reply.effects
  }

  // O resumo do fim do treino, do result do finish; nil numa outra ação, ou num finish que não mudou
  // nada.
  public nonisolated func finishSummary(from outcome: SessionOutcome) throws -> FinishSummary? {
    guard let result = outcome.result, case .object(let fields) = result, fields["durationMs"] != nil else { return nil }
    do {
      return try Self.sessionDecoder.decode(FinishSummary.self, from: JSONEncoder().encode(result))
    } catch {
      throw EngineError.javaScript("HexEngine: o result do finish não é um FinishSummary: \(error)")
    }
  }

  private struct LiveReply: Decodable { let effects: [SessionEffect] }

  // As horas vão e voltam em ms, como o now do motor. Um codificador novo a cada chamada: o
  // JSONEncoder e o JSONDecoder não são Sendable para ficar num static.
  static var sessionEncoder: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .millisecondsSince1970
    return e
  }
  static var sessionDecoder: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .millisecondsSince1970
    return d
  }

  static func ms(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }

  // A resposta do motor num modelo. Um texto que não decodifica é erro do motor, com o que faltou.
  private func decodedSession<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try Self.sessionDecoder.decode(T.self, from: data)
    } catch {
      throw EngineError.javaScript("HexEngine: a resposta não é um \(T.self): \(error)")
    }
  }
}
