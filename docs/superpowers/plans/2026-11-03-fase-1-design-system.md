# Fase 1 do HexGym (Design system): plano de implementação

> **Quem executa:** o orquestrador do relentless, como ele vem (nota `docs/decisions/notes/2026-11-03-um-orquestrador-so.md`), tocado pela sessão da fase 1 ao mesmo tempo que a fase 0. Cada Task é uma issue do milestone "Fase 1: Design system", sub-issue do épico da fase, e um PR para `develop`: uma worktree e uma branch por Task, o critério de aceite da issue é a Task deste plano (a linha `Plano:` da issue), e a revisão isolada do relentless é a revisão do PR. Os títulos ficam "Task N" porque é assim que a linha `Plano:` das issues aponta para eles. Os passos usam caixas de seleção (`- [ ]`).

**Objetivo:** o design system do HexGym num pacote Swift, o `HexDesign`: as cores dos quatro temas (com alto contraste e Display P3), a tipografia, o espaçamento, o movimento e os hápticos, os componentes nossos e os da Apple com a marca, em versões para iPhone e Watch, com uma galeria dentro do app, a troca de tema ao vivo e a documentação pública.

**Arquitetura:** `apple/Packages/HexDesign` é um pacote local (seção 8.7) que só usa SwiftUI, CoreText e Foundation. Ele não importa o `HexEngine` nem o `HexStore`: o Watch não roda o motor, e as regras de passo da carga e do esforço (`addStep` e `stepEffort`, no `lib` do openGym) continuam no motor; os componentes só mostram valores e repassam toques. O que dá para provar sem tela (cores, contraste, escala de texto, fontes de reserva, movimento, hápticos, formatos e tema) são funções puras testadas no Mac com `swift test`; as views leem o ambiente de acessibilidade do SwiftUI. Até o Xcode 27.2, o pacote roda com o `swift` das Command Line Tools; a galeria, o Watch e o ícone vêm depois, sobre as Tasks 9 e 10 da fase 0 (#21 e #22).

**Tecnologias:** Swift (`swift-tools-version: 6.2`), SwiftUI, CoreText e Swift Testing; a Barlow Condensed (SIL OFL 1.1) como recurso do pacote; Node 22 para as checagens; Xcode 27.2 a partir da Task 10.

**Especificação:** `docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md`, seções 5, 6 ("Linguagem visual", "Cor", "Design system antes das telas" e "Como o founder acompanha"), 8.7, 8.9, 8.12, 8.13, 9, 9.1 e 10. O estudo de cor é `docs/brand/estudo-de-cor-2026-10-31.md`.

## Decisões visuais de 03/11/2026

O founder aceitou as quatro recomendações da página das decisões da fase 1 (https://claude.ai/artifact/3fwPGoNm3EBDZkqesDkvbB), que é o registro visual da fase:

1. **Fonte:** Barlow Condensed nos números, nos títulos e no logotipo; SF Pro Compressed de reserva no cirílico e no grego; a fonte do sistema (SF Pro) no texto corrido e nas outras escritas. É a "tipografia final" da seção 10.
2. **Camadas:** a tabela da seção 6, com quatro ajustes. O número que rola (`numericText`) e a transição de "Começar treino" (`zoom`) passam para "Da Apple, com a marca"; os botões secundários usam o `.glass` da Apple tingido pelo tema; o brilho que respira entra como nosso.
3. **Alto contraste:** os valores da Task 1, com o botão do Ultravioleta mais claro (#8A88FF) e rótulo preto. Os cinzas vêm do sistema. O Display P3 mais vivo vale só no brilho, e o Giz fica sem ele. Com Aumentar Contraste, o cartão do sistema fica #242426 e o texto do Ultravioleta e do Cobre sobe para #ABA5FF e #F5976C; com ou sem ele, o texto na cor do tema fica só no fundo da tela e no cartão, e os cartões de uma tela que sobe levam texto branco ou nos cinzas do sistema (escolha recomendada, com a delegação do Lipe de 03/11/2026, na #71).
4. **Participação:** cada componente chega com prints no PR, e com vídeo do simulador quando houver simulador. Com a delegação do founder de 03/11/2026, nenhum componente espera aprovação dele: cada escolha visual que este plano faz além das quatro acima vem marcada como "escolha recomendada, com a delegação do Lipe de 03/11/2026", e a issue da Task repete a marca. A sessão da fase 1 atualiza a página depois de cada merge. O que o founder pedir para mudar depois vira uma Task normal.

As escolhas recomendadas deste plano: as cores do alto contraste sobre o cartão do sistema e o lugar do texto na cor do tema (#71), a escala de texto, o logotipo com `gym` no peso 200, o espaçamento e os raios, os movimentos e os hápticos, os nomes dos temas em inglês, o botão principal, as entradas do treino, os segmentos, o carimbo, o anel de descanso, o brilho no alto contraste e no Watch, o vidro tingido, o zoom com Reduzir Movimento, a organização da galeria e o botão que a abre, o botão compacto de 44 pt no Watch, a Coroa Digital e o ícone do app. Cada Task diz as suas.

## Restrições globais (Global Constraints)

Valem para toda Task. Os valores vêm da especificação, das decisões de 03/11/2026 e das sondas feitas em 03/11/2026 com o `swift` 6.4 das Command Line Tools (macOS 27.2, SDK MacOSX27.0).

- **Plataforma:** iOS 26 e watchOS 26 como mínimo. O pacote declara `platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)]`: o macOS existe só para o `swift test` rodar no Mac. Nenhuma API só do iOS 27 ou do watchOS 27. O que precisa do SDK do iPhone ou do Watch (a galeria, o Watch, o ícone) espera o Xcode 27.2 (#23) e o projeto (#21 e #22), e roda com `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs)`. Nada com o Xcode-beta.
- **O comando do pacote:** `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) --package-path apple/Packages/HexDesign`. As duas opções vêm da #19: o `--swift` cai nas Command Line Tools enquanto não há Xcode completo, e o `--swift-test-flags` dá as flags que carregam o plugin `TestingMacros`, que o `swift test` delas às vezes perde (6 falhas em 13 rodadas), e não dá nada com o Xcode completo. Se a #19 entrar com outro nome para essas opções, vale o da #19. Os passos dizem "o comando do pacote" e, quando for o caso, o `--filter`. Até a Task 8, o HexDesign não está em parte nenhuma do `check.mjs`, então o QA roda o comando do pacote além do `node scripts/hexgym/check.mjs`.
- **O que o `swift` das Command Line Tools não tem:** XCTest (só há Swift Testing); os macros `@Entry` e `#Preview` (faltam os plugins `SwiftUIMacros` e `PreviewsMacros`), então as chaves de ambiente são `EnvironmentKey` escritas à mão e não há `#Preview`; e o `xcstringstool`, então o `.xcstrings` quebra o build e os textos do pacote ficam em `Resources/Strings/<idioma>.lproj/<tabela>.strings` e `.stringsdict`, uma tabela por assunto (o `defaultLocalization` é `en`). O `@Observable` funciona. No Mac, o Dynamic Type não muda tamanho (`@ScaledMetric` e `Font.custom(_:size:relativeTo:)` dão o mesmo valor em `.large` e em `.accessibility3`): a escala é testada como função pura no Mac, e na tela, no simulador (Task 10).
- **Arquivos que a fase 0 está mexendo:** `scripts/hexgym/check.mjs` e `scripts/hexgym/xcode.mjs` (na #19, na #20 e na #22) e o projeto Xcode (na #21 e na #22). Uma Task daqui que precise mexer neles entra com `Depende de:` da issue da fase 0 que mexe ali, em vez de correr junto. A exceção é a Task 8: ela espera a #20, mas não a #22, que precisa do Xcode 27.2 (#23) e cria a parte `app`, longe da `packages`. Se a #22 entrar em `develop` no meio da Task 8, a branch dela faz `git merge origin/develop` antes do QA.
- **Os blocos de interface:** mostram só as assinaturas, e os corpos são de quem implementa. `{ get }` e `{ get set }` dizem se uma propriedade calculada é só de leitura ou também de escrita; fora de um protocolo, o Swift não compila essa forma, então ela não é para colar.
- **Poucas dependências:** nenhum pacote Swift de terceiros e nenhuma dependência npm nova. A Barlow Condensed é recurso, não dependência: os arquivos vêm de um commit fixado do `google/fonts`, conferidos pelo hash (Task 2).
- **Cores:** sempre em Display P3 (`Color(.displayP3, ...)`), com os valores aprovados em sRGB convertidos para o mesmo ponto (Task 1); o P3 mais vivo só no brilho, e nunca no Giz. Recorde sempre em ouro; erro sempre `Color.red`, o systemRed; os cinzas do sistema (`.secondary`, e `.tertiary` só em decoração e em estado desligado); esforço sempre com número ou rótulo, além da cor.
- **Claro e escuro:** o primeiro TestFlight é só escuro (`UIUserInterfaceStyle = Dark` desde a fase 0). Os valores claros existem e são testados, para onde o iOS força claro (widgets, tela bloqueada) e para um modo claro depois.
- **O tema fica no aparelho:** nos `UserDefaults` do App Group (`group.app.hexgym`), na chave `hexgym.theme`; nunca `theme` nem `accent` no documento compartilhado (seção 8.12).
- **Acessibilidade:** todo componente nosso funciona com Dynamic Type, VoiceOver, Reduzir Movimento, Aumentar Contraste, Reduzir Transparência, Texto em Negrito e hápticos, e tem versão para o Watch quando fizer sentido (seção 6). Alvo de toque de pelo menos 44 pt.
- **Desempenho (seção 8.13):** um toque reflete na tela em menos de 100 ms; transições e números que rolam sem perder quadro, a 120 Hz; nada pesado no `body` (as fontes e as tabelas são feitas uma vez, fora dele).
- **Texto para o usuário:** simples e humano, sem travessão; português do Brasil e inglês.
- **Mídias de exercício:** nenhuma entra no pacote, na galeria, nos prints ou nos vídeos. Nunca abrir, converter ou passar por ferramenta de IA as fotos e animações da Gym visual, e nada novo em `catalogue/media/`.
- **Prints e vídeo dos PRs:** como na fase 0: em `docs/hexgym/prints/<issue>/`, no commit do próprio PR, mostrados no corpo por `https://github.com/lipedesign/HexGym/blob/<sha>/docs/hexgym/prints/<issue>/<arquivo>?raw=true`; o vídeo é do simulador (`xcrun simctl io <udid> recordVideo --codec h264`), com até 15 s e menos de 5 MB. Antes do simulador, os prints saem de testes de print com `ImageRenderer`, ligados só com `HEXDESIGN_PRINTS=<pasta absoluta>` no ambiente: sem a variável, eles ficam pulados e não contam na parte `packages`. O vidro só aparece de verdade no simulador, então os prints dele esperam a Task 10.
- **Escolhas visuais deste plano:** marcadas como "escolha recomendada, com a delegação do Lipe de 03/11/2026", e a issue da Task repete a marca. Quem implementa não publica nada fora do repositório; a página das decisões é atualizada pela sessão da fase 1.
- **Duas fases ao mesmo tempo:** (1) nada solto no checkout principal; os scripts do relentless rodam, e os arquivos da revisão ficam, na worktree da Task. (2) Nenhuma linha em `docs/decisions/log.jsonl` nem no `README.md` até o `/decide 36`. (3) Antes de um `new-adr.sh`, atualizar de `origin/develop` e olhar os PRs abertos atrás de ADRs novos; numa colisão, renumerar. (4) O comando de teste roda todas as partes de propósito, e um PR que cria uma parte ou muda a lista de partes mexe na linha "unknown part" do `check.test.mjs`. (5) Um `git fetch` ao mesmo tempo que outro pode dar trava de ref, e o `worktree-create.sh` usa o arquivo fixo `/tmp/relentless-wt-push.err`: se um fetch falhar por trava, ou se o script disser que uma branch existe quando ela não existe, esperar um minuto e tentar de novo uma vez. E todo `gh issue list` desta fase leva `--milestone "Fase 1: Design system"`.
- **Repositório, IDs, Git Flow, estado das issues, `.claude/` e commits:** como nas Restrições globais da fase 0 (`docs/superpowers/plans/2026-10-31-fase-0-fundacao.md`).

## Foco da revisão (Review Focus)

O que a especificação implica, nenhuma Task testaria sozinha e mais pode morder quem usa o app. Cada linha ganhou um teste na Task dona do código.

1. **Nomes em outras escritas** (os exercícios vêm em 20 idiomas, com ru, uk, ar, zh, ko, th, hi e bn): o cirílico e o grego saem na SF Pro Compressed, no peso do estilo; as outras escritas saem na fonte do sistema, nunca num quadrado vazio; o latim fica na Barlow; e da direita para a esquerda, os segmentos acendem a partir da direita. Testes nas Tasks 2 e 6.
2. **O maior tamanho de texto (AX5) e o Texto em Negrito:** os números crescem até o teto do estilo, as entradas do treino empilham, nada é cortado, e o negrito sobe um peso. Testes nas Tasks 2, 5 e 10, e os prints em AX5 da Task 10 mostram que nada é cortado.
3. **Números grandes e descansos longos** (1000 kg, 2000 lb, 59:59 virando 1:00:00): dígitos tabulares, então nada pula de largura. Testes nas Tasks 2, 5 e 6.
4. **Reduzir Movimento, Reduzir Transparência e Aumentar Contraste, cada um sozinho e os três juntos:** nada se move, o brilho apaga ou fica parado, as cores viram as de alto contraste, e nenhuma função se perde. Testes nas Tasks 3, 4, 5, 6 e 7.
5. **Carga fora da grade e o idioma do aparelho** (141,3 kg; 141,25 kg; 317,5 lb; vírgula e ponto): a carga aparece como foi registrada, com até duas casas e sem zero à direita, e o VoiceOver diz a unidade. Teste na Task 5.

## Mapa dos arquivos

```
apple/Packages/HexDesign/                 o design system (iPhone e Watch; o Mac só para os testes)
  Package.swift
  Sources/HexDesign/
    Color/HexRGB.swift                    sRGB, a conversão para Display P3 e o contraste da WCAG
    Color/HexPalette.swift                os quatro temas, o alto contraste, o claro, o Watch e a ilha
    Type/HexFonts.swift                   o registro da Barlow e a cascata de reserva (CoreText)
    Type/HexTextStyle.swift               a escala sobre o Dynamic Type e o .hexFont
    Type/HexWordmark.swift                o logotipo
    Layout/HexLayout.swift                espaçamento, raios e alvo mínimo
    Motion/HexMotion.swift                os movimentos, com e sem Reduzir Movimento
    Motion/HexHaptic.swift                os hápticos do iPhone e do Watch
    Theme/ThemeStore.swift                o tema guardado no aparelho e o modelo da troca ao vivo
    Theme/HexEnvironment.swift            as chaves de ambiente, a paleta do ambiente e os textos por idioma
    Components/                           os nossos (Tasks 5, 6 e 11)
    Branded/                              os da Apple com a marca (Task 7)
    Resources/Fonts/                      a Barlow Condensed e o OFL.txt
    Resources/Strings/en.lproj/, pt-BR.lproj/
  Tests/HexDesignTests/                   um arquivo de testes por assunto, mais Support/Render.swift
apple/HexGym/Gallery/                     a galeria no iPhone (Task 10)
apple/HexGymTests/DynamicTypeTests.swift  o Dynamic Type no simulador (Task 10)
apple/HexGymWatch/Gallery/                a galeria no Watch (Task 11)
apple/HexGymWatch/Localizable.xcstrings   os textos da galeria do Watch (Task 11)
scripts/hexgym/app-icon.swift             o ícone (Task 12), no lugar do placeholder-icon.swift
scripts/hexgym/app-icon.test.mjs
docs/hexgym/design-system/                a documentação pública (Task 9)
docs/hexgym/prints/                       os prints e os vídeos dos PRs, uma pasta por issue
```

Arquivos da fase 0 que mudam aqui: `scripts/hexgym/check.mjs` e `check.test.mjs` (Task 8); `apple/HexGym.xcodeproj/project.pbxproj`, `scripts/hexgym/project-format.test.mjs`, `apple/HexGym/Localizable.xcstrings` e os arquivos do app que mostram o logotipo (Task 10); `apple/HexGymWatch/HexGymWatchApp.swift` (Tasks 10 e 11); os `AppIcon.appiconset` do iPhone e do Watch (Task 12); e o `MARKETING_VERSION` do `project.pbxproj`, na branch da release (Task 13). Saem `apple/Shared/Wordmark.swift` (Task 10) e `scripts/hexgym/placeholder-icon.swift` (Task 12).

## Ordem e dependências

| Task | O que entrega | Depende de |
|---|---|---|
| 1 | O pacote HexDesign e as cores | #19 |
| 2 | A tipografia | 1 |
| 3 | Espaçamento, movimento e háptico | 1 |
| 4 | O tema no aparelho e a troca ao vivo | 1 |
| 5 | O botão principal, o número que rola e as entradas do treino | 2, 3, 4 |
| 6 | Segmentos inclinados, carimbo de recorde, anel de descanso e brilho | 5 |
| 7 | Da Apple, com a marca: o cartão de vidro, os botões secundários e a transição | 2, 3, 4 |
| 8 | O HexDesign na checagem | 1, #20 |
| 9 | A documentação pública | 5, 6, 7 |
| 10 | A galeria no iPhone | 5, 6, 7, 8, 9, #22 |
| 11 | O design system no Watch | 10 |
| 12 | O ícone do app | 1, #21, #22 |
| 13 | A versão 0.2.0 | todas as outras, #25 |

Cada issue leva, no fim das Notas, as duas linhas que o orquestrador lê: `Depende de: #a, #b` (ou `nenhuma`) e `Plano: docs/superpowers/plans/2026-11-03-fase-1-design-system.md, Task N`. A sessão da fase 1 cria as issues depois do merge deste plano, com o modelo Tarefa, as etiquetas `design-system`, a do tipo e `state:todo`, o critério de aceite de cada Task copiado no corpo (o revisor isolado só lê o corpo) e a marca das escolhas recomendadas; cada uma vira sub-issue do épico da fase e entra no Project 6. Nas linhas `Depende de:`, o número da Task vira o da issue. A #31 fecha como substituída por este plano, e o que a Task 16 da fase 0 passar para cá (com `orphan:ok`) vira sub-issue do épico da fase 1.

A #21 e a #22 precisam do Xcode completo, que chega com a #23. Até lá, a onda faz as Tasks 1 a 9; a 10, a 11 e a 12 esperam a #21 e a #22, e a 13 espera a versão 0.1.0 (#25).

Ficam fora desta fase, de propósito: as telas de verdade (fases 2 a 4); o modo claro; os ícones alternativos, um por tema (fase 6, seção 8.12); a transição de "Começar treino" ligada à tela do treino (fase 3; aqui ela aparece na galeria); o tema chegando ao Watch pelo iPhone (fase 4, com a conversa entre os dois; aqui o Watch tem o próprio seletor, na galeria); widgets, Live Activity e complicações com a marca (fases 3, 4 e 6); e as regras de passo da carga e do esforço, que ficam no `lib` do openGym e chegam pelo motor (fase 3).

---

### Task 1: O pacote HexDesign e as cores

**Depende de:** #19, que cria o `xcode.mjs --swift`, o `--swift-test-flags` e o `apple/.gitignore`.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026 (#71):** com alto contraste, o `accent` do Ultravioleta e o do Cobre são #ABA5FF e #F5976C, o primeiro passo de 1% em direção ao branco (a partir de #A29BFF e #F48B5C) que chega a 7 no `cardIncreased`; e o texto na cor do tema fica só no fundo da tela e no cartão, por isso o cinza elevado de uma tela que sobe fica fora das regras (decisão 3).

**Files:**
- Create: `apple/Packages/HexDesign/Package.swift`
- Create: `apple/Packages/HexDesign/Sources/HexDesign/Color/HexRGB.swift`, `Color/HexPalette.swift`
- Create: `apple/Packages/HexDesign/Tests/HexDesignTests/ColorTests.swift`, `Support/Render.swift`
- Create: `docs/hexgym/prints/<issue>/cores.png`

**Interfaces:**
- Consumes: `node scripts/hexgym/xcode.mjs --swift` e `--swift-test-flags` (#19).
- Produces:

```swift
public struct HexRGB: Hashable, Sendable {
  public let hex: UInt32                                     // 0xRRGGBB
  public init(_ hex: UInt32)
  public struct Components: Equatable, Sendable { public let red, green, blue: Double }   // de 0 a 1
  public var srgb: Components
  public var displayP3: Components                           // o mesmo ponto, no espaço Display P3
  public var luminance: Double                               // a luminância relativa da WCAG 2.2
  public func contrast(with other: HexRGB) -> Double         // de 1 a 21, nos dois sentidos
  public static let black: HexRGB, white: HexRGB             // 0x000000 e 0xFFFFFF
  public static let card: HexRGB                             // 0x1C1C1E, o cartão do sistema no escuro, sem alto contraste
  public static let cardIncreased: HexRGB                    // 0x242426, o mesmo cartão com Aumentar Contraste (o systemGray6 acessível do HIG)
}
public struct HexP3: Equatable, Sendable { public let red, green, blue, opacity: Double }   // já em Display P3
public enum HexTheme: String, CaseIterable, Sendable {       // o rawValue é o que fica guardado (Task 4)
  case ultraviolet, chalk, cyan, copper
  public static let standard: HexTheme = .ultraviolet
}
public enum HexSurface: Sendable { case app, watch, island }  // a ilha é a Dynamic Island e a Live Activity
public struct HexPalette: Equatable, Sendable {
  public let accent, fill, onFill, record, onRecord: HexRGB
  public let support: HexRGB?                                // a cor de apoio do brilho; nil no alto contraste
  public let glow: HexP3?                                    // o brilho que respira; nil no claro
  public static func resolve(_ theme: HexTheme, scheme: ColorScheme, contrast: ColorSchemeContrast, surface: HexSurface = .app) -> HexPalette
  public static let error: Color                             // Color.red, o systemRed
}
extension Color {
  public init(_ rgb: HexRGB)                                 // Color(.displayP3, ...) com rgb.displayP3
  public init(_ p3: HexP3)
}
```

- `Support/Render.swift`, para os testes: `image(_:)` desenha uma view com `ImageRenderer`, em escala 1, no esquema escuro e com fundo preto; `width(_:)` e `size(_:)` medem a view com `.fixedSize()`; `printsEnabled` diz se `HEXDESIGN_PRINTS` está no ambiente; `writePrint(_:named:)` grava a view em PNG, em escala 2, na pasta de `HEXDESIGN_PRINTS`. Os testes de print usam `@Test(.enabled(if: printsEnabled))`.

**Como as cores funcionam:**
- `displayP3`: tira a curva do sRGB de cada componente (limiar 0,04045, o da WCAG 2.2), multiplica pela matriz do sRGB linear para o Display P3 linear e põe de volta a mesma curva, que o Display P3 também usa. A matriz: `[[0.8224621, 0.1775380, 0], [0.0331941, 0.9668058, 0], [0.0170827, 0.0723974, 0.9105199]]`. Assim a cor aprovada fica igual na tela, e o P3 vivo aparece só onde foi escolhido (o brilho).
- `luminance` = 0,2126 R + 0,7152 G + 0,0722 B, nos componentes lineares; `contrast` = (L1 + 0,05) / (L2 + 0,05), com L1 o maior dos dois.
- Os valores (a tabela da seção 6, com as decisões de 03/11):

| Tema | accent | accent (alto contraste) | fill / onFill | fill / onFill (alto contraste) | claro | claro (alto contraste) | support | glow (P3; opacidade) |
|---|---|---|---|---|---|---|---|---|
| Ultravioleta | #8B7BFF | #ABA5FF | #6F5CFF / branco | #8A88FF / preto | #5B45E6 | #5339DB | | 0,4221 0,3535 0,9822; 0,85 |
| Giz & Ferro | #F2EFE9 | o mesmo | #F2EFE9 / preto | o mesmo | #1D1D1F | o mesmo | | #8D8A84 convertido, sem P3 vivo; 0,55 |
| Ciano Glacial | #4FD8FF | o mesmo | #4FD8FF / preto | o mesmo | #00739E | #005F84 | #5E6BFF | 0,2302 0,6551 0,8761; 0,8 |
| Cobre Forjado | #F2895A | #F5976C | #F2895A / preto | o mesmo | #B0521F | #973D00 | #8EA4BF | 0,8374 0,3918 0,1830; 0,8 |

- No claro, o `accent` e o `fill` são a coluna "claro" (ou a do alto contraste), e o `onFill` é branco. O recorde é #FFC94D com texto preto no escuro, e #8A6100 no claro (#765200 com alto contraste), com texto branco. `support` é nil com alto contraste, e `glow` é nil no claro. A superfície `.watch` ou `.island` só muda o `accent` do Ultravioleta no escuro sem alto contraste: #9D8CFF (seção 6). Nos outros casos, vale o `accent` do app.
- As regras, que o teste confere em cada tema, com e sem alto contraste (normal / alto contraste). Os fundos do escuro são o preto e o `card`, e com alto contraste também o `cardIncreased`, o cartão que o sistema desenha com Aumentar Contraste:
  - `accent` nos fundos do escuro: 4,5 / 7;
  - `onFill` sobre o `fill`: 4,5 / 7;
  - `fill` contra os fundos do escuro: 3 nos dois (o contorno do botão, a regra de componente da WCAG);
  - no claro, `accent` no branco e branco sobre o `fill`: 4,5 / 7; `fill` contra o branco: 3;
  - recorde contra o fundo (os fundos do escuro, e o branco no claro) e `onRecord` sobre o recorde: 4,5 / 7;
  - o `accent` do Watch e da ilha no preto: 4,5 / 7.
  Alguns pares passam com pouca folga (o `onFill` do Ultravioleta dá 4,52; com alto contraste, no `cardIncreased`, o `accent` do Ultravioleta, #ABA5FF, dá 7,05, e o do Cobre, #F5976C, dá 7,03): quem mudar uma cor vê o teste cair.

- [ ] **Step 1: Write `Package.swift` and the failing tests**

`Package.swift`: `swift-tools-version: 6.2`; nome `HexDesign`; `defaultLocalization: "en"`; as três plataformas das Restrições globais; produto `.library` `HexDesign`; alvo `HexDesign`, ainda sem recursos; alvo de teste `HexDesignTests`. Os dois arquivos de `Color/` entram só com `import SwiftUI`, para o alvo não ficar vazio: sem eles, o `swift test` para em `target 'HexDesign' referenced in product 'HexDesign' is empty`, antes do erro esperado. O `Support/Render.swift` como diz a interface. Os arquivos de teste usam `import Testing`, `import SwiftUI` e `@testable import HexDesign` (as Tasks seguintes testam alguns internos). Em `ColorTests.swift`:

```swift
@Test func contrastFollowsWCAG() {
  #expect(HexRGB.white.contrast(with: .black) == 21)
  #expect(abs(HexRGB(0x8B7BFF).contrast(with: .black) - 6.37) < 0.01)
  #expect(abs(HexRGB(0x6F5CFF).contrast(with: .white) - 4.52) < 0.01)
  #expect(HexRGB(0x6F5CFF).contrast(with: .white) == HexRGB.white.contrast(with: HexRGB(0x6F5CFF)))
}
@Test func displayP3KeepsTheApprovedColor() {
  let cases: [(UInt32, [Double])] = [(0x8B7BFF, [0.5346, 0.4846, 0.9682]), (0xFFC94D, [0.9668, 0.7965, 0.3914]), (0x4FD8FF, [0.4687, 0.8359, 0.9829])]
  for (hex, p3) in cases {
    let c = HexRGB(hex).displayP3
    #expect(zip([c.red, c.green, c.blue], p3).allSatisfy { abs($0 - $1) < 0.0005 }, "\(String(hex, radix: 16))")
  }
}
@Test(arguments: HexTheme.allCases, [false, true])
func everyPairMeetsItsRule(theme: HexTheme, increased: Bool) {
  let text = increased ? 7.0 : 4.5, contrast: ColorSchemeContrast = increased ? .increased : .standard
  let dark = HexPalette.resolve(theme, scheme: .dark, contrast: contrast)
  let light = HexPalette.resolve(theme, scheme: .light, contrast: contrast)
  // No escuro, o fundo da tela e o cartão do sistema; com Aumentar Contraste, o cartão fica #242426.
  let backgrounds: [HexRGB] = increased ? [.black, .card, .cardIncreased] : [.black, .card]
  for background in backgrounds {
    #expect(dark.accent.contrast(with: background) >= text); #expect(dark.fill.contrast(with: background) >= 3)
    #expect(dark.record.contrast(with: background) >= text)
  }
  #expect(dark.onFill.contrast(with: dark.fill) >= text); #expect(dark.onRecord.contrast(with: dark.record) >= text)
  #expect(light.accent.contrast(with: .white) >= text); #expect(light.onFill.contrast(with: light.fill) >= text)
  #expect(light.fill.contrast(with: .white) >= 3); #expect(light.record.contrast(with: .white) >= text)
  #expect(light.onRecord.contrast(with: light.record) >= text)
  for surface in [HexSurface.watch, .island] {
    #expect(HexPalette.resolve(theme, scheme: .dark, contrast: contrast, surface: surface).accent.contrast(with: .black) >= text)
  }
}
@Test func increasedContrastSwapsTheUltravioletButton() {
  let p = HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased)
  #expect(p.fill == HexRGB(0x8A88FF)); #expect(p.onFill == .black); #expect(p.accent == HexRGB(0xABA5FF))
}
@Test func increasedContrastTextClearsTheSystemCard() {  // #71: o texto passa de 7 no cartão do alto contraste
  #expect(HexRGB.cardIncreased == HexRGB(0x242426))
  #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased).accent == HexRGB(0xABA5FF))
  #expect(HexPalette.resolve(.copper, scheme: .dark, contrast: .increased).accent == HexRGB(0xF5976C))
}
@Test func lightUsesTheLightColumnWithAWhiteLabel() {
  let p = HexPalette.resolve(.copper, scheme: .light, contrast: .standard)
  #expect(p.accent == HexRGB(0xB0521F)); #expect(p.fill == HexRGB(0xB0521F)); #expect(p.onFill == .white)
  #expect(p.record == HexRGB(0x8A6100)); #expect(p.glow == nil)
}
@Test func theWatchAndTheIslandUseTheirOwnUltraviolet() {
  for surface in [HexSurface.watch, .island] {
    #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .standard, surface: surface).accent == HexRGB(0x9D8CFF))
    #expect(HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .increased, surface: surface).accent == HexRGB(0xABA5FF))
    #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard, surface: surface).accent == HexRGB(0x4FD8FF))
  }
}
@Test func increasedContrastDropsTheGradientSupport() {
  #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard).support == HexRGB(0x5E6BFF))
  #expect(HexPalette.resolve(.cyan, scheme: .dark, contrast: .increased).support == nil)
}
@Test func chalkHasNoVividGlow() {                       // decisão 3: o Giz fica sem P3 vivo
  let gray = HexRGB(0x8D8A84).displayP3
  #expect(HexPalette.resolve(.chalk, scheme: .dark, contrast: .standard).glow
          == HexP3(red: gray.red, green: gray.green, blue: gray.blue, opacity: 0.55))
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheSwatches() throws { /* cores.png */ }
```

O `printTheSwatches` grava `cores.png`: os quatro temas lado a lado, cada um com `accent` (no escuro, também no cartão do sistema: o `card`, ou o `cardIncreased` com alto contraste), `fill` com o `onFill` escrito, recorde e brilho, no escuro, no escuro com alto contraste e no claro.

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote
Expected: FAIL no build dos testes, com `cannot find '...' in scope` num tipo novo desta Task: o `HexTheme` ou o `HexRGB`, o que o compilador achar primeiro.

- [ ] **Step 3: Implement `HexRGB.swift` and `HexPalette.swift`**

O `glow` do Giz sai de `HexRGB(0x8D8A84).displayP3`, e não de números copiados.

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, 9 testes, e o print pulado.

- [ ] **Step 5: Take the print**

Run: `HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue>` na frente do comando do pacote, com `--filter printTheSwatches`
Expected: `docs/hexgym/prints/<issue>/cores.png`, que vai no PR, em "Para o founder ver".

- [ ] **Step 6: Commit**

```bash
git add apple/Packages/HexDesign docs/hexgym/prints
git commit -m "O pacote HexDesign com as cores dos quatro temas, o alto contraste e o Display P3"
```

---

### Task 2: A tipografia

**Depende de:** 1.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** a escala de texto da tabela abaixo (tamanhos, pesos, tetos e espaçamento entre letras) e o logotipo com `gym` no peso 200.

**Files:**
- Create: `Sources/HexDesign/Type/HexFonts.swift`, `Type/HexTextStyle.swift`, `Type/HexWordmark.swift`
- Create: `Sources/HexDesign/Resources/Fonts/BarlowCondensed-ExtraLight.ttf`, `BarlowCondensed-Medium.ttf`, `BarlowCondensed-Bold.ttf`, `BarlowCondensed-ExtraBold.ttf`, `OFL.txt`
- Modify: `Package.swift` (o alvo `HexDesign` ganha `resources: [.copy("Resources/Fonts")]`; a Task 4 junta as tabelas de texto, e a forma final, com as duas, é `resources: [.copy("Resources/Fonts"), .process("Resources/Strings")]`: das duas, a que entrar depois deixa o arquivo assim)
- Test: `Tests/HexDesignTests/TypeTests.swift`
- Create: `docs/hexgym/prints/<issue>/tipografia.png`, `logotipo.png`

(Os caminhos `Sources/` e `Tests/` desta Task em diante são dentro de `apple/Packages/HexDesign/`.)

**Interfaces:**
- Consumes: o pacote (Task 1).
- Produces:

```swift
public enum HexWeight: Int, CaseIterable, Sendable {
  case extraLight = 200, medium = 500, bold = 700, extraBold = 800
  public var postScriptName: String       // "BarlowCondensed-ExtraLight", "-Medium", "-Bold", "-ExtraBold"
  public var boldText: HexWeight          // um peso acima, com Texto em Negrito: 200→500, 500→700, 700→800, 800→800
  var reserveWeight: CGFloat              // o rawValue do peso do sistema na reserva: thin, medium, bold e heavy
}
public enum HexFonts {
  public static func register()           // idempotente; CTFontManagerRegisterFontURLs, no escopo do processo
  public static func font(_ weight: HexWeight, size: CGFloat, tabularDigits: Bool) -> CTFont
  static var licenseURL: URL?             // o OFL.txt do Bundle.module do HexDesign
}
public enum HexTextStyle: CaseIterable, Sendable {
  case display, number, title, headline, unit, caption
  public var baseSize: CGFloat; public var weight: HexWeight; public var relativeTo: Font.TextStyle
  public var maxSize: CGFloat?; public var tabularDigits: Bool; public var uppercase: Bool; public var tracking: CGFloat
  public func pointSize(scaled: CGFloat) -> CGFloat   // o tamanho do @ScaledMetric, parado no teto
}
extension View { public func hexFont(_ style: HexTextStyle) -> some View }
public struct HexWordmark: View { public init(size: CGFloat = 44) }
```

**Como a tipografia funciona:**
- Os arquivos vêm do commit `60824dce48f7dd28fe7d65559f2da1f6e04e585b` do `google/fonts` (26/02/2026), pasta `ofl/barlowcondensed/`, por `https://raw.githubusercontent.com/google/fonts/60824dce48f7dd28fe7d65559f2da1f6e04e585b/ofl/barlowcondensed/<arquivo>`:

| Arquivo | Bytes | `git hash-object` |
|---|---|---|
| `BarlowCondensed-ExtraLight.ttf` | 101172 | `f9f862c33c697c7b8f87de4ddf42fb0e2b942496` |
| `BarlowCondensed-Medium.ttf` | 103360 | `eee49eb632153608c0bef5809ceab2418dd617a8` |
| `BarlowCondensed-Bold.ttf` | 109912 | `9e480f467d703009e3abfce290b2ec2b7d24e188` |
| `BarlowCondensed-ExtraBold.ttf` | 110296 | `d5a6c7505459f142b20d65d3579e1b840462b75f` |
| `OFL.txt` | 4377 | `2f22ba6ca4dbc12145ae40b14c3368f387cba0e2` |

- `font(_:size:tabularDigits:)` registra as fontes na primeira chamada e guarda as que já criou num cache, porque o `body` chama de novo a cada mudança. O descritor tem o nome PostScript do peso, a lista de cascata com a fonte do sistema no mesmo tamanho, com `reserveWeight` e largura `.compressed` (a SF Pro Compressed; `UIFont` ou `NSFont.systemFont(ofSize:weight:width:)`), e, com `tabularDigits`, o recurso OpenType `tnum` ligado: a Barlow tem dígitos proporcionais por padrão. O cirílico e o grego caem na SF Pro Compressed (sonda de 03/11: `.SFNS-CompressedHeavy` e os outros pesos, largura -0,3); as outras escritas caem na fonte do sistema daquela escrita, pela cascata do próprio CoreText.
- `hexFont(_:)` é um `ViewModifier` com `@ScaledMetric(relativeTo: style.relativeTo)` começando em `baseSize` e com `@Environment(\.legibilityWeight)`: com `.bold`, usa `weight.boldText`. Aplica `Font(HexFonts.font(peso, size: pointSize(scaled:), tabularDigits:))`, o `tracking` e, quando `uppercase`, `textCase(.uppercase)`. O texto corrido não usa `hexFont`: fica nos estilos do sistema (`.body`, `.subheadline` e os outros), na SF Pro.
- A escala:

| Estilo | Tamanho | Peso | Segue | Teto | Dígitos tabulares | Caixa alta | Tracking |
|---|---|---|---|---|---|---|---|
| `display` | 92 | 800 | `.largeTitle` | 132 | sim | | 0 |
| `number` | 48 | 800 | `.title` | 88 | sim | | 0 |
| `title` | 34 | 800 | `.title2` | 60 | | sim | 0 |
| `headline` | 22 | 700 | `.headline` | sem | | sim | 0,4 |
| `unit` | 24 | 700 | `.title3` | 44 | | sim | 0,2 |
| `caption` | 15 | 500 | `.footnote` | sem | sim | sim | 0,6 |

  Os estilos com teto são os de uma linha só, que estouram a tela no AX5; o `headline` e o `caption` quebram linha e crescem sem teto.
- `HexWordmark`: `HEX` no peso 800 e `gym` no 200, do mesmo tamanho, alinhados pela linha de base, com `0,06 × size` entre os dois, brancos, e `accessibilityLabel("HexGym")` num elemento só. O logotipo não segue o Dynamic Type.

- [ ] **Step 1: Bring the font files and check them**

```bash
base=https://raw.githubusercontent.com/google/fonts/60824dce48f7dd28fe7d65559f2da1f6e04e585b/ofl/barlowcondensed
dir=apple/Packages/HexDesign/Sources/HexDesign/Resources/Fonts
mkdir -p "$dir"
for f in BarlowCondensed-ExtraLight.ttf BarlowCondensed-Medium.ttf BarlowCondensed-Bold.ttf BarlowCondensed-ExtraBold.ttf OFL.txt; do curl -fsSL "$base/$f" -o "$dir/$f"; done
```

Run: `git hash-object apple/Packages/HexDesign/Sources/HexDesign/Resources/Fonts/*` e `wc -c` nos mesmos arquivos
Expected: os hashes e os tamanhos da tabela. Um valor diferente para a Task com BLOCKED: o arquivo não é o do commit fixado.

- [ ] **Step 2: Write the failing tests**

Em `TypeTests.swift`, `runs(_:_:)` monta uma `CTLine` com o texto e a fonte e devolve, de cada trecho, o texto, o nome PostScript da fonte, os traços de largura e de peso (`kCTFontWidthTrait`, `kCTFontWeightTrait`) e os glifos (`CTRunGetGlyphs`); `width(_:_:)` é o `CTLineGetTypographicBounds` do texto:

```swift
@Test func registersTheFourWeightsAndShipsTheLicense() throws {
  HexFonts.register(); HexFonts.register()
  for w in HexWeight.allCases {
    #expect(CTFontCopyPostScriptName(CTFontCreateWithName(w.postScriptName as CFString, 20, nil)) as String == w.postScriptName)
  }
  #expect(try String(contentsOf: #require(HexFonts.licenseURL), encoding: .utf8).contains("SIL OPEN FONT LICENSE Version 1.1"))
}
@Test(arguments: HexWeight.allCases)
func cyrillicAndGreekFallBackToSFProCompressed(weight: HexWeight) {      // Foco da revisão 1
  let font = HexFonts.font(weight, size: 40, tabularDigits: false)
  for name in ["ЖИМ ЛЁЖА", "Πιέσεις πάγκου"] {
    for run in runs(name, font) where run.text.contains(where: \.isLetter) {
      #expect(!run.fontName.hasPrefix("BarlowCondensed")); #expect(run.widthTrait < 0)
      #expect(abs(run.weightTrait - weight.reserveWeight) <= 0.15)
    }
  }
  #expect(runs("SUPINO RETO", font).allSatisfy { $0.fontName == weight.postScriptName })
}
@Test func otherScriptsNeverShowAnEmptyBox() {                            // Foco da revisão 1
  let font = HexFonts.font(.bold, size: 40, tabularDigits: false)
  for name in ["ضغط البنش", "卧推", "벤치 프레스", "เบนช์เพรส", "बेंच प्रेस", "বেঞ্চ প্রেস", "Supino 142,5"] {
    #expect(runs(name, font).allSatisfy { !$0.glyphs.contains(0) }, "\(name)")
  }
}
@Test func tabularStylesKeepEveryDigitTheSameWidth() {                    // Foco da revisão 3
  let tabular = HexFonts.font(.extraBold, size: 48, tabularDigits: true)
  let proportional = HexFonts.font(.extraBold, size: 48, tabularDigits: false)
  #expect(abs(width("111,1", tabular) - width("888,8", tabular)) < 0.01)
  #expect(abs(width("1:11:11", tabular) - width("8:88:88", tabular)) < 0.01)
  #expect(abs(width("111,1", proportional) - width("888,8", proportional)) > 1)
}
@Test func boldTextRaisesOneWeight() {                                    // Foco da revisão 2
  #expect(HexWeight.allCases.map(\.boldText) == [.medium, .bold, .extraBold, .extraBold])
}
@Test func oneLineStylesStopAtTheirCap() {                                // Foco da revisão 2
  #expect(HexTextStyle.display.pointSize(scaled: 400) == 132); #expect(HexTextStyle.display.pointSize(scaled: 100) == 100)
  #expect(HexTextStyle.headline.pointSize(scaled: 400) == 400)
}
@Test func theScaleMatchesTheTable() {
  #expect(HexTextStyle.allCases.map(\.baseSize) == [92, 48, 34, 22, 24, 15])
  #expect(HexTextStyle.allCases.map(\.maxSize) == [132, 88, 60, nil, 44, nil])
  #expect(HexTextStyle.allCases.filter(\.tabularDigits) == [.display, .number, .caption])
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheTypeScale() throws { /* tipografia.png e logotipo.png */ }
```

O `printTheTypeScale` grava `tipografia.png`, com cada estilo escrito em português ("SUPINO RETO", "142,5", "KG", "SÉRIE 3 DE 5") e uma linha com "ЖИМ ЛЁЖА", "Πιέσεις πάγκου" e "卧推" no `title`, e `logotipo.png`, com o `HexWordmark` em 44 e em 88.

- [ ] **Step 3: Run them to verify they fail**

Run: o comando do pacote, com `--filter TypeTests`
Expected: FAIL no build dos testes, com `cannot find '...' in scope` num tipo novo desta Task: o `HexWeight` ou o `HexFonts`, o que o compilador achar primeiro.

- [ ] **Step 4: Implement `HexFonts`, `HexTextStyle` and `HexWordmark`, and add the fonts to `Package.swift`**

- [ ] **Step 5: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 7 testes novos, e os prints pulados.

- [ ] **Step 6: Take the prints**

Run: `HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue>` na frente do comando do pacote, com `--filter printTheTypeScale`
Expected: `tipografia.png` e `logotipo.png`, no PR.

- [ ] **Step 7: Commit**

```bash
git add apple/Packages/HexDesign docs/hexgym/prints
git commit -m "A tipografia do HexDesign: a Barlow Condensed, a reserva na SF Pro Compressed e a escala sobre o Dynamic Type"
```

---

### Task 3: Espaçamento, movimento e háptico

**Depende de:** 1.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** os espaços e os raios, a tabela de movimentos e a de hápticos abaixo.

**Files:**
- Create: `Sources/HexDesign/Layout/HexLayout.swift`, `Motion/HexMotion.swift`, `Motion/HexHaptic.swift`
- Test: `Tests/HexDesignTests/MotionTests.swift`

**Interfaces:**
- Consumes: o pacote (Task 1).
- Produces:

```swift
public enum HexSpacing { public static let xxs: CGFloat = 4, xs: CGFloat = 8, s: CGFloat = 12, m: CGFloat = 16, l: CGFloat = 24, xl: CGFloat = 32, xxl: CGFloat = 48 }
public enum HexRadius { public static let chip: CGFloat = 10, button: CGFloat = 18, card: CGFloat = 28 }
public enum HexTarget { public static let minimum: CGFloat = 44 }

public struct MotionSpec: Equatable, Sendable {
  public enum Curve: Equatable, Sendable { case spring(duration: Double, bounce: Double), easeInOut(duration: Double) }
  public let curve: Curve?            // nil: sem animação
  public let allowsMovement: Bool     // false: só opacidade, nada muda de lugar nem de tamanho
  public let repeats: Bool
}
public enum HexMotion: CaseIterable, Sendable {
  case tap, change, enter, celebrate, breathe
  public func spec(reduceMotion: Bool) -> MotionSpec
  public func animation(reduceMotion: Bool) -> Animation?   // a curva do spec; o breathe repete com autoreverses
}
public enum HexBreathing { public static let scale: ClosedRange<CGFloat> = 0.95...1.05; public static let period: Double = 4 }

public enum HexPlatform: Sendable { case phone, watch; public static var current: HexPlatform }   // .watch só no watchOS
public enum HexFeedback: Equatable, Sendable {      // a tabela num tipo nosso, que guarda o peso do impacto
  case selection, success, warning, error, increase, decrease, start
  case impact(weight: Weight, intensity: Double)
  public enum Weight: Equatable, Sendable { case light, medium, heavy }
}
public enum HexHaptic: CaseIterable, Sendable {
  case increase, decrease, setLogged, record, restDone, error
  public func kind(on platform: HexPlatform = .current) -> HexFeedback          // a tabela
  public func feedback(on platform: HexPlatform = .current) -> SensoryFeedback  // só traduz o kind, para o .sensoryFeedback das views
}
```

**Os valores:**

| Movimento | Normal | Com Reduzir Movimento |
|---|---|---|
| `tap` | `spring` 0,25 s, `bounce` 0 | `easeInOut` 0,15 s, só opacidade |
| `change` | `spring` 0,35 s, `bounce` 0,1 | `easeInOut` 0,2 s, só opacidade |
| `enter` | `spring` 0,5 s, `bounce` 0,15 | `easeInOut` 0,25 s, só opacidade |
| `celebrate` | `spring` 0,6 s, `bounce` 0,35 | `easeInOut` 0,3 s, só opacidade |
| `breathe` | `easeInOut` 2 s, repetindo ida e volta (o ciclo de 4 s de `HexBreathing`) | nenhuma |

| Háptico | iPhone | Watch |
|---|---|---|
| `increase` | `.selection` | `.increase` |
| `decrease` | `.selection` | `.decrease` |
| `setLogged` | `.success` | `.success` |
| `record` | `.impact(weight: .heavy, intensity: 1)` | o mesmo |
| `restDone` | `.warning` | `.start` |
| `error` | `.error` | `.error` |

A documentação da Apple diz que `.increase` e `.decrease` só tocam no watchOS e no visionOS, e `.start` só no watchOS: por isso o iPhone usa outros. No Mac, o `SensoryFeedback` não guarda o peso do impacto (`.impact(weight: .heavy, intensity: 1) == .impact(weight: .light, intensity: 1)` dá verdadeiro, sonda de 03/11), então a tabela mora no `HexFeedback`, que guarda, e o teste confere o `kind`; o `feedback(on:)` só traduz.

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter MotionTests`
Expected: FAIL, `cannot find 'HexMotion' in scope`.

- [ ] **Step 3: Implement `HexLayout`, `HexMotion` and `HexHaptic`**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 4 testes novos.

- [ ] **Step 5: Commit**

```bash
git add apple/Packages/HexDesign
git commit -m "Espaçamento, movimento e háptico do HexDesign, com Reduzir Movimento"
```

---

### Task 4: O tema no aparelho e a troca ao vivo

**Depende de:** 1.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** os nomes dos temas em inglês (Ultraviolet, Chalk & Iron, Glacial Cyan, Forged Copper).

**Files:**
- Create: `Sources/HexDesign/Theme/ThemeStore.swift`, `Theme/HexEnvironment.swift`
- Create: `Sources/HexDesign/Resources/Strings/en.lproj/Theme.strings`, `Sources/HexDesign/Resources/Strings/pt-BR.lproj/Theme.strings`
- Modify: `Package.swift` (os recursos do alvo ganham `.process("Resources/Strings")`; com a Task 2, a forma final é `resources: [.copy("Resources/Fonts"), .process("Resources/Strings")]`: das duas, a que entrar depois deixa o arquivo assim)
- Test: `Tests/HexDesignTests/ThemeTests.swift`, `Tests/HexDesignTests/Support/Locales.swift`

**Interfaces:**
- Consumes: `HexTheme`, `HexPalette.resolve` e `HexSurface` (Task 1).
- Produces:

```swift
public struct ThemeStore {
  public static let key = "hexgym.theme"
  public static let appGroup = "group.app.hexgym"
  public init(defaults: UserDefaults)
  public static func appGroupStore() -> ThemeStore   // os UserDefaults do App Group; sem eles, os padrão
  public func load() -> HexTheme                     // .standard quando falta ou quando não reconhece o valor
  public func save(_ theme: HexTheme)                // grava o rawValue
}
@Observable @MainActor public final class ThemeModel {
  public var theme: HexTheme                         // ao mudar, grava no store
  public var contrastPreview: Bool                   // a prévia de alto contraste da galeria; não é gravada
  public init(store: ThemeStore)
}
extension HexTheme { public func displayName(locale: Locale = .current) -> String }
extension EnvironmentValues {
  public var hexTheme: HexTheme { get set }
  public var hexContrastPreview: Bool { get set }
  public var hexPalette: HexPalette { get }          // a paleta do ambiente
}
extension View { public func hexTheme(_ model: ThemeModel) -> some View }   // põe o tema e a prévia no ambiente
enum HexStrings {                                    // interno: os textos do pacote no idioma pedido
  static func text(_ key: String, table: String, locale: Locale) -> String
  static func format(_ key: String, table: String, locale: Locale, _ arguments: CVarArg...) -> String
}
```

- `hexPalette` = `HexPalette.resolve(hexTheme, scheme: colorScheme, contrast:, surface:)`, com `contrast` `.increased` quando `colorSchemeContrast == .increased` ou `hexContrastPreview`, e `surface` `.watch` no watchOS e `.app` no resto. As chaves de ambiente são `EnvironmentKey` escritas à mão, com o padrão `.standard` e `false` (sem `@Entry`, Restrições globais).
- `HexStrings` lê a tabela do `.lproj` do idioma pedido dentro do `Bundle.module` do HexDesign: português (de qualquer região) lê `pt-BR.lproj`, e o resto lê `en.lproj`. As views passam o `@Environment(\.locale)`, e os testes passam o idioma que querem. Os plurais vêm do `.stringsdict` da mesma tabela. As Tasks 5 e 6 usam os dois.
- `Theme.strings`:

| Chave | pt-BR | en |
|---|---|---|
| `ultraviolet` | Ultravioleta | Ultraviolet |
| `chalk` | Giz & Ferro | Chalk & Iron |
| `cyan` | Ciano Glacial | Glacial Cyan |
| `copper` | Cobre Forjado | Forged Copper |

- [ ] **Step 1: Write the failing tests**

Cada teste usa um `UserDefaults(suiteName: "hexdesign-<UUID>")` só dele, apagado no fim com `removePersistentDomain(forName:)`; `fresh()` cria um. `br` e `en` ficam em `Support/Locales.swift`, para as Tasks 5 e 6 usarem também: `let br = Locale(identifier: "pt-BR")` e `let en = Locale(identifier: "en_US")`:

```swift
@Test func aFreshDeviceStartsOnUltraviolet() { #expect(ThemeStore(defaults: fresh()).load() == .ultraviolet) }
@Test func aSavedThemeComesBack() {
  let d = fresh(); ThemeStore(defaults: d).save(.copper)
  #expect(ThemeStore(defaults: d).load() == .copper); #expect(d.string(forKey: ThemeStore.key) == "copper")
}
@Test func anUnknownOrBrokenValueFallsBackToUltraviolet() {
  let d = fresh()
  d.set("aurora", forKey: ThemeStore.key); #expect(ThemeStore(defaults: d).load() == .ultraviolet)
  d.set(42, forKey: ThemeStore.key); #expect(ThemeStore(defaults: d).load() == .ultraviolet)
}
@MainActor @Test func changingTheModelSavesAndKeepsThePreviewOut() {
  let d = fresh(), model = ThemeModel(store: ThemeStore(defaults: d))
  model.theme = .cyan; model.contrastPreview = true
  #expect(d.string(forKey: ThemeStore.key) == "cyan")
  #expect(d.dictionaryRepresentation().keys.filter { $0.hasPrefix("hexgym.") } == ["hexgym.theme"])
}
@Test func thePaletteFollowsTheEnvironment() {                            // Foco da revisão 4
  var env = EnvironmentValues(); env.colorScheme = .dark; env.hexTheme = .ultraviolet
  #expect(env.hexPalette.fill == HexRGB(0x6F5CFF))
  env.hexContrastPreview = true; #expect(env.hexPalette.fill == HexRGB(0x8A88FF))
  env.colorScheme = .light; #expect(env.hexPalette.fill == HexRGB(0x5339DB))
}
@Test func themeNamesInBothLanguages() {
  #expect(HexTheme.allCases.map { $0.displayName(locale: br) } == ["Ultravioleta", "Giz & Ferro", "Ciano Glacial", "Cobre Forjado"])
  #expect(HexTheme.allCases.map { $0.displayName(locale: en) } == ["Ultraviolet", "Chalk & Iron", "Glacial Cyan", "Forged Copper"])
}
```

O `colorSchemeContrast` do ambiente é só de leitura e não dá para mudar no teste: o caminho dele fica para a galeria, no simulador (Task 10), e a prévia prova a mesma troca.

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter ThemeTests`
Expected: FAIL, `cannot find 'ThemeStore' in scope`.

- [ ] **Step 3: Implement the store, the model, the environment, `HexStrings` and the strings**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 6 testes novos.

- [ ] **Step 5: Commit**

```bash
git add apple/Packages/HexDesign
git commit -m "O tema do HexDesign: a escolha guardada no aparelho e a troca ao vivo"
```

---

### Task 5: O botão principal, o número que rola e as entradas do treino

**Depende de:** 2, 3 e 4.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** o botão principal (alturas, raio, o aperto e o desligado) e as entradas do treino (botões − e + de 56 pt, o valor no estilo `number`, a unidade no `unit`, e empilhadas nos tamanhos de acessibilidade).

**Files:**
- Create: `Sources/HexDesign/Components/HexPrimaryButton.swift`, `Components/RollingNumber.swift`, `Components/WorkoutInput.swift`, `Components/WorkoutFormat.swift`
- Create: `Workout.strings` e `Workout.stringsdict`, em `Sources/HexDesign/Resources/Strings/en.lproj/` e em `pt-BR.lproj/`
- Test: `Tests/HexDesignTests/WorkoutInputTests.swift`, `Tests/HexDesignTests/PrimaryButtonTests.swift`
- Create: `docs/hexgym/prints/<issue>/botao-principal.png`, `entradas.png`

**Interfaces:**
- Consumes: `hexFont` e `HexTextStyle` (Task 2); `HexMotion`, `HexHaptic`, `HexRadius` e `HexTarget` (Task 3); `hexPalette` e `HexStrings` (Task 4).
- Produces:

```swift
public struct HexPrimaryButtonStyle: ButtonStyle {
  public enum Size: Sendable { case regular, large; public var minHeight: CGFloat }   // 56 e 72
  public init(size: Size = .regular)
  nonisolated public static func pressedEffect(reduceMotion: Bool) -> PressedEffect
}
public struct PressedEffect: Equatable, Sendable { public let scale: CGFloat; public let opacity: Double }
extension ButtonStyle where Self == HexPrimaryButtonStyle {
  public static var hexPrimary: HexPrimaryButtonStyle { get }
  public static func hexPrimary(size: HexPrimaryButtonStyle.Size) -> HexPrimaryButtonStyle
}
public struct RollingNumber: View {
  public init(value: Double, text: String, style: HexTextStyle = .number)   // value dá o sentido da rolagem; text é o que aparece
  nonisolated public static func transition(for value: Double, reduceMotion: Bool) -> ContentTransition
}
public enum WeightUnit: String, Sendable { case kg, lb }
public enum EffortScale: String, Sendable { case rpe, rir }
public enum StepDirection: Sendable { case down, up }
public enum WorkoutFormat {
  public static func load(_ value: Double, locale: Locale = .current) -> String
  public static func effort(_ value: Double?, locale: Locale = .current) -> String
  public static func spokenLoad(_ value: Double, unit: WeightUnit, locale: Locale = .current) -> String
  public static func spokenReps(_ count: Int, locale: Locale = .current) -> String
  public static func spokenEffort(_ value: Double?, scale: EffortScale, locale: Locale = .current) -> String
}
public struct LoadInput: View { public init(value: Double, unit: WeightUnit, onStep: @escaping (StepDirection) -> Void) }
public struct RepsInput: View { public init(value: Int, onStep: @escaping (StepDirection) -> Void) }
public struct EffortInput: View { public init(value: Double?, scale: EffortScale, onStep: @escaping (StepDirection) -> Void) }
public enum WorkoutInputLayout { public static func axis(for size: DynamicTypeSize) -> Axis }   // .vertical nos de acessibilidade
```

As funções estáticas dos tipos que são `View` ou `ButtonStyle` levam `nonisolated`: esses protocolos põem o tipo no ator principal, e os testes que chamam essas funções não rodam nele (sem o `nonisolated`, o build dá o aviso "call to main actor-isolated static method"). O mesmo vale na Task 6.

**Como funcionam:**
- **Botão principal:** largura toda, altura mínima do `Size` (as duas passam de `HexTarget.minimum`), raio `HexRadius.button` contínuo, fundo `fill` e rótulo `onFill` da paleta do ambiente, rótulo em `headline` (`.regular`) ou `title` (`.large`). Apertado: escala 0,97 com o movimento `tap`, ou só opacidade 0,8 com Reduzir Movimento (`pressedEffect`). Desligado (`isEnabled` falso): opacidade 0,4. O alto contraste já vem pela paleta: no Ultravioleta, #8A88FF com rótulo preto.
- **Número que rola:** `Text(text)` no estilo, com `contentTransition(transition(for:reduceMotion:))` e `.animation(HexMotion.change.animation(reduceMotion:), value:)`. A transição é `.numericText(value:)`, ou `.opacity` com Reduzir Movimento. Ela é a da Apple, com a nossa tipografia (decisão 2).
- **Formatos:** `load` tem de 0 a 2 casas e não agrupa milhar (`FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).grouping(.never)` no idioma); `effort` é vazio para `nil`; `spokenLoad` é o `Measurement` em quilogramas ou libras, com a largura `.wide`, o uso `.asProvided` e o mesmo formato de número; `spokenReps` vem do `.stringsdict`; `spokenEffort` é `RPE` ou `RIR` com o número, e "Esforço não registrado" para `nil`. A carga nunca é arredondada para a grade: mostra o que foi registrado (Foco da revisão 5).
- **Entradas do treino:** o rótulo do campo em `caption`, o valor num `RollingNumber` em `number` e a unidade em `unit` (`kg` ou `lb`, `RPE` ou `RIR`); os botões − e + têm 56 pt, o raio `HexRadius.chip`, os símbolos `minus` e `plus`, e o háptico `decrease` ou `increase` a cada toque. Com `WorkoutInputLayout.axis` vertical, os botões descem para baixo do valor. Para o VoiceOver, o valor é um elemento ajustável, com o rótulo do campo, o valor falado (`spokenLoad`, `spokenReps` ou `spokenEffort`) e `accessibilityAdjustableAction`, que chama `onStep`; os botões continuam elementos próprios, "Diminuir" e "Aumentar", para quem usa Controle por Voz. O esforço vazio mostra só a unidade. As entradas não decidem o passo: quem usa a entrada aplica `addStep` ou `stepEffort` pelo motor e passa o valor novo.
- `Workout.strings` e `Workout.stringsdict`:

| Chave | pt-BR | en |
|---|---|---|
| `load` | Carga | Load |
| `reps` | Repetições | Reps |
| `effort` | Esforço | Effort |
| `effort.empty` | Esforço não registrado | Effort not logged |
| `decrease` | Diminuir | Decrease |
| `increase` | Aumentar | Increase |
| `%lld reps` (plural) | %lld repetição / %lld repetições | %lld repetition / %lld repetitions |

- [ ] **Step 1: Write the failing tests**

Em `WorkoutInputTests.swift`, com o `br` e o `en` de `Support/Locales.swift` (Task 4):

```swift
@Test func loadsShowWhatWasLogged() {                                     // Foco da revisão 5
  #expect([141.3, 141.25, 142.5, 100, 1000, 2000, 141.333].map { WorkoutFormat.load($0, locale: br) }
          == ["141,3", "141,25", "142,5", "100", "1000", "2000", "141,33"])
  #expect(WorkoutFormat.load(142.5, locale: en) == "142.5")
}
@Test func voiceOverSaysTheUnit() {                                       // Foco da revisão 5
  #expect(WorkoutFormat.spokenLoad(142.5, unit: .kg, locale: br) == "142,5 quilogramas")
  #expect(WorkoutFormat.spokenLoad(317.5, unit: .lb, locale: br) == "317,5 libras")
  #expect(WorkoutFormat.spokenLoad(317.5, unit: .lb, locale: en) == "317.5 pounds")
  #expect(WorkoutFormat.spokenLoad(1, unit: .kg, locale: en) == "1 kilogram")
  #expect([1, 8].map { WorkoutFormat.spokenReps($0, locale: br) } == ["1 repetição", "8 repetições"])
  #expect([1, 8].map { WorkoutFormat.spokenReps($0, locale: en) } == ["1 repetition", "8 repetitions"])
  #expect(WorkoutFormat.spokenEffort(8.5, scale: .rpe, locale: br) == "RPE 8,5")
  #expect(WorkoutFormat.spokenEffort(2, scale: .rir, locale: en) == "RIR 2")
  #expect(WorkoutFormat.spokenEffort(nil, scale: .rpe, locale: br) == "Esforço não registrado")
}
@Test func anEmptyEffortShowsNothing() {
  #expect(WorkoutFormat.effort(nil, locale: br) == ""); #expect(WorkoutFormat.effort(8.5, locale: br) == "8,5")
  #expect(WorkoutFormat.effort(8, locale: br) == "8")
}
@Test func accessibilitySizesStack() {                                    // Foco da revisão 2
  #expect(WorkoutInputLayout.axis(for: .xxxLarge) == .horizontal)
  for size in [DynamicTypeSize.accessibility1, .accessibility5] { #expect(WorkoutInputLayout.axis(for: size) == .vertical) }
}
@MainActor @Test func bigLoadsKeepTheirWidth() {                          // Foco da revisão 3
  #expect(width(LoadInput(value: 1000, unit: .kg) { _ in }) == width(LoadInput(value: 1111, unit: .kg) { _ in }))
}
@Test func rollingNumbersRollUnlessReduceMotion() {                       // Foco da revisão 4
  #expect(RollingNumber.transition(for: 5, reduceMotion: false) == .numericText(value: 5))
  #expect(RollingNumber.transition(for: 5, reduceMotion: true) == .opacity)
}
```

Em `PrimaryButtonTests.swift`:

```swift
@Test func thePrimaryButtonOnlyFadesWithReduceMotion() {                  // Foco da revisão 4
  #expect(HexPrimaryButtonStyle.pressedEffect(reduceMotion: false) == PressedEffect(scale: 0.97, opacity: 1))
  #expect(HexPrimaryButtonStyle.pressedEffect(reduceMotion: true) == PressedEffect(scale: 1, opacity: 0.8))
}
@Test func thePrimaryButtonHasRoomForAThumb() {
  #expect(HexPrimaryButtonStyle.Size.regular.minHeight == 56); #expect(HexPrimaryButtonStyle.Size.large.minHeight == 72)
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheButtonAndTheInputs() throws { /* botao-principal.png e entradas.png */ }
```

O print grava `botao-principal.png` (os quatro temas, normal, com alto contraste e desligado, em `.regular` e `.large`) e `entradas.png` (141,3 kg; 1000 kg; 317,5 lb; 8 repetições; o esforço vazio e com 8,5).

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter "WorkoutInputTests|PrimaryButtonTests"`
Expected: FAIL no build dos testes, com `cannot find '...' in scope` num tipo novo desta Task: o `WorkoutFormat`, o `HexPrimaryButtonStyle` ou o `PressedEffect`, conforme o arquivo de teste que o compilador ler primeiro.

- [ ] **Step 3: Implement the button, the rolling number, the formats, the inputs and the strings**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 8 testes novos.

- [ ] **Step 5: Take the prints**

Run: `HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue>` na frente do comando do pacote, com `--filter printTheButtonAndTheInputs`
Expected: `botao-principal.png` e `entradas.png`, no PR.

- [ ] **Step 6: Commit**

```bash
git add apple/Packages/HexDesign docs/hexgym/prints
git commit -m "O botão principal, o número que rola e as entradas de carga, repetições e esforço"
```

---

### Task 6: Segmentos inclinados, carimbo de recorde, anel de descanso e brilho

**Depende de:** 5.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** a inclinação de 18° nos segmentos; o carimbo dourado em contorno, girado 8° (sobe para a direita) e caindo de 1,4 vez o tamanho; o anel de descanso em 60 traços inclinados, sem pontas redondas, na cor do tema; o brilho com a metade da força no alto contraste, apagado com Reduzir Transparência e parado no Watch.

**Files:**
- Create: `Sources/HexDesign/Components/SlantedSegments.swift`, `Components/RecordStamp.swift`, `Components/RestRing.swift`, `Components/BreathingGlow.swift`
- Create: `Progress.strings` e `Progress.stringsdict`, em `en.lproj/` e `pt-BR.lproj/`
- Modify: `Tests/HexDesignTests/Support/Render.swift` (ganha `brightness(_:)`)
- Test: `Tests/HexDesignTests/ProgressTests.swift`, `Tests/HexDesignTests/GlowTests.swift`
- Create: `docs/hexgym/prints/<issue>/segmentos.png`, `carimbo.png`, `anel.png`, `brilho.png`

**Interfaces:**
- Consumes: `RollingNumber` (Task 5); `hexFont` (Task 2); `HexMotion`, `HexBreathing`, `HexHaptic`, `HexSpacing` e `HexRadius` (Task 3); `hexPalette`, `HexStrings` e `HexSurface` (Tasks 1 e 4).
- Produces:

```swift
public struct SlantedSegments: View {
  public init(total: Int, done: Int)
  nonisolated public static func spokenValue(total: Int, done: Int, locale: Locale = .current) -> String
}
public struct RecordStamp: View {
  public init(isShown: Bool)
  nonisolated public static func startScale(reduceMotion: Bool) -> CGFloat
}
public struct RestRing: View { public init(total: Int, remaining: Int) }    // em segundos
public enum RestRingModel {
  public static let ticks = 60
  public static func litTicks(total: Int, remaining: Int) -> Int
  public static func time(_ seconds: Int) -> String
  public static func spokenTime(_ seconds: Int, locale: Locale = .current) -> String
}
public struct BreathingGlow: View { public init() }                        // o fundo preto com o brilho do tema
public struct GlowSpec: Equatable, Sendable {
  public let color: HexP3                                                  // com a opacidade já resolvida
  public let support: HexRGB?
  public let breathes: Bool
  public static func resolve(palette: HexPalette, contrast: ColorSchemeContrast, reduceTransparency: Bool, reduceMotion: Bool, surface: HexSurface = .app) -> GlowSpec?
}
```

- `brightness(_:)`, no `Render.swift`: a média de luz do quinto da esquerda e do quinto da direita da imagem da view, `(left: Double, right: Double)`.

**Como funcionam:**
- **Segmentos:** `total` paralelogramos numa linha, inclinados 18° (o alto puxa para a direita), com `HexSpacing.xxs` entre eles. Os feitos ficam no `accent`, o seguinte (o da série atual) no `accent` com opacidade 0,35, e os outros em `.tertiary`. Da direita para a esquerda, a ordem e a inclinação viram (`flipsForRightToLeftLayoutDirection`). Para o VoiceOver, um elemento só: rótulo "Séries", valor `spokenValue`, com o plural no `.stringsdict`.
- **Carimbo:** "Recorde" no estilo `title` (caixa alta), no ouro do `record`, com contorno de 3 pt em `HexRadius.chip`, girado -8° (sobe para a direita, como os segmentos). Quando `isShown` passa a verdadeiro: entra com `celebrate` de `startScale` para 1 e de opacidade 0 para 1, ou só a opacidade com Reduzir Movimento; toca o háptico `record`; e anuncia "Novo recorde" no VoiceOver (`AccessibilityNotification.Announcement`).
- **Anel de descanso:** 60 traços curtos em volta de um círculo, cada um inclinado 18° em relação ao raio, sem pontas redondas; os acesos no `accent`, os outros em `.tertiary`. Assim ele não parece um anel de atividade da Apple (seção 6), que é uma faixa contínua com pontas redondas. No centro, `RollingNumber(value: Double(remaining), text: RestRingModel.time(remaining))` em `number`, com `minimumScaleFactor(0.5)` para caber no anel sem cortar. O diâmetro segue o Dynamic Type (`@ScaledMetric`, 220 pt em `.large`) e nunca passa da largura disponível. Quando `remaining` chega a zero, toca o háptico `restDone`. Para o VoiceOver: rótulo "Descanso", valor `spokenTime` e o traço `.updatesFrequently`.
- `litTicks` = `round(60 × remaining / total)`, entre 0 e 60, e 0 com `total` zero. `time` é `m:ss` abaixo de uma hora e `h:mm:ss` a partir dela; negativo dá `0:00`. `spokenTime` é `Duration.seconds(s).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))` no idioma.
- **Brilho:** um gradiente radial na cor do `glow` (P3), da opacidade resolvida até zero, passando pelo `support` quando há, com 60% da largura, no alto da tela, atrás de tudo, respirando entre `HexBreathing.scale` com o movimento `breathe`. `GlowSpec.resolve` é nil quando a paleta não tem brilho (o claro) ou com Reduzir Transparência; com alto contraste, a opacidade cai para a metade; com Reduzir Movimento, ou na superfície `.watch`, ele não respira.
- `Progress.strings` e `Progress.stringsdict`:

| Chave | pt-BR | en |
|---|---|---|
| `sets` | Séries | Sets |
| `%lld of %lld sets` (plural no segundo número) | %1$lld de %2$lld série / séries | %1$lld of %2$lld set / sets |
| `record` | Recorde | Record |
| `record.new` | Novo recorde | New record |
| `rest` | Descanso | Rest |

- [ ] **Step 1: Write the failing tests**

Em `ProgressTests.swift`, com o `br` e o `en` de `Support/Locales.swift` (Task 4):

```swift
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
```

Em `GlowTests.swift`:

```swift
@Test func theGlowFollowsAccessibility() {                                // Foco da revisão 4
  let uv = HexPalette.resolve(.ultraviolet, scheme: .dark, contrast: .standard)
  func glow(_ contrast: ColorSchemeContrast, transparency: Bool, motion: Bool) -> GlowSpec? {
    GlowSpec.resolve(palette: uv, contrast: contrast, reduceTransparency: transparency, reduceMotion: motion)
  }
  #expect(glow(.standard, transparency: false, motion: false)?.color.opacity == 0.85)
  #expect(glow(.standard, transparency: false, motion: false)?.breathes == true)
  #expect(glow(.increased, transparency: false, motion: false)?.color.opacity == 0.425)
  #expect(glow(.standard, transparency: false, motion: true)?.breathes == false)
  #expect(glow(.standard, transparency: true, motion: false) == nil)
  #expect(glow(.increased, transparency: true, motion: true) == nil)
}
@Test func noGlowOnLightAndAStillGlowOnTheWatch() {
  let light = HexPalette.resolve(.cyan, scheme: .light, contrast: .standard)
  #expect(GlowSpec.resolve(palette: light, contrast: .standard, reduceTransparency: false, reduceMotion: false) == nil)
  let cyan = HexPalette.resolve(.cyan, scheme: .dark, contrast: .standard)
  #expect(GlowSpec.resolve(palette: cyan, contrast: .standard, reduceTransparency: false, reduceMotion: false, surface: .watch)?.breathes == false)
}
@MainActor @Test(.enabled(if: printsEnabled)) func printTheProgressPieces() throws { /* segmentos, carimbo, anel e brilho */ }
```

O print grava `segmentos.png` (0, 3 e 5 de 5, e 1 de 5 da direita para a esquerda), `carimbo.png`, `anel.png` (1:30 e 1:00:00) e `brilho.png` (os quatro temas, com e sem alto contraste).

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter "ProgressTests|GlowTests"`
Expected: FAIL no build dos testes, com `cannot find '...' in scope` num tipo novo desta Task: o `SlantedSegments` ou o `GlowSpec`, conforme o arquivo de teste que o compilador ler primeiro.

- [ ] **Step 3: Implement the four components, `brightness` and the strings**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 9 testes novos.

- [ ] **Step 5: Take the prints**

Run: `HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue>` na frente do comando do pacote, com `--filter printTheProgressPieces`
Expected: os quatro PNGs, no PR.

- [ ] **Step 6: Commit**

```bash
git add apple/Packages/HexDesign docs/hexgym/prints
git commit -m "Segmentos inclinados, carimbo de recorde, anel de descanso e o brilho que respira"
```

---

### Task 7: Da Apple, com a marca: o cartão de vidro, os botões secundários e a transição

**Depende de:** 2, 3 e 4.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** o vidro tingido com o `accent` a 18%, sem tinta no alto contraste; e, com Reduzir Movimento, a tela do treino entrando sem animação, no lugar do zoom.

**Files:**
- Create: `Sources/HexDesign/Branded/HexGlassCard.swift`, `Branded/SecondaryButton.swift`, `Branded/StartWorkoutTransition.swift`
- Test: `Tests/HexDesignTests/BrandedTests.swift`

**Interfaces:**
- Consumes: `hexPalette` (Task 4); `HexRadius` e `HexSpacing` (Task 3); `hexFont` (Task 2).
- Produces:

```swift
public struct HexGlassCard<Content: View>: View { public init(@ViewBuilder content: () -> Content) }
public enum HexGlass { public static func tintOpacity(contrast: ColorSchemeContrast) -> Double? }   // 0,18; nil com alto contraste
extension View {
  public func hexSecondaryButton() -> some View
  public func hexStartWorkoutSource(id: some Hashable, in namespace: Namespace.ID) -> some View
  public func hexStartWorkoutDestination(id: some Hashable, in namespace: Namespace.ID) -> some View
}
public enum StartWorkoutTransition {
  public static func usesZoom(reduceMotion: Bool) -> Bool
  public static func transaction(reduceMotion: Bool) -> Transaction   // para abrir a tela do treino
}
```

**Como funcionam:** são componentes da Apple, com o comportamento dela, e o HexGym só põe a cor, a tipografia e a composição (decisão 2).
- `HexGlassCard`: o conteúdo com `HexSpacing.m` de margem e `glassEffect(.regular.tint(...), in: RoundedRectangle(cornerRadius: HexRadius.card, style: .continuous))`, com a tinta no `accent` e na opacidade de `tintOpacity`, ou `.regular` sem tinta quando ela é nil. Com Reduzir Transparência, o sistema já deixa o vidro opaco.
- `hexSecondaryButton()`: `.buttonStyle(.glass)` com `.tint` no `accent` do tema.
- A transição: a origem usa `matchedTransitionSource(id:in:)`; o destino usa `navigationTransition(.zoom(sourceID:in:))` só quando `usesZoom` (que é falso com Reduzir Movimento), e só fora do macOS (`#if !os(macOS)`), onde o zoom não existe. Quem abre a tela do treino o faz dentro de `withTransaction(transaction(reduceMotion:))`: com Reduzir Movimento, a transação tem `disablesAnimations`, e a tela aparece sem se mover. A tela do treino de verdade é da fase 3; aqui a transição aparece na galeria (Task 10).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func theGlassTakesTheThemeUnlessContrastIsUp() {                    // Foco da revisão 4
  #expect(HexGlass.tintOpacity(contrast: .standard) == 0.18); #expect(HexGlass.tintOpacity(contrast: .increased) == nil)
}
@Test func theZoomStepsAsideForReduceMotion() {                           // Foco da revisão 4
  #expect(StartWorkoutTransition.usesZoom(reduceMotion: false)); #expect(!StartWorkoutTransition.usesZoom(reduceMotion: true))
}
@Test func theWorkoutScreenAppearsStillWithReduceMotion() {
  #expect(StartWorkoutTransition.transaction(reduceMotion: true).disablesAnimations)
  #expect(!StartWorkoutTransition.transaction(reduceMotion: false).disablesAnimations)
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter BrandedTests`
Expected: FAIL, `cannot find 'HexGlass' in scope`.

- [ ] **Step 3: Implement the card, the secondary button and the transition**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do pacote
Expected: PASS, com os 3 testes novos. Os prints do vidro e da transição ficam para o simulador, na Task 10.

- [ ] **Step 5: Commit**

```bash
git add apple/Packages/HexDesign
git commit -m "Da Apple, com a marca: o cartão de vidro tingido, os botões secundários e o zoom de Começar treino"
```

---

### Task 8: O HexDesign na checagem

**Depende de:** 1 e #20. A #19 cria a parte `packages`, e a #20 põe o HexStore nela: esta Task mexe no mesmo lugar e entra depois das duas. Ela não espera a #22, que precisa do Xcode 27.2 e cria a parte `app` (a exceção das Restrições globais): se a #22 entrar em `develop` enquanto esta Task corre, `git merge origin/develop` na branch antes do QA.

**Files:**
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs`

**Interfaces:**
- Consumes: a parte `packages` como a #19 e a #20 deixarem: o `developerDir({ swiftOnly: true })` e o `swiftTestFlags(dir)` do `xcode.mjs` (#19), a rodada do HexStore (#20) e a contagem dos testes pelo XUnit que o `spawnCheck` pede ao `swift test` (`--xunit-output`, #19).
- Produces: a parte `packages` com uma rodada do HexDesign depois da do HexStore. Daqui em diante, o `node scripts/hexgym/check.mjs` cobre o pacote, e o QA das Tasks seguintes não roda mais o comando do pacote à parte.

- [ ] **Step 1: Write the failing test**

Em `check.test.mjs`, o teste `test('the packages part runs HexDesign after HexStore, with the same flags and env')`: na parte `packages`, a checagem `HexDesign` vem logo depois da `HexStore`, e o `args()` e o `env()` dela são os da `HexStore` com `apple/Packages/HexDesign` no lugar de `apple/Packages/HexStore`. O teste segue o formato que os testes da #19 e da #20 usam para as rodadas delas. A rodada nova, no `check.mjs`, como a da #20:

```js
{ name: 'HexDesign', cmd: 'swift', args: () => ['test', ...swiftTestFlags(developerDir({ swiftOnly: true })), '--package-path', 'apple/Packages/HexDesign'], env: () => ({ DEVELOPER_DIR: developerDir({ swiftOnly: true }) }) }
```

Se a #19 e a #20 entrarem com outra forma, a rodada do HexDesign copia a do HexStore.

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test scripts/hexgym/check.test.mjs`
Expected: FAIL no teste novo.

- [ ] **Step 3: Add the HexDesign run to `PARTS.packages`**

A lista de partes não muda, então a linha "unknown part" do `check.test.mjs` fica como está. Os testes de print ficam pulados sem `HEXDESIGN_PRINTS` e não contam.

- [ ] **Step 4: Run the checks**

Run: `node scripts/hexgym/check.mjs scripts packages`
Expected: `ok`, e a parte `packages` mostra a conta dos testes com os do HexDesign.

- [ ] **Step 5: Commit**

```bash
git add scripts/hexgym/check.mjs scripts/hexgym/check.test.mjs
git commit -m "A parte packages do check.mjs roda os testes do HexDesign"
```

---

### Task 9: A documentação pública

**Depende de:** 5, 6 e 7.

**Files:**
- Create: `docs/hexgym/design-system/README.md`, `cores.md`, `tipografia.md`, `movimento-e-haptico.md`, `componentes.md`
- Create: `docs/hexgym/design-system/imagens/` (os prints do pacote)

**Interfaces:**
- Consumes: as interfaces e as tabelas das Tasks 1 a 7, e os testes de print delas.
- Produces: a documentação que a seção 6 pede ("documentado em público"), que as Tasks 10 e 11 completam com os prints do simulador.

O que cada arquivo diz, em português do Brasil, simples e sem travessão:
- `README.md`: o que é o HexDesign; as três camadas, com a divisão final (a da seção 6 com os quatro ajustes de 03/11); como usar o pacote num alvo (`import HexDesign`, `.hexTheme(model)` na raiz, `.hexFont(.number)`, `.buttonStyle(.hexPrimary)`); e o índice dos outros arquivos.
- `cores.md`: a tabela dos quatro temas (normal, alto contraste, claro, Watch e ilha, apoio e brilho), as regras de contraste com os números que os testes conferem, e as regras de todos os temas (ouro, systemRed, cinzas do sistema, esforço com número).
- `tipografia.md`: a Barlow Condensed e a reserva, a escala, os dígitos tabulares, os tetos e o Texto em Negrito, e a licença (SIL OFL 1.1, com o `OFL.txt` no pacote e o commit de origem).
- `movimento-e-haptico.md`: as duas tabelas da Task 3 e o que muda com Reduzir Movimento, Reduzir Transparência e Aumentar Contraste.
- `componentes.md`: cada componente nosso e cada um da Apple com a marca, com o que faz, os estados, o VoiceOver, a versão do Watch (preenchida na Task 11) e o print.

- [ ] **Step 1: Generate the images**

Run: `HEXDESIGN_PRINTS=$PWD/docs/hexgym/design-system/imagens` na frente do comando do pacote, com `--filter print`
Expected: os PNGs das Tasks 1, 2, 5 e 6 na pasta.

- [ ] **Step 2: Write the five files**

Cada número e cada valor vem do código e dos testes das Tasks 1 a 7, nunca de memória.

- [ ] **Step 3: Check the links and the text**

Run: `grep -rn -e "$(printf '\342\200\224')" -e "$(printf '\342\200\223')" docs/hexgym/design-system` (o travessão e o meio-travessão, em UTF-8) e, para os links, este comando, que confere cada `](caminho)` relativo dos arquivos, com ou sem título:

```bash
node -e 'const fs=require("fs"),path=require("path");const d="docs/hexgym/design-system";let bad=0;for(const f of fs.readdirSync(d).filter(n=>n.endsWith(".md"))){for(const m of fs.readFileSync(path.join(d,f),"utf8").matchAll(/\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)){const p=m[1].split("#")[0];if(p&&!/^[a-z]+:/i.test(p)&&!fs.existsSync(path.join(d,p))){console.log(f+": "+m[1]);bad=1}}}process.exit(bad)'
```

Expected: o `grep` sem nenhuma linha, e o `node` sai com 0, sem nenhum link quebrado escrito.

- [ ] **Step 4: Commit**

```bash
git add docs/hexgym/design-system
git commit -m "A documentação pública do design system"
```

---

### Task 10: A galeria no iPhone

**Depende de:** 5, 6, 7, 8, 9 e #22 (o projeto e o app da fase 0, que já pedem o Xcode 27.2 da #23). A 9 vem antes porque esta Task completa o `componentes.md` dela.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** a organização da galeria (as três camadas lado a lado no topo, depois o tema, as cores, a tipografia, os componentes e o movimento) e o botão de entrada na tela provisória.

**Files:**
- Modify: `apple/HexGym.xcodeproj/project.pbxproj` (o pacote HexDesign nos quatro alvos do app)
- Delete: `apple/Shared/Wordmark.swift`
- Modify: `apple/HexGym/HexGymApp.swift`, `apple/HexGym/ContentView.swift`, `apple/HexGymWatch/HexGymWatchApp.swift`, `apple/HexGymWidgets/HexGymWidgets.swift`, `apple/HexGymWatchWidgets/HexGymWatchWidgets.swift` (o `Wordmark()` vira `HexWordmark()`)
- Create: `apple/HexGym/Gallery/GalleryView.swift`, `LayersSection.swift`, `ThemeSection.swift`, `ColorSection.swift`, `TypeSection.swift`, `ComponentsSection.swift`, `MotionSection.swift`
- Modify: `apple/HexGym/Localizable.xcstrings` (os textos da galeria, em pt-BR e en)
- Create: `apple/HexGymTests/DynamicTypeTests.swift`
- Modify: `scripts/hexgym/project-format.test.mjs`
- Create: `docs/hexgym/prints/<issue>/` (prints e vídeo) e os prints do simulador em `docs/hexgym/design-system/imagens/`
- Modify: `docs/hexgym/design-system/componentes.md` (os prints do simulador, citados em cada componente)

**Interfaces:**
- Consumes: tudo das Tasks 1 a 7; o projeto (#21), o `AppModel`, a tela provisória e a parte `app` do `check.mjs` (#22).
- Produces: a galeria, que a Task 11 repete no Watch e a Task 13 mostra na versão.

**Como fica:**
- O pacote entra como o HexEngine e o HexStore (Task 9 da fase 0): `XCLocalSwiftPackageReference` com `relativePath = Packages/HexDesign`, e o produto nos alvos `HexGym`, `HexGymWidgets`, `HexGymWatch` e `HexGymWatchWidgets`, porque o logotipo de `Shared/` estava nos quatro. O `HexGymTests` importa o HexDesign pelo app.
- `HexGymApp` cria um `ThemeModel(store: .appGroupStore())` e põe `.hexTheme(model)` na raiz, com o `BreathingGlow` atrás da tela.
- A tela provisória da fase 0 ganha, embaixo da linha de estado, um botão `.hexPrimary` "Galeria do design system" / "Design system gallery", num `NavigationStack`, que abre a galeria.
- A galeria, de cima para baixo:
  1. **As três camadas lado a lado**, cada uma com o nome dela: "Da Apple, como vem" (uma chave, um seletor segmentado, uma linha de ajustes e um SF Symbol), "Da Apple, com a marca" (um `HexGlassCard` com um número, um botão `hexSecondaryButton` e um `RollingNumber`) e "Nossos" (o botão principal, uma `LoadInput`, os segmentos e o carimbo). Nos tamanhos de acessibilidade, as três colunas viram uma embaixo da outra (`ViewThatFits`).
  2. **Tema:** o seletor com os quatro temas (`displayName`), que troca a galeria inteira na hora e grava no App Group, e a chave "Prévia de alto contraste" / "High contrast preview".
  3. **Cores:** cada papel da paleta com o contraste escrito.
  4. **Tipografia:** cada estilo, com "ЖИМ ЛЁЖА", "Πιέσεις πάγκου" e "卧推".
  5. **Componentes:** cada um nos seus estados: o botão normal, desligado e grande; as entradas com 141,3 kg, 1000 kg e o esforço vazio, que andam de verdade (um passo simples da galeria, só para mostrar: a regra de verdade vem do motor na fase 3); os segmentos com 0, 3 e 5 de 5; o carimbo com um botão que mostra de novo; o anel com um descanso de 90 s que começa num toque; o brilho.
  6. **Movimento e háptico:** um botão por háptico e o estado de Reduzir Movimento, Reduzir Transparência e Aumentar Contraste.
  7. **A transição:** um botão principal "Começar treino" / "Start workout" com `hexStartWorkoutSource`, que abre uma tela preta com o brilho e o título "Treino" / "Workout", com `hexStartWorkoutDestination`, dentro de `withTransaction(StartWorkoutTransition.transaction(reduceMotion:))`.

- [ ] **Step 1: Write the failing tests**

Em `apple/HexGymTests/DynamicTypeTests.swift`, dentro de `@Suite @MainActor struct DynamicTypeTests`, com `measure(_:_:bold:)`, que devolve o tamanho de `Text("142,5").hexFont(style).fixedSize()` desenhado por `ImageRenderer` com o `dynamicTypeSize` e o `legibilityWeight` pedidos:

```swift
@Test func displayGrowsUpToItsCap() {                                     // Foco da revisão 2
  let cap = ImageRenderer(content: Text("142,5").font(Font(HexFonts.font(.extraBold, size: 132, tabularDigits: true))).fixedSize()).cgImage!.height
  #expect(measure(.display, .accessibility5).height > measure(.display, .large).height)
  #expect(measure(.display, .accessibility5).height <= CGFloat(cap) + 1)
}
@Test func headlinesKeepGrowing() {                                       // Foco da revisão 2
  #expect(measure(.headline, .accessibility5).height > 1.5 * measure(.headline, .large).height)
}
@Test func boldTextIsWider() {                                            // Foco da revisão 2
  #expect(measure(.headline, .large, bold: true).width > measure(.headline, .large).width)
}
```

Em `scripts/hexgym/project-format.test.mjs`: `test('the HexDesign package is linked to the four app targets')`, com `relativePath = Packages/HexDesign;` no `project.pbxproj` e o produto `HexDesign` em quatro `XCSwiftPackageProductDependency`, um por alvo.

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test scripts/hexgym/project-format.test.mjs` e `node scripts/hexgym/check.mjs app`
Expected: FAIL no teste do pacote e `no such module 'HexDesign'` nos testes do app.

- [ ] **Step 3: Link the package, swap the wordmark, and write the gallery**

- [ ] **Step 4: Run the checks**

Run: `node scripts/hexgym/check.mjs scripts packages app`
Expected: `ok`, com os 3 testes novos na conta da parte `app`.

- [ ] **Step 5: See it run**

Compilar assinado e instalar no simulador do iPhone, como no passo 7 da Task 9 da fase 0. Prints da galeria: no topo (as três camadas), em cada tema, com a prévia de alto contraste, com Aumentar Contraste ligado no simulador e no AX5 (`xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`, e de volta a `large` no fim). Um vídeo de até 15 s e menos de 5 MB: a troca de tema ao vivo e o zoom de "Começar treino". Os prints e o vídeo vão em `docs/hexgym/prints/<issue>/`, no PR, e os prints do vidro, da transição e de cada componente vão também para `docs/hexgym/design-system/imagens/`, citados no `componentes.md`.

- [ ] **Step 6: Commit**

```bash
git add apple scripts/hexgym/project-format.test.mjs docs/hexgym
git commit -m "A galeria do design system no iPhone, com as três camadas e a troca de tema ao vivo"
```

---

### Task 11: O design system no Watch

**Depende de:** 10.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** o botão compacto de 44 pt, um passo por dente da Coroa Digital e o brilho parado no Watch.

**Files:**
- Create: `Sources/HexDesign/Components/CrownSteps.swift`
- Modify: `Sources/HexDesign/Components/HexPrimaryButton.swift` (o tamanho `.compact`), `Components/WorkoutInput.swift` (a Coroa Digital, em `#if os(watchOS)`)
- Test: `Tests/HexDesignTests/WatchTests.swift`
- Create: `apple/HexGymWatch/Gallery/WatchGalleryView.swift` e as seções dela
- Create: `apple/HexGymWatch/Localizable.xcstrings` (os textos da galeria do Watch, em pt-BR e en)
- Modify: `apple/HexGymWatch/HexGymWatchApp.swift` (o `ThemeModel` e a entrada da galeria) e `docs/hexgym/design-system/componentes.md` (a versão do Watch de cada componente)
- Create: `docs/hexgym/prints/<issue>/` (prints e vídeo do Watch)

**Interfaces:**
- Consumes: os componentes das Tasks 5 a 7 e a galeria do iPhone (Task 10).
- Produces:

```swift
public enum Size: Sendable { case regular, large, compact }   // dentro de HexPrimaryButtonStyle; compact: 44 pt
public enum CrownSteps { public static func steps(from old: Double, to new: Double) -> [StepDirection] }
```

**Como fica:**
- `HexPrimaryButtonStyle.Size` ganha `.compact` (altura mínima 44, rótulo em `headline`), que é o padrão do `init()` no watchOS.
- No watchOS, a entrada em foco responde à Coroa Digital: `digitalCrownRotation` com `by: 1`, sensibilidade `.low`, sem fim e com o háptico da própria coroa; cada mudança passa por `CrownSteps.steps`, que dá um passo por dente cruzado (`floor(new) - floor(old)`, para cima quando positivo), e cada passo chama `onStep`. Os botões − e + continuam, para quem não usa a coroa.
- O anel, o número que rola, os segmentos e o carimbo são os mesmos componentes, com a paleta da superfície `.watch` e o tamanho do `hexFont`. O brilho fica parado (`GlowSpec` com `surface: .watch`, Task 6).
- A galeria do Watch, numa `List` com seções: as três camadas, o tema (com o seletor próprio, gravado nos `UserDefaults` do App Group no próprio Watch: a ida do tema do iPhone para o Watch é da fase 4) e os componentes.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func eachCrownDetentIsOneStep() {
  #expect(CrownSteps.steps(from: 0, to: 3) == [.up, .up, .up]); #expect(CrownSteps.steps(from: 3, to: 2) == [.down])
  #expect(CrownSteps.steps(from: 0, to: 0.4) == []); #expect(CrownSteps.steps(from: 0.4, to: 1.2) == [.up])
  #expect(CrownSteps.steps(from: 1.2, to: -0.6) == [.down, .down])
}
@Test func theWatchButtonIsCompact() { #expect(HexPrimaryButtonStyle.Size.compact.minHeight == 44) }
```

- [ ] **Step 2: Run them to verify they fail**

Run: o comando do pacote, com `--filter WatchTests`
Expected: FAIL, `cannot find 'CrownSteps' in scope`.

- [ ] **Step 3: Implement the crown, the compact button and the Watch gallery**

- [ ] **Step 4: Run the checks**

Run: `node scripts/hexgym/check.mjs packages app`
Expected: `ok`; o build do Watch da parte `app` compila o código de `#if os(watchOS)`.

- [ ] **Step 5: See it run**

No simulador do Apple Watch, como no passo 7 da Task 9 da fase 0: prints da galeria em cada tema e do anel de descanso, e um vídeo curto (até 15 s e menos de 5 MB) da troca de tema e de uma carga mudando pela coroa. O print do anel mostra que ele não parece um anel de atividade. Os prints vão em `docs/hexgym/prints/<issue>/` e em `docs/hexgym/design-system/imagens/`, citados no `componentes.md`.

- [ ] **Step 6: Commit**

```bash
git add apple docs/hexgym
git commit -m "O design system no Watch: a Coroa Digital nas entradas e a galeria do Watch"
```

---

### Task 12: O ícone do app

**Depende de:** 1, #21 e #22. A #21 cria o `placeholder-icon.swift` e os `AppIcon`, e a #22 cria a parte `app` do `check.mjs`, que o passo 4 roda.

**Escolhas recomendadas, com a delegação do Lipe de 03/11/2026:** o ícone abaixo, que é o "ícone de verdade" que a Task 9 da fase 0 deixou para a fase 1.

**Files:**
- Create: `scripts/hexgym/app-icon.swift`, `scripts/hexgym/app-icon.test.mjs`
- Delete: `scripts/hexgym/placeholder-icon.swift`
- Modify: `apple/HexGym/Assets.xcassets/AppIcon.appiconset/` (`AppIcon.png`, `AppIcon-dark.png`, `AppIcon-tinted.png` e o `Contents.json`), `apple/HexGymWatch/Assets.xcassets/AppIcon.appiconset/` (`AppIcon.png` e o `Contents.json`)
- Create: `docs/hexgym/prints/<issue>/`

**Interfaces:**
- Consumes: as cores do Ultravioleta (Task 1), copiadas no script, porque um script `swift` solto não importa o pacote: #8B7BFF e o brilho em P3 (0,4221 0,3535 0,9822, opacidade 0,85).
- Produces: `swift scripts/hexgym/app-icon.swift <pasta do appiconset do iPhone> <pasta do appiconset do Watch>`, que grava os quatro PNGs.

**O desenho:** fundo preto; um hexágono de topo reto, só o contorno, em #8B7BFF, com 58% do lado de ponta a ponta e traço de 10% do lado, inclinado 18° como os segmentos; atrás dele, o brilho do Ultravioleta, um gradiente radial de 60% do lado. Tudo cabe no círculo do Watch. O `AppIcon-dark.png` é igual ao normal (o ícone já é escuro). O `AppIcon-tinted.png` é em tons de cinza, o hexágono branco no preto e sem brilho, para o sistema tingir. Todos têm 1024 × 1024, sem canal alfa, desenhados num `CGContext` em Display P3 com `noneSkipLast` e gravados em PNG pelo ImageIO. O Watch usa o normal.

- [ ] **Step 1: Write the failing test**

Em `app-icon.test.mjs`, `ihdr(arquivo)` lê o cabeçalho do PNG (largura, altura, profundidade e tipo de cor):

```js
test('every icon is 1024 square, RGB and without alpha', () => {
  for (const f of icons) assert.deepEqual(Object.values(ihdr(f)), [1024, 1024, 8, 2], f)
})
test('the iPhone icon has the any, dark and tinted looks', () => {
  assert.deepEqual(phone.images.map(i => i.appearances?.[0]?.value ?? 'any'), ['any', 'dark', 'tinted'])
  assert.ok(phone.images.every(i => i.size === '1024x1024' && i.platform === 'ios'))
})
test('the Watch has one icon', () => assert.deepEqual(watch.images.map(i => i.platform), ['watchos']))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test scripts/hexgym/app-icon.test.mjs`
Expected: FAIL, `ENOENT` no `AppIcon-dark.png`.

- [ ] **Step 3: Write the script, draw the icons and update the two `Contents.json`**

O `Contents.json` do iPhone tem três imagens `universal`, `ios`, `1024x1024`: a normal sem `appearances`, a escura com `[{ "appearance": "luminosity", "value": "dark" }]` e a tingida com `"value": "tinted"`.

Run: `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift scripts/hexgym/app-icon.swift apple/HexGym/Assets.xcassets/AppIcon.appiconset apple/HexGymWatch/Assets.xcassets/AppIcon.appiconset`, depois `node --test scripts/hexgym/app-icon.test.mjs` e `sips -g hasAlpha` nos quatro PNGs
Expected: PASS, 3 testes, e `hasAlpha: no` nos quatro.

- [ ] **Step 4: Run the checks**

Run: `node scripts/hexgym/check.mjs scripts app`
Expected: `ok`, com o ícone compilado no app e no Watch.

- [ ] **Step 5: See it on the home screen**

Instalar no simulador do iPhone e no do Watch, como no passo 7 da Task 9 da fase 0. Prints da tela inicial do iPhone no claro e no escuro (`xcrun simctl ui <udid> appearance light` e `dark`) e da lista de apps do Watch, em `docs/hexgym/prints/<issue>/`, no PR. Depois do merge, a sessão da fase 1 põe o ícone na página das decisões.

- [ ] **Step 6: Commit**

```bash
git add scripts/hexgym apple/HexGym/Assets.xcassets apple/HexGymWatch/Assets.xcassets docs/hexgym/prints
git rm scripts/hexgym/placeholder-icon.swift
git commit -m "O ícone do HexGym: o hexágono inclinado com o brilho do Ultravioleta"
```

---

### Task 13: A versão 0.2.0

**Depende de:** todas as outras, da fase 1 e as que entrarem nela depois, e a versão 0.1.0 (#25). É a Task da versão: segue os passos da Task 16 da fase 0, na mesma ordem e com um comentário na issue por passo, retomando pelo último comentado, com estas trocas:

- **Os nomes:** versão `0.2.0`, branch `release/0.2.0`, worktree `.claude/worktrees/release-0.2.0`, milestone "Fase 1: Design system" (número 2), resumo `docs/status/m2-design-system-status.md` (`--milestone 2`), PR "Versão 0.2.0: o design system", tag `v0.2.0` com o título "HexGym 0.2.0", e o PR de volta "Versão 0.2.0 de volta para develop".
- **Passo 1:** o que sobrar aberto sai do épico da fase 1 e vai para o milestone "Fase 2: Biblioteca e rotinas", com `orphan:ok`.
- **Passo 2:** na branch da release, um commit "Versão 0.2.0" com `MARKETING_VERSION = 0.2.0` nos quatro alvos. O número do build não muda no projeto: o `testflight.mjs` (#24) põe a data e a hora em UTC no passo 5.
- **Passo 3:** prints das duas galerias, a do iPhone e a do Watch, e um vídeo da troca de tema ao vivo e do zoom de "Começar treino".
- **Passo 5:** o build interno no TestFlight, com `node scripts/hexgym/testflight.mjs` (#24).
- **Passo 7:** o pedido de decisão vai nesta issue: 1. Aprovar a versão 0.2.0 (recomendada); 2. Pedir mudanças. É a parada de fim de fase da seção 9.1, que a delegação de 03/11 não tira do founder.
- **Passo 12:** `check-milestone-outcomes.sh --milestone 2`.
- **Passo 13:** fecha o milestone 2, e o filtro da visão "Fase atual" vira `milestone:"Fase 2: Biblioteca e rotinas"`; o primeiro milestone aberto passa a ser "Fase 2: Biblioteca e rotinas". A sessão da fase 1 põe o resultado da fase na página das decisões.
