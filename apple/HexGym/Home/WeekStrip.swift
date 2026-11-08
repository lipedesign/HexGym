// A semana do Início (Task 7 do plano da fase 3, escolha 2): sete segmentos inclinados, um por dia, na
// ordem do weekStart do perfil, com a letra do dia embaixo. O segmento fica cheio no destaque do tema no
// dia treinado, contornado no destaque no dia planejado e no cinza terciário nos outros; o hoje tem o
// segmento no destaque a 35% (a "série atual" dos segmentos do HexDesign) quando ainda não treinou, e a
// letra no destaque, em negrito. O segmento é o SlantedSegment do HexDesign, o mesmo dos segmentos das
// séries, e vira junto da direita para a esquerda.
//
// A semana fica sobre o fundo da tela, onde a cor do tema pode ficar (regra da #71). Para o VoiceOver, a
// linha é um elemento só, com a fala do HomeModel ("segunda, hoje, planejado; terça, descanso; ...",
// embaixo do título "Semana"), como a linha de segmentos das séries é uma só.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o contorno de 2 pt no dia planejado, o hoje
// marcado no segmento e na letra, e a altura fixa de 28 pt: com o Dynamic Type, só a letra cresce, e o
// segmento fica inclinado também em AX5, em vez de virar um traço alto e fino.
import HexDesign
import SwiftUI

struct WeekStrip: View {
  let days: [HomeDay]
  let spoken: String

  @Environment(\.hexPalette) private var palette
  private let height: CGFloat = 28

  var body: some View {
    HStack(alignment: .top, spacing: HexSpacing.xs) {
      ForEach(days) { day in
        VStack(spacing: HexSpacing.xs) {
          segment(day)
            .frame(height: height)
          Text(verbatim: day.letter)
            .font(.subheadline.weight(day.today ? .bold : .regular))
            .foregroundStyle(day.today ? AnyShapeStyle(Color(palette.accent)) : AnyShapeStyle(.secondary))
        }
        .frame(maxWidth: .infinity)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: spoken))
  }

  private func segment(_ day: HomeDay) -> some View {
    SlantedSegment()
      .fill(fill(day))
      .overlay {
        if day.planned, !day.trained {
          SlantedSegment()
            .stroke(Color(palette.accent), lineWidth: 2)
            .padding(1)
        }
      }
      .flipsForRightToLeftLayoutDirection(true)
  }

  private func fill(_ day: HomeDay) -> AnyShapeStyle {
    if day.trained { return AnyShapeStyle(Color(palette.accent)) }
    if day.today { return AnyShapeStyle(Color(palette.accent).opacity(0.35)) }
    return AnyShapeStyle(.tertiary)
  }
}
