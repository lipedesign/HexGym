// A tela da primeira abertura (Task 7 do plano da fase 2): três passos numa tela só que avança, a
// unidade ("Em que você levanta?"), o tema ("Escolha a sua cor") e o corpo ("Qual corpo mostra os seus
// músculos?"), com "Continuar" (o botão principal do HexDesign), "Começar" no último passo e "Pular" em
// todos. O que cada toque faz está no OnboardingFlow, testado sem tela.
//
// O tema troca no ThemeModel na hora, e o brilho que respira atrás da tela e o botão principal mudam
// junto: é a prévia ao vivo. A unidade e o corpo só vão para o documento no fim, pelo AppModel.perform.
// Com Reduzir Movimento, a passagem de um passo para o outro é um esmaecido. O VoiceOver diz "Passo 1
// de 3" no topo de cada passo e vai para lá a cada troca. Em qualquer tamanho de texto, a tela rola, e
// nada é cortado.
//
// A regra da #71 vale aqui: o texto fica em branco ou nos cinzas do sistema, e a cor do tema só aparece
// nos segmentos do topo, sobre o fundo da tela, e nas marcas de escolhido, sobre o cartão do sistema.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o corpo com os símbolos figure.stand e
// figure.stand.dress até a Task 14 (escolha 3), os segmentos inclinados do HexDesign como o "Passo 1 de
// 3" na tela, as opções num cartão do sistema, como as dos Ajustes, e o "Pular" no botão secundário do
// HexDesign, embaixo do principal.
import HexDesign
import HexEngine
import os
import SwiftUI

struct OnboardingView: View {
  let model: AppModel
  // Chamado uma vez, no fim, para a raiz trocar a primeira abertura pelas abas.
  let finish: () -> Void

  @Environment(ThemeModel.self) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // nil enquanto o motor não devolveu os ajustes do documento.
  @State private var flow: OnboardingFlow?
  @AccessibilityFocusState private var positionFocused: Bool

  private static let logger = Logger(subsystem: "app.hexgym", category: "onboarding")

  var body: some View {
    Group {
      if let flow {
        page(flow)
      } else {
        Color.clear
      }
    }
    .task { await start() }
  }

  private func page(_ flow: OnboardingFlow) -> some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: HexSpacing.l) {
          position(flow.step)
          // Um ZStack, para o passo que sai e o que entra ficarem um sobre o outro durante a passagem.
          ZStack(alignment: .topLeading) {
            StepContent(flow: flow, choose: choose)
              .id(flow.step)
              .transition(stepTransition)
          }
          Spacer(minLength: HexSpacing.l)
          buttons(flow)
        }
        .padding(.horizontal, HexSpacing.m)
        .padding(.vertical, HexSpacing.m)
        // Os botões ficam no pé da tela quando tudo cabe, e descem com o resto quando não cabe.
        .frame(minHeight: proxy.size.height, alignment: .top)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }

  // O topo de cada passo: os segmentos inclinados, com o atual no accent a 35%, e "Passo 1 de 3" em
  // texto. Para o VoiceOver, um elemento só, que ele diz sem a caixa alta da tela.
  private func position(_ step: OnboardingFlow.Step) -> some View {
    let text = OnboardingText(locale: locale).position(step)
    return VStack(alignment: .leading, spacing: HexSpacing.xs) {
      SlantedSegments(total: OnboardingFlow.stepCount, done: step.rawValue - 1)
        .frame(maxWidth: 120)
      Text(verbatim: text)
        .hexFont(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: text))
    .accessibilityFocused($positionFocused)
  }

  private func buttons(_ flow: OnboardingFlow) -> some View {
    VStack(spacing: HexSpacing.s) {
      Button { advance { $0.next() } } label: {
        Text(flow.isLastStep ? "Get started" : "Continue")
      }
      .buttonStyle(.hexPrimary)
      Button { advance { $0.skip() } } label: {
        Text("Skip")
          .frame(maxWidth: .infinity, minHeight: HexTarget.minimum)
      }
      .hexSecondaryButton()
    }
  }

  // Com Reduzir Movimento, um esmaecido; sem ele, o passo novo entra pela direita (a esquerda, num
  // idioma da direita para a esquerda) e o de antes sai pelo outro lado.
  private var stepTransition: AnyTransition {
    reduceMotion ? .opacity : .push(from: .trailing)
  }

  // Uma escolha num passo. O tema vai para o ThemeModel na hora; a unidade e o corpo ficam no fluxo
  // até o fim.
  private func choose(_ change: (inout OnboardingFlow) -> Void) {
    guard var next = flow else { return }
    change(&next)
    flow = next
    if theme.theme != next.theme { theme.theme = next.theme }
  }

  // "Continuar", "Começar" ou "Pular": o fluxo avança, com a passagem; o "Pular" do tema devolve o tema
  // de antes ao ThemeModel. No fim, a marca vai para o App Group, a raiz mostra as abas, e o que mudou
  // vai para o documento.
  private func advance(_ step: (inout OnboardingFlow) -> Void) {
    guard var next = flow else { return }
    step(&next)
    withAnimation(HexMotion.change.animation(reduceMotion: reduceMotion)) { flow = next }
    if theme.theme != next.theme { theme.theme = next.theme }
    if next.isFinished {
      complete(next)
    } else {
      positionFocused = true
    }
  }

  // A marca vai antes da gravação: se uma ação falhar, o erro vai para o log, o que já foi gravado fica,
  // e os Ajustes mostram o que o documento tem. No log, como no AppModel, o tipo do erro fica público e
  // o detalhe, privado.
  private func complete(_ done: OnboardingFlow) {
    OnboardingMark.appGroup().markSeen()
    finish()
    Task {
      do {
        try await done.save(using: model)
      } catch {
        Self.logger.error("não deu para gravar a primeira abertura (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      }
    }
  }

  // Lê a unidade e o corpo do documento e começa no passo 1 (ou no do -HexGymOnboardingStep). Se o
  // motor não devolve os ajustes, a primeira abertura não aparece, sem a marca: o app abre nas abas, e
  // os Ajustes ficam para a pessoa.
  private func start() async {
    guard flow == nil else { return }
    do {
      var initial = OnboardingFlow(settings: try await model.engine.settings(), theme: theme.theme)
      if let step = OnboardingLaunch.step {
        while initial.step != step { initial.next() }
      }
      flow = initial
    } catch {
      Self.logger.error("não deu para ler os ajustes da primeira abertura (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      finish()
      return
    }
    if OnboardingLaunch.script == "demo" { await demo() }
  }

  // O roteiro do vídeo do PR (-HexGymOnboardingScript demo): o caminho inteiro, pelos mesmos choose e
  // advance dos toques. Libras, o Cobre, o Giz e o Ciano um depois do outro, ficando no Ciano, e o
  // corpo feminino; no fim, as abas no Ciano.
  private func demo() async {
    let pause = Duration.seconds(1.1)
    try? await Task.sleep(for: .seconds(1.4))
    choose { $0.unit = .lb }
    try? await Task.sleep(for: pause)
    advance { $0.next() }
    for next in [HexTheme.copper, .chalk, .cyan] {
      try? await Task.sleep(for: pause)
      choose { $0.theme = next }
    }
    try? await Task.sleep(for: pause)
    advance { $0.next() }
    try? await Task.sleep(for: pause)
    choose { $0.body = .female }
    try? await Task.sleep(for: pause)
    advance { $0.next() }
  }
}

// O título, as opções e a nota de um passo.
private struct StepContent: View {
  let flow: OnboardingFlow
  let choose: ((inout OnboardingFlow) -> Void) -> Void

  @Environment(\.locale) private var locale

  private var rows: SettingsRows { SettingsRows(locale: locale) }

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.l) {
      title
        .hexFont(.title)
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      switch flow.step {
      case .unit: units
      case .theme: themes
      case .body: bodies
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var title: Text {
    switch flow.step {
    case .unit: Text("What do you lift in?")
    case .theme: Text("Pick your color")
    case .body: Text("Which body shows your muscles?")
    }
  }

  private var units: some View {
    OptionCard {
      ForEach([WeightUnit.kg, .lb], id: \.self) { unit in
        OptionRow(label: rows.unit(unit), isSelected: flow.unit == unit) { choose { $0.unit = unit } }
        if unit == .kg { Divider() }
      }
    }
  }

  // Os quatro temas, com a amostra de cada um, nas mesmas linhas dos Ajustes.
  private var themes: some View {
    OptionCard {
      ForEach(HexTheme.allCases, id: \.self) { option in
        ThemeChoiceRow(theme: option, isSelected: flow.theme == option) { choose { $0.theme = option } }
        if option != HexTheme.allCases.last { Divider() }
      }
    }
  }

  // Os dois corpos lado a lado e, quando não cabem (nos tamanhos grandes de texto), um embaixo do outro.
  private var bodies: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HexSpacing.s) { bodyTiles }
        VStack(spacing: HexSpacing.s) { bodyTiles }
      }
      Text("You can change this later in Settings.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder private var bodyTiles: some View {
    ForEach(BodyChoice.allCases, id: \.self) { option in
      BodyTile(choice: option, label: rows.body(option), isSelected: flow.body == option) { choose { $0.body = option } }
    }
  }
}

// As opções de um passo num cartão do sistema, onde a marca de escolhido pode ficar na cor do tema
// (#71), com as divisórias entre as linhas.
private struct OptionCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 0) { content }
      .padding(.horizontal, HexSpacing.m)
      .padding(.vertical, HexSpacing.xxs)
      .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
  }
}

// Uma opção: o nome em branco e a marca de escolhido no accent, como as linhas de tema dos Ajustes, com
// pelo menos 44 pt de altura. No AX5, a marca desce para baixo do nome, para o nome não quebrar.
private struct OptionRow: View {
  let label: String
  let isSelected: Bool
  let select: () -> Void

  @Environment(\.hexPalette) private var palette

  var body: some View {
    Button(action: select) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HexSpacing.s) {
          name.fixedSize()
          Spacer(minLength: 0)
          if isSelected { checkmark }
        }
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          name
          if isSelected { checkmark }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, HexSpacing.xs)
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: label))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var name: some View {
    Text(verbatim: label).foregroundStyle(Color.white)
  }

  private var checkmark: some View {
    Image(systemName: "checkmark")
      .font(.body.weight(.semibold))
      .foregroundStyle(Color(palette.accent))
  }
}

// Um corpo: o símbolo da Apple e o nome, num cartão do sistema. O escolhido ganha a borda, o símbolo e
// a marca no accent. O desenho do corpo entra no lugar do símbolo na Task 14.
private struct BodyTile: View {
  let choice: BodyChoice
  let label: String
  let isSelected: Bool
  let select: () -> Void

  @Environment(\.hexPalette) private var palette
  // O símbolo acompanha o texto no Dynamic Type, de 56 pt até 96 pt.
  @ScaledMetric(relativeTo: .body) private var scaledSymbol: CGFloat = 56
  private var symbolSize: CGFloat { min(scaledSymbol, 96) }

  private var symbol: String { choice == .male ? "figure.stand" : "figure.stand.dress" }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous)
    Button(action: select) {
      VStack(spacing: HexSpacing.s) {
        Image(systemName: symbol)
          .font(.system(size: symbolSize, weight: .regular))
          .foregroundStyle(isSelected ? Color(palette.accent) : Color.white)
          .frame(height: symbolSize * 1.1)
        HStack(spacing: HexSpacing.xs) {
          Text(verbatim: label)
            .foregroundStyle(Color.white)
            .fixedSize()
          if isSelected {
            Image(systemName: "checkmark")
              .font(.body.weight(.semibold))
              .foregroundStyle(Color(palette.accent))
          }
        }
      }
      .padding(HexSpacing.m)
      .frame(maxWidth: .infinity, minHeight: HexTarget.minimum)
      .background(Color(uiColor: .secondarySystemBackground), in: shape)
      .overlay { shape.strokeBorder(isSelected ? Color(palette.accent) : Color.clear, lineWidth: 2) }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: label))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
