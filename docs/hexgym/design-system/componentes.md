# Os componentes

Cada componente do HexDesign, com o que faz, os estados, o que o VoiceOver diz, a versão do Watch e o print. Primeiro os nossos, depois os da Apple com a marca. As camadas estão explicadas no [README](README.md#as-três-camadas); o que muda com os ajustes de acessibilidade, em [movimento-e-haptico.md](movimento-e-haptico.md); a escala de texto (`.hexFont`) e o logotipo, em [tipografia.md](tipografia.md).

Os componentes leem as cores do tema no ambiente (`@Environment(\.hexPalette)`), então a raiz das views precisa do `.hexTheme(model)`. Eles só mostram valores e repassam toques: o passo da carga e do esforço é do motor, não daqui.

## As medidas comuns

No código: `Layout/HexLayout.swift`. São escolhas recomendadas, com a delegação do Lipe de 03/11/2026.

| Espaço | Valor | | Raio | Valor |
|---|---|---|---|---|
| `HexSpacing.xxs` | 4 pt | | `HexRadius.chip` | 10 pt |
| `HexSpacing.xs` | 8 pt | | `HexRadius.button` | 18 pt |
| `HexSpacing.s` | 12 pt | | `HexRadius.card` | 28 pt |
| `HexSpacing.m` | 16 pt | | | |
| `HexSpacing.l` | 24 pt | | | |
| `HexSpacing.xl` | 32 pt | | | |
| `HexSpacing.xxl` | 48 pt | | | |

O alvo de toque nunca fica abaixo de 44 pt (`HexTarget.minimum`), no iPhone e no Watch.

## Nossos

### O botão principal

![O botão principal nos quatro temas: normal, com alto contraste e desligado, em .regular e .large](imagens/botao-principal.png)

**O que faz:** o botão da ação principal da tela, como "Começar treino". Ocupa a largura toda, no `fill` do tema, com o rótulo no `onFill`.

```swift
Button("Começar treino") {}.buttonStyle(.hexPrimary)
Button("Começar treino") {}.buttonStyle(.hexPrimary(size: .large))
```

- **Tamanhos:** `.regular`, com altura mínima de 56 pt e rótulo no `headline`; e `.large`, com 72 pt e rótulo no `title`. Os dois passam do alvo mínimo de 44 pt. Os dois estilos são em caixa alta.
- **Forma:** raio de 18 pt (`HexRadius.button`), contínuo; 24 pt de margem dos lados e 12 pt em cima e embaixo; o rótulo centralizado.
- **Com Dynamic Type:** o rótulo cresce com o estilo dele e o botão cresce junto, sem ficar abaixo da altura mínima. Com o Texto em Negrito, o `headline` sobe de 700 para 800.

**Estados:**

| Estado | Como fica |
|---|---|
| Normal | `fill` com o rótulo no `onFill` |
| Apertado | encolhe para 0,97 com o movimento `tap`; com Reduzir Movimento, não encolhe e esmaece para 0,8 |
| Desligado (`.disabled(true)`) | opacidade de 0,4 |
| Alto contraste | as cores de alto contraste do tema; no Ultravioleta, #8A88FF com rótulo preto |

**VoiceOver:** é um botão do SwiftUI, e o VoiceOver lê o rótulo como botão.

**Testes:** `thePrimaryButtonOnlyFadesWithReduceMotion` (0,97 sem Reduzir Movimento e 0,8 de opacidade com ele) e `thePrimaryButtonHasRoomForAThumb` (56 e 72 pt).

**No Watch:** preenchida na Task 11.

### As entradas do treino

![As entradas de carga, repetições e esforço, e a carga empilhada como nos tamanhos de acessibilidade](imagens/entradas.png)

**O que faz:** registra a carga, as repetições e o esforço de uma série, com uma mão, entre séries. Cada entrada tem o rótulo do campo, o valor, a unidade e os botões de diminuir e aumentar.

```swift
LoadInput(value: 141.3, unit: .kg) { direção in /* o motor aplica o passo e devolve o valor novo */ }
RepsInput(value: 8) { direção in }
EffortInput(value: 8.5, scale: .rpe) { direção in }   // value: nil para o esforço vazio
```

- **O valor:** o rótulo vai no `caption`, em cinza (`.secondary`); o valor vai num [número que rola](#o-número-que-rola), no `number`, na cor primária do sistema (branco no escuro); a unidade vai no `unit`, no destaque do tema: KG, LB, RPE ou RIR (o `unit` é em caixa alta). As repetições não têm unidade.
- **Os botões − e +:** 56 pt, raio de 10 pt (`HexRadius.chip`), os símbolos `minus` e `plus` do SF Symbols no destaque do tema, sobre o cartão do sistema (#1C1C1E, ou #242426 com alto contraste), que é um dos fundos onde o texto na cor do tema pode ficar. Cada toque toca o háptico `decrease` ou `increase` e chama o `onStep` com `.down` ou `.up`. Apertados, eles fazem o mesmo que o botão principal.
- **A entrada não decide o passo:** quem usa a entrada aplica o passo pelo motor (as regras do openGym) e passa o valor novo.

**Como a carga aparece:** como foi registrada, nunca arredondada para a grade, com até duas casas, sem zero à direita, sem separar o milhar e no jeito do idioma (`WorkoutFormat.load`). O teste `loadsShowWhatWasLogged` confere:

| Registrada | Em português | Em inglês |
|---|---|---|
| 141,3 | 141,3 | |
| 141,25 | 141,25 | |
| 142,5 | 142,5 | 142.5 |
| 1000 | 1000 | |
| 141,333 | 141,33 | |

**Estados:**

| Estado | Como fica |
|---|---|
| Normal | os botões dos dois lados do valor |
| Tamanhos de acessibilidade (AX1 a AX5) | os botões descem para baixo do valor, lado a lado (`WorkoutInputLayout.axis` dá `.vertical`) |
| Número grande | os dígitos tabulares seguram a largura: 1000 kg e 1111 kg ocupam o mesmo espaço; se não couber, o valor diminui até a metade, sem cortar |
| Esforço vazio | só a unidade aparece, e a entrada tem a mesma altura de quando há um valor: nada pula quando o primeiro valor chega |
| Desligado | os botões ficam com opacidade de 0,4 |

**VoiceOver:**

- O rótulo, o valor e a unidade são um elemento só, ajustável: o VoiceOver diz o rótulo e o valor falado, e deslizar para cima ou para baixo aumenta ou diminui (chama o `onStep`).
- Os botões continuam elementos próprios, "Diminuir" e "Aumentar", para quem usa o Controle por Voz.
- O valor falado diz a unidade por extenso:

| Entrada | Português do Brasil | Inglês |
|---|---|---|
| Carga | "142,5 quilogramas", "317,5 libras", "1 quilograma", "0 quilogramas" | "317.5 pounds", "1 kilogram", "0 kilograms" |
| Repetições | "1 repetição", "8 repetições", "0 repetições" | "1 repetition", "8 repetitions" |
| Esforço | "RPE 8,5"; vazio, "Esforço não registrado" | "RIR 2"; vazio, "Effort not logged" |

Num aparelho em outro idioma, os textos saem em inglês, com o plural do inglês ("1 repetition" num aparelho em japonês).

**Testes:** `loadsShowWhatWasLogged`, `voiceOverSaysTheUnit`, `anEmptyEffortShowsNothing`, `accessibilitySizesStack`, `bigLoadsKeepTheirWidth`, `anEmptyEffortKeepsItsHeight`, `otherLanguagesUseTheEnglishPlural`, `zeroRepsArePluralInPortuguese` e `zeroLoadsArePluralInPortuguese`.

**Cuidado:** a unidade fica no destaque do tema. Num cartão de uma tela que sobe, ela iria contra a regra de onde o texto na cor do tema pode ficar ([cores.md](cores.md#onde-o-texto-na-cor-do-tema-pode-ficar)). A galeria (Task 10) confere isso no simulador.

**No Watch:** preenchida na Task 11.

### Os segmentos inclinados

![Os segmentos nos quatro temas: 0, 3 e 5 de 5, e 1 de 5 da direita para a esquerda](imagens/segmentos.png)

**O que faz:** mostra as séries do exercício numa linha, um paralelogramo por série.

```swift
SlantedSegments(total: 5, done: 3)
```

- **Forma:** cada segmento é inclinado 18°, com o alto puxando para a direita, e há 4 pt (`HexSpacing.xxs`) entre eles. A linha ocupa a largura toda. A altura é de 10 pt e cresce com o Dynamic Type. A inclinação de 18° é uma escolha recomendada, com a delegação do Lipe de 03/11/2026.

**Estados:**

| Segmento | Cor |
|---|---|
| Série feita | destaque do tema |
| Série atual (a seguinte às feitas) | destaque do tema a 35% |
| Séries que faltam | cinza terciário do sistema |

- **Da direita para a esquerda** (árabe, hebraico), a linha começa na direita, e a inclinação vira junto. O teste `segmentsLightFromTheStartOfTheLine` confere que, com uma série feita, o lado de onde a linha começa é o mais claro.

**VoiceOver:** a linha é um elemento só, com o rótulo "Séries" e o valor "3 de 5 séries" ("3 of 5 sets" em inglês). O plural segue o total: "0 de 1 série", "0 de 0 séries", "1 of 1 set".

**Testes:** `segmentsLightFromTheStartOfTheLine`, `segmentsSayWhereYouAre`, `otherLanguagesCountSetsInEnglish` e `zeroSetsArePluralInPortuguese`.

**No Watch:** preenchida na Task 11.

### O carimbo de recorde

![O carimbo de recorde em português e em inglês](imagens/carimbo.png)

**O que faz:** marca um recorde novo. "Recorde" ("Record" em inglês) no `title`, em caixa alta, no ouro do recorde, com contorno de 3 pt no raio de 10 pt (`HexRadius.chip`).

```swift
RecordStamp(isShown: bateuRecorde)
```

- **A inclinação:** o carimbo gira -8° no `rotationEffect` (`.rotationEffect(.degrees(-8))`), e por isso sobe para a direita, como os segmentos. No print, o texto da folha diz "girado 8° para subir à direita": é o mesmo giro, escrito pelo sentido.
- **O ouro:** a cor do recorde da paleta, #FFC94D no escuro. O recorde é sempre em ouro, em todo tema.
- O carimbo dourado em contorno, o giro e a queda de 1,4 vez o tamanho são escolhas recomendadas, com a delegação do Lipe de 03/11/2026.

**Estados:**

| Momento | O que acontece |
|---|---|
| `isShown` passa de falso para verdadeiro | o carimbo cai de 1,4 vez o tamanho até o tamanho dele, e de transparente a visível, com o movimento `celebrate`; toca o háptico `record`; e o VoiceOver anuncia "Novo recorde" |
| A mesma passagem, com Reduzir Movimento | ele só aparece, por opacidade, sem mudar de tamanho; o háptico e o anúncio continuam |
| O carimbo já abre com `isShown` verdadeiro | aparece parado, sem animação, sem háptico e sem anúncio |
| `isShown` volta para falso | some na hora, sem animação, pronto para o próximo recorde |

O carimbo só anima, toca e anuncia na passagem de `isShown` de falso para verdadeiro. Para mostrar um recorde que acabou de acontecer, a tela troca o `isShown` de um carimbo que já está montado.

- **Com Dynamic Type:** o texto cresce com o `title` até o teto de 60 pt, numa linha só.
- **Com o Texto em Negrito:** fica igual, porque o `title` já está no peso 800, o mais forte do pacote.

**VoiceOver:** escondido enquanto não aparece. Mostrado, é um elemento só, "Recorde". Na chegada, o anúncio "Novo recorde".

**Testes:** `theStampLandsOrFades` (cai de 1,4 sem Reduzir Movimento, e de 1 com ele).

**No Watch:** preenchida na Task 11.

### O anel de descanso

![O anel de descanso em 1:30 de 2:00, 59:59 e 1:00:00 de uma hora, e 1:30 no Ciano](imagens/anel.png)

**O que faz:** mostra o tempo de descanso que falta, com o tempo no centro.

```swift
RestRing(total: 120, remaining: 90)   // em segundos
```

- **Forma:** 60 traços curtos em volta de um círculo, cada um inclinado 18° em relação ao raio, retos, sem pontas redondas. Os acesos ficam no destaque do tema, e os apagados no cinza terciário do sistema. Assim ele não parece um anel de atividade da Apple, que é uma faixa contínua com pontas redondas. O anel em 60 traços inclinados é uma escolha recomendada, com a delegação do Lipe de 03/11/2026.
- **A direção:** os traços contam a partir do alto, no sentido do relógio. O tempo que passa apaga os traços nessa mesma direção, como um ponteiro: com 1:30 de 2:00, os 15 traços apagados vão do alto até as três horas.
- **Não espelha:** da direita para a esquerda, o anel continua igual, no sentido do relógio, porque ele é um relógio.
- **Quantos acendem:** `RestRingModel.litTicks` dá o arredondamento de 60 × o que falta ÷ o total, entre 0 e 60, e 0 quando o total é 0.
- **O tempo:** no centro, num [número que rola](#o-número-que-rola) no `number`. Abaixo de uma hora, `m:ss` (1:30, 59:59); a partir dela, `h:mm:ss` (1:00:00, 1:02:05); um valor negativo dá 0:00. Se o tempo não couber, ele diminui até a metade, sem cortar.
- **O tamanho:** 220 pt de diâmetro no tamanho de texto padrão, crescendo com o Dynamic Type, e nunca maior que a largura que tem: numa largura de 150 pt, o anel fica com 150 pt. O tamanho do anel não depende do texto, e 59:59 virando 1:00:00 não muda nada de tamanho.

**Estados:**

| Momento | O que acontece |
|---|---|
| Contando | os traços acesos diminuem e o tempo rola |
| O tempo chega a zero | toca o háptico `restDone` (`.warning` no iPhone) |

**VoiceOver:** um elemento só, com o rótulo "Descanso", o valor falado ("1 minuto e 30 segundos", "1 hora"; em inglês, "1 minute, 30 seconds") e o traço de que atualiza com frequência.

**Ainda a resolver:** em português, com o tempo em zero, o VoiceOver diz "0 segundo", no singular, e não "0 segundos". A galeria (Task 10) cuida disso.

**Testes:** `restTimeNeverJumps`, `restTimeIsSpoken`, `theRingCountsDownInTicks`, `theRingKeepsItsSizeWhenAnHourBegins` e `theRingNeverOutgrowsItsWidth`.

**No Watch:** preenchida na Task 11.

### O brilho que respira

![O brilho nos quatro temas, sem e com alto contraste](imagens/brilho.png)

**O que faz:** o fundo das telas do app: preto, com um brilho na cor do tema no alto, que cresce e encolhe devagar.

```swift
TelaQualquer().background { BreathingGlow() }
```

- **Forma:** um gradiente radial que sai do meio do alto da tela e vai até 60% da largura. Começa na cor do brilho do tema, em Display P3, com a opacidade do tema, e some até zero. Quando o tema tem cor de apoio (Ciano e Cobre), o gradiente passa por ela no ponto 0,55 do raio, com metade da opacidade do brilho, e dali some até zero.
- **A respiração:** a escala vai e volta entre 95% e 105%, a partir do alto, num ciclo de 4 s, com o movimento `breathe`.
- **Fica atrás de tudo:** cobre a tela toda, inclusive as áreas seguras, não recebe toque e não aparece para o VoiceOver.
- O brilho com metade da força no alto contraste, apagado com Reduzir Transparência e parado no Watch são escolhas recomendadas, com a delegação do Lipe de 03/11/2026.

**Estados** (`GlowSpec.resolve`):

| Situação | Como fica |
|---|---|
| Normal | respira, na opacidade do tema (0,85 no Ultravioleta) |
| Alto contraste | a opacidade cai à metade (0,425 no Ultravioleta) e a cor de apoio sai |
| Reduzir Movimento | fica parado, no tamanho 1 |
| Reduzir Transparência | apaga: fica só o preto |
| Claro | não há brilho: fica só o preto |
| Watch | fica parado |

**VoiceOver:** nenhum. O brilho é decoração.

**Testes:** `theGlowFollowsAccessibility`, `noGlowOnLightAndAStillGlowOnTheWatch`, `theGlowStopsStillWhenReduceMotionTurnsOn` e `theGlowCarriesTheSupportColorUnlessContrastIsUp`.

**No Watch:** preenchida na Task 11. O que o pacote já faz no watchOS: o brilho usa a superfície do Watch e fica parado.

## Da Apple, com a marca

São componentes da Apple, com o comportamento dela. O HexGym só põe a cor, a tipografia e a composição.

### O número que rola

**O que faz:** um número que rola os dígitos quando muda, para cima quando cresce e para baixo quando diminui. É a transição `numericText` da Apple, com a nossa tipografia.

```swift
RollingNumber(value: 142.5, text: "142,5")                    // no number
RollingNumber(value: 90, text: "1:30", style: .display)
```

- `value` dá o sentido da rolagem; `text` é o que aparece, já formatado.
- O estilo padrão é o `number`. Nos estilos de números, os dígitos tabulares fazem o número mudar sem pular de largura.
- A troca usa o movimento `change`.

**Estados:**

| Situação | Como muda |
|---|---|
| Normal | os dígitos rolam (`.numericText(value:)`) |
| Reduzir Movimento | o número troca por opacidade (`.opacity`) |

**VoiceOver:** lê o texto como ele aparece. Nas entradas do treino e no anel, quem fala é o elemento de fora, com a unidade.

**Testes:** `rollingNumbersRollUnlessReduceMotion`.

**No Watch:** preenchida na Task 11.

**Print:** o número que rola aparece nos prints das [entradas do treino](#as-entradas-do-treino) e do [anel de descanso](#o-anel-de-descanso). A rolagem em si aparece no vídeo do simulador, na Task 10.

### O cartão de vidro

**O que faz:** um cartão de informação no vidro da Apple (Liquid Glass), tingido pelo tema.

```swift
HexGlassCard {
  Text("Semana 3").foregroundStyle(.secondary)
  Text(verbatim: "4 treinos").hexFont(.title)
}
```

- **Forma:** o conteúdo com 16 pt de margem (`HexSpacing.m`), no vidro regular da Apple, com raio de 28 pt (`HexRadius.card`), contínuo.
- **A tinta:** o destaque do tema a 18%. O vidro tingido com o destaque a 18% e sem tinta no alto contraste é uma escolha recomendada, com a delegação do Lipe de 03/11/2026.
- **O texto sobre o vidro:** vai em branco ou nos cinzas do sistema, nunca na cor do tema. É a mesma regra da #71 ([cores.md](cores.md#onde-o-texto-na-cor-do-tema-pode-ficar)): o texto na cor do tema só fica sobre o fundo da tela e sobre o cartão do sistema. O contraste do texto sobre o vidro tingido ainda não foi medido; a galeria mede no simulador (Task 10).

**Estados:**

| Situação | Como fica |
|---|---|
| Normal | vidro regular, tingido pelo destaque a 18% (`HexGlass.tintOpacity` dá 0,18) |
| Aumentar Contraste, ou a prévia de alto contraste | vidro regular sem tinta (`tintOpacity` dá nil) |
| Reduzir Transparência | o sistema deixa o vidro opaco |

**VoiceOver:** o vidro não é um elemento; o VoiceOver lê o conteúdo.

**Testes:** `theGlassTakesTheThemeUnlessContrastIsUp`.

**No Watch:** preenchida na Task 11.

**Print:** o vidro só aparece de verdade no simulador, então o print dele fica para a Task 10.

### Os botões secundários

**O que faz:** os botões que não são a ação principal da tela, no estilo `.glass` da Apple, tingidos pelo destaque do tema.

```swift
HStack {
  Button("Pular") {}
  Button("Trocar exercício") {}
}
.hexSecondaryButton()   // os botões dentro desta view
```

**Estados:** os da Apple (apertado, desligado), com a tinta no destaque do tema. Com Aumentar Contraste, continuam tingidos, com o destaque de alto contraste; só o cartão de vidro perde a tinta. O contraste do rótulo sobre o vidro tingido fica para a galeria medir no simulador (Task 10).

**VoiceOver:** são botões do SwiftUI; o VoiceOver lê o rótulo como botão.

**No Watch:** preenchida na Task 11.

**Print:** fica para a Task 10, com o vidro.

### A transição de "Começar treino"

**O que faz:** a assinatura do HexGym: o botão "Começar treino" cresce até virar a tela do treino. É o zoom de navegação da Apple.

```swift
@Namespace private var zoom
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@State private var treinoAberto = false

NavigationStack {
  Button("Começar treino") {
    withTransaction(StartWorkoutTransition.transaction(reduceMotion: reduceMotion)) { treinoAberto = true }
  }
  .buttonStyle(.hexPrimary)
  .hexStartWorkoutSource(id: "treino", in: zoom)
  .navigationDestination(isPresented: $treinoAberto) {
    TelaDoTreino().hexStartWorkoutDestination(id: "treino", in: zoom)
  }
}
```

- A origem (`hexStartWorkoutSource`) marca o botão de onde o zoom sai, e o destino (`hexStartWorkoutDestination`) põe o zoom na tela do treino.
- Quem abre a tela do treino o faz dentro de `withTransaction(StartWorkoutTransition.transaction(reduceMotion:))`.

**Estados:**

| Situação | Como abre |
|---|---|
| Normal | com o zoom (`usesZoom` dá verdadeiro) |
| Reduzir Movimento | sem zoom, e a transação desliga as animações: a tela aparece sem se mover. Essa troca é uma escolha recomendada, com a delegação do Lipe de 03/11/2026 |

**Para saber:** se o Reduzir Movimento mudar com a tela do treino aberta, a tela do treino recomeça o estado dela. Hoje isso não afeta ninguém, porque a tela do treino de verdade é da fase 3.

**VoiceOver:** a navegação é a da Apple; o VoiceOver anuncia a tela nova como em qualquer navegação.

**Testes:** `theZoomStepsAsideForReduceMotion` e `theWorkoutScreenAppearsStillWithReduceMotion`.

**No Watch:** preenchida na Task 11.

**Print:** a transição é um movimento e só aparece no simulador; o print e o vídeo ficam para a Task 10. Até a fase 3, ela aparece na galeria.
