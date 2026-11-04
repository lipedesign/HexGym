// O tema no Watch: o seletor próprio do Watch, com os quatro temas, que troca a galeria inteira na hora
// e grava o tema nos UserDefaults do App Group deste Watch (a chave hexgym.theme), e a chave da
// prévia de alto contraste, que fica só na memória. A ida do tema do iPhone para o Watch é da fase 4.
//
// Cada tema é uma linha da List, com uma amostra do destaque daquele tema, o nome em branco e a marca
// de escolhido em branco: sobre o cinza da linha, o texto e os símbolos não ficam na cor do tema.
import HexDesign
import SwiftUI

struct WatchThemeSection: View {
  @Environment(ThemeModel.self) private var model

  var body: some View {
    @Bindable var model = model
    Section {
      ForEach(HexTheme.allCases, id: \.self) { theme in
        WatchThemeRow(theme: theme, isSelected: model.theme == theme) { model.theme = theme }
      }
      Toggle(isOn: $model.contrastPreview) {
        Text("High contrast preview").foregroundStyle(Color.white)
      }
      WatchComponentRow {
        WatchNote("The theme stays on this watch, in the App Group, under hexgym.theme. It comes from the iPhone in phase 4.")
      }
    } header: {
      WatchSectionHeader("Theme")
    }
    .id(WatchGalleryAnchor.theme)
  }
}

// Uma linha do seletor: a amostra do destaque do tema, o nome e a marca de escolhido.
private struct WatchThemeRow: View {
  let theme: HexTheme
  let isSelected: Bool
  let select: () -> Void

  @Environment(\.locale) private var locale
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexContrastPreview) private var contrastPreview

  // O destaque daquele tema no Watch, no contraste do aparelho ou da prévia.
  private var swatch: Color {
    let increased = contrast == .increased || contrastPreview
    return Color(HexPalette.resolve(theme, scheme: .dark, contrast: increased ? .increased : .standard, surface: .watch).accent)
  }

  var body: some View {
    Button(action: select) {
      HStack(spacing: HexSpacing.xs) {
        Circle().fill(swatch).frame(width: 14, height: 14)
        Text(verbatim: theme.displayName(locale: locale))
          .foregroundStyle(Color.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "checkmark")
          .font(.body.weight(.semibold))
          .foregroundStyle(Color.white)
          .opacity(isSelected ? 1 : 0)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: theme.displayName(locale: locale)))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
