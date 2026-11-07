// A aba Exercícios (Task 9 do plano da fase 2): os 5.632 exercícios numa List da Apple, com a busca da
// Apple (.searchable, "Buscar exercícios"), os favoritos primeiro, a estrela e o deslizar para
// favoritar, os filtros num botão da barra que abre uma tela que sobe (com a contagem no botão quando
// há filtro) e o estado vazio da Apple (ContentUnavailableView.search) quando a busca não acha nada.
// A busca, os filtros e a ordem são do motor, pelo LibraryModel; as linhas vêm prontas dele.
//
// Um toque no nome abre o detalhe do exercício (ExerciseDetailView, Task 10), na pilha da aba.
//
// Com selection (o editor de rotina, Task 11), a lista vira múltipla escolha: cada toque marca ou
// desmarca, na ordem dos toques, que vira a ordem dos slots, e o botão "Adicionar (n)" da barra chama o
// onAdd com os ids nessa ordem.
//
// Para a rolagem dos 5.632 (seção 8.13): a List é preguiçosa, as linhas não têm imagem nem conta no
// body, e cada linha é uma view só, de tipo fixo (ExerciseRow), para a List não montar todas para
// contar. Mostrar em lotes (como o shown da Library.jsx do openGym) foi medido no QA do PR #112 e não
// entrou: o primeiro toque na aba custou o mesmo (uns 200 ms no simulador, de montar a tela, e não as
// linhas), e a rolagem contínua piorou muito a cada lote que entrava. O fundo da pilha fica
// transparente, para o brilho da raiz aparecer atrás, como nos Ajustes.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a escolha 6 do plano (sem miniatura, o
// nome, o grupo principal e o equipamento, os favoritos primeiro), a contagem dos filtros no selo do
// botão, e o deslizar para favoritar no índigo do sistema, onde o texto branco do botão é legível em
// todos os temas. O selo é desenhado aqui, e não o .badge da Apple: o .badge vira o valor do botão
// para o VoiceOver ("Filtros, 2 itens") por cima do nosso ("2 filtros ligados") (QA do PR #112).
import HexDesign
import HexEngine
import SwiftUI

struct LibraryView: View {
  let model: LibraryModel
  // nil na lista comum; no modo de escolha, os ids escolhidos, na ordem dos toques.
  var selection: Binding<[String]>? = nil
  var onAdd: (([String]) -> Void)? = nil

  @State private var showsFilters = false
  // O que os argumentos de início pedem roda uma vez só, mesmo que a aba volte.
  @State private var ranLaunch = false

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(model.results) { row in
          ExerciseRow(row: row, picked: selection.map { $0.wrappedValue.contains(row.id) },
                      toggleFavourite: { favourite(row.id) }, pick: { pick(row.id) })
            .swipeActions(edge: .trailing) {
              Button { favourite(row.id) } label: {
                Label(row.favourite ? "Remove from favorites" : "Favorite", systemImage: row.favourite ? "star.slash" : "star")
              }
              .tint(Color(.systemIndigo))
            }
        }
      }
      .task { await appear(proxy) }
    }
    .scrollContentBackground(.hidden)
    .overlay { overlay }
    .navigationTitle("Exercises")
    .searchable(text: searchText, prompt: Text("Search exercises"))
    .toolbar { toolbar }
    .sheet(isPresented: $showsFilters) { LibraryFilterSheet(model: model) }
    .navigationDestination(for: ExerciseRoute.self) { route in
      ExerciseDetailView(screen: model.detail(route.id))
    }
    .onChange(of: model.documentRevision) { Task { await model.refresh() } }
    .containerBackground(.clear, for: .navigation)
  }

  // Abrindo, sem resultado ou sem o catálogo.
  @ViewBuilder private var overlay: some View {
    switch model.phase {
    case .loading:
      ProgressView()
    case .failed:
      ContentUnavailableView {
        Label("Couldn't open the exercises.", systemImage: "exclamationmark.triangle")
      }
    case .ready:
      if model.isEmpty { ContentUnavailableView.search(text: model.query.query) }
    }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button { showsFilters = true } label: {
        // Um ZStack, e não um Label: com Label ou Image, a barra desenha só o símbolo e perde o selo.
        ZStack {
          Image(systemName: "line.3.horizontal.decrease")
            .overlay(alignment: .topTrailing) {
              if model.activeFilterCount > 0 { FilterBadge(count: model.activeFilterCount) }
            }
        }
      }
      .accessibilityLabel(Text("Filters"))
      .accessibilityValue(Text(verbatim: model.filtersValue))
    }
    if let selection {
      ToolbarItem(placement: .confirmationAction) {
        Button { onAdd?(selection.wrappedValue) } label: {
          Text("Add (\(selection.wrappedValue.count))")
        }
        .disabled(selection.wrappedValue.isEmpty)
      }
    }
  }

  // O campo mostra o texto na hora; a busca sai 150 ms depois da última letra.
  private var searchText: Binding<String> {
    Binding(get: { model.query.query }, set: { text in
      var next = model.query
      next.query = text
      model.update(query: next)
    })
  }

  private func favourite(_ id: String) {
    Task { await model.toggleFavourite(id) }
  }

  // Marca ou desmarca, guardando a ordem dos toques.
  private func pick(_ id: String) {
    guard let selection else { return }
    if let index = selection.wrappedValue.firstIndex(of: id) {
      selection.wrappedValue.remove(at: index)
    } else {
      selection.wrappedValue.append(id)
    }
  }

  // Cada vez que a lista aparece, o catálogo e a busca de agora (LibraryModel.load). Na primeira, antes,
  // a busca e os filtros dos argumentos de início e, depois, os favoritos e o roteiro deles.
  private func appear(_ proxy: ScrollViewProxy) async {
    guard !ranLaunch else {
      await model.load()
      return
    }
    ranLaunch = true
    if let query = LibraryLaunch.query { model.update(query: query) }
    await model.load()
    let favourites = LibraryLaunch.favourites.filter { model.summary($0)?.favourite == false }
    if !favourites.isEmpty {
      for id in favourites { await model.toggleFavourite(id) }
      await model.load()
    }
    if LibraryLaunch.opensFilters { showsFilters = true }
    if LibraryLaunch.script == "demo" { await demo(proxy) }
  }

  // O roteiro do vídeo do PR (-HexGymLibraryScript demo): com a lista no topo, onde o campo da busca
  // aparece, "supino" digitado letra por letra, pelo mesmo update(query:) do campo; depois, o campo
  // limpo e a lista inteira, do primeiro ao último, em dez saltos animados. A busca vem antes porque a
  // List não volta ao topo de verdade (com o campo à vista) por código.
  private func demo(_ proxy: ScrollViewProxy) async {
    try? await Task.sleep(for: .seconds(1.0))
    var typed = ""
    for letter in "supino" {
      typed.append(letter)
      type(typed)
      try? await Task.sleep(for: .seconds(0.25))
    }
    try? await Task.sleep(for: .seconds(1.6))
    type("")
    await model.settled()
    let ids = model.results.map(\.id)
    guard !ids.isEmpty else { return }
    try? await Task.sleep(for: .seconds(0.6))
    for step in 1...10 {
      let id = ids[min(ids.count - 1, step * ids.count / 10)]
      withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(id, anchor: .top) }
      try? await Task.sleep(for: .seconds(0.6))
    }
  }

  private func type(_ text: String) {
    var next = model.query
    next.query = text
    model.update(query: next)
  }
}

// O selo da contagem no botão dos filtros, no desenho do .badge da Apple: o número em branco no
// vermelho do sistema, crescendo com o tamanho do texto. Fica fora da acessibilidade: o botão diz a
// contagem no valor dele.
private struct FilterBadge: View {
  let count: Int
  @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 18

  var body: some View {
    Text(count, format: .number)
      .font(.footnote.weight(.medium))
      .monospacedDigit()
      .foregroundStyle(.white)
      .padding(.horizontal, size / 4)
      .frame(minWidth: size, minHeight: size)
      .background(Capsule().fill(Color(.systemRed)))
      .fixedSize()
      // O centro do selo na borda do botão de vidro, em cima à direita, onde o .badge da Apple ficava.
      .offset(x: size * 0.75, y: -size)
      .accessibilityHidden(true)
  }
}

// Os argumentos de início da biblioteca, como os dos Ajustes (SettingsLaunch), do domínio dos
// argumentos dos UserDefaults padrão, que não fica gravado, para os prints e o vídeo do PR saírem do
// simulador sem tocar na tela. Com -HexGymTab exercicios e -HexGymSkipOnboarding YES junto:
//   -HexGymLibraryQuery supino                            a busca já digitada
//   -HexGymLibraryFilters muscle:chest,equipment:barbell  filtros ligados (muscle:, equipment:,
//                                                         category: e favourites)
//   -HexGymLibraryOpen filters                            abre a tela dos filtros
//   -HexGymLibraryFavourites 0025,0047                    marca esses como favoritos, pela ação do
//                                                         motor (grava no documento do simulador)
//   -HexGymLibraryScript demo                             o roteiro do vídeo: rola tudo e busca
//   -HexGymLibraryPick YES                                a lista no modo de escolha da Task 11
enum LibraryLaunch {
  private static var defaults: UserDefaults { .standard }

  static var opensFilters: Bool { defaults.string(forKey: "HexGymLibraryOpen") == "filters" }
  static var script: String? { defaults.string(forKey: "HexGymLibraryScript") }
  static var picks: Bool { defaults.bool(forKey: "HexGymLibraryPick") }

  static var favourites: [String] {
    (defaults.string(forKey: "HexGymLibraryFavourites") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  // A busca e os filtros pedidos, ou nil sem nenhum dos dois.
  static var query: LibraryQuery? {
    let text = defaults.string(forKey: "HexGymLibraryQuery")
    let filters = defaults.string(forKey: "HexGymLibraryFilters")
    guard text != nil || filters != nil else { return nil }
    var query = LibraryQuery()
    query.query = text ?? ""
    for item in (filters ?? "").split(separator: ",") {
      let parts = item.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
      switch (parts.first, parts.count == 2 ? parts[1] : nil) {
      case ("muscle", let id?): query.muscles.append(id)
      case ("equipment", let id?): query.equipment.append(id)
      case ("category", let id?): query.categories.append(id)
      case ("favourites", nil): query.favouritesOnly = true
      default: break
      }
    }
    return query
  }
}
