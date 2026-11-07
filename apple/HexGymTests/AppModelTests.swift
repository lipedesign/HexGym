// Os testes do AppModel, que liga o motor e o documento de dados quando o app abre. Os cinco
// primeiros são os do passo 1 da Task 10 do plano da fase 0, com o texto de lá; o sexto entrou pelas
// notas do PR #69: um documento que o HexStore aceita e o motor não lê. Os marcados com o Foco da
// revisão prendem o item 1 dele. Os dois últimos são da Task 5 do plano da fase 2: a gravação das
// ações, que junta as de 0,5 s numa só, e o flush(), que grava na hora.
//
// O alvo roda dentro do app (TEST_HOST) e vê o HexEngine e o HexStore pelo app, sem uma segunda cópia
// deles. Cada teste roda num diretório temporário novo: o Swift Testing cria uma AppModelTests para
// cada um, e a pasta é criada antes, porque o save do HexStore não cria pasta. Ela sai no fim, com o
// TemporaryFolder.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexEngine
import HexStore
import Testing
@testable import HexGym

@Suite @MainActor struct AppModelTests {
  let folder: TemporaryFolder
  let store: DocumentStore

  init() throws {
    folder = try TemporaryFolder()
    store = DocumentStore(directory: folder.url)
  }

  // O arquivo lido direto do diretório, sem o DocumentStore. Quando não deu para ler, o teste falha,
  // e a resposta é vazia.
  func read(_ name: String) -> Data {
    do { return try Data(contentsOf: folder.url.appending(path: name)) } catch {
      Issue.record(error, "não deu para ler \(name)")
      return Data()
    }
  }

  // Grava direto no diretório, por cima do que houver. Um erro vira uma falha do teste.
  func write(_ name: String, _ data: Data) {
    do { try data.write(to: folder.url.appending(path: name)) } catch { Issue.record(error, "não deu para gravar \(name)") }
  }

  @Test func firstRunCreatesAndSavesADocument() async throws {
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    guard case .ready(let s) = model.state else { Issue.record("\(model.state)"); return }
    #expect(s.origin == .created); #expect(s.exercises > 5000)
    #expect(try JSONSerialization.jsonObject(with: read("state.json")) is [String: Any])
  }
  @Test func secondRunOpensWithoutWriting() async throws {
    await AppModel(engine: HexEngine(), store: store).start(); let before = read("state.json")
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    #expect(model.state.origin == .opened); #expect(read("state.json") == before)
  }
  @Test func bothCopiesBrokenFailsWithoutWriting() async throws {          // Foco da revisão 1
    write("state.json", Data("{".utf8)); write("state.previous.json", Data("x".utf8))
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    guard case .failed = model.state else { Issue.record("\(model.state)"); return }
    #expect(read("state.json") == Data("{".utf8))
  }
  @Test func recoveredDocumentIsRestoredAndSaved() async throws {          // Foco da revisão 1
    await AppModel(engine: HexEngine(), store: store).start(); let good = read("state.json")
    try await store.save(good)                                   // deixa a cópia anterior
    write("state.json", Data("{".utf8))
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    #expect(model.state.origin == .recovered); #expect(read("state.json") == good)
    #expect(read("state.unreadable.json") == Data("{".utf8))
  }
  @Test func missingAppGroupFailsWithoutWriting() async {
    let model = AppModel(engine: HexEngine(), store: nil); await model.start()
    guard case .failed = model.state else { Issue.record("\(model.state)"); return }
  }
  // Uma vírgula sobrando: o JSONSerialization do HexStore lê, e o JSON.parse do motor não. O load dá
  // .current, o restore lança, e o app mostra o erro sem gravar nada (notas do PR #69).
  @Test func aDocumentTheEngineCannotReadFailsWithoutWriting() async throws {   // Foco da revisão 1
    let bad = Data(#"{"a":1,}"#.utf8)
    write("state.json", bad)
    #expect(try await store.load() == .current(bad))
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    guard case .failed = model.state else { Issue.record("\(model.state)"); return }
    #expect(read("state.json") == bad)
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path(percentEncoded: false)) == ["state.json"])
  }
  // Duas ações seguidas, bem antes de 0,5 s, saem numa gravação só: o save guarda o state.json de
  // antes como cópia anterior, e ela é o documento criado, e não o de depois da primeira ação.
  @Test func twoActionsWithinHalfASecondSaveOnce() async throws {
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    let created = read("state.json")
    #expect(try await model.perform(.createRoutine(name: "A")).changed)
    #expect(try await model.perform(.createRoutine(name: "B")).changed)
    #expect(model.revision == 2)
    #expect(read("state.json") == created)
    let previous = folder.url.appending(path: "state.previous.json").path(percentEncoded: false)
    for _ in 0..<40 where !FileManager.default.fileExists(atPath: previous) { try await Task.sleep(for: .milliseconds(50)) }
    try await Task.sleep(for: AppModel.saveDelay)                 // uma segunda gravação teria tempo de sair
    #expect(read("state.previous.json") == created)
    #expect(read("state.json") == (try await model.engine.document()))
    #expect(try await model.engine.routines().map(\.name) == ["A", "B"])
  }
  @Test func flushSavesRightAway() async throws {
    let model = AppModel(engine: HexEngine(), store: store); await model.start()
    let created = read("state.json")
    _ = try await model.perform(.createRoutine(name: "A"))
    await model.flush()
    let saved = read("state.json")
    #expect(saved != created); #expect(saved == (try await model.engine.document()))
    // Uma ação ainda rodando no motor quando o app vai para o fundo: o flush() espera por ela e grava o
    // que ela mudou. O yield deixa o perform começar e parar no engine.apply antes do flush().
    let late = Task { try await model.perform(.createRoutine(name: "B")) }
    await Task.yield()
    await model.flush()
    let flushed = read("state.json")
    let routines = (try JSONSerialization.jsonObject(with: flushed) as? [String: Any])?["routines"] as? [[String: Any]]
    #expect(routines?.compactMap { $0["name"] as? String } == ["A", "B"])
    #expect(try await late.value.changed)
    // A gravação marcada para depois foi cancelada: nada mais sai, e a cópia anterior fica a do
    // primeiro flush().
    try await Task.sleep(for: AppModel.saveDelay * 2)
    #expect(read("state.json") == flushed); #expect(read("state.previous.json") == saved)
  }
}

// Um diretório temporário novo, criado no init e apagado quando a última cópia do teste sai. Um
// diretório que não saiu não muda nenhum teste, porque cada um usa um novo, e o sistema limpa a pasta
// temporária. Por isso o erro do deinit fica de fora.
final class TemporaryFolder: Sendable {
  let url = FileManager.default.temporaryDirectory.appending(path: "appmodel-\(UUID().uuidString)", directoryHint: .isDirectory)

  init() throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  deinit { try? FileManager.default.removeItem(at: url) }
}

// O atalho de teste: a origem de um .ready, ou nil nos outros estados.
extension AppModel.State {
  var origin: AppModel.Origin? {
    guard case .ready(let status) = self else { return nil }
    return status.origin
  }
}
