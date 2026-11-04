// O app do iPhone. Ao abrir, carrega o motor e o documento de dados (AppModel), e a tela provisória
// mostra a marca e o que aconteceu. O tema do aparelho (o ThemeModel, nos UserDefaults do App Group)
// vai para o ambiente na raiz, com o brilho que respira atrás da tela: a troca de tema na galeria muda
// tudo na hora e pede aos widgets que se desenhem de novo, com o tema novo.
import HexDesign
import SwiftUI
import WidgetKit

@main
struct HexGymApp: App {
  @State private var model = AppModel.live()
  @State private var theme = ThemeModel(store: .appGroupStore())

  var body: some Scene {
    WindowGroup {
      ThemedRoot(theme: theme) {
        ContentView(model: model)
      }
      .task { await model.start() }
    }
  }
}

// A raiz com o tema: uma view, e não o body da cena, para observar o modelo e trocar o tema na hora.
// Os componentes da Apple usam o accent do tema como tint, e o modelo também vai para o ambiente, para a
// galeria trocar o tema e a prévia de alto contraste.
private struct ThemedRoot<Content: View>: View {
  let theme: ThemeModel
  @ViewBuilder let content: Content

  var body: some View {
    content
      .modifier(AccentTint())
      .background { BreathingGlow() }
      .hexTheme(theme)
      .environment(theme)
      .onAppear { GalleryLaunch.apply(to: theme) }
      .onChange(of: theme.theme) { WidgetCenter.shared.reloadTimelines(ofKind: "HexGymWordmark") }
  }
}

// O tint dos componentes da Apple: o accent da paleta do ambiente.
private struct AccentTint: ViewModifier {
  @Environment(\.hexPalette) private var palette

  func body(content: Content) -> some View {
    content.tint(Color(palette.accent))
  }
}
