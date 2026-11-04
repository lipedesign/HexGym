// Os testes das entradas do treino e do número que rola (seção 6 do design doc e o Foco da revisão,
// itens 2 a 5): a carga como foi registrada, no idioma do aparelho; o que o VoiceOver fala, com a
// unidade; o esforço vazio; o empilhar nos tamanhos de acessibilidade; a largura que não pula com
// números grandes; e o número que só rola sem Reduzir Movimento. Mais os plurais: o inglês nas regras
// do inglês, mesmo num aparelho em outro idioma, e o 0 no plural em português.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter WorkoutInputTests

import Foundation
import SwiftUI
import Testing
@testable import HexDesign

@Test func loadsShowWhatWasLogged() {                                     // Foco da revisão 5
  #expect([141.3, 141.25, 142.5, 100, 1000, 2000, 141.333].map { WorkoutFormat.load($0, locale: br) }
          == ["141,3", "141,25", "142,5", "100", "1000", "2000", "141,33"])
  #expect(WorkoutFormat.load(142.5, locale: en) == "142.5")
}
@Test func voiceOverSaysTheUnit() {                                       // Foco da revisão 5
  #expect(WorkoutFormat.spokenLoad(142.5, unit: .kg, locale: br) == "142,5 quilogramas")
  #expect(WorkoutFormat.spokenLoad(317.5, unit: .lb, locale: br) == "317,5 libras")
  #expect(WorkoutFormat.spokenLoad(317.5, unit: .lb, locale: en) == "317.5 pounds")
  #expect(WorkoutFormat.spokenLoad(1, unit: .kg, locale: en) == "1 kilogram")
  #expect([1, 8].map { WorkoutFormat.spokenReps($0, locale: br) } == ["1 repetição", "8 repetições"])
  #expect([1, 8].map { WorkoutFormat.spokenReps($0, locale: en) } == ["1 repetition", "8 repetitions"])
  #expect(WorkoutFormat.spokenEffort(8.5, scale: .rpe, locale: br) == "RPE 8,5")
  #expect(WorkoutFormat.spokenEffort(2, scale: .rir, locale: en) == "RIR 2")
  #expect(WorkoutFormat.spokenEffort(nil, scale: .rpe, locale: br) == "Esforço não registrado")
}
@Test func anEmptyEffortShowsNothing() {
  #expect(WorkoutFormat.effort(nil, locale: br) == ""); #expect(WorkoutFormat.effort(8.5, locale: br) == "8,5")
  #expect(WorkoutFormat.effort(8, locale: br) == "8")
}
@Test func accessibilitySizesStack() {                                    // Foco da revisão 2
  #expect(WorkoutInputLayout.axis(for: .xxxLarge) == .horizontal)
  for size in [DynamicTypeSize.accessibility1, .accessibility5] { #expect(WorkoutInputLayout.axis(for: size) == .vertical) }
}
@MainActor @Test func bigLoadsKeepTheirWidth() {                          // Foco da revisão 3
  #expect(width(LoadInput(value: 1000, unit: .kg) { _ in }) == width(LoadInput(value: 1111, unit: .kg) { _ in }))
}
// O esforço vazio mostra só a unidade, mas tem a altura do esforço registrado: nada pula quando o
// primeiro valor chega.
@MainActor @Test func anEmptyEffortKeepsItsHeight() {
  #expect(size(EffortInput(value: nil, scale: .rpe) { _ in }).height == size(EffortInput(value: 8.5, scale: .rpe) { _ in }).height)
}
@Test func rollingNumbersRollUnlessReduceMotion() {                       // Foco da revisão 4
  #expect(RollingNumber.transition(for: 5, reduceMotion: false) == .numericText(value: 5))
  #expect(RollingNumber.transition(for: 5, reduceMotion: true) == .opacity)
}

// Achado no QA da PR #75: num aparelho em japonês, a tabela é a do en.lproj, e o plural precisa seguir
// as regras do inglês (o japonês só tem a forma other, e o 1 sairia "1 repetitions").
@Test func otherLanguagesUseTheEnglishPlural() {
  let ja = Locale(identifier: "ja_JP")
  #expect([1, 8].map { WorkoutFormat.spokenReps($0, locale: ja) } == ["1 repetition", "8 repetitions"])
}
// Achado no QA da PR #75: o CLDR do português põe o 0 na forma one, e a chave zero do .stringsdict
// faz o 0 sair no plural.
@Test func zeroRepsArePluralInPortuguese() {
  #expect(WorkoutFormat.spokenReps(0, locale: br) == "0 repetições")
  #expect(WorkoutFormat.spokenReps(0, locale: en) == "0 repetitions")
}
// Achado no QA da PR #76: o mesmo caso na carga. O VoiceOver dizia "0 quilograma" e "0 libra".
@Test func zeroLoadsArePluralInPortuguese() {
  #expect(WorkoutFormat.spokenLoad(0, unit: .kg, locale: br) == "0 quilogramas")
  #expect(WorkoutFormat.spokenLoad(0, unit: .lb, locale: br) == "0 libras")
  #expect(WorkoutFormat.spokenLoad(1, unit: .kg, locale: br) == "1 quilograma")
  #expect(WorkoutFormat.spokenLoad(0, unit: .kg, locale: en) == "0 kilograms")
}
