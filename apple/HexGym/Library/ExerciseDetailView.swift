// O detalhe do exercício (Task 10 do plano da fase 2, issue #97), aberto de uma linha da biblioteca.
// De cima para baixo: o nome em .hexFont(.title), que quebra a linha sem teto de linhas; o equipamento e
// a categoria; o cartão "Músculos" (HexGlassCard), com a MuscleList até a Task 14; "Como fazer", os
// passos numerados; e a descrição, quando há. Na barra, a estrela e o "Adicionar à rotina", um Menu da
// Apple com as rotinas e "Nova rotina". Nenhuma foto nem animação nesta fase (seção 8.8).
//
// Tudo o que a tela mostra e o que o VoiceOver diz vem pronto do ExerciseDetailModel, pelo
// ExerciseDetailScreen: o body não calcula nada. A estrela muda na hora, pela ação .toggleFavourite,
// como na lista. "Adicionar à rotina" aplica o addExercises e confirma com o sensoryFeedback(.success),
// uma faixa "Adicionado a <rotina>" no pé da tela por alguns segundos e um anúncio do VoiceOver. Com
// Reduzir Movimento, a faixa só esmaece. Um exercício desconhecido mostra só o nome e a linha que diz
// que ele não está na biblioteca deste aparelho, sem a estrela e sem o menu.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema. Os botões da barra seguem o
// tint branco da raiz (RootTint), e não o accent, que sobre o vidro da barra não é conferido.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a ordem da tela do plano, os títulos
// "Músculos", "Como fazer" e "Sobre o exercício" no headline do HexDesign, a barra sem título (o nome
// grande já está no topo), a estrela e o "Adicionar à rotina" como símbolos na barra (o VoiceOver diz o
// nome, e a Visualização de Conteúdo Grande mostra o nome nos tamanhos de acessibilidade), "Nova rotina"
// no fim do menu, depois das rotinas, e a faixa da confirmação por 2,5 s. Desde a Task 11, a rotina que
// já tem o exercício leva a marca da Apple no menu.
import HexDesign
import SwiftUI

// As partes da tela até onde o -HexGymExerciseScroll rola.
enum ExerciseSection: String {
  case muscles, steps
}

// O caminho da pilha da biblioteca até o detalhe de um exercício.
struct ExerciseRoute: Hashable {
  let id: String
}

struct ExerciseDetailView: View {
  @State private var screen: ExerciseDetailScreen
  // A faixa da confirmação, enquanto ela aparece.
  @State private var notice: String?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(screen: @autoclosure @escaping () -> ExerciseDetailScreen) {
    _screen = State(wrappedValue: screen())
  }

  var body: some View {
    content
      .overlay { overlay }
      .overlay(alignment: .bottom) { banner }
      .toolbar { toolbar }
      .navigationBarTitleDisplayMode(.inline)
      .sensoryFeedback(.success, trigger: screen.confirmations)
      .task { await appear() }
      .task(id: screen.notices) { await showNotice() }
      .onChange(of: screen.documentRevision) { Task { await screen.loadRoutines() } }
      .containerBackground(.clear, for: .navigation)
  }

  @ViewBuilder private var content: some View {
    if let model = screen.model {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: HexSpacing.l) {
            header(model)
            if let note = model.unknownNote {
              Text(verbatim: note)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !model.muscles.isEmpty { muscles(model).id(ExerciseSection.muscles) }
            if !model.steps.isEmpty { steps(model).id(ExerciseSection.steps) }
            if let about = model.about { aboutSection(about) }
          }
          .padding(.horizontal, HexSpacing.m)
          .padding(.top, HexSpacing.xs)
          .padding(.bottom, HexSpacing.xxl)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .task {
          // Só com -HexGymExerciseScroll: a tela já rolada até o cartão ou os passos, para os prints.
          if let section = ExerciseLaunch.scroll { proxy.scrollTo(section, anchor: .top) }
        }
      }
    } else {
      Color.clear
    }
  }

  // Abrindo, ou o detalhe que não abriu.
  @ViewBuilder private var overlay: some View {
    switch screen.phase {
    case .loading:
      ProgressView()
    case .failed:
      ContentUnavailableView {
        Label("Couldn't open the exercise.", systemImage: "exclamationmark.triangle")
      }
    case .ready:
      EmptyView()
    }
  }

  private func header(_ model: ExerciseDetailModel) -> some View {
    VStack(alignment: .leading, spacing: HexSpacing.xs) {
      Text(verbatim: model.name)
        .hexFont(.title)
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if !model.subtitle.isEmpty {
        Text(verbatim: model.subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // O cartão "Músculos": o título, e a lista como um elemento só do VoiceOver, com o texto do modelo.
  private func muscles(_ model: ExerciseDetailModel) -> some View {
    HexGlassCard {
      VStack(alignment: .leading, spacing: HexSpacing.s) {
        SectionTitle("Muscles")
        MuscleList(sections: model.muscles)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(verbatim: model.musclesSpoken))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // "Como fazer": cada passo com o número, um elemento do VoiceOver por passo ("Passo 1. …").
  private func steps(_ model: ExerciseDetailModel) -> some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      SectionTitle("How to do it")
      ForEach(model.steps) { step in
        StepRow(step: step)
      }
    }
  }

  private func aboutSection(_ about: String) -> some View {
    VStack(alignment: .leading, spacing: HexSpacing.s) {
      SectionTitle("About this exercise")
      Text(verbatim: about)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // A faixa "Adicionado a <rotina>" no pé da tela.
  @ViewBuilder private var banner: some View {
    if let notice {
      Label {
        Text(verbatim: notice)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: screen.confirmationSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.white)
      .padding(.horizontal, HexSpacing.m)
      .padding(.vertical, HexSpacing.s)
      .frame(minHeight: HexTarget.minimum)
      .glassEffect(.regular, in: Capsule())
      .padding(.horizontal, HexSpacing.m)
      .padding(.bottom, HexSpacing.m)
      .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    if let model = screen.model, model.known {
      ToolbarItemGroup(placement: .topBarTrailing) {
        // O rótulo diz o estado, porque o botão da barra do UIKit não leva o .isSelected (QA do PR #113).
        Button { Task { await screen.toggleFavourite() } } label: {
          Label(model.favouriteLabel, systemImage: model.favourite ? "star.fill" : "star")
        }
        Menu {
          ForEach(screen.routines) { routine in
            Button { Task { await screen.add(to: routine.id) } } label: {
              if routine.hasExercise {
                Label(routine.name, systemImage: "checkmark")
              } else {
                Text(verbatim: routine.name)
              }
            }
            .accessibilityLabel(Text(verbatim: routine.spoken))
          }
          if !screen.routines.isEmpty { Divider() }
          Button { Task { await screen.addToNewRoutine() } } label: {
            Label("New routine", systemImage: "plus")
          }
        } label: {
          Label("Add to routine", systemImage: "text.badge.plus")
        }
      }
    }
  }

  // Abre o detalhe e, só com -HexGymExerciseAdd new, põe o exercício numa rotina nova, para o print da
  // confirmação (ExerciseLaunch).
  private func appear() async {
    let first = screen.model == nil
    await screen.load()
    if first, ExerciseLaunch.addsToNewRoutine(screen.id) { await screen.addToNewRoutine() }
  }

  // A faixa aparece com a confirmação nova, o VoiceOver anuncia o texto, e ela some 2,5 s depois. Uma
  // confirmação nova no meio cancela a espera da anterior.
  private func showNotice() async {
    guard screen.notices > 0, let text = screen.confirmation else { return }
    withAnimation(HexMotion.enter.animation(reduceMotion: reduceMotion)) { notice = text }
    AccessibilityNotification.Announcement(text).post()
    do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
    withAnimation(HexMotion.change.animation(reduceMotion: reduceMotion)) { notice = nil }
  }
}

// O título de uma parte da tela, no headline do HexDesign, em branco, como cabeçalho do VoiceOver.
private struct SectionTitle: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .hexFont(.headline)
      .foregroundStyle(Color.white)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}

// Um passo de "Como fazer": o número numa coluna e o texto ao lado, que quebra a linha. O VoiceOver
// diz o passo inteiro de uma vez, com o texto pronto do modelo.
private struct StepRow: View {
  let step: ExerciseStep
  @ScaledMetric(relativeTo: .body) private var numberWidth: CGFloat = 24

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: HexSpacing.s) {
      Text(step.number, format: .number)
        .font(.body.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: numberWidth, alignment: .trailing)
      Text(verbatim: step.text)
        .font(.body)
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: step.spoken))
  }
}

// Os argumentos de início do detalhe, como os da biblioteca (LibraryLaunch), do domínio dos argumentos
// dos UserDefaults padrão, que não fica gravado, para os prints do PR saírem do simulador sem tocar na
// tela. Com -HexGymTab exercicios e -HexGymSkipOnboarding YES junto:
//   -HexGymExercise 0025          abre a aba já no detalhe desse exercício (um id que não existe abre o
//                                 do desconhecido)
//   -HexGymExerciseAdd new        põe o exercício numa rotina nova ao abrir, pela ação do motor (grava
//                                 no documento do simulador), para o print da confirmação
//   -HexGymExerciseScroll muscles  abre a tela já rolada até o cartão "Músculos" (ou steps, até "Como
//                                 fazer"), para os prints em AX5
enum ExerciseLaunch {
  private static var defaults: UserDefaults { .standard }

  static var exercise: String? {
    defaults.string(forKey: "HexGymExercise").map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
  }

  // A parte da tela até onde ela abre rolada, ou nil.
  static var scroll: ExerciseSection? { defaults.string(forKey: "HexGymExerciseScroll").flatMap(ExerciseSection.init(rawValue:)) }

  // A pilha da aba Exercícios quando o app abre: o detalhe pedido, ou só a lista.
  static var path: [ExerciseRoute] { exercise.map { [ExerciseRoute(id: $0)] } ?? [] }

  // Só o detalhe aberto pelo argumento, e só uma vez, põe o exercício na rotina nova.
  @MainActor static func addsToNewRoutine(_ id: String) -> Bool {
    guard !added, defaults.string(forKey: "HexGymExerciseAdd") == "new", id == exercise else { return false }
    added = true
    return true
  }

  @MainActor private static var added = false
}
