// Uma linha da biblioteca (Task 9 do plano da fase 2, escolha 6): sem miniatura, o nome em .body e,
// embaixo, o grupo principal e o equipamento em .secondary, com a estrela dos favoritos. Tudo o que a
// linha mostra e o rótulo do VoiceOver vêm prontos do modelo (LibraryRow): o body não calcula nada,
// para a lista dos 5.632 rolar sem perder quadro. O nome quebra linha em qualquer tamanho de texto,
// sem teto de linhas (Foco da revisão 5).
//
// Na lista comum, o texto é o link para o detalhe do exercício (Task 10), um elemento do VoiceOver com o
// rótulo do modelo, e a estrela é um botão à parte, com pelo menos 44 pt, que o VoiceOver, o Controle
// por Botão e o teclado acionam. O rótulo vai no próprio NavigationLink, sem um
// .accessibilityElement(children: .ignore) por fora, para o toque do VoiceOver abrir o detalhe. Nos tamanhos
// de acessibilidade (AX1 a AX5), a estrela desce para baixo do texto, e o nome fica com a largura
// inteira da linha (escolha recomendada, com a delegação do Lipe de 03/11/2026). No modo de
// escolha (o editor de rotina, Task 11), a linha inteira é o botão que marca e desmarca, e a estrela
// só mostra o favorito.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema; a cor do tema aparece só
// na estrela acesa e na marca de escolhido, sobre o cartão do sistema.
import HexDesign
import SwiftUI

struct ExerciseRow: View {
  let row: LibraryRow
  // nil na lista comum; no modo de escolha, se a linha está escolhida.
  let picked: Bool?
  let toggleFavourite: () -> Void
  let pick: () -> Void

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize

  // Lado a lado, ou a estrela embaixo do texto nos tamanhos de acessibilidade.
  private var browseLayout: AnyLayout {
    typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
      : AnyLayout(HStackLayout(spacing: HexSpacing.xs))
  }

  // Uma view só, de tipo fixo (o HStack), por fora do if: a List conta uma linha por exercício sem
  // montar o body de cada um dos 5.632. Com o if por fora, ela montava todos para contar (medido no
  // Instruments: uns 700 ms na thread principal ao encher a lista).
  var body: some View {
    HStack(spacing: 0) {
      if let picked {
        pickRow(picked)
      } else {
        browseRow
      }
    }
  }

  private func pickRow(_ picked: Bool) -> some View {
    Button(action: pick) {
      HStack(spacing: HexSpacing.s) {
        Image(systemName: picked ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(picked ? Color(palette.accent) : Color.secondary)
        texts
        if row.favourite { star }
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // O próprio Button é o elemento, com o rótulo por cima: o toque do VoiceOver, do Controle por
    // Botão e do teclado marca e desmarca (QA do PR #111).
    .accessibilityLabel(Text(verbatim: row.spoken))
    .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
  }

  private var browseRow: some View {
    browseLayout {
      NavigationLink(value: ExerciseRoute(id: row.id)) {
        texts
          .frame(minHeight: HexTarget.minimum)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(verbatim: row.spoken))
      Button(action: toggleFavourite) {
        star
          .frame(minWidth: HexTarget.minimum, minHeight: HexTarget.minimum)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("Favorite"))
      .accessibilityAddTraits(row.favourite ? [.isButton, .isSelected] : .isButton)
    }
    .frame(minHeight: HexTarget.minimum)
  }

  private var texts: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xxs) {
      Text(verbatim: row.name)
        .font(.body)
        .foregroundStyle(Color.white)
      if !row.detail.isEmpty {
        Text(verbatim: row.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var star: some View {
    Image(systemName: row.favourite ? "star.fill" : "star")
      .font(.body)
      .foregroundStyle(row.favourite ? Color(palette.accent) : Color.secondary)
  }
}
