// O motor do openGym no iPhone (seção 8.2 do design doc): o script do motor, gerado por
// scripts/build-hexgym-engine.mjs, num JSContext só, que vive dentro deste ator e nunca roda na
// thread principal. O Swift e o JavaScript trocam só texto JSON, nunca um JSValue de objeto: o
// documento de dados fica dentro do JS, e o Swift pede o texto dele para gravar.
//
// O script vai no pacote comprimido em DEFLATE cru (hexengine.js.deflate), com o sha256 do texto ao
// lado (hexengine.js.sha256), e o bundledScript() é o único lugar que o descomprime. O host.js traz
// o console e os timers, que o JavaScriptCore não tem, pelas duas pontes que o bridge(_:) põe no
// contexto. Uma exceção do JS vira EngineError.javaScript("<mensagem>\n<pilha>"), e o contexto segue
// usável na chamada seguinte. O load() carrega também o pacote do idioma do aparelho e o en, de
// Resources/langs (Language.swift).

import Foundation
import JavaScriptCore
import os

public struct EngineInfo: Equatable, Sendable {
  public let exercises: Int
  public let openGymVersion: String
  // O idioma de LANGS do openGym em que o motor responde, escolhido pelas línguas do aparelho
  // (EngineLanguage.tag(for:)).
  public let language: String
}

// O languagePack diz o que há de errado com os pacotes de idioma (Language.swift): o index.json que
// falta ou não lê, um pacote que falta ou não descomprime, ou um que não bate com o sha256 do índice.
public enum EngineError: Error, Equatable, Sendable {
  case scriptMissing, notLoaded, javaScript(String), languagePack(String)
}

public actor HexEngine {
  static let logger = Logger(subsystem: "app.hexgym", category: "motor")

  // As línguas do aparelho, na ordem de preferência.
  private let languages: [String]
  private var context: JSContext?
  // O global HexEngine que o script cria, com o que runtime.js exporta, o call e os __modules.
  private var engine: JSValue?
  private var info: EngineInfo?
  // Conta os contextos criados. Um timer guarda o número do contexto que o pediu, e o de um load()
  // que falhou não dispara no contexto de outro load().
  private var generation = 0

  public init(languages: [String] = Locale.preferredLanguages) {
    self.languages = languages
  }

  // Uma língua só, como se o aparelho tivesse só ela.
  public init(language: String) {
    self.init(languages: [language])
  }

  // Avalia o host.js e o script do motor num contexto novo, diz ao motor a língua do aparelho,
  // carrega o pacote do idioma e o en e lê o info(). Da segunda vez em diante, devolve o mesmo, sem
  // avaliar de novo. Um load() que falha não guarda nada, e o seguinte começa outro contexto.
  public func load() throws -> EngineInfo {
    if let info { return info }
    let script = try Self.bundledScript().script
    guard let url = Bundle.module.url(forResource: "host", withExtension: "js"),
          let host = try? String(contentsOf: url, encoding: .utf8)
    else { throw EngineError.scriptMissing }
    guard let context = JSContext() else { throw EngineError.javaScript("HexEngine: não deu para criar o JSContext") }
    generation += 1
    bridge(context, generation: generation)
    // Com os nomes do withSourceURL, a pilha de um erro diz host.js ou hexengine.js, com as linhas
    // do texto descomprimido.
    _ = context.evaluateScript(host, withSourceURL: URL(string: "host.js"))
    try check(context)
    _ = context.evaluateScript(String(decoding: script, as: UTF8.self), withSourceURL: URL(string: "hexengine.js"))
    try check(context)
    guard let engine = context.objectForKeyedSubscript("HexEngine"), engine.isObject
    else { throw EngineError.javaScript("HexEngine: o script não criou o global HexEngine") }
    // O idioma das telas e dos nomes sai do pacote e nunca é gravado no documento (escolha 4 do plano
    // da fase 2): o documento novo sai sem lang (runtime.js, freshDocument).
    let language = EngineLanguage.tag(for: languages)
    let en = try EngineLanguage.packText("en")
    let own: Any = language == "en" ? NSNull() : try EngineLanguage.packText(language)
    _ = engine.invokeMethod("setLanguage", withArguments: [en, own, language])
    try check(context)
    let text = try Self.text(engine.invokeMethod("info", withArguments: []), from: "info", in: context)
    guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
          let exercises = json["exercises"] as? Int, let version = json["openGymVersion"] as? String
    else { throw EngineError.javaScript("HexEngine: o info() devolveu \(text)") }
    let info = EngineInfo(exercises: exercises, openGymVersion: version, language: language)
    (self.context, self.engine, self.info) = (context, engine, info)
    return info
  }

  // Cria o documento dentro do motor (o primeiro uso, como o do app web) e devolve o texto dele.
  public func freshDocument() throws -> Data {
    try run("freshDocument", [])
  }

  // Troca o documento dentro do motor. Texto que não é um objeto JSON lança o erro do JS, e o
  // documento aberto continua o mesmo.
  public func restore(_ document: Data) throws {
    let (context, engine) = try opened()
    _ = engine.invokeMethod("restore", withArguments: [String(decoding: document, as: UTF8.self)])
    try check(context)
  }

  // O texto do documento de agora, o mesmo que o app web grava, para o HexStore guardar.
  public func document() throws -> Data {
    try run("document", [])
  }

  // Uma função de um módulo do motor, por "<caminho do módulo>#<export>", com os argumentos e a
  // resposta na troca de values.js: {"returned": …, "args": …}, os argumentos depois da chamada.
  func call(_ name: String, json arguments: Data) throws -> Data {
    try run("call", [name, String(decoding: arguments, as: UTF8.self)])
  }

  // Avalia um trecho de JS no contexto do motor e devolve o resultado como texto (o String do JS).
  func evaluate(_ script: String) throws -> String {
    let (context, _) = try opened()
    let value = context.evaluateScript(script)
    try check(context)
    return value?.toString() ?? ""
  }

  // O script do motor descomprimido e o texto do hexengine.js.sha256, os dois do Bundle.module do
  // HexEngine (o alvo de teste tem o próprio Bundle.module, por isso pede aqui). É o único lugar que
  // descomprime o script. Os dois arquivos vão juntos no pacote: quando falta um deles, ou o
  // .deflate não descomprime, o pacote está quebrado, e o erro é .scriptMissing.
  static func bundledScript() throws -> (script: Data, sha256: String) {
    guard let packedURL = Bundle.module.url(forResource: "hexengine.js", withExtension: "deflate"),
          let sumURL = Bundle.module.url(forResource: "hexengine.js", withExtension: "sha256"),
          let packed = try? Data(contentsOf: packedURL),
          let sha256 = try? String(contentsOf: sumURL, encoding: .utf8),
          let script = try? (packed as NSData).decompressed(using: .zlib) as Data
    else { throw EngineError.scriptMissing }
    return (script, sha256)
  }

  // O contexto e o global HexEngine, ou .notLoaded antes do primeiro load() que deu certo.
  private func opened() throws -> (JSContext, JSValue) {
    guard let context, let engine else { throw EngineError.notLoaded }
    return (context, engine)
  }

  // Chama um método do global HexEngine e devolve o texto JSON que ele devolveu. Interno, para a
  // biblioteca (Library.swift) chamar também.
  func run(_ method: String, _ arguments: [Any]) throws -> Data {
    let (context, engine) = try opened()
    return Data(try Self.text(engine.invokeMethod(method, withArguments: arguments), from: method, in: context).utf8)
  }

  // O texto que uma chamada devolveu, depois de olhar a exceção dela.
  private static func text(_ value: JSValue?, from method: String, in context: JSContext) throws -> String {
    try check(context)
    guard let value, value.isString, let text = value.toString()
    else { throw EngineError.javaScript("HexEngine: \(method) não devolveu texto") }
    return text
  }

  // A exceção que a última chamada deixou no contexto vira um erro Swift, e o contexto fica limpo
  // para a chamada seguinte.
  private func check(_ context: JSContext) throws {
    try Self.check(context)
  }

  private static func check(_ context: JSContext) throws {
    guard let exception = context.exception else { return }
    context.exception = nil
    throw EngineError.javaScript(describe(exception))
  }

  // "<mensagem>\n<pilha>": o String do valor lançado (para um Error, "TypeError: …") e, quando ele
  // tem uma, a pilha, com as linhas de host.js ou hexengine.js. Um valor lançado sem pilha (um
  // throw 5) fica só com a mensagem.
  private static func describe(_ exception: JSValue) -> String {
    let message = exception.toString() ?? "exceção sem mensagem"
    guard let stack = exception.objectForKeyedSubscript("stack"), stack.isString,
          let lines = stack.toString(), !lines.isEmpty
    else { return message }
    return "\(message)\n\(lines)"
  }

  // As duas pontes que o host.js guarda. Nenhuma prende o motor: a do log nem usa o ator, e a dos
  // timers o captura com [weak self], e assim o contexto, que o ator guarda, não guarda o ator.
  private func bridge(_ context: JSContext, generation: Int) {
    let log: @convention(block) @Sendable (String, String) -> Void = { level, text in
      Self.write(level, text)
    }
    let schedule: @convention(block) @Sendable (Int, Double) -> Void = { [weak self] id, ms in
      Task { [weak self] in
        do {
          try await Task.sleep(for: .milliseconds(ms.isFinite ? max(0, ms) : 0))
        } catch {
          return
        }
        await self?.fire(id, generation: generation)
      }
    }
    context.setObject(log, forKeyedSubscript: "__hexgymLog" as NSString)
    context.setObject(schedule, forKeyedSubscript: "__hexgymSchedule" as NSString)
  }

  // Um timer que venceu, de volta ao ator. O do contexto de um load() que falhou, ou já trocado,
  // não faz nada. A exceção dentro dele não tem para quem voltar e vai para o log como erro.
  private func fire(_ id: Int, generation: Int) {
    guard generation == self.generation, let context else { return }
    _ = context.objectForKeyedSubscript("__hexgymFire")?.call(withArguments: [id])
    guard let exception = context.exception else { return }
    context.exception = nil
    Self.logger.error("exceção num timer do motor: \(Self.describe(exception), privacy: .private)")
  }

  // O console do motor no log do sistema, no nível do método. O texto pode trazer dados do
  // documento, por isso fica privado: o Console do macOS mostra só com um depurador ligado.
  private static func write(_ level: String, _ text: String) {
    switch level {
    case "debug": logger.debug("\(text, privacy: .private)")
    case "info": logger.info("\(text, privacy: .private)")
    case "warn": logger.warning("\(text, privacy: .private)")
    case "error": logger.error("\(text, privacy: .private)")
    default: logger.notice("\(text, privacy: .private)")
    }
  }
}
