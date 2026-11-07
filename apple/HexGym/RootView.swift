// A raiz do app do iPhone (Task 6 do plano da fase 2): enquanto o motor e o documento abrem, um
// ProgressView; se não deu para abrir, a tela de erro, com a marca e a linha de sempre, sem abas; e,
// com o documento aberto, a TabView da Apple com as três abas, Rotinas, Exercícios e Ajustes, cada uma
// com o seu NavigationStack. As Rotinas são a lista das rotinas, com o editor (RoutinesView, Task 11); os
// Exercícios são a biblioteca (LibraryView, Task 9), e um toque abre o detalhe do exercício (Task 10). O
// detalhe de um erro vai para o log, nunca para a tela.
//
// Antes das abas, a primeira abertura (Task 7), quando o documento foi criado agora ou quando este
// aparelho nunca a viu (OnboardingLaunch.shouldShow). No fim dela, as abas entram com um esmaecido.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: as três abas (escolha 1 do plano), com
// as Rotinas primeiro.
import HexDesign
import SwiftUI

struct RootView: View {
  let model: AppModel

  var body: some View {
    switch model.state {
    case .starting:
      ProgressView("Opening…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed:
      FailureView()
    case .ready(let status):
      ReadyRoot(model: model, origin: status.origin)
    }
  }
}

// O documento aberto: a primeira abertura, quando ela aparece, e depois as abas. A decisão sai uma vez
// só, quando o documento abre, com a marca do App Group (OnboardingMark) e os argumentos de início.
private struct ReadyRoot: View {
  let model: AppModel
  @State private var onboarding: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(model: AppModel, origin: AppModel.Origin) {
    self.model = model
    _onboarding = State(initialValue: OnboardingLaunch.shouldShow(origin: origin, seen: OnboardingMark.appGroup().seen))
  }

  var body: some View {
    ZStack {
      if onboarding {
        OnboardingView(model: model) {
          withAnimation(HexMotion.enter.animation(reduceMotion: reduceMotion)) { onboarding = false }
        }
        .transition(.opacity)
      } else {
        RootTabs(model: model)
          .transition(.opacity)
      }
    }
  }
}

// As abas. O rawValue é o que o -HexGymTab recebe.
enum RootTab: String, CaseIterable, Hashable {
  case routines = "rotinas", library = "exercicios", settings = "ajustes"

  // A aba em que o app abre. Vem do domínio dos argumentos dos UserDefaults padrão (xcrun simctl
  // launch ... -HexGymTab ajustes), que não fica gravado, para os prints e os testes de interface:
  //   -HexGymTab <rotinas|exercicios|ajustes>   abre nessa aba
  //   -HexGymGallery YES                        sem -HexGymTab, abre nos Ajustes, com a galeria aberta
  //   -HexGymSettingsOpen licenses              com -HexGymTab ajustes, as Licenças (SettingsLaunch)
  // Sem eles, ou com um valor que não é aba, as Rotinas. Desde a Task 7, os prints e os testes de
  // interface põem também -HexGymSkipOnboarding YES, para a primeira abertura não ficar na frente das
  // abas num simulador que nunca a viu (OnboardingLaunch).
  static func launch(_ defaults: UserDefaults = .standard) -> RootTab {
    if let raw = defaults.string(forKey: "HexGymTab"), let tab = RootTab(rawValue: raw) { return tab }
    return GalleryLaunch.opensGallery ? .settings : .routines
  }
}

// A TabView pinta um fundo opaco por cima do brilho da raiz, e o iOS não deixa o fundo dela
// transparente: por isso, cada aba desenha o brilho que respira atrás da própria pilha.
private struct RootTabs: View {
  let model: AppModel
  @State private var tab = RootTab.launch()
  // A biblioteca, criada uma vez com o documento aberto: o catálogo fica guardado entre as abas.
  @State private var library: LibraryModel
  // A lista das rotinas e a biblioteca da escolha de exercícios do editor, separada da aba Exercícios,
  // para a busca de uma não aparecer na outra.
  @State private var routines: RoutinesScreen
  @State private var pickLibrary: LibraryModel
  // A pilha da aba Rotinas: o editor de uma rotina por cima da lista. Com -HexGymRoutine, a lista abre
  // o editor da rotina pedida (RoutinesLaunch).
  @State private var routinesPath: [RoutineRoute] = []
  // Só com -HexGymLibraryPick YES: os escolhidos no modo de escolha, para os prints (LibraryLaunch).
  @State private var picked: [String] = []
  // A pilha da aba Exercícios: o detalhe de um exercício por cima da lista. Com -HexGymExercise <id>, já
  // começa no detalhe dele, para os prints (ExerciseLaunch).
  @State private var libraryPath = ExerciseLaunch.path
  // A galeria já aberta nos Ajustes quando o app começa com -HexGymGallery YES, ou as Licenças, para os
  // prints e o vídeo (SettingsLaunch.path).
  @State private var settingsPath = SettingsLaunch.path

  init(model: AppModel) {
    self.model = model
    _library = State(initialValue: LibraryModel(app: model))
    _routines = State(initialValue: RoutinesScreen(app: model))
    _pickLibrary = State(initialValue: LibraryModel(app: model))
  }

  var body: some View {
    TabView(selection: $tab) {
      Tab("Routines", systemImage: "list.bullet.rectangle", value: RootTab.routines) {
        NavigationStack(path: $routinesPath) {
          RoutinesView(screen: routines, library: pickLibrary, path: $routinesPath)
        }
        .background { BreathingGlow() }
      }
      Tab("Exercises", systemImage: "dumbbell", value: RootTab.library) {
        NavigationStack(path: $libraryPath) {
          if LibraryLaunch.picks {
            LibraryView(model: library, selection: $picked, onAdd: { _ in picked = [] })
          } else {
            LibraryView(model: library)
          }
        }
        .background { BreathingGlow() }
      }
      Tab("Settings", systemImage: "gearshape", value: RootTab.settings) {
        NavigationStack(path: $settingsPath) {
          SettingsView(model: model, path: $settingsPath)
        }
        .background { BreathingGlow() }
      }
    }
  }
}

// O documento não abriu: a marca e a linha do erro, como a tela provisória mostrava.
private struct FailureView: View {
  var body: some View {
    VStack(spacing: HexSpacing.l) {
      HexWordmark()
      Text("Couldn't open your data.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(HexSpacing.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
