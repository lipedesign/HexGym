// O app do iPhone. Ao abrir, carrega o motor e o documento de dados (AppModel), e a raiz (RootView)
// mostra as abas, ou o erro, se o documento não abriu. Quando a cena vai para o fundo, o AppModel grava
// na hora o que as ações ainda não gravaram (flush), com um tempo pedido ao sistema para terminar. O
// tema do aparelho (o ThemeModel, nos UserDefaults do App Group) vai para o ambiente na raiz, com o
// brilho que respira atrás da tela: a troca de tema nos Ajustes ou na galeria muda tudo na hora e pede
// aos widgets que se desenhem de novo, com o tema novo.
import HexDesign
import os
import SwiftUI
import UIKit
import WidgetKit

@main
struct HexGymApp: App {
  @State private var model = AppModel.live()
  @State private var theme = ThemeModel(store: .appGroupStore())
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ThemedRoot(theme: theme) {
        RootView(model: model)
      }
      .task { await model.start() }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { flushInBackground() }
    }
  }

  // O flush() com o tempo extra do sistema, para a gravação terminar antes de o app ser suspenso.
  // A ida para o fundo e o fim do flush() vão para o log, com a hora, para a conferência no simulador.
  private func flushInBackground() {
    let time = BackgroundTime()
    time.begin()
    Self.logger.info("fundo: gravando o que falta")
    Task {
      await model.flush()
      Self.logger.info("fundo: flush terminou")
      time.end()
    }
  }

  private static let logger = Logger(subsystem: "app.hexgym", category: "app")
}

// O tempo extra que o sistema dá a um app que foi para o fundo, encerrado uma vez só: quando a
// gravação termina, ou quando o tempo acaba antes (o sistema chama o fim na thread principal).
@MainActor private final class BackgroundTime {
  private var id = UIBackgroundTaskIdentifier.invalid

  func begin() {
    id = UIApplication.shared.beginBackgroundTask(withName: "Gravar o documento") { [weak self] in
      MainActor.assumeIsolated { self?.end() }
    }
  }

  func end() {
    guard id != .invalid else { return }
    UIApplication.shared.endBackgroundTask(id)
    id = .invalid
  }
}

// A raiz com o tema: uma view, e não o body da cena, para observar o modelo e trocar o tema na hora.
// O modelo também vai para o ambiente, para os Ajustes e a galeria trocarem o tema, e a galeria, a
// prévia de alto contraste.
private struct ThemedRoot<Content: View>: View {
  let theme: ThemeModel
  @ViewBuilder let content: Content

  var body: some View {
    content
      .modifier(RootTint())
      .background { BreathingGlow() }
      .hexTheme(theme)
      .environment(theme)
      .onAppear { GalleryLaunch.apply(to: theme) }
      .onChange(of: theme.theme) { WidgetCenter.shared.reloadTimelines(ofKind: "HexGymWordmark") }
  }
}

// O tint dos componentes da Apple na raiz: branco. O tint vira a cor do texto dos botões de barra (o
// "OK" de uma tela que sobe, por exemplo), dos alertas e dos menus, que ficam sobre o vidro das barras
// (#3A3A3C), onde o accent não é conferido: no QA da PR #85, o "OK" no accent mediu 3,45:1 no
// Ultravioleta. Pela regra da #71, o texto na cor do tema só fica sobre o fundo da tela e sobre o
// cartão do sistema. O accent entra só onde é pedido: nos componentes do HexDesign, que leem a paleta;
// nas chaves, pelo HexSwitchStyle abaixo, porque nelas o tint é o preenchimento, e não texto; e onde
// uma tela o põe de propósito.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o tint branco na raiz e o accent só onde
// é pedido.
private struct RootTint: ViewModifier {
  func body(content: Content) -> some View {
    content
      .tint(Color.white)
      .toggleStyle(HexSwitchStyle())
  }
}

// A chave da Apple, como vem, com o preenchimento no accent do tema.
private struct HexSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    AccentSwitch(configuration: configuration)
  }
}

private struct AccentSwitch: View {
  let configuration: ToggleStyleConfiguration
  @Environment(\.hexPalette) private var palette

  var body: some View {
    Toggle(configuration)
      .toggleStyle(.switch)
      .tint(Color(palette.accent))
  }
}
