// A galeria do design system no iPhone (Task 10 do plano da fase 1): o HexDesign rodando de verdade,
// com a troca de tema ao vivo. De cima para baixo: as três camadas lado a lado, o tema, as cores, a
// tipografia, os componentes, o movimento e o háptico, e a transição de "Começar treino". Nenhuma
// mídia de exercício.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a organização da galeria.
//
// A regra da #71 vale aqui: o texto na cor do tema só fica sobre o fundo da tela e sobre o cartão do
// sistema (GalleryCard); nos cartões de uma tela que sobe, o texto é branco ou nos cinzas do sistema;
// e sobre o vidro, só branco (LayersSection).
import HexDesign
import SwiftUI

struct GalleryView: View {
  @Binding var path: NavigationPath
  @Environment(ThemeModel.self) private var theme
  // Os pedidos de abrir a tela do treino, que o roteiro dos argumentos de início faz.
  @State private var startRequests = 0
  // O roteiro roda uma vez só: a tarefa começa de novo cada vez que a galeria volta para a tela.
  @State private var ranLaunchScript = false

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: HexSpacing.xxl) {
          LayersSection().id(GalleryAnchor.layers)
          ThemeSection().id(GalleryAnchor.theme)
          ColorSection().id(GalleryAnchor.colors)
          TypeSection().id(GalleryAnchor.type)
          ComponentsSection()
          MotionSection().id(GalleryAnchor.motion)
          TransitionSection(path: $path, startRequests: startRequests).id(GalleryAnchor.transition)
        }
        .padding(.horizontal, HexSpacing.m)
        .padding(.vertical, HexSpacing.l)
      }
      .task { await runLaunchScript(proxy) }
    }
    .navigationTitle("Design system")
    .navigationBarTitleDisplayMode(.inline)
    .containerBackground(.clear, for: .navigation)
  }

  // O que os argumentos de início pedem (GalleryLaunch): rolar até uma parte, abrir a tela do treino
  // e, com -HexGymDemo YES, o roteiro do vídeo do PR: os quatro temas, um depois do outro, e o zoom de
  // "Começar treino". As trocas passam pelo mesmo ThemeModel do seletor. Quem fecha a tela do treino no
  // vídeo é ela mesma (WorkoutPreview): com ela aberta, a galeria sai da tela e esta tarefa é cancelada.
  private func runLaunchScript(_ proxy: ScrollViewProxy) async {
    guard !ranLaunchScript else { return }
    ranLaunchScript = true
    if let anchor = GalleryLaunch.anchor {
      try? await Task.sleep(for: .milliseconds(400))
      proxy.scrollTo(anchor, anchor: .top)
    }
    if GalleryLaunch.action == "start" {
      try? await Task.sleep(for: .milliseconds(800))
      startRequests += 1
    }
    guard GalleryLaunch.demo else { return }
    try? await Task.sleep(for: .seconds(1.6))
    for next in [HexTheme.chalk, .cyan, .copper, .ultraviolet] {
      theme.theme = next
      try? await Task.sleep(for: .seconds(1.5))
    }
    withAnimation(.easeInOut(duration: 0.8)) { proxy.scrollTo(GalleryAnchor.transition, anchor: .center) }
    try? await Task.sleep(for: .seconds(1.5))
    startRequests += 1
  }
}

// Os lugares da galeria para onde o -HexGymSection rola.
enum GalleryAnchor {
  static let layers = "layers", theme = "theme", colors = "colors", type = "type", buttons = "buttons", inputs = "inputs"
  static let segments = "segments", ring = "ring", glow = "glow", motion = "motion", transition = "transition"
}

// Os argumentos de início da galeria, para os prints e o vídeo do PR saírem do simulador sem tocar na
// tela. Vêm do domínio dos argumentos dos UserDefaults padrão (xcrun simctl launch ... -HexGymGallery
// YES), que não fica gravado: sem eles, o app abre como sempre.
//   -HexGymGallery YES          a galeria já aberta
//   -HexGymTheme copper         o tema, pelo ThemeModel (vai para o App Group, como no seletor)
//   -HexGymContrastPreview YES  a prévia de alto contraste ligada
//   -HexGymSection inputs       rola até uma parte (GalleryAnchor)
//   -HexGymAction start         abre a tela do treino; rest começa o descanso; stamp derruba o carimbo;
//                               sheet abre as entradas na tela que sobe
//   -HexGymRestSeconds 3        o descanso do anel, no lugar dos 90 s
//   -HexGymDemo YES             o roteiro do vídeo
enum GalleryLaunch {
  private static var defaults: UserDefaults { .standard }

  static var opensGallery: Bool { defaults.bool(forKey: "HexGymGallery") || demo }
  static var anchor: String? { defaults.string(forKey: "HexGymSection") }
  static var action: String? { defaults.string(forKey: "HexGymAction") }
  static var demo: Bool { defaults.bool(forKey: "HexGymDemo") }
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

// Uma parte da galeria: o título, uma nota opcional e o conteúdo.
struct GallerySectionView<Content: View>: View {
  let title: LocalizedStringKey
  let note: LocalizedStringKey?
  @ViewBuilder let content: Content

  init(_ title: LocalizedStringKey, note: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.note = note
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      VStack(alignment: .leading, spacing: HexSpacing.xs) {
        Text(title)
          .hexFont(.headline)
          .foregroundStyle(Color.white)
          .accessibilityAddTraits(.isHeader)
        if let note { GalleryNote(note) }
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// O nome de um componente dentro de uma parte.
struct GallerySubheader: View {
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

// Uma explicação curta, no cinza do sistema.
struct GalleryNote: View {
  let text: LocalizedStringKey

  init(_ text: LocalizedStringKey) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

// O cartão do sistema: o secondarySystemBackground, que é #1C1C1E no escuro e #242426 com Aumentar
// Contraste (SystemCardTests). Pela #71, é um dos dois fundos onde o texto na cor do tema pode ficar.
struct GalleryCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) { content }
      .padding(HexSpacing.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
  }
}

// Uma linha de rótulo e valor que vira duas linhas quando não cabe (nos tamanhos grandes de texto).
struct GalleryValueRow: View {
  let label: LocalizedStringKey
  let value: Text

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline) {
        Text(label).foregroundStyle(Color.white)
        Spacer(minLength: HexSpacing.s)
        value.foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: HexSpacing.xxs) {
        Text(label).foregroundStyle(Color.white)
        value.foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
