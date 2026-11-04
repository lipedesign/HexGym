// O app do Apple Watch. Nesta fase, a tela provisória com a marca do HexDesign e o botão que abre a
// galeria do design system no Watch (Task 11 do plano da fase 1). O Watch não roda JavaScript: nada de
// JavaScriptCore nem do HexEngine aqui.
//
// O tema do Watch é um ThemeModel próprio, nos UserDefaults do App Group deste Watch (a chave
// hexgym.theme): a galeria tem o seletor dela, e a ida do tema do iPhone para o Watch é da fase 4. O
// brilho fica atrás da tela, parado, porque o pacote sabe que está no Watch (HexPlatform.current).
import HexDesign
import SwiftUI

@main
struct HexGymWatchApp: App {
  @State private var theme = ThemeModel(store: .appGroupStore())

  var body: some Scene {
    WindowGroup {
      WatchThemedRoot(theme: theme) {
        WatchHomeView()
      }
    }
  }
}

// A raiz com o tema: uma view, e não o body da cena, para observar o modelo e trocar o tema na hora.
// O modelo também vai para o ambiente, para a galeria trocar o tema e a prévia de alto contraste.
private struct WatchThemedRoot<Content: View>: View {
  let theme: ThemeModel
  @ViewBuilder let content: Content

  var body: some View {
    content
      .modifier(WatchRootTint())
      .background { BreathingGlow() }
      .hexTheme(theme)
      .environment(theme)
      .onAppear { WatchGalleryLaunch.apply(to: theme) }
  }
}

// O tint dos controles do sistema na raiz do Watch: branco, como no iPhone (QA da PR #85). O tint vira
// a cor do botão de voltar, do texto dos botões de barra e de outros controles do sistema, que no
// Watch ficam sobre o cinza das linhas da List ou do vidro: ali, o accent não é conferido. O accent
// entra só onde é pedido: nos componentes do HexDesign, que leem a paleta, e no preenchimento das
// chaves (WatchSwitchStyle), que não é texto e foi medido acima de 4,5:1 sobre a linha da List.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o tint branco na raiz do Watch, como no
// iPhone, e o accent só onde é pedido.
private struct WatchRootTint: ViewModifier {
  func body(content: Content) -> some View {
    content
      .tint(Color.white)
      .toggleStyle(WatchSwitchStyle())
  }
}

// A chave da Apple, como vem, com o preenchimento no accent do tema.
private struct WatchSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    WatchAccentSwitch(configuration: configuration)
  }
}

private struct WatchAccentSwitch: View {
  let configuration: ToggleStyleConfiguration
  @Environment(\.hexPalette) private var palette

  var body: some View {
    Toggle(configuration)
      .toggleStyle(.switch)
      .tint(Color(palette.accent))
  }
}

// A tela provisória do Watch: a marca e o botão principal compacto que abre a galeria.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o botão "Galeria" embaixo da marca,
// como no iPhone.
private struct WatchHomeView: View {
  @State private var path = NavigationPath(WatchGalleryLaunch.opensGallery ? [WatchRoute.gallery] : [])

  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: HexSpacing.m) {
        HexWordmark(size: 30)
        NavigationLink(value: WatchRoute.gallery) {
          Text("Gallery")
        }
        .buttonStyle(.hexPrimary)
      }
      .padding(.horizontal, HexSpacing.xs)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .containerBackground(.clear, for: .navigation)
      .navigationDestination(for: WatchRoute.self) { _ in WatchGalleryView() }
    }
  }
}

// Para onde a tela provisória leva.
enum WatchRoute: Hashable {
  case gallery
}
