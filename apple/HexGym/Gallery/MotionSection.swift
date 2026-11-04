// O movimento e o háptico: um botão por háptico do HexHaptic e o estado dos ajustes de acessibilidade
// que o HexDesign lê. E a transição de "Começar treino": o zoom da Apple, do botão até uma tela de
// exemplo, preta com o brilho.
import HexDesign
import SwiftUI

struct MotionSection: View {
  @Environment(ThemeModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.legibilityWeight) private var legibilityWeight
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .body) private var buttonWidth: CGFloat = 150

  var body: some View {
    GallerySectionView("Motion and haptics", note: "The simulator does not play haptics: try these on a real iPhone.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: buttonWidth), spacing: HexSpacing.s, alignment: .leading)], alignment: .leading, spacing: HexSpacing.s) {
        ForEach(HexHaptic.allCases, id: \.self) { HapticButton(haptic: $0) }
      }
      .hexSecondaryButton()
      GallerySubheader("Accessibility settings")
      VStack(alignment: .leading, spacing: HexSpacing.s) {
        GalleryValueRow(label: "Reduce Motion", value: state(reduceMotion))
        GalleryValueRow(label: "Reduce Transparency", value: state(reduceTransparency))
        GalleryValueRow(label: "Increase Contrast", value: state(contrast == .increased))
        GalleryValueRow(label: "High contrast preview", value: state(model.contrastPreview))
        GalleryValueRow(label: "Bold Text", value: state(legibilityWeight == .bold))
        GalleryValueRow(label: "Text size", value: TextSizeName.text(dynamicTypeSize))
      }
    }
  }

  private func state(_ isOn: Bool) -> Text {
    isOn ? Text("On") : Text("Off")
  }
}

// Um háptico, num botão que toca o háptico a cada toque.
private struct HapticButton: View {
  let haptic: HexHaptic
  @State private var taps = 0

  var body: some View {
    Button { taps += 1 } label: {
      Text(name).frame(maxWidth: .infinity)
    }
    .sensoryFeedback(haptic.feedback(), trigger: taps)
  }

  private var name: LocalizedStringKey {
    switch haptic {
    case .increase: "Increase"
    case .decrease: "Decrease"
    case .setLogged: "Set logged"
    case .record: "Record"
    case .restDone: "Rest done"
    case .error: "Error"
    }
  }
}

// A transição de "Começar treino": o botão principal é a origem do zoom, e a tela do treino de exemplo
// é o destino. Ela abre dentro de withTransaction(StartWorkoutTransition.transaction(reduceMotion:)):
// com Reduzir Movimento, sem zoom e sem animação nenhuma.
//
// A tela entra pelo caminho do NavigationStack (path.append), não por navigationDestination(isPresented:).
// Medido no simulador do iOS 27 (QA da PR #77): com o isPresented, a transação sem animação não chega ao
// empurrão da pilha, e a tela entra deslizando da direita mesmo com Reduzir Movimento; pelo caminho, ela
// aparece de uma vez, sem se mover.
struct TransitionSection: View {
  @Binding var path: NavigationPath
  // Os pedidos do roteiro dos argumentos de início: cada número novo abre a tela.
  let startRequests: Int

  @Namespace private var zoom
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GallerySectionView("The transition", note: "The button grows into the workout screen. With Reduce Motion, the screen appears without moving.") {
      Button("Start workout") { open() }
        .buttonStyle(.hexPrimary(size: .large))
        .hexStartWorkoutSource(id: "workout", in: zoom)
      GalleryNote("If Reduce Motion changes while the workout screen is open, the screen gets a new identity and starts over (the if usesZoom of the destination). In phase 3, the workout state lives outside the view, or the screen reads Reduce Motion once, when it opens.")
    }
    .navigationDestination(for: WorkoutRoute.self) { _ in
      WorkoutPreview()
        .hexStartWorkoutDestination(id: "workout", in: zoom)
    }
    .onChange(of: startRequests) { open() }
  }

  private func open() {
    withTransaction(StartWorkoutTransition.transaction(reduceMotion: reduceMotion)) { path.append(WorkoutRoute()) }
  }
}

// A tela do treino de exemplo, na pilha da galeria.
struct WorkoutRoute: Hashable {}

// A tela do treino de exemplo: preta, com o brilho e o título. A tela de verdade é da fase 3.
private struct WorkoutPreview: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: HexSpacing.m) {
      Text("Workout")
        .hexFont(.title)
        .foregroundStyle(Color.white)
        .accessibilityAddTraits(.isHeader)
      Text("An example screen. The real one comes in phase 3.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(HexSpacing.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { BreathingGlow() }
    .containerBackground(.clear, for: .navigation)
    .task { await closeForTheVideo() }
  }

  // No roteiro do vídeo (-HexGymDemo YES), a tela fecha sozinha depois de 2,8 s, para o zoom voltar.
  private func closeForTheVideo() async {
    guard GalleryLaunch.demo else { return }
    do { try await Task.sleep(for: .seconds(2.8)) } catch { return }
    dismiss()
  }
}

// O nome do tamanho de texto, no idioma: o padrão do aparelho é o "Grande" da Apple.
enum TextSizeName {
  static func text(_ size: DynamicTypeSize) -> Text {
    switch size {
    case .xSmall: Text("Extra small")
    case .small: Text("Small")
    case .medium: Text("Medium")
    case .large: Text("Default (Large)")
    case .xLarge: Text("Extra large")
    case .xxLarge: Text("Extra large 2")
    case .xxxLarge: Text("Extra large 3")
    case .accessibility1: Text("Accessibility 1")
    case .accessibility2: Text("Accessibility 2")
    case .accessibility3: Text("Accessibility 3")
    case .accessibility4: Text("Accessibility 4")
    case .accessibility5: Text("Accessibility 5")
    @unknown default: Text(verbatim: String(describing: size))
    }
  }
}
