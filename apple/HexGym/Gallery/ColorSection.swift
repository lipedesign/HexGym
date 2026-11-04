// As cores: cada papel da paleta do ambiente (o tema, com o Aumentar Contraste do aparelho ou a prévia),
// com o valor aprovado e o contraste escrito, pela conta da WCAG 2.2 do HexRGB. O cartão é o do sistema
// no contraste do aparelho: #1C1C1E, ou #242426 com Aumentar Contraste.
import HexDesign
import SwiftUI

struct ColorSection: View {
  @Environment(\.hexPalette) private var palette
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.locale) private var locale

  private var card: HexRGB { contrast == .increased ? .cardIncreased : .card }

  var body: some View {
    GallerySectionView("Colors", note: "Theme colored text only goes on the screen background and on the system card.") {
      ColorRow(name: "Accent", swatch: Color(palette.accent), hex: hex(palette.accent)) {
        Text("\(ratio(palette.accent, .black)) on the background")
        Text("\(ratio(palette.accent, card)) on the card")
      }
      AccentSamples()
      ColorRow(name: "Button", swatch: Color(palette.fill), hex: "\(hex(palette.fill)) / \(hex(palette.onFill))") {
        Text("\(ratio(palette.fill, palette.onFill)) with its label")
      }
      ColorRow(name: "Record", swatch: Color(palette.record), hex: "\(hex(palette.record)) / \(hex(palette.onRecord))") {
        Text("\(ratio(palette.record, .black)) on the background")
        Text("\(ratio(palette.record, palette.onRecord)) with its text")
      }
      if let support = palette.support {
        ColorRow(name: "Support", swatch: Color(support), hex: hex(support)) {
          Text("Only in the glow, never in text")
        }
      } else {
        ColorRow(name: "Support", swatch: Color.clear, hex: "") {
          Text("None in this theme and contrast")
        }
      }
      if let glow = palette.glow {
        ColorRow(name: "Glow", swatch: Color(glow), hex: p3(glow)) {
          Text("Display P3, only in the glow, never in text")
        }
      }
      ColorRow(name: "Error", swatch: HexPalette.error, hex: "systemRed") {
        Text("Always the system red, in every theme")
      }
    }
  }

  private func hex(_ rgb: HexRGB) -> String {
    String(format: "#%06X", rgb.hex)
  }

  // A razão de contraste com duas casas, no idioma: "6,37:1".
  private func ratio(_ a: HexRGB, _ b: HexRGB) -> String {
    a.contrast(with: b).formatted(.number.precision(.fractionLength(2)).locale(locale)) + ":1"
  }

  // Os componentes em Display P3 e a opacidade.
  private func p3(_ glow: HexP3) -> String {
    let values = [glow.red, glow.green, glow.blue].map { $0.formatted(.number.precision(.fractionLength(3)).locale(locale)) }
    return "P3 " + values.joined(separator: " ") + " · " + glow.opacity.formatted(.percent.precision(.fractionLength(0)).locale(locale))
  }
}

// Um papel: a amostra, o nome, o valor e as linhas do contraste, em branco e no cinza do sistema.
private struct ColorRow<Lines: View>: View {
  let name: LocalizedStringKey
  let swatch: Color
  let hex: String
  @ViewBuilder let lines: Lines

  var body: some View {
    HStack(alignment: .top, spacing: HexSpacing.s) {
      RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous)
        .fill(swatch)
        .overlay(RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous).strokeBorder(.quaternary))
        .frame(width: HexTarget.minimum, height: HexTarget.minimum)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: HexSpacing.xxs) {
        Text(name).font(.headline).foregroundStyle(Color.white)
        if !hex.isEmpty { Text(verbatim: hex).font(.subheadline.monospaced()).foregroundStyle(.secondary) }
        lines.font(.subheadline).foregroundStyle(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

// O texto no accent nos dois fundos em que ele pode ficar: o da tela e o cartão do sistema.
private struct AccentSamples: View {
  @Environment(\.hexPalette) private var palette
  @Environment(\.locale) private var locale

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: HexSpacing.s) { onBackground; onCard }
      VStack(alignment: .leading, spacing: HexSpacing.s) { onBackground; onCard }
    }
    .accessibilityHidden(true)
  }

  private var sample: String { WorkoutFormat.load(142.5, locale: locale) + " kg" }

  private var onBackground: some View {
    Text(verbatim: sample).hexFont(.title).foregroundStyle(Color(palette.accent))
      .padding(HexSpacing.s)
  }

  private var onCard: some View {
    Text(verbatim: sample).hexFont(.title).foregroundStyle(Color(palette.accent))
      .padding(HexSpacing.s)
      .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous))
  }
}
