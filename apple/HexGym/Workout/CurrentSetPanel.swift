// O painel da série atual, fixo embaixo da tela do treino (Task 8 do plano da fase 3, escolha 4): "Supino
// com barra" e, numa linha própria, "Série 2 de 3", as entradas grandes do HexDesign e o botão principal
// "Registrar série". No modo de repetições, a carga (LoadInput) e as repetições (RepsInput), e o esforço
// (EffortInput) quando o perfil usa, na escala dele; no modo tempo, um Stepper da Apple de segundos, de 5 em 5 (o passo é do
// motor); numa série de drop set, rest-pause, lados ou cardio, o texto do motor e só o botão, que marca a
// linha inteira (escolha 12, Foco da revisão 4). Cada passo das entradas vai ao motor como um set.step, na
// série que o painel mostra; o botão marca a série com set.mark (done: true), e o painel passa para a
// série seguinte que o motor diz.
//
// As entradas ficam uma embaixo da outra, na largura toda: lado a lado, cada uma teria menos que os 188 pt
// que a entrada precisa com os dois botões de 56 pt. Nos tamanhos de acessibilidade, os botões de cada
// entrada descem para baixo do valor (o WorkoutInputLayout, dentro das entradas), e o painel vai para a
// lista, logo depois do cabeçalho (fixed: false), para nada ficar fora da tela.
//
// Fixo, o painel fica no preto da tela, com uma passagem suave do que rola por baixo dele: a unidade das
// entradas, no destaque do tema, e o rótulo cinza delas ficam num dos fundos onde podem ficar (#71).
//
// O painel do descanso da Task 9 entra no lugar deste, enquanto o descanso conta.
import HexDesign
import HexEngine
import SwiftUI

struct CurrentSetPanel: View {
  let model: WorkoutScreenModel
  let screen: WorkoutScreen
  // true: embaixo da tela, sobre o preto; false: dentro da lista, nos tamanhos de acessibilidade.
  let fixed: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      if let panel = model.panel {
        PanelTitle(panel: panel)
        inputs(panel)
        if panel.action != nil {
          Button { screen.log() } label: { Text(verbatim: panel.buttonLabel) }
            .buttonStyle(.hexPrimary(size: .large))
        }
      } else if let empty = model.emptyPanel {
        Text(verbatim: empty)
          .hexFont(.headline)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, minHeight: HexTarget.minimum, alignment: .leading)
      }
    }
    .padding(.horizontal, fixed ? HexSpacing.m : 0)
    .padding(.top, fixed ? HexSpacing.s : 0)
    .padding(.bottom, fixed ? HexSpacing.xs : 0)
    .background { if fixed { PanelBackground() } }
  }

  @ViewBuilder private func inputs(_ panel: WorkoutPanel) -> some View {
    switch panel.inputs {
    case .reps(let effort):
      VStack(spacing: HexSpacing.s) {
        LoadInput(value: panel.load, unit: panel.unit) { screen.step(.w, $0) }
        RepsInput(value: panel.reps) { screen.step(.r, $0) }
        if let effort {
          EffortInput(value: panel.effort, scale: effort) { screen.step(.effort, $0) }
        }
      }
    case .time:
      SecondsStepper(panel: panel, screen: screen)
    case .line:
      Text(verbatim: panel.line)
        .font(.title3.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// O título do painel em duas linhas (achado 6 do QA da #160): o nome do exercício, que quebra só entre
// palavras, e embaixo "Série 2 de 3" (ou "Aquecimento 1") na cor do tema, sobre o preto, numa linha só, que
// encolhe antes de quebrar. Para o VoiceOver, um cabeçalho só, com o título inteiro.
private struct PanelTitle: View {
  let panel: WorkoutPanel

  @Environment(\.hexPalette) private var palette

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xxs) {
      Text(verbatim: panel.exercise)
        .hexFont(.headline)
        .foregroundStyle(Color.white)
        .modifier(WholeWords(panel.exercise))
      Text(verbatim: panel.setLabel)
        .hexFont(.headline)
        .foregroundStyle(Color(palette.accent))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(verbatim: panel.title))
    .accessibilityAddTraits(.isHeader)
  }
}

// Os segundos de uma série com tempo, num Stepper da Apple, de 5 em 5 pelo motor: o rótulo e o tempo
// ("0:45") ao lado dos botões, e o VoiceOver diz "45 segundos".
private struct SecondsStepper: View {
  let panel: WorkoutPanel
  let screen: WorkoutScreen

  var body: some View {
    Stepper {
      VStack(alignment: .leading, spacing: HexSpacing.xxs) {
        Text("Seconds")
          .hexFont(.caption)
          .foregroundStyle(.secondary)
        Text(verbatim: panel.secondsText)
          .hexFont(.number)
          .foregroundStyle(Color.white)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
    } onIncrement: {
      screen.step(.sec, .up)
    } onDecrement: {
      screen.step(.sec, .down)
    }
    .controlSize(.large)
    .frame(minHeight: HexTarget.minimum)
    .accessibilityLabel(Text("Seconds"))
    .accessibilityValue(Text(verbatim: panel.spokenSeconds))
  }
}

// O fundo do painel fixo: o preto da tela, e em cima dele uma passagem de 24 pt do transparente ao preto,
// para o que rola por baixo sumir sem uma linha dura.
private struct PanelBackground: View {
  var body: some View {
    Color.black
      .overlay(alignment: .top) {
        LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
          .frame(height: HexSpacing.l)
          .offset(y: -HexSpacing.l)
      }
      .ignoresSafeArea(edges: .bottom)
      .accessibilityHidden(true)
  }
}
