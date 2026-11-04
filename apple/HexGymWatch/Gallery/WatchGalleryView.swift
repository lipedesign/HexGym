// A galeria do design system no Watch (Task 11 do plano da fase 1): o HexDesign rodando no Watch, com
// a troca de tema ao vivo, numa List com três seções: as três camadas, o tema e os componentes.
// Nenhuma mídia de exercício.
//
// A regra do Watch (QA das PRs #72 e #85): o texto na cor do tema fica sobre o preto, e as linhas da
// List levam texto branco ou nos cinzas do sistema. Por isso, as linhas com componentes nossos (que
// usam o accent) ficam sem o fundo cinza da linha (WatchComponentRow), direto no preto, e as linhas
// do sistema (a chave, os temas, os ajustes) levam texto branco. Com Aumentar Contraste, o #ABA5FF só
// passa de 7:1 até o #242426, e a linha da List é mais clara que isso.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a organização da galeria do Watch e os
// componentes direto no preto, fora do fundo cinza das linhas.
import HexDesign
import SwiftUI

struct WatchGalleryView: View {
  @Environment(ThemeModel.self) private var theme
  // O roteiro roda uma vez só: a tarefa começa de novo cada vez que a galeria volta para a tela.
  @State private var ranLaunchScript = false

  var body: some View {
    ScrollViewReader { proxy in
      List {
        WatchLayersSection()
        WatchThemeSection()
        WatchComponentsSection()
      }
      .task { await runLaunchScript(proxy) }
    }
    // O título em branco: o do sistema sai no cinza #808080, que sobre o brilho do alto ficava abaixo
    // de 3:1 (medido no simulador do Watch).
    .navigationTitle { Text("Design system").foregroundStyle(Color.white) }
    .containerBackground(.clear, for: .navigation)
  }

  // O que os argumentos de início pedem (WatchGalleryLaunch): rolar até uma parte e, com -HexGymDemo
  // YES, a troca de tema do vídeo do PR: os quatro temas, um depois do outro, pelo mesmo ThemeModel do
  // seletor. A carga do vídeo muda pela coroa de verdade: o toque na carga e o giro da coroa vêm de
  // fora do app, pelo simulador.
  private func runLaunchScript(_ proxy: ScrollViewProxy) async {
    guard !ranLaunchScript else { return }
    ranLaunchScript = true
    if let anchor = WatchGalleryLaunch.anchor {
      try? await Task.sleep(for: .milliseconds(400))
      proxy.scrollTo(anchor, anchor: WatchGalleryLaunch.scrollPoint)
    }
    guard WatchGalleryLaunch.demo else { return }
    try? await Task.sleep(for: .seconds(1.2))
    for next in [HexTheme.chalk, .cyan, .copper, .ultraviolet] {
      theme.theme = next
      try? await Task.sleep(for: .seconds(1.2))
    }
  }
}

// Os lugares da galeria para onde o -HexGymSection rola.
enum WatchGalleryAnchor {
  static let layers = "layers", branded = "branded", ours = "ours", theme = "theme", buttons = "buttons", inputs = "inputs"
  static let segments = "segments", stamp = "stamp", ring = "ring", type = "type", glow = "glow"
}

// Os argumentos de início da galeria do Watch, para os prints e o vídeo do PR saírem do simulador sem
// tocar na tela, como na galeria do iPhone. Vêm do domínio dos argumentos dos UserDefaults padrão
// (xcrun simctl launch ... -HexGymGallery YES), que não fica gravado: sem eles, o app abre como sempre.
//   -HexGymGallery YES          a galeria já aberta
//   -HexGymTheme copper         o tema, pelo ThemeModel (vai para o App Group do Watch, como no seletor)
//   -HexGymContrastPreview YES  a prévia de alto contraste ligada
//   -HexGymSection ring         rola até uma parte (WatchGalleryAnchor)
//   -HexGymScroll bottom        a parte fica embaixo da tela (bottom) ou no meio (center), e não no alto
//   -HexGymAction rest          começa o descanso; stamp derruba o carimbo
//   -HexGymRestSeconds 3        o descanso do anel, no lugar dos 90 s
//   -HexGymDemo YES             o roteiro do vídeo
enum WatchGalleryLaunch {
  private static var defaults: UserDefaults { .standard }

  static var opensGallery: Bool { defaults.bool(forKey: "HexGymGallery") || demo }
  static var anchor: String? { defaults.string(forKey: "HexGymSection") }
  static var action: String? { defaults.string(forKey: "HexGymAction") }
  static var demo: Bool { defaults.bool(forKey: "HexGymDemo") }
  // Onde a parte pedida fica na tela: no alto, ou embaixo e no meio com -HexGymScroll.
  static var scrollPoint: UnitPoint {
    switch defaults.string(forKey: "HexGymScroll") {
    case "bottom": .bottom
    case "center": .center
    default: .top
    }
  }
  // O descanso do anel, em segundos: 90, ou outro com -HexGymRestSeconds, para ver o fim sem esperar.
  static var restSeconds: Int {
    let seconds = defaults.integer(forKey: "HexGymRestSeconds")
    return seconds > 0 ? seconds : 90
  }

  // O tema e a prévia pedidos, no modelo da raiz.
  static func apply(to model: ThemeModel) {
    if let raw = defaults.string(forKey: "HexGymTheme"), let theme = HexTheme(rawValue: raw) { model.theme = theme }
    if defaults.bool(forKey: "HexGymContrastPreview") { model.contrastPreview = true }
  }
}

// Uma linha com um componente nosso, direto no preto: sem o fundo cinza da linha da List, onde o
// accent não é conferido.
struct WatchComponentRow<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xs) { content }
      .frame(maxWidth: .infinity, alignment: .leading)
      .listRowBackground(Color.clear)
  }
}

// O nome de um componente ou de uma camada, em branco.
struct WatchSubheader: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .hexFont(.caption)
      .foregroundStyle(Color.white)
      .accessibilityAddTraits(.isHeader)
  }
}

// Uma explicação curta, no cinza do sistema, direto no preto.
struct WatchNote: View {
  let text: LocalizedStringKey

  init(_ text: LocalizedStringKey) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

// O título de uma seção da List, em branco.
struct WatchSectionHeader: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title).foregroundStyle(Color.white)
  }
}

// O passo simples da galeria, só para as entradas andarem: a regra de verdade vem do motor na fase 3.
// É o mesmo da galeria do iPhone.
enum WatchGalleryStep {
  // 2,5 kg para cada lado, sem passar de 0.
  static func load(_ value: Double, _ direction: StepDirection) -> Double {
    max(0, value + (direction == .up ? 2.5 : -2.5))
  }

  // Meio ponto para cada lado, de 6 a 10; vazio, o primeiro passo dá 8, e abaixo de 6 volta a vazio.
  static func effort(_ value: Double?, _ direction: StepDirection) -> Double? {
    guard let value else { return 8 }
    let next = value + (direction == .up ? 0.5 : -0.5)
    return next < 6 ? nil : min(next, 10)
  }
}
