// O que o app faz ao abrir (seção 9 do design doc e Task 10 do plano da fase 0): carrega o motor e
// abre o documento de dados do App Group, e a tela mostra numa linha o que aconteceu.
//
// O motor (HexEngine) e o armazenamento (DocumentStore) são atores: cada chamada a eles roda fora da
// thread principal, e só o state muda aqui, no ator principal.
//
// A ordem do start(), pelo que o store.load() achou:
//   - nada: o motor cria o documento, que é gravado como veio, origem .created. O documento novo não
//     leva horário: um carimbo de agora ganharia, numa sincronização futura, de um documento de
//     verdade do servidor;
//   - o state.json: o motor abre o documento, e nada é gravado, origem .opened;
//   - a cópia anterior: o motor abre e os mesmos bytes são gravados, para o próximo início abrir
//     normal, origem .recovered.
// Qualquer erro, inclusive um documento que o HexStore aceita e o JSON.parse do motor recusa, vira
// .failed, com o detalhe no log, e depois dele nada é gravado: o app nunca começa do zero em silêncio
// (Foco da revisão 1). Sem o App Group, o app mostra o erro e não grava nada, nunca numa pasta
// inventada.

import Foundation
import HexEngine
import HexStore
import Observation
import os

@Observable @MainActor final class AppModel {
  // Em failed, o detalhe do erro, para o log e os testes. A tela não mostra.
  enum State: Equatable { case starting, ready(Status), failed(String) }
  struct Status: Equatable { var exercises: Int; var origin: Origin }
  enum Origin: Equatable { case created, opened, recovered }

  private(set) var state: State = .starting

  private let engine: HexEngine
  // nil: o App Group não abriu.
  private let store: DocumentStore?
  // O start() roda uma vez só, mesmo que a janela peça de novo.
  private var started = false

  private static let logger = Logger(subsystem: "app.hexgym", category: "app")

  init(engine: HexEngine, store: DocumentStore?) {
    self.engine = engine
    self.store = store
  }

  func start() async {
    guard !started else { return }
    started = true
    guard let store else {
      fail("o App Group não abriu, e nada foi gravado", kind: "appGroupUnavailable")
      return
    }
    do {
      let info = try await engine.load()
      let origin: Origin
      switch try await store.load() {
      case .empty:
        try await store.save(try await engine.freshDocument())
        origin = .created
      case .current(let document):
        try await engine.restore(document)
        origin = .opened
      case .recovered(let document):
        try await engine.restore(document)
        try await store.save(document)
        origin = .recovered
      }
      state = .ready(Status(exercises: info.exercises, origin: origin))
    } catch {
      fail(String(describing: error), kind: String(describing: type(of: error)))
    }
  }

  // O app de verdade: o documento na pasta do App Group. Quando ela não abre, o store é nil, e o
  // appGroupDirectory já disse no log por quê.
  static func live() -> AppModel {
    let store = (try? DocumentStore.appGroupDirectory()).map { DocumentStore(directory: $0) }
    return AppModel(engine: HexEngine(), store: store)
  }

  // O erro vai para o log e para o state. O tipo do erro fica público no log; o detalhe, privado,
  // porque a mensagem do motor pode trazer um pedaço do documento.
  private func fail(_ detail: String, kind: String) {
    Self.logger.error("não deu para abrir os dados (\(kind, privacy: .public)): \(detail, privacy: .private)")
    state = .failed(detail)
  }
}
