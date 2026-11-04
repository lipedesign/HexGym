// O espaçamento, os raios e o alvo mínimo de toque do HexGym (seção 6 do design doc, "Design system
// antes das telas"). Os espaços andam de 4 em 4 até 16 e depois de 8 em 8, mais o 48 das margens
// grandes.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: os espaços e os raios.

import CoreGraphics

public enum HexSpacing {
  public static let xxs: CGFloat = 4, xs: CGFloat = 8, s: CGFloat = 12, m: CGFloat = 16, l: CGFloat = 24, xl: CGFloat = 32, xxl: CGFloat = 48
}

// Os raios dos cantos: o chip, o botão e o cartão.
public enum HexRadius {
  public static let chip: CGFloat = 10, button: CGFloat = 18, card: CGFloat = 28
}

// O alvo de toque nunca fica abaixo de 44 pt, no iPhone e no Watch.
public enum HexTarget {
  public static let minimum: CGFloat = 44
}
