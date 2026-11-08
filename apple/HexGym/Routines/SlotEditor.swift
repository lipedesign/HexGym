// A edição de um exercício da rotina (Task 11 do plano da fase 2, issue #98), numa tela que sobe: as
// séries (o Stepper da Apple, de 1 a 20), as repetições (o RepsInput do HexDesign, de 1 a 100) ou, no
// modo "Tempo", os segundos (o Stepper da Apple, de 5 em 5 s, até 3.600), a carga (o LoadInput, com o
// passo do increment do SlotSummary), o modo ("Repetições" ou "Tempo") e a nota. O RepsInput tem o
// rótulo e a fala fixos de repetições, por isso não serve para as séries nem para os segundos.
//
// Cada toque muda a tela na hora (o SlotDraft) e manda o updateSlot ao motor sem esperar (seção 8.13),
// uma ação depois da outra, na ordem dos toques. A nota vai 0,4 s depois da última letra e, de qualquer
// jeito, quando a tela fecha. Um exercício de cardio do openGym mostra só as séries e a nota: a duração e
// a velocidade dele chegam numa próxima versão.
//
// Numa tela que sobe, as entradas ficam direto no fundo dela, nunca num cartão (a regra da galeria). Nos
// tamanhos de acessibilidade, as entradas do treino empilham (WorkoutInputLayout), o modo vira um menu e
// os Steppers põem o valor embaixo do rótulo, para nada ser cortado (Foco da revisão 5).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o nome do exercício no topo, quebrando a
// linha, e o título "Editar exercício" na barra; o modo em segmentos (em menu nos tamanhos de
// acessibilidade); a nota de até 500 letras numa caixa que cresce até oito linhas.
import HexDesign
import HexEngine
import Observation
import SwiftUI

@Observable @MainActor final class SlotEditorScreen: Identifiable {
  let routineID: String
  let index: Int
  let name: String
  let known: Bool
  private(set) var draft: SlotDraft
  let locale: Locale

  nonisolated var id: String { "\(routineID)#\(index)" }

  // Os textos que a tela mostra, prontos.
  var setsText: String { draft.sets.formatted(.number.grouping(.never).locale(locale)) }
  var secondsText: String { RestRingModel.time(draft.seconds) }
  var secondsSpoken: String { SettingsRows(locale: locale).spokenRest(draft.seconds) }

  var note: String { draft.note }

  // O que a pessoa escreveu no campo da nota: devolve o texto que o campo deve mostrar, cortado nas 500
  // unidades, e a nota vai ao motor depois. Quando o corte muda o que chegou, o campo volta para o
  // cortado, mesmo que a nota não mude (a pessoa escreveu além do limite).
  func typeNote(_ text: String) -> String {
    if let fields = draft.setNote(text) {
      pendingNote = fields
      scheduleNote()
    }
    return draft.note
  }

  @ObservationIgnored private let perform: (EngineAction) async throws -> ActionOutcome
  // A última ação mandada: cada uma espera a de antes, para o motor receber na ordem dos toques.
  @ObservationIgnored private var last: Task<Void, Never>?
  @ObservationIgnored private var pendingNote: SlotFields?
  @ObservationIgnored private var noteTimer: Task<Void, Never>?

  static let noteDelay = Duration.milliseconds(400)

  init(routineID: String, index: Int, row: SlotRow, slot: SlotSummary, unit: WeightUnit, locale: Locale,
       perform: @escaping (EngineAction) async throws -> ActionOutcome) {
    self.routineID = routineID
    self.index = index
    name = row.name
    known = row.known
    draft = SlotDraft(slot, unit: unit)
    self.locale = locale
    self.perform = perform
  }

  func stepSets(_ direction: StepDirection) { send(draft.stepSets(direction)) }
  func stepReps(_ direction: StepDirection) { send(draft.stepReps(direction)) }
  func stepSeconds(_ direction: StepDirection) { send(draft.stepSeconds(direction)) }
  func stepLoad(_ direction: StepDirection) { send(draft.stepLoad(direction)) }
  func setMode(_ mode: SlotMode) { send(draft.setMode(mode)) }

  // Manda a nota que ainda esperava e volta quando todas as ações chegaram ao motor.
  func flush() async {
    noteTimer?.cancel()
    noteTimer = nil
    if let fields = pendingNote {
      pendingNote = nil
      send(fields)
    }
    await last?.value
  }

  private func scheduleNote() {
    noteTimer?.cancel()
    noteTimer = Task { [weak self] in
      do { try await Task.sleep(for: Self.noteDelay) } catch { return }
      guard let self, let fields = self.pendingNote else { return }
      self.pendingNote = nil
      self.send(fields)
    }
  }

  private func send(_ fields: SlotFields?) {
    guard let fields else { return }
    let previous = last
    let action = EngineAction.updateSlot(routineID: routineID, index: index, fields: fields)
    last = Task { [perform] in
      await previous?.value
      do {
        _ = try await perform(action)
      } catch {
        RoutinesScreen.log("não deu para mudar o exercício", error)
      }
    }
  }
}

struct SlotEditor: View {
  let screen: SlotEditorScreen

  // O texto do campo da nota. O TextField fica com o que a pessoa escreveu quando o valor de uma
  // Binding não muda; com o estado da tela, o onChange põe o texto cortado de volta.
  @State private var noteText: String
  @FocusState private var noteFocused: Bool

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize

  init(screen: SlotEditorScreen) {
    self.screen = screen
    _noteText = State(initialValue: screen.note)
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: HexSpacing.l) {
            header
            if screen.draft.mode != .cardio { mode }
            sets
            switch screen.draft.mode {
            case .reps:
              RepsInput(value: screen.draft.reps) { screen.stepReps($0) }
                .id(SlotEditorAnchor.inputs)
            case .time:
              seconds
                .id(SlotEditorAnchor.inputs)
            case .cardio:
              Text("Duration and speed for cardio come in a later version.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if screen.draft.mode != .cardio {
              LoadInput(value: screen.draft.weight, unit: screen.draft.unit) { screen.stepLoad($0) }
            }
            note
          }
          .padding(.horizontal, HexSpacing.m)
          .padding(.vertical, HexSpacing.m)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
          // Só com -HexGymRoutineScroll inputs: a tela já rolada até as entradas, para o print em AX5.
          guard RoutinesLaunch.scroll == "inputs" else { return }
          try? await Task.sleep(for: .milliseconds(600))
          proxy.scrollTo(SlotEditorAnchor.inputs, anchor: .top)
        }
      }
      .navigationTitle("Edit exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .onDisappear { Task { await screen.flush() } }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xs) {
      Text(verbatim: screen.name)
        .hexFont(.headline)
        .foregroundStyle(Color.white)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if !screen.known {
        Text("This exercise isn't in the library on this device.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // Repetições ou tempo: em segmentos e, nos tamanhos de acessibilidade, num menu, que não corta o texto.
  @ViewBuilder private var mode: some View {
    let picker = Picker("Mode", selection: Binding(get: { screen.draft.mode }, set: { screen.setMode($0) })) {
      Text("Reps").tag(SlotMode.reps)
      Text("Time").tag(SlotMode.time)
    }
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: HexSpacing.xxs) {
        FieldLabel("Mode")
        picker.pickerStyle(.menu).labelsHidden()
      }
    } else {
      picker.pickerStyle(.segmented)
    }
  }

  private var sets: some View {
    CountStepper(title: "Sets", value: screen.setsText, spoken: screen.setsText,
                 onIncrement: { screen.stepSets(.up) }, onDecrement: { screen.stepSets(.down) })
  }

  private var seconds: some View {
    CountStepper(title: "Time", value: screen.secondsText, spoken: screen.secondsSpoken,
                 onIncrement: { screen.stepSeconds(.up) }, onDecrement: { screen.stepSeconds(.down) })
  }

  private var note: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xs) {
      FieldLabel("Note")
      // O exemplo fica num texto atrás do campo, e não no placeholder do sistema, que é de uma linha só e
      // corta nos tamanhos de acessibilidade. O VoiceOver lê o rótulo "Nota", sem o exemplo.
      ZStack(alignment: .topLeading) {
        Text("Grip, bench, setup")
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .opacity(noteText.isEmpty ? 1 : 0)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        TextField(text: $noteText, prompt: Text(verbatim: ""), axis: .vertical) { Text("Note") }
          .lineLimit(1...8)
          .focused($noteFocused)
          .accessibilityLabel(Text("Note"))
          .onChange(of: noteText) { _, typed in
            let shown = screen.typeNote(typed)
            if shown != typed { noteText = shown }
          }
      }
      .padding(HexSpacing.s)
      // Um toque em qualquer ponto da caixa abre o teclado, também no exemplo de duas linhas.
      .contentShape(Rectangle())
      .onTapGesture { noteFocused = true }
      .frame(minHeight: HexTarget.minimum)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous))
    }
  }
}

private enum SlotEditorAnchor {
  static let inputs = "inputs"
}

// O rótulo de um campo, no caption do HexDesign, como o das entradas do treino.
private struct FieldLabel: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .hexFont(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityHidden(true)
  }
}

// O Stepper da Apple com o rótulo e o valor: lado a lado e, nos tamanhos de acessibilidade, o valor
// embaixo do rótulo, para os dois caberem inteiros ao lado dos botões. O Stepper põe o rótulo nos dois
// botões dele, que o VoiceOver lê como "Tempo, 45 segundos, Aumentar": o valor vai falado, e não 0:45.
private struct CountStepper: View {
  let title: LocalizedStringKey
  let value: String
  let spoken: String
  let onIncrement: () -> Void
  let onDecrement: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Stepper {
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xxs))
        : AnyLayout(HStackLayout(spacing: HexSpacing.s))
      layout {
        Text(title)
          .font(.body)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
        if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        Text(verbatim: value)
          .hexFont(.unit)
          .foregroundStyle(Color.white)
          .monospacedDigit()
          .accessibilityLabel(Text(verbatim: spoken))
      }
      .frame(minHeight: HexTarget.minimum)
    } onIncrement: {
      onIncrement()
    } onDecrement: {
      onDecrement()
    }
  }
}
