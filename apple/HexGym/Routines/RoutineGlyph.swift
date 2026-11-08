// O ícone da rotina (Task 11 do plano da fase 2, escolha 9): os 20 glyphs que o seletor do openGym
// oferece (o GLYPHS do lib/glyphs.js, nos quatro grupos do GLYPH_GROUPS), cada um com um SF Symbol, e os
// sete antigos, que uma rotina ainda pode ter (o primeiro seletor do openGym e os que um emoji antigo
// vira). O motor manda o glyph pelo glyphStr do api/coach/core/glyphs.js: uma chave conhecida, um emoji
// antigo como está ou o padrão. O emoji antigo é traduzido aqui pelo mapa LEGACY do glyphOf do openGym,
// copiado do lib/glyphs.js com o mesmo corte (o seletor de variação e o ZWJ saem, e vale o primeiro
// caractere), e só um desconhecido cai no DEFAULT_GLYPH.
//
// Os nomes de cada ícone (o openGym só tem a chave no aria-label) são do catálogo do app, para o menu e
// o VoiceOver.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: a tabela dos SF Symbols da Task 11 do
// plano, os nomes dos ícones e o menu nos quatro grupos do openGym.
import Foundation

nonisolated enum RoutineGlyph {
  // Um grupo do seletor: o título do catálogo e os glyphs, na ordem do openGym.
  struct Group: Identifiable, Sendable {
    let title: String
    let glyphs: [String]
    var id: String { title }
  }

  // O DEFAULT_GLYPH do openGym, o mesmo do motor.
  static let defaultGlyph = "figureStrength"

  // O GLYPH_GROUPS do lib/glyphs.js.
  static let groups: [Group] = [
    Group(title: "Strength", glyphs: ["figureStrength", "arm", "abs", "legs", "pullup"]),
    Group(title: "Equipment", glyphs: ["dumbbell", "barbell", "kettlebell", "plate", "machine"]),
    Group(title: "Cardio", glyphs: ["figureRun", "bike", "swim", "boxing", "timer"]),
    Group(title: "Recovery", glyphs: ["stretch", "moon", "heart", "flame", "bolt"]),
  ]

  // Cada glyph que uma rotina pode ter, com o SF Symbol e o nome (a chave do catálogo do app).
  private static let table: [String: (symbol: String, name: String)] = [
    "figureStrength": ("figure.strengthtraining.traditional", "Strength training"),
    "arm": ("figure.arms.open", "Arms"),
    "abs": ("figure.core.training", "Core"),
    "legs": ("figure.step.training", "Legs"),
    "pullup": ("figure.climbing", "Pull-ups"),
    "dumbbell": ("dumbbell", "Dumbbell"),
    "barbell": ("figure.strengthtraining.functional", "Barbell"),
    "kettlebell": ("scalemass", "Kettlebell"),
    "plate": ("circle.circle", "Weight plate"),
    "machine": ("gearshape.2", "Machine"),
    "figureRun": ("figure.run", "Running"),
    "bike": ("figure.outdoor.cycle", "Cycling"),
    "swim": ("figure.pool.swim", "Swimming"),
    "boxing": ("figure.boxing", "Boxing"),
    "timer": ("timer", "Timer"),
    "stretch": ("figure.flexibility", "Stretching"),
    "moon": ("moon", "Moon"),
    "heart": ("heart", "Heart"),
    "flame": ("flame", "Flame"),
    "bolt": ("bolt", "Lightning"),
    // Os antigos: o primeiro seletor do openGym e os que um emoji antigo vira.
    "trophy": ("trophy", "Trophy"),
    "medal": ("medal", "Medal"),
    "crown": ("crown", "Crown"),
    "flag": ("flag", "Flag"),
    "star": ("star", "Star"),
    "target": ("target", "Target"),
    "shield": ("shield", "Shield"),
  ]

  // O LEGACY do glyphOf do openGym (frontend/src/lib/glyphs.js), com cada emoji escrito pelos códigos,
  // para nenhum seletor de variação se perder na cópia. Fica visível no módulo para o RoutineCasesTests
  // conferir o mapa inteiro contra o do openGym (issue #116).
  static let legacy: [String: String] = [
    "\u{1F4AA}": "arm",  // 💪
    "\u{1F9BE}": "arm",  // 🦾
    "\u{1FAF8}": "figureStrength",  // 🫸
    "\u{1FAF7}": "pullup",  // 🫷
    "\u{1F3CB}\u{FE0F}": "dumbbell",  // 🏋️
    "\u{1F3CB}": "dumbbell",  // 🏋
    "\u{1F3CB}\u{FE0F}\u{200D}\u{2640}\u{FE0F}": "dumbbell",  // 🏋️‍♀️
    "\u{1F9B5}": "legs",  // 🦵
    "\u{1F351}": "legs",  // 🍑
    "\u{1F525}": "flame",  // 🔥
    "\u{26A1}": "bolt",  // ⚡
    "\u{1F4A5}": "bolt",  // 💥
    "\u{1F9E8}": "bolt",  // 🧨
    "\u{1F624}": "flame",  // 😤
    "\u{1F3C3}": "figureRun",  // 🏃
    "\u{1F3C3}\u{200D}\u{2640}\u{FE0F}": "figureRun",  // 🏃‍♀️
    "\u{1F6B4}": "bike",  // 🚴
    "\u{1F3CA}": "swim",  // 🏊
    "\u{1F938}": "stretch",  // 🤸
    "\u{1F9D8}": "stretch",  // 🧘
    "\u{1F9D8}\u{200D}\u{2640}\u{FE0F}": "stretch",  // 🧘‍♀️
    "\u{1F94A}": "boxing",  // 🥊
    "\u{1F9D7}": "pullup",  // 🧗
    "\u{26F0}\u{FE0F}": "figureRun",  // ⛰️
    "\u{1F3D4}\u{FE0F}": "figureRun",  // 🏔️
    "\u{1F680}": "bolt",  // 🚀
    "\u{1F3AF}": "target",  // 🎯
    "\u{1F3C6}": "trophy",  // 🏆
    "\u{1F947}": "medal",  // 🥇
    "\u{2B50}": "star",  // ⭐
    "\u{1F31F}": "star",  // 🌟
    "\u{1F451}": "crown",  // 👑
    "\u{1F6E1}\u{FE0F}": "shield",  // 🛡️
    "\u{2694}\u{FE0F}": "shield",  // ⚔️
    "\u{2764}\u{FE0F}\u{200D}\u{1F525}": "heart",  // ❤️‍🔥
    "\u{1F98D}": "kettlebell",  // 🦍
    "\u{1F402}": "barbell",  // 🐂
    "\u{1F43B}": "kettlebell",  // 🐻
    "\u{1F981}": "boxing",  // 🦁
    "\u{1F43A}": "figureRun",  // 🐺
    "\u{1F988}": "swim",  // 🦈
    "\u{1F916}": "machine",  // 🤖
  ]

  // A chave do ícone, como o glyphOf do openGym: a chave conhecida passa, o emoji antigo vira a dele
  // pelo mapa e, sem achar, o mapa é tentado de novo com o primeiro caractere depois de tirar o
  // seletor de variação (U+FE0F) e o ZWJ (U+200D); o resto é o padrão.
  static func key(for glyph: String) -> String {
    if glyph.isEmpty { return defaultGlyph }
    if table[glyph] != nil { return glyph }
    if let key = legacy[glyph] { return key }
    // O [...v] do JS anda por ponto de código, e não por caractere: o mesmo que os unicodeScalars.
    let base = glyph.unicodeScalars.first { $0 != "\u{FE0F}" && $0 != "\u{200D}" }
    return base.flatMap { legacy[String($0)] } ?? defaultGlyph
  }

  // O SF Symbol do ícone.
  static func symbol(for glyph: String) -> String {
    table[key(for: glyph)]?.symbol ?? "figure.strengthtraining.traditional"
  }

  // O nome do ícone, para o menu e o VoiceOver, no idioma pedido.
  @MainActor static func name(of glyph: String, locale: Locale) -> String {
    AppText.text(table[key(for: glyph)]?.name ?? "Strength training", locale: locale)
  }

  // O título de um grupo do seletor, no idioma pedido.
  @MainActor static func title(of group: Group, locale: Locale) -> String {
    AppText.text(group.title, locale: locale)
  }
}
