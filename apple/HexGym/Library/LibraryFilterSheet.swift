// A tela dos filtros da biblioteca (Task 9 do plano da fase 2), a tela que sobe do botão da barra: "Só
// favoritos" e, em listas com marca, os grupos musculares, o equipamento e as categorias do openGym,
// com "Limpar" e "Pronto". Cada toque muda a LibraryQuery do modelo na hora, e a lista atrás busca de
// novo; o "Pronto" só fecha. As opções e os nomes vêm prontos do modelo (LibraryFilterOptions).
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema, e a cor do tema só aparece
// na marca de escolhido, sobre o cartão do sistema.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: "Só favoritos" primeiro, depois os
// grupos, o equipamento e as categorias, nesta ordem; "Limpar" à esquerda da barra, desligado quando
// nenhum filtro está ligado, e "Pronto" à direita.
import HexDesign
import HexEngine
import SwiftUI

struct LibraryFilterSheet: View {
  let model: LibraryModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Favorites only", isOn: favouritesOnly)
        }
        section("Muscle groups", model.options.muscles, \.muscles)
        section("Equipment", model.options.equipment, \.equipment)
        section("Category", model.options.categories, \.categories)
      }
      .navigationTitle("Filters")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Clear") { model.clearFilters() }
            .disabled(model.activeFilterCount == 0)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var favouritesOnly: Binding<Bool> {
    Binding(get: { model.query.favouritesOnly }, set: { on in
      var next = model.query
      next.favouritesOnly = on
      model.update(query: next)
    })
  }

  private func section(_ title: LocalizedStringKey, _ options: [LibraryFilterOption],
                       _ key: WritableKeyPath<LibraryQuery, [String]>) -> some View {
    Section {
      ForEach(options) { option in
        FilterOptionRow(name: option.name, isOn: model.query[keyPath: key].contains(option.id)) {
          var next = model.query
          if let index = next[keyPath: key].firstIndex(of: option.id) {
            next[keyPath: key].remove(at: index)
          } else {
            next[keyPath: key].append(option.id)
          }
          model.update(query: next)
        }
      }
    } header: {
      SettingsHeader(title)
    }
  }
}

// Uma opção com a marca de escolhida, com pelo menos 44 pt de altura. O próprio Button é o elemento do
// VoiceOver, com o nome e o traço de escolhido: o toque do VoiceOver, do Controle por Botão e do
// teclado marca e desmarca (QA do PR #111).
private struct FilterOptionRow: View {
  let name: String
  let isOn: Bool
  let toggle: () -> Void

  @Environment(\.hexPalette) private var palette

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: HexSpacing.s) {
        Text(verbatim: name)
          .foregroundStyle(Color.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        if isOn {
          Image(systemName: "checkmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(palette.accent))
        }
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: name))
    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
  }
}
