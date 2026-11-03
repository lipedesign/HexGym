// Os testes do HexStore, o documento de dados no App Group (seção 8.3 do design doc). Os 14 testes
// são os do passo 1 da Task 8 do plano da fase 0, com o texto de lá, e os marcados com o Foco da
// revisão prendem os itens 1 e 2 dele. Cada teste roda num diretório temporário novo: o Swift Testing
// cria uma DocumentStoreTests para cada um, e o deinit apaga o diretório no fim.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexStore

import Foundation
import Testing
import HexStore

@Suite final class DocumentStoreTests {
  // Três documentos JSON pequenos e diferentes. O b tem mais de 10 bytes, e os 10 primeiros dele não
  // são JSON: são o arquivo truncado.
  let a = Data(#"{"lang":"pt","workouts":[{"id":"a"}]}"#.utf8)
  let b = Data(#"{"lang":"en","workouts":[{"id":"b"}]}"#.utf8)
  let c = Data(#"{"lang":"es","workouts":[]}"#.utf8)
  let directory = FileManager.default.temporaryDirectory.appending(path: "hexstore-\(UUID().uuidString)", directoryHint: .isDirectory)
  // O DocumentStore do diretório deste teste. É lazy porque o valor inicial de uma propriedade não
  // pode ler outra.
  lazy var store = DocumentStore(directory: directory)

  init() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  // Um diretório que não saiu não muda nenhum teste, porque cada um usa um novo, e o sistema limpa a
  // pasta temporária. Por isso o erro aqui fica de fora.
  deinit { try? FileManager.default.removeItem(at: directory) }

  // O arquivo lido direto do diretório, sem o DocumentStore, ou nil quando não deu para ler.
  func read(_ name: String) -> Data? { try? Data(contentsOf: directory.appending(path: name)) }

  // Grava direto no diretório, por cima do que houver. Um erro vira uma falha do teste.
  func write(_ name: String, _ data: Data) {
    do { try data.write(to: directory.appending(path: name)) } catch { Issue.record(error, "não deu para gravar \(name)") }
  }

  // As permissões do arquivo: 0o000 ninguém lê, 0o644 é a de sempre.
  func lock(_ name: String) { permissions(0o000, name) }
  func unlock(_ name: String) { permissions(0o644, name) }

  func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: path(name)) }

  func path(_ name: String) -> String { directory.appending(path: name).path(percentEncoded: false) }

  func permissions(_ mode: Int, _ name: String) {
    do { try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: path(name)) }
    catch { Issue.record(error, "não deu para mudar as permissões de \(name)") }
  }

  @Test func emptyDirectoryHasNoDocument() async throws { #expect(try await store.load() == .empty) }
  @Test func saveThenLoadGivesTheSameBytes() async throws { try await store.save(a); #expect(try await store.load() == .current(a)) }
  @Test func secondSaveKeepsThePreviousCopy() async throws {
    try await store.save(a); try await store.save(b)
    #expect(read("state.json") == b); #expect(read("state.previous.json") == a)
  }
  @Test func truncatedDocumentRecoversFromThePreviousCopy() async throws {   // Foco da revisão 1
    try await store.save(a); try await store.save(b); write("state.json", b.prefix(10))
    #expect(try await store.load() == .recovered(a))
    #expect(read("state.unreadable.json") == b.prefix(10))
  }
  @Test func bothCopiesBrokenThrowsAndTouchesNothing() async throws {      // Foco da revisão 1
    write("state.json", Data("{".utf8)); write("state.previous.json", Data("x".utf8))
    await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
    #expect(read("state.json") == Data("{".utf8)); #expect(read("state.previous.json") == Data("x".utf8))
  }
  @Test func brokenDocumentWithoutAPreviousCopyThrows() async throws {     // Foco da revisão 1
    write("state.json", Data("{".utf8))
    await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
    #expect(read("state.json") == Data("{".utf8))
  }
  @Test func missingDocumentWithAPreviousCopyRecovers() async throws {     // Foco da revisão 1
    write("state.previous.json", a)
    #expect(try await store.load() == .recovered(a))
  }
  @Test func savingOverABrokenDocumentKeepsTheGoodPreviousCopy() async throws {   // Foco da revisão 1
    try await store.save(a); try await store.save(b); write("state.json", Data("{".utf8))
    try await store.save(c)
    #expect(read("state.json") == c); #expect(read("state.previous.json") == a)
  }
  @Test func onlyJSONObjectsAreSaved() async throws {
    await #expect(throws: DocumentStoreError.notAnObject) { try await store.save(Data("[1]".utf8)) }
    #expect(try await store.load() == .empty)
  }
  @Test func unknownKeysSurvive() async throws {                            // Foco da revisão 2
    let doc = Data(#"{"settings":{},"chaveDoFuturo":{"x":[1,2]}}"#.utf8)
    try await store.save(doc); #expect(try await store.load() == .current(doc))
  }
  @Test func aHalfEmojiIsSavedAndReadAsIs() async throws {                    // Foco da revisão 2
    let doc = Data(#"{"dayNotes":{"2026-10-31":{"text":"\ud83d"}},"x":"\ude00"}"#.utf8)
    try await store.save(doc); #expect(read("state.json") == doc); #expect(try await store.load() == .current(doc))
  }
  @Test func aDocumentThatCannotBeReadNowThrowsAndTouchesNothing() async throws {   // Foco da revisão 1
    try await store.save(a); try await store.save(b); lock("state.json")
    await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
    await #expect(throws: DocumentStoreError.unreadable) { try await store.save(c) }
    unlock("state.json"); #expect(read("state.json") == b); #expect(read("state.previous.json") == a)
    #expect(!exists("state.unreadable.json"))
  }
  @Test func syncBaseRoundTrips() async throws {
    try await store.saveSyncBase(SyncBase(rev: 7, ts: 1_730_000_000_000, wid: "w1"))
    #expect(try await store.syncBase() == SyncBase(rev: 7, ts: 1_730_000_000_000, wid: "w1"))
  }
  @Test func missingAppGroupThrows() {
    #expect(throws: DocumentStoreError.appGroupUnavailable("group.app.hexgym")) {
      try DocumentStore.appGroupDirectory(lookup: { _ in nil })
    }
  }
}
