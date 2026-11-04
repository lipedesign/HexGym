// O carimbo de recorde (seção 6 do design doc, componentes nossos): "Recorde" no title, em caixa alta,
// no ouro do recorde, com contorno, girado para subir à direita como os segmentos. Quando o recorde
// chega, ele cai de 1,4 vez o tamanho com o movimento celebrate, ou só aparece com Reduzir Movimento
// (Foco da revisão, item 4); toca o háptico record; e o VoiceOver anuncia "Novo recorde".
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o carimbo dourado em contorno, girado
// -8° no rotationEffect (sobe para a direita) e caindo de 1,4 vez o tamanho.

import SwiftUI

public struct RecordStamp: View {
  private let isShown: Bool

  @Environment(\.hexPalette) private var palette
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // Se o carimbo já pousou. Começa como isShown: um carimbo que já abre mostrado aparece parado, e só
  // a passagem para mostrado anima. O State vai escrito sem o @: neste SDK o @State é um macro, e as
  // Command Line Tools não têm o plugin SwiftUIMacros.
  private let landed: State<Bool>

  public init(isShown: Bool) {
    self.isShown = isShown
    landed = State(initialValue: isShown)
  }

  // De onde o carimbo cai: 1,4 vez o tamanho, ou o próprio tamanho quando o celebrate não pode mover
  // nada (Reduzir Movimento). A regra do Reduzir Movimento fica no HexMotion.
  nonisolated public static func startScale(reduceMotion: Bool) -> CGFloat {
    HexMotion.celebrate.spec(reduceMotion: reduceMotion).allowsMovement ? 1.4 : 1
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: HexRadius.chip, style: .continuous)
    let record = Color(palette.record)
    Text(verbatim: HexStrings.text("record", table: "Progress", locale: locale))
      .hexFont(.title)
      .lineLimit(1)
      .foregroundStyle(record)
      .padding(.horizontal, HexSpacing.s)
      .padding(.vertical, HexSpacing.xxs)
      .overlay(shape.strokeBorder(record, lineWidth: 3))
      .rotationEffect(.degrees(-8))
      .scaleEffect(landed.wrappedValue ? 1 : Self.startScale(reduceMotion: reduceMotion))
      .opacity(landed.wrappedValue ? 1 : 0)
      .sensoryFeedback(HexHaptic.record.feedback(), trigger: isShown) { old, new in !old && new }
      .onChange(of: isShown) { _, shown in shown ? land() : lift() }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(verbatim: HexStrings.text("record", table: "Progress", locale: locale)))
      .accessibilityHidden(!isShown)
  }

  // O recorde chegou: o carimbo pousa com o celebrate e o VoiceOver anuncia.
  private func land() {
    withAnimation(HexMotion.celebrate.animation(reduceMotion: reduceMotion)) { landed.wrappedValue = true }
    AccessibilityNotification.Announcement(HexStrings.text("record.new", table: "Progress", locale: locale)).post()
  }

  // O carimbo sai sem animação, pronto para o próximo recorde.
  private func lift() {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { landed.wrappedValue = false }
  }
}
