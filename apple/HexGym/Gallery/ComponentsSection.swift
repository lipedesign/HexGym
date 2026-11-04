// Os componentes, cada um nos seus estados: o botão principal; as entradas do treino num cartão do
// sistema e numa tela que sobe; os segmentos; o carimbo, que cai de novo num toque; o anel, com um
// descanso de 90 s que começa num toque; e o brilho. As entradas andam com um passo simples da
// galeria (GalleryStep), só para mostrar: a regra de verdade vem do motor na fase 3.
import HexDesign
import SwiftUI

struct ComponentsSection: View {
  var body: some View {
    GallerySectionView("Components") {
      PrimaryButtons().id(GalleryAnchor.buttons)
      WorkoutInputs().id(GalleryAnchor.inputs)
      Segments().id(GalleryAnchor.segments)
      Stamp()
      Ring().id(GalleryAnchor.ring)
      Glow().id(GalleryAnchor.glow)
    }
  }
}

// O botão principal normal, desligado e grande.
private struct PrimaryButtons: View {
  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Primary button")
      Button("Log set") {}.buttonStyle(.hexPrimary)
      Button("Log set") {}.buttonStyle(.hexPrimary).disabled(true)
      Button("Start workout") {}.buttonStyle(.hexPrimary(size: .large))
      GalleryNote("Normal, turned off and large.")
    }
  }
}

// As entradas do treino num cartão do sistema: a carga de 141,3 kg, a de 1000 kg e o esforço vazio. Os
// botões − e + têm o fundo do próprio cartão, e por isso o contorno deles some dentro dele (QA da PR
// #76). Numa tela que sobe, elas ficam direto no fundo dela (InputsSheet).
private struct WorkoutInputs: View {
  @State private var load = 141.3
  @State private var heavyLoad = 1000.0
  @State private var effort: Double?
  @State private var showsSheet = false

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Workout inputs")
      GalleryCard {
        LoadInput(value: load, unit: .kg) { load = GalleryStep.load(load, $0) }
        LoadInput(value: heavyLoad, unit: .kg) { heavyLoad = GalleryStep.load(heavyLoad, $0) }
        EffortInput(value: effort, scale: .rpe) { effort = GalleryStep.effort(effort, $0) }
      }
      GalleryNote("Inside a card, the − and + buttons take the card's own background, so their outline disappears.")
      Button("See them in a sheet") { showsSheet = true }
        .hexSecondaryButton()
    }
    .sheet(isPresented: $showsSheet) { InputsSheet() }
    .onAppear { if GalleryLaunch.action == "sheet" { showsSheet = true } }
  }
}

// A tela que sobe com as entradas. Pela #71, os cartões de uma tela que sobe levam texto branco ou nos
// cinzas do sistema, e a unidade das entradas fica no accent: por isso as entradas não entram num
// cartão aqui. Elas ficam direto no fundo da tela que sobe, opaco, que no escuro é o mesmo cinza do
// cartão do sistema (#1C1C1E, ou #242426 com Aumentar Contraste), onde o accent já é conferido.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: numa tela que sobe, as entradas ficam
// fora de cartão, direto no fundo opaco dela.
private struct InputsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var load = 141.3
  @State private var effort: Double? = 8

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: HexSpacing.l) {
          LoadInput(value: load, unit: .kg) { load = GalleryStep.load(load, $0) }
          EffortInput(value: effort, scale: .rpe) { effort = GalleryStep.effort(effort, $0) }
          GalleryNote("In a sheet, the inputs sit straight on its background, never on a card inside it.")
        }
        .padding(HexSpacing.m)
      }
      .navigationTitle("In a sheet")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
    .presentationDetents([.large])
    .presentationBackground(Color(uiColor: .systemBackground))
  }
}

// Os segmentos com 0, 3 e 5 de 5, com o que o VoiceOver diz embaixo de cada um.
private struct Segments: View {
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Slanted segments")
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
// #78). Ele cai a primeira vez que aparece na tela, e o botão faz cair de novo: o isShown volta a
// falso, a tela desenha sem ele, e depois volta a verdadeiro.
private struct Stamp: View {
  @State private var isShown = false
  @State private var dropped = false

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Record stamp")
      RecordStamp(isShown: isShown)
        .frame(maxWidth: .infinity, minHeight: 96)
        .onScrollVisibilityChange(threshold: 0.9) { visible in
          if visible, !dropped { drop() }
        }
      Button("Show it again") { drop() }
        .hexSecondaryButton()
    }
    .onAppear { if GalleryLaunch.action == "stamp" { drop() } }
  }

  private func drop() {
    dropped = true
    isShown = false
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      isShown = true
    }
  }
}

// O anel com um descanso de 90 s, que começa num toque e conta de segundo em segundo.
private struct Ring: View {
  @State private var remaining = GalleryLaunch.restSeconds
  @State private var runs = 0

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Rest ring")
      RestRing(total: GalleryLaunch.restSeconds, remaining: remaining)
        .frame(maxWidth: .infinity)
      Button("Start a 90 s rest") { runs += 1 }
        .hexSecondaryButton()
    }
    .onAppear { if GalleryLaunch.action == "rest", runs == 0 { runs = 1 } }
    .task(id: runs) {
      guard runs > 0 else { return }
      remaining = GalleryLaunch.restSeconds
      while remaining > 0 {
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }
        remaining -= 1
      }
    }
  }
}

// O brilho que respira, num recorte do tamanho de um cartão. Ele também está atrás de toda a galeria.
private struct Glow: View {
  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      GallerySubheader("Breathing glow")
      BreathingGlow()
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
      GalleryNote("It stops with Reduce Motion, goes out with Reduce Transparency and drops to half with high contrast.")
    }
  }
}
