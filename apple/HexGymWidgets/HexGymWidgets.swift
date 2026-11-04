// Os widgets do iPhone. Nesta fase, um só, pequeno, com a marca em fundo preto e um traço na cor do
// tema. O tema vem dos UserDefaults do App Group, que a galeria do app grava: a linha do tempo tem uma
// entrada e nunca pede outra, e o app pede uma linha do tempo nova quando o tema muda.
import HexDesign
import SwiftUI
import WidgetKit

struct WordmarkEntry: TimelineEntry {
  let date: Date
  let theme: HexTheme
}

struct WordmarkProvider: TimelineProvider {
  func placeholder(in context: Context) -> WordmarkEntry {
    WordmarkEntry(date: .now, theme: .standard)
  }

  func getSnapshot(in context: Context, completion: @escaping (WordmarkEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WordmarkEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .never))
  }

  // O tema que está no App Group agora.
  private func entry() -> WordmarkEntry {
    WordmarkEntry(date: .now, theme: ThemeStore.appGroupStore().load())
  }
}

// A marca e, embaixo, o traço no accent do tema. O fundo é sempre preto, então a paleta é a do escuro,
// mesmo com o aparelho no claro.
struct WordmarkView: View {
  @Environment(\.hexPalette) private var palette

  var body: some View {
    VStack(spacing: HexSpacing.s) {
      HexWordmark(size: 34)
      Capsule()
        .fill(Color(palette.accent))
        .frame(width: 44, height: 4)
        .accessibilityHidden(true)
    }
  }
}

@main
struct WordmarkWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HexGymWordmark", provider: WordmarkProvider()) { entry in
      WordmarkView()
        .environment(\.hexTheme, entry.theme)
        .environment(\.colorScheme, .dark)
        .containerBackground(.black, for: .widget)
    }
    .configurationDisplayName("HexGym")
    .supportedFamilies([.systemSmall])
  }
}
