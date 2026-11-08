// Os documentos preparados para os prints e os testes (Task 6 do plano da fase 3), só no build Debug.
// Com -HexGymFixture <nome> nos argumentos de início (xcrun simctl launch ... -HexGymFixture descanso),
// o AppModel.live() abre o documento preparado com esse nome numa pasta temporária nova, nunca no App
// Group: o documento de verdade de quem usa o simulador fica como está.
//
// Os documentos (FixtureDocuments) foram gravados num dia só, e o carregador leva cada um para hoje
// na carga. O texto traz a chave _fixtureNow, o instante em ms em que o documento "está", e ela sai
// do documento depois da troca:
//   - as datas (o d do active, de cada treino e de cada pesagem do bodyweight, e as chaves do dayPlan)
//     andam os dias inteiros entre o dia do _fixtureNow e hoje, no calendário do aparelho;
//   - as horas do active (start, at e endsAt, em qualquer nível) andam agora − _fixtureNow, em ms: o
//     descanso que faltava 75 s no _fixtureNow falta 75 s agora;
//   - as horas de cada treino do workouts vão com o d: o start cai no dia do d novo, na mesma hora local
//     que tinha, no fuso do aparelho, e o end e o at das séries andam o mesmo que o start, e a duração
//     fica. Andar por ms, como o plano dizia, punha o start em outro dia que o d conforme a hora do
//     print (rodada 2 do PR #156).
// Por isso, a chave de um treino antigo sem id (que sai do d e do start) muda a cada dia, e os
// treinos que os prints abrem têm id.
//
// Este arquivo e o FixtureDocuments.swift ficam inteiros dentro do #if DEBUG, e a chamada do live()
// também: nenhum documento preparado entra no build Release (teste no project-format.test.mjs).

#if DEBUG
import Foundation
import HexStore
import os

enum FixtureLoader {
  enum Failure: Error, Equatable {
    case unknown(String), malformed(String)
  }

  private static let logger = Logger(subsystem: "app.hexgym", category: "dados")

  // As chaves de hora que andam em ms, e a de data que anda em dias.
  private static let timeKeys: Set<String> = ["start", "end", "at", "endsAt"]

  // O nome pedido com -HexGymFixture, do domínio dos argumentos dos UserDefaults padrão.
  static func requested(_ defaults: UserDefaults = .standard) -> String? {
    defaults.string(forKey: "HexGymFixture")
  }

  // O DocumentStore numa pasta temporária nova, com o documento preparado já gravado como state.json
  // (o nome do documento no HexStore). Um nome que não existe, ou um erro ao gravar, vai para o log e
  // dá nil: o app mostra o erro de abrir os dados, e nunca abre o App Group no lugar do pedido.
  static func store(named name: String, now: Date = .now) -> DocumentStore? {
    do {
      let folder = FileManager.default.temporaryDirectory
        .appending(path: "hexgym-fixture-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try document(named: name, now: now).write(to: folder.appending(path: "state.json"), options: .atomic)
      logger.info("documento preparado \(name, privacy: .public) aberto numa pasta temporária")
      return DocumentStore(directory: folder)
    } catch {
      logger.error("não deu para abrir o documento preparado \(name, privacy: .public): \(String(describing: error), privacy: .public)")
      return nil
    }
  }

  // O documento preparado levado para o now, sem o _fixtureNow.
  static func document(named name: String, now: Date = .now, calendar: Calendar = .current) throws -> Data {
    guard let text = FixtureDocuments.text(named: name) else { throw Failure.unknown(name) }
    guard var doc = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
          let fixtureMs = (doc["_fixtureNow"] as? NSNumber)?.doubleValue
    else { throw Failure.malformed(name) }
    doc["_fixtureNow"] = nil
    let ms = (now.timeIntervalSince1970 * 1000).rounded() - fixtureMs
    let fixtureDay = calendar.startOfDay(for: Date(timeIntervalSince1970: fixtureMs / 1000))
    guard let days = calendar.dateComponents([.day], from: fixtureDay, to: calendar.startOfDay(for: now)).day
    else { throw Failure.malformed(name) }

    if let active = doc["active"] as? [String: Any] {
      doc["active"] = movingDay(moving(active, by: ms) as? [String: Any] ?? active, by: days)
    }
    if let workouts = doc["workouts"] as? [Any] {
      doc["workouts"] = workouts.map { item -> Any in
        guard let workout = item as? [String: Any] else { return item }
        return movingWorkout(workout, by: days, calendar: calendar)
      }
    }
    if let weights = doc["bodyweight"] as? [Any] {
      doc["bodyweight"] = weights.map { item -> Any in (item as? [String: Any]).map { movingDay($0, by: days) } ?? item }
    }
    if let plan = doc["dayPlan"] as? [String: Any] {
      doc["dayPlan"] = Dictionary(plan.map { (day($0.key, plus: days) ?? $0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
    }
    return try JSONSerialization.data(withJSONObject: doc)
  }

  // As horas de um valor, em qualquer nível: cada número numa chave de hora anda ms.
  private static func moving(_ value: Any, by ms: Double) -> Any {
    if let object = value as? [String: Any] {
      var moved = object
      for (key, inner) in object {
        if timeKeys.contains(key), let number = inner as? NSNumber, !isBool(number) {
          moved[key] = integral(number.doubleValue + ms)
        } else if inner is [String: Any] || inner is [Any] {
          moved[key] = moving(inner, by: ms)
        }
      }
      return moved
    }
    if let list = value as? [Any] { return list.map { moving($0, by: ms) } }
    return value
  }

  // Um treino do histórico: o d anda os dias, e as horas andam o que leva o start para o dia do d novo,
  // na mesma hora local. Sem start, só o d anda.
  private static func movingWorkout(_ workout: [String: Any], by days: Int, calendar: Calendar) -> [String: Any] {
    let dated = movingDay(workout, by: days)
    guard let number = workout["start"] as? NSNumber, !isBool(number), let d = dated["d"] as? String,
          let target = wallClock(of: number.doubleValue, on: d, calendar: calendar)
    else { return dated }
    return moving(dated, by: target - number.doubleValue) as? [String: Any] ?? dated
  }

  // O instante em ms no dia d (AAAA-MM-DD), na hora local que o instante ms tem, no fuso do calendário.
  private static func wallClock(of ms: Double, on d: String, calendar: Calendar) -> Double? {
    let parts = d.split(separator: "-").compactMap { Int($0) }
    guard d.count == 10, parts.count == 3 else { return nil }
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    let time = gregorian.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: ms / 1000))
    guard let date = gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                                         hour: time.hour, minute: time.minute, second: time.second))
    else { return nil }
    return (date.timeIntervalSince1970 * 1000).rounded() + ms.truncatingRemainder(dividingBy: 1000)
  }

  // O d do objeto, quando é uma data, anda os dias.
  private static func movingDay(_ object: [String: Any], by days: Int) -> [String: Any] {
    guard let d = object["d"] as? String, let moved = day(d, plus: days) else { return object }
    var copy = object
    copy["d"] = moved
    return copy
  }

  // Uma data AAAA-MM-DD com mais n dias, no calendário gregoriano sem fuso (a data é só a data); nil
  // quando o texto não é uma data.
  static func day(_ iso: String, plus days: Int) -> String? {
    let parts = iso.split(separator: "-").compactMap { Int($0) }
    guard iso.count == 10, parts.count == 3 else { return nil }
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = .gmt
    guard let date = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
          let moved = utc.date(byAdding: .day, value: days, to: date)
    else { return nil }
    let c = utc.dateComponents([.year, .month, .day], from: moved)
    guard let y = c.year, let m = c.month, let d = c.day else { return nil }
    return String(format: "%04d-%02d-%02d", y, m, d)
  }

  // Um ms inteiro volta como inteiro no JSON.
  private static func integral(_ value: Double) -> NSNumber {
    value.rounded() == value && abs(value) < 9e15 ? NSNumber(value: Int64(value)) : NSNumber(value: value)
  }

  // O true e o false do JSONSerialization também são NSNumber.
  private static func isBool(_ number: NSNumber) -> Bool {
    CFGetTypeID(number) == CFBooleanGetTypeID()
  }
}
#endif
