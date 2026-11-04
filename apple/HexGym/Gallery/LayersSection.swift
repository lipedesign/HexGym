// As três camadas lado a lado, no topo da galeria (seção 6 do design doc e a decisão 2 de 03/11/2026):
// "Da Apple, como vem", "Da Apple, com a marca" e "Nossos", cada uma com os exemplos dela.
//
// O ViewThatFits escolhe entre as colunas lado a lado e uma embaixo da outra. Cada coluna diz que
// quer 100 pt de largura no tamanho de texto padrão, e essa largura cresce com o Dynamic Type: nos
// tamanhos de acessibilidade, as três não cabem lado a lado e viram uma embaixo da outra. A entrada da
// carga não cabe numa coluna de um terço da tela (só os dois botões de 56 pt e os espaços somam 136 pt):
// lado a lado, ela fica numa faixa da largura toda, logo embaixo das colunas, com o nome da camada dela.
import HexDesign
import SwiftUI

struct LayersSection: View {
  @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 100
  @State private var load = 141.3

  var body: some View {
    GallerySectionView("The three layers") {
      ViewThatFits(in: .horizontal) {
        VStack(alignment: .leading, spacing: HexSpacing.l) {
          HStack(alignment: .top, spacing: HexSpacing.xs) {
            AppleColumn().frame(idealWidth: columnWidth, maxWidth: .infinity, alignment: .topLeading)
            BrandedColumn().frame(idealWidth: columnWidth, maxWidth: .infinity, alignment: .topLeading)
            OursColumn(load: $load, showsInput: false).frame(idealWidth: columnWidth, maxWidth: .infinity, alignment: .topLeading)
          }
          VStack(alignment: .leading, spacing: HexSpacing.xs) {
            LayerName("Ours: the load input")
            loadInput
          }
        }
        VStack(alignment: .leading, spacing: HexSpacing.xl) {
          AppleColumn()
          BrandedColumn()
          OursColumn(load: $load, showsInput: true)
        }
      }
    }
  }

  private var loadInput: some View {
    LoadInput(value: load, unit: .kg) { load = GalleryStep.load(load, $0) }
  }
}

// O nome de uma camada, no topo da coluna.
struct LayerName: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .hexFont(.caption)
      .foregroundStyle(Color.white)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}

// Da Apple, como vem: uma chave, um seletor segmentado, uma linha de ajustes e um SF Symbol. A marca
// entra só pela cor de destaque: na chave, pelo estilo da raiz, e no símbolo, pela paleta.
private struct AppleColumn: View {
  @Environment(\.hexPalette) private var palette
  @State private var isOn = true
  @State private var unit = WeightUnit.kg

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      LayerName("Apple, as it comes")
      Toggle("Switch", isOn: $isOn)
        .foregroundStyle(Color.white)
      Picker("Unit", selection: $unit) {
        Text(verbatim: "kg").tag(WeightUnit.kg)
        Text(verbatim: "lb").tag(WeightUnit.lb)
      }
      .pickerStyle(.segmented)
      Button {} label: {
        HStack {
          Text("Settings").foregroundStyle(Color.white)
          Spacer(minLength: HexSpacing.xxs)
          Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(.horizontal, HexSpacing.s)
        .frame(minHeight: HexTarget.minimum)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous))
      }
      .buttonStyle(.plain)
      Image(systemName: "dumbbell.fill")
        .font(.largeTitle)
        .foregroundStyle(Color(palette.accent))
        .accessibilityLabel(Text("SF Symbol"))
    }
  }
}

// Da Apple, com a marca: o cartão de vidro com um número que rola, e um botão secundário que muda o
// número. Sobre o vidro, o texto é branco (QA da PR #77): medido no simulador, o branco fica em pelo
// menos 8,54:1 nos quatro temas, no pior pixel do vidro, e o cinza secundário do sistema fica em 3,1 a
// 3,2:1, abaixo de 4,5.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: sobre o vidro, só texto branco.
private struct BrandedColumn: View {
  @State private var workouts = 3

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      LayerName("Apple, with our brand")
      HexGlassCard {
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          RollingNumber(value: Double(workouts), text: "\(workouts)")
            .foregroundStyle(Color.white)
          Text("workouts")
            .font(.subheadline)
            .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }
      Button("One more") { workouts += 1 }
        .hexSecondaryButton()
    }
  }
}

// Nossos: o botão principal, os segmentos, o carimbo e, uma embaixo da outra, a entrada da carga.
private struct OursColumn: View {
  @Binding var load: Double
  let showsInput: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      LayerName("Ours")
      Button("Go") {}
        .buttonStyle(.hexPrimary)
      SlantedSegments(total: 5, done: 3)
      RecordStamp(isShown: true)
        .minimumScaleFactor(0.5)
        .padding(.vertical, HexSpacing.xs)
      if showsInput {
        LoadInput(value: load, unit: .kg) { load = GalleryStep.load(load, $0) }
      }
    }
  }
}

// O passo simples da galeria, só para as entradas andarem: a regra de verdade vem do motor na fase 3.
enum GalleryStep {
  // 2,5 kg para cada lado, sem passar de 0.
  static func load(_ value: Double, _ direction: StepDirection) -> Double {
    max(0, value + (direction == .up ? 2.5 : -2.5))
  }

  // Meio ponto para cada lado, de 6 a 10; vazio, o primeiro toque dá 8, e abaixo de 6 volta a vazio.
  static func effort(_ value: Double?, _ direction: StepDirection) -> Double? {
    guard let value else { return 8 }
    let next = value + (direction == .up ? 0.5 : -0.5)
    return next < 6 ? nil : min(next, 10)
  }
}
