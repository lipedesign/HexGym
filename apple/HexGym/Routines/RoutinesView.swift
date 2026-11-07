// A aba Rotinas (Task 11 do plano da fase 2, issue #98): a lista das rotinas numa List da Apple, cada
// linha com o ícone, o nome, "6 exercícios" e os dias da semana em que ela está; "Nova rotina" na barra;
// o .onMove para reordenar (e o "Editar" da Apple, que mostra as alças); e o deslizar com "Duplicar" e
// "Apagar". Apagar mostra a faixa "Rotina apagada" com o "Desfazer" por 5 s, que aplica o restoreRoutine
// com o snapshot (Foco da revisão 4); com o VoiceOver ligado, a faixa fica 15 s, e o anúncio diz que ela
// apareceu. Sem rotinas, o estado vazio da Apple com "Nova rotina", até a tela vazia da Task 12.
//
// Um toque numa linha abre o editor (RoutineEditorView), na pilha da aba. As linhas vêm prontas do
// RoutineEditorModel, pelo RoutinesScreen: o body não calcula nada.
//
// A faixa segue o desenho da confirmação do detalhe do exercício (Task 10): o vidro numa cápsula no pé
// da tela, o anúncio do VoiceOver e, com Reduzir Movimento, só o esmaecido. O "Desfazer" é um botão de
// verdade dentro dela, com 44 pt, que o VoiceOver alcança.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema; a cor do tema só aparece no
// ícone da rotina, sobre o cartão do sistema.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o ícone na cor do tema; a contagem e os
// dias na segunda linha, com o ponto no meio; o "Duplicar" no índigo do sistema, como o favoritar da
// biblioteca; o "Editar" da Apple na barra, para quem não arrasta; e a faixa de 15 s com o VoiceOver.
import HexDesign
import HexEngine
import SwiftUI

// O caminho da pilha da aba Rotinas até o editor de uma rotina.
struct RoutineRoute: Hashable {
  let id: String
  // A rotina acabou de ser criada: o campo do nome abre vazio e com o foco.
  var isNew = false
}

struct RoutinesView: View {
  let screen: RoutinesScreen
  // A biblioteca da escolha de exercícios do editor, separada da aba Exercícios: a busca de uma não
  // aparece na outra.
  let library: LibraryModel
  @Binding var path: [RoutineRoute]

  @State private var ranLaunch = false
  // A faixa "Rotina apagada", enquanto aparece.
  @State private var banner: RoutineUndo?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

  var body: some View {
    List {
      ForEach(screen.rows) { row in
        NavigationLink(value: RoutineRoute(id: row.id)) {
          RoutineListRow(row: row)
        }
        .accessibilityLabel(Text(verbatim: row.spoken))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          Button(role: .destructive) { screen.delete(row.id) } label: {
            Label("Delete", systemImage: "trash")
          }
          Button { Task { await screen.duplicate(row.id) } } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
          }
          .tint(Color(.systemIndigo))
        }
      }
      .onMove { screen.move(from: $0, to: $1) }
    }
    .scrollContentBackground(.hidden)
    .overlay { overlay }
    .overlay(alignment: .bottom) { undoBanner }
    .navigationTitle("Routines")
    .toolbar { toolbar }
    .navigationDestination(for: RoutineRoute.self) { route in
      RoutineEditorView(screen: screen.editor(route.id, isNew: route.isNew), library: library)
    }
    .task { await appear() }
    .task(id: screen.undo?.id) { await showUndo() }
    .onChange(of: screen.documentRevision) { Task { await screen.load() } }
    .containerBackground(.clear, for: .navigation)
  }

  @ViewBuilder private var overlay: some View {
    switch screen.phase {
    case .loading:
      ProgressView()
    case .failed:
      ContentUnavailableView {
        Label("Couldn't open the routines.", systemImage: "exclamationmark.triangle")
      }
    case .ready:
      if screen.rows.isEmpty {
        ContentUnavailableView {
          Label("No routines yet", systemImage: "list.bullet.rectangle")
        } actions: {
          Button { Task { await create() } } label: {
            Text("New routine")
          }
          .buttonStyle(.hexPrimary)
        }
      }
    }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    if !screen.rows.isEmpty {
      ToolbarItem(placement: .topBarLeading) { EditButton() }
    }
    ToolbarItem(placement: .topBarTrailing) {
      Button { Task { await create() } } label: {
        Label("New routine", systemImage: "plus")
      }
    }
  }

  // A faixa "Rotina apagada", com o "Desfazer".
  @ViewBuilder private var undoBanner: some View {
    if let banner {
      HStack(spacing: HexSpacing.s) {
        Label {
          Text(verbatim: banner.message)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
          Image(systemName: "trash")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.white)
        Spacer(minLength: 0)
        Button { Task { await screen.performUndo() } } label: {
          Text("Undo")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, HexSpacing.s)
            .frame(minWidth: HexTarget.minimum, minHeight: HexTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .padding(.leading, HexSpacing.m)
      .padding(.trailing, HexSpacing.xs)
      .padding(.vertical, HexSpacing.xxs)
      .frame(minHeight: HexTarget.minimum)
      .glassEffect(.regular, in: Capsule())
      .padding(.horizontal, HexSpacing.m)
      .padding(.bottom, HexSpacing.m)
      .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
  }

  // "Nova rotina": a rotina nova e, por cima da lista, o editor dela, com o nome para escrever.
  private func create() async {
    guard let id = await screen.create() else { return }
    path.append(RoutineRoute(id: id, isNew: true))
  }

  // A faixa aparece com o desfazer novo, o VoiceOver anuncia, e ela some 5 s depois (15 s com o
  // VoiceOver). Um desfazer novo no meio cancela a espera do anterior; o "Desfazer" tira a faixa na hora.
  private func showUndo() async {
    guard let undo = screen.undo else {
      withAnimation(HexMotion.change.animation(reduceMotion: reduceMotion)) { banner = nil }
      return
    }
    withAnimation(HexMotion.enter.animation(reduceMotion: reduceMotion)) { banner = undo }
    AccessibilityNotification.Announcement(undo.message).post()
    do { try await Task.sleep(for: .seconds(voiceOver ? 15 : 5)) } catch { return }
    screen.dismissUndo(undo.id)
  }

  // A lista do motor e, na primeira vez, o que os argumentos de início pedem (RoutinesLaunch).
  private func appear() async {
    await screen.load()
    guard !ranLaunch else { return }
    ranLaunch = true
    if let target = RoutinesLaunch.routine, let row = RoutinesLaunch.resolve(target, in: screen.rows) {
      path = [RoutineRoute(id: row.id)]
    }
    switch RoutinesLaunch.script {
    case "delete":
      // A faixa do desfazer, para o print: a primeira rotina sai pelo mesmo caminho do deslizar.
      try? await Task.sleep(for: .seconds(1))
      if let first = screen.rows.first { screen.delete(first.id) }
    case "demo":
      // O vídeo: "Nova rotina" pelo mesmo caminho do botão; o resto, no editor (RoutineEditorView).
      try? await Task.sleep(for: .seconds(1.2))
      await create()
    default:
      break
    }
  }
}

// Uma linha da lista: o ícone na cor do tema, o nome e, embaixo, a contagem e os dias. O nome quebra a
// linha em qualquer tamanho de texto. Nos tamanhos de acessibilidade, o ícone fica em cima do texto,
// para o nome ter a largura inteira.
private struct RoutineListRow: View {
  let row: RoutineRow

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .title3) private var iconWidth: CGFloat = 32

  var body: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xs))
      : AnyLayout(HStackLayout(spacing: HexSpacing.s))
    layout {
      Image(systemName: row.symbol)
        .font(.title3)
        .foregroundStyle(Color(palette.accent))
        .frame(width: typeSize.isAccessibilitySize ? nil : iconWidth)
        .accessibilityHidden(true)
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
    }
    .frame(minHeight: HexTarget.minimum)
  }
}

// Os argumentos de início das rotinas, como os da biblioteca (LibraryLaunch), do domínio dos argumentos
// dos UserDefaults padrão, que não fica gravado, para os prints e o vídeo do PR saírem do simulador sem
// tocar na tela. Com -HexGymTab rotinas e -HexGymSkipOnboarding YES junto:
//   -HexGymRoutine 0                 abre o editor da rotina dessa posição na lista (0 é a primeira), ou
//                                    do id dado
//   -HexGymRoutineOpen slot:2        no editor, abre o SlotEditor do exercício dessa posição
//   -HexGymRoutineOpen pick          no editor, abre a escolha de exercícios, com a busca do
//                                    -HexGymLibraryQuery e os ids do -HexGymRoutinePick já marcados
//   -HexGymRoutinePick 0025,0043     os exercícios marcados na escolha, na ordem
//   -HexGymRoutineScroll bottom      o editor rolado até o fim, para os prints em AX5
//   -HexGymRoutineScroll inputs      o SlotEditor rolado até as entradas, para os prints em AX5
//   -HexGymRoutinesScript delete     apaga a primeira rotina ao abrir, para o print da faixa do desfazer
//                                    (grava no documento do simulador)
//   -HexGymRoutinesScript demo       o roteiro do vídeo: monta uma rotina do zero pelos caminhos dos
//                                    toques (nome, ícone, três exercícios, séries e carga)
enum RoutinesLaunch {
  private static var defaults: UserDefaults { .standard }

  static var routine: String? { value("HexGymRoutine") }
  static var script: String? { value("HexGymRoutinesScript") }
  static var open: String? { value("HexGymRoutineOpen") }
  static var scroll: String? { value("HexGymRoutineScroll") }

  static var picks: [String] {
    (value("HexGymRoutinePick") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  // O SlotEditor pedido: a posição do slot:N.
  static var slot: Int? {
    guard let open, open.hasPrefix("slot:") else { return nil }
    return Int(open.dropFirst(5))
  }

  // A rotina pedida: pelo id ou, sem achar, pela posição na lista.
  static func resolve(_ target: String, in rows: [RoutineRow]) -> RoutineRow? {
    rows.first { $0.id == target } ?? Int(target).flatMap { rows.indices.contains($0) ? rows[$0] : nil }
  }

  private static func value(_ key: String) -> String? {
    defaults.string(forKey: key).map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
  }
}
