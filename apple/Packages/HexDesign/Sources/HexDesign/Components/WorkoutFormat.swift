// Os números do treino escritos e falados (seção 6 do design doc e o Foco da revisão, item 5): a
// carga aparece como foi registrada, com até duas casas, sem zero à direita e sem separar o milhar,
// no idioma do aparelho, e o VoiceOver diz a unidade. A carga nunca é arredondada para a grade: o
// passo é do motor, não daqui.

import Foundation

// A unidade da carga.
public enum WeightUnit: String, Sendable { case kg, lb }

// A escala do esforço: a percepção (RPE) ou as repetições que sobraram (RIR).
public enum EffortScale: String, Sendable { case rpe, rir }

// Para onde vai um toque de diminuir ou aumentar.
public enum StepDirection: Sendable { case down, up }

public enum WorkoutFormat {
  // A carga como foi registrada: 141,3; 141,25; 1000.
  public static func load(_ value: Double, locale: Locale = .current) -> String {
    value.formatted(number(locale))
  }

  // O esforço no mesmo formato, e vazio quando não foi registrado.
  public static func effort(_ value: Double?, locale: Locale = .current) -> String {
    value.map { load($0, locale: locale) } ?? ""
  }

  // A carga falada, com a unidade por extenso: "142,5 quilogramas", "1 kilogram". O CLDR do português
  // põe o 0 na forma one, e o formato da Apple diria "0 quilograma": o 0 em português vem da tabela
  // Workout, no plural, como a chave zero das repetições.
  public static func spokenLoad(_ value: Double, unit: WeightUnit, locale: Locale = .current) -> String {
    if value == 0, HexStrings.isPortuguese(locale) {
      return HexStrings.text("load.zero.\(unit.rawValue)", table: "Workout", locale: locale)
    }
    let measurement = Measurement(value: value, unit: unit == .kg ? UnitMass.kilograms : UnitMass.pounds)
    return measurement.formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: number(locale)).locale(locale))
  }

  // As repetições faladas, com o plural do .stringsdict: "1 repetição", "8 repetições".
  public static func spokenReps(_ count: Int, locale: Locale = .current) -> String {
    HexStrings.format("%lld reps", table: "Workout", locale: locale, count)
  }

  // O esforço falado: "RPE 8,5", "RIR 2", ou que ele não foi registrado.
  public static func spokenEffort(_ value: Double?, scale: EffortScale, locale: Locale = .current) -> String {
    guard let value else { return HexStrings.text("effort.empty", table: "Workout", locale: locale) }
    return "\(scale.symbol) \(load(value, locale: locale))"
  }

  // De 0 a 2 casas, sem separar o milhar, no idioma.
  private static func number(_ locale: Locale) -> FloatingPointFormatStyle<Double> {
    FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale)
  }
}

extension EffortScale {
  // A sigla que aparece e que o VoiceOver lê, a mesma nos dois idiomas.
  var symbol: String { rawValue.uppercased() }
}
