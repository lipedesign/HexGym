// A Coroa Digital nas entradas do treino, no Watch (Task 11 do plano da fase 1): cada dente que a
// coroa cruza é um passo, para cima quando o valor da coroa cresce e para baixo quando diminui. A conta
// fica fora da view, para os testes rodarem no Mac: o WorkoutInput, no watchOS, passa cada mudança da
// coroa por aqui e chama o onStep uma vez por passo.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: um passo por dente da Coroa Digital, e o
// dente mais perto em cada leitura (#121), no lugar do floor.

public enum CrownSteps {
  // Os passos entre duas leituras da coroa: o dente mais perto de new menos o dente mais perto de old,
  // .up quando o número é positivo e .down quando é negativo. Um valor que não é finito não dá passo
  // nenhum. Com o dente mais perto, o passo acontece quando a coroa passa do meio caminho entre dois
  // dentes: um toque mínimo que sai do dente e volta não dá passo nenhum, nos dois sentidos. No meio
  // exato, o rounded() vai para longe do zero, e um giro que para ali e volta ainda dá um passo e o de
  // volta (raro, porque a coroa descansa no dente; a histerese fica na issue #128). Com o floor (até a #121),
  // o mesmo toque para baixo dava -1 e depois +1, e para cima não dava nada (achado no QA da PR #86).
  public static func steps(from old: Double, to new: Double) -> [StepDirection] {
    guard old.isFinite, new.isFinite else { return [] }
    let crossed = new.rounded() - old.rounded()
    // Um giro de verdade cruza poucos dentes entre duas leituras: o teto só protege a conta de um salto
    // absurdo, que não viraria milhares de passos de uma vez.
    let count = Int(min(abs(crossed), Double(maxStepsPerChange)))
    return Array(repeating: crossed > 0 ? .up : .down, count: count)
  }

  // O máximo de passos de uma mudança só da coroa.
  static let maxStepsPerChange = 100
}
