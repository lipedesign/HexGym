// A tela do treino (Task 8 do plano da fase 3, issue #137, escolhas 3 e 4), num fullScreenCover do RootView
// que cobre as abas. Em cima, o cabeçalho: o nome do treino, o tempo que passa, "5 de 13 séries" e os
// segmentos inclinados; na barra, "Minimizar" e "Terminar". No meio, um cartão de vidro por exercício
// (ExerciseCard), com as séries em linhas curtas (SetRow). Embaixo, fixo, o painel da série atual
// (CurrentSetPanel), com as entradas grandes do HexDesign e o botão principal "Registrar série": é para
// registrar com uma mão, entre séries, com pressa (seção 6).
//
// A tela abre pelo zoom da fase 1 (StartWorkoutTransition): o "Começar treino" e o "Continuar treino" do
// Início e o "Começar" do editor de rotina são a origem, e esta tela é o destino. O WorkoutLauncher abre e
// fecha a tela dentro de withTransaction(StartWorkoutTransition.transaction(reduceMotion:)), a outra
// metade do Reduzir Movimento: sem zoom e sem animação, a tela aparece sem se mover. O estado da tela mora
// no WorkoutScreen, fora da view: a tela recomeça quando o Reduzir Movimento muda com ela aberta, e nada
// se perde.
//
// O tempo conta num TimelineView de 1 s a partir do começo, sem ler o motor a cada tique (seção 8.13). O
// háptico de cada efeito do motor (o setLogged, ao marcar a série) toca pelo hapticTick do WorkoutSession.
//
// Até a Task 11, o "Terminar" só fecha a tela, como o "Minimizar"; o painel do descanso (Task 9) entra no
// lugar do CurrentSetPanel, e os menus de mudar o treino (Task 10) entram nos cartões e na barra.
//
// A regra da #71 vale aqui: no cartão de vidro, o texto vai só em branco; a cor do tema fica nas marcas que
// não são texto (a série atual, o superset), no "Superset A" sobre o fundo da tela e nas entradas e no
// botão do painel, que fica sobre o preto da tela.
//
// Escolhas recomendadas, com a delegação do Lipe de 03/11/2026: o "Minimizar" na barra, como o do openGym
// (views/Workout.jsx:2162), para voltar ao Início sem terminar; o painel no preto da tela, com uma
// passagem suave do que rola por baixo, e não no vidro, porque a unidade das entradas, no destaque do
// tema, e o rótulo cinza delas não podem ficar no vidro (#71); nos tamanhos de acessibilidade, o painel
// entra na lista, logo depois do cabeçalho, porque fixo ele passaria da altura da tela; a tela rola até a
// série do painel quando ela muda.
import HexDesign
import HexEngine
import os
import SwiftUI

// De onde o zoom sai: o botão principal do Início ou o "Começar" do editor de rotina.
enum WorkoutZoom: String, Hashable {
  case home = "inicio", routine = "rotina"
}

// O que as telas de onde o treino abre recebem do RootView: o namespace do zoom e quem abre a tela.
struct WorkoutDoor {
  let namespace: Namespace.ID
  let launcher: WorkoutLauncher
}

extension EnvironmentValues {
  @Entry var workoutDoor: WorkoutDoor?
}

// A origem do zoom, quando o RootView deu a porta.
struct WorkoutZoomSource: ViewModifier {
  let source: WorkoutZoom
  @Environment(\.workoutDoor) private var door

  func body(content: Content) -> some View {
    if let door {
      content.hexStartWorkoutSource(id: source, in: door.namespace)
    } else {
      content
    }
  }
}

// Quem começa o treino e abre e fecha a tela. Um treino em andamento ganha de um "Começar": abre o que está
// aí, como o openGym (views/Home.jsx:104, "starting another would overwrite it"). Se o motor recusar o
// começo, o alerta da Apple diz, e o detalhe vai para o log.
@Observable @MainActor final class WorkoutLauncher {
  var isPresented = false
  // O começo falhou: o RootView mostra o alerta.
  var startFailed = false
  // Um treino sendo começado, para um segundo toque não começar outro.
  private(set) var starting = false
  private(set) var source = WorkoutZoom.home

  @ObservationIgnored private let session: WorkoutSession
  @ObservationIgnored private var openedOnLaunch = false
  @ObservationIgnored private var ranDemo = false

  private static let logger = Logger(subsystem: "app.hexgym", category: "treino")

  init(app: AppModel) {
    session = app.session
  }

  var hasWorkout: Bool { session.workout != nil }

  func open(from source: WorkoutZoom, reduceMotion: Bool) {
    self.source = source
    withTransaction(StartWorkoutTransition.transaction(reduceMotion: reduceMotion)) { isPresented = true }
  }

  func close(reduceMotion: Bool) {
    withTransaction(StartWorkoutTransition.transaction(reduceMotion: reduceMotion)) { isPresented = false }
  }

  // Começa o treino das rotinas dadas (o treino livre, sem rotina) e abre a tela pelo zoom. O id do treino
  // vem daqui (escolha 12 do plano: o uid() do openGym não entra no motor).
  func start(_ routineIDs: [String], from source: WorkoutZoom, reduceMotion: Bool) async {
    if session.workout != nil {
      open(from: source, reduceMotion: reduceMotion)
      return
    }
    guard !starting else { return }
    starting = true
    defer { starting = false }
    do {
      _ = try await session.perform(.start(routineIDs: routineIDs, id: UUID().uuidString.lowercased()))
      open(from: source, reduceMotion: reduceMotion)
    } catch {
      Self.logger.error("não deu para começar o treino (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
      startFailed = true
    }
  }

  // Com -HexGymWorkout YES, a tela abre uma vez, sem animação, quando o treino em andamento chega.
  func openOnLaunch() {
    guard WorkoutLaunch.opensWorkout(), !openedOnLaunch, session.workout != nil else { return }
    openedOnLaunch = true
    open(from: .home, reduceMotion: true)
  }

  // Com -HexGymWorkoutDemo inicio, o roteiro do vídeo do PR, como o -HexGymDemo da galeria: do Início, a tela
  // abre pelo zoom do "Continuar treino", registra a série do painel e fecha pelo zoom de volta. Com o
  // Reduzir Movimento, a tela aparece e some sem se mover.
  func runDemo(_ screen: WorkoutScreen, reduceMotion: Bool) async {
    guard WorkoutLaunch.demo() == "inicio", !ranDemo, session.workout != nil else { return }
    ranDemo = true
    do {
      try await Task.sleep(for: .seconds(2.5))
      open(from: .home, reduceMotion: reduceMotion)
      try await Task.sleep(for: .seconds(2))
      await screen.log().value
      try await Task.sleep(for: .seconds(2.2))
      close(reduceMotion: reduceMotion)
    } catch {
      return
    }
  }
}

struct WorkoutView: View {
  let screen: WorkoutScreen
  let close: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    NavigationStack {
      Group {
        if let model = screen.model {
          content(model)
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: close) {
            Label("Minimize", systemImage: "chevron.down")
          }
          .labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Finish", action: close)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .containerBackground(.clear, for: .navigation)
    }
    .background { BreathingGlow() }
    .sensoryFeedback(trigger: screen.session.hapticTick) { _, _ in screen.session.haptic?.feedback(on: .phone) }
  }

  private func content(_ model: WorkoutScreenModel) -> some View {
    // Nos tamanhos de acessibilidade, o painel entra na lista: fixo, ele passaria da altura da tela.
    let inline = typeSize.isAccessibilitySize
    return ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: HexSpacing.l) {
          WorkoutHeader(model: model)
          if inline {
            CurrentSetPanel(model: model, screen: screen, fixed: false)
              .id(Self.inlinePanel)
          }
          VStack(alignment: .leading, spacing: HexSpacing.s) {
            ForEach(model.cards) { card in
              ExerciseCard(card: card, select: { screen.select($0) }, mark: { screen.mark($0) })
            }
          }
        }
        .padding(.horizontal, HexSpacing.m)
        .padding(.top, HexSpacing.xs)
        .padding(.bottom, HexSpacing.xl)
      }
      // A borda firme do iOS 26 em cima: o que rola não aparece por trás dos botões da barra.
      .scrollEdgeEffectStyle(.hard, for: .top)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if !inline {
          CurrentSetPanel(model: model, screen: screen, fixed: true)
        }
      }
      .onAppear { opening(proxy, model) }
      .onChange(of: model.panel?.ref) { _, ref in
        // Fora dos tamanhos de acessibilidade: neles, o painel está no topo da lista, e rolar tiraria ele
        // da tela.
        if !inline { scroll(proxy, to: ref, animated: true) }
      }
    }
  }

  // O id do painel na lista, nos tamanhos de acessibilidade.
  private static let inlinePanel = "painel"

  // Onde a tela abre: na série do painel; ou, pelos argumentos dos prints (WorkoutLaunch), no topo, no
  // fim de um exercício ou no fim do painel da lista. Os argumentos valem também nos tamanhos de
  // acessibilidade, onde a tela, sem eles, abre no topo.
  private func opening(_ proxy: ScrollViewProxy, _ model: WorkoutScreenModel) {
    if WorkoutLaunch.opensAtTop() { return }
    if WorkoutLaunch.opensAtPanelEnd() {
      proxy.scrollTo(Self.inlinePanel, anchor: .bottom)
      return
    }
    if let entry = WorkoutLaunch.entry() {
      if let ref = model.cards.first(where: { $0.entry == entry })?.rows.last?.ref {
        proxy.scrollTo(ref, anchor: typeSize.isAccessibilitySize ? .bottom : UnitPoint(x: 0.5, y: 0.9))
      }
      return
    }
    scroll(proxy, to: model.panel?.ref, animated: false)
  }

  // A tela rola até a série do painel, para ela nunca ficar escondida embaixo dele: a série fica perto do
  // painel, e o que vem antes dela (o cabeçalho, no começo do treino) continua à vista.
  private func scroll(_ proxy: ScrollViewProxy, to ref: WorkoutRef?, animated: Bool) {
    guard let ref, !typeSize.isAccessibilitySize else { return }
    withAnimation(animated ? HexMotion.change.animation(reduceMotion: reduceMotion) : nil) {
      proxy.scrollTo(ref, anchor: UnitPoint(x: 0.5, y: 0.9))
    }
  }
}

// O cabeçalho: o nome do treino, o tempo que passa, "5 de 13 séries" e os segmentos das séries. Sobre o
// fundo da tela, onde o cinza do sistema pode ficar.
private struct WorkoutHeader: View {
  let model: WorkoutScreenModel

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      Text(verbatim: model.name)
        .hexFont(.title)
        .foregroundStyle(Color.white)
        .modifier(WholeWords(model.name))
        .accessibilityAddTraits(.isHeader)
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xxs))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: HexSpacing.s))
      layout {
        if let start = model.start {
          ElapsedClock(start: start)
        }
        if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        Text(verbatim: model.progress)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      SlantedSegments(total: model.total, done: model.done)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// Um nome na tela do treino (o do treino, o do exercício no cartão e no painel) quebra só entre palavras
// (achado 4 do QA da #160): uma linha por palavra, no máximo, e o texto encolhe até a metade antes de
// partir uma palavra longa ("Desenvolvimento" em AX5). A fonte da marca em AX5 nas outras telas fica para
// um follow-up no HexDesign.
struct WholeWords: ViewModifier {
  let lines: Int

  init(_ text: String) {
    lines = max(1, text.split(whereSeparator: \.isWhitespace).count)
  }

  func body(content: Content) -> some View {
    content
      .lineLimit(lines)
      .minimumScaleFactor(0.5)
  }
}

// O tempo que passa desde o começo, num TimelineView de 1 s: o body dele só escreve o relógio, sem ler o
// motor nem o resto da tela.
private struct ElapsedClock: View {
  let start: Date

  @Environment(\.locale) private var locale

  var body: some View {
    TimelineView(.periodic(from: start, by: 1)) { context in
      let seconds = context.date.timeIntervalSince(start)
      Text(verbatim: WorkoutScreenModel.elapsed(seconds))
        .hexFont(.number)
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .accessibilityLabel(Text("Duration"))
        .accessibilityValue(Text(verbatim: WorkoutScreenModel.spokenElapsed(seconds, locale: locale)))
    }
  }
}
