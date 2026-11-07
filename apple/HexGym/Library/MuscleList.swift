// A lista dos músculos no cartão "Músculos" do detalhe (Task 10 do plano da fase 2), o espaço do corpo
// até a Task 14: "Principal" e "Também trabalha", cada um com as regiões dele, uma por linha. As linhas
// vêm prontas do ExerciseDetailModel, sem nenhuma lista vazia. Cada nome quebra a linha em qualquer
// tamanho de texto, sem teto de linhas: o mais longo, "Nuca (esplênios e levantador da escápula)",
// desce inteiro no AX5.
//
// A marca de cada linha antecipa a legenda do corpo da Task 14 (escolha 7): cheia na cor do tema no
// primário, e em 40% dela no secundário. Ela é decorativa: o VoiceOver lê o cartão inteiro com o texto
// pronto do modelo (o musclesSpoken), e a cor do tema não pinta texto (regra da #71).
import HexDesign
import SwiftUI

struct MuscleList: View {
  let sections: [MuscleSection]

  @Environment(\.hexPalette) private var palette

  var body: some View {
    VStack(alignment: .leading, spacing: HexSpacing.m) {
      ForEach(sections) { section in
        VStack(alignment: .leading, spacing: HexSpacing.xs) {
          Text(verbatim: section.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(section.names, id: \.self) { name in
            HStack(alignment: .firstTextBaseline, spacing: HexSpacing.xs) {
              Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(Color(palette.accent).opacity(section.kind == .primary ? 1 : 0.4))
              Text(verbatim: name)
                .font(.body)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
