# O movimento e o háptico

Os movimentos e os hápticos do HexGym, e o que muda com Reduzir Movimento, Reduzir Transparência e Aumentar Contraste. As duas tabelas são escolhas recomendadas, com a delegação do Lipe de 03/11/2026.

No código: `Motion/HexMotion.swift` e `Motion/HexHaptic.swift`. Os testes estão em `MotionTests.swift`, e o que cada componente faz com os ajustes de acessibilidade, nos testes de cada um.

## Os movimentos

Cada movimento é um `HexMotion`. O `spec(reduceMotion:)` dá a curva, e o `animation(reduceMotion:)` dá a `Animation` do SwiftUI pronta.

| Movimento | Normal | Com Reduzir Movimento | Onde aparece |
|---|---|---|---|
| `tap` | `spring` de 0,25 s, `bounce` 0 | `easeInOut` de 0,15 s, só opacidade | o aperto do botão principal e dos botões − e + das entradas |
| `change` | `spring` de 0,35 s, `bounce` 0,1 | `easeInOut` de 0,2 s, só opacidade | o número que rola |
| `enter` | `spring` de 0,5 s, `bounce` 0,15 | `easeInOut` de 0,25 s, só opacidade | o que entra na tela; nenhum componente do pacote usa ainda |
| `celebrate` | `spring` de 0,6 s, `bounce` 0,35 | `easeInOut` de 0,3 s, só opacidade | o carimbo de recorde |
| `breathe` | `easeInOut` de 2 s, indo e voltando sem parar | nenhum | o brilho que respira |

- **"Só opacidade"** quer dizer que, com Reduzir Movimento, nada muda de lugar nem de tamanho: o `allowsMovement` do movimento é falso, e o componente troca a escala ou o deslocamento por uma troca de opacidade.
- **O brilho respira** entre 95% e 105% do tamanho (`HexBreathing.scale`, de 0,95 a 1,05), num ciclo de 4 s (`HexBreathing.period`): 2 s de ida e 2 s de volta.
- **A regra mora num lugar só.** O botão principal, o carimbo e o brilho decidem o que fazer pelo `spec(reduceMotion:)` do movimento deles, e não por uma regra própria.

Os testes:

- `reduceMotionNeverMoves`: com Reduzir Movimento, nenhum dos cinco movimentos tem `allowsMovement`.
- `theGlowStopsWithReduceMotion`: com Reduzir Movimento, o `breathe` fica sem curva e sem animação; sem ele, o `breathe` repete.
- `motionsMatchTheTable`: o `tap`, o `celebrate` (nas duas versões) e a animação do `change` são os da tabela.

## Os hápticos

Cada háptico é um `HexHaptic`, com uma versão para o iPhone e outra para o Watch. O `kind(on:)` dá o háptico da tabela, e o `feedback(on:)` dá o `SensoryFeedback` para o `.sensoryFeedback` das views. Sem dizer a plataforma, vale a do aparelho (`HexPlatform.current`: `.watch` no watchOS, `.phone` no resto).

| Háptico | iPhone | Watch | Onde toca |
|---|---|---|---|
| `increase` | `.selection` | `.increase` | o botão + das entradas do treino |
| `decrease` | `.selection` | `.decrease` | o botão − das entradas do treino |
| `setLogged` | `.success` | `.success` | a série registrada: toca ao marcar a série, pelo efeito `haptic` do motor, que o `WorkoutSession` do app publica (`haptic` e `hapticTick`) para a tela do treino tocar com `.sensoryFeedback` |
| `record` | `.impact(weight: .heavy, intensity: 1)` | o mesmo | o carimbo de recorde, quando ele chega |
| `restDone` | `.warning` | `.start` | o anel de descanso, quando o tempo chega a zero |
| `error` | `.error` | `.error` | um erro; nenhum componente do pacote usa ainda |

- **Por que o iPhone usa outros:** a documentação da Apple diz que `.increase` e `.decrease` só tocam no watchOS e no visionOS, e `.start` só no watchOS.
- **Por que a tabela é um tipo nosso:** no Mac, o `SensoryFeedback` não guarda o peso do impacto (o `.heavy` fica igual ao `.light`). O `HexFeedback` guarda, então a tabela mora nele e o teste confere o `kind`. O `feedback(on:)` só traduz. O peso de verdade só se sente no aparelho.

O teste `hapticsMatchTheTable` confere as duas colunas e a tradução do Watch.

## Com Reduzir Movimento

Nada se move, e nenhuma função se perde.

| Componente | Normal | Com Reduzir Movimento |
|---|---|---|
| Botão principal e botões − e + | encolhe para 0,97 ao ser apertado | não encolhe; só esmaece para 0,8 |
| Número que rola | os dígitos rolam (`numericText`) | o número troca por opacidade |
| Carimbo de recorde | cai de 1,4 vez o tamanho até o tamanho dele | só aparece, por opacidade |
| Brilho que respira | cresce e encolhe num ciclo de 4 s | fica parado, no tamanho 1 |
| Transição de "Começar treino" | o botão cresce até virar a tela do treino (zoom) | sem zoom; a tela aparece sem se mover |

Quando o Reduzir Movimento liga com o brilho no meio do ciclo, ele volta ao tamanho 1 numa transação sem animação, porque uma animação que repete sem parar não para só porque a próxima é nenhuma (teste `theGlowStopsStillWhenReduceMotionTurnsOn`).

## Com Reduzir Transparência

| Componente | O que muda |
|---|---|
| Brilho que respira | apaga: fica só o fundo preto |
| Cartão de vidro e botões secundários | o próprio sistema deixa o vidro opaco; no simulador do iPhone, os dois viram uma cor lisa ([componentes.md](componentes.md#o-cartão-de-vidro)) |

Os outros componentes não têm transparência e não mudam.

## Com Aumentar Contraste

| Componente | O que muda |
|---|---|
| Todas as cores | a paleta passa para as cores de alto contraste (veja [cores.md](cores.md)): no Ultravioleta, o destaque #ABA5FF e o botão #8A88FF com rótulo preto; no Cobre, o destaque #F5976C; no claro, os tons mais escuros |
| Brilho que respira | a força cai à metade (0,85 vira 0,425 no Ultravioleta) e a cor de apoio sai |
| Cartão de vidro | fica sem a tinta do tema, no vidro da Apple como vem |
| Botões secundários | continuam tingidos, com o destaque de alto contraste |
| Botões − e + das entradas | o fundo passa para o cartão do alto contraste, #242426 |

A prévia de alto contraste da galeria (`contrastPreview` do `ThemeModel`) faz as mesmas trocas, sem mudar o ajuste do aparelho.

## Os três juntos

Com Reduzir Movimento, Reduzir Transparência e Aumentar Contraste ligados ao mesmo tempo, as regras de cada um valem juntas: nada se move, o brilho apaga, as cores são as de alto contraste, e todo componente continua fazendo o que faz. O teste `theGlowFollowsAccessibility` confere o brilho com os ajustes sozinhos e juntos.
