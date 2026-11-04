# Fase 2 do HexGym (Biblioteca e rotinas): plano de implementação

> **Quem executa:** o orquestrador do relentless, como ele vem (nota `docs/decisions/notes/2026-11-03-um-orquestrador-so.md`), tocado pela sessão da fase 2. Cada Task é uma issue do milestone "Fase 2: Biblioteca e rotinas", sub-issue do épico da fase, e um PR para `develop`: uma worktree e uma branch por Task, o critério de aceite da issue é a Task deste plano (a linha `Plano:` da issue), e a revisão isolada do relentless é a revisão do PR. Os títulos ficam "Task N" porque é assim que a linha `Plano:` das issues aponta para eles. Os passos usam caixas de seleção (`- [ ]`).

**Objetivo:** o founder monta a própria rotina no app: a primeira abertura (unidade, tema e corpo), os 5.632 exercícios com busca e filtros, o detalhe de cada exercício com o corpo muscular no lugar das mídias, a criação e a edição de rotinas e do plano da semana, e os ajustes básicos.

**Arquitetura:** as regras continuam no motor do openGym (seção 8.2). O que é do HexGym em JavaScript fica em `apple/Packages/HexEngine/JS/` (ao lado do `runtime.js`): os idiomas (`language.js`), a biblioteca (`library.js`) e as ações sobre o documento (`actions.js`), cada um com o seu `*.test.mjs`, todos dentro do script do motor. As ações fazem o que o `update()` do `store/useStore.js` faz: um rascunho (`draftOf`), a mudança, e o carimbo (`stampChange`); o app grava o documento pelo HexStore depois de cada ação. O Swift só troca JSON e modelos pequenos com o motor. As regiões do corpo por exercício saem do gerador em `scripts/hexbody/regions/` (as #12 e #13) para um pacote novo, o `HexBody`, que leva os dados e, depois da #10, os desenhos e a view do corpo. As telas são do app do iPhone, no HexDesign. O Watch não muda nesta fase.

**Tecnologias:** Swift (`swift-tools-version: 6.2`), SwiftUI e Swift Testing; JavaScript do motor (Node 22 nos testes, `node --test`); Python 3 da máquina, só com a biblioteca padrão, no gerador de regiões; Blender 5.1 só na Task 13; Xcode 27.2 estável.

**Especificação:** `docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md`, seções 4, 5, 6, 8.2, 8.3, 8.8, 8.9, 8.12, 8.13, 9 e 9.1. A pesquisa do corpo é `docs/research/reports/Sistema muscular para o HexGym.md`, e os scripts dele, `scripts/hexbody/` (o README de lá tem a ordem de build). As decisões visuais da fase 1 valem como estão: página https://claude.ai/artifact/3fwPGoNm3EBDZkqesDkvbB e `docs/hexgym/design-system/`.

## Escolhas desta fase

O founder delegou em 03/11/2026: o tech lead segue a opção recomendada, inclusive em visual, produto e texto. Cada escolha abaixo vem marcada no plano e na issue como "escolha recomendada, com a delegação do Lipe de 03/11/2026". O que ele pedir para mudar depois vira uma Task normal. A página da fase 2 (Artifact, publicada pela sessão da fase 2) mostra as telas propostas e, a cada merge, o PR, os prints do simulador e a escolha.

As escolhas recomendadas deste plano:
1. **As abas:** três, "Rotinas", "Exercícios" e "Ajustes", na barra de abas da Apple. A tela do treino e o início chegam na fase 3. A galeria do design system sai da tela provisória e vai para o fim dos Ajustes (Task 6).
2. **A primeira abertura:** três passos numa tela só que avança (unidade, tema e corpo), com "Pular" em cada passo e os padrões: kg e masculino, do `DEF` do openGym, e o Ultravioleta, o tema padrão do HexGym. Ela aparece quando o documento foi criado agora ou quando o aparelho nunca a viu (Task 7).
3. **O corpo na primeira abertura, antes da #10:** a escolha "Masculino" ou "Feminino" com os símbolos `figure.stand` e `figure.stand.dress`; o desenho do corpo entra no lugar deles na Task 14.
4. **O idioma:** segue o do aparelho, e o HexGym nunca grava `lang` no documento compartilhado, pelo mesmo motivo do tema (seção 8.12): não mudar o app do openGym de quem usa os dois. O `body` e o `unit` são gravados, porque querem dizer a mesma coisa nos dois apps.
5. **Os textos das telas:** num catálogo do app (`apple/HexGym/Localizable.xcstrings`), em português do Brasil e em inglês, como na fase 1. Os nomes, as instruções e as descrições dos exercícios e os nomes dos grupos musculares vêm dos pacotes do openGym, pelo motor, nos 20 idiomas (seção 8.9).
6. **A lista de exercícios:** sem miniatura (as mídias não entram, seção 8.8): o nome, o grupo principal e o equipamento, com os favoritos primeiro. Os filtros são os do openGym: grupo muscular, equipamento, categoria e favoritos.
7. **O corpo no detalhe:** frente e costas lado a lado, o primário na cor do tema e o secundário em 40% dela (os pesos 1 e 0,4 da pesquisa), com a legenda em texto. Antes da #10, o detalhe mostra as regiões em lista; o desenho entra na Task 14.
8. **Os desenhos do corpo:** uma imagem de base chapada (o acabamento flat que o founder escolheu em 31/10/2026) e uma máscara recortada por região, tingidas pelo SwiftUI, sem shader Metal (Task 13).
9. **O ícone da rotina:** os 20 glyphs do `lib/glyphs.js`, cada um com um SF Symbol (a tabela da Task 11).
10. **O plano da semana:** a semana fixa do openGym (uma ou mais rotinas por dia), com os quatro planos prontos dele (`lib/starter.js`) na tela vazia. O modo de rodízio (`rotation`) fica para a fase 5, junto com os programas.

## Restrições globais (Global Constraints)

Valem para toda Task. Os valores vêm da especificação, das decisões da fase 1 e do levantamento de 04/11/2026.

- **Plataforma e Xcode:** iOS 26 como mínimo, nada só do iOS 27; Xcode 27.2 estável em `/Applications/Xcode.app`, por `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs)`. O Xcode-beta nunca é escolhido, nem num comando que só imprime o caminho. Os pacotes rodam com `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) --package-path apple/Packages/<pacote>` ("o comando do pacote"); com o Xcode 27.2, o `--swift-test-flags` não imprime nada.
- **A checagem:** `node scripts/hexgym/check.mjs` roda as partes `scripts, engine, load, packages, app`, nessa ordem, e cada parte só passa se rodou pelo menos um teste, contado por um arquivo, nunca pela tela (regra da #44, comentário do topo do `check.mjs`). Hoje ela dá `scripts 51, engine 2593, load 3, packages 89, app 10`. Toda Task diz quanto cada parte cresce, contando os testes que ela lista (o XUnit do `swift test` conta um por função, mesmo num teste do Swift Testing com argumentos: os `packages 89` de hoje contam assim; o plano conta um por função também na parte `app`, e o PR diz a conta medida); a conta de partida é a de `develop` no começo da Task, e o PR diz a de antes e a de depois e, se o número for outro, por quê. O QA confere a conta, não só o código de saída. Um PR que cria uma rodada mexe nos testes do `check.test.mjs` que prendem a lista de rodadas.
- **O script do motor:** toda mudança em `apple/Packages/HexEngine/JS/` muda o script gerado. A Task roda `node scripts/build-hexgym-engine.mjs` e commita o `hexengine.js.deflate` e o `hexengine.js.sha256` juntos. Como os dois são binários, duas Tasks que mexem no motor nunca correm juntas: a ordem é 3, 4, 5, e quem vem depois faz `git merge origin/develop` e gera o script de novo antes do QA. O mesmo vale, sem o script, para dois arquivos de texto que várias Tasks mexem: o `check.mjs` e o `check.test.mjs` (Tasks 1, 3 e 8) e o `RootView.swift` e o `Localizable.xcstrings` (Tasks 6, 7, 9, 10, 11 e 12). Elas podem correr juntas, mas a que entrar depois faz `git merge origin/develop`, resolve o conflito e roda a checagem de novo antes do QA.
- **O motor:** um `JSContext` só, dentro do ator `HexEngine`, nunca na thread principal. O Swift troca só texto JSON e modelos `Codable` pequenos; o documento fica dentro do JS e nunca vai inteiro para a tela.
- **O documento:** toda mudança passa por uma ação do motor (Task 5), com `draftOf` e `stampChange`, como o `update()` do `store/useStore.js`; o app grava pelo `DocumentStore` do HexStore. Nenhuma chave do documento se perde ao ler e gravar. O HexGym não escreve `theme`, `accent` nem `lang` (seção 8.12 e escolha 4).
- **O código do openGym:** nenhum arquivo de `frontend/` muda nesta fase. O que o HexGym precisa em JS fica em `apple/Packages/HexEngine/JS/` e importa o `lib` como o `runtime.js` importa. `cd frontend && npm test` continua verde.
- **Desempenho (seção 8.13):** um toque reflete na tela em menos de 100 ms; a busca da biblioteca responde em menos de 100 ms por letra e o catálogo inteiro sai em menos de 400 ms, no `jsc` sem JIT (as metas da Task 4 no `engine-load.mjs`; a seção 8.13 não fala da busca, então os dois números são escolha recomendada, com a delegação do Lipe de 03/11/2026, tirados do toque de 100 ms); a lista dos 5.632 exercícios rola sem perder quadro (`List` preguiçosa, linhas sem imagem, nada calculado no `body`); o app abre na primeira tela em menos de 1 segundo.
- **Design system:** toda tela usa o HexDesign (`.hexFont`, `.buttonStyle(.hexPrimary)`, `HexGlassCard`, `hexSecondaryButton`, `HexSpacing`, `@Environment(\.hexPalette)`, as entradas do treino). As decisões da fase 1 ficam como estão, inclusive o tint branco na raiz (`RootTint`) e o texto na cor do tema só sobre o fundo da tela e sobre o cartão do sistema (#71). Componentes da Apple como vêm: `TabView`, `NavigationStack`, `List`, `.searchable`, `.swipeActions`, `Menu`, `Picker`, `Toggle`, `.sheet`, `.confirmationDialog`.
- **Acessibilidade:** toda tela funciona com Dynamic Type até AX5 (nada cortado), VoiceOver (rótulo, valor e ação em cada controle; o corpo diz as regiões em texto), Reduzir Movimento, Aumentar Contraste, Reduzir Transparência e Texto em Negrito; alvo de toque de pelo menos 44 pt.
- **Mídias da Gym visual:** nenhuma entra no app, nos prints ou nos vídeos desta fase (seção 8.8: só depois do ok do Duarte). Nunca abrir, copiar, converter ou passar por ferramenta de IA as fotos e animações; nada maior que 180 px delas em lugar nenhum; nada novo em `catalogue/media/`. O gerador de regiões e o app leem só o texto do catálogo. O limite de 180 px é das mídias da Gym visual: os desenhos do corpo (Task 13) são nossos e não passam por ele.
- **O corpo muscular:** os scripts estão em `scripts/hexbody/`, e a pasta `work/` fica fora do git. A Task 13 e a Task 14 levam a arte do corpo para o app e dependem da #10 (a cópia de `work/` fora desta máquina e a procedência da imagem de referência), que espera o `/decide 10` do founder. O crédito do MuscleMap (MIT, Melih Colpan) vai na tela de licenças (Task 6).
- **Dependências:** nenhum pacote Swift de terceiros, nenhuma dependência npm nova e nenhum módulo Python fora da biblioteca padrão no gerador de regiões.
- **Texto para o usuário:** simples e humano, sem travessão; português do Brasil e inglês no catálogo do app; os nomes da Apple na grafia da Apple (Apple Watch, iPhone, Dynamic Type, VoiceOver, Liquid Glass, SF Symbols).
- **Prints e vídeo dos PRs:** em `docs/hexgym/prints/<issue>/`, no commit do próprio PR, mostrados no corpo por `https://github.com/lipedesign/HexGym/blob/<sha>/docs/hexgym/prints/<issue>/<arquivo>?raw=true`. Os prints saem do simulador do iPhone (o `pickSimulator` do `check.mjs`: iPhone do iOS mais novo, 26 ou acima) com `xcrun simctl io <udid> screenshot`; o vídeo, com `xcrun simctl io <udid> recordVideo --codec h264`, até 15 s e menos de 5 MB. Toda Task de tela tem print em tamanho padrão e em AX5. Nunca um aparelho físico.
- **Abrir o app numa tela, para prints e testes de interface:** argumentos de lançamento, como o `-HexGymGallery YES` da fase 1. A Task 6 cria `-HexGymTab <rotinas|exercicios|ajustes>`, e a Task 7 cria `-HexGymOnboarding YES` (mostra a primeira abertura) e `-HexGymSkipOnboarding YES` (nunca mostra). Os testes de interface e os prints usam os dois.
- **Os testes do app:** a parte `app` do `check.mjs` roda o alvo `HexGymTests` (Swift Testing). Lógica de tela que dá para provar sem tela (filtros, textos, ordem, validação) vai num tipo pequeno testado ali; o que só a tela prova vai nos prints.
- **Duas fases ao mesmo tempo:** a fase 0 ainda tem a #8, a #23, a #24 e a #25 abertas, da sessão `primeira-leva-da-fase-0`: nenhuma Task daqui mexe nelas nem nos arquivos que elas mudam (`README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `scripts/hexgym/testflight.mjs`). Nenhuma linha em `docs/decisions/log.jsonl` até o `/decide 36`. Todo `gh issue list` desta fase leva `--milestone "Fase 2: Biblioteca e rotinas"`.
- **Repositório, IDs, Git Flow, estado das issues, `.claude/` e commits:** como nas Restrições globais da fase 0 (`docs/superpowers/plans/2026-10-31-fase-0-fundacao.md`). Todo `gh` leva `-R lipedesign/HexGym`. Os commits terminam com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Foco da revisão (Review Focus)

O que a especificação implica, nenhuma Task testaria sozinha e mais pode morder quem usa o app. Cada linha ganhou um teste na Task dona do código.

1. **O documento de outro aparelho ou do openGym:** um documento com rotinas, semana e chaves que o HexGym não conhece abre, passa por qualquer ação e sai com todas as chaves, e só o que a ação mexeu ganha carimbo novo; uma rotina com exercício que não existe mais (id apagado ou personalizado de outro aparelho) aparece como "Exercício desconhecido" e não derruba a tela. Testes nas Tasks 5 e 11.
2. **A busca em outros idiomas e sem acento:** "supino" acha o supino em pt-BR, "SUPINO" e "supíno" também, um nome em inglês acha o exercício com o aparelho em pt-BR (o openGym procura nos dois), e uma busca sem resultado mostra o estado vazio da Apple com o texto. Testes nas Tasks 4 e 9.
3. **A troca de unidade com rotinas prontas:** trocar de kg para lb converte as cargas das rotinas e do documento como o `convertStateUnit` do openGym, uma vez só (trocar duas vezes volta ao valor de antes, dentro do arredondamento dele). Teste na Task 5.
4. **Desfazer e apagar:** apagar uma rotina que está no plano da semana tira ela dos dias; desfazer devolve a rotina e os dias, como o `routineSnapshot` e o `restoreRoutine` do openGym. Teste na Task 5, e o desfazer na tela, na Task 11.
5. **O maior tamanho de texto (AX5) e nomes longos:** nomes de exercício com mais de 60 letras e em alemão quebram linha em todas as telas, nada é cortado, e as entradas do editor empilham (o `WorkoutInputLayout` da fase 1). Prints em AX5 nas Tasks 7, 9, 10, 11 e 12, e um teste da linha da lista na Task 9.

## Mapa dos arquivos

```
scripts/hexbody/regions/                       o gerador de regiões, num caminho sem espaço (Tasks 1, 2 e 8)
  build_exercise_regions.py                    lê o texto do catálogo; --check; --app
  test_build_exercise_regions.py               Python unittest
  run_tests.py                                 roda os testes e grava a conta no HEXGYM_CHECK_COUNT_FILE
  exercise_regions_v2.json, regions_v2.json    a saída de referência (sai de docs/research/...)
scripts/hexbody/blender/app_art.py             os desenhos do corpo para o app (Task 13)
scripts/build-hexgym-langs.mjs                 os pacotes de idioma do motor, com --check (Task 3)
scripts/hexgym/build-hexgym-langs.test.mjs
apple/Packages/HexEngine/JS/
  language.js, language.test.mjs               o idioma do motor (Task 3)
  library.js, library.test.mjs                 a biblioteca (Task 4)
  actions.js, actions.test.mjs                 as ações sobre o documento e as leituras das telas (Task 5)
apple/Packages/HexEngine/Sources/HexEngine/
  Language.swift                               a escolha do idioma e a carga do pacote (Task 3)
  Library.swift                                os modelos e as chamadas da biblioteca (Task 4)
  Actions.swift                                as ações e as leituras (Task 5)
  Resources/langs/<idioma>.json.deflate        os pacotes gerados, e o index.json (Task 3)
apple/Packages/HexBody/                        o corpo: as regiões por exercício e, depois da #10, o desenho
  Package.swift
  Sources/HexBody/RegionCatalog.swift          os dados (Task 8)
  Sources/HexBody/BodyFigureView.swift         o desenho (Task 14)
  Sources/HexBody/Resources/exercise-regions.json   gerado pelo --app (Task 8)
  Sources/HexBody/Resources/Art/<corpo>/<vista>/    base.png, regiões e layout.json (Task 13)
  Sources/HexBody/Resources/Strings/en.lproj/, pt-BR.lproj/Regions.strings
  Tests/HexBodyTests/
apple/HexGym/
  AppModel.swift                               ganha o documento vivo e a gravação (Task 5)
  RootView.swift                               as abas e a primeira abertura (Tasks 6 e 7)
  Settings/                                    os ajustes e as licenças (Task 6)
  Onboarding/                                  a primeira abertura (Task 7)
  Library/                                     a lista, a busca, os filtros e o detalhe (Tasks 9 e 10)
  Routines/                                    a lista de rotinas, o editor e o seletor (Task 11)
  Plan/                                        o plano da semana e os planos prontos (Task 12)
apple/HexGymTests/                             um arquivo por assunto
docs/hexgym/prints/<issue>/                    os prints e os vídeos dos PRs
```

Arquivos de antes que mudam: `apple/HexGym/ContentView.swift` sai (Task 6), e o `HexGymApp.swift` passa a abrir o `RootView`; `apple/HexGym/Localizable.xcstrings` em toda Task de tela; `apple/HexGym.xcodeproj/project.pbxproj` e `scripts/hexgym/project-format.test.mjs` quando um pacote entra no app (Tasks 8 e 14); `scripts/hexgym/check.mjs` e `check.test.mjs` nas Tasks 1, 3 e 8; `scripts/hexgym/engine-load.mjs` na Task 4; `scripts/hexbody/README.md` nas Tasks 1 e 13; `docs/research/research_notes/Sistema muscular para o HexGym/` perde o gerador e os JSON, com um aviso apontando para `scripts/hexbody/regions/` (Task 1).

## Ordem e dependências

| Task | O que entrega | Depende de |
|---|---|---|
| 1 | O gerador de regiões em `scripts/`, com `--check` e a ênfase corrigida (#12) | nenhuma |
| 2 | As regras por nome da pesquisa (#13) | 1 |
| 3 | Os idiomas do openGym no motor | nenhuma |
| 4 | A biblioteca no motor | 3 |
| 5 | As ações sobre o documento e a gravação | 4 |
| 6 | As abas e os ajustes básicos | 5 |
| 7 | A primeira abertura | 6 |
| 8 | O pacote HexBody com as regiões de cada exercício | 2 |
| 9 | A biblioteca: lista, busca e filtros | 4, 6 |
| 10 | O detalhe do exercício | 8, 9 |
| 11 | O editor de rotina | 5, 9 |
| 12 | O plano da semana e os planos prontos | 11 |
| 13 | Os desenhos do corpo | 8, #10 |
| 14 | O corpo no app | 7, 10, 13, #10 |
| 15 | A versão 0.3.0 | todas as outras, #67 |

Cada issue leva, no fim das Notas, as duas linhas que o orquestrador lê: `Depende de: #a, #b` (ou `nenhuma`) e `Plano: docs/superpowers/plans/2026-11-04-fase-2-biblioteca-e-rotinas.md, Task N`. A #12 e a #13 já existem e viram as Tasks 1 e 2: ganham as duas linhas e o critério da Task no corpo. As outras saem depois do merge deste plano, com o modelo Tarefa, a etiqueta do tipo, as de área (`motor`, `dados`, `design-system`) e `state:todo`, o critério de aceite de cada Task copiado no corpo (o revisor isolado só lê o corpo) e a marca das escolhas recomendadas; cada uma vira sub-issue do épico da fase e entra no Project 6. Nas linhas `Depende de:`, o número da Task vira o da issue.

A Task 13 e a Task 14 ficam no fim da ordem com `Depende de: #10`: a onda faz as outras e para nelas até o `/decide 10`. A 15 espera também a versão 0.2.0 (#67), que espera a 0.1.0 (#25).

Ficam fora desta fase, de propósito: o treino (fase 3), com o histórico, a progressão aplicada e o "Começar treino" ligado à tela do treino; o Watch (fase 4); o rodízio, os programas, a importação, o servidor, os exercícios personalizados, as medidas, os perfis de equipamento e o mapa de recuperação (fase 5); as mídias da Gym visual (seção 8.8); o modo claro.

---

### Task 1: O gerador de regiões em scripts/, com --check e a ênfase corrigida

É a #12.

**Depende de:** nenhuma.

**Files:**
- Create (com `git mv` a partir de `docs/research/research_notes/Sistema muscular para o HexGym/`): `scripts/hexbody/regions/build_exercise_regions.py`, `test_build_exercise_regions.py` (era `test_build_exercise_regions_v2.py`), `exercise_regions_v2.json`, `regions_v2.json`
- Create: `scripts/hexbody/regions/run_tests.py`, `scripts/hexbody/regions/README.md`
- Delete: `docs/research/research_notes/Sistema muscular para o HexGym/exercise_regions.json` (a v1, que ninguém lê; a história fica no git)
- Modify: `docs/research/research_notes/Sistema muscular para o HexGym/` ganha `GERADOR.md` com uma linha apontando para `scripts/hexbody/regions/`; `docs/research/reports/Sistema muscular para o HexGym.md` troca os caminhos citados
- Modify: `scripts/hexbody/musclemap/raster.py` (grava o `labels.json` com `indent=1`), `scripts/hexbody/musclemap/labels.json` (gerado de novo, só a indentação), `scripts/hexbody/README.md`
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs`

**Interfaces:**
- Produces:
  - `python3 -I scripts/hexbody/regions/build_exercise_regions.py` grava os dois JSON da v2 (a v2 passa a ser o padrão, e a opção `--v2` some); `--check` não grava nada e sai com 1, dizendo qual arquivo e qual exercício, quando um JSON não bate com o que sairia do catálogo.
  - O formato de `exercise_regions_v2.json` não muda: `{ "<id>": { "name", "primary": [região], "secondary": [região], "emphasis"?: [região], "source", "variantOf"? } }`, 6.554 chaves (os 5.632 exercícios e os 922 desenhos femininos).
  - `python3 -I scripts/hexbody/regions/run_tests.py`: roda o `unittest` da pasta e, com `HEXGYM_CHECK_COUNT_FILE` no ambiente, grava `# pass <n>` nele (os testes que passaram, sem os pulados); sai com 1 se algum falhou.
  - Na parte `scripts` do `check.mjs`, duas rodadas novas, depois da que existe: `regiões em dia` (`python3 -I scripts/hexbody/regions/build_exercise_regions.py --check`) e `testes do gerador de regiões` (`python3 -I scripts/hexbody/regions/run_tests.py`).

**A ênfase:** sai depois das regras por nome, só com as regiões que estão no primário, e é descartada quando cobre todas as regiões de um grupo inteiro do primário (não diz nada a mais) ou quando fica igual ao primário. Nas abduções sentadas (0597, 3006, 3611 e 3005), o glúteo máximo, que as regras mandam para o secundário, deixa a ênfase.

- [ ] **Step 1: Move the files and make the tests run from the new place**

`git mv` dos quatro arquivos; o gerador acha a raiz do repositório a partir do próprio caminho (`Path(__file__).resolve().parents[3]`). `run_tests.py` usa `unittest.defaultTestLoader.discover` na pasta dele e grava a conta. Run: `python3 -I scripts/hexbody/regions/run_tests.py`. Expected: os 14 testes que vieram passam.

- [ ] **Step 2: Write the failing tests**

Em `test_build_exercise_regions.py`:
- `test_emphasis_stays_inside_primary`: para todo exercício com `emphasis`, `set(emphasis) <= set(primary)`.
- `test_emphasis_never_equals_primary_or_a_whole_group`: nenhuma ênfase igual ao primário, nem igual a todas as regiões de um grupo do primário.
- `test_seated_abduction_has_no_gluteus_maximus_emphasis`: 0597, 3006, 3611 e 3005 sem `gluteal` na ênfase.
- `test_check_passes_when_fresh` e `test_check_fails_when_stale`: o `--check` dá 0 com os JSON do repositório e 1 com uma cópia em que um exercício perdeu uma região (rodando o gerador contra uma pasta temporária, com uma opção `--out <pasta>` só para isso).

Run: `python3 -I scripts/hexbody/regions/run_tests.py`. Expected: as três da ênfase e a do `--check` falham.

- [ ] **Step 3: Implement the emphasis rule and `--check` / `--out` in `build_exercise_regions.py`**

A v2 vira o padrão; `--check` compara o texto que seria gravado com o do arquivo.

- [ ] **Step 4: Regenerate and run the tests**

Run: `python3 -I scripts/hexbody/regions/build_exercise_regions.py && python3 -I scripts/hexbody/regions/run_tests.py`. Expected: todos passam. O diff do `exercise_regions_v2.json` mexe só em `emphasis` (o PR conta quantos exercícios mudaram e mostra as abduções).

- [ ] **Step 5: The labels table with indentation**

Nos dois `json.dump` do `raster.py` (linhas 173 e 175), `ensure_ascii=False, indent=1`; o `raster.py` não roda nesta Task (ele usa `numpy` e `PIL` e recalcula as caixas e as figuras). O `labels.json` que existe é regravado só com a biblioteca padrão: `python3 -I -c` com `json.load` e `json.dumps(..., ensure_ascii=False, indent=1)`. O `labels_f.json` ganha a mesma indentação na próxima rodada do corpo feminino, e o README do hexbody diz isso. Expected: o diff do `labels.json` é só de espaço (`git diff -w --stat` vazio).

- [ ] **Step 6: The two rounds in the check**

No `check.mjs`, as duas rodadas na parte `scripts`; no `check.test.mjs`, os testes que prendem a lista de rodadas mudam. Run: `node --test scripts/hexgym/check.test.mjs && node scripts/hexgym/check.mjs scripts`. Expected: a parte `scripts` passa de 51 para 70, com os 19 testes do gerador (os 14 que vieram e os 5 do Step 2), mais o que o `check.test.mjs` ganhar, que o PR diz. A rodada `regiões em dia` não conta teste. A #12 pede o `--check` e os testes no workflow do HexGym: eles chegam pelo `check.mjs`, que o workflow da #9 roda.

- [ ] **Step 7: Docs and commit**

`scripts/hexbody/regions/README.md` (o que o gerador lê, os dois comandos, que nunca abre mídia); a linha no `README.md` do hexbody; o `GERADOR.md` na pasta da pesquisa. Commit: "O gerador de regiões em scripts/, com --check e a ênfase corrigida".

---

### Task 2: As regras por nome da pesquisa

É a #13.

**Depende de:** Task 1.

**Files:**
- Modify: `scripts/hexbody/regions/build_exercise_regions.py`, `test_build_exercise_regions.py`, `exercise_regions_v2.json`

**Interfaces:**
- Consumes: o gerador da Task 1.
- Produces: o `exercise_regions_v2.json` com as regras da tabela "A evidência confirma o banco inclinado e derruba o abdômen inferior" do relatório da pesquisa. O formato não muda.

**As regras** (as fontes estão no relatório; o número do exercício de cada teste sai do catálogo, procurado pelo nome, e fica escrito no teste):

| Regra | Primário | Secundário |
|---|---|---|
| Supino inclinado até cerca de 30° (o nome diz "incline" sem ângulo, ou 15° a 30°) | `upperChest` | `frontDeltoid`, `triceps` |
| Supino inclinado de 45° em diante | `frontDeltoid` | `upperChest`, `triceps` |
| Supino reto, crucifixo e flexão de braço, sem inclinação | `chest`, `lowerChest` | `upperChest`, `frontDeltoid`, e `triceps` e `tricepsLongHead` no supino e na flexão (não no crucifixo); o `deltoids` (lateral) e o `rearDeltoid` saem do secundário (o lateral fica em 3,4% a 5%) |
| Supino declinado | `lowerChest`, `chest` | `triceps`, `frontDeltoid` |
| Desenvolvimento (overhead/shoulder/military press) | `frontDeltoid` | `deltoids` (o secundário forte do relatório), `triceps`, `upperTrapezius` |
| Elevação lateral | `deltoids` | `rearDeltoid`, `upperTrapezius` |
| Crucifixo inverso, face pull, deltoide posterior | `rearDeltoid` | `rhomboids`, `trapezius` |
| Encolhimento | `upperTrapezius` | nenhum |
| Elevação em "Y" | `lowerTrapezius` | `deltoids` |
| Rotação de tronco, woodchopper, prancha lateral sem abdução | `obliques` | `upperAbs` |
| Abdução de quadril, prancha lateral com abdução | `gluteusMedius` | `gluteal` (o glúteo máximo não fica no primário), e `obliques` na prancha |
| Agachamento (livre, frontal, com barra ou halter) | `outerQuad`, `innerQuad`, `gluteal`, `adductors` | `quadriceps` (o reto femoral só secundário), e os secundários que já tinha |
| Adução de quadril | `adductors` | nenhum |
| Elevação de pernas, reverse crunch (o abdômen "inferior") | `hipFlexors`, `upperAbs`, `lowerAbs` juntos: o `lowerAbs` nunca acende sozinho | nenhum |

A tabela segue a do relatório nas linhas de peito, ombro, trapézio, abdução, agachamento e abdômen; as linhas sem estudo no relatório (crucifixo inverso, face pull, rotação, adução) vêm da anatomia funcional, como ele diz. Ficam fora: a cadeira flexora sentada (o mapa tem uma região só para o posterior de coxa, então não há o que mostrar), e as linhas de braço (rosca martelo e inversa, extensão de tríceps acima da cabeça), de cadeira extensora e de panturrilha, que o implementador confere no `exercise_regions_v2.json`: se uma não bater com o relatório, ela vira regra com um teste a mais e o PR diz qual. O revisor confere o gerador contra esta tabela.

- [ ] **Step 1: Write one failing test per rule**, 14 testes, cada um com um exercício real do catálogo (o primário e o secundário da tabela); o da linha do supino reto usa o `0025`.
- [ ] **Step 2: Run** `python3 -I scripts/hexbody/regions/run_tests.py`. Expected: os testes novos falham.
- [ ] **Step 3: Implement the rules**, aplicadas antes da ênfase da Task 1, na mesma estrutura das regras da v2.
- [ ] **Step 4: Regenerate and run** `python3 -I scripts/hexbody/regions/build_exercise_regions.py && python3 -I scripts/hexbody/regions/run_tests.py && node scripts/hexgym/check.mjs scripts`. Expected: tudo passa, e a parte `scripts` cresce 14 (os testes das regras), mais um por regra que a conferência das linhas de fora acrescentar. O PR traz a contagem de exercícios que mudaram por regra.
- [ ] **Step 5: Commit** "As regras por nome da pesquisa no gerador de regiões".

---

### Task 3: Os idiomas do openGym no motor

**Depende de:** nenhuma.

**Files:**
- Create: `scripts/build-hexgym-langs.mjs`, `scripts/hexgym/build-hexgym-langs.test.mjs` (na pasta do glob da parte `scripts`)
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Resources/langs/<idioma>.json.deflate` (um por idioma de `LANGS` que tem pacote, mais `en`) e `langs/index.json`
- Create: `apple/Packages/HexEngine/JS/language.js`, `language.test.mjs`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Language.swift`, `Tests/HexEngineTests/LanguageTests.swift`
- Modify: `apple/Packages/HexEngine/JS/runtime.js` (exporta `setLanguage`), `HexEngine.swift` (o `load()` carrega o pacote), `Package.swift` (os recursos de `langs/`), o script do motor gerado
- Modify: `scripts/hexgym/check.mjs`, `check.test.mjs` (a rodada `idiomas em dia` na parte `engine`), `scripts/hexgym/engine-load.mjs` (a carga do pacote entra na medida de abrir o motor)

**Interfaces:**
- Produces:
  - `node scripts/build-hexgym-langs.mjs` (e `--check`, que sai com 1 quando um pacote está velho): para cada idioma, um JSON `{ "lang", "dict", "names", "instr", "desc" }` comprimido em DEFLATE cru, como o script do motor, a partir de `frontend/src/locales/<idioma>.js`, `exercise-names/<base>.js`, `instr/<base>.js` e `exercise-desc/<base>.js` (o que faltar fica `null`); o `en.json.deflate` leva o `instr/en.js` e o `exercise-desc/en.js`. `index.json`: `{ "<idioma>": { "file", "sha256" } }`, com o sha256 do texto. Os módulos são lidos com `import()` do Node; nada de `frontend/` muda.
  - JS, em `language.js`, exportado pelo `runtime.js`: `setLanguage(enJson, langJson)`, que faz o que o `setLang` do `lib/i18n.js` faz sem o navegador: `_setLangState` e `_setDetails` com o inglês e o idioma. O `pt-BR` já vem com a herança do `pt` no próprio módulo (`locales/pt-BR.js` importa o `pt.js`), e o gerador grava o resultado; o `de-CH` é o único derivado (`derivePack`, `i18n-core.js:35`): não tem pacote próprio, carrega o do `de` e o `setLanguage` aplica o `derivePack`. O nome sai sem o inglês entre parênteses (o `_setLangState` com `showEn = false`, sem gravar nada no documento); o inglês aparece no detalhe, pelo `nameEnglish` (escolha recomendada, com a delegação do Lipe de 03/11/2026). Depois dele, `t()`, `exerciseNameFor`, `instrFor` e `descFor` respondem no idioma.
  - Swift:

```swift
public enum EngineLanguage {
  // O idioma de LANGS do openGym para as línguas do aparelho, na ordem da lista; para cada uma, a tag
  // inteira ("pt-BR", "de-CH"), depois o chinês pelo script ("zh-Hant-TW" e "zh-Hant-HK" viram
  // "zh-TW", "zh-Hans-CN" vira "zh"), depois a base ("pt-PT" vira "pt"); "en" quando nenhuma serve.
  public static func tag(for preferred: [String]) -> String
}
```

  O `HexEngine` ganha `init(languages: [String] = Locale.preferredLanguages)`, e o `init(language:)` de antes perde o valor padrão e continua, chamando o novo com `[language]`; assim o `HexEngine()` do `AppModel.live()` segue compilando, agora com a lista inteira do aparelho, e o `AppModel.swift` não muda. O `load()` passa a escolher o idioma pelo `EngineLanguage.tag(for:)`, carregar o pacote dele e o `en` do `Bundle.module`, descomprimir e chamar `setLanguage`. O `EngineInfo` ganha `public let language: String`. Escolhas 4 e 5 do plano, escolha recomendada, com a delegação do Lipe de 03/11/2026: o idioma segue o do aparelho e nunca é gravado no documento.

- [ ] **Step 1: Write the failing tests**
  - `scripts/hexgym/build-hexgym-langs.test.mjs`, 3 testes: o `--check` passa com os pacotes do repositório; falha com um pacote mexido (numa cópia temporária); o pacote `pt-BR` traz o nome de `0025` igual ao de `frontend/src/exercise-names/pt-BR.js`.
  - `language.test.mjs`, 3 testes: depois de `setLanguage(en, ptBR)`, `exerciseNameFor(EXIDX['0025'])` dá o nome em português, sem parênteses; `t('Routine')` dá "Rotina" (a herança do `pt.js`); com `de-CH`, a herança do `de` vale.
  - `LanguageTests.swift`, 2 testes: `tag(for:)` com argumentos, nove casos: `["pt-BR"]` dá `"pt-BR"`, `["pt-PT"]` dá `"pt"`, `["de-CH"]` dá `"de-CH"`, `["fr-CA"]` dá `"fr"`, `["nl-NL", "es-MX"]` dá `"es"`, `["nl"]` dá `"en"`, `[]` dá `"en"`, `["zh-Hant-TW"]` dá `"zh-TW"`, `["zh-Hans-CN"]` dá `"zh"`; e `HexEngine(languages: ["pt-BR"]).load().language == "pt-BR"`.
- [ ] **Step 2: Run** `node --test scripts/hexgym/build-hexgym-langs.test.mjs apple/Packages/HexEngine/JS/language.test.mjs` e o comando do pacote do HexEngine com `--filter LanguageTests`. Expected: falham.
- [ ] **Step 3: Implement** o script, o `language.js`, o `Language.swift` e a carga no `load()`.
- [ ] **Step 4: Generate** `node scripts/build-hexgym-langs.mjs && node scripts/build-hexgym-engine.mjs`. O PR diz o tamanho dos pacotes juntos (comprimidos) e o tempo da carga no `engine-load.mjs` (a carga do pacote entra na meta de abrir o motor que já existe; se ela passar, o PR diz quanto e a Task mede de novo com a carga só do idioma do aparelho).
- [ ] **Step 5: The check** A rodada `idiomas em dia` (`node scripts/build-hexgym-langs.mjs --check`) entra na parte `engine`, antes de `script do motor em dia`, e o `check.test.mjs` muda nos testes que prendem a lista de rodadas. Run: `node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `scripts` cresce 3, a `engine` 3 (o `language.test.mjs` cai no glob dela) e a `packages` 2.
- [ ] **Step 6: Commit** "Os idiomas do openGym no motor, com o pacote do idioma do aparelho".

---

### Task 4: A biblioteca no motor

**Depende de:** Task 3.

**Files:**
- Create: `apple/Packages/HexEngine/JS/library.js`, `library.test.mjs`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Library.swift`, `Tests/HexEngineTests/LibraryTests.swift`
- Modify: `runtime.js` (exporta as quatro funções), o script do motor gerado, `scripts/hexgym/engine-load.mjs` (duas metas novas)

**Interfaces:**
- Consumes: o documento aberto (`current`) e o idioma da Task 3.
- Produces (JS, entra e sai texto JSON, como o resto do `runtime.js`):
  - `catalogue()`: todos os exercícios, na ordem do `allExercises(current)`, cada um `{ "id", "name", "bp", "equipment": [..], "category", "muscles": { "<grupo>": peso }, "favourite": bool, "custom": bool }`, com o nome no idioma (`exerciseNameFor`), os pesos do `muscleWeightsOf`, o equipamento do `e.eq` (pode vir vazio num personalizado antigo) e a categoria do `e.cat` (`null` num personalizado, que não tem, `lib/exercises.js:68`). O `bp` é o "grupo principal" que a lista mostra.
  - `search(queryJson)`: `{ "query", "muscles": [grupo], "equipment": [nome], "categories": [nome], "favouritesOnly": bool }` dá `{ "ids": [id] }`, com `searchExercises` para o texto (ele já procura no nome traduzido e no inglês, sem acento), `matchesMuscleGroups`, o equipamento pelo `e.eq` de cada exercício (algum dos escolhidos) e a categoria pelo `e.cat` (alguma das escolhidas), e os favoritos primeiro (`sortFavouritesFirst`). Sem texto e sem filtro, a ordem do catálogo com os favoritos primeiro.
  - `exercise(id)`: `{ "id", "name", "nameEnglish", "bp", "equipment", "category", "muscles", "instructions": [passo], "description", "favourite", "custom", "known": bool }`; um id que não existe dá `known: false` e o nome `t('Unknown exercise')` (Foco da revisão 1).
  - `facets()`: `{ "muscles": [{ "id", "name" }], "equipment": [{ "id", "name" }], "categories": [{ "id", "name" }], "bodyParts": [{ "id", "name" }] }`: as partes do corpo do `bp` na ordem do `BODYPARTS` (as 11), com o nome pelo `t()` (`'upper legs'` vira "pernas"); os grupos na ordem do `MUSCLES`, com o nome `t(MUSCLE_NAME[id])`; o equipamento do `equipmentOf(allExercises(current))` (só o que filtra alguma coisa, 34 hoje, e não o `ALL_EQUIPMENT`); as categorias do `categoriesOf(allExercises(current))`, na ordem do `CATEGORIES`; os nomes pelo `t()`.
- Produces (Swift, em `Library.swift`):

```swift
public struct ExerciseSummary: Codable, Hashable, Identifiable, Sendable {
  public let id: String, name: String, bp: String, equipment: [String], category: String?
  public let muscles: [String: Double], favourite: Bool, custom: Bool
}
public struct LibraryQuery: Codable, Equatable, Sendable {
  public var query: String = "", muscles: [String] = [], equipment: [String] = [], categories: [String] = []
  public var favouritesOnly = false
  public init()
}
public struct ExerciseDetail: Codable, Equatable, Sendable {
  public let id: String, name: String, nameEnglish: String, bp: String, equipment: [String], category: String?
  public let muscles: [String: Double], instructions: [String], description: String?
  public let favourite: Bool, custom: Bool, known: Bool
}
public struct LibraryFacet: Codable, Hashable, Identifiable, Sendable { public let id: String, name: String }
public struct LibraryFacets: Codable, Equatable, Sendable { public let muscles, equipment, categories, bodyParts: [LibraryFacet] }
extension HexEngine {
  public func catalogue() throws -> [ExerciseSummary]
  public func search(_ query: LibraryQuery) throws -> [String]
  public func exercise(_ id: String) throws -> ExerciseDetail
  public func facets() throws -> LibraryFacets
}
```

- [ ] **Step 1: Write the failing tests**
  - `library.test.mjs`, 8 testes (com o documento do `freshState` e o idioma `pt-BR` da Task 3; um personalizado sem categoria entra no documento do teste do catálogo e sai com `category: null`): `catalogue()` tem 5.632 itens mais o personalizado e o `0025` com o nome em português e `muscles.chest == 1`; `search` com "supino", "SUPINO" e "supíno" dá o mesmo primeiro resultado, e com o nome inglês "bench press" também acha o `0025` (Foco da revisão 2); com `muscles: ["chest"]`, todo id tem peito; com `favouritesOnly`, só os favoritos; um favorito vem primeiro; `exercise('nao-existe')` dá `known: false`; `facets().muscles` tem os 18 grupos e `facets().bodyParts` as 11 partes. São oito testes, nesta ordem: o catálogo; as três grafias de "supino"; o "bench press"; o filtro de peito; só favoritos; o favorito primeiro; o desconhecido; o `facets()`.
  - `LibraryTests.swift`, 3 testes: o mesmo caminho de ponta a ponta no JavaScriptCore, com o Codable: `catalogue().count == 5632` (e um documento com um personalizado sem categoria decodifica), `search` com "supino" não vazio, `exercise("0025").instructions` não vazio.
- [ ] **Step 2: Run** `node --test apple/Packages/HexEngine/JS/library.test.mjs` e o comando do pacote com `--filter LibraryTests`. Expected: falham.
- [ ] **Step 3: Implement** `library.js` e `Library.swift`. Nada de lógica de busca no Swift: ele só repassa.
- [ ] **Step 4: The two goals in `engine-load.mjs`**: no `jsc` sem JIT, com 280 treinos, `catalogue()` em menos de 400 ms e `search` de "supino" em menos de 100 ms (as metas das Restrições globais, escolha recomendada, com a delegação do Lipe de 03/11/2026). Run: `node scripts/hexgym/engine-load.mjs`. Expected: as metas passam, e o PR diz os tempos medidos. Se a busca passar de 100 ms, a Task não entra: ela guarda um índice de texto normalizado no `library.js`, feito uma vez por idioma, e mede de novo.
- [ ] **Step 5: Generate and check** Run: `node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `engine` cresce 8, a `packages` 3 e a `load` passa de 3 para 5.
- [ ] **Step 6: Commit** "A biblioteca no motor: o catálogo, a busca, os filtros e o detalhe".

---

### Task 5: As ações sobre o documento e a gravação

**Depende de:** Task 4.

**Files:**
- Create: `apple/Packages/HexEngine/JS/actions.js`, `actions.test.mjs`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/Actions.swift`, `Tests/HexEngineTests/ActionsTests.swift`
- Modify: `runtime.js`, o script do motor gerado
- Modify: `apple/HexGym/AppModel.swift`, `apple/HexGymTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `draftOf` (`lib/state-core.js`), `stampChange` (`lib/sync-merge.js`), `copyRoutine`, `deleteRoutine`, `routineSnapshot`, `restoreRoutine`, `replaceSlotExercise` (`lib/routines.js`), `pickedExerciseConfig`, `setsRepsOf`, `pairAdjacent`, `unpairSuperset`, `cleanupSg` (`lib/history.js`), `buildStarterPlan`, `starterPlanOptions` (`lib/starter.js`), `convertStateUnit` (`lib/units.js`), `toggleFav` (`lib/favourites.js`), `loadOfRoutine` (`lib/muscles.js`), `uid` (`lib/format.js`), `ROUTINE_GLYPHS` e `DEFAULT_GLYPH` (`api/coach/core/glyphs.js`: o `lib/glyphs.js` importa o `components/Icon.jsx` e não entra no motor; a lista é a mesma, presa pelo `coach-parity.test.js`), `undoMarks` e `markUndone` (`lib/sync-merge.js`).
- Produces (JS):
  - `apply(actionJson, now)`: roda uma ação num rascunho do documento aberto e, se ela mudou alguma coisa, carimba como o `update()` do `store/useStore.js` (`S._ts = stampChange(prev, S, now)`), troca o `current` e devolve `{ "changed": bool, "result": … }`. Uma ação inválida lança `TypeError` e o documento fica como estava. As ações (`type` e os campos):
    - `routine.create { name }` → `result: { id }`; a rotina nova é `{ id: uid(), name, emoji: DEFAULT_GLYPH, ex: [] }`, no fim da lista; nome vazio vira `t('New routine')`, como o openGym (`views/Plan.jsx:422`).
    - `routine.rename { id, name }` (aparado; vazio vira `t('New routine')`, como no `routine.create`), `routine.glyph { id, glyph }` (só um dos `ROUTINE_GLYPHS`), `routine.duplicate { id }` (`copyRoutine` com `t('Copy')`, logo depois da original) → `result: { id }`, `routine.move { from, to }`.
    - `routine.delete { id }` → `result: { snapshot }`: o `routineSnapshot` de antes, com `snapshot.marks = undoMarks(antes, depois)`, em que o depois é o documento já carimbado pelo `stampChange` da remoção, como o `deleteRoutineWithUndo` do `views/Plan.jsx` lê o estado depois do `update`; `routine.restore { snapshot }` aplica o `restoreRoutine` e, quando ele devolve verdadeiro e há `marks`, o `markUndone` (é o que faz a rotina devolvida ganhar de uma remoção carimbada noutro aparelho); quando o `restoreRoutine` devolve falso (a rotina já voltou por outro caminho), `changed: false`. Apagar tira a rotina dos dias do `week` (Foco da revisão 4).
    - `slot.add { routineId, exerciseIds, at? }`: cada um com o `pickedExerciseConfig(id)` e o `id`, como o seletor do `RoutineEdit.jsx` do openGym adiciona; `at` ausente é o fim.
    - `slot.remove { routineId, index }`, `slot.move { routineId, from, to }` (com o `cleanupSg` depois, para um superset desfeito pela mudança não ficar pela metade), `slot.replace { routineId, index, exerciseId }` (`replaceSlotExercise`), `slot.superset { routineId, index }` (junta com o seguinte, `pairAdjacent`) e `slot.unsuperset { routineId, index }`.
    - `slot.update { routineId, index, fields }`: só `sets`, `reps`, `repsMin`, `weight`, `sec`, `mode` (`reps` ou `time`) e `note`. O openGym não tem teto (o salvar da sheet só faz `Math.max(1, ...)`), então os limites são escolha recomendada, com a delegação do Lipe de 03/11/2026: `sets` de 1 a 20, `reps` de 1 a 100, `repsMin` de 1 até o `reps`, `sec` de 1 a 3.600, `weight` de 0 a 1.000 na unidade do perfil, e `note` com até `NOTE_MAX` (500) letras. Fora deles a ação lança `TypeError` e não ajusta nada: as telas só mandam valores dentro dos limites, e um valor de fora é erro de quem chamou. Um documento do openGym com um valor acima do limite abre normalmente; só um valor novo é conferido.
    - `week.set { day, routineIds }`: `day` de 0 a 6 (o `getDay()`), `routineIds` vazio apaga o dia; ids que não são rotinas lançam `TypeError`.
    - `plan.starter { planId }`: o que o `loadStarterPlan` do `sheets.jsx` faz, reescrito no `actions.js` com o `buildStarterPlan` (o `sheets.jsx` puxa o React e não entra no motor), sem o perfil de equipamento: reaproveita as rotinas iguais de antes e só troca os dias do plano → `result: { routines: n }`. Os nomes das rotinas ficam em inglês, como o `buildStarterPlan` faz no openGym (`lib/starter.js:6`: "Names stay canonical English").
    - `settings.set { key, value }`: só `unit` (`kg` ou `lb`, pelo `convertStateUnit`), `body` (`male` ou `female`), `weekStart` (0 ou 1), `restSec` (inteiro de 0 ao `REST_MAX` do `lib/duration.js`, 900) e `effort` (`none`, `rir` ou `rpe`). Qualquer outra chave lança `TypeError` (o `theme`, o `accent` e o `lang` nunca: escolha 4, escolha recomendada, com a delegação do Lipe de 03/11/2026).
    - `favourite.toggle { id }` (`toggleFav`).
  - Leituras, sem mudar nada: `routines()` → `[{ "id", "name", "glyph", "slots": [{ "id", "name", "known", "setsReps", "increment", "sets", "reps", "repsMin", "weight", "sec", "mode", "note", "superset": id ou null }], "muscles": { "<grupo>": carga }, "days": [dia] }]`, com o `glyph` pelo `glyphStr` do `api/coach/core/glyphs.js` (um emoji antigo passa como está, e a Task 11 o traduz), com o `setsRepsOf`, o `loadOfRoutine` e o `increment` de cada slot (o `defaultIncrement(id, unit)` do `lib/exercises.js`, na unidade do perfil); `week()` → `{ "weekStart", "days": [{ "day", "routineIds" }] }` na ordem da semana do perfil; `settings()` → `{ "unit", "body", "weekStart", "restSec", "effort" }`; `starterPlans()` → `[{ "id", "days" }]` do `starterPlanOptions`.
- Produces (Swift, em `Actions.swift`):

```swift
public enum EngineAction: Encodable, Sendable {
  case createRoutine(name: String)
  case renameRoutine(id: String, name: String)
  case setRoutineGlyph(id: String, glyph: String)
  case duplicateRoutine(id: String)
  case moveRoutine(from: Int, to: Int)
  case deleteRoutine(id: String)
  case restoreRoutine(snapshot: RoutineSnapshot)
  case addExercises(routineID: String, exerciseIDs: [String], at: Int?)
  case removeSlot(routineID: String, index: Int)
  case moveSlot(routineID: String, from: Int, to: Int)
  case replaceSlot(routineID: String, index: Int, exerciseID: String)
  case superset(routineID: String, index: Int)
  case unsuperset(routineID: String, index: Int)
  case updateSlot(routineID: String, index: Int, fields: SlotFields)
  case setWeekDay(day: Int, routineIDs: [String])
  case loadStarterPlan(id: String)
  case setSetting(SettingChange)
  case toggleFavourite(id: String)
}
public struct RoutineSnapshot: Codable, Equatable, Sendable { /* o JSON do routineSnapshot com os marks, guardado como veio (um JSONValue) e devolvido igual */ }
public struct SlotFields: Codable, Equatable, Sendable { public var sets, reps, repsMin: Int?; public var weight: Double?; public var sec: Int?; public var mode: String?; public var note: String? }
public enum SettingChange: Encodable, Equatable, Sendable { case unit(String), body(String), weekStart(Int), restSec(Int), effort(String) }
// O JS devolve { changed, result: { id?, snapshot?, routines? } }; o Decodable lê o result por dentro e deixa plano.
public struct ActionOutcome: Decodable, Equatable, Sendable { public let changed: Bool; public let id: String?; public let snapshot: RoutineSnapshot?; public let routines: Int? }
public struct RoutineSummary: Codable, Hashable, Identifiable, Sendable {
  public let id: String, name: String, glyph: String, slots: [SlotSummary], muscles: [String: Double], days: [Int]
}
public struct SlotSummary: Codable, Hashable, Sendable {
  public let id: String, name: String, known: Bool, setsReps: String, increment: Double
  public let sets: Int?, reps: Int?, repsMin: Int?, weight: Double?, sec: Int?
  public let mode: String?        // reps, time ou cardio (o cardio do openGym só é lido nesta fase)
  public let note: String?, superset: String?
}
public struct WeekPlan: Codable, Equatable, Sendable {
  public struct Day: Codable, Equatable, Sendable { public let day: Int, routineIds: [String] }
  public let weekStart: Int, days: [Day]
}
public struct DocumentSettings: Codable, Equatable, Sendable { public let unit: String, body: String, weekStart: Int, restSec: Int, effort: String? }
public struct StarterPlanOption: Codable, Hashable, Identifiable, Sendable { public let id: String, days: Int }
extension HexEngine {
  public func apply(_ action: EngineAction, now: Date = .now) throws -> ActionOutcome
  public func routines() throws -> [RoutineSummary]
  public func week() throws -> WeekPlan
  public func settings() throws -> DocumentSettings
  public func starterPlans() throws -> [StarterPlanOption]
}
```

- Produces (app, em `AppModel`):

```swift
extension AppModel {
  // Aplica a ação no motor e, se ela mudou o documento, pede a gravação. A gravação junta as ações
  // de 0,5 s numa só e sai na hora quando o app vai para o fundo (flush()). Devolve o resultado da ação.
  func perform(_ action: EngineAction) async throws -> ActionOutcome
  func flush() async
  var revision: Int { get }        // sobe a cada ação que mudou o documento, para as telas lerem de novo
}
```

O `AppModel` expõe o `engine` para as leituras das telas (`model.engine.routines()`), e as telas leem de novo quando o `revision` muda. O `HexGymApp` chama `flush()` quando a cena vai para `.background`.

- [ ] **Step 1: Write the failing tests** em `actions.test.mjs`, 27 testes:
  - cada ação da lista acima (18 testes, um por ação), num documento do `freshState`, com o resultado esperado;
  - `apply` carimba: a rotina mexida ganha `_ts` igual ao `now` passado (ou maior, se o documento já tinha um carimbo maior), e uma rotina que a ação não mexeu fica com o `_ts` de antes;
  - um documento com uma chave desconhecida (`{"x-futuro": 1}`) e um `customEx` passa por `routine.create` e sai com as duas (Foco da revisão 1);
  - uma rotina com o id de exercício `nao-existe` sai em `routines()` com `known: false` e o nome `t('Unknown exercise')`;
  - `settings.set unit lb` converte o peso de uma rotina como o `convertStateUnit`, e voltar para `kg` dá o valor de antes dentro do arredondamento dele (Foco da revisão 3);
  - `routine.delete` de uma rotina que está na segunda e na quinta tira ela dos dois dias, e `routine.restore` com o snapshot devolve a rotina e os dois dias (Foco da revisão 4);
  - `settings.set` com `theme`, `accent` ou `lang` lança `TypeError`, e o documento não muda;
  - `routine.restore` com um snapshot de uma rotina que estava na segunda e na quinta aplica o `markUndone`: o `undone` do documento ganha as chaves `week.1` e `week.4` das marcas;
  - `slot.update` com `sets: 0` ou acima do limite lança `TypeError`;
  - `plan.starter ppl` duas vezes não duplica as rotinas.
- [ ] **Step 2: Write the failing Swift tests**, 4 testes: `ActionsTests.swift`, 2 (o Encodable de cada `EngineAction` dá o JSON que o `actions.js` espera; `createRoutine` e depois `routines()` no JavaScriptCore) e, em `AppModelTests.swift`, 2: `perform` grava o documento uma vez para duas ações em menos de 0,5 s, e `flush()` grava na hora (com um `DocumentStore` numa pasta temporária).
- [ ] **Step 3: Run** `node --test apple/Packages/HexEngine/JS/actions.test.mjs`, o comando do pacote com `--filter ActionsTests` e `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 4: Implement** `actions.js`, `Actions.swift` e o `perform` do `AppModel`.
- [ ] **Step 5: Generate and check** Run: `node scripts/build-hexgym-engine.mjs && node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `engine` cresce 27, a `packages` 2 e a `app` 2.
- [ ] **Step 6: Commit** "As ações sobre o documento, com o carimbo do openGym, e a gravação no app".

---

### Task 6: As abas e os ajustes básicos

**Depende de:** Task 5.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** as três abas (escolha 1), os ajustes nesta ordem e a galeria no fim.

**Files:**
- Create: `apple/HexGym/RootView.swift`, `apple/HexGym/Settings/SettingsView.swift`, `apple/HexGym/Settings/LicensesView.swift`, `apple/HexGym/Settings/SettingsRows.swift`
- Create: `apple/HexGymTests/SettingsRowsTests.swift`
- Modify: `apple/HexGym/HexGymApp.swift`, `apple/HexGym/Localizable.xcstrings`, `apple/HexGym/Gallery/GalleryView.swift` (recebe o `GalleryRoute`, que hoje mora no `ContentView.swift:35`; o `-HexGymGallery YES` passa a abrir os Ajustes com a galeria aberta)
- Delete: `apple/HexGym/ContentView.swift`
- Create: `docs/hexgym/prints/<issue>/`

**Interfaces:**
- Consumes: `AppModel.perform`, `engine.settings()`, `ThemeModel`.
- Produces:
  - `RootView(model:)`: a `TabView` da Apple com as abas `Rotinas` (`list.bullet.rectangle`), `Exercícios` (`dumbbell`) e `Ajustes` (`gearshape`), cada uma com o seu `NavigationStack`; enquanto o `AppModel.state` é `.starting`, um `ProgressView`; em `.failed`, a tela de erro de antes ("Não deu para abrir os seus dados."), sem abas. As abas Rotinas e Exercícios mostram, até as Tasks 9 e 11, um `ContentUnavailableView` com o nome da aba.
  - `enum RootTab: String { case routines = "rotinas", library = "exercicios", settings = "ajustes" }`, e o argumento `-HexGymTab <valor>`.
  - Os ajustes, uma `List` da Apple em seções: **Treino** (unidade kg ou lb; descanso padrão, num `Picker` de 30 s a 5 min de 15 em 15 s, mais o valor do documento quando ele está fora dessa lista (um documento do openGym pode ter até 15 min, ou fora do passo de 15 s), que aparece como mais uma opção; escala de esforço nenhuma, RIR ou RPE); **Semana** (começa no domingo ou na segunda); **Corpo** (masculino ou feminino); **Aparência** (o tema, com os quatro nomes da fase 1 e a cor de cada um); **Sobre** (a versão, "Licenças", que abre a `LicensesView`, e "Galeria do design system").
  - `struct SettingsRows`: os valores e os rótulos de cada linha (pt-BR e inglês), testados sem tela.
  - `LicensesView`: o openGym (AGPL-3.0-or-later), a Barlow Condensed (SIL OFL 1.1, com o texto do `OFL.txt` do HexDesign), o MuscleMap (MIT, Melih Colpan, com o texto de `scripts/hexbody/musclemap/LICENSE-MuscleMap`, copiado para o app) e o aviso de que o HexGym é um fork não oficial do openGym.

- [ ] **Step 1: Write the failing tests** em `SettingsRowsTests.swift`, 4 testes: as opções do descanso vão de 30 a 300 de 15 em 15, e um documento com 420 ganha a opção 420; o rótulo de 90 é "1:30" (e "1 min 30 s" para o VoiceOver); a unidade troca para lb por uma `SettingChange.unit("lb")`; trocar o tema não gera ação nenhuma no motor (fica no `ThemeModel`, seção 8.12).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a raiz, as abas, os ajustes e as licenças; tirar o `ContentView`.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 4.
- [ ] **Step 5: Prints**: os Ajustes no Ultravioleta e no Cobre, em tamanho padrão e em AX5, e as Licenças, com `-HexGymTab ajustes` (a primeira abertura só chega na Task 7, que passa a pôr `-HexGymSkipOnboarding YES` nos prints). Um vídeo curto trocando a unidade e o tema.
- [ ] **Step 6: Commit** "As abas do app e os ajustes básicos".

---

### Task 7: A primeira abertura

**Depende de:** Task 6.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 2 e a 3, e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Onboarding/OnboardingView.swift`, `apple/HexGym/Onboarding/OnboardingFlow.swift`
- Create: `apple/HexGymTests/OnboardingFlowTests.swift`
- Modify: `apple/HexGym/RootView.swift`, `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `AppModel.perform(.setSetting(...))`, `ThemeModel`, `AppModel.State.ready(Status)` com a origem.
- Produces:
  - `struct OnboardingFlow`: os passos `unit`, `theme` e `body`, o passo atual, `next()`, `skip()` e o que vai ser gravado no fim; `static func shouldShow(origin: AppModel.Origin, seen: Bool) -> Bool` (mostra quando o documento foi criado agora ou quando este aparelho nunca viu a primeira abertura).
  - A marca de que o aparelho já viu: `UserDefaults` do App Group, chave `hexgym.onboarded` (`true`), no aparelho e não no documento, como o tema.
  - O texto: passo 1 "Em que você levanta?" com "Quilos (kg)" e "Libras (lb)"; passo 2 "Escolha a sua cor" com os quatro temas e a prévia ao vivo (o brilho muda na hora); passo 3 "Qual corpo mostra os seus músculos?" com "Masculino" e "Feminino" e a linha "Dá para trocar depois nos Ajustes."; botões "Continuar" (o principal do HexDesign), "Pular" e, no fim, "Começar". Em inglês: "What do you lift in?", "Pounds (lb)", "Pick your color", "Which body shows your muscles?", "You can change this later in Settings.", "Continue", "Skip", "Get started".
  - A unidade e o corpo são gravados no fim, numa ação cada; o tema, pelo `ThemeModel`, na hora.

- [ ] **Step 1: Write the failing tests** em `OnboardingFlowTests.swift`, 5 testes: `shouldShow(.created, seen: false)` é verdadeiro; `shouldShow(.opened, seen: true)` é falso; `shouldShow(.opened, seen: false)` é verdadeiro (um aparelho novo com um documento que veio do backup ainda escolhe o tema, e a unidade e o corpo já vêm marcados com o que o documento tem); `skip()` no passo 1 vai para o 2 sem mudar a unidade; o fim grava só o que mudou (nenhuma ação se nada mudou).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a tela e o fluxo, com os argumentos `-HexGymOnboarding YES` e `-HexGymSkipOnboarding YES`. Reduzir Movimento troca a passagem entre os passos por um esmaecido. O VoiceOver diz "Passo 1 de 3".
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 5.
- [ ] **Step 5: Prints e vídeo**: os três passos no Ultravioleta, o passo do tema no Ciano, e o passo 1 em AX5; um vídeo do caminho inteiro.
- [ ] **Step 6: Commit** "A primeira abertura: unidade, tema e corpo".

---

### Task 8: O pacote HexBody com as regiões de cada exercício

**Depende de:** Task 2.

**Files:**
- Create: `apple/Packages/HexBody/Package.swift`, `Sources/HexBody/RegionCatalog.swift`, `Sources/HexBody/Resources/exercise-regions.json`, `Sources/HexBody/Resources/Strings/en.lproj/Regions.strings`, `pt-BR.lproj/Regions.strings`, `Tests/HexBodyTests/RegionCatalogTests.swift`
- Modify: `scripts/hexbody/regions/build_exercise_regions.py` (a saída `--app`), `test_build_exercise_regions.py`
- Modify: `apple/HexGym.xcodeproj/project.pbxproj` (o pacote no alvo `HexGym`), `scripts/hexgym/project-format.test.mjs`, `scripts/hexgym/check.mjs`, `check.test.mjs` (a rodada `HexBody` na parte `packages`, depois da `HexDesign`, como ela)

**Interfaces:**
- Consumes: o `exercise_regions_v2.json` e o `regions_v2.json` das Tasks 1 e 2.
- Produces:
  - O gerador também grava (e o `--check` também confere) `apple/Packages/HexBody/Sources/HexBody/Resources/exercise-regions.json`, compacto: `{ "regions": [{ "id", "group", "watchGroup" }]` (o `watchGroup` é `null` no `sternocleidomastoid` e no `neckBack`, como no `regions_v2.json`), "exercises": { "<id>": [primário, secundário, ênfase] } }`, cada lista com os índices das regiões, sem o nome e sem a fonte. Os 922 desenhos femininos entram pelo id deles.
  - Swift (o código só usa Foundation; `platforms` iOS 26 e macOS 26; o `Package.swift` tem `defaultLocalization: "en"` e `resources: [.copy("Resources/exercise-regions.json"), .process("Resources/Strings")]`, e o `name(of:locale:)` acha o `Regions.strings` do idioma pelo mesmo jeito do `HexStrings` do HexDesign, `HexEnvironment.swift:60-90`):

```swift
public enum BodyFigure: String, CaseIterable, Sendable { case male, female }
public struct BodyRegion: Hashable, Identifiable, Sendable { public let id: String, group: String, watchGroup: String? }
public struct ExerciseRegions: Equatable, Sendable {
  public let primary: [BodyRegion], secondary: [BodyRegion], emphasis: [BodyRegion]
  public func weight(of region: BodyRegion) -> Double   // 1 no primário, 0,4 no secundário, 0 fora
}
public final class RegionCatalog: Sendable {
  public static let bundled: RegionCatalog              // lido uma vez, do Bundle.module
  public let regions: [BodyRegion]                      // as 36, na ordem do regions_v2.json
  public func regions(for exerciseID: String) -> ExerciseRegions?
  public func name(of region: BodyRegion, locale: Locale = .current) -> String   // do Regions.strings
}
```

  Os nomes em português são os do `regions_v2.json`; os em inglês, os nomes anatômicos de costume (o PR mostra a tabela).

- [ ] **Step 1: Write the failing tests**: no Python, 1 teste, o `--check` falha quando o `exercise-regions.json` do app não bate; no Swift, 4 testes: `bundled.regions.count == 36`, `regions(for: "0025")` tem `chest` no primário e `triceps` no secundário com peso 0,4, um id que não existe dá `nil`, e todo nome existe nos dois idiomas (nenhum `name(of:)` devolve o próprio id).
- [ ] **Step 2: Run** `python3 -I scripts/hexbody/regions/run_tests.py` e o comando do pacote do HexBody. Expected: falham.
- [ ] **Step 3: Implement** o `--app` e o pacote; pôr o pacote no projeto e na parte `packages`.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs`. Expected: tudo passa; a parte `scripts` cresce 1 e a `packages` 4, na rodada nova do HexBody. O PR diz o tamanho do JSON do app.
- [ ] **Step 5: Commit** "O pacote HexBody com as regiões de cada exercício".

---

### Task 9: A biblioteca: lista, busca e filtros

**Depende de:** Tasks 4 e 6.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 6, os filtros num botão da barra que abre uma tela que sobe (com contagem no botão quando há filtro), e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Library/LibraryView.swift`, `LibraryModel.swift`, `LibraryFilterSheet.swift`, `ExerciseRow.swift`
- Create: `apple/HexGymTests/LibraryModelTests.swift`
- Modify: `apple/HexGym/RootView.swift`, `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.catalogue()`, `engine.search(_:)`, `engine.facets()`, `AppModel.perform(.toggleFavourite)`.
- Produces:
  - `@Observable @MainActor final class LibraryModel`: guarda o catálogo uma vez (um dicionário por id), a `LibraryQuery` atual, os ids do resultado e o estado; `func update(query:)` pede a busca ao motor 150 ms depois da última letra (a busca anterior é cancelada), e só a última resposta vale; `var activeFilterCount: Int`; `func summary(_ id: String) -> ExerciseSummary?`.
  - `LibraryView(model:selection:onAdd:)`, com `selection: Binding<[String]>?` (a ordem é a dos toques, que vira a ordem dos slots) e `onAdd: (([String]) -> Void)?`: a `List` com `.searchable` (o texto "Buscar exercícios"), uma linha por exercício (`ExerciseRow`: o nome em `.body`, embaixo o grupo principal (o `bp`, pelo nome do `facets().bodyParts`) e o equipamento em `.secondary`, a estrela dos favoritos), `.swipeActions` para favoritar, e o `ContentUnavailableView.search` quando não há resultado. Com `selection` (a Task 11 usa), a lista vira múltipla escolha com o botão "Adicionar (n)" na barra, que chama `onAdd` com os ids na ordem dos toques.
  - `LibraryFilterSheet`: grupos musculares, equipamento e categoria em listas com marca, e "Só favoritos", com "Limpar" e "Pronto".
  - Os nomes do grupo e do equipamento na linha vêm do `facets()`.

- [ ] **Step 1: Write the failing tests** em `LibraryModelTests.swift`, 6 testes, com o motor de verdade: o catálogo carrega 5.632; "supino" dá resultado e o primeiro tem "supino" no nome em pt-BR; duas buscas seguidas ("sup" e "supino") deixam só o resultado da segunda; um filtro de peito deixa `activeFilterCount == 1`; uma busca sem resultado deixa o estado vazio; o rótulo do VoiceOver de uma linha junta o nome, o grupo, o equipamento e "favorito" (Foco da revisão 5: um nome com 70 letras vai inteiro no rótulo).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a lista, a busca e os filtros. A linha não calcula nada no `body`: os textos vêm prontos do modelo.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 6.
- [ ] **Step 5: Prints e vídeo**: a lista, a busca "supino", os filtros abertos, a lista com dois filtros e o estado vazio, no Ultravioleta; a lista em AX5 com um nome longo em alemão (o aparelho em `de`). Um vídeo rolando a lista inteira depressa e buscando. O PR diz se a rolagem perdeu quadro (Instruments, Hangs e Hitches, ou o contador de quadros do simulador).
- [ ] **Step 6: Commit** "A biblioteca: os 5.632 exercícios com busca e filtros".

---

### Task 10: O detalhe do exercício

**Depende de:** Tasks 8 e 9.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 7, com as regiões em lista até a Task 14, e a ordem da tela abaixo.

**Files:**
- Create: `apple/HexGym/Library/ExerciseDetailView.swift`, `ExerciseDetailModel.swift`, `MuscleList.swift`
- Create: `apple/HexGymTests/ExerciseDetailModelTests.swift`
- Modify: `apple/HexGym/Library/LibraryView.swift` (a navegação), `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.exercise(_:)`, `RegionCatalog.bundled`, `engine.routines()`, `AppModel.perform(.addExercises(...))`, `.toggleFavourite`.
- Produces:
  - A tela, de cima para baixo: o nome em `.hexFont(.title)` (quebra linha, sem teto de linhas); o equipamento e a categoria; um `HexGlassCard` "Músculos" com o espaço do corpo (até a Task 14, a `MuscleList`: "Principal" com as regiões do primário e "Também trabalha" com as do secundário, pelos nomes do `RegionCatalog`; sem regiões, os grupos do `muscles` do motor); "Como fazer", os passos numerados; a descrição, quando há; e, na barra, a estrela e o botão "Adicionar à rotina", que abre um `Menu` com as rotinas e "Nova rotina".
  - `struct ExerciseDetailModel`: monta as linhas da tela a partir do `ExerciseDetail` e do `ExerciseRegions?` (a ordem das regiões, os rótulos, o texto do VoiceOver do cartão dos músculos). O texto falado separa as regiões por ponto e vírgula, porque há nomes com vírgula ("Tríceps, cabeças lateral e medial"): "Principal: <região>; <região>. Também trabalha: <região>; <região>.", na ordem do `RegionCatalog`, com os nomes do `name(of:)` (escolha recomendada, com a delegação do Lipe de 03/11/2026).
  - Um exercício com `known: false` mostra só o nome "Exercício desconhecido" e uma linha dizendo que ele não está na biblioteca deste aparelho.

- [ ] **Step 1: Write the failing tests**, 4 testes: o `0025` em pt-BR tem "Principal" com as regiões de peito e "Também trabalha" com tríceps, como o `exercise-regions.json` das Tasks 1 e 2 diz; com uma fixture de `ExerciseRegions` (primário `upperChest` e `chest`, secundário `frontDeltoid` e `triceps`), o texto do VoiceOver é "Principal: Peito alto; Peito médio. Também trabalha: Deltoide frontal; Tríceps, cabeças lateral e medial." (a ordem do `RegionCatalog`); um exercício sem regiões cai nos grupos do motor; `known: false` dá a tela do desconhecido.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a tela e o modelo; "Adicionar à rotina" aplica `addExercises` e mostra a confirmação do sistema (um `sensoryFeedback(.success)` e o texto "Adicionado a <rotina>").
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 4.
- [ ] **Step 5: Prints**: o supino, um agachamento e uma prancha, em tamanho padrão e em AX5; o desconhecido.
- [ ] **Step 6: Commit** "O detalhe do exercício, com os músculos e os passos".

---

### Task 11: O editor de rotina

**Depende de:** Tasks 5 e 9.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 9, e as telas e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Routines/RoutinesView.swift`, `RoutineEditorView.swift`, `SlotEditor.swift`, `RoutineGlyph.swift`, `RoutineEditorModel.swift`
- Create: `apple/HexGymTests/RoutineEditorModelTests.swift`, `RoutineGlyphTests.swift`
- Modify: `apple/HexGym/RootView.swift`, `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.routines()`, `AppModel.perform(...)` com as ações de rotina e de slot, `LibraryView(model:selection:onAdd:)` da Task 9, `LoadInput`, `RepsInput` e `WorkoutInputLayout` do HexDesign.
- Produces:
  - `RoutinesView`: a lista das rotinas (o ícone, o nome, "6 exercícios", os dias da semana em que ela está), com "Nova rotina" na barra, `.onMove` para reordenar, `.swipeActions` com "Duplicar" e "Apagar". Apagar mostra uma faixa "Rotina apagada" com "Desfazer" por 5 s, que aplica `restoreRoutine` com o snapshot (Foco da revisão 4). Sem rotinas, a tela vazia da Task 12 (até lá, um `ContentUnavailableView` com "Nova rotina").
  - `RoutineEditorView`: o nome (um `TextField` da Apple, "Nome da rotina"), o ícone (um `Menu` com os 20 glyphs), e a lista dos exercícios: cada linha com o nome e o `setsReps`, aberta para editar no `SlotEditor` (uma tela que sobe), com `.onMove`, `.swipeActions` ("Remover", "Trocar exercício") e o botão "Adicionar exercícios", que abre a biblioteca em modo de escolha. Dois exercícios seguidos podem virar superset pelo menu da linha ("Juntar com o próximo" e "Separar"), com a marca do superset na lateral das duas linhas.
  - `SlotEditor`: séries (o `Stepper` da Apple, de 1 a 20), repetições (o `RepsInput` do HexDesign, de 1 a 100) ou, no modo "Tempo", os segundos (o `Stepper` da Apple, de 5 em 5 s, até 3.600), a carga (`LoadInput`, com o passo do `increment` do `SlotSummary`, da Task 5), o modo ("Repetições" ou "Tempo") e a nota. O `RepsInput` tem o rótulo e a fala fixos de repetições, por isso não serve para séries nem segundos (escolha recomendada, com a delegação do Lipe de 03/11/2026; os limites são os do `slot.update`, Task 5). Cada toque aplica `updateSlot` (o desempenho da seção 8.13: a tela muda na hora, e a ação vai ao motor sem esperar).
  - `enum RoutineGlyph`: `static func symbol(for glyph: String) -> String`, a tabela dos 20 glyphs do `lib/glyphs.js` com um SF Symbol cada (`figureStrength` → `figure.strengthtraining.traditional`, `arm` → `figure.arms.open`, `abs` → `figure.core.training`, `legs` → `figure.step.training`, `pullup` → `figure.climbing`, `dumbbell` → `dumbbell`, `barbell` → `figure.strengthtraining.functional`, `kettlebell` → `scalemass`, `plate` → `circle.circle`, `machine` → `gearshape.2`, `figureRun` → `figure.run`, `bike` → `figure.outdoor.cycle`, `swim` → `figure.pool.swim`, `boxing` → `figure.boxing`, `timer` → `timer`, `stretch` → `figure.flexibility`, `moon` → `moon`, `heart` → `heart`, `flame` → `flame`, `bolt` → `bolt`), os sete glyphs antigos com um SF Symbol também (`trophy` → `trophy`, `medal` → `medal`, `crown` → `crown`, `flag` → `flag`, `star` → `star`, `target` → `target`, `shield` → `shield`), um emoji antigo pelo mapa `LEGACY` do `glyphOf` do openGym (`💪` vira `arm`, copiado do `lib/glyphs.js` para o Swift, com o mesmo corte de seletor de variação), e só um desconhecido cai no do `DEFAULT_GLYPH`.
  - `struct RoutineEditorModel`: os textos e as decisões da tela que dá para testar sem ela (o rótulo "6 exercícios" com plural, os dias "Seg, Qui" na ordem da semana do perfil, o que o "Desfazer" aplica, o rótulo do VoiceOver de uma linha com superset).

- [ ] **Step 1: Write the failing tests**, 7 testes: `RoutineGlyphTests`, 3 (todo glyph do `GLYPHS` e dos antigos tem símbolo, e cada símbolo existe, conferido com `UIImage(systemName:) != nil` no simulador; `💪` dá o do `arm`; um desconhecido dá o do padrão); `RoutineEditorModelTests`, 4 (o plural de 1 e de 6 exercícios nos dois idiomas; os dias com a semana começando no domingo e na segunda; apagar e desfazer com o motor de verdade devolve a rotina e os dias; uma rotina com um exercício desconhecido mostra "Exercício desconhecido" na linha, Foco da revisão 1).
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** as três telas e o modelo.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 7.
- [ ] **Step 5: Prints e vídeo**: a lista de rotinas, o editor com seis exercícios e um superset, o `SlotEditor`, a escolha dos exercícios e a faixa do desfazer; o editor em AX5 (as entradas empilham). Um vídeo montando uma rotina do zero: nome, ícone, três exercícios, séries e carga.
- [ ] **Step 6: Commit** "O editor de rotina, com o seletor de exercícios e o desfazer".

---

### Task 12: O plano da semana e os planos prontos

**Depende de:** Task 11.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 10, o plano da semana no topo da aba Rotinas e o texto abaixo.

**Files:**
- Create: `apple/HexGym/Plan/WeekPlanView.swift`, `StarterPlansView.swift`, `WeekPlanModel.swift`
- Create: `apple/HexGymTests/WeekPlanModelTests.swift`
- Modify: `apple/HexGym/Routines/RoutinesView.swift`, `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: `engine.week()`, `engine.routines()`, `engine.starterPlans()`, `AppModel.perform(.setWeekDay(...))`, `.loadStarterPlan(id:)`.
- Produces:
  - No topo da aba Rotinas, a semana: sete linhas (na ordem do `weekStart`), cada uma com o dia e as rotinas dele, ou "Descanso". Tocar num dia abre a escolha das rotinas daquele dia (uma lista com marca, mais de uma é permitida, como no openGym).
  - `StarterPlansView`: a tela vazia da aba (sem rotinas): "Monte a sua primeira rotina" com o botão principal "Nova rotina" e, embaixo, "Ou comece com um plano pronto", os quatro planos (os nomes e as descrições do `PLAN_COPY` do `sheets.jsx`, traduzidos no catálogo do app: "Empurrar, puxar, pernas", "Superior e inferior", "Corpo inteiro" e "5×5"), cada um com os dias que ele ocupa. Escolher um aplica `loadStarterPlan` e mostra a semana montada. Com rotinas, os planos prontos ficam num item "Planos prontos" do menu da barra.
  - `struct WeekPlanModel`: os dias na ordem, os rótulos ("Seg", "Segunda-feira" para o VoiceOver), "Descanso", os dias que um plano pronto vai trocar (para o aviso "Este plano troca segunda, quarta e sexta.").

- [ ] **Step 1: Write the failing tests**, 4 testes: a ordem dos dias com `weekStart` 0 e 1; um dia sem rotina diz "Descanso"; com o motor de verdade, `loadStarterPlan("ppl")` deixa segunda, quarta e sexta com as rotinas e os outros dias como estavam; o aviso diz os dias certos.
- [ ] **Step 2: Run** `node scripts/hexgym/check.mjs app`. Expected: falham.
- [ ] **Step 3: Implement** a semana, a escolha do dia e os planos prontos.
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs app`. Expected: passa, e a parte `app` cresce 4.
- [ ] **Step 5: Prints e vídeo**: a tela vazia com os planos prontos, a semana com o PPL, a escolha de um dia, e a semana em AX5. Um vídeo do founder montando a própria rotina: do app vazio até a semana pronta (é o "o founder vê" da fase).
- [ ] **Step 6: Commit** "O plano da semana e os planos prontos".

---

### Task 13: Os desenhos do corpo

**Depende de:** Task 8 e **#10** (a cópia de `scripts/hexbody/work/` fora desta máquina e a procedência da imagem de referência, no `/decide 10` do founder). Sem a #10 resolvida, a Task não começa.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 8 e os tamanhos abaixo.

**Files:**
- Create: `scripts/hexbody/blender/app_art.py`, `scripts/hexbody/regions/test_app_art.py` (Python unittest, só com a biblioteca padrão: lê o tamanho das PNG pelo cabeçalho; o `run_tests.py` da Task 1 já acha ele)
- Create: `apple/Packages/HexBody/Sources/HexBody/Resources/Art/<male|female>/<front|back>/base.png`, `regions/<região>.png` e `layout.json`
- Modify: `scripts/hexbody/README.md` (o passo 9, os desenhos do app)

**Interfaces:**
- Consumes: `work/body/hexbody_rig.blend`, `work/body_f/hexbody_rig.blend`, os `mm_v2.npy` e os `seams_v2.npz` (os arquivos de referência de `work/`, com a cópia da #10 conferida antes).
- Produces:
  - `$B -b work/<corpo>/hexbody_rig.blend -P blender/app_art.py -- <male|female> work/<corpo>/mm_v2.npy work/<corpo>/seams_v2.npz <pasta de saída>`: para cada vista (frente e costas, com a câmera ortográfica do `blender/show_labels_v2.py:36`, `ortho_scale` 1,95, na pose A; o `body/render.sh` usa perspectiva e não serve), uma `base.png` com o corpo no acabamento flat (cinza chapado com uma sombra, as divisas das regiões desenhadas, fundo transparente) e, para cada uma das 36 regiões visível naquela vista, uma máscara em branco com alfa (os dois lados juntos), recortada pela caixa da região; `layout.json`: `{ "size": [largura, altura], "regions": { "<região>": [x, y, largura, altura] } }`, em pixels da base.
  - Tamanho: a base com 1.200 px de altura (o corpo ocupa até 400 pt de altura a 3x). PNG sem perdas, e a pasta inteira, os dois corpos juntos, com menos de 4 MB (o PR diz o tamanho).
- Run, de dentro de `scripts/hexbody`, com `$B` o Blender 5.1 do README de lá, um comando por corpo: `$B -b work/body/hexbody_rig.blend -P blender/app_art.py -- male work/body/mm_v2.npy work/body/seams_v2.npz ../../apple/Packages/HexBody/Sources/HexBody/Resources/Art/male` e `$B -b work/body_f/hexbody_rig.blend -P blender/app_art.py -- female work/body_f/mm_v2.npy work/body_f/seams_v2.npz ../../apple/Packages/HexBody/Sources/HexBody/Resources/Art/female`. Os desenhos são gerados nesta máquina, que tem `work/`; o PR diz o commit da cópia da #10 de que eles saíram.

- [ ] **Step 1: Write the failing test** em `test_app_art.py`, que lê só o que a Task grava no pacote: os dois corpos, as duas vistas, a `base.png` com 1.200 px de altura, cada região do `layout.json` com a máscara do mesmo tamanho da caixa, toda região das 36 em pelo menos uma vista, e nenhuma máscara fora da base.
- [ ] **Step 2: Run** `python3 -I scripts/hexbody/regions/run_tests.py`. Expected: falha (não há desenhos).
- [ ] **Step 3: Implement** `app_art.py` e gerar os desenhos dos dois corpos.
- [ ] **Step 4: Run** de novo. Expected: passa, e a parte `scripts` cresce 1. Conferir à mão os oito desenhos (frente e costas, base e todas as máscaras juntas) e pôr no PR uma prancha com eles.
- [ ] **Step 5: Commit** "Os desenhos do corpo para o app, a partir dos arquivos de referência".

---

### Task 14: O corpo no app

**Depende de:** Tasks 7, 10 e 13, e **#10**.

**Escolha recomendada, com a delegação do Lipe de 03/11/2026:** a escolha 7, o corpo na primeira abertura no lugar dos símbolos (escolha 3), e as cores abaixo.

**Files:**
- Create: `apple/Packages/HexBody/Sources/HexBody/BodyFigureView.swift`, `BodyArt.swift`, `Tests/HexBodyTests/BodyArtTests.swift`
- Modify: `apple/Packages/HexBody/Package.swift` (os recursos de `Art/`; o pacote passa a usar SwiftUI e a importar o HexDesign para a paleta)
- Modify: `apple/HexGym/Library/ExerciseDetailView.swift`, `apple/HexGym/Onboarding/OnboardingView.swift`, `apple/HexGym/Settings/SettingsView.swift` (a linha do corpo mostra o corpo pequeno)
- Modify: `apple/HexGym/Localizable.xcstrings`

**Interfaces:**
- Consumes: os desenhos da Task 13, `RegionCatalog`, `ExerciseRegions.weight(of:)`, `@Environment(\.hexPalette)`.
- Produces:

```swift
public struct BodyArt: Sendable {
  public static func bundled(_ figure: BodyFigure, view: BodyView) -> BodyArt   // lido uma vez e guardado
  public let size: CGSize
  public func frame(of region: BodyRegion) -> CGRect?                         // nil quando a região não aparece nesta vista
}
public enum BodyView: String, CaseIterable, Sendable { case front, back }
public struct BodyFigureView: View {
  // A base e, por cima, a máscara de cada região com peso, tingida pelo accent do tema: peso 1 na cor
  // cheia, 0,4 em 40% dela. Sem regiões, só a base (a primeira abertura e os ajustes).
  public init(figure: BodyFigure, view: BodyView, regions: ExerciseRegions?)
}
```

  - No detalhe, frente e costas lado a lado no cartão "Músculos", com a legenda "Principal" e "Também trabalha" (um quadrado na cor cheia e um em 40%) e a `MuscleList` embaixo, que fica; o figure vem do `body` do documento (`engine.settings().body`). Com Aumentar Contraste, o secundário passa a 60% e ganha a divisa mais escura, e o primário fica na cor de alto contraste do tema (o `accent` da paleta já muda). O VoiceOver lê o cartão inteiro com o texto da Task 10; o desenho é decorativo (`accessibilityHidden`).
  - Na primeira abertura, os dois corpos, sem regiões, no lugar dos símbolos; nos Ajustes, o corpo escolhido, pequeno, na linha "Corpo".
  - O crédito do MuscleMap já está nas Licenças (Task 6).

- [ ] **Step 1: Write the failing tests** em `BodyArtTests.swift`, 4 testes: os quatro desenhos carregam; o `frame(of:)` do peito médio existe na frente e não nas costas, e o da dorsal o contrário; uma view com o `0025` desenha (pelo `ImageRenderer`, no Mac) pixels na cor do accent dentro da caixa do peito e nenhum dentro da caixa da dorsal; com Aumentar Contraste (no teste, pelo `\.hexContrastPreview` do HexDesign, `HexEnvironment.swift:26,34`, porque o `colorSchemeContrast` não se define pelo `.environment`), o secundário sai com 60%.
- [ ] **Step 2: Run** o comando do pacote do HexBody. Expected: falham.
- [ ] **Step 3: Implement** o `BodyArt` e a `BodyFigureView`, e pôr o corpo nas três telas. As imagens são lidas uma vez (fora do `body`).
- [ ] **Step 4: Run** `node scripts/hexgym/check.mjs`. Expected: tudo passa, e a parte `packages` cresce 4.
- [ ] **Step 5: Prints e vídeo**: o detalhe do supino, do agachamento, da remada e da elevação lateral, no masculino e no feminino, no Ultravioleta e no Cobre, e com Aumentar Contraste; a primeira abertura no passo do corpo; o detalhe em AX5. Um vídeo trocando o corpo nos Ajustes e voltando ao detalhe.
- [ ] **Step 6: Commit** "O corpo muscular no detalhe do exercício, na primeira abertura e nos ajustes".

---

### Task 15: A versão 0.3.0

**Depende de:** todas as outras, da fase 2 e as que entrarem nela depois, e a versão 0.2.0 (#67). É a Task da versão: segue os passos da Task 16 da fase 0, na mesma ordem e com um comentário na issue por passo, retomando pelo último comentado, com estas trocas:

- **Os nomes:** versão `0.3.0`, branch `release/0.3.0`, worktree `.claude/worktrees/release-0.3.0`, milestone "Fase 2: Biblioteca e rotinas" (número 3), resumo `docs/status/m3-biblioteca-e-rotinas-status.md` (`--milestone 3`), PR "Versão 0.3.0: a biblioteca e as rotinas", tag `v0.3.0` com o título "HexGym 0.3.0", e o PR de volta "Versão 0.3.0 de volta para develop".
- **Passo 1:** o que sobrar aberto sai do épico da fase 2 e vai para o milestone "Fase 3: Treino no iPhone", com `orphan:ok`. A Task 13 e a 14 só saem se a #10 ainda esperar o founder; nesse caso, o PR da versão diz que o corpo vem na 0.3.1 e mostra as regiões em lista.
- **Passo 2:** na branch da release, um commit "Versão 0.3.0" com `MARKETING_VERSION = 0.3.0` nos quatro alvos. O número do build não muda no projeto: o `testflight.mjs` (#24) põe a data e a hora em UTC no passo 5.
- **Passo 3:** prints da primeira abertura, da biblioteca com busca e filtros, do detalhe com o corpo, do editor e da semana, e o vídeo do founder montando a própria rotina (o da Task 12, gravado de novo na versão).
- **Passo 5:** o build interno no TestFlight, com `node scripts/hexgym/testflight.mjs` (#24).
- **Passo 7:** o pedido de decisão vai nesta issue: 1. Aprovar a versão 0.3.0 (recomendada); 2. Pedir mudanças. É a parada de fim de fase da seção 9.1, que a delegação de 03/11 não tira do founder.
- **Passo 12:** `check-milestone-outcomes.sh --milestone 3`.
- **Passo 13:** fecha o milestone 3, e o filtro da visão "Fase atual" vira `milestone:"Fase 3: Treino no iPhone"`. A sessão da fase 2 põe o resultado da fase na página da fase 2.
