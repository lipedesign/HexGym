// Os testes do botão principal (seção 6 do design doc e o Foco da revisão, item 4): com Reduzir
// Movimento ele só esmaece ao ser apertado, e as duas alturas têm lugar para o polegar. E o print do
// botão e das entradas do treino.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter PrimaryButtonTests
//
// Os prints (botao-principal.png e entradas.png) só rodam com HEXDESIGN_PRINTS na frente do comando e
// --filter printTheButtonAndTheInputs.

import SwiftUI
import Testing
@testable import HexDesign

@Test func thePrimaryButtonOnlyFadesWithReduceMotion() {                  // Foco da revisão 4
  #expect(HexPrimaryButtonStyle.pressedEffect(reduceMotion: false) == PressedEffect(scale: 0.97, opacity: 1))
  #expect(HexPrimaryButtonStyle.pressedEffect(reduceMotion: true) == PressedEffect(scale: 1, opacity: 0.8))
}
@Test func thePrimaryButtonHasRoomForAThumb() {
  #expect(HexPrimaryButtonStyle.Size.regular.minHeight == 56); #expect(HexPrimaryButtonStyle.Size.large.minHeight == 72)
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheButtonAndTheInputs() throws { // botao-principal.png e entradas.png
  var buttons: [ButtonCell: Image] = [:]
  for cell in ButtonCell.all { buttons[cell] = try still(cell.view) }
  try writePrint(ButtonSheet(stills: buttons), named: "botao-principal")
  try writePrint(InputSheet(stills: try InputCell.all.map { try still($0.view) }), named: "entradas")
}

// Cada estado desenhado num ImageRenderer só dele, no palco, em escala 2 (a do writePrint), e
// devolvido como imagem para a folha do print.
@MainActor private func still(_ view: some View) throws -> Image {
  let renderer = ImageRenderer(content: staged(view.environment(\.locale, br)))
  renderer.scale = 2
  return Image(decorative: try #require(renderer.cgImage, "o ImageRenderer não desenhou um estado"), scale: 2)
}

// O print do botão: uma coluna por tema e uma linha por estado (normal, com alto contraste e
// desligado), em .regular e em .large.
private enum ButtonState: CaseIterable {
  case normal, contrast, disabled

  var title: String {
    switch self {
    case .normal: "Normal"
    case .contrast: "Com alto contraste"
    case .disabled: "Desligado"
    }
  }
}

private struct ButtonCell: Hashable {
  let theme: HexTheme, state: ButtonState, size: HexPrimaryButtonStyle.Size

  static let sizes: [HexPrimaryButtonStyle.Size] = [.regular, .large]
  static let all = ButtonState.allCases.flatMap { state in
    sizes.flatMap { size in HexTheme.allCases.map { ButtonCell(theme: $0, state: state, size: size) } }
  }

  @MainActor var view: some View {
    Button {} label: { Text(verbatim: "Começar treino") }
      .buttonStyle(.hexPrimary(size: size))
      .disabled(state == .disabled)
      .environment(\.hexTheme, theme)
      .environment(\.hexContrastPreview, state == .contrast)
      .frame(width: 300)
  }
}

private struct ButtonSheet: View {
  let stills: [ButtonCell: Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text("O botão principal").font(.system(size: 26, weight: .bold))
        Text("Largura toda, 56 pt no .regular e 72 pt no .large, raio de 18 pt, no fill do tema com o rótulo no onFill. Com alto contraste, as cores do alto contraste; desligado, opacidade de 0,4.")
          .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: 1200, alignment: .leading)
      HStack(spacing: 16) {
        Color.clear.frame(width: 150, height: 1)
        ForEach(HexTheme.allCases, id: \.self) { theme in
          Text(verbatim: theme.displayName(locale: br)).font(.system(size: 17, weight: .semibold)).frame(width: 300, alignment: .leading)
        }
      }
      ForEach(ButtonState.allCases, id: \.self) { state in
        ForEach(ButtonCell.sizes, id: \.self) { size in
          HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
              Text(verbatim: state.title).font(.system(size: 15, weight: .semibold))
              Text(verbatim: size == .regular ? ".regular, 56 pt" : ".large, 72 pt").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .leading)
            ForEach(HexTheme.allCases, id: \.self) { theme in
              stills[ButtonCell(theme: theme, state: state, size: size)]
            }
          }
        }
      }
    }
    .padding(28)
  }
}

// O print das entradas do treino, no Ultravioleta e em português, com a última empilhada como nos
// tamanhos de acessibilidade.
@MainActor private struct InputCell {
  let title: String
  let input: AnyView
  var stacked = false

  static let all = [
    InputCell(title: "Carga fora da grade: 141,3 kg", input: AnyView(LoadInput(value: 141.3, unit: .kg) { _ in })),
    InputCell(title: "Carga grande: 1000 kg", input: AnyView(LoadInput(value: 1000, unit: .kg) { _ in })),
    InputCell(title: "Em libras: 317,5 lb", input: AnyView(LoadInput(value: 317.5, unit: .lb) { _ in })),
    InputCell(title: "8 repetições", input: AnyView(RepsInput(value: 8) { _ in })),
    InputCell(title: "Esforço vazio: só a unidade", input: AnyView(EffortInput(value: nil, scale: .rpe) { _ in })),
    InputCell(title: "Esforço 8,5", input: AnyView(EffortInput(value: 8.5, scale: .rpe) { _ in })),
    InputCell(title: "Nos tamanhos de acessibilidade, os botões descem", input: AnyView(LoadInput(value: 141.3, unit: .kg) { _ in }), stacked: true),
  ]

  @MainActor var view: some View {
    input
      .environment(\.dynamicTypeSize, stacked ? .accessibility3 : .large)
      .frame(width: 360)
  }
}

private struct InputSheet: View {
  let stills: [Image]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text("As entradas do treino").font(.system(size: 26, weight: .bold))
        Text("O rótulo no caption, o valor no number, com dígitos tabulares, e a unidade no unit. Os botões têm 56 pt. A carga aparece como foi registrada, com até duas casas.")
          .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: 760, alignment: .leading)
      // Duas colunas: cada linha leva dois estados.
      Grid(alignment: .topLeading, horizontalSpacing: 40, verticalSpacing: 24) {
        ForEach(Array(stride(from: 0, to: stills.count, by: 2)), id: \.self) { first in
          GridRow {
            ForEach(first..<min(first + 2, stills.count), id: \.self) { index in
              VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: InputCell.all[index].title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                stills[index]
              }
              .frame(width: 360, alignment: .topLeading)
            }
          }
        }
      }
    }
    .padding(28)
  }
}
