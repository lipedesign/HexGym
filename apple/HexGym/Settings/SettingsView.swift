// Os Ajustes (Task 6 do plano da fase 2): uma List da Apple em seções, nesta ordem: Treino (a unidade,
// o descanso padrão e a escala de esforço), Semana, Corpo, Aparência (os quatro temas) e Sobre (a
// versão, as licenças e a galeria do design system). Cada ajuste do documento grava por uma ação do
// motor (AppModel.perform), e a tela lê de novo pelo engine.settings() quando o revision sobe; o tema
// fica no ThemeModel, no aparelho, sem ação (seção 8.12). O que cada linha mostra e o caminho de cada
// escolha estão no SettingsRows, testado sem tela.
//
// A regra da #71 vale aqui: o texto fica em branco ou nos cinzas do sistema, e a cor do tema só
// aparece na amostra e na marca do tema escolhido, sobre o cartão do sistema.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: as seções nesta ordem, os seletores em
// menu (cabem em qualquer tamanho de texto), as notas embaixo do Treino, do Corpo e da Aparência, e a
// galeria no fim.
import HexDesign
import HexEngine
import os
import SwiftUI

// Para onde os Ajustes levam, além da galeria (GalleryRoute).
enum SettingsRoute: Hashable {
  case licenses
}

struct SettingsView: View {
  let model: AppModel
  @Binding var path: NavigationPath
  @Environment(ThemeModel.self) private var theme
  @Environment(\.locale) private var locale
  // nil enquanto o motor não respondeu.
  @State private var values: SettingsValues?
  // O roteiro dos argumentos de início roda uma vez só, mesmo que a tela volte.
  @State private var ranLaunchScript = false

  private static let logger = Logger(subsystem: "app.hexgym", category: "settings")

  private var rows: SettingsRows { SettingsRows(locale: locale) }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        if let values {
          workoutSection(values).id(SettingsAnchor.workout)
          weekSection(values).id(SettingsAnchor.week)
          bodySection(values).id(SettingsAnchor.body)
        }
        appearance.id(SettingsAnchor.appearance)
        about.id(SettingsAnchor.about)
      }
      .task { await runLaunchScript(proxy) }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Settings")
    .navigationDestination(for: SettingsRoute.self) { _ in LicensesView() }
    .navigationDestination(for: GalleryRoute.self) { _ in GalleryView(path: $path) }
    // O fundo da pilha fica transparente, para o brilho da raiz aparecer atrás.
    .containerBackground(.clear, for: .navigation)
    .task(id: model.revision) { await load() }
  }

  private func workoutSection(_ values: SettingsValues) -> some View {
    Section {
      Picker("Unit", selection: binding(values.unit, SettingsChoice.unit)) {
        ForEach([WeightUnit.kg, .lb], id: \.self) { Text(verbatim: rows.unit($0)).tag($0) }
      }
      // O rótulo de cada opção vale no menu aberto e na linha fechada (#94, conferido no simulador com a
      // acessibilidade do sistema carregada): no menu, o VoiceOver lê "1 min 30 s" onde a tela mostra
      // "1:30", e a linha fechada diz "Descanso padrão, 1 min 30 s". Por isso, nenhum accessibilityValue
      // no Picker: ele repetiria o tempo depois do rótulo.
      Picker("Default rest", selection: binding(values.restSec, SettingsChoice.rest)) {
        ForEach(SettingsRows.restOptions(current: values.restSec), id: \.self) { seconds in
          Text(verbatim: rows.rest(seconds))
            .accessibilityLabel(Text(verbatim: rows.spokenRest(seconds)))
            .tag(seconds)
        }
      }
      Picker("Effort scale", selection: binding(values.effort, SettingsChoice.effort)) {
        ForEach(EffortChoice.allCases, id: \.self) { Text(verbatim: rows.effort($0)).tag($0) }
      }
      .id(SettingsAnchor.effort)
    } header: {
      SettingsHeader("Workout")
    } footer: {
      Text("Changing the unit converts the loads in your routines. RIR counts the reps you had left; RPE rates the same effort from 1 to 10.")
    }
  }

  private func weekSection(_ values: SettingsValues) -> some View {
    Section {
      Picker("First day", selection: binding(values.weekStart, SettingsChoice.weekStart)) {
        ForEach(WeekStart.allCases, id: \.self) { Text(verbatim: rows.weekStart($0)).tag($0) }
      }
    } header: {
      SettingsHeader("Week")
    }
  }

  private func bodySection(_ values: SettingsValues) -> some View {
    Section {
      Picker("Muscle map", selection: binding(values.body, SettingsChoice.body)) {
        ForEach(BodyChoice.allCases, id: \.self) { Text(verbatim: rows.body($0)).tag($0) }
      }
    } header: {
      SettingsHeader("Body")
    } footer: {
      Text("The body the muscles of each exercise are shown on.")
    }
  }

  private var appearance: some View {
    Section {
      // Os quatro numa linha só da List, com as divisórias entre eles: em quatro linhas, a List deixava
      // uma fresta de 1 px entre os fundos de duas delas.
      VStack(spacing: 0) {
        ForEach(HexTheme.allCases, id: \.self) { option in
          ThemeChoiceRow(theme: option, isSelected: theme.theme == option) { choose(.theme(option)) }
          if option != HexTheme.allCases.last { Divider() }
        }
      }
    } header: {
      SettingsHeader("Appearance")
    } footer: {
      Text("The theme stays on this device only.")
    }
  }

  private var about: some View {
    Section {
      LabeledContent("Version") { Text(verbatim: SettingsRows.version()) }
      NavigationLink(value: SettingsRoute.licenses) { Text("Licenses") }
      NavigationLink(value: GalleryRoute.gallery) { Text("Design system gallery") }
    } header: {
      SettingsHeader("About")
    }
  }

  // O seletor lê o valor de agora e manda a escolha pelo choose.
  private func binding<Value>(_ value: Value, _ choice: @escaping (Value) -> SettingsChoice) -> Binding<Value> {
    Binding(get: { value }, set: { choose(choice($0)) })
  }

  // O tema troca no ThemeModel, dentro do SettingsRows.change, e não vai ao motor. O resto muda na
  // tela na hora e vai ao motor pelo perform; se a ação falhar, o erro vai para o log e a tela lê de
  // novo o que o documento tem. No log, como no AppModel, o tipo do erro fica público e o detalhe,
  // privado, porque a mensagem do motor pode trazer um pedaço do documento.
  private func choose(_ choice: SettingsChoice) {
    guard let change = SettingsRows.change(for: choice, theme: theme) else { return }
    values?.apply(choice)
    Task {
      do {
        _ = try await model.perform(.setSetting(change))
      } catch {
        Self.logger.error("não deu para gravar o ajuste (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
        await load()
      }
    }
  }

  private func load() async {
    do {
      values = SettingsValues(try await model.engine.settings())
    } catch {
      Self.logger.error("não deu para ler os ajustes (\(String(describing: type(of: error)), privacy: .public)): \(String(describing: error), privacy: .private)")
    }
  }

  // O que os argumentos de início pedem (SettingsLaunch), para os prints e o vídeo do PR saírem do
  // simulador sem tocar na tela. As trocas passam pelo mesmo choose dos seletores.
  private func runLaunchScript(_ proxy: ScrollViewProxy) async {
    guard !ranLaunchScript else { return }
    ranLaunchScript = true
    if let anchor = SettingsLaunch.anchor {
      try? await Task.sleep(for: .milliseconds(600))
      proxy.scrollTo(anchor, anchor: .top)
    }
    switch SettingsLaunch.script {
    case "demo":
      // O vídeo: a unidade vai para lb, os temas trocam um depois do outro, e tudo volta.
      try? await Task.sleep(for: .seconds(1.2))
      choose(.unit(.lb))
      try? await Task.sleep(for: .seconds(1.2))
      withAnimation(.easeInOut(duration: 0.8)) { proxy.scrollTo(SettingsAnchor.appearance, anchor: .center) }
      for next in [HexTheme.copper, .cyan, .chalk, .ultraviolet] {
        try? await Task.sleep(for: .seconds(1.1))
        choose(.theme(next))
      }
      try? await Task.sleep(for: .seconds(1.1))
      withAnimation(.easeInOut(duration: 0.8)) { proxy.scrollTo(SettingsAnchor.workout, anchor: .top) }
      try? await Task.sleep(for: .seconds(1.2))
      choose(.unit(.kg))
    case "flush":
      // A conferência do flush(): 3 s depois de abrir, avisa no log que vai trocar o corpo e troca 0,8 s
      // depois, com a hora, para quem confere mandar o app para o fundo logo depois da troca (a troca de
      // app no simulador leva quase 1 s) e comparar com a gravação.
      try? await Task.sleep(for: .seconds(3))
      Self.logger.notice("roteiro: troca do corpo em 0,8 s")
      try? await Task.sleep(for: .seconds(0.8))
      guard let body = values?.body else { return }
      let next: BodyChoice = body == .male ? .female : .male
      choose(.body(next))
      Self.logger.notice("roteiro: corpo trocado para \(next.rawValue, privacy: .public)")
    default:
      break
    }
  }
}

// Os lugares dos Ajustes para onde o -HexGymSection rola.
enum SettingsAnchor {
  static let workout = "workout", effort = "effort", week = "week", body = "body", appearance = "appearance"
  static let about = "about"
  // Nas Licenças: os links do código do openGym e do HexGym.
  static let opengym = "opengym"
}

// Os argumentos de início dos Ajustes, como os da galeria (GalleryLaunch), do domínio dos argumentos
// dos UserDefaults padrão, que não fica gravado. Com -HexGymSkipOnboarding YES junto, desde a Task 7,
// para a primeira abertura não aparecer antes (OnboardingLaunch):
//   -HexGymTab ajustes             abre nos Ajustes (RootTab.launch)
//   -HexGymSection appearance      rola até uma seção (SettingsAnchor); a galeria lê a mesma chave
//   -HexGymSettingsScript demo     o roteiro do vídeo do PR: troca a unidade e o tema
//   -HexGymSettingsScript flush    troca o corpo 3,8 s depois de abrir, para conferir o flush()
//   -HexGymSettingsOpen licenses   abre as Licenças; musclemap e barlow abrem o texto de uma licença
//   -HexGymSection opengym         nas Licenças, rola até os links do código do openGym e do HexGym
enum SettingsLaunch {
  private static var defaults: UserDefaults { .standard }

  static var anchor: String? { defaults.string(forKey: "HexGymSection") }
  static var script: String? { defaults.string(forKey: "HexGymSettingsScript") }

  // A pilha dos Ajustes quando o app abre: a galeria (GalleryLaunch), as Licenças ou o texto de uma
  // licença, ou nada.
  static var path: NavigationPath {
    if GalleryLaunch.opensGallery { return NavigationPath([GalleryRoute.gallery]) }
    var path = NavigationPath()
    switch defaults.string(forKey: "HexGymSettingsOpen") {
    case "licenses":
      path.append(SettingsRoute.licenses)
    case "musclemap":
      path.append(SettingsRoute.licenses)
      path.append(LicenseText(title: "MuscleMap", source: .bundle("LICENSE-MuscleMap")))
    case "barlow":
      path.append(SettingsRoute.licenses)
      path.append(LicenseText(title: "Barlow Condensed", source: .url(HexFonts.licenseURL)))
    default:
      break
    }
    return path
  }
}

// O título de uma seção, na escala do HexDesign, em branco. A altura da linha da Barlow não é um
// número inteiro de pontos, e a List põe as células da seção logo abaixo do título: fora da grade de
// pixels, ficava uma fresta de 1 px entre duas células. Por isso a altura do título sobe para o ponto
// inteiro seguinte (WholePointHeight).
struct SettingsHeader: View {
  let title: Text

  init(_ title: LocalizedStringKey) {
    self.title = Text(title)
  }

  init(verbatim title: String) {
    self.title = Text(verbatim: title)
  }

  var body: some View {
    WholePointHeight {
      title
        .hexFont(.caption)
        .foregroundStyle(Color.white)
    }
    .accessibilityAddTraits(.isHeader)
  }
}

// Uma view com a altura arredondada para cima, para um número inteiro de pontos, e a largura dela.
struct WholePointHeight: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let size = subviews.first?.sizeThatFits(proposal) ?? .zero
    return CGSize(width: size.width, height: size.height.rounded(.up))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
  }
}

// Uma linha de tema: a amostra do destaque daquele tema, o nome em branco e a marca de escolhido, como
// o seletor da galeria, com pelo menos 44 pt de altura. Os quatro dividem uma linha da List, e por isso
// o botão é plain: no estilo padrão, um toque na linha apertaria os quatro. O fundo da linha é o
// secondarySystemGroupedBackground, o mesmo cinza do cartão do sistema (SystemCardTests), onde a cor do
// tema pode ficar (#71). A primeira abertura usa as mesmas linhas, no passo do tema.
struct ThemeChoiceRow: View {
  let theme: HexTheme
  let isSelected: Bool
  let select: () -> Void

  @Environment(\.locale) private var locale
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexPalette) private var palette
  // A amostra acompanha o texto no Dynamic Type, de 18 pt até 36 pt (no AX5, sem o teto, passaria de
  // 50 pt e tomaria o lugar do nome).
  @ScaledMetric(relativeTo: .body) private var scaledSwatch: CGFloat = 18
  private var swatchSize: CGFloat { min(scaledSwatch, 36) }

  // O destaque daquele tema no contraste do aparelho.
  private var swatch: Color {
    Color(HexPalette.resolve(theme, scheme: .dark, contrast: contrast == .increased ? .increased : .standard).accent)
  }

  var body: some View {
    Button(action: select) {
      HStack(spacing: HexSpacing.s) {
        Circle().fill(swatch).frame(width: swatchSize, height: swatchSize)
        // A marca ao lado do nome quando os dois cabem numa linha; senão (no AX5), embaixo dele, para o
        // nome não quebrar no meio da palavra. Só na linha escolhida: nas outras, o espaço vai para o nome.
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
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: theme.displayName(locale: locale)))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var name: some View {
    Text(verbatim: theme.displayName(locale: locale)).foregroundStyle(Color.white)
  }

  private var checkmark: some View {
    Image(systemName: "checkmark")
      .font(.body.weight(.semibold))
      .foregroundStyle(Color(palette.accent))
  }
}
