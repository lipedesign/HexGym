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
// O modelo também vai para o ambiente, para a galeria trocar o tema e a prévia de alto contraste.
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
