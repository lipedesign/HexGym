// Uma série no cartão do exercício (Task 8 do plano da fase 3, escolha 4): o número (o aquecimento com a
// chama, como o openGym marca), a linha curta do motor ("60 kg × 8", ou o texto do openGym num drop set,
// num rest-pause, numa série com lados ou no cardio), o lado numa série com tempo por lado ("Esquerda") e
// a marca de feita. Tocar na linha faz dela a série
// do painel; a marca manda ao motor o contrário do que ela está. A série do painel fica destacada por um
// contorno na cor do tema, que não é texto, e por um fundo claro.
//
// Para o VoiceOver, a linha é um botão com a fala do modelo ("Série 2, 60 quilogramas, 8 repetições,
// feita"), com o traço de selecionado na série do painel, e a marca é um botão de alternância, "Série 2
// concluída", como o checkbox do openGym ('Set {0} done'). Os dois alvos têm pelo menos 44 pt.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a marca é o círculo do SF Symbols, cheio
// com o visto na série feita, em branco no vidro (#71).
import HexDesign
import SwiftUI

struct SetRow: View {
  let row: WorkoutRow
  let select: () -> Void
  let mark: () -> Void

  @Environment(\.hexPalette) private var palette
  // A coluna do número cresce com o texto, para "12" e a chama do aquecimento não encostarem na linha.
  @ScaledMetric(relativeTo: .subheadline) private var numberWidth: CGFloat = 28

  var body: some View {
    HStack(spacing: HexSpacing.xs) {
      Button(action: select) {
        HStack(alignment: .firstTextBaseline, spacing: HexSpacing.s) {
          number
          Text(verbatim: row.line)
            .font(.body.weight(row.current ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          if let side = row.side { SideTag(side: side) }
        }
        .padding(.vertical, HexSpacing.xxs)
        .frame(maxWidth: .infinity, minHeight: HexTarget.minimum, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(verbatim: row.spoken))
      .accessibilityAddTraits(row.current ? .isSelected : [])
      Toggle(isOn: Binding(get: { row.done }, set: { _ in mark() })) {
        Text(verbatim: row.markLabel)
      }
      .toggleStyle(SetMarkStyle())
    }
    .padding(.leading, HexSpacing.xs)
    .background { highlight }
  }

  // O número da série, com a chama no aquecimento.
  private var number: some View {
    HStack(spacing: 2) {
      if row.warmup {
        Image(systemName: "flame.fill")
          .font(.caption)
      }
      Text(verbatim: row.number)
    }
    .font(.subheadline.weight(.semibold))
    .monospacedDigit()
    .foregroundStyle(Color.white)
    .frame(minWidth: numberWidth, alignment: .leading)
    .accessibilityHidden(true)
  }

  @ViewBuilder private var highlight: some View {
    if row.current {
      let shape = RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous)
      shape
        .fill(Color.white.opacity(0.12))
        .overlay { shape.strokeBorder(Color(palette.accent), lineWidth: 2) }
    }
  }
}

// O lado de uma série com tempo por lado, "Esquerda" ou "Direita", numa pílula depois da linha, como a
// sidepill do openGym (views/Workout.jsx:650, issue #161). No vidro, em branco (#71), com o fundo claro
// da pílula. O VoiceOver já ouve o lado na fala da linha ("Série 1 (Esquerda)").
private struct SideTag: View {
  let side: String

  var body: some View {
    Text(verbatim: side)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.white)
      .padding(.horizontal, HexSpacing.xs)
      .padding(.vertical, 2)
      .background(Capsule().fill(Color.white.opacity(0.16)))
      .fixedSize()
      .accessibilityHidden(true)
  }
}

// A marca de feita: o círculo, cheio com o visto quando a série está feita, num alvo de 44 pt. Para o
// VoiceOver, é a alternância da Apple, com o rótulo e o estado.
private struct SetMarkStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button { configuration.isOn.toggle() } label: {
      Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
        .font(.title2)
        .foregroundStyle(Color.white)
        .frame(minWidth: HexTarget.minimum, minHeight: HexTarget.minimum)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
    }
  }
}
