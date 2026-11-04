// Os testes dos segmentos inclinados, do carimbo de recorde e do anel de descanso (seção 6 do design
// doc e o Foco da revisão, itens 1, 3 e 4): da direita para a esquerda, os segmentos acendem a partir
// da direita; o VoiceOver diz em que série você está; o carimbo cai de 1,4 vez o tamanho, ou só
// aparece com Reduzir Movimento; e o descanso não pula de tamanho quando passa de uma hora. Mais os
// plurais das séries: o inglês nas regras do inglês, mesmo num aparelho em outro idioma, e o 0 no
// plural em português.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter ProgressTests
//
// Os prints (segmentos.png, carimbo.png, anel.png e brilho.png) só rodam com HEXDESIGN_PRINTS na frente
// do comando e --filter printTheProgressPieces; o teste de print está em GlowTests.swift.

import Foundation
import SwiftUI
import Testing
@testable import HexDesign

@MainActor @Test func segmentsLightFromTheStartOfTheLine() {             // Foco da revisão 1
  let segments = SlantedSegments(total: 5, done: 1).frame(width: 200, height: 12)
  let ltr = brightness(segments), rtl = brightness(segments.environment(\.layoutDirection, .rightToLeft))
  #expect(ltr.left > ltr.right); #expect(rtl.right > rtl.left)
}
@Test func segmentsSayWhereYouAre() {
  #expect(SlantedSegments.spokenValue(total: 5, done: 3, locale: br) == "3 de 5 séries")
  #expect(SlantedSegments.spokenValue(total: 5, done: 3, locale: en) == "3 of 5 sets")
  #expect(SlantedSegments.spokenValue(total: 1, done: 1, locale: en) == "1 of 1 set")
}
@Test func theStampLandsOrFades() {                                       // Foco da revisão 4
  #expect(RecordStamp.startScale(reduceMotion: false) == 1.4); #expect(RecordStamp.startScale(reduceMotion: true) == 1)
}
@Test func restTimeNeverJumps() {                                         // Foco da revisão 3
  #expect([0, 5, 90, 3599, 3600, 3725, -3].map(RestRingModel.time) == ["0:00", "0:05", "1:30", "59:59", "1:00:00", "1:02:05", "0:00"])
}
@Test func restTimeIsSpoken() {
  #expect(RestRingModel.spokenTime(90, locale: br) == "1 minuto e 30 segundos")
  #expect(RestRingModel.spokenTime(90, locale: en) == "1 minute, 30 seconds")
  #expect(RestRingModel.spokenTime(3600, locale: br) == "1 hora")
}
@Test func theRingCountsDownInTicks() {
  #expect(RestRingModel.litTicks(total: 90, remaining: 90) == 60); #expect(RestRingModel.litTicks(total: 90, remaining: 45) == 30)
  #expect(RestRingModel.litTicks(total: 90, remaining: 0) == 0); #expect(RestRingModel.litTicks(total: 90, remaining: 200) == 60)
  #expect(RestRingModel.litTicks(total: 0, remaining: 0) == 0)
}
@MainActor @Test func theRingKeepsItsSizeWhenAnHourBegins() {             // Foco da revisão 3
  #expect(size(RestRing(total: 3600, remaining: 3599)) == size(RestRing(total: 3600, remaining: 3600)))
}

// Achado no QA da PR #76: num aparelho em japonês, a tabela é a do en.lproj, e o plural das séries
// segue as regras do inglês (o japonês só tem a forma other, e o 1 sairia "1 of 1 sets").
@Test func otherLanguagesCountSetsInEnglish() {
  let ja = Locale(identifier: "ja_JP")
  #expect(SlantedSegments.spokenValue(total: 1, done: 1, locale: ja) == "1 of 1 set")
  #expect(SlantedSegments.spokenValue(total: 5, done: 3, locale: ja) == "3 of 5 sets")
}
// Achado no QA da PR #76: o CLDR do português põe o 0 na forma one, e a chave zero do .stringsdict
// faz o 0 sair no plural.
@Test func zeroSetsArePluralInPortuguese() {
  #expect(SlantedSegments.spokenValue(total: 0, done: 0, locale: br) == "0 de 0 séries")
  #expect(SlantedSegments.spokenValue(total: 1, done: 0, locale: br) == "0 de 1 série")
  #expect(SlantedSegments.spokenValue(total: 0, done: 0, locale: en) == "0 of 0 sets")
}
// O anel cabe na largura que tem: numa tela estreita, ele fica do tamanho dela, e não maior.
@MainActor @Test func theRingNeverOutgrowsItsWidth() {
  #expect(size(RestRing(total: 90, remaining: 90)) == CGSize(width: 220, height: 220))
  #expect(size(RestRing(total: 90, remaining: 90).frame(width: 150)) == CGSize(width: 150, height: 150))
}
// Achado no QA da PR #78: o CLDR do português põe o 0 na forma one, e o VoiceOver dizia "Descanso, 0
// segundo" justo quando o descanso acaba. Um valor negativo também é o 0.
@Test func zeroRestIsPluralInPortuguese() {
  #expect(RestRingModel.spokenTime(0, locale: br) == "0 segundos")
  #expect(RestRingModel.spokenTime(-5, locale: br) == "0 segundos")
  #expect(RestRingModel.spokenTime(1, locale: br) == "1 segundo")
  #expect(RestRingModel.spokenTime(0, locale: en) == "0 seconds")
}
