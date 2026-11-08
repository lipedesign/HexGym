// O editor de uma rotina (Task 11 do plano da fase 2, issue #98), aberto de uma linha da aba Rotinas: o
// nome (um TextField da Apple, "Nome da rotina"), o ícone (um Menu da Apple com os 20 glyphs, nos quatro
// grupos do openGym) e a lista dos exercícios. Cada linha tem o nome e o setsReps (e a carga, quando há),
// abre o SlotEditor numa tela que sobe, muda de lugar pelo .onMove e, no deslizar, tem "Remover" e
// "Trocar exercício". Dois exercícios seguidos viram superset pelo menu da linha ("Juntar com o próximo"
// e "Separar"), com a marca do superset na lateral das linhas dele, e o VoiceOver diz com quem a linha
// está no superset. O "Adicionar exercícios" abre a biblioteca em modo de escolha (LibraryView, Task 9),
// e os escolhidos entram no fim, na ordem dos toques.
//
// Um exercício que não existe mais aparece como "Exercício desconhecido", com o símbolo da dúvida, e
// abre e troca como qualquer outro (Foco da revisão 1). Os textos vêm prontos do RoutineEditorModel: o
// body não calcula nada. O menu da linha também está nas ações do VoiceOver.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema; a cor do tema só aparece no
// ícone e na marca do superset, sobre o cartão do sistema, e no botão principal.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o título "Editar rotina" na barra (o nome
// inteiro fica no campo, que quebra a linha); o nome vai ao motor quando o campo perde o foco; a marca do
// superset é uma barra de 4 pt na cor do tema, sem a divisória entre as linhas dele; o "Trocar exercício"
// abre a mesma biblioteca, com uma escolha só e o botão "Trocar".
import HexDesign
import HexEngine
import SwiftUI

struct RoutineEditorView: View {
  @State private var screen: RoutineEditorScreen
  let library: LibraryModel

  // O exercício aberto no SlotEditor.
  @State private var slotEditor: SlotEditorScreen?
  // A escolha de exercícios aberta, e os escolhidos, na ordem dos toques.
  @State private var picking = false
  @State private var picked: [String] = []
  // O exercício que está sendo trocado, e o escolhido para o lugar dele.
  @State private var replacing: SlotRow?
  @State private var replacement: [String] = []
  @State private var ranLaunch = false
  @FocusState private var nameFocused: Bool
  @Environment(\.dynamicTypeSize) private var typeSize

  init(screen: @autoclosure @escaping () -> RoutineEditorScreen, library: LibraryModel) {
    _screen = State(wrappedValue: screen())
    self.library = library
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        if let content = screen.content {
          Section {
            TextField("Routine name", text: $screen.name, axis: .vertical)
              .focused($nameFocused)
              .accessibilityLabel(Text("Routine name"))
              .submitLabel(.done)
              .onSubmit { nameFocused = false }
              .frame(minHeight: HexTarget.minimum)
            glyphMenu(content)
          }
          Section {
            ForEach(content.slots) { row in
              slotRow(row)
            }
            .onMove { screen.move(from: $0, to: $1) }
          } header: {
            SettingsHeader("Exercises")
          }
          Section {
            // Nos tamanhos de acessibilidade, sem o símbolo, para "Adicionar" caber inteiro numa linha.
            Button { picking = true } label: {
              Label("Add exercises", systemImage: "plus")
                .labelStyle(AddLabelStyle(iconShown: !typeSize.isAccessibilitySize))
            }
            .buttonStyle(.hexPrimary)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .id(EditorAnchor.bottom)
          }
        }
      }
      .task { await appear(proxy) }
    }
    .scrollContentBackground(.hidden)
    .overlay { overlay }
    .navigationTitle("Edit routine")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !(screen.content?.slots.isEmpty ?? true) {
        ToolbarItem(placement: .topBarTrailing) { EditButton() }
      }
    }
    .sheet(item: $slotEditor) { SlotEditor(screen: $0) }
    .sheet(isPresented: $picking, onDismiss: { picked = [] }) { picker }
    .sheet(item: $replacing, onDismiss: { replacement = [] }) { replacePicker($0) }
    .onChange(of: nameFocused) { _, focused in
      screen.editingName = focused
      if !focused { Task { await screen.commitName() } }
    }
    .onChange(of: screen.documentRevision) { Task { await screen.load() } }
    .onDisappear { if nameFocused { Task { await screen.commitName() } } }
    .containerBackground(.clear, for: .navigation)
  }

  @ViewBuilder private var overlay: some View {
    switch screen.phase {
    case .loading:
      ProgressView()
    case .gone, .failed:
      ContentUnavailableView {
        Label("Couldn't open the routines.", systemImage: "exclamationmark.triangle")
      }
    case .ready:
      EmptyView()
    }
  }

  // O ícone: um Menu da Apple com os 20, nos grupos do openGym, e a marca no de agora.
  private func glyphMenu(_ content: RoutineEditorContent) -> some View {
    Menu {
      Picker(selection: Binding(get: { content.glyph }, set: { glyph in Task { await screen.setGlyph(glyph) } })) {
        ForEach(RoutineGlyph.groups) { group in
          Section(screen.text.groupTitles[group.title] ?? group.title) {
            ForEach(group.glyphs, id: \.self) { glyph in
              Label(screen.text.glyphName(glyph), systemImage: RoutineGlyph.symbol(for: glyph)).tag(glyph)
            }
          }
        }
      } label: {
        EmptyView()
      }
      .pickerStyle(.inline)
    } label: {
      GlyphMenuLabel(symbol: content.symbol, name: content.glyphName)
    }
    .accessibilityLabel(Text("Icon"))
    .accessibilityValue(Text(verbatim: content.glyphName))
  }

  private func slotRow(_ row: SlotRow) -> some View {
    Button { open(row.id) } label: {
      SlotListRow(row: row)
    }
    .accessibilityLabel(Text(verbatim: row.spoken))
    .listRowSeparator(row.superset == .first || row.superset == .middle ? .hidden : .automatic, edges: .bottom)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) { screen.remove(row.id) } label: {
        Label("Remove", systemImage: "minus.circle")
      }
      Button { replacing = row } label: {
        Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
      }
      .tint(Color(.systemIndigo))
    }
    .contextMenu {
      supersetButtons(row)
      Divider()
      Button { replacing = row } label: { Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath") }
      Button(role: .destructive) { screen.remove(row.id) } label: { Label("Remove", systemImage: "minus.circle") }
    }
    .accessibilityActions { supersetButtons(row) }
  }

  @ViewBuilder private func supersetButtons(_ row: SlotRow) -> some View {
    if row.canJoinNext {
      Button { screen.joinWithNext(row.id) } label: { Label("Join with next", systemImage: "link") }
    }
    if row.canSeparate {
      Button { screen.separate(row.id) } label: { Label("Separate", systemImage: "link.badge.plus") }
    }
  }

  // A escolha de exercícios: a biblioteca em modo de escolha, com "Cancelar" e "Adicionar (n)".
  private var picker: some View {
    NavigationStack {
      LibraryView(model: library, selection: $picked, onAdd: { ids in
        picking = false
        Task { await screen.add(ids) }
      })
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { picking = false }
        }
      }
    }
  }

  // A troca de um exercício: a mesma biblioteca, com uma escolha só e "Trocar".
  private func replacePicker(_ row: SlotRow) -> some View {
    NavigationStack {
      LibraryView(model: library, selection: $replacement, pickOne: true, onAdd: { ids in
        replacing = nil
        guard let id = ids.first else { return }
        screen.replace(row.id, with: id)
      })
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { replacing = nil }
        }
      }
    }
  }

  private func open(_ rowID: String) {
    Task {
      if nameFocused { nameFocused = false }
      slotEditor = await screen.slotEditor(rowID)
    }
  }

  // A rotina do motor e, na primeira vez, o foco no nome de uma rotina nova e o que os argumentos de
  // início pedem (RoutinesLaunch).
  private func appear(_ proxy: ScrollViewProxy) async {
    await screen.load()
    guard !ranLaunch else { return }
    ranLaunch = true
    if screen.name.isEmpty, RoutinesLaunch.script != "demo" { nameFocused = true }
    if RoutinesLaunch.scroll == "bottom" {
      try? await Task.sleep(for: .milliseconds(600))
      proxy.scrollTo(EditorAnchor.bottom, anchor: .bottom)
    }
    if let index = RoutinesLaunch.slot {
      slotEditor = await screen.slotEditor(at: index)
    } else if RoutinesLaunch.open == "pick" {
      // A busca do -HexGymLibraryQuery, a LibraryView da escolha aplica ao abrir, como na aba Exercícios.
      picked = RoutinesLaunch.picks
      picking = true
    }
    if RoutinesLaunch.script == "demo" { await demo() }
  }

  // O roteiro do vídeo do PR (-HexGymRoutinesScript demo), depois do "Nova rotina" da lista: o nome
  // escrito letra por letra no campo, o ícone trocado pelo mesmo caminho do menu, três exercícios
  // escolhidos na biblioteca pela busca e pelos toques, o "Adicionar (3)", e o primeiro aberto no
  // SlotEditor, com uma série a mais e a carga subindo.
  private func demo() async {
    func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
    await wait(0.4)
    nameFocused = true
    for letter in "Peito e tríceps" {
      screen.name.append(letter)
      await wait(0.05)
    }
    await wait(0.3)
    nameFocused = false
    await wait(0.4)
    await screen.setGlyph("arm")
    await wait(0.6)
    picking = true
    await wait(0.8)
    for (query, id) in [("supino", "0025"), ("tríceps", nil as String?), ("crucifixo", nil)] {
      var next = LibraryQuery()
      next.query = query
      library.update(query: next)
      await library.settled()
      await wait(0.45)
      guard let pick = id ?? library.results.first(where: { !picked.contains($0.id) })?.id else { continue }
      picked.append(pick)
      await wait(0.45)
    }
    await wait(0.3)
    let ids = picked
    picking = false
    await screen.add(ids)
    var reset = LibraryQuery()
    reset.query = ""
    library.update(query: reset)
    await wait(0.8)
    guard let editor = await screen.slotEditor(at: 0) else { return }
    slotEditor = editor
    await wait(0.8)
    editor.stepSets(.up)
    await wait(0.4)
    for _ in 0..<4 {
      editor.stepLoad(.up)
      await wait(0.3)
    }
    await wait(0.7)
    slotEditor = nil
  }
}

// O rótulo do "Adicionar exercícios": com o símbolo, ou só o texto.
private struct AddLabelStyle: LabelStyle {
  let iconShown: Bool

  func makeBody(configuration: Configuration) -> some View {
    if iconShown {
      Label(configuration)
    } else {
      configuration.title
    }
  }
}

private enum EditorAnchor {
  static let bottom = "bottom"
}

// O rótulo do menu do ícone: o símbolo na cor do tema, "Ícone" e o nome do de agora.
private struct GlyphMenuLabel: View {
  let symbol: String
  let name: String

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xxs))
      : AnyLayout(HStackLayout(spacing: HexSpacing.s))
    layout {
      HStack(spacing: HexSpacing.s) {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(Color(palette.accent))
        Text("Icon")
          .foregroundStyle(Color.white)
      }
      if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
      Text(verbatim: name)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, minHeight: HexTarget.minimum, alignment: .leading)
    .contentShape(Rectangle())
  }
}

// Uma linha de exercício: a marca do superset na lateral, o nome, que quebra a linha, e o setsReps
// embaixo. O desconhecido leva o símbolo da dúvida.
private struct SlotListRow: View {
  let row: SlotRow

  @Environment(\.hexPalette) private var palette

  var body: some View {
    HStack(spacing: HexSpacing.s) {
      if let mark = row.superset { SupersetMark(mark: mark) }
      VStack(alignment: .leading, spacing: HexSpacing.xxs) {
        Text(verbatim: row.name)
          .font(.body)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
        Text(verbatim: row.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if !row.known {
        Image(systemName: "questionmark.circle")
          .font(.body)
          .foregroundStyle(.secondary)
      }
    }
    .frame(minHeight: HexTarget.minimum)
    .contentShape(Rectangle())
  }
}

// A marca do superset: uma barra na cor do tema, que encosta na linha de baixo na primeira, nas duas
// pontas no meio e na de cima na última.
private struct SupersetMark: View {
  let mark: SlotRow.Mark

  @Environment(\.hexPalette) private var palette

  var body: some View {
    Capsule()
      .fill(Color(palette.accent))
      .frame(width: 4)
      .padding(.top, mark == .first ? HexSpacing.xs : -HexSpacing.m)
      .padding(.bottom, mark == .last ? HexSpacing.xs : -HexSpacing.m)
      .accessibilityHidden(true)
  }
}
