// Os movimentos do HexGym (seção 6 do design doc e o Foco da revisão, item 4). Cada um tem a versão
// de Reduzir Movimento: uma troca curta de opacidade, sem nada mudar de lugar nem de tamanho, e o
// brilho que respira para de vez.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a tabela de movimentos.

import SwiftUI

public struct MotionSpec: Equatable, Sendable {
  public enum Curve: Equatable, Sendable {
    case spring(duration: Double, bounce: Double), easeInOut(duration: Double)
  }

  // nil: sem animação.
  public let curve: Curve?
  // false: só opacidade, nada muda de lugar nem de tamanho.
  public let allowsMovement: Bool
  public let repeats: Bool
}

public enum HexMotion: CaseIterable, Sendable {
  case tap, change, enter, celebrate, breathe

  // A tabela. Com Reduzir Movimento, os quatro primeiros viram um easeInOut curto, só de opacidade, e
  // o breathe fica sem animação.
  public func spec(reduceMotion: Bool) -> MotionSpec {
    if reduceMotion {
      switch self {
      case .tap: MotionSpec(curve: .easeInOut(duration: 0.15), allowsMovement: false, repeats: false)
      case .change: MotionSpec(curve: .easeInOut(duration: 0.2), allowsMovement: false, repeats: false)
      case .enter: MotionSpec(curve: .easeInOut(duration: 0.25), allowsMovement: false, repeats: false)
      case .celebrate: MotionSpec(curve: .easeInOut(duration: 0.3), allowsMovement: false, repeats: false)
      case .breathe: MotionSpec(curve: nil, allowsMovement: false, repeats: false)
      }
    } else {
      switch self {
      case .tap: MotionSpec(curve: .spring(duration: 0.25, bounce: 0), allowsMovement: true, repeats: false)
      case .change: MotionSpec(curve: .spring(duration: 0.35, bounce: 0.1), allowsMovement: true, repeats: false)
      case .enter: MotionSpec(curve: .spring(duration: 0.5, bounce: 0.15), allowsMovement: true, repeats: false)
      case .celebrate: MotionSpec(curve: .spring(duration: 0.6, bounce: 0.35), allowsMovement: true, repeats: false)
      // Meio ciclo de HexBreathing.period: a ida em 2 s e a volta em 2 s.
      case .breathe: MotionSpec(curve: .easeInOut(duration: HexBreathing.period / 2), allowsMovement: true, repeats: true)
      }
    }
  }

  // A curva do spec como Animation do SwiftUI; o que repete vai e volta para sempre.
  public func animation(reduceMotion: Bool) -> Animation? {
    let spec = spec(reduceMotion: reduceMotion)
    guard let curve = spec.curve else { return nil }
    let animation: Animation = switch curve {
    case let .spring(duration, bounce): .spring(duration: duration, bounce: bounce)
    case let .easeInOut(duration): .easeInOut(duration: duration)
    }
    return spec.repeats ? animation.repeatForever(autoreverses: true) : animation
  }
}

// O brilho que respira: a escala entre 95% e 105%, num ciclo de 4 s.
public enum HexBreathing {
  public static let scale: ClosedRange<CGFloat> = 0.95...1.05
  public static let period: Double = 4
}
