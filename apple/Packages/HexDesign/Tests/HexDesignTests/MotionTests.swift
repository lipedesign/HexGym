// Os testes do movimento e dos hápticos do HexDesign (seção 6 do design doc e o Foco da revisão,
// item 4): com Reduzir Movimento nada muda de lugar nem de tamanho e o brilho para, os movimentos
// seguem a tabela, e o iPhone só usa hápticos que tocam nele.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexDesign --filter MotionTests

import SwiftUI
import Testing
@testable import HexDesign

@Test func reduceMotionNeverMoves() {                                     // Foco da revisão 4
  for m in HexMotion.allCases { #expect(!m.spec(reduceMotion: true).allowsMovement, "\(m)") }
}
@Test func theGlowStopsWithReduceMotion() {                               // Foco da revisão 4
  #expect(HexMotion.breathe.spec(reduceMotion: true).curve == nil); #expect(HexMotion.breathe.animation(reduceMotion: true) == nil)
  #expect(HexMotion.breathe.spec(reduceMotion: false).repeats)
}
@Test func motionsMatchTheTable() {
  #expect(HexMotion.tap.spec(reduceMotion: false).curve == .spring(duration: 0.25, bounce: 0))
  #expect(HexMotion.celebrate.spec(reduceMotion: false).curve == .spring(duration: 0.6, bounce: 0.35))
  #expect(HexMotion.celebrate.spec(reduceMotion: true).curve == .easeInOut(duration: 0.3))
  #expect(HexMotion.change.animation(reduceMotion: false) == .spring(duration: 0.35, bounce: 0.1))
}
@Test func hapticsMatchTheTable() {
  #expect(HexHaptic.allCases.map { $0.kind(on: .phone) } == [.selection, .selection, .success, .impact(weight: .heavy, intensity: 1), .warning, .error])
  #expect(HexHaptic.allCases.map { $0.kind(on: .watch) } == [.increase, .decrease, .success, .impact(weight: .heavy, intensity: 1), .start, .error])
  #expect(HexHaptic.allCases.map { $0.feedback(on: .watch) } == [.increase, .decrease, .success, .impact(weight: .heavy, intensity: 1), .start, .error])   // a tradução
}
