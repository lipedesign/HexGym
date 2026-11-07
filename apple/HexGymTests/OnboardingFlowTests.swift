// Os testes da primeira abertura sem tela (Task 7 do plano da fase 2): quando ela aparece
// (OnboardingFlow.shouldShow, com a marca hexgym.onboarded do aparelho e os argumentos de início), o
// "Pular", que avança sem mudar a escolha do passo, e o fim, que grava no documento só o que mudou,
// numa ação cada. Os textos da tela são conferidos em português do Brasil e em inglês.
//
// O alvo roda dentro do app (TEST_HOST) e lê os textos do catálogo do app. O fim roda num AppModel com
// um DocumentStore numa pasta temporária (TemporaryFolder, do AppModelTests), nunca no App Group.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym \
//     -destination id=<udid> -derivedDataPath apple/DerivedData -parallel-testing-enabled NO test

import Foundation
import HexDesign
import HexEngine
import HexStore
import Testing
@testable import HexGym

@Suite @MainActor struct OnboardingFlowTests {
  let portuguese = Locale(identifier: "pt-BR")
  let english = Locale(identifier: "en-US")

  // UserDefaults só do teste, para não mexer na marca nem nos argumentos do simulador.
  func defaults(_ name: String) -> UserDefaults {
    let suite = "onboarding-\(name)-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  // Os ajustes de um documento, como o engine.settings() devolve.
  func settings(unit: String, body: String) throws -> DocumentSettings {
    let json = #"{"unit":"\#(unit)","body":"\#(body)","weekStart":1,"restSec":90,"effort":null}"#
    return try JSONDecoder().decode(DocumentSettings.self, from: Data(json.utf8))
  }

  @Test func aDocumentCreatedNowShowsTheFirstRun() {
    #expect(OnboardingFlow.shouldShow(origin: .created, seen: false))
    // Um documento criado agora mostra mesmo num aparelho que já viu: os dados começaram do zero.
    #expect(OnboardingFlow.shouldShow(origin: .created, seen: true))
    // Os argumentos de início, só para prints e testes: -HexGymOnboarding YES mostra sempre, e
    // -HexGymSkipOnboarding YES nunca mostra, e ganha dos dois.
    let launch = defaults("launch")
    #expect(OnboardingLaunch.shouldShow(origin: .created, seen: false, launch: launch))
    launch.set(true, forKey: "HexGymSkipOnboarding")
    #expect(!OnboardingLaunch.shouldShow(origin: .created, seen: false, launch: launch))
    launch.set(true, forKey: "HexGymOnboarding")
    #expect(!OnboardingLaunch.shouldShow(origin: .created, seen: false, launch: launch))
    launch.removeObject(forKey: "HexGymSkipOnboarding")
    #expect(OnboardingLaunch.shouldShow(origin: .opened, seen: true, launch: launch))
  }

  @Test func anOpenedDocumentOnADeviceThatSawItDoesNotShow() {
    #expect(!OnboardingFlow.shouldShow(origin: .opened, seen: true))
    #expect(!OnboardingFlow.shouldShow(origin: .recovered, seen: true))
    // A marca fica nos UserDefaults (no app, os do App Group), na chave hexgym.onboarded, como true.
    let store = defaults("mark")
    let mark = OnboardingMark(defaults: store)
    #expect(!mark.seen)
    mark.markSeen()
    #expect(mark.seen)
    #expect(store.object(forKey: "hexgym.onboarded") as? Bool == true)
    #expect(OnboardingMark.key == "hexgym.onboarded")
    #expect(!OnboardingFlow.shouldShow(origin: .opened, seen: mark.seen))
  }

  // Um aparelho novo com um documento que veio do backup ainda escolhe o tema, e a unidade e o corpo
  // já vêm marcados com o que o documento tem.
  @Test func anOpenedDocumentOnANewDeviceShowsWithTheDocumentChoices() throws {
    #expect(OnboardingFlow.shouldShow(origin: .opened, seen: false))
    #expect(OnboardingFlow.shouldShow(origin: .recovered, seen: false))
    let flow = OnboardingFlow(settings: try settings(unit: "lb", body: "female"), theme: .copper)
    #expect(flow.step == .unit)
    #expect(flow.unit == .lb); #expect(flow.body == .female); #expect(flow.theme == .copper)
    #expect(flow.changes.isEmpty)
    // Os padrões, num documento novo: kg e masculino, do DEF do openGym, e o Ultravioleta.
    let fresh = OnboardingFlow()
    #expect(fresh.unit == .kg); #expect(fresh.body == .male); #expect(fresh.theme == .ultraviolet)
  }

  @Test func skipOnTheFirstStepGoesToTheSecondWithoutChangingTheUnit() {
    var flow = OnboardingFlow()
    #expect(OnboardingText(locale: portuguese).position(flow.step) == "Passo 1 de 3")
    #expect(OnboardingText(locale: english).position(flow.step) == "Step 1 of 3")
    flow.unit = .lb
    flow.skip()
    #expect(flow.step == .theme); #expect(flow.unit == .kg); #expect(!flow.isFinished)
    #expect(OnboardingText(locale: portuguese).position(flow.step) == "Passo 2 de 3")
    // O "Pular" do tema volta ao tema de antes; o "Continuar" fica com a escolha.
    flow.theme = .cyan
    flow.skip()
    #expect(flow.step == .body); #expect(flow.theme == .ultraviolet)
    #expect(flow.isLastStep)
    flow.body = .female
    flow.next()
    #expect(flow.isFinished); #expect(flow.body == .female)
    // Depois do fim, nada mais muda.
    flow.skip()
    #expect(flow.isFinished); #expect(flow.body == .female)
    // O texto da tela, o do plano, nos dois idiomas.
    let texts: [(String, String)] = [
      ("What do you lift in?", "Em que você levanta?"),
      ("Pick your color", "Escolha a sua cor"),
      ("Which body shows your muscles?", "Qual corpo mostra os seus músculos?"),
      ("You can change this later in Settings.", "Dá para trocar depois nos Ajustes."),
      ("Continue", "Continuar"), ("Skip", "Pular"), ("Get started", "Começar"),
      ("Kilograms (kg)", "Quilos (kg)"), ("Pounds (lb)", "Libras (lb)"), ("Male", "Masculino"), ("Female", "Feminino"),
    ]
    for (key, value) in texts {
      #expect(AppText.text(key, locale: portuguese) == value)
      #expect(AppText.text(key, locale: english) == key)
    }
  }

  // O fim grava só o que mudou, numa ação cada: nada mudou, nenhuma ação, e o documento fica como
  // estava; só a unidade mudou, uma ação só, e o corpo fica. O tema nunca vai para o documento.
  @Test func theEndSavesOnlyWhatChanged() async throws {
    let folder = try TemporaryFolder()
    let model = AppModel(engine: HexEngine(), store: DocumentStore(directory: folder.url))
    await model.start()
    let created = try Data(contentsOf: folder.url.appending(path: "state.json"))

    var untouched = OnboardingFlow(settings: try await model.engine.settings(), theme: .ultraviolet)
    untouched.next(); untouched.theme = .cyan; untouched.next(); untouched.next()
    #expect(untouched.isFinished)
    #expect(untouched.changes.isEmpty)
    try await untouched.save(using: model)
    await model.flush()
    #expect(model.revision == 0)
    #expect(try Data(contentsOf: folder.url.appending(path: "state.json")) == created)

    var pounds = OnboardingFlow(settings: try await model.engine.settings(), theme: .ultraviolet)
    pounds.unit = .lb; pounds.next(); pounds.next(); pounds.next()
    #expect(pounds.changes == [.unit("lb")])
    try await pounds.save(using: model)
    #expect(model.revision == 1)
    let saved = try await model.engine.settings()
    #expect(saved.unit == "lb"); #expect(saved.body == "male")

    var both = OnboardingFlow(settings: saved, theme: .ultraviolet)
    both.unit = .kg; both.body = .female
    #expect(both.changes == [.unit("kg"), .body("female")])
  }
}
