# Fase 3 do HexGym (Treino no iPhone): plano de implementação

> **Quem executa:** o orquestrador do relentless, como ele vem (nota `docs/decisions/notes/2026-11-03-um-orquestrador-so.md`), tocado pela sessão da fase 3. Cada Task é uma issue do milestone "Fase 3: Treino no iPhone", sub-issue do épico da fase, e um PR para `develop`: uma worktree e uma branch por Task, o critério de aceite da issue é a Task deste plano (a linha `Plano:` da issue), e a revisão isolada do relentless é a revisão do PR. Os títulos ficam "Task N" porque é assim que a linha `Plano:` das issues aponta para eles. Os passos usam caixas de seleção (`- [ ]`).

**Objetivo:** o founder faz um treino completo no iPhone: abre o app na tela inicial, toca em "Começar treino", registra as séries com carga, repetições e esforço (supersets inclusive), descansa com o anel, a notificação e os hápticos, acompanha pela Live Activity e pela Dynamic Island, termina com os recordes e a próxima carga, vê o treino no histórico e começa o próximo pela Siri.

**Arquitetura:** a sequência do treino vira um módulo puro do openGym, `frontend/src/lib/session-controller.js`, no formato `(estado, ação, agora) → {estado, efeitos}` da seção 8.2, montado só com as funções que o lib já tem (`buildCombinedEntries`, `supersetFlowStep`, `restSecFor`, `buildCompletedWorkout`, `beatsWeight`, `is1RMRecord`, `finishCompare` e companhia). Como todo módulo limpo do lib, ele entra no script do motor sozinho. Em `apple/Packages/HexEngine/JS/`, o `session.js` liga o controlador ao documento aberto, com o rascunho e o carimbo do `update()` do openGym, e dá as leituras das telas (o treino em andamento, a tela inicial, a Live Activity); o `workouts.js` dá as leituras do histórico. O app executa os efeitos (hápticos, notificação, Live Activity) num modelo `@Observable`, `WorkoutSession`. A Live Activity e os botões dela moram num pacote novo, o `HexLive`, ligado ao app e à extensão dos widgets. O Watch não muda nesta fase.

**Tecnologias:** Swift (`swift-tools-version: 6.2`), SwiftUI, ActivityKit, WidgetKit, App Intents, UserNotifications e Swift Testing; JavaScript do motor (Node 22, `node --test` e Vitest do frontend); Xcode 27.2 estável.

**Especificação:** `docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md`, seções 4, 5, 6, 7, 8.2, 8.3, 8.6, 8.12, 8.13, 9 e 9.1. As decisões visuais da fase 1 valem como estão: página https://claude.ai/artifact/3fwPGoNm3EBDZkqesDkvbB e `docs/hexgym/design-system/`. A paridade é com o openGym em vigor no começo desta fase (seção 8.12): o 1.4.3 do script do motor, em `develop` no `f767b7e`.

## Escolhas desta fase

O founder delegou em 03/11/2026: o tech lead segue a opção recomendada, inclusive em visual, produto e texto. Cada escolha abaixo vem marcada no plano e na issue como "escolha recomendada, com a delegação do Lipe de 03/11/2026". O que ele pedir para mudar depois vira uma Task normal. A página da fase 3 (Artifact, publicada pela sessão da fase 3) mostra as telas propostas e, a cada merge, o PR, os prints do simulador e a escolha.

As escolhas recomendadas deste plano:
1. **As abas:** cinco, nesta ordem: "Início", "Rotinas", "Exercícios", "Histórico" e "Ajustes", na barra de abas da Apple. O app abre no Início (Task 7).
2. **A tela inicial:** de cima para baixo, o cartão de hoje (as rotinas do dia pela semana do openGym, ou "Hoje é dia de descanso", ou "Nada marcado para hoje"); o botão principal grande "Começar treino" (ou "Continuar treino", com o tempo e as séries feitas, quando há um treino em andamento); "Outro treino", um `Menu` com as rotinas e "Treino livre"; a semana em segmentos inclinados (um por dia, cheio quando treinou); a sequência de semanas e os treinos da semana; e o último treino, que abre o detalhe dele (Task 7).
3. **A transição:** o botão "Começar treino" cresce até a tela do treino (o zoom da fase 1), que cobre as abas como uma tela cheia (`fullScreenCover`). Com Reduzir Movimento, a tela esmaece. O mesmo vale para o "Começar" do editor de rotina (Task 8).
4. **A tela do treino:** em cima, o nome, o tempo que passa, os segmentos inclinados das séries e "Terminar"; no meio, um cartão de vidro por exercício, com as séries em linhas curtas ("60 kg × 8", com a marca de feita); embaixo, fixo, o painel da série atual, com as entradas grandes do HexDesign (carga, repetições e, quando o perfil usa, esforço) e o botão principal "Série feita". Tocar numa linha faz dela a série atual. É para registrar com uma mão, entre séries, com pressa (seção 6). O superset aparece com a marca na lateral dos cartões e a letra do grupo (Task 8).
5. **O descanso:** começa sozinho ao marcar a série, pelas regras do openGym (o descanso do perfil, do exercício, do aquecimento e do superset, que só descansa no fim da volta). Ele toma o lugar do painel da série atual: o anel de descanso, o tempo, "−15 s", "+15 s" e "Pular". No fim, o háptico de descanso no app e, com o app fora da frente, uma notificação local "Descanso acabou" com o próximo exercício (Task 9).
6. **A permissão de notificação:** pedida pelo sistema no primeiro "Começar treino", sem tela antes. Sem permissão, o descanso funciona igual dentro do app (Task 9).
7. **O esforço:** a entrada de esforço do HexDesign na escala do perfil (RIR ou RPE), no painel da série atual. Mudar o esforço não marca a série; quem marca é o "Série feita". No openGym, escolher o esforço no seletor marca a série; no HexGym, a entrada é um passo, e marcar por ela marcaria a série a cada toque (Task 1).
8. **A Live Activity:** na tela bloqueada e na Dynamic Island, com o nome do exercício, a série ("Série 2 de 3 · 60 kg × 8"), as séries feitas e o descanso contando. Os botões: "Série feita" fora do descanso; "+15 s" e "Pular" no descanso. As cores são as da superfície `.island` do tema (Tasks 13 e 14).
9. **O fim do treino:** "Terminar" pede confirmação quando faltam séries ("Ainda faltam 4 séries."); "Descartar treino" fica no menu da tela, com um `.alert` destrutivo. O resumo mostra a duração, o volume, as séries, os recordes com o carimbo e o háptico de recorde, e, por exercício, "Da última vez" e "Na próxima" (a carga que a progressão do openGym vai pedir). O "Pronto" volta ao Início (Task 11).
10. **O histórico:** a aba lista os treinos do mais novo para o mais antigo, em seções por mês; o detalhe mostra as séries, os recordes e a nota; apagar pede confirmação e não tem desfazer, como no openGym. Editar um treino salvo, mudar a data, repetir e exportar ficam para a fase 5 (Task 12).
11. **A Siri:** dois atalhos, "Começar treino no HexGym" (o treino de hoje) e "Começar <rotina> no HexGym", em português do Brasil e em inglês. Os dois abrem o app na tela do treino; com um treino em andamento, abrem ele (Task 15).
12. **O que fica para a fase 5:** a pesagem no começo (o `bw` do treino é o último peso do documento, sem perguntar), o cronômetro da série com tempo (no modo tempo, os segundos entram por um `Stepper` da Apple), o aquecimento novo, a edição de drop set, rest-pause, lados e cardio (as séries assim vindas do openGym aparecem e são marcadas inteiras), pausar o descanso, o treino passado, editar e repetir treinos, e o modo de tela em tabela do openGym (`workoutView`).
13. **O descanso no documento:** o openGym guarda o descanso fora do documento (`store/useUI.js` e o `localStorage` `gym_rest`). O HexGym guarda em `active.rest`, dentro do treino em andamento: uma fonte só, gravada com o resto, e que sobrevive ao app morto. O `active` nunca sai do aparelho (seção 8.12), e o `buildCompletedWorkout` monta o treino salvo campo a campo, então o `rest` não chega ao histórico (Task 1).

## Restrições globais (Global Constraints)

Valem para toda Task. Os valores vêm da especificação, das decisões das fases 1 e 2 e do levantamento de 08/11/2026.

- **Plataforma e Xcode:** iOS 26 como mínimo, nada só do iOS 27; Xcode 27.2 estável em `/Applications/Xcode.app`, por `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs)`. O Xcode-beta nunca é escolhido, nem num comando que só imprime o caminho. Os pacotes rodam com `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) --package-path apple/Packages/<pacote>` ("o comando do pacote").
- **A checagem:** `node scripts/hexgym/check.mjs` roda as partes `scripts, engine, load, packages, app`, e cada parte só passa se rodou pelo menos um teste, contado por um arquivo (regra da #44). Em `develop` no `f767b7e`, ela dá `scripts 93, engine 2633, load 7, packages 101, app 57`. Toda Task diz quanto cada parte cresce, contando os testes que ela lista (um por função no XUnit do `swift test` e na parte `app`; um por `test` ou `it` no Vitest e no `node --test`); a conta de partida é a de `develop` no começo da Task, e o PR diz a de antes e a de depois e, se o número for outro, por quê. O QA confere a conta, não só o código de saída. Um teste de propriedade do openGym (o `sync-merge.property.test.js`, como o `plates.property.test.js` da fase 0) cai de vez em quando contra o script: rodar de novo, e o PR diz se caiu.
- **O código do openGym:** nesta fase, só dois arquivos novos em `frontend/`: `frontend/src/lib/session-controller.js` e o teste dele, o que a seção 8.2 pede. Nenhum arquivo de `frontend/` que já existe muda, e o app web do openGym não passa a usar o controlador. `cd frontend && npm test` continua verde. O cabeçalho do controlador lista as linhas de `views/Workout.jsx`, `sheets.jsx` e `store/useUI.js` que ele reproduz, para o PR de sync com o openGym comparar (seção 8.11).
- **O controlador:** puro. Não lê o relógio (o `agora` vem de fora, e toda função do lib que tem um `now` ou um `today` recebe o dele), não muda o estado que recebe, não chama `sound.js`, `mobile.js` nem nada do navegador. O mesmo `agora` dá o mesmo resultado.
- **O script do motor:** toda mudança no lib e em `apple/Packages/HexEngine/JS/` muda o script gerado. A Task roda `node scripts/build-hexgym-engine.mjs` e commita o `hexengine.js.deflate` e o `hexengine.js.sha256` juntos. Como os dois são binários, duas Tasks que mexem no motor nunca correm juntas: a ordem é 1, 2, 3, 4, 5. A sessão da fase 2 também pode mudar o motor nos follow-ups dela (#116, #120): quem entra depois faz `git merge origin/develop` e gera o script de novo antes do QA. O mesmo vale, sem o script, para os arquivos de texto que várias Tasks mexem: o `RootView.swift` (Tasks 7, 8, 12 e 15), o `Localizable.xcstrings` (toda Task de tela), o `project.pbxproj`, o `project-format.test.mjs`, o `check.mjs` e o `check.test.mjs` (Task 13).
- **O motor:** um `JSContext` só, dentro do ator `HexEngine`, nunca na thread principal. O Swift troca só texto JSON e modelos `Codable` pequenos; o documento fica dentro do JS e nunca vai inteiro para a tela.
- **O documento:** toda mudança passa pelo motor, com `draftOf` e `stampChange`, como o `update()` do `store/useStore.js`; o app grava pelo `DocumentStore` do HexStore. Nenhuma chave do documento se perde ao ler e gravar. O HexGym não escreve `theme`, `accent` nem `lang`. O `active` é do aparelho (seção 8.12).
- **Desempenho (seção 8.13):** marcar uma série reflete na tela em menos de 100 ms; a ação de marcar, no `jsc` sem JIT com 1.040 treinos, fica na meta `TICK_MS` do `engine-load.mjs` (30 ms), agora pela ação do controlador; o tempo que passa e o descanso contam por `TimelineView` e pelo `endsAt`, sem timer que acorda a tela inteira; transições a 120 Hz; nada calculado no `body`.
- **Design system:** toda tela usa o HexDesign (`.hexFont`, `.buttonStyle(.hexPrimary)`, `HexGlassCard`, `hexSecondaryButton`, `HexSpacing`, `@Environment(\.hexPalette)`, `LoadInput`, `RepsInput`, `EffortInput`, `WorkoutInputLayout`, `RollingNumber`, `SlantedSegments`, `RecordStamp`, `RestRing`, `HexHaptic`, `StartWorkoutTransition`). As decisões das fases 1 e 2 ficam como estão, inclusive o tint branco na raiz (`RootTint`). Componentes da Apple como vêm: `TabView`, `NavigationStack`, `List`, `Menu`, `Stepper`, `.sheet`, `.fullScreenCover`, `.swipeActions`, `.alert`.
- **As pegadinhas do iOS 27 (fase 2):** o `confirmationDialog` esconde o Cancelar: usar `.alert`; o `.badge` toma o valor de acessibilidade do botão: usar um selo desenhado; `.accessibilityElement(children: .ignore)` por fora de um `Button` tira a ativação pelo VoiceOver; os traços de acessibilidade não chegam aos botões da barra do UIKit: usar o rótulo.
- **Acessibilidade:** toda tela funciona com Dynamic Type até AX5 (nada cortado; as entradas empilham pelo `WorkoutInputLayout`), VoiceOver (rótulo, valor e ação em cada controle; a série atual e o descanso são anunciados), Reduzir Movimento, Aumentar Contraste, Reduzir Transparência e Texto em Negrito; alvo de toque de pelo menos 44 pt.
- **Mídias da Gym visual:** nenhuma entra no app, nos prints ou nos vídeos desta fase (seção 8.8). Nunca abrir, copiar, converter ou passar por ferramenta de IA as fotos e animações; nada maior que 180 px delas em lugar nenhum; nada novo em `catalogue/media/`. A Live Activity e os cartões do treino não têm imagem de exercício.
- **Dependências:** nenhum pacote Swift de terceiros e nenhuma dependência npm nova.
- **Texto para o usuário:** simples e humano, sem travessão; português do Brasil e inglês no catálogo do app (`apple/HexGym/Localizable.xcstrings`); os nomes dos exercícios e os textos que o openGym já tem vêm do motor, nos 20 idiomas; os nomes da Apple na grafia da Apple (iPhone, Apple Watch, Live Activity, Dynamic Island, Siri, VoiceOver, Dynamic Type).
- **Prints e vídeo dos PRs:** em `docs/hexgym/prints/<issue>/`, no commit do próprio PR, mostrados no corpo por `https://github.com/lipedesign/HexGym/blob/<sha>/docs/hexgym/prints/<issue>/<arquivo>?raw=true`. Os prints saem do simulador do iPhone (o `pickSimulator` do `check.mjs`) com `xcrun simctl io <udid> screenshot`; o vídeo, com `xcrun simctl io <udid> recordVideo --codec h264`, até 15 s e menos de 5 MB. Toda Task de tela tem print em tamanho padrão e em AX5. Nunca um aparelho físico.
- **Abrir o app num estado, para prints e testes:** argumentos de lançamento, como os das fases 1 e 2. A Task 6 cria `-HexGymFixture <nome>` (abre um documento preparado de `apple/HexGym/Fixtures/<nome>.json` numa pasta temporária, nunca no App Group, só no build Debug) e `-HexGymWorkout YES` (abre a tela do treino em andamento). A Task 7 cria `-HexGymTab inicio` e `-HexGymTab historico`; a Task 11, `-HexGymFinish YES` (termina o treino do documento preparado e mostra o resumo); a Task 12, `-HexGymWorkoutDetail <id>`. O QA não toca no simulador: ele confere por esses argumentos e pelos documentos preparados.
- **O que só um iPhone de verdade prova:** hápticos, a notificação do descanso com o app no fundo e na tela bloqueada, a Live Activity na tela bloqueada e na Dynamic Island expandida, os botões dela com o app fechado, a Siri por voz, os 120 Hz e o toque em menos de 100 ms com um histórico grande. Cada Task diz o que ficou para o aparelho, e a Task 16 junta a lista para conferir com o founder, como a #67 faz.
- **Os testes do app:** a parte `app` do `check.mjs` roda o alvo `HexGymTests` (Swift Testing). Lógica de tela que dá para provar sem tela (textos, ordem, decisões, o que um efeito faz) vai num tipo pequeno testado ali; o que só a tela prova vai nos prints.
- **Duas fases ao mesmo tempo:** a fase 2 ainda tem os follow-ups #106, #114, #116, #117, #118 e #120 e os itens de código da #67, da sessão "Fase 2: biblioteca e rotinas", e as Tasks 13 e 14 dela (#100 e #101) esperam o `/decide 10`. Nenhuma Task daqui depende delas, e uma Task que precise mexer nos arquivos que um PR aberto da fase 2 mexe espera o merge dele. A fase 0 ainda tem a #8, a #23, a #24 e a #25: nenhuma Task daqui mexe em `README.md`, `CONTRIBUTING.md`, `SECURITY.md` nem em `scripts/hexgym/testflight.mjs`. Nenhuma linha em `docs/decisions/log.jsonl` até o `/decide 36`. Todo `gh issue list` desta fase leva `--milestone "Fase 3: Treino no iPhone"`.
- **Repositório, IDs, Git Flow, estado das issues, `.claude/` e commits:** como nas Restrições globais da fase 0 (`docs/superpowers/plans/2026-10-31-fase-0-fundacao.md`). Todo `gh` leva `-R lipedesign/HexGym`. Os commits terminam com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Foco da revisão (Review Focus)

O que a especificação implica, nenhuma Task testaria sozinha e mais pode morder quem treina. Cada linha ganhou um teste na Task dona do código.

1. **O app morto no meio do treino:** o sistema fecha o app, ou o iPhone reinicia, com séries feitas e o descanso contando. Ao abrir de novo, o treino está lá, com as séries, e o descanso no ponto certo pelo `endsAt` (ou acabado, se o tempo passou), sem notificação repetida. Testes nas Tasks 4 e 6.
2. **O relógio:** um treino que passa da meia-noite fica no dia em que começou; o fim é a última série, e 20 minutos sem série no fim (o "esqueci de terminar" do `sessionEnd`) não entram na duração; os casos gravados rodam nos três fusos do `check.mjs`. Testes nas Tasks 3 e 4.
3. **Toques repetidos e fora de ordem:** marcar a mesma série duas vezes depressa, o botão da Live Activity para uma série que o app já marcou, o mesmo evento da fila aplicado duas vezes, "Pular" com o descanso já acabado: o resultado é o de um toque só, e nenhum descanso fica pendurado. Por isso o controlador recebe o estado que a série deve ter (`set.mark` com `done`), e não um "inverte". Testes nas Tasks 1, 4 e 14.
4. **O treino que veio do openGym:** um `active` com aquecimento, drop set, rest-pause, lados, cardio, série com tempo, pirâmide e `noProg` abre, aparece, cada linha pode ser marcada inteira, e o treino termina como no openGym, sem perder campo. Testes nas Tasks 1, 3 e 8.
5. **O vazio:** o treino livre sem exercício; terminar sem nenhuma série feita (não grava treino, como o openGym); uma rotina com um exercício que não existe neste aparelho ("Exercício desconhecido"); o Início sem rotinas e sem histórico; o histórico vazio; a Siri sem nada marcado para hoje. Testes nas Tasks 3, 7, 12 e 15.

## Mapa dos arquivos

```
frontend/src/lib/session-controller.js        o controlador do treino, puro (Tasks 1, 2 e 3)
frontend/src/lib/session-controller.test.js   Vitest; roda também contra o script do motor
apple/Packages/HexEngine/JS/
  session.js, session.test.mjs                o treino no documento aberto e as leituras (Task 4)
  workouts.js, workouts.test.mjs              o histórico (Task 5)
apple/Packages/HexEngine/Sources/HexEngine/
  Session.swift                               as ações, os efeitos e as leituras do treino (Task 4)
  Workouts.swift                              o histórico (Task 5)
apple/Packages/HexLive/                       a Live Activity e os botões dela (Tasks 13 e 14)
  Package.swift
  Sources/HexLive/WorkoutActivity.swift       os atributos e o estado
  Sources/HexLive/LiveAdvance.swift           o avanço local quando o app não está aberto (Task 14)
  Sources/HexLive/LiveEventQueue.swift        a fila no App Group (Task 14)
  Sources/HexLive/WorkoutIntents.swift        os App Intents dos botões (Task 14)
  Tests/HexLiveTests/
apple/HexGym/
  Workout/                                    o modelo do treino, a tela, o descanso, o fim (Tasks 6, 8 a 11)
  Home/                                       a tela inicial (Task 7)
  History/                                    o histórico (Task 12)
  Live/                                       quem liga e atualiza a Live Activity (Tasks 13 e 14)
  Intents/                                    a Siri (Task 15)
  Fixtures/                                   os documentos preparados, só no Debug (Task 6)
apple/HexGymWidgets/WorkoutLiveActivity.swift a tela bloqueada e a Dynamic Island (Task 13)
apple/HexGymTests/                            um arquivo por assunto
docs/hexgym/prints/<issue>/                   os prints e os vídeos dos PRs
```

Arquivos de antes que mudam: `apple/Packages/HexEngine/JS/runtime.js` e `actions.js` (Tasks 4 e 5); `scripts/hexgym/engine-load.mjs` e `scripts/hexgym/engine-cases.mjs` (Task 4); `apple/HexGym/AppModel.swift` e `HexGymApp.swift` (Task 6); `apple/HexGym/RootView.swift` (Tasks 7, 8, 12 e 15); `apple/HexGym/Routines/RoutineEditorView.swift` (Task 8); `apple/HexGymWidgets/HexGymWidgets.swift` (Task 13, que passa a ter um `WidgetBundle`); `apple/Config/HexGym-Info.plist` (Task 13); `apple/HexGym.xcodeproj/project.pbxproj`, `scripts/hexgym/project-format.test.mjs`, `scripts/hexgym/check.mjs` e `check.test.mjs` (Task 13); `apple/HexGym/Localizable.xcstrings` em toda Task de tela; `docs/hexgym/design-system/movimento-e-haptico.md` (Task 6: o `setLogged` passa a ter quem toque).

## Ordem e dependências

| Task | O que entrega | Depende de |
|---|---|---|
| 1 | O controlador: começar, as séries e o descanso | nenhuma |
| 2 | O controlador: exercícios no meio do treino | 1 |
| 3 | O controlador: o fim do treino, com recordes e progressão | 2 |
| 4 | O treino no motor e as leituras das telas | 3 |
| 5 | O histórico no motor | 4 |
| 6 | O treino no app: o modelo, os efeitos e os documentos preparados | 4 |
| 7 | As abas novas e a tela inicial | 6 |
| 8 | A tela do treino e a transição de "Começar treino" | 7 |
| 9 | O descanso: o painel, a notificação e os hápticos | 8 |
| 10 | Mudar o treino no meio: séries e exercícios | 8 |
| 11 | O fim do treino na tela | 8 |
| 12 | O histórico na tela | 5, 7 |
| 13 | A Live Activity e a Dynamic Island | 6, 9 |
| 14 | Os botões da Live Activity | 13 |
| 15 | A Siri para começar o treino | 8 |
| 16 | A versão 0.4.0 | todas as outras, #102 |

Cada issue leva, no fim das Notas, as duas linhas que o orquestrador lê: `Depende de: #a, #b` (ou `nenhuma`) e `Plano: docs/superpowers/plans/2026-11-08-fase-3-treino-no-iphone.md, Task N`. As issues saem depois do merge deste plano, com o modelo Tarefa, a etiqueta do tipo, as de área (`motor`, `dados`, `design-system`, `widgets`) e `state:todo`, o critério de aceite de cada Task copiado no corpo (o revisor isolado só lê o corpo) e a marca das escolhas recomendadas; cada uma vira sub-issue do épico da fase e entra no Project 6. Nas linhas `Depende de:`, o número da Task vira o da issue.

As Tasks de motor e de dados (1 a 6) vêm primeiro, e as de tela depois: assim a página da fase mostra as telas propostas antes do código delas. As Tasks 9, 10, 11 e 15 dependem só da 8 e podem correr em paralelo, cada uma na sua worktree, com o merge de `develop` antes do QA por causa do `Localizable.xcstrings`. A 16 espera também a versão 0.3.0 (#102), que espera a #100, a #101 e a 0.2.0 (#67).

Ficam fora desta fase, de propósito: o Watch e o WatchCore (fase 4); o que a escolha 12 lista (fase 5); widgets da tela inicial, controles da Central de Controle, botão de Ação e Spotlight (fase 6); as mídias da Gym visual (seção 8.8); o modo claro.

---

### Task 1: O controlador: começar, as séries e o descanso

**Depende de:** nenhuma.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** as escolhas 7, 12 e 13.

**Files:**
- Create: `frontend/src/lib/session-controller.js`, `frontend/src/lib/session-controller.test.js`
- Modify: o script do motor gerado (`apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js.deflate` e `.sha256`)

**Interfaces:**
- Consumes (todas do lib, nenhuma muda): `buildCombinedEntries`, `deriveSessionName` (`session-merge.js`); `supersetFlowStep`, `restAfterSet`, `restSecFor`, `ownSetRest`, `warmupRestSecFor`, `nextUnfinishedUnit` (`supersetFlow.js`); `setUnits`, `supersetUnits`, `cascadeWeight`, `removeLastSet`, `bestWeightForEntry`, `stepEffort`, `effortOf`, `EFFORT`, `repStep`, `lastBW`, `modeOf` (`history.js`); `stepWeight`, `weightIncrement` (`progression.js`); `stepOwned` (`dumbbells.js`); `hasCompletedWork` e as leituras de série de `workout-model.js`; `REST_MAX` (`duration.js`); `draftOf` (`state-core.js`); `uid`, `isoOf` (`format.js`); `t` (`i18n-core.js`).
- Produces:
  - `step(S, action, now) → { state, effects, result }`: `S` é o documento, `now` um número em ms. Devolve o documento novo (o mesmo objeto quando nada mudou), a lista de efeitos e o resultado da ação. Não carimba: quem carimba é o `session.js` (Task 4). Uma ação inválida lança `TypeError` e não muda nada.
  - O descanso fica em `S.active.rest`: `{ endsAt, total, forIdx, forSet, kind: 'rest' }` ou `null` (escolha 13).
  - As ações desta Task (`type` e os campos):
    - `start { routineIds, id? }` → `result: { id }`. Faz o que o `beginWorkout` do `sheets.jsx:3121` faz: `active = { id: id ?? uid(), d: isoOf(new Date(now)), start: now, routineIds, name, bw, cur: 0, entries, workoutView: S.workoutView ?? 'cards', rest: null }`, com as entradas do `buildCombinedEntries(S, routineIds)`, o nome do `deriveSessionName` (sem rotina, `t('Freestyle')`) e o `bw` do `lastBW(S)` ou `null` (escolha 12). Com um treino já em andamento, lança `TypeError`.
    - `set.mark { entry, set, done }`: põe a série no estado pedido. Igual ao estado de agora, nada muda e não há efeito (Foco da revisão 3). Marcar faz o que o `toggle` do `views/Workout.jsx:1776-1908` faz, sem o som, a vibração e os avisos: `done: true`, `at: now`, tira o `planSec`, grava o `topW` quando o exercício fica todo feito, começa o descanso (o tempo do `restSecFor` com o descanso próprio da série e o do aquecimento, como lá; o superset pelo `supersetFlowStep`, que só descansa no fim da volta; o exercício simples pelo `restAfterSet`) e move o `cur` como lá. Uma série com lados, drop set ou rest-pause é marcada inteira (Foco da revisão 4). Desmarcar tira o `done` e o `at`; se o descanso era desta série, ele acaba.
    - `set.update { entry, set, fields }`: só `w`, `r`, `sec`, `rir` e `rpe`, e só a do esforço do perfil (`effortOf(S)`). `null` apaga o campo; `w` grava `weightOrigin: 'manual'` e passa pela cascata do `cascadeWeight` com o `backoffStep` do alvo, como o `setField` (`Workout.jsx:1275-1288`); `sec` apaga o `planSec`. Os limites: `w` de 0 a 1.000, `r` de 0 a 100, `sec` de 1 a 3.600 e o esforço no `EFFORT` da escala, de 0,5 em 0,5; fora deles, `TypeError`. Mudar o esforço não marca a série (escolha 7).
    - `set.step { entry, set, field, direction }`: `field` é `w`, `r`, `sec` ou `effort`, e `direction` é `up` ou `down`. A carga passa pelo `stepOwned` quando o exercício tem pesos próprios e pelo `stepWeight` com o `weightIncrement` do alvo nos outros, como o `bump` (`Workout.jsx:326-338`); as repetições, pelo `repStep`; os segundos, de 5 em 5; o esforço, pelo `stepEffort`. É o passo que as entradas do HexDesign pedem (a entrada não decide o passo).
    - `set.add { entry }`: uma série nova como o `addSet` (`Workout.jsx:1290-1313`). `set.remove { entry, set }`: deixa pelo menos uma série, e o descanso da série removida acaba, como o `deleteActiveSet` (`Workout.jsx:858-886`).
    - `focus { entry }`: troca o `cur`.
    - `rest.adjust { by }`: `by` é `15` ou `-15`, como o `addRest` (`store/useUI.js:336-354`): soma ao `endsAt` e ao `total`, com o teto do `REST_MAX`; quando sobra 0 s ou menos, o descanso acaba. `rest.skip`: o descanso acaba. Sem descanso, as duas não mudam nada.
  - Os efeitos (objetos `{ type, … }`, na ordem em que acontecem):
    - `{ type: 'haptic', kind: 'setLogged' }` ao marcar;
    - `{ type: 'rest.started', endsAt, total }` e `{ type: 'rest.cleared' }`;
    - `{ type: 'workout.complete' }` quando a última série do treino fica feita;
    - `{ type: 'activity.start' }`, `{ type: 'activity.update' }` (depois de toda ação que mudou o treino) e `{ type: 'activity.end' }` (Task 3).
  - O cabeçalho do arquivo lista as linhas do openGym que cada ação reproduz.

- [ ] **Step 1: Write the failing tests** em `session-controller.test.js`, 18 testes, com documentos do `freshState` e rotinas montadas no próprio teste:
  1. `start` de uma rotina monta o `active` como o `beginWorkout` (cada chave do objeto acima, as entradas iguais às do `buildCombinedEntries`), e o efeito é `activity.start`;
  2. `start` com duas rotinas dá o nome "A + B", e com `[]` dá o `t('Freestyle')` e `entries: []`;
  3. `start` com um treino em andamento lança `TypeError`;
  4. `set.mark` com `done: true` grava `done`, `at === now`, tira o `planSec`, e dá `haptic setLogged`, `rest.started` com `endsAt === now + 1000 * restSec` e `activity.update`;
  5. `set.mark` com `done: false` tira o `done` e o `at`, e o descanso daquela série acaba com `rest.cleared`;
  6. `set.mark` com o estado que a série já tem devolve o mesmo objeto `S` e nenhum efeito;
  7. a última série de um exercício grava o `topW` do `bestWeightForEntry` e leva o `cur` ao próximo exercício por terminar;
  8. num superset de dois, marcar a série do primeiro não começa descanso e leva o `cur` ao segundo; marcar a do segundo começa o descanso do grupo (o `sgRest`, ou o maior do grupo);
  9. com `restSec: 0` no perfil não há descanso; o descanso próprio da série e o do aquecimento valem como no `restSecFor`;
  10. a última série do treino dá `workout.complete` e nenhum descanso;
  11. `set.update` de `w` grava `weightOrigin: 'manual'` e leva a carga às séries seguintes não feitas; `null` apaga; `w: 1001` lança;
  12. `set.step` sobe a carga pelo incremento do exercício, as repetições pelo `repStep` e o esforço pelo `stepEffort` na escala do perfil; o esforço da outra escala lança;
  13. `set.add` dá a série como o `addSet`; `set.remove` nunca deixa o exercício sem série, e o descanso da série removida acaba;
  14. `focus` troca o `cur`, e um índice fora lança;
  15. `rest.adjust` com `15` e `-15` muda o `endsAt` e o `total`, para no `REST_MAX`, e acaba quando chega a 0; `rest.skip` acaba; sem descanso, nenhuma muda nada;
  16. um `active` do openGym com aquecimento, drop set, rest-pause, lados, cardio, série com tempo, pirâmide e `noProg` (montado com as formas dos testes do lib, como `failure-sets.test.js` e `unilateral-integration.test.js`): cada linha é marcada inteira, e fora dos campos que a ação mexeu o objeto continua igual campo a campo (Foco da revisão 4);
  17. com o `Date.now` trocado por uma função que lança (`vi.spyOn`), todas as ações desta Task rodam;
  18. o `S` de entrada, congelado por inteiro antes (`Object.freeze` profundo), passa por todas as ações sem erro.
- [ ] **Step 2: Run** `cd frontend && npx vitest run src/lib/session-controller.test.js`. Expected: falham.
- [ ] **Step 3: Implement** `step` e as ações acima em `session-controller.js`, com uma tabela `ACTIONS` como a do `actions.js` do HexEngine.
- [ ] **Step 4: Run** `cd frontend && npx vitest run src/lib/session-controller.test.js && npm test`. Expected: passam.
- [ ] **Step 5: Generate and check** Run: `node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs scripts engine load packages`. Expected: tudo passa; a parte `engine` cresce 18 (o teste novo cai na escolha do `vitest.hexengine.config.js`, porque só importa módulos do motor; se não cair, o PR diz por quê e a Task não entra).
- [ ] **Step 6: Commit** "O controlador do treino: começar, as séries e o descanso".

---

### Task 2: O controlador: exercícios no meio do treino

**Depende de:** Task 1.

**Files:**
- Modify: `frontend/src/lib/session-controller.js`, `session-controller.test.js`, o script do motor gerado

**Interfaces:**
- Consumes: `buildSessionEntry` (`session-start.js`), `insertionIndexAfterCurrentUnit` (`supersetFlow.js`), `swapActiveExercise` (`active-exercise-swap.js`), `cleanupSg` (`history.js`), `EXIDX` e `pickedExerciseConfig` (`exercises.js`, `history.js`).
- Produces (ações novas no `step`):
  - `exercise.add { exerciseIds }`: como o "adicionar exercício" do `Workout.jsx:1518-1557`: cada um montado pelo `buildSessionEntry` com o `pickedExerciseConfig`, inseridos na ordem, depois da unidade atual (`insertionIndexAfterCurrentUnit`), com o `rid` da entrada atual e `addedInSession: true`; o `cur` vai para o primeiro deles, e o `forIdx` do descanso acompanha o deslocamento. Um id que não é exercício (nem do catálogo nem personalizado) lança `TypeError`.
  - `exercise.replace { entry, exerciseId, confirmLogged?, group? }`: pelo `swapActiveExercise`. Sem séries feitas, troca no lugar. Com séries feitas e sem `confirmLogged`, não muda nada e devolve `result: { needs: 'confirmLogged' }`; com ele, a troca entra ao lado, como lá. Dentro de um superset sem `group`, devolve `result: { needs: 'group' }`; `group` é `keep` ou `detach`. Antes da troca, o descanso daquele exercício acaba.
  - `exercise.remove { entry }`: como o `removeActiveExercise` (`Workout.jsx:923-942`): tira a entrada, passa o `cleanupSg`, ajusta o `cur`; se o descanso era dela, acaba; se era de outra, o `forIdx` acompanha. Tirar o último exercício deixa `entries: []`, e o treino continua.

- [ ] **Step 1: Write the failing tests**, 8 testes no mesmo arquivo: `exercise.add` de um id entra depois da unidade atual, com o `rid` e o `addedInSession`, e o `cur` vai para ele; com três ids, eles entram na ordem; o `forIdx` de um descanso que estava depois do ponto de inserção acompanha; `exercise.replace` sem séries feitas troca no lugar; com séries feitas, sem `confirmLogged`, devolve `needs: 'confirmLogged'` e o mesmo `S`, e com ele a troca entra ao lado; num superset, sem `group` devolve `needs: 'group'`, e com `detach` o novo sai do grupo; `exercise.remove` tira, limpa o superset desfeito e ajusta o `cur` e o descanso; um id desconhecido em `exercise.add` lança.
- [ ] **Step 2: Run** `cd frontend && npx vitest run src/lib/session-controller.test.js`. Expected: os 8 novos falham.
- [ ] **Step 3: Implement** as três ações.
- [ ] **Step 4: Generate and check** Run: `cd frontend && npm test && cd .. && node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs scripts engine load packages`. Expected: tudo passa, e a parte `engine` cresce 8.
- [ ] **Step 5: Commit** "O controlador do treino: adicionar, trocar e remover exercícios no meio".

---

### Task 3: O controlador: o fim do treino, com recordes e progressão

**Depende de:** Task 2.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 9, na parte que é do motor: o que o resumo traz.

**Files:**
- Modify: `frontend/src/lib/session-controller.js`, `session-controller.test.js`, o script do motor gerado

**Interfaces:**
- Consumes: `buildCompletedWorkout`, `sessionEnd` (`finish-workout.js`); `beatsWeight`, `betterWeight` (`exercises.js`); `bestWeightFor`, `bestWeightForEntry`, `workoutVolume`, `sessionVolume`, `setsDone`, `workSetsDone` (`history.js`); `is1RMRecord` (`onerm.js`); `finishCompare` (`finish-compare.js`); `routineAdditions` (`session-routines.js`); `refillAfter` (`rotation.js`); `exerciseNameFor` (`i18n-core.js`).
- Produces (ações novas no `step`):
  - `finish {}`: o que o `doFinishWorkout` (`sheets.jsx:3738-3798`) faz num treino que não é passado, com o `now` em todo lugar que lá usa o relógio: os recordes de carga (`prs`, pelo `beatsWeight` contra o `bestWeightFor` de antes, só com séries feitas que não são aquecimento) e os de 1RM estimado fora deles (`is1RMRecord`); `w = buildCompletedWorkout(active, { end: sessionEnd(active, now), prs, snapshotFor })` com `w.vol = workoutVolume(w)`; o `exWeights` de cada exercício que bateu o melhor; `workouts.push(w)`; `active = null`; e o `refillAfter(S, w, hoje, now)`. Sem nenhuma série feita, não grava nada, o treino continua e o resultado é `{ empty: true }` (o "Terminar" da tela pergunta antes, Task 11).
  - O resultado do `finish` (o que a tela do resumo mostra):

```js
{ id, name, start, end, durationMs, volume /* sessionVolume(w, S) */, unit,
  sets: { done /* setsDone(w) */, work /* workSetsDone(w) */ },
  prs: [{ id, name, w }], e1rm: [{ id, name, e1rm }],
  compare: [{ id, name, today, last, trend, next: { w, r, sets, kind } }],   // finishCompare(S depois, w)
  additions /* routineAdditions(active, S.routines) */ }
```

  - `discard {}`: `active = null`, sem treino salvo.
  - Os efeitos: `finish` e `discard` dão `rest.cleared` (quando havia descanso) e `activity.end`; `finish` com algum recorde dá `{ type: 'haptic', kind: 'record' }`, e todo `finish` que grava dá `{ type: 'workout.finished', id }`.

- [ ] **Step 1: Write the failing tests**, 9 testes no mesmo arquivo:
  1. `finish` grava o treino como o `doFinishWorkout`: o objeto do `buildCompletedWorkout` com o `vol`, no fim de `workouts`, `active: null`, o `exWeights` e o `refillAfter`;
  2. os recordes de carga: entra o exercício que bateu o melhor de antes; o aquecimento não conta; numa máquina assistida, a carga menor é o recorde;
  3. um recorde de 1RM estimado de um exercício que não está nos `prs` vai para o `e1rm`;
  4. o resultado traz a duração, o volume, as séries feitas e de trabalho, os recordes com o nome no idioma, e o `compare` igual ao `finishCompare`;
  5. a progressão aplicada: uma rotina linear 3×5 a 60 kg, com as três séries feitas, dá `next.w` de 62,5 no `compare` e um `start` seguinte com 62,5 kg nas séries; com uma série que falhou, os dois ficam em 60 kg;
  6. passa da meia-noite (Foco da revisão 2): começo às 23:50 e última série às 00:35 dão o `d` do dia do começo e o `end` da última série; 25 minutos sem série no fim não entram no `end`;
  7. sem nenhuma série feita, `finish` devolve `{ empty: true }` e o mesmo `S`; `discard` deixa `active: null` sem gravar treino; os dois dão `activity.end`, e o `rest.cleared` só com descanso (Foco da revisão 5);
  8. o `haptic record` sai só com recorde, e o `workout.finished` traz o id do treino gravado;
  9. a sessão com `noProg` sai com `excludeFromProgression`, como no openGym.
- [ ] **Step 2: Run** `cd frontend && npx vitest run src/lib/session-controller.test.js`. Expected: os 9 novos falham.
- [ ] **Step 3: Implement** `finish` e `discard`.
- [ ] **Step 4: Generate and check** Run: `cd frontend && npm test && cd .. && node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs scripts engine load packages`. Expected: tudo passa, e a parte `engine` cresce 9.
- [ ] **Step 5: Commit** "O controlador do treino: o fim, com os recordes e a próxima carga".

---

### Task 4: O treino no motor e as leituras das telas

**Depende de:** Task 3.

**Files:**
- Create: `apple/Packages/HexEngine/JS/session.js`, `session.test.mjs`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Session.swift`, `Tests/HexEngineTests/SessionTests.swift`
- Modify: `runtime.js`, o script do motor gerado, `scripts/hexgym/engine-load.mjs` (o tick pela ação do controlador), `scripts/hexgym/engine-cases.mjs` e os três arquivos de `Tests/HexEngineTests/Cases/` (gravados de novo pelo `record-engine-cases.mjs`)

**Interfaces:**
- Consumes: `step` (Tasks 1 a 3), `draftOf`, `stampChange`, `effectiveRoutineIds`, `nextTrainingDay`, `streakWeeks`, `weekTally`, `workoutDay`, `workoutDuration`, `setsDone`, `exerciseNameFor`, `t`, `weekOrder`, `weekStartOf`.
- Produces (JS, entra e sai texto JSON, exportado pelo `runtime.js`):
  - `sessionApply(actionJson, now)` → `{ changed, effects, result }`: roda o `step` no documento aberto e, se ele mudou, carimba como o `apply` do `actions.js` (`S._ts = stampChange(prev, S, now)`) e troca o `current`.
  - `activeWorkout(now)` → `null` ou o modelo da tela do treino:

```js
{ id, name, start, unit, effort /* 'none' | 'rir' | 'rpe' */, cur, done, total,
  rest: null | { endsAt, total, forIdx, forSet, remaining /* s, nunca < 0 */ },
  next: null | { entry, set },                 // a série que o "Série feita" marca
  entries: [{ index, id, name, known, mode, sg, sgLetter /* 'A', 'B'... ou null */,
              target /* "3 × 8 · 60 kg" */, increment,
              sets: [{ index, w, r, sec, rir, rpe, done, warmup, kind /* normal | drop | restpause | sides | cardio */, line /* "60 kg × 8" */ }] }] }
```

  - `home(now)` → `{ today: { date, status /* planned | rest | none | done */, routines: [{ id, name, glyph }] }, active: null | { name, start, done, total }, week: [{ day, date, trained, planned, today }] /* 7, na ordem do weekStart */, streakWeeks, weekCount, total, last: null | { id, name, d, durationMs, sets } }`, com o `effectiveRoutineIds(S, hoje, hoje)` e o hoje tirado do `now`. Uma função do lib que só lê o relógio por dentro (o `streakWeeks`, por exemplo) roda como está, e o teste prende o resultado com o relógio falso do `node --test` (`mock.timers`).
  - `liveActivity(now)` → `null` ou `{ name, exercise, setLine, done, total, restEndsAt, restTotal, ahead: [{ entry, set, exercise, setLine, restAfter }] }`: as próximas 8 séries por fazer na ordem do treino (o `LIVE_AHEAD` do openGym), com o descanso que vem depois de cada uma, para a Live Activity avançar sozinha (Task 14). O JSON passa de 3.600 bytes nunca: os nomes são cortados em 40 letras e o `ahead` encolhe até caber (o orçamento do openGym, `lib/live-activity.js`).
  - `liveEvents(eventsJson, now)` → `{ applied, effects }`: cada evento é `{ id, wid, kind: 'set.done' | 'rest.skip' | 'rest.adjust', entry?, set?, by? }`; aplica cada um uma vez só, pelo `id`, guardado em `active.liveSeen` (os últimos 64); evento de outro treino (`wid` diferente do `active.id`) ou sem treino é ignorado. `set.done` vira `set.mark` com `done: true` (Foco da revisão 3).
- Produces (Swift, em `Session.swift`):

```swift
public enum SessionAction: Encodable, Sendable {
  case start(routineIDs: [String], id: String?)
  case markSet(entry: Int, set: Int, done: Bool)
  case updateSet(entry: Int, set: Int, fields: SetFields)
  case stepSet(entry: Int, set: Int, field: SetField, direction: SessionStep)
  case addSet(entry: Int), removeSet(entry: Int, set: Int), focus(entry: Int)
  case addExercises([String]), replaceExercise(entry: Int, exerciseID: String, confirmLogged: Bool, group: String?), removeExercise(entry: Int)
  case adjustRest(by: Int), skipRest, finish, discard
}
public struct SetFields: Codable, Equatable, Sendable { public var w: Double?; public var r: Int?; public var sec: Int?; public var rir: Double?; public var rpe: Double? }
public enum SetField: String, Codable, Sendable { case w, r, sec, effort }
public enum SessionEffect: Decodable, Equatable, Sendable {
  case haptic(String), restStarted(endsAt: Date, total: Int), restCleared, workoutComplete
  case activityStart, activityUpdate, activityEnd, workoutFinished(id: String)
}
public struct SessionOutcome: Decodable, Equatable, Sendable { public let changed: Bool; public let effects: [SessionEffect]; public let result: JSONValue? }
public struct FinishSummary: Codable, Equatable, Sendable { /* os campos do resultado do finish da Task 3 */ }
public struct ActiveWorkout: Codable, Equatable, Sendable { /* o modelo do activeWorkout */ }
public struct HomeSummary: Codable, Equatable, Sendable { /* o modelo do home */ }
public struct LiveActivityModel: Codable, Equatable, Sendable { /* o modelo do liveActivity */ }
public struct LiveEvent: Codable, Equatable, Sendable { public let id: String, wid: String, kind: String; public let entry: Int?, set: Int?, by: Int? }
extension HexEngine {
  public func session(_ action: SessionAction, now: Date = .now) throws -> SessionOutcome
  public func activeWorkout(now: Date = .now) throws -> ActiveWorkout?
  public func home(now: Date = .now) throws -> HomeSummary
  public func liveActivity(now: Date = .now) throws -> LiveActivityModel?
  public func liveEvents(_ events: [LiveEvent], now: Date = .now) throws -> [SessionEffect]
}
```

  O `SessionStep` é um `enum SessionStep: String, Codable, Sendable { case up, down }` do próprio motor, porque o HexEngine não importa o HexDesign; a tela converte o `StepDirection` das entradas. O `FinishSummary` decodifica o `result` do `finish` por um `func finishSummary(from: SessionOutcome) throws -> FinishSummary?`.

- [ ] **Step 1: Write the failing tests** em `session.test.mjs`, 8 testes:
  1. `sessionApply` carimba: o `active` mexido ganha o `_ts` do `now`, e as rotinas ficam com o de antes;
  2. uma ação inválida lança e o documento fica igual (`document()` antes e depois);
  3. `activeWorkout` de um treino de PPL tem os nomes em pt-BR, as linhas "60 kg × 8", o `sgLetter` do superset, o `next` e o `done`/`total` certos; sem treino, `null`;
  4. `home` com a semana do PPL dá `planned` na segunda com as rotinas, `rest` no domingo, `done` depois de um treino no dia, os 7 dias na ordem do `weekStart`, e o `last`; sem rotinas e sem histórico, `none`, `streakWeeks: 0` e `last: null` (Foco da revisão 5);
  5. `liveActivity` traz o exercício, a linha da série, o descanso e até 8 próximas séries com o `restAfter`; com nomes de 70 letras, o JSON fica com menos de 3.600 bytes;
  6. `liveEvents` com o mesmo `set.done` duas vezes marca uma vez; um `set.done` de uma série já feita não muda nada; um evento de outro `wid` é ignorado (Foco da revisão 3);
  7. um documento com um treino e um descanso gravados, aberto pelo `restore` 30 s depois, dá o `rest.remaining` 30 s menor; aberto depois do `endsAt`, `remaining: 0` (Foco da revisão 1);
  8. um treino inteiro pelo `sessionApply` (começar, marcar tudo, terminar) deixa o treino no `workouts` e o `home` com `done`.
- [ ] **Step 2: Write the failing Swift tests** em `SessionTests.swift`, 3 testes: o Encodable de cada `SessionAction` dá o JSON que o `session.js` espera; `start` e `markSet` no JavaScriptCore dão os efeitos decodificados certos e o `activeWorkout` com a série feita; o `finish` decodifica o `FinishSummary`.
- [ ] **Step 3: Write the recorded cases** em `engine-cases.mjs`, 2 casos, pelo `call` do `session-controller.js#step`: começar o dia de PPL e terminar um treino que passa da meia-noite (Foco da revisão 2). Run: `node scripts/hexgym/record-engine-cases.mjs`. Expected: os três arquivos de `Cases/` ganham os dois casos.
- [ ] **Step 4: Run** `node --test apple/Packages/HexEngine/JS/session.test.mjs` e o comando do pacote do HexEngine com `--filter SessionTests`. Expected: falham.
- [ ] **Step 5: Implement** `session.js`, as exportações do `runtime.js` e o `Session.swift`.
- [ ] **Step 6: The tick goal**: no `engine-load.mjs`, a medida do tick (linhas 228 a 282) passa a marcar a série pelo `sessionApply` com `set.mark`, com a mesma meta `TICK_MS` (30 ms) e o mesmo documento de 1.040 treinos. Run: `node scripts/hexgym/engine-load.mjs`. Expected: as 7 metas passam, e o PR diz o tempo do tick antes e depois.
- [ ] **Step 7: Generate and check** Run: `node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `engine` cresce 8, a `packages` 3 e a `load` fica em 7.
- [ ] **Step 8: Commit** "O treino no motor: as ações, os efeitos e as leituras das telas".

---

### Task 5: O histórico no motor

**Depende de:** Task 4.

**Files:**
- Create: `apple/Packages/HexEngine/JS/workouts.js`, `workouts.test.mjs`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Workouts.swift`, `Tests/HexEngineTests/WorkoutsTests.swift`
- Modify: `runtime.js`, `actions.js` (a ação `workout.delete`), `Actions.swift` (o caso novo), o script do motor gerado

**Interfaces:**
- Consumes: `workoutDay`, `workoutDuration`, `sessionVolume`, `setsDone`, `workSetsDone` (`history.js`), `sameWorkout`, `legacySyncKey` (`workout-date.js`), `exerciseNameFor`, `t`.
- Produces:
  - JS: `history(queryJson)` com `{ before?: <chave>, limit }` → `{ items: [{ key, id, d, name, start, end, durationMs, sets, volume, unit, prs }], more }`, do mais novo para o mais antigo (pelo `workoutDay` e depois o `start`), com a `key` igual à do `sameWorkout`: o `id`, ou o `legacySyncKey` quando o treino é antigo e não tem `id` (a mesma regra do `keyOf` do `session-edit.js`, porque o `syncKeyOf` não é exportado); `workoutDetail(key)` → `null` ou `{ key, name, d, start, end, durationMs, volume, unit, note, prs, entries: [{ id, name, known, sg, sgLetter, sets: [{ line, done, warmup, pr }] }] }`.
  - A ação `workout.delete { key }` no `actions.js`: tira o treino pelo `sameWorkout`, como o "Apagar treino" do `sheets.jsx:2931`, carimbada pelo `apply`; uma `key` que não existe lança `TypeError`.
  - Swift: `WorkoutSummary`, `WorkoutDetail` e `HistoryPage` (`Codable`), `func history(before: String?, limit: Int) throws -> HistoryPage`, `func workoutDetail(_ key: String) throws -> WorkoutDetail?`, e `EngineAction.deleteWorkout(key: String)`.

- [ ] **Step 1: Write the failing tests** em `workouts.test.mjs`, 5 testes: a lista vem do mais novo para o mais antigo, em páginas de `limit` com o `more` certo; o item traz a duração, as séries, o volume e os recordes; o detalhe traz as linhas, o aquecimento marcado e a série do recorde; um treino antigo sem `id` aparece, abre e é apagado pela `key`, sem levar os outros sem `id` junto (o comentário do `sheets.jsx:2929`); `workout.delete` carimba e uma `key` desconhecida lança. Em `WorkoutsTests.swift`, 2 testes: a lista e o detalhe decodificam no JavaScriptCore; `deleteWorkout` tira o treino.
- [ ] **Step 2: Run** `node --test apple/Packages/HexEngine/JS/workouts.test.mjs` e o comando do pacote com `--filter WorkoutsTests`. Expected: falham.
- [ ] **Step 3: Implement** `workouts.js`, a ação e o `Workouts.swift`.
- [ ] **Step 4: Generate and check** Run: `node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `engine` cresce 5 e a `packages` 2.
- [ ] **Step 5: Commit** "O histórico no motor: a lista, o detalhe e apagar um treino".

---

### Task 6: O treino no app: o modelo, os efeitos e os documentos preparados

**Depende de:** Task 4.

**Files:**
- Create: `apple/HexGym/Workout/WorkoutSession.swift`, `apple/HexGym/Workout/SessionEffects.swift`, `apple/HexGym/Workout/RestAlerts.swift`
- Create: `apple/HexGym/Fixtures/FixtureLoader.swift` e os documentos `semana-ppl.json`, `treino-em-andamento.json`, `descanso.json`, `vazio.json` e `veio-do-opengym.json`
- Create: `apple/HexGymTests/WorkoutSessionTests.swift`, `FixtureLoaderTests.swift`
- Modify: `apple/HexGym/AppModel.swift`, `apple/HexGym/HexGymApp.swift`, `docs/hexgym/design-system/movimento-e-haptico.md`

**Interfaces:**
- Consumes: `HexEngine.session`, `activeWorkout`, `home`, `liveActivity`, `AppModel.perform`, `AppModel.revision`, `HexHaptic`.
- Produces:

```swift
@Observable @MainActor final class WorkoutSession {
  init(model: AppModel, alerts: RestAlerts, activity: WorkoutActivityControlling)
  private(set) var workout: ActiveWorkout?          // lido de novo depois de cada ação e de cada revision
  private(set) var lastFinish: FinishSummary?
  private(set) var haptic: HexHaptic?               // as telas tocam com .sensoryFeedback(trigger:)
  private(set) var hapticTick: Int                  // sobe a cada háptico, para o trigger mudar
  func refresh() async
  func perform(_ action: SessionAction) async throws -> SessionOutcome
}
protocol RestAlerts: Sendable {                      // o de verdade é da Task 9
  func schedule(at: Date, title: String, body: String) async
  func cancel() async
}
protocol WorkoutActivityControlling: Sendable {     // o de verdade é da Task 13
  func start(_ model: LiveActivityModel, workoutID: String, start: Date) async
  func update(_ model: LiveActivityModel) async
  func end() async
}
```

  - O `perform` passa a ação pelo `AppModel` (o motor e a gravação de 0,5 s da fase 2, com o `flush()` na ida para o fundo) e executa os efeitos pelo `SessionEffects`, na ordem: `haptic` muda o `haptic` e o `hapticTick`; `rest.started` agenda o aviso no `endsAt` (o texto é da Task 9; até lá, o título "Descanso acabou" e o corpo vazio); `rest.cleared` cancela; `activity.*` chama o `WorkoutActivityControlling` com o `liveActivity()` lido depois da ação. Até a Task 9 e a 13, o app usa um `RestAlerts` e um `WorkoutActivityControlling` que não fazem nada.
  - Ao abrir o app com um treino em andamento, o `refresh` agenda o aviso para o resto do descanso, se o `endsAt` ainda não passou, e não agenda nada se passou (Foco da revisão 1).
  - `AppModel` ganha `var session: WorkoutSession` e uma `func perform(_ action: SessionAction) async throws -> SessionOutcome`, com a mesma gravação do `perform` das ações.
  - O `FixtureLoader`: com `-HexGymFixture <nome>` num build Debug, o `AppModel.live()` usa um `DocumentStore` numa pasta temporária nova e grava nela o documento preparado antes de abrir. O relógio do documento é trocado na carga: o arquivo traz a chave `_fixtureNow`, e o carregador soma `agora − _fixtureNow` a todo `start`, `at` e `endsAt` do `active` e tira a chave. Os documentos: `semana-ppl` (as três rotinas do PPL na semana, 12 treinos em quatro semanas, hoje é dia de Push), `treino-em-andamento` (o Push com 5 séries feitas e um superset no meio), `descanso` (o mesmo, com 75 s de descanso pela frente), `vazio` (o documento novo) e `veio-do-opengym` (um `active` com as formas da Foco da revisão 4). Nenhum documento preparado entra no build Release.
  - `-HexGymWorkout YES` abre a tela do treino quando há um em andamento (a Task 8 liga).
  - O `movimento-e-haptico.md` passa a dizer que o `setLogged` toca ao marcar a série.
  - A medida da gravação: o PR mede o `DocumentStore.save` com o documento de 1.040 treinos do `engine-load.mjs` no simulador (o pior de 20 gravações). A meta é 50 ms, metade do toque de 100 ms (escolha recomendada, com a delegação do Lipe de 03/11/2026); se passar, a Task troca a leitura do `state.json` inteiro a cada gravação (a linha 106 do plano da fase 0) por um `rename` para a cópia anterior e mede de novo.

- [ ] **Step 1: Write the failing tests**, 8 testes: `WorkoutSessionTests`, 6, com o motor de verdade, um `DocumentStore` numa pasta temporária e um `RestAlerts` e um `WorkoutActivityControlling` falsos que guardam as chamadas: `start` publica o `workout` e chama o `start` da Live Activity; `markSet` muda o `haptic` para `.setLogged` e agenda o aviso no `endsAt`; `skipRest` cancela; `finish` limpa o `workout`, guarda o `lastFinish` e chama o `end`; um documento com descanso que ainda não acabou agenda o aviso no `refresh`, e um com o descanso acabado não agenda (Foco da revisão 1); duas marcações em menos de 0,5 s gravam o documento uma vez. `FixtureLoaderTests`, 2: os cinco documentos abrem no motor; o relógio do `descanso` deixa 75 s pela frente.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o `WorkoutSession`, os efeitos, o `AppModel` e os documentos preparados.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 8. O PR diz a medida da gravação.
- [ ] **Step 5: Commit** "O treino no app: o modelo, os efeitos e os documentos preparados".

---

### Task 7: As abas novas e a tela inicial

**Depende de:** Task 6.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** as escolhas 1 e 2, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Home/HomeView.swift`, `HomeModel.swift`, `WeekStrip.swift`
- Create: `apple/HexGymTests/HomeModelTests.swift`
- Modify: `apple/HexGym/RootView.swift` (as cinco abas; a do Histórico mostra um `ContentUnavailableView` até a Task 12), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.home(now:)`, `WorkoutSession`, `engine.routines()`, `SlantedSegments`, `HexGlassCard`, `.hexPrimary(size: .large)`.
- Produces:
  - `RootTab` ganha `home = "inicio"` e `history = "historico"`, na ordem da escolha 1, e o Início passa a ser a aba de partida. Os símbolos: `house` (Início) e `clock.arrow.circlepath` (Histórico).
  - `HomeView`: o cartão de hoje ("Hoje", o nome das rotinas e os exercícios delas; "Hoje é dia de descanso"; "Nada marcado para hoje"; "Treino de hoje feito"); o botão "Começar treino" (que, até a Task 8, começa o treino e não abre tela nenhuma) ou o cartão "Treino em andamento" com o nome, o tempo que passa (`TimelineView`) e "5 de 18 séries", com o botão "Continuar treino"; "Outro treino" num `Menu` com as rotinas e "Treino livre"; a semana (`WeekStrip`: 7 segmentos inclinados com a letra do dia embaixo, cheio no dia treinado, contornado no planejado, e o hoje marcado); "Sequência: 3 semanas" e "2 treinos nesta semana"; e "Último treino" com o nome, a data e a duração, que, até a Task 12, não abre nada.
  - Sem rotinas: o cartão de hoje diz "Monte a sua primeira rotina", com o botão para a aba Rotinas, e "Começar treino" vira "Começar treino livre".
  - `struct HomeModel`: os textos e as decisões da tela, a partir do `HomeSummary` (o título do cartão por `status`, o rótulo do botão, "5 de 18 séries", "Sequência: 1 semana" no singular, as letras dos dias na ordem do `weekStart`, o texto do VoiceOver da semana: "Semana: segunda, treinou; terça, planejado; ...").

- [ ] **Step 1: Write the failing tests** em `HomeModelTests.swift`, 5 testes: o título e o botão para cada `status`; com treino em andamento, "Continuar treino" e "5 de 18 séries"; o singular e o plural da sequência e dos treinos da semana nos dois idiomas; as letras e a fala da semana com o `weekStart` 0 e 1; sem rotinas e sem histórico, "Monte a sua primeira rotina" e "Começar treino livre" (Foco da revisão 5).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** as abas, a tela e o modelo.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 5.
- [ ] **Step 5: Prints**: o Início com `semana-ppl` no Ultravioleta e no Cobre, com `treino-em-andamento`, com `vazio`, e o Início em AX5 (`-HexGymTab inicio -HexGymSkipOnboarding YES -HexGymFixture <nome>`).
- [ ] **Step 6: Commit** "A tela inicial e as abas Início e Histórico".

---

### Task 8: A tela do treino e a transição de "Começar treino"

**Depende de:** Task 7.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** as escolhas 3 e 4, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Workout/WorkoutView.swift`, `ExerciseCard.swift`, `SetRow.swift`, `CurrentSetPanel.swift`, `WorkoutScreenModel.swift`
- Create: `apple/HexGymTests/WorkoutScreenModelTests.swift`
- Modify: `apple/HexGym/Home/HomeView.swift`, `apple/HexGym/RootView.swift` (o `fullScreenCover` do treino e o `-HexGymWorkout YES`), `apple/HexGym/Routines/RoutineEditorView.swift` (o "Começar" na barra), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `WorkoutSession`, `ActiveWorkout`, `SessionAction`, `LoadInput`, `RepsInput`, `EffortInput`, `WorkoutInputLayout`, `SlantedSegments`, `HexGlassCard`, `StartWorkoutTransition` (`hexStartWorkoutSource` e `hexStartWorkoutDestination`), `.sensoryFeedback`.
- Produces:
  - A transição: o "Começar treino" e o "Continuar treino" do Início e o "Começar" do editor de rotina são a origem do zoom (`hexStartWorkoutSource`), e a tela do treino, num `fullScreenCover` do `RootView`, é o destino (`hexStartWorkoutDestination`, que já cuida do Reduzir Movimento). O estado do treino mora no `WorkoutSession`, fora da view (a tela recomeça quando o Reduzir Movimento muda com ela aberta, `StartWorkoutTransition.swift`). Se o zoom do HexDesign não pegar no `fullScreenCover`, a Task o estende no próprio HexDesign, com um teste no `MotionTests`, e o PR diz.
  - `WorkoutView`: o cabeçalho (o nome, o tempo que passa em `.hexFont(.number)` por `TimelineView(.periodic(from:by: 1))`, os `SlantedSegments(total:done:)` das séries e o botão "Terminar", que até a Task 11 só fecha a tela); a lista dos `ExerciseCard` (o nome, o `target` em `.secondary`, as séries em `SetRow`, a série atual destacada pela cor do tema, a marca do superset na lateral com "Superset A"); o `CurrentSetPanel` fixo embaixo, sobre o vidro: "Supino reto · Série 2 de 3", as entradas (no modo reps, `LoadInput` e `RepsInput`; no modo tempo, um `Stepper` da Apple de segundos, de 5 em 5; o `EffortInput` quando o perfil usa esforço), dispostas pelo `WorkoutInputLayout`, e o botão "Série feita" (`.hexPrimary(size: .large)`). Cada passo das entradas manda `stepSet` ao motor; o "Série feita" manda `markSet(done: true)` para o `next`. Tocar numa `SetRow` faz dela a série atual (um `focus` e o painel nela); a marca de feita da linha manda `markSet` com o contrário do que ela está. Uma linha de drop set, rest-pause, lados ou cardio mostra o texto do motor e só a marca de feita (escolha 12, Foco da revisão 4).
  - O háptico: `.sensoryFeedback` com o `HexHaptic.feedback(on: .phone)` do `haptic` do `WorkoutSession`, pelo `hapticTick`.
  - `struct WorkoutScreenModel`: os textos e as decisões da tela, a partir do `ActiveWorkout` (o título do painel, "Série 2 de 3", o tempo "12:04" e "1:02:10", o rótulo do VoiceOver de uma linha: "Série 2, 60 quilos, 8 repetições, feita", a fala do superset "Superset A, 1 de 2", quais entradas o painel mostra por modo e escala, e o que a marca de uma linha manda).

- [ ] **Step 1: Write the failing tests** em `WorkoutScreenModelTests.swift`, 6 testes: o título do painel e "Série 2 de 3"; o tempo abaixo e acima de uma hora; a fala de uma linha feita e de uma por fazer, em kg e em lb; as entradas por modo (reps, tempo) e escala (nenhuma, RIR, RPE); a fala do superset; com o `veio-do-opengym`, toda linha tem texto e marca, e nenhuma linha estranha derruba o modelo (Foco da revisão 4).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a tela, a transição e o modelo.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 6.
- [ ] **Step 5: Prints e vídeo**: a tela com `treino-em-andamento` no Ultravioleta e no Ciano, o superset, o painel com RIR e com RPE, a tela em AX5 (as entradas empilham), e o `veio-do-opengym`. Um vídeo do Início até a tela do treino pelo zoom, e outro com Reduzir Movimento (`xcrun simctl ui <udid> ...` não liga o Reduzir Movimento: usar o argumento `-UIAccessibilityReduceMotionEnabled YES`, e, se ele não pegar no simulador, o PR diz e o caso vai para a lista do aparelho). O PR diz se a transição perdeu quadro (Instruments, Hangs e Hitches) e deixa a conferência a 120 Hz para o aparelho.
- [ ] **Step 6: Commit** "A tela do treino e a transição de Começar treino".

---

### Task 9: O descanso: o painel, a notificação e os hápticos

**Depende de:** Task 8.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** as escolhas 5 e 6, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Workout/RestPanel.swift`, `RestPanelModel.swift`, `SystemRestAlerts.swift`
- Create: `apple/HexGymTests/RestPanelModelTests.swift`
- Modify: `apple/HexGym/Workout/WorkoutView.swift`, `apple/HexGym/Workout/SessionEffects.swift` (o texto do aviso), `apple/HexGym/HexGymApp.swift` (o `SystemRestAlerts` no lugar do que não faz nada), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ActiveWorkout.rest`, `RestRing(total:remaining:)`, `SessionAction.adjustRest(by:)`, `.skipRest`, `RestAlerts`.
- Produces:
  - `RestPanel`: no lugar do `CurrentSetPanel` enquanto há descanso: o `RestRing` com o `remaining` tirado do `endsAt` por `TimelineView(.periodic(from:by: 1))`, o tempo grande, "Agora: Supino reto, série 2 de 3" embaixo, e os botões "−15 s", "+15 s" (`hexSecondaryButton`) e "Pular". Quando o tempo chega a 0, o anel toca o `restDone` (ele já faz isso) e o VoiceOver anuncia "Descanso acabou"; o painel fica em "Descanso acabou" até a próxima série ser marcada ou o "Pular". Com Reduzir Movimento, o anel não anima a troca.
  - `SystemRestAlerts: RestAlerts`, sobre o `UNUserNotificationCenter`: um aviso só, com o id `hexgym.rest`, por `UNTimeIntervalNotificationTrigger` até o `endsAt`, com o som padrão; agendar de novo troca o anterior. Com o app na frente, o aviso não aparece (o `willPresent` devolve `[]`), porque o anel e o háptico já avisam. A permissão (`.alert`, `.sound`) é pedida no primeiro `start` (escolha 6); a resposta fica no sistema, e nada muda no documento.
  - O texto do aviso: título "Descanso acabou"; corpo "Agora: <exercício>, série <n> de <total>." (em inglês, "Rest's over" e "Up next: <exercise>, set <n> of <total>."), da próxima série do `liveActivity()`.
  - `struct RestPanelModel`: o `remaining` a partir do `endsAt` e do agora (nunca negativo), o texto do tempo, a fala ("1 minuto e 15 segundos de descanso"), o texto "Agora: ...", e o título e o corpo do aviso.

- [ ] **Step 1: Write the failing tests** em `RestPanelModelTests.swift`, 5 testes: o `remaining` antes, no e depois do `endsAt`; o texto e a fala do tempo nos dois idiomas; o "Agora: ..." com um superset; o título e o corpo do aviso; o `SessionEffects` com um `RestAlerts` falso agenda o aviso com esse texto e, num `adjustRest`, agenda de novo no `endsAt` novo.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o painel, os avisos e a permissão.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 5.
- [ ] **Step 5: Prints e vídeo**: o painel com `descanso` no Ultravioleta e no Cobre, em AX5, e o "Descanso acabou"; um vídeo marcando uma série, vendo o descanso começar, "+15 s" e "Pular". O aviso com o app no fundo aparece no simulador (`xcrun simctl launch <udid> com.apple.Preferences` depois de marcar a série, com `-HexGymRestSeconds 5`): print dele. O háptico e o aviso na tela bloqueada ficam para o aparelho.
- [ ] **Step 6: Commit** "O descanso: o anel, o aviso do fim e os hápticos".

---

### Task 10: Mudar o treino no meio: séries e exercícios

**Depende de:** Task 8.

**Files:**
- Create: `apple/HexGym/Workout/ExerciseMenu.swift`, `WorkoutEditModel.swift`
- Create: `apple/HexGymTests/WorkoutEditModelTests.swift`
- Modify: `apple/HexGym/Workout/WorkoutView.swift`, `ExerciseCard.swift`, `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `SessionAction.addSet`, `.removeSet`, `.addExercises`, `.replaceExercise`, `.removeExercise`, `LibraryView(model:selection:onAdd:)` da fase 2, `SessionOutcome.result` (o `needs` da Task 2).
- Produces:
  - O `Menu` de cada cartão (`ellipsis.circle`): "Adicionar série", "Remover última série", "Trocar exercício" e "Remover exercício". Remover pede confirmação num `.alert` ("Remover supino reto do treino?") quando o exercício tem série feita. Trocar abre a biblioteca em modo de escolha de um só; se o motor devolver `needs: 'confirmLogged'`, um `.alert` ("Este exercício já tem séries feitas. A troca entra ao lado, e as séries ficam.") com "Trocar" e "Cancelar"; se devolver `needs: 'group'`, um `.alert` com "Manter no superset" e "Tirar do superset".
  - Na barra da tela, "Adicionar exercício" (`plus`), que abre a biblioteca em modo de escolha de vários, como o editor de rotina.
  - Uma série apagada some com a animação da Apple; o desfazer de série fica para a fase 5.
  - `struct WorkoutEditModel`: os títulos e as mensagens dos alertas, quando cada alerta aparece, e qual ação vai ao motor depois de cada resposta.

- [ ] **Step 1: Write the failing tests** em `WorkoutEditModelTests.swift`, 4 testes: remover sem série feita não pergunta, e com série feita pergunta com o nome; a resposta "Trocar" ao `needs: 'confirmLogged'` manda o `replaceExercise` com `confirmLogged: true`; as duas respostas ao `needs: 'group'` mandam `keep` e `detach`; com o motor de verdade, adicionar dois exercícios põe os dois depois do atual, na ordem.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o menu, os alertas e o "Adicionar exercício".
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 4.
- [ ] **Step 5: Prints**: o menu aberto (pelo argumento `-HexGymWorkoutMenu <índice>`, que a Task cria), o alerta da troca, o alerta do superset e a biblioteca em modo de escolha, no Ultravioleta.
- [ ] **Step 6: Commit** "Mudar o treino no meio: séries e exercícios".

---

### Task 11: O fim do treino na tela

**Depende de:** Task 8.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 9, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Workout/FinishSummaryView.swift`, `FinishModel.swift`
- Create: `apple/HexGymTests/FinishModelTests.swift`
- Modify: `apple/HexGym/Workout/WorkoutView.swift`, `apple/HexGym/RootView.swift` (o `-HexGymFinish YES`), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `SessionAction.finish`, `.discard`, `FinishSummary`, `RecordStamp(isShown:)`, `RollingNumber`, `HexGlassCard`, `WorkoutSession.lastFinish`.
- Produces:
  - "Terminar": sem série por fazer, termina na hora; com séries por fazer, um `.alert` "Ainda faltam 4 séries." com "Terminar" e "Continuar treinando"; sem nenhuma série feita, "Nenhuma série feita. Descartar o treino?" com "Descartar" (destrutivo) e "Continuar treinando" (Foco da revisão 5).
  - "Descartar treino", no `Menu` da barra da tela, com o `.alert` "Descartar este treino? As séries feitas não vão para o histórico." e "Descartar" (destrutivo).
  - `FinishSummaryView`, no mesmo `fullScreenCover`, no lugar da tela do treino: "Treino feito" em `.hexFont(.title)`, o nome, e três números grandes (`RollingNumber`): a duração, o volume ("4.320 kg") e as séries ("18 séries"); os recordes num `HexGlassCard` com o `RecordStamp(isShown: true)` (que toca o háptico de recorde e anuncia "Novo recorde") e uma linha por recorde ("Supino reto · 82,5 kg"), mais os de 1RM estimado ("Melhor 1RM estimado: 95 kg"); e, por exercício, "Da última vez: 60 kg × 8" e "Na próxima: 62,5 kg × 8" (o `compare.next`). O botão "Pronto" (`.hexPrimary`) fecha a tela e volta ao Início, que já mostra o treino feito.
  - `struct FinishModel`: o texto e a decisão do "Terminar" (qual alerta, ou nenhum), os textos do resumo (a duração "48 min" e "1 h 12 min", o volume na unidade, "1 série" e "18 séries", a linha do recorde, "Da última vez" e "Na próxima" para cada `kind` do `next`: `up`, `hold`, `down` e `deload`, e a primeira vez, sem "Da última vez").

- [ ] **Step 1: Write the failing tests** em `FinishModelTests.swift`, 5 testes: a decisão do "Terminar" para tudo feito, faltando séries e nada feito; a duração abaixo e acima de uma hora e o volume em kg e em lb; o singular e o plural das séries nos dois idiomas; as linhas "Na próxima" para cada `kind`; com o motor de verdade e o `treino-em-andamento` terminado, o resumo tem o recorde que o documento preparado tem.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o "Terminar", o "Descartar" e o resumo.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 5.
- [ ] **Step 5: Prints e vídeo**: o alerta das séries por fazer, o resumo com recorde (`-HexGymFixture treino-em-andamento -HexGymFinish YES`) no Ultravioleta e no Cobre, o resumo sem recorde, e o resumo em AX5; um vídeo da última série até o resumo e de volta ao Início.
- [ ] **Step 6: Commit** "O fim do treino: os recordes e a próxima carga".

---

### Task 12: O histórico na tela

**Depende de:** Tasks 5 e 7.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 10, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/History/HistoryView.swift`, `WorkoutDetailView.swift`, `HistoryModel.swift`
- Create: `apple/HexGymTests/HistoryModelTests.swift`
- Modify: `apple/HexGym/RootView.swift` (a aba Histórico e o `-HexGymWorkoutDetail <key>`), `apple/HexGym/Home/HomeView.swift` (o "Último treino" abre o detalhe), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.history(before:limit:)`, `engine.workoutDetail(_:)`, `AppModel.perform(.deleteWorkout(key:))`, `AppModel.revision`.
- Produces:
  - `HistoryView`: uma `List` da Apple em seções por mês ("Novembro de 2026"), em páginas de 60 (o `HISTORY_PAGE` do openGym), cada linha com o nome, a data ("sex., 6 de nov."), a duração, as séries e a estrela do recorde (um selo desenhado, não o `.badge`); sem treinos, o `ContentUnavailableView` "Nenhum treino ainda" com "O seu primeiro treino aparece aqui." (Foco da revisão 5).
  - `WorkoutDetailView`: o nome, a data, a duração, o volume, a nota, e um `HexGlassCard` por exercício com as linhas (o aquecimento marcado, a série do recorde com a estrela); na barra, "Apagar treino" (`trash`), com o `.alert` "Apagar este treino? Ele sai do histórico para sempre." e "Apagar" (destrutivo); depois de apagar, volta à lista.
  - `struct HistoryModel`: o agrupamento por mês no calendário e no idioma do aparelho, os textos da linha, o rótulo do VoiceOver ("Push, sexta-feira, 6 de novembro, 52 minutos, 18 séries, com recorde"), e quando pedir a próxima página.

- [ ] **Step 1: Write the failing tests** em `HistoryModelTests.swift`, 5 testes: o agrupamento por mês, com um treino que passa da meia-noite no mês do começo; os textos e a fala da linha nos dois idiomas; a próxima página é pedida só quando a última linha aparece e o `more` é verdadeiro; com o motor de verdade e o `semana-ppl`, apagar um treino tira ele da lista; o histórico vazio dá o estado vazio.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a lista, o detalhe e o apagar.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 5.
- [ ] **Step 5: Prints**: a lista com `semana-ppl`, o detalhe de um treino com recorde, o alerta do apagar, o vazio, e a lista e o detalhe em AX5 (`-HexGymTab historico`, `-HexGymWorkoutDetail <key>`).
- [ ] **Step 6: Commit** "O histórico: a lista, o detalhe e apagar um treino".

---

### Task 13: A Live Activity e a Dynamic Island

**Depende de:** Tasks 6 e 9.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 8, sem os botões (que são da Task 14), e o desenho abaixo.

**Files:**
- Create: `apple/Packages/HexLive/Package.swift`, `Sources/HexLive/WorkoutActivity.swift`, `Tests/HexLiveTests/WorkoutActivityTests.swift`
- Create: `apple/HexGymWidgets/WorkoutLiveActivity.swift`, `apple/HexGym/Live/WorkoutActivityController.swift`
- Create: `apple/HexGymTests/WorkoutActivityControllerTests.swift`
- Modify: `apple/HexGymWidgets/HexGymWidgets.swift` (um `@main struct HexGymWidgetBundle: WidgetBundle` com o `WordmarkWidget` e o `WorkoutLiveActivity`; o `WordmarkWidget` perde o `@main`), `apple/Config/HexGym-Info.plist` (`NSSupportsLiveActivities` verdadeiro), `apple/HexGym/HexGymApp.swift` (o controlador de verdade)
- Modify: `apple/HexGym.xcodeproj/project.pbxproj` (o `HexLive` no `HexGym` e no `HexGymWidgets`), `scripts/hexgym/project-format.test.mjs` (`PACKAGES.HexLive = ['HexGym', 'HexGymWidgets']` e o `NSSupportsLiveActivities`), `scripts/hexgym/check.mjs`, `check.test.mjs` (a rodada `HexLive` na parte `packages`, depois da `HexBody`)

**Interfaces:**
- Consumes: `LiveActivityModel` (Task 4), `HexPalette.resolve(_:scheme:contrast:surface: .island)`, `ThemeStore.appGroupStore()`, `HexWordmark`, `.hexFont`.
- Produces:
  - O pacote `HexLive` (iOS 26 e macOS 26, só Foundation e, por `#if canImport(ActivityKit)`, o ActivityKit; o `swift test` roda no Mac sem ele):

```swift
public struct WorkoutActivityContent: Codable, Hashable, Sendable {
  public struct Ahead: Codable, Hashable, Sendable { public let entry: Int, set: Int; public let exercise: String, setLine: String; public let restAfter: Int }
  public let name: String, exercise: String, setLine: String
  public let done: Int, total: Int
  public let restEndsAt: Date?, restTotal: Int?
  public let ahead: [Ahead]
  public init(name: String, exercise: String, setLine: String, done: Int, total: Int, restEndsAt: Date?, restTotal: Int?, ahead: [Ahead])
}
#if canImport(ActivityKit)
public struct WorkoutActivityAttributes: ActivityAttributes {
  public typealias ContentState = WorkoutActivityContent
  public let workoutID: String, start: Date, theme: String   // o tema do aparelho na hora de começar
}
#endif
```

  O `HexLive` não importa o `HexEngine`: o app monta o conteúdo a partir do `LiveActivityModel`.
  - `WorkoutLiveActivity` (`ActivityConfiguration(for: WorkoutActivityAttributes.self)`), com as cores da superfície `.island` do tema dos atributos:
    - **Tela bloqueada:** o `HexWordmark` pequeno, o exercício e a linha da série, os `SlantedSegments(total:done:)`; no descanso, o tempo que conta (`Text(timerInterval:countsDown:)`) e a barra (`ProgressView(timerInterval:countsDown:)`).
    - **Dynamic Island compacta:** à esquerda, "2/3" da série; à direita, o tempo do descanso que conta, ou as séries feitas fora do descanso. **Mínima:** o anel do descanso, ou o "H" da marca. **Expandida:** o exercício, a linha da série e o descanso, com o espaço dos botões embaixo (os botões são da Task 14).
    - Depois do `restEndsAt`, a linha diz "Descanso acabou" (o `staleDate` do conteúdo é o `restEndsAt`).
  - `WorkoutActivityController: WorkoutActivityControlling`: `start` pede a `Activity.request` (sem push), `update` chama `activity.update` com o conteúdo novo, `end` encerra com `.immediate`; uma Live Activity de outro treino (o `workoutID`) é encerrada no `start`; com as Live Activities desligadas pela pessoa, nada acontece e o treino segue. O app recria o controlador sobre a atividade que já existe quando abre com um treino em andamento.

- [ ] **Step 1: Write the failing tests**: em `WorkoutActivityTests.swift`, 3 testes: o `WorkoutActivityContent` vai e volta pelo `JSONEncoder`; com 8 `ahead` e nomes de 40 letras, ele tem menos de 4 KB codificado (o limite do ActivityKit); um conteúdo sem descanso tem `restEndsAt` nulo. Em `WorkoutActivityControllerTests.swift`, 2 testes, com o ActivityKit atrás de um protocolo falso: o `start` de um treino novo encerra a atividade de outro treino; o `update` sem atividade não faz nada.
- [ ] **Step 2: Run** o comando do pacote do HexLive e `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o pacote, a Live Activity, o controlador e o projeto.
- [ ] **Step 4: Run** `node --test scripts/hexgym/project-format.test.mjs scripts/hexgym/check.test.mjs && node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `packages` cresce 3, a `app` 2, e a `scripts` o que o `project-format.test.mjs` e o `check.test.mjs` ganharem (o PR diz).
- [ ] **Step 5: Prints**: a Dynamic Island compacta no simulador de um iPhone com ilha, com o treino em andamento e o app no fundo (`xcrun simctl launch <udid> com.apple.Preferences`), no descanso e fora dele, no Ultravioleta e no Cobre. A tela bloqueada e a ilha expandida ficam para o aparelho, com o código das três telas no PR.
- [ ] **Step 6: Commit** "A Live Activity e a Dynamic Island do treino".

---

### Task 14: Os botões da Live Activity

**Depende de:** Task 13.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 8, os botões.

**Files:**
- Create: `apple/Packages/HexLive/Sources/HexLive/LiveAdvance.swift`, `LiveEventQueue.swift`, `WorkoutIntents.swift`, `Tests/HexLiveTests/LiveAdvanceTests.swift`, `LiveEventQueueTests.swift`
- Create: `apple/HexGym/Live/LiveEventDrain.swift`, `apple/HexGymTests/LiveEventDrainTests.swift`
- Modify: `apple/HexGymWidgets/WorkoutLiveActivity.swift` (os botões), `apple/HexGym/HexGymApp.swift` (escoar a fila ao abrir e ao voltar para a frente)

**Interfaces:**
- Consumes: `WorkoutActivityContent`, `HexEngine.liveEvents(_:now:)` (Task 4), `LiveEvent`.
- Produces:
  - `LiveEventQueue`: um arquivo `live-events.json` no App Group (`group.app.hexgym`), escrito de forma atômica; `append(_ event: QueuedLiveEvent)`, `drain() -> [QueuedLiveEvent]` (lê e esvazia), com `QueuedLiveEvent { id: String; wid: String; kind: String; entry: Int?; set: Int?; by: Int?; at: Date }` e no máximo 64 eventos (o mais velho sai).
  - `LiveAdvance`: `static func advanced(_ content: WorkoutActivityContent, by kind: String, by seconds: Int?, now: Date) -> WorkoutActivityContent`, o que o `LiveActivityTick` do openGym (`frontend/ios/App/App/WorkoutActivity.swift:224-308`) faz: `set.done` tira a primeira do `ahead`, soma uma às feitas e começa o descanso dela (`restAfter`); `rest.skip` tira o descanso; `rest.adjust` muda o `restEndsAt` e o `restTotal` com o teto de 900 s e acaba em 0. Sem `ahead`, `set.done` não muda nada.
  - Os App Intents (`#if os(iOS)`), `LiveActivityIntent`, cada um com o `workoutID` como parâmetro: `LogSetIntent` ("Série feita"), `AddRestIntent` ("+15 s") e `SkipRestIntent` ("Pular"). O `perform` grava o evento na fila, avança a Live Activity pelo `LiveAdvance`, e reagenda ou cancela o aviso do descanso (id `hexgym.rest`, pelo `UNUserNotificationCenter`); quando o app está aberto e com o motor pronto, um `LiveIntentHandler` registrado pelo app no começo (`WorkoutIntents.handler`) aplica o evento direto no motor, como a seção 8.6 pede, e a fila fica vazia.
  - `LiveEventDrain` (no app): ao abrir e ao voltar para a frente, `drain()` e `engine.liveEvents`, que aplica cada evento uma vez pelo id (Foco da revisão 3), e depois o `WorkoutSession.refresh()`.
  - Os botões na Live Activity: fora do descanso, "Série feita"; no descanso, "+15 s" e "Pular"; na tela bloqueada e na ilha expandida.

- [ ] **Step 1: Write the failing tests**: `LiveAdvanceTests`, 3 (o `set.done` avança e começa o descanso; o `rest.adjust` com o teto e o fim em 0; sem `ahead`, nada muda); `LiveEventQueueTests`, 2 (gravar e escoar numa pasta temporária, e o limite de 64); `LiveEventDrainTests`, 2, com o motor de verdade (dois eventos iguais na fila marcam uma série só; um evento de um treino que já terminou não muda nada).
- [ ] **Step 2: Run** o comando do pacote do HexLive e `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a fila, o avanço, os intents, os botões e o escoamento.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `packages` cresce 5 e a `app` 2.
- [ ] **Step 5: Prints**: a Dynamic Island compacta antes e depois de um evento posto na fila por um argumento de lançamento (`-HexGymLiveEvent set.done`, que a Task cria, só no Debug). Os toques nos botões, com o app aberto e fechado, ficam para o aparelho.
- [ ] **Step 6: Commit** "Os botões da Live Activity: série feita, mais tempo e pular o descanso".

---

### Task 15: A Siri para começar o treino

**Depende de:** Task 8.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 11, e as frases abaixo.

**Files:**
- Create: `apple/HexGym/Intents/StartWorkoutIntent.swift`, `RoutineEntity.swift`, `HexGymShortcuts.swift`, `StartRequest.swift`, `apple/HexGym/AppShortcuts.xcstrings`
- Create: `apple/HexGymTests/StartRequestTests.swift`
- Modify: `apple/HexGym/RootView.swift` (atender o pedido), `apple/HexGym/AppModel.swift` (gravar a lista das rotinas para a Siri), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.routines()`, `engine.home(now:)`, `WorkoutSession.perform(.start(...))`.
- Produces:
  - `StartWorkoutIntent: AppIntent` ("Começar treino"), com `static let supportedModes: IntentModes = .foreground` e o parâmetro opcional `routine: RoutineEntity?`. O `perform` põe um `StartRequest` no app (`StartRequest.pending`), que o `RootView` atende quando o motor está pronto.
  - `RoutineEntity: AppEntity`, com o `id` e o nome da rotina; a `RoutineQuery` lê `intents/routines.json` do App Group, que o `AppModel` grava (só o id e o nome) a cada `revision` que mudou as rotinas.
  - `HexGymShortcuts: AppShortcutsProvider`, com as frases em `AppShortcuts.xcstrings`: "Começar treino no \(.applicationName)", "Começar o treino no \(.applicationName)", "Começar \(\.$routine) no \(.applicationName)"; em inglês, "Start a workout in \(.applicationName)", "Start my workout in \(.applicationName)", "Start \(\.$routine) in \(.applicationName)". O símbolo: `figure.strengthtraining.traditional`.
  - `struct StartRequest`: `func decide(home: HomeSummary, routine: String?) -> StartDecision`, com `enum StartDecision { case resume, start([String]), chooseOnHome }`: com um treino em andamento, abre ele; com uma rotina pedida, começa ela; sem rotina pedida, começa as do dia; sem nada marcado para hoje, abre o Início com "Outro treino" aberto (Foco da revisão 5).

- [ ] **Step 1: Write the failing tests** em `StartRequestTests.swift`, 4 testes: as quatro decisões do `decide`; a `RoutineQuery` lê o arquivo de uma pasta temporária e acha a rotina pelo id e pelo nome; o arquivo das rotinas é gravado depois de criar uma rotina (com o motor de verdade); uma rotina pedida que não existe mais dá `chooseOnHome`.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** o intent, a entidade, os atalhos e o pedido.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 4.
- [ ] **Step 5: Prints**: os atalhos do HexGym no app Atalhos do simulador (`xcrun simctl launch <udid> com.apple.shortcuts`), se ele mostrar; senão, o PR diz. O pedido por voz fica para o aparelho, em português e em inglês.
- [ ] **Step 6: Commit** "A Siri para começar o treino".

---

### Task 16: A versão 0.4.0

**Depende de:** todas as outras, da fase 3 e as que entrarem nela depois, e a versão 0.3.0 (#102). É a Task da versão: segue os passos da Task 16 da fase 0, na mesma ordem e com um comentário na issue por passo, retomando pelo último comentado, com estas trocas:

- **Os nomes:** versão `0.4.0`, branch `release/0.4.0`, worktree `.claude/worktrees/release-0.4.0`, milestone "Fase 3: Treino no iPhone" (número 4), resumo `docs/status/m4-treino-no-iphone-status.md` (`--milestone 4`), PR "Versão 0.4.0: o treino no iPhone", tag `v0.4.0` com o título "HexGym 0.4.0", e o PR de volta "Versão 0.4.0 de volta para develop".
- **Passo 1:** o que sobrar aberto sai do épico da fase 3 e vai para o milestone "Fase 4: Apple Watch", com `orphan:ok`.
- **Passo 2:** na branch da release, um commit "Versão 0.4.0" com `MARKETING_VERSION = 0.4.0` nos quatro alvos. O número do build não muda no projeto: o `testflight.mjs` (#24) põe a data e a hora em UTC no passo 5.
- **Passo 3:** prints do Início, da tela do treino, do descanso, do resumo com recorde, do histórico e da Dynamic Island, e o vídeo de um treino completo no simulador: do Início, pelo zoom, até o resumo e o histórico (é o "o founder vê" da fase).
- **Passo 5:** o build interno no TestFlight, com `node scripts/hexgym/testflight.mjs` (#24).
- **Passo 7:** o pedido de decisão vai nesta issue: 1. Aprovar a versão 0.4.0 (recomendada); 2. Pedir mudanças. Ele traz a lista do que só o iPhone de verdade prova, para o founder conferir no build interno, cada item com uma caixa:
  - o háptico da série feita, do recorde e do fim do descanso;
  - o aviso do fim do descanso com o app no fundo e na tela bloqueada, e sem aviso com o app na frente;
  - a Live Activity na tela bloqueada e na Dynamic Island, compacta, mínima e expandida, no descanso e fora dele;
  - os botões "Série feita", "+15 s" e "Pular", com o app aberto e com o app fechado, e o app mostrando o mesmo treino depois;
  - a Siri: "Começar treino no HexGym" e "Começar <rotina> no HexGym", em português e em inglês;
  - a transição de "Começar treino" a 120 Hz, e com Reduzir Movimento;
  - marcar uma série em menos de 100 ms com um histórico grande, e o app abrindo no Início em menos de 1 segundo;
  - o app morto no meio do treino (fechar pelo seletor de apps): ao abrir, o treino e o descanso no ponto certo.
  É a parada de fim de fase da seção 9.1, que a delegação de 03/11 não tira do founder.
- **Passo 12:** `check-milestone-outcomes.sh --milestone 4`.
- **Passo 13:** fecha o milestone 4, e o filtro da visão "Fase atual" vira `milestone:"Fase 4: Apple Watch"`. A sessão da fase 3 põe o resultado da fase na página da fase 3.
