// As três camadas no Watch (seção 6 do design doc e a decisão 2 de 03/11/2026), uma embaixo da outra:
// "Da Apple, como vem", "Da Apple, com a marca" e "Nossos". A carga de "Nossos" responde à Coroa
// Digital quando está em foco: depois de um toque nela, a coroa muda a carga, um passo por dente.
import HexDesign
import SwiftUI

struct WatchLayersSection: View {
  var body: some View {
    Section {
      AppleRows()
      BrandedRow()
      OursRows()
    } header: {
      WatchSectionHeader("The three layers")
    }
    .id(WatchGalleryAnchor.layers)
  }
}

// Da Apple, como vem: uma chave, uma linha de ajustes e um SF Symbol. A marca entra só pela cor de
// destaque: na chave, pelo estilo da raiz, e no símbolo, que fica no preto, pela paleta. O texto das
// linhas é branco, e a seta, no cinza do sistema.
private struct AppleRows: View {
  @Environment(\.hexPalette) private var palette
  @State private var isOn = true

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Apple, as it comes")
    }
    Toggle(isOn: $isOn) {
      Text("Switch").foregroundStyle(Color.white)
    }
    Button {} label: {
      HStack {
        Text("Settings").foregroundStyle(Color.white)
        Spacer(minLength: HexSpacing.xxs)
        Image(systemName: "chevron.right").foregroundStyle(.secondary)
      }
    }
    WatchComponentRow {
      Image(systemName: "dumbbell.fill")
        .font(.title2)
        .foregroundStyle(Color(palette.accent))
        .accessibilityLabel(Text("SF Symbol"))
    }
  }
}

// Da Apple, com a marca: o cartão de vidro com um número que rola, e um botão secundário que muda o
// número. Sobre o vidro, o texto é branco, como no iPhone (QA da PR #77).
private struct BrandedRow: View {
  @State private var workouts = 3

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Apple, with our brand")
      HexGlassCard {
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          RollingNumber(value: Double(workouts), text: "\(workouts)")
            .foregroundStyle(Color.white)
          Text("workouts")
            .font(.footnote)
            .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }
      Button("One more") { workouts += 1 }
        .hexSecondaryButton()
    }
    .id(WatchGalleryAnchor.branded)
  }
}

// Nossos: o botão principal compacto, os segmentos, a carga com a Coroa Digital e o carimbo.
private struct OursRows: View {
  @State private var load = 141.3

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Ours")
      Button("Go") {}
        .buttonStyle(.hexPrimary)
      SlantedSegments(total: 5, done: 3)
        .padding(.vertical, HexSpacing.xxs)
    }
    .id(WatchGalleryAnchor.ours)
    WatchComponentRow {
      LoadInput(value: load, unit: .kg) { load = WatchGalleryStep.load(load, $0) }
      WatchNote("Tap the load, then turn the Digital Crown: one step per detent.")
    }
    WatchComponentRow {
      RecordStamp(isShown: true)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity)
        .padding(.vertical, HexSpacing.xs)
    }
  }
}
