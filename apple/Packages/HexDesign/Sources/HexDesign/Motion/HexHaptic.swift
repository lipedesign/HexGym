// Os hápticos do HexGym no iPhone e no Watch (seção 6 do design doc). A documentação da Apple diz que
// .increase e .decrease só tocam no watchOS e no visionOS, e .start só no watchOS: por isso o iPhone
// usa outros. No Mac, o SensoryFeedback não guarda o peso do impacto, então a tabela mora no
// HexFeedback, que guarda, e o feedback(on:) só traduz.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a tabela de hápticos.

import SwiftUI

public enum HexPlatform: Sendable {
  case phone, watch

  // .watch só no watchOS; no iPhone e no Mac dos testes, .phone.
  public static var current: HexPlatform {
    #if os(watchOS)
    .watch
    #else
    .phone
    #endif
  }
}

// A tabela num tipo nosso, que guarda o peso do impacto.
public enum HexFeedback: Equatable, Sendable {
  case selection, success, warning, error, increase, decrease, start
  case impact(weight: Weight, intensity: Double)

  public enum Weight: Equatable, Sendable { case light, medium, heavy }
}

public enum HexHaptic: CaseIterable, Sendable {
  case increase, decrease, setLogged, record, restDone, error

  // A tabela.
  public func kind(on platform: HexPlatform = .current) -> HexFeedback {
    switch (self, platform) {
    case (.increase, .phone): .selection
    case (.increase, .watch): .increase
    case (.decrease, .phone): .selection
    case (.decrease, .watch): .decrease
    case (.setLogged, _): .success
    case (.record, _): .impact(weight: .heavy, intensity: 1)
    case (.restDone, .phone): .warning
    case (.restDone, .watch): .start
    case (.error, _): .error
    }
  }

  // Só traduz o kind, para o .sensoryFeedback das views.
  public func feedback(on platform: HexPlatform = .current) -> SensoryFeedback {
    switch kind(on: platform) {
    case .selection: .selection
    case .success: .success
    case .warning: .warning
    case .error: .error
    case .increase: .increase
    case .decrease: .decrease
    case .start: .start
    case let .impact(weight, intensity): .impact(weight: weight.sensory, intensity: intensity)
    }
  }
}

extension HexFeedback.Weight {
  var sensory: SensoryFeedback.Weight {
    switch self {
    case .light: .light
    case .medium: .medium
    case .heavy: .heavy
    }
  }
}
