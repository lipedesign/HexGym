// As entradas do treino (seção 6 do design doc, componentes nossos): a carga, as repetições e o
// esforço, cada uma com o rótulo, o valor que rola, a unidade e os botões de diminuir e aumentar.
// Nos tamanhos de acessibilidade, os botões descem para baixo do valor (Foco da revisão, item 2), e
// os dígitos tabulares do number seguram a largura com números grandes (item 3).
//
// As entradas não decidem o passo: quem usa a entrada aplica o addStep ou o stepEffort pelo motor e
// passa o valor novo. Para o VoiceOver, o valor é um elemento ajustável que fala a unidade, e os
// botões continuam elementos próprios, para o Controle por Voz.
//
// No Watch (Task 11), a entrada é a variante compacta: o valor em cima e os botões − e + embaixo, lado
// a lado, cada um com metade da largura e 44 pt de altura, para caber na tela mais estreita (a do
// iPhone mede de 188 a 299 pt, com dois botões de 56 pt, e o Watch de 40 mm tem 162 pt). E a entrada
// em foco responde à Coroa Digital: um passo por dente cruzado (CrownSteps), cada um chamando o onStep,
// com o háptico da própria coroa. Os botões continuam, para quem não usa a coroa.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: os botões de 56 pt, o valor no number,
// a unidade no unit e o empilhar nos tamanhos de acessibilidade; no Watch, a variante compacta com os
// botões de 44 pt embaixo do valor, e um passo por dente da Coroa Digital.

import SwiftUI

public enum WorkoutInputLayout {
  // Vertical nos tamanhos de acessibilidade (AX1 a AX5), e horizontal nos outros.
  public static func axis(for size: DynamicTypeSize) -> Axis {
    size.isAccessibilitySize ? .vertical : .horizontal
  }

  // Vertical sempre no Watch, a variante compacta; no iPhone, a regra de cima.
  static func axis(for size: DynamicTypeSize, on platform: HexPlatform) -> Axis {
    platform == .watch ? .vertical : axis(for: size)
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

  // A distância entre o valor e os botões: menor no Watch.
  private var gap: CGFloat { HexPlatform.current == .watch ? HexSpacing.xs : HexSpacing.s }

  var body: some View {
    Group {
      if WorkoutInputLayout.axis(for: dynamicTypeSize, on: .current) == .vertical {
        VStack(spacing: gap) {
          reading
          HStack(spacing: gap) { decrease; increase }
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
    #if os(watchOS)
    .modifier(CrownInput(onStep: onStep))
    #endif
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

#if os(watchOS)
// A Coroa Digital na entrada em foco: a coroa gira um valor sem fim, um dente por unidade (by: 1), com
// a sensibilidade baixa e o háptico da própria coroa a cada dente. Cada mudança passa pelo
// CrownSteps, e cada passo chama o onStep. O háptico de increase e decrease dos botões não toca aqui,
// para a coroa não vibrar duas vezes por dente.
//
// Só a entrada que recebeu um toque no valor pode ter o foco. Medido no simulador do Watch: com duas
// entradas focáveis na tela, o sistema passava o foco de uma para a outra sem parar (centenas de
// trocas por segundo, sem toque nenhum). Assim, a coroa rola a tela até a pessoa tocar numa entrada;
// depois, muda o valor dela. Um toque em outra entrada passa a coroa para ela, e a entrada que sai da
// tela devolve a coroa para a rolagem.
private struct CrownInput: ViewModifier {
  let onStep: (StepDirection) -> Void
  // A leitura da coroa e se a entrada pode ter o foco. Os State vão escritos sem o @, como no resto
  // do pacote.
  private let rotation = State(initialValue: 0.0)
  private let armed = State(initialValue: false)
  @FocusState private var focused: Bool

  // Os dois lados do giro. Com isContinuous, a coroa dá a volta de um lado para o outro: um salto
  // maior que o lado é essa volta, e não um giro, então não vira passo.
  private static let side = 1_000_000.0

  func body(content: Content) -> some View {
    content
      .overlay { CrownFocusRing(isFocused: focused) }
      .contentShape(Rectangle())
      .onTapGesture { takeTheCrown() }
      .focusable(armed.wrappedValue)
      .focused($focused)
      .digitalCrownRotation(
        rotation.projectedValue, from: -Self.side, through: Self.side, by: 1, sensitivity: .low, isContinuous: true,
        isHapticFeedbackEnabled: true)
      .onChange(of: rotation.wrappedValue) { old, new in
        guard focused, abs(new - old) < Self.side else { return }
        for direction in CrownSteps.steps(from: old, to: new) { onStep(direction) }
      }
      // Sem o foco (outra entrada o pegou), a entrada deixa de ser focável; fora da tela, também.
      .onChange(of: focused) { _, now in if !now { armed.wrappedValue = false } }
      .onDisappear { armed.wrappedValue = false }
  }

  // Um toque pega a coroa. O foco só chega depois que a entrada já é focável, na volta seguinte do
  // ciclo da tela. Com a coroa já aqui, o toque não muda nada.
  private func takeTheCrown() {
    guard !(armed.wrappedValue && focused) else { return }
    armed.wrappedValue = true
    Task { focused = true }
  }
}

// O contorno da entrada que está com a coroa: 2 pt no accent, no raio do chip, só com o foco. O
// sistema não desenha anel nenhum numa entrada focada (medido no simulador do Watch), e sem ele não
// dá para saber qual entrada a coroa muda. O contorno fica no preto, em volta do valor, onde o accent
// é conferido.
private struct CrownFocusRing: View {
  let isFocused: Bool
  @Environment(\.hexPalette) private var palette

  var body: some View {
    RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous)
      .strokeBorder(Color(palette.accent), lineWidth: 2)
      .padding(-HexSpacing.xxs)
      .opacity(isFocused ? 1 : 0)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}
#endif

// Um botão de diminuir ou aumentar, no raio do chip, com o símbolo do SF Symbols: 56 pt no iPhone; no
// Watch, metade da largura e 44 pt de altura, o alvo mínimo.
private struct StepButton: View {
  let symbol: String
  let title: String
  let action: () -> Void

  static let side: CGFloat = 56

  var body: some View {
    Button(action: action) {
      if HexPlatform.current == .watch {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .bold))
          .frame(maxWidth: .infinity, minHeight: HexTarget.minimum)
      } else {
        Image(systemName: symbol)
          .font(.system(size: 22, weight: .bold))
          .frame(width: Self.side, height: Self.side)
      }
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
