// Os componentes no Watch, cada um nos seus estados, com a paleta do Watch e o brilho parado: o botão
// principal compacto, normal e desligado; as entradas do treino na variante compacta, com a Coroa
// Digital; os segmentos; o carimbo, que cai de novo num toque; o anel, com um descanso de 90 s que
// começa num toque; os nomes em outras escritas; e o brilho. As entradas andam com o passo simples da
// galeria (WatchGalleryStep): a regra de verdade vem do motor na fase 3.
import HexDesign
import SwiftUI

struct WatchComponentsSection: View {
  var body: some View {
    Section {
      PrimaryButtons().id(WatchGalleryAnchor.buttons)
      WorkoutInputs().id(WatchGalleryAnchor.inputs)
      Segments().id(WatchGalleryAnchor.segments)
      Stamp().id(WatchGalleryAnchor.stamp)
      Ring().id(WatchGalleryAnchor.ring)
      OtherScripts().id(WatchGalleryAnchor.type)
      Glow().id(WatchGalleryAnchor.glow)
    } header: {
      WatchSectionHeader("Components")
    }
  }
}

// O botão principal compacto (44 pt), normal e desligado.
private struct PrimaryButtons: View {
  var body: some View {
    WatchComponentRow {
      WatchSubheader("Primary button")
      Button("Log set") {}.buttonStyle(.hexPrimary)
      Button("Log set") {}.buttonStyle(.hexPrimary).disabled(true)
      WatchNote("Compact, 44 pt: normal and turned off.")
    }
  }
}

// As entradas do treino na variante compacta: a carga de 141,3 kg, a de 1000 kg, as repetições e o
// esforço vazio. A entrada em foco responde à Coroa Digital.
private struct WorkoutInputs: View {
  @State private var load = 141.3
  @State private var heavyLoad = 1000.0
  @State private var reps = 8
  @State private var effort: Double?

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Workout inputs")
      LoadInput(value: load, unit: .kg) { load = WatchGalleryStep.load(load, $0) }
    }
    WatchComponentRow {
      LoadInput(value: heavyLoad, unit: .kg) { heavyLoad = WatchGalleryStep.load(heavyLoad, $0) }
    }
    WatchComponentRow {
      RepsInput(value: reps) { reps = max(0, reps + ($0 == .up ? 1 : -1)) }
    }
    WatchComponentRow {
      EffortInput(value: effort, scale: .rpe) { effort = WatchGalleryStep.effort(effort, $0) }
      WatchNote("The − and + buttons stay for anyone who does not use the crown.")
    }
  }
}

// Os segmentos com 0, 3 e 5 de 5, com o que o VoiceOver diz embaixo de cada um.
private struct Segments: View {
  @Environment(\.locale) private var locale

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Slanted segments")
      ForEach([0, 3, 5], id: \.self) { done in
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          SlantedSegments(total: 5, done: done)
          Text(verbatim: SlantedSegments.spokenValue(total: 5, done: done, locale: locale))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
    }
  }
}

// O carimbo, sempre montado: a queda acontece quando o isShown passa de falso para verdadeiro (QA da PR
// #78). O botão faz cair de novo: o isShown volta a falso e, 0,3 s depois, a verdadeiro.
private struct Stamp: View {
  @State private var isShown = true

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Record stamp")
      RecordStamp(isShown: isShown)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, minHeight: 64)
      Button("Show it again") { drop() }
        .hexSecondaryButton()
    }
    .onAppear { if WatchGalleryLaunch.action == "stamp" { drop() } }
  }

  private func drop() {
    isShown = false
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      isShown = true
    }
  }
}

// O anel com um descanso de 90 s, que começa num toque e conta de segundo em segundo. No Watch, ele
// ocupa a largura da linha.
private struct Ring: View {
  @State private var remaining = WatchGalleryLaunch.restSeconds
  @State private var runs = 0

  var body: some View {
    WatchComponentRow {
      WatchSubheader("Rest ring")
      RestRing(total: WatchGalleryLaunch.restSeconds, remaining: remaining)
        .frame(maxWidth: .infinity)
      Button("Start a 90 s rest") { runs += 1 }
        .hexSecondaryButton()
    }
    .onAppear { if WatchGalleryLaunch.action == "rest", runs == 0 { runs = 1 } }
    .task(id: runs) {
      guard runs > 0 else { return }
      remaining = WatchGalleryLaunch.restSeconds
      while remaining > 0 {
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }
        remaining -= 1
      }
    }
  }
}

// Os nomes em outras escritas, no title: o cirílico e o grego saem na reserva do sistema, comprimida. O
// HexText põe o grego em maiúsculas sem o tonos, como a regra do grego pede, também em pt-BR (#121).
private struct OtherScripts: View {
  var body: some View {
    WatchComponentRow {
      WatchSubheader("Other scripts")
      ForEach(["Supino", "ЖИМ ЛЁЖА", "Πιέσεις πάγκου"], id: \.self) { name in
        HexText(name, style: .title)
          .foregroundStyle(Color.white)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      WatchNote("Cyrillic and Greek fall back to the system font, compressed.")
    }
  }
}

// O brilho, num recorte do tamanho de um cartão. Ele também está atrás da galeria inteira. No Watch,
// fica parado.
private struct Glow: View {
  var body: some View {
    WatchComponentRow {
      WatchSubheader("Glow")
      BreathingGlow()
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
      WatchNote("On the watch the glow stays still. It goes out with Reduce Transparency and drops to half with high contrast.")
    }
  }
}
