// As entradas do treino (seção 6 do design doc, componentes nossos): a carga, as repetições e o
// esforço, cada uma com o rótulo, o valor que rola, a unidade e os botões de diminuir e aumentar.
// Nos tamanhos de acessibilidade, os botões descem para baixo do valor (Foco da revisão, item 2), e
// os dígitos tabulares do number seguram a largura com números grandes (item 3).
//
// As entradas não decidem o passo: quem usa a entrada aplica o addStep ou o stepEffort pelo motor e
// passa o valor novo. Para o VoiceOver, o valor é um elemento ajustável que fala a unidade, e os
// botões continuam elementos próprios, para o Controle por Voz.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: os botões de 56 pt, o valor no number,
// a unidade no unit e o empilhar nos tamanhos de acessibilidade.

import SwiftUI

public enum WorkoutInputLayout {
  // Vertical nos tamanhos de acessibilidade (AX1 a AX5), e horizontal nos outros.
  public static func axis(for size: DynamicTypeSize) -> Axis {
    size.isAccessibilitySize ? .vertical : .horizontal
  }
}

// A carga, como foi registrada, em kg ou lb.
public struct LoadInput: View {
  private let value: Double
  private let unit: WeightUnit
  private let onStep: (StepDirection) -> Void

  @Environment(\.locale) private var locale

  public init(value: Double, unit: WeightUnit, onStep: @escaping (StepDirection) -> Void) {
    self.value = value
    self.unit = unit
    self.onStep = onStep
  }

  public var body: some View {
    WorkoutInputBody(
      label: HexStrings.text("load", table: "Workout", locale: locale), value: value,
      text: WorkoutFormat.load(value, locale: locale), unit: unit.rawValue,
      spoken: WorkoutFormat.spokenLoad(value, unit: unit, locale: locale), onStep: onStep)
  }
}

// As repetições, sem unidade.
public struct RepsInput: View {
  private let value: Int
  private let onStep: (StepDirection) -> Void

  @Environment(\.locale) private var locale

  public init(value: Int, onStep: @escaping (StepDirection) -> Void) {
    self.value = value
    self.onStep = onStep
  }

  public var body: some View {
    WorkoutInputBody(
      label: HexStrings.text("reps", table: "Workout", locale: locale), value: Double(value),
      text: value.formatted(.number.grouping(.never).locale(locale)), unit: nil,
      spoken: WorkoutFormat.spokenReps(value, locale: locale), onStep: onStep)
  }
}

// O esforço em RPE ou RIR. Vazio, mostra só a unidade.
public struct EffortInput: View {
  private let value: Double?
  private let scale: EffortScale
  private let onStep: (StepDirection) -> Void

  @Environment(\.locale) private var locale

  public init(value: Double?, scale: EffortScale, onStep: @escaping (StepDirection) -> Void) {
    self.value = value
    self.scale = scale
    self.onStep = onStep
  }

  public var body: some View {
    WorkoutInputBody(
      label: HexStrings.text("effort", table: "Workout", locale: locale), value: value ?? 0,
      text: WorkoutFormat.effort(value, locale: locale), unit: scale.symbol,
      spoken: WorkoutFormat.spokenEffort(value, scale: scale, locale: locale), onStep: onStep)
  }
}

// O corpo comum das três entradas.
private struct WorkoutInputBody: View {
  let label: String
  let value: Double
  let text: String
  let unit: String?
  let spoken: String
  let onStep: (StepDirection) -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @Environment(\.hexPalette) private var palette
  // Um contador por botão: cada toque muda o gatilho e toca o háptico. O State vai escrito sem o @:
  // neste SDK o @State é um macro, e as Command Line Tools não têm o plugin SwiftUIMacros. O SwiftUI
  // acha o State do mesmo jeito, por ser uma propriedade guardada da view.
  private let downs = State(initialValue: 0)
  private let ups = State(initialValue: 0)

  var body: some View {
    Group {
      if WorkoutInputLayout.axis(for: dynamicTypeSize) == .vertical {
        VStack(spacing: HexSpacing.s) {
          reading
          HStack(spacing: HexSpacing.s) { decrease; increase }
        }
      } else {
        HStack(spacing: HexSpacing.s) { decrease; reading; increase }
      }
    }
    .sensoryFeedback(HexHaptic.decrease.feedback(), trigger: downs.wrappedValue)
    .sensoryFeedback(HexHaptic.increase.feedback(), trigger: ups.wrappedValue)
  }

  // O rótulo do campo, o valor e a unidade, que o VoiceOver lê como um elemento ajustável.
  private var reading: some View {
    VStack(spacing: HexSpacing.xxs) {
      Text(verbatim: label).hexFont(.caption).foregroundStyle(.secondary)
      // Vazio, o número fica invisível e sem largura, mas segura a altura da linha: a entrada não pula
      // quando o primeiro valor chega.
      HStack(alignment: .firstTextBaseline, spacing: text.isEmpty ? 0 : HexSpacing.xxs) {
        RollingNumber(value: value, text: text.isEmpty ? "0" : text)
          .opacity(text.isEmpty ? 0 : 1)
          .fixedSize(horizontal: text.isEmpty, vertical: false)
          .frame(width: text.isEmpty ? 0 : nil)
        if let unit { Text(verbatim: unit).hexFont(.unit).foregroundStyle(Color(palette.accent)) }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.5)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: label))
    .accessibilityValue(Text(verbatim: spoken))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: step(.up)
      case .decrement: step(.down)
      @unknown default: break
      }
    }
  }

  private var decrease: some View {
    StepButton(symbol: "minus", title: HexStrings.text("decrease", table: "Workout", locale: locale)) { step(.down) }
  }

  private var increase: some View {
    StepButton(symbol: "plus", title: HexStrings.text("increase", table: "Workout", locale: locale)) { step(.up) }
  }

  // Toca o háptico e repassa o toque.
  private func step(_ direction: StepDirection) {
    switch direction {
    case .down: downs.wrappedValue += 1
    case .up: ups.wrappedValue += 1
    }
    onStep(direction)
  }
}

// Um botão de diminuir ou aumentar: 56 pt, no raio do chip, com o símbolo do SF Symbols.
private struct StepButton: View {
  let symbol: String
  let title: String
  let action: () -> Void

  static let side: CGFloat = 56

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 22, weight: .bold))
        .frame(width: Self.side, height: Self.side)
    }
    .buttonStyle(StepButtonStyle())
    .accessibilityLabel(Text(verbatim: title))
  }
}

private struct StepButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    StepButtonBody(configuration: configuration)
  }
}

// O símbolo no accent, sobre o cartão do sistema (onde o texto na cor do tema pode ficar, pela #71),
// com o mesmo aperto do botão principal.
private struct StepButtonBody: View {
  let configuration: ButtonStyleConfiguration

  @Environment(\.hexPalette) private var palette
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexContrastPreview) private var contrastPreview
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // O cartão do sistema no escuro, mais claro com Aumentar Contraste; no claro, um cinza leve.
  private var card: Color {
    guard colorScheme == .dark else { return Color.primary.opacity(0.08) }
    return Color(contrast == .increased || contrastPreview ? HexRGB.cardIncreased : HexRGB.card)
  }

  var body: some View {
    let effect = configuration.isPressed ? HexPrimaryButtonStyle.pressedEffect(reduceMotion: reduceMotion) : .none
    let shape = RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous)
    configuration.label
      .foregroundStyle(Color(palette.accent))
      .background(card, in: shape)
      .contentShape(shape)
      .scaleEffect(effect.scale)
      .opacity(effect.opacity * (isEnabled ? 1 : 0.4))
      .animation(HexMotion.tap.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
  }
}
