// A tipografia: o logotipo, cada estilo da escala (a Barlow Condensed sobre o Dynamic Type, até o teto)
// e os nomes em outras escritas: o cirílico e o grego na SF Pro Compressed, e o chinês na fonte do
// sistema (Foco da revisão, item 1).
import HexDesign
import SwiftUI

struct TypeSection: View {
  @Environment(\.locale) private var locale

  var body: some View {
    GallerySectionView("Typography", note: "Barlow Condensed in numbers, titles and the logo; the system font in running text.") {
      HexWordmark()
      ForEach(HexTextStyle.allCases, id: \.self) { style in
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          sample(style)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
          description(style)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
      GallerySubheader("Other scripts")
      VStack(alignment: .leading, spacing: HexSpacing.xs) {
        Text(verbatim: "ЖИМ ЛЁЖА").hexFont(.title)
        // O HexText põe o grego em maiúsculas sem o tonos, como a regra do grego pede (#121).
        HexText("Πιέσεις πάγκου", style: .title)
        Text(verbatim: "卧推").hexFont(.title)
      }
      .foregroundStyle(Color.white)
      GalleryNote("Cyrillic and Greek come out in SF Pro Compressed, at the weight of the style; other scripts, in the system font.")
    }
  }

  @ViewBuilder private func sample(_ style: HexTextStyle) -> some View {
    switch style {
    case .display: Text(verbatim: WorkoutFormat.load(142.5, locale: locale)).hexFont(style)
    case .number: Text(verbatim: "1000").hexFont(style)
    case .title: Text("Bench press").hexFont(style)
    case .headline: Text("Third set").hexFont(style)
    case .unit: Text(verbatim: "kg").hexFont(style)
    case .caption: Text("Rest").hexFont(style)
    }
  }

  // O nome do estilo no idioma, o nome dele no código, o tamanho no tamanho de texto padrão e o teto,
  // quando há.
  private func description(_ style: HexTextStyle) -> Text {
    let code = String(describing: style), size = Int(style.baseSize)
    if let cap = style.maxSize {
      return Text("\(name(style)) (\(code)), \(size) pt, up to \(Int(cap)) pt")
    }
    return Text("\(name(style)) (\(code)), \(size) pt, grows without a cap")
  }

  private func name(_ style: HexTextStyle) -> Text {
    switch style {
    case .display: Text("Display")
    case .number: Text("Number")
    case .title: Text("Title")
    case .headline: Text("Headline")
    case .unit: Text("Unit")
    case .caption: Text("Caption")
    }
  }
}
