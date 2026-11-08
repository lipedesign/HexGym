// A aba Início (Task 7 do plano da fase 3, issue #136, escolha 2), de cima para baixo: o cartão de hoje,
// de vidro (as rotinas do dia e os exercícios delas, "Dia de descanso", o treino feito, o treino em
// andamento com o tempo que passa e as séries, ou, no app vazio, "Monte a sua primeira rotina" com o
// botão para a aba Rotinas); o botão principal grande ("Começar treino", "Continuar treino", "Começar
// treino livre" ou o próprio "Escolher outro treino"); o "Escolher outro treino" num Menu da Apple, com as
// rotinas e o treino livre; a semana (WeekStrip); a sequência de semanas e os treinos da semana e do
// histórico; e o último treino.
//
// Tudo vem pronto do HomeModel, pelo HomeScreen: o body não calcula nada. O tempo do treino em andamento
// conta por um TimelineView de 1 s a partir do começo, sem ler o motor de novo a cada tique (seção 8.13).
// A tela lê o motor de novo a cada revision do documento e ao voltar para a frente, porque o dia pode ter
// virado.
//
// Até a Task 8, o "Começar treino" começa o treino e o Início passa a mostrar o treino em andamento, sem
// abrir tela nenhuma, e o "Continuar treino" não abre nada; até a Task 12, o último treino não abre o
// detalhe.
//
// A regra da #71 vale aqui: no cartão de vidro, o texto vai só em branco; a cor do tema fica na semana, na
// chama da sequência e nos botões, sobre o fundo da tela; o último treino fica no cartão do sistema.
//
// A tela rola, e nos tamanhos de acessibilidade o tempo e as séries do treino em andamento ficam um embaixo
// do outro: nada corta em AX5.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: "Hoje" e o dia da semana em cima do título
// do cartão; o tempo do treino no estilo de número do HexDesign; a semana com o título "Semana"; a chama no
// destaque do tema, como a chama laranja do openGym; e o último treino no cartão do sistema, sem a seta,
// até ele abrir o detalhe.
import HexDesign
import HexEngine
import SwiftUI

struct HomeView: View {
  let screen: HomeScreen
  // O botão do app vazio leva para a aba Rotinas.
  let goToRoutines: () -> Void
  // O "Continuar treino": a tela do treino é da Task 8.
  var resume: () -> Void = {}

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        if let model = screen.model {
          HomeContent(model: model, starting: screen.starting, start: start, goToRoutines: goToRoutines, resume: resume)
        }
      }
      .onChange(of: screen.phase) { _, phase in
        // Só para os prints em AX5: a tela rolada até uma parte (HomeLaunch).
        if phase == .ready, let anchor = HomeLaunch.scroll {
          Task { @MainActor in
            // Depois de a tela se desenhar com o modelo.
            try? await Task.sleep(for: .milliseconds(300))
            proxy.scrollTo(anchor, anchor: .top)
          }
        }
      }
    }
    .overlay { overlay }
    .navigationTitle("Home")
    .task { await screen.load() }
    .onChange(of: screen.documentRevision) { Task { await screen.load() } }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await screen.load() } }
    }
    .containerBackground(.clear, for: .navigation)
  }

  private func start(_ routineIDs: [String]) {
    Task { await screen.start(routineIDs) }
  }

  @ViewBuilder private var overlay: some View {
    switch screen.phase {
    case .loading:
      ProgressView()
    case .failed:
      ContentUnavailableView {
        Label("Couldn't open your data.", systemImage: "exclamationmark.triangle")
      }
    case .ready:
      EmptyView()
    }
  }
}

private struct HomeContent: View {
  let model: HomeModel
  let starting: Bool
  let start: ([String]) -> Void
  let goToRoutines: () -> Void
  let resume: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.l) {
      VStack(spacing: HexSpacing.s) {
        TodayCard(model: model, goToRoutines: goToRoutines)
        primary
          .id(HomeAnchor.primary)
        if model.offersChooser {
          WorkoutChooser(model: model, start: start) {
            Label(model.chooserLabel, systemImage: "arrow.left.arrow.right")
              .font(.body.weight(.semibold))
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity, minHeight: HexTarget.minimum)
          }
          .hexSecondaryButton()
          .disabled(starting)
        }
      }
      VStack(alignment: .leading, spacing: HexSpacing.s) {
        SettingsHeader("Week")
          .id(HomeAnchor.week)
        WeekStrip(days: model.week, spoken: model.weekSpoken)
        if let streak = model.streak {
          StreakLine(streak: streak, tally: model.tally)
            .padding(.top, HexSpacing.xs)
        }
      }
      if let last = model.last {
        VStack(alignment: .leading, spacing: HexSpacing.s) {
          SettingsHeader("Last workout")
            .id(HomeAnchor.last)
          LastWorkoutRow(last: last)
        }
      }
    }
    .padding(.horizontal, HexSpacing.m)
    .padding(.top, HexSpacing.xs)
    .padding(.bottom, HexSpacing.xl)
  }

  // O botão principal grande, ou, sem treino para começar hoje, o próprio "Escolher outro treino".
  @ViewBuilder private var primary: some View {
    switch model.primary {
    case .resume:
      Button(action: resume) { Text(verbatim: model.primaryLabel) }
        .buttonStyle(.hexPrimary(size: .large))
    case .start(let ids):
      Button { start(ids) } label: { Text(verbatim: model.primaryLabel) }
        .buttonStyle(.hexPrimary(size: .large))
        .disabled(starting)
    case .freestyle:
      Button { start([]) } label: { Text(verbatim: model.primaryLabel) }
        .buttonStyle(.hexPrimary(size: .large))
        .disabled(starting)
    case .choose:
      WorkoutChooser(model: model, start: start) { Text(verbatim: model.primaryLabel) }
        .menuStyle(.button)
        .buttonStyle(.hexPrimary(size: .large))
        .disabled(starting)
    }
  }
}

// O "Escolher outro treino": um Menu da Apple, com as rotinas na ordem da lista e o treino livre no fim.
private struct WorkoutChooser<LabelView: View>: View {
  let model: HomeModel
  let start: ([String]) -> Void
  @ViewBuilder let label: LabelView

  var body: some View {
    Menu {
      ForEach(model.chooser) { choice in
        Button { start([choice.id]) } label: {
          Label(choice.name, systemImage: choice.symbol)
        }
      }
      Section {
        Button { start([]) } label: {
          Label(model.freestyleLabel, systemImage: "shuffle")
        }
      }
    } label: {
      label
    }
  }
}

// O cartão de hoje, de vidro. Todo texto nele fica em branco (regra da #71).
private struct TodayCard: View {
  let model: HomeModel
  let goToRoutines: () -> Void

  var body: some View {
    HexGlassCard {
      VStack(alignment: .leading, spacing: HexSpacing.xs) {
        Text(verbatim: model.eyebrow)
          .hexFont(.caption)
          .foregroundStyle(Color.white)
        Text(verbatim: model.title)
          .hexFont(.title)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
        if let active = model.active {
          ActiveProgress(active: active)
            .padding(.top, HexSpacing.xxs)
        }
        if let detail = model.detail {
          Text(verbatim: detail)
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
        }
        if model.goesToRoutines {
          Button(action: goToRoutines) {
            Text(verbatim: model.routinesLabel)
              .font(.body.weight(.semibold))
              .foregroundStyle(Color.white)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity, minHeight: HexTarget.minimum)
          }
          .hexSecondaryButton()
          .padding(.top, HexSpacing.xs)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// O treino em andamento no cartão: o tempo que passa, "5 de 18 séries" e os segmentos inclinados. O tempo
// conta a partir do começo, num TimelineView de 1 s, sem ler o motor.
private struct ActiveProgress: View {
  let active: HomeActiveCard

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xxs))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: HexSpacing.s))
      layout {
        if let start = active.start {
          TimelineView(.periodic(from: start, by: 1)) { context in
            let seconds = context.date.timeIntervalSince(start)
            Text(verbatim: HomeModel.elapsed(seconds))
              .hexFont(.number)
              .foregroundStyle(Color.white)
              .accessibilityLabel(Text("Duration"))
              .accessibilityValue(Text(verbatim: HomeModel.spokenElapsed(seconds, locale: locale)))
          }
        }
        if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        Text(verbatim: active.progress)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
      }
      SlantedSegments(total: active.total, done: active.done)
        .accessibilityHidden(true)
    }
  }
}

// "Sequência de 3 semanas", com a chama no destaque do tema, e "2 esta semana · 12 treinos no total".
private struct StreakLine: View {
  let streak: String
  let tally: String?

  @Environment(\.hexPalette) private var palette

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xxs) {
      Label {
        Text(verbatim: streak)
          .hexFont(.headline)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "flame.fill")
          .foregroundStyle(Color(palette.accent))
      }
      if let tally {
        Text(verbatim: tally)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

// O último treino, no cartão do sistema (#1C1C1E, ou #242426 com Aumentar Contraste): o nome e, embaixo,
// a data, a duração e as séries. Até a Task 12, não abre nada, e por isso não é botão nem tem a seta.
private struct LastWorkoutRow: View {
  let last: HomeLastWorkout

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xxs) {
      Text(verbatim: last.name)
        .font(.body.weight(.semibold))
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
      Text(verbatim: last.detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, minHeight: HexTarget.minimum, alignment: .leading)
    .padding(.horizontal, HexSpacing.m)
    .padding(.vertical, HexSpacing.s)
    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: last.spoken))
  }
}

// As partes da tela para onde o -HexGymHomeScroll rola.
enum HomeAnchor: String {
  case primary = "botao", week = "semana", last = "ultimo"
}

// O argumento de início do Início, como os das Rotinas (RoutinesLaunch), do domínio dos argumentos dos
// UserDefaults padrão, que não fica gravado, para os prints em AX5 saírem do simulador sem tocar na tela.
// Com -HexGymTab inicio e -HexGymSkipOnboarding YES junto:
//   -HexGymHomeScroll <botao|semana|ultimo>   a tela rolada até o botão principal, a semana ou o último
//                                             treino
enum HomeLaunch {
  static var scroll: HomeAnchor? {
    UserDefaults.standard.string(forKey: "HexGymHomeScroll").flatMap(HomeAnchor.init(rawValue:))
  }
}
