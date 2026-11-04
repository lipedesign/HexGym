// Os widgets do iPhone. Nesta fase, um só, pequeno, com a marca em fundo preto. Ele não muda com o
// tempo, então a linha do tempo tem uma entrada e nunca pede outra.
import SwiftUI
import WidgetKit

struct WordmarkEntry: TimelineEntry {
  let date: Date
}

struct WordmarkProvider: TimelineProvider {
  func placeholder(in context: Context) -> WordmarkEntry {
    WordmarkEntry(date: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (WordmarkEntry) -> Void) {
    completion(WordmarkEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WordmarkEntry>) -> Void) {
    completion(Timeline(entries: [WordmarkEntry(date: .now)], policy: .never))
  }
}

@main
struct WordmarkWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "HexGymWordmark", provider: WordmarkProvider()) { _ in
      Wordmark(size: 34)
        .containerBackground(.black, for: .widget)
    }
    .configurationDisplayName("HexGym")
    .supportedFamilies([.systemSmall])
  }
}
