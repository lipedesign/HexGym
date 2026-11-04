// O tema: o seletor com os quatro temas, que troca a galeria inteira na hora e grava o tema nos
// UserDefaults do App Group (a chave hexgym.theme), e a chave da prévia de alto contraste, que fica só
// na memória.
//
// O seletor é uma lista de quatro linhas num cartão do sistema, cada uma com uma amostra do destaque
// daquele tema: os nomes ("Cobre Forjado", "Ciano Glacial") não cabem num seletor segmentado na largura
// do iPhone, e a lista cabe em qualquer tamanho de texto.
import HexDesign
import SwiftUI

struct ThemeSection: View {
  @Environment(ThemeModel.self) private var model

  var body: some View {
    @Bindable var model = model
    GallerySectionView("Theme", note: "The theme changes the whole gallery at once and stays on this device, in the App Group, under hexgym.theme.") {
      GalleryCard {
        VStack(spacing: 0) {
          ForEach(HexTheme.allCases, id: \.self) { theme in
            ThemeRow(theme: theme, isSelected: model.theme == theme) { model.theme = theme }
            if theme != HexTheme.allCases.last { Divider() }
          }
        }
      }
      Toggle("High contrast preview", isOn: $model.contrastPreview)
        .foregroundStyle(Color.white)
      GalleryNote("The preview swaps the colors the way Increase Contrast does, without changing the system setting.")
    }
  }
}

// Uma linha do seletor: a amostra do destaque do tema, o nome em branco e a marca de escolhido.
private struct ThemeRow: View {
  let theme: HexTheme
  let isSelected: Bool
  let select: () -> Void

  @Environment(\.locale) private var locale
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.hexContrastPreview) private var contrastPreview
  @Environment(\.hexPalette) private var palette

  // O destaque daquele tema no contraste do aparelho ou da prévia.
  private var swatch: Color {
    let increased = contrast == .increased || contrastPreview
    return Color(HexPalette.resolve(theme, scheme: .dark, contrast: increased ? .increased : .standard).accent)
  }

  var body: some View {
    Button(action: select) {
      HStack(spacing: HexSpacing.s) {
        Circle().fill(swatch).frame(width: 18, height: 18)
        Text(verbatim: theme.displayName(locale: locale))
          .foregroundStyle(Color.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "checkmark")
          .font(.body.weight(.semibold))
          .foregroundStyle(Color(palette.accent))
          .opacity(isSelected ? 1 : 0)
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: theme.displayName(locale: locale)))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
