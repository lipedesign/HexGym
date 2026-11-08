// Um cartão de exercício na tela do treino (Task 8 do plano da fase 3, escolha 4): o vidro do HexDesign,
// com o nome, o alvo ("3 × 8 · 60 kg") e as séries em linhas (SetRow). Sem imagem do exercício (seção 8.8:
// nenhuma mídia da Gym visual nesta fase). Um exercício que não existe neste aparelho aparece como
// "Exercício desconhecido", com o símbolo da dúvida, e as séries dele marcam como as outras (Foco da
// revisão 5).
//
// O superset tem a marca na lateral dos cartões, uma barra na cor do tema que liga os cartões do grupo,
// e "Superset A" em cima do primeiro, os dois sobre o fundo da tela, onde a cor do tema pode ficar (#71).
// O VoiceOver lê o nome do exercício como cabeçalho, com "Superset A, 1 de 2" e o alvo.
//
// No vidro, todo texto vai em branco (#71): o alvo também, no lugar do cinza secundário que o plano dizia,
// que mediu 3,1:1 sobre o vidro.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a barra do superset de 4 pt na margem, à
// esquerda dos cartões, como a do editor de rotina, e o "Superset A" no estilo de legenda, no destaque do
// tema.
import HexDesign
import SwiftUI

struct ExerciseCard: View {
  let card: WorkoutCard
  let select: (WorkoutRef) -> Void
  let mark: (WorkoutRow) -> Void

  @Environment(\.hexPalette) private var palette

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xs) {
      if let superset = card.superset, superset.first {
        Text(verbatim: superset.label)
          .hexFont(.caption)
          .foregroundStyle(Color(palette.accent))
          .accessibilityHidden(true)
      }
      HexGlassCard {
        VStack(alignment: .leading, spacing: HexSpacing.xs) {
          heading
          VStack(spacing: HexSpacing.xxs) {
            ForEach(card.rows) { row in
              SetRow(row: row, select: { select(row.ref) }, mark: { mark(row) })
                .id(row.ref)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .overlay(alignment: .leading) {
        if let superset = card.superset { SupersetBar(superset: superset) }
      }
    }
  }

  // O nome e o alvo, um cabeçalho só para o VoiceOver.
  private var heading: some View {
    VStack(alignment: .leading, spacing: HexSpacing.xxs) {
      HStack(alignment: .firstTextBaseline, spacing: HexSpacing.xs) {
        Text(verbatim: card.name)
          .hexFont(.headline)
          .foregroundStyle(Color.white)
          .modifier(WholeWords(card.name))
          .frame(maxWidth: .infinity, alignment: .leading)
        if !card.known {
          Image(systemName: "questionmark.circle")
            .font(.body)
            .foregroundStyle(Color.white)
        }
      }
      if let target = card.target {
        Text(verbatim: target)
          .font(.subheadline)
          .foregroundStyle(Color.white)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, HexSpacing.xs)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: card.name))
    .accessibilityValue(Text(verbatim: [card.superset?.spoken, card.target].compactMap { $0 }.joined(separator: ", ")))
    .accessibilityAddTraits(.isHeader)
  }
}

// A barra do superset, na margem à esquerda do cartão. Entre dois cartões do grupo, a barra do de baixo
// sobe até o de cima, e a linha fica contínua.
private struct SupersetBar: View {
  let superset: WorkoutSuperset

  @Environment(\.hexPalette) private var palette

  var body: some View {
    // Só as pontas do grupo são redondas: no meio, os pedaços de dois cartões se juntam sem marca.
    let top: CGFloat = superset.first ? 2 : 0, bottom: CGFloat = superset.last ? 2 : 0
    UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom,
                           topTrailingRadius: top)
      .fill(Color(palette.accent))
      .frame(width: 4)
      .padding(.top, superset.first ? HexSpacing.xs : -HexSpacing.s)
      .padding(.bottom, superset.last ? HexSpacing.xs : 0)
      .offset(x: -(HexSpacing.xs + 2))
      .accessibilityHidden(true)
  }
}
