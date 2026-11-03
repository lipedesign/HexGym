# Fase 0 do HexGym (Fundação): plano de implementação

> **Quem executa:** o orquestrador do relentless, como ele vem (nota `docs/decisions/notes/2026-11-03-um-orquestrador-so.md`), a partir do fim da Task 1, que liga o relentless no HexGym. Cada Task é uma issue do milestone "Fase 0: Fundação", sub-issue do épico da fase, e um PR para `develop`: uma worktree e uma branch por Task, o critério de aceite da issue é a Task deste plano (a linha `Plano:` da issue), e a revisão isolada do relentless é a revisão do PR. Os títulos ficam "Task N" porque é assim que a linha `Plano:` das issues aponta para eles. Os passos usam caixas de seleção (`- [ ]`).

**Objetivo:** deixar o fork pronto para o trabalho feito por agentes e o HexGym abrindo no simulador e no iPhone do founder, ainda sem telas, com o motor do openGym rodando no JavaScriptCore, o documento de dados no App Group e um build interno no TestFlight.

**Arquitetura:** o motor é o código de `frontend/src/lib`, juntado num script só (`HexEngine`) pelo Vite que o frontend já tem e rodado num único `JSContext` dentro de um `actor` Swift (pacote `HexEngine`). O documento de dados é o mesmo `gym_state_v1` do openGym, guardado como JSON no App Group por outro `actor` (pacote `HexStore`, que não está na lista da seção 8.7: decisão do tech lead, para a gravação ter testes próprios, sem o motor). O app SwiftUI liga os dois e mostra o estado numa tela provisória. O trabalho é tocado pelo orquestrador do relentless, como ele vem; o HexGym só acrescenta as checagens (`scripts/hexgym/check.mjs`, Node sem dependências), que o relentless e a CI chamam.

**Tecnologias:** Node 22, com o Vite e o Vitest do frontend; Swift (`swift-tools-version: 6.2`), SwiftUI, JavaScriptCore e Swift Testing; Xcode 27; `gh` e GitHub Actions.

**Especificação:** `docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md`, seções 5, 8.2, 8.3, 8.7, 8.10, 8.13, 9, 9.1, 10 e 11.

## Restrições globais (Global Constraints)

Valem para toda Task. Os valores vêm da especificação e do levantamento de 31/10/2026.

- **Plataforma:** iOS 26 e watchOS 26 como mínimo (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `WATCHOS_DEPLOYMENT_TARGET = 26.0`). Xcode 27 via `DEVELOPER_DIR`, porque o `xcode-select` desta máquina aponta para as Command Line Tools: `/Applications/Xcode.app` (o 27.2 estável, quando o founder instalar na Task 12) ou, até lá, `/Applications/Xcode-beta.app` (27.0 beta 6). Da Task 7 em diante, todo `swift`, `xcodebuild`, `xcrun` e `codesign` roda com `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs)`.
- **Formato do projeto:** `objectVersion = 77` e `preferredProjectObjectVersion = 77` (o formato "Xcode 16.0", que o Xcode 26 e o 27 abrem), sempre `project.pbxproj`, nunca o `.xcproj` em JSON do Xcode 27.2. Pacotes com `swift-tools-version: 6.2`. Nenhuma API só do iOS 27 ou do watchOS 27.
- **O Watch não roda JavaScript:** nada de JavaScriptCore nos alvos do Watch.
- **Poucas dependências:** nenhum pacote Swift de terceiros e nenhuma dependência npm nova; o script do motor usa o Vite que o frontend já tem.
- **Compatibilidade com o openGym:** o mesmo documento de dados (as chaves de `gym_state_v1`), sem perder chave nenhuma ao ler e gravar.
- **Privacidade:** sem telemetria, sem conta de terceiros, e nenhuma chamada de rede no app nesta fase.
- **Texto para o usuário:** simples e humano, sem travessão; português do Brasil e inglês.
- **Mídias de exercício:** nenhuma entra no app nesta fase. Nunca abrir, converter ou passar por ferramenta de IA as fotos e animações da Gym visual, e nada novo em `catalogue/media/`.
- **Prints e vídeo dos PRs:** ficam em `docs/hexgym/prints/<issue>/`, no commit do próprio PR, e o corpo do PR os mostra por `https://github.com/lipedesign/HexGym/blob/<sha>/docs/hexgym/prints/<issue>/<arquivo>?raw=true`. O vídeo é do simulador (`xcrun simctl io <udid> recordVideo --codec h264`), com até 15 s e menos de 5 MB. Nenhum print ou vídeo mostra as imagens ou animações da Gym visual.
- **Repositório:** nunca mexer no upstream (`DuarteSantos8/openGym`) nem no espelho do GitLab, e nenhum `gh` aponta para ele: para ler o upstream, o `git` com o remoto `upstream`, que não tem push. Todo `gh` mira o fork: `-R lipedesign/HexGym`, `repos/lipedesign/HexGym/` no `gh api` e, no `gh api graphql`, só os IDs das visões do Project 6 (o `updateProjectV2View`): "Fase atual" é `PVTV_lAHOAYVuVc4Bpo0bzgMV7KM`, e "Pede você", `PVTV_lAHOAYVuVc4Bpo0bzgMV7Lo`. O único repositório novo é o `lipedesign/hexgym-corpo` da Task 15, com `gh repo create`, quando o `/decide 10` escolhe essa opção. Nada em `data/`.
- **IDs:** `app.hexgym`, `app.hexgym.widgets`, `app.hexgym.watchkitapp`, `app.hexgym.watchkitapp.widgets`; App Group `group.app.hexgym`; esquema de URL `hexgym://`; time `MPAGLMK4Q2`.
- **Alvos:** `HexGym`, `HexGymWidgets`, `HexGymWatch` e `HexGymWatchWidgets`, com pastas sincronizadas e sem gerador de projeto.
- **Motor:** um `JSContext` só, dentro de um `actor`, nunca na thread principal; o script gerado é versionado, e o `--check` falha quando ele está velho.
- **Mudanças no código do openGym:** pequenas, com teste, cada uma num commit que possa ser proposto ao openGym; `cd frontend && npm test` e as checagens de locale (`node scripts/check-locales.mjs && node scripts/check-source-strings.mjs --strict`, em `frontend/`) continuam verdes.
- **Git Flow:** `feature/<número>-<nome>` a partir de `develop`; PR para `develop` com `Closes #<número>`; squash nas features; merge normal em release, sync e hotfix.
- **Estado das issues:** só o orquestrador troca a etiqueta `state:*`, e sempre pelo `set-state.sh` do relentless, inclusive o `state:todo` de uma issue aberta sem nenhuma (criada fora dos formulários). `human:pending` só entra pelo `request-decision.sh` e só sai pelo `/decide` do founder.
- **Arquivos em `.claude/`:** o `.gitignore` do openGym ignora a pasta inteira; arquivo novo ali entra com `git add -f`.
- **Commits:** terminam com a linha `Co-Authored-By:` do agente que escreveu.

## Foco da revisão (Review Focus)

O que a especificação implica, nenhuma Task testaria sozinha e mais pode morder quem usa o app. Cada linha ganhou um teste na Task dona do código.

1. **Documento truncado, corrompido ou que não abre naquela hora** (o app morreu no meio da gravação, disco cheio, permissão, o aparelho ainda bloqueado depois de ligar): com o documento ruim, o app abre a cópia anterior, guarda o arquivo ruim de lado e avisa no log; com as duas cópias ruins, ou com um arquivo que existe e não abre, mostra o erro e não grava nada. Nunca começa do zero em silêncio. Testes nas Tasks 8 e 10.
2. **Documento com chaves que o HexGym não conhece** (de um openGym mais novo ou de outra versão do HexGym), **ou com um texto que só o JavaScript lê** (um emoji cortado ao meio, que o `JSON.stringify` grava como `\ud83d`): restaurar e gravar de volta preserva todas as chaves, os valores e os bytes. Testes nas Tasks 7 e 8.
3. **Erro dentro do motor** (exceção no JS, JSON inválido, função que não existe): vira um erro Swift com a mensagem do JS, e a chamada seguinte funciona no mesmo contexto. Teste na Task 7.
4. **Histórico grande** (anos de treino): carregar o motor e marcar uma série ficam dentro das metas da seção 8.13, medidos sem JIT. Teste na Task 6.
5. **Fuso horário do aparelho** diferente do da máquina que gravou os casos, com e sem horário de verão: o JavaScriptCore dá o mesmo resultado que o Node no mesmo fuso, inclusive num treino que cruza a meia-noite. Teste na Task 7.

## Mapa dos arquivos

```
scripts/hexgym/                  ferramentas do HexGym (Node 22, sem dependências)
  check.mjs                      as checagens por parte; a CI chama o mesmo script
  xcode.mjs                      qual Xcode usar e qual simulador
  engine-load.mjs                teste de carga do motor no jsc, sem JIT
  engine-tests.mjs               quais testes do lib rodam contra o script
  engine-cases.mjs               os casos de contrato do motor
  record-engine-cases.mjs        grava os casos no Node, um arquivo por fuso (--check)
  testflight.mjs                 arquivo, exportação e envio ao TestFlight
scripts/build-hexgym-engine.mjs  junta o motor num script só (--check)
frontend/src/lib/                as mudanças pequenas no openGym (Task 4)
frontend/vitest.hexengine.config.js   roda os testes do lib contra o script gerado
apple/
  .gitignore
  .gitattributes                 marca o script e os casos como gerados
  HexGym.xcodeproj/              os quatro alvos e os testes, formato 77
  HexGym/ HexGymWidgets/ HexGymWatch/ HexGymWatchWidgets/ HexGymTests/ Shared/
  Config/                        Info.plist parciais e entitlements, fora das pastas sincronizadas
  ExportOptions.plist
  Packages/HexEngine/            o motor no JavaScriptCore
    JS/                          o que o script leva além do lib, com os testes em Node
    Sources/HexEngine/           o ator e, em Resources/, o script gerado e o host.js
    Tests/HexEngineTests/        os testes Swift e, em Cases/, os casos gravados
  Packages/HexStore/             o documento de dados no App Group
.github/workflows/hexgym.yml
.github/README.md, .github/CONTRIBUTING.md, .github/SECURITY.md
docs/hexgym/prints/              os prints e os vídeos dos PRs, uma pasta por issue
docs/superpowers/.gitignore      deixa o git ver os planos (o openGym ignora docs/superpowers/plans/); entra com este plano
```

## Ordem e dependências

| Task | Issue | O que entrega | Depende de | Quem faz |
|---|---|---|---|---|
| 1 | #15 | O relentless ligado no HexGym | | tech lead |
| 2 | #3 | Workflows herdados desligados e `tests-ok` obrigatório | | orquestrador, depois do clique do founder na aba Actions e do `/decide 3` |
| 3 | #11 | Branches e etiquetas herdadas | 1 | orquestrador, com o `/decide 11` do founder para apagar as branches |
| 4 | #16 | O motor sem React | 1 | orquestrador |
| 5 | #17 | O script do motor | 4 | orquestrador |
| 6 | #18 | Os testes do lib contra o script e a carga no jsc | 5 | orquestrador |
| 7 | #19 | O pacote HexEngine | 5 | orquestrador |
| 8 | #20 | O pacote HexStore | 7 | orquestrador |
| 9 | #21 | O projeto Xcode com os quatro alvos | 7, 8 | orquestrador |
| 10 | #22 | O app abre com o motor e os dados | 9 | orquestrador |
| 11 | #9 | A CI do HexGym | 2, 6, 10 | orquestrador |
| 12 | #23 | Xcode 27.2, os IDs e o app no App Store Connect | 9 | founder |
| 13 | #24 | TestFlight a partir desta máquina | 10, 12 | orquestrador, com o ok do founder no primeiro envio |
| 14 | #8 | README, CONTRIBUTING e SECURITY do fork | 10 | orquestrador, com o texto aprovado pelo founder |
| 15 | #10 | Cópia dos arquivos do corpo e procedência da referência | 1 | orquestrador, depois das respostas do founder |
| 16 | #25 | Versão 0.1.0 | todas as outras, menos a 15 | orquestrador, com a aprovação do founder |

Cada issue leva duas linhas que o orquestrador lê: `Depende de: #a, #b` (ou `nenhuma`) e `Plano: docs/superpowers/plans/2026-10-31-fase-0-fundacao.md, Task N`. O tech lead criou as issues novas junto com o PR deste plano, já com as duas linhas, e acrescentou as duas no fim das Notas da #3, da #8, da #9, da #10 e da #11. A #14 é este plano e fecha com o PR dele; a #3 fecha com a Task 2, depois do clique do founder. Na Task 1, cada issue da fase ganha uma etiqueta `state:*` e vira sub-issue do épico da fase. O orquestrador do relentless lê as duas linhas como diz a nota de 03/11: a `Depende de:` faz o papel da `Blocked by:` dele, e a Task da linha `Plano:` é o critério de aceite.

Ficam fora desta fase, de propósito: o WatchCore em `apple/` (fase 4), o pacote `HexDesign` (fase 1), o `session-controller.js` (fase 3), as traduções do openGym em JSON (fase 2), o HealthKit, a sincronização com servidor e a medição num iPhone real com histórico grande (seção 8.13), que espera as telas que fazem esses cálculos (fases 3 e 5); nesta fase, a medida é a do `jsc` sem JIT, na Task 6.

Ficam também para a fase 5, cada um com uma issue no milestone "Fase 5: O resto do openGym" (#26 e #27), o que o JavaScriptCore não tem e só a importação e a exportação usam: `URL` (sem ele, o `cleanUrl` de `media-refs.js` devolve `null` e o plano compartilhado perde os links dos exercícios personalizados), `fetch` (a importação do Hevy), `TextEncoder`, `TextDecoder` e `Blob` (o zip e o FIT), e a leitura das datas do Apple Health (o JavaScriptCore não entende `new Date('2024-01-15 07:30:00 +0100')`, usado em `import-csv.js:866`). Nenhuma tela da fase 0 chega nesses caminhos, e o teste `webGlobalsTheEngineDoesNotHaveYet` da Task 7 prende o que falta: quem trouxer um deles muda o teste junto.

E duas coisas que a revisão do plano achou e ficam para depois, de propósito. A nota do dia é cortada por unidade de UTF-16 (`day-notes.js:33`), o que parte um emoji que cai na posição 500: o HexStore aceita esse texto (Task 8), e cortar por caractere é uma proposta ao openGym, para quando o founder falar com o Duarte. E o `save` do HexStore lê o `state.json` inteiro a cada gravação para decidir a cópia anterior: na fase 0 isso acontece uma vez por início, e a fase 3, que grava a cada série, mede antes de mudar.

---

### Task 1: O relentless ligado no HexGym

**Issue:** #15. **Quem faz:** o tech lead, à mão, pelos passos do orquestrador do relentless. É esta Task que deixa o HexGym pronto para ele, então ela não espera uma onda. As decisões por trás dela estão em `docs/decisions/notes/2026-11-03-um-orquestrador-so.md`.

**Files:**
- Create: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs`
- Modify: `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/1-tarefa.yml`, `.github/ISSUE_TEMPLATE/2-bug.yml`, `.relentless/config.json`, `docs/decisions/notes/2026-11-01-relentless-no-git-flow.md`
- Fora do git: o `.claude/settings.json` do checkout e o de cada worktree que já existir, com o marketplace do relentless fixado na tag da versão (passo 1)

**Interfaces:**
- Consumes: o relentless na última versão publicada (a tag `v1.4.11` em 03/11/2026), ativado só neste projeto. `S` é a pasta dos scripts dele: `S="$(claude plugin list --json | jq -r '.[] | select(.id == "relentless@relentless") | .installPath')/core/scripts"`. Os scripts desta Task: `set-state.sh`, `worktree-create.sh`, `wait-ci.sh`, `fill-qa-section.sh`, `run-isolated-review.sh`, `merge-if-ready.sh`, `request-decision.sh`, `comment-agent.sh`, `create-epic.sh`, `add-sub-issue.sh`, `check-milestone-outcomes.sh` e `worktree-cleanup.sh`, mais o agente `relentless:qa`.
- Produces:
  - `check.mjs` exporta `PARTS` (objeto `parte → [{ name, cmd, args, cwd?, env? }]`, na ordem em que rodam), `planChecks(parts: string[]) → check[]`, `runChecks(checks, run) → { ok: boolean, failed?: string }` e `runParts(parts, run) → { ok: boolean, failed?: string, part?: string, tests?: number }`. Uma parte só passa se as checagens dela passam e se, somadas, rodaram pelo menos um teste (issue #44): o `node --test` é contado sozinho, pelo `tap` que o `spawnCheck` grava num arquivo, e qualquer outro comando conta zero até ensinar o `spawnCheck` a contar os testes dele. CLI: `node scripts/hexgym/check.mjs [parte ...] [--list]`, e sem parte roda todas. As Tasks seguintes acrescentam partes ao `PARTS`. É o `checks.test` do `.relentless/config.json`, e o QA e a CI chamam o mesmo comando.
  - O modelo de PR com a seção `## QA / dogfood result`, que o `fill-qa-section.sh` preenche.
  - A fase 0 pronta para o orquestrador do relentless: o milestone com a seção Outcome, o épico, cada issue da fase como sub-issue dele e com uma etiqueta `state:*`, e as esperas da #3 e da #10 como pedidos de decisão.

- [ ] **Step 1: Pin the relentless to its latest published version, only in this project**

No checkout principal (`/Users/lipe/Developer/MyGym`). A `main` do relentless já tem mudanças sem versão (o "corte mínimo"), com o número da última versão no `plugin.json`. A atualização copia o que está no clone do marketplace, que segue a branch padrão quando a declaração não tem `ref`, e o `claude plugin update` não troca uma cópia que já tem o mesmo número de versão: a primeira cópia da 1.4.11 é a que fica. Por isso, o marketplace é fixado na tag da última versão publicada (`v1.4.11`, commit `ee722b8`, em 03/11/2026; as tags saem de `git ls-remote --tags https://github.com/marcelusfernandes/relentless`) antes de qualquer atualização:

1. No `.claude/settings.json` do checkout, a fonte do relentless em `extraKnownMarketplaces` ganha `"ref": "v1.4.11"`, ao lado de `"source": "github"` e `"repo"`. O mesmo vale para o `.claude/settings.json` de cada worktree que já existir (`git worktree list`), porque o `worktree-create.sh` só copia o arquivo (pelo `.worktreeinclude`) quando a worktree nasce.
2. `claude plugin marketplace list --json` mostra o relentless com `"ref": "v1.4.11"`. Se não mostrar, uma sessão nova do Claude Code e a mesma conferência.
3. `claude plugin marketplace update relentless`, e o `git -C ~/.claude/plugins/marketplaces/relentless rev-parse HEAD` dá o commit da tag. Se não der, a Task para aqui, sem o `plugin update`.
4. `claude plugin update relentless@relentless --scope project`, da raiz do checkout, e uma sessão nova do Claude Code, porque os ganchos e os agentes da versão nova valem a partir dela.

A correção local de `.claude/relentless-compat/` não é reaplicada: a 1.4.10 trouxe as mesmas correções (PRs #23 e #24 do relentless). Se a última versão publicada já for o corte mínimo (o `.relentless/config.json` dele ganha `base`, `merge_methods` e `layers`), a Task para antes do item 1: o tech lead relê o `agents/orchestrator.md` dela e acerta esta Task e a nota `2026-11-03-um-orquestrador-so.md` num PR.

Run: `claude plugin list --json | jq '.[] | select(.id == "relentless@relentless") | {version, scope, projectPath}'`, `jq -r '.plugins["relentless@relentless"][] | select(.projectPath == "/Users/lipe/Developer/MyGym") | .gitCommitSha' ~/.claude/plugins/installed_plugins.json` e `grep -c 'ENVIRON\["QA"\]' "$S/fill-qa-section.sh"`
Expected: `"version": "1.4.11"`, `"scope": "project"` e `"projectPath": "/Users/lipe/Developer/MyGym"`; `ee722b806536f9b031c28e1591a9bdecae7b1dbe`, o commit da tag; e `1`.

- [ ] **Step 2: Take the issue and its worktree**

`"$S/set-state.sh" --repo lipedesign/HexGym --issue 15 --state in-progress` e `"$S/worktree-create.sh" --repo lipedesign/HexGym --workdir /Users/lipe/Developer/MyGym --issue 15 --slug relentless --type feature --base develop --path /Users/lipe/Developer/MyGym/.claude/worktrees/15-relentless`. Os passos 3 a 10 rodam nessa worktree, até o merge; os 11 a 13, na raiz do checkout, depois do `git pull --ff-only`.

Run: `gh issue view 15 -R lipedesign/HexGym --json labels --jq '[.labels[].name]'` e `git ls-remote --heads origin feature/15-relentless`
Expected: `state:in-progress` entre as etiquetas, e a branch no remoto.

- [ ] **Step 3: Write the failing tests for `check.mjs`**

Em `scripts/hexgym/check.test.mjs`, com `node:test` e `node:assert/strict`:

```js
test('the scripts part runs the node tests of scripts/hexgym', () => {
  assert.deepEqual(planChecks(['scripts']).map(c => [c.cmd, ...c.args]), [['node', '--test', 'scripts/hexgym/*.test.mjs']])
})
test('no part means every part, in PARTS order', () => {
  assert.deepEqual(planChecks([]), Object.values(PARTS).flat())
})
test('an unknown part fails with the list of parts', () => {
  assert.throws(() => planChecks(['x']), /parte desconhecida: x \(partes: scripts\)/)
})
test('runChecks stops at the first failure', async () => {
  const ran = []
  const r = await runChecks([{ name: 'a' }, { name: 'b' }, { name: 'c' }], async c => { ran.push(c.name); return c.name === 'b' ? 1 : 0 })
  assert.deepEqual(r, { ok: false, failed: 'b' }); assert.deepEqual(ran, ['a', 'b'])
})
```

O teste "unknown part" lista as partes que existirem no `PARTS`; as Tasks que acrescentam partes atualizam a mensagem esperada.

- [ ] **Step 4: Run the tests to verify they fail**

Run: `node --test scripts/hexgym/check.test.mjs`
Expected: FAIL, `Cannot find module` para `./check.mjs`.

- [ ] **Step 5: Implement `scripts/hexgym/check.mjs`**

`PARTS = { scripts: [{ name: 'testes dos scripts', cmd: 'node', args: ['--test', 'scripts/hexgym/*.test.mjs'] }] }`. O `PARTS` fica escrito sempre nesta ordem, e cada Task põe a sua parte no lugar dela: `scripts`, `engine`, `load`, `packages`, `app`. O `run` padrão usa `spawn` com `stdio: 'inherit'`, `cwd` relativo à raiz do repositório e `env` somado ao `process.env`. O `args` e o `env` podem ser um valor ou uma função que devolve o valor; a função só é chamada quando aquela checagem vai rodar, e o `--list` mostra `(calculado ao rodar)` no lugar, para uma parte que precisa do Xcode não quebrar as outras nem o `--list` numa máquina sem ele. A CLI imprime `▶ <nome>` antes de cada checagem e, no fim, `ok` ou `falhou: <nome>`, saindo com 1 na falha. Uma parte que, somadas as checagens, não rodou nenhum teste também falha (issue #44): o stderr diz qual parte, e o fim é `falhou: <parte> (nenhum teste)`. `--list` imprime os comandos e não roda nada.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node scripts/hexgym/check.mjs scripts`
Expected: PASS nos quatro testes e `ok` no fim.

- [ ] **Step 7: Adjust the PR model, the issue forms and the relentless config**

- `.github/pull_request_template.md`: todos os títulos passam a `##`, e entra a seção `## QA / dogfood result` entre `## Como foi testado` e `## Para o founder ver`, com o comentário "O orquestrador preenche com o `fill-qa-section.sh` do relentless.". O último item do checklist passa a ser "Revisão isolada aprovada (`review:approved`) no último commit do PR". O `fill-qa-section.sh` troca a seção até o próximo `## `: com um título `###` depois dela, o resto do corpo iria junto.
- `.github/ISSUE_TEMPLATE/1-tarefa.yml` ganha `labels: ["state:todo"]`, e o `2-bug.yml` passa a `labels: ["bug", "state:todo"]`.
- `.relentless/config.json`: `checks.test` passa a `node scripts/hexgym/check.mjs`, `checks.install` a `npm ci && npm ci --prefix frontend`, e `merge.allow_issue_override` a `false` (nota de 03/11).

Run: `ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' .github/ISSUE_TEMPLATE/1-tarefa.yml .github/ISSUE_TEMPLATE/2-bug.yml && jq -e '.checks.test == "node scripts/hexgym/check.mjs" and .merge.allow_issue_override == false' .relentless/config.json && grep -c '^## ' .github/pull_request_template.md`
Expected: `true` e `5` (os cinco títulos do modelo de PR).

- [ ] **Step 8: Bring the Git Flow note to the pinned version**

Em `docs/decisions/notes/2026-11-01-relentless-no-git-flow.md`, com a versão do passo 1:
- no Contexto, a versão passa a ser a do passo 1, e sai a linha do `wait-ci.sh`, que a versão nova trocou pelos checks do commit do PR;
- no "Squash nas features", a frase do `wait-ci.sh` que "aceita a última execução verde de qualquer workflow" dá lugar aos portões da nota `2026-11-03-um-orquestrador-so.md`;
- o "Sem `merge:auto` por enquanto" passa a dizer que o `merge.allow_issue_override` fica `false` e a etiqueta não vale, porque o merge automático do relentless é `gh pr merge --merge`;
- sai a linha da correção do macOS (`.claude/relentless-compat/`), e entra uma dizendo que o marketplace fica fixado na tag da versão e que trocar de versão é fixar a tag nova, reler o `agents/orchestrator.md` e acertar as notas.

Run: `grep -c 'relentless-compat\|qualquer workflow\|1\.4\.8' docs/decisions/notes/2026-11-01-relentless-no-git-flow.md`
Expected: `0`.

- [ ] **Step 9: Commit**

```bash
git add scripts/hexgym .github/pull_request_template.md .github/ISSUE_TEMPLATE/1-tarefa.yml .github/ISSUE_TEMPLATE/2-bug.yml .relentless/config.json docs/decisions/notes/2026-11-01-relentless-no-git-flow.md
git commit -m "O relentless ligado no HexGym: as checagens, os modelos e a configuração"
```

- [ ] **Step 10: Take the pull request through the relentless steps**

O tech lead faz o que o `agents/orchestrator.md` dá ao implementador, ao QA e ao orquestrador, com as regras da nota de 03/11:

1. `gh pr create -R lipedesign/HexGym --base develop --title "O relentless ligado no HexGym"`, com o corpo do modelo de PR, `Closes #15` e `ADRs: none (configuração do relentless; a decisão está em docs/decisions/notes/2026-11-03-um-orquestrador-so.md)`. Depois, o `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr>` uma vez: até a #3, ele sai com 3, e valem os outros portões.
2. O QA com o `relentless:qa`, na worktree, com a issue e esta Task, e nunca o raciocínio de quem implementou: `node scripts/hexgym/check.mjs`, o `--list` e o `Run` do passo 7. A saída vai para `.relentless/review/<pr>/qa.md`, sem nenhuma linha começando com `## `, e entra no PR com `"$S/fill-qa-section.sh" --repo lipedesign/HexGym --pr <pr> --body-file .relentless/review/<pr>/qa.md`. Então `"$S/set-state.sh" --repo lipedesign/HexGym --issue 15 --state review`.
3. A revisão isolada, de dentro da worktree e em primeiro plano: `"$S/run-isolated-review.sh" --repo lipedesign/HexGym --pr <pr> --issue 15 --workdir /Users/lipe/Developer/MyGym/.claude/worktrees/15-relentless`. Com `changes_requested`: a linha do `docs/decisions/log.jsonl` que o `orchestrator.md` pede, as correções na mesma worktree, um commit por rodada, e os itens 2 e 3 de novo.
4. O merge: o `"$S/merge-if-ready.sh" --repo lipedesign/HexGym --pr <pr> --issue 15 --dry-run` sai com 0, o `gh pr view <pr> -R lipedesign/HexGym --json state,mergeable` dá `OPEN` e `MERGEABLE`, e então `gh pr merge <pr> -R lipedesign/HexGym --squash --match-head-commit <sha>`.

Expected: o PR entra em `develop` em squash, com a seção de QA preenchida no corpo e o comentário do veredito `review:approved` no último commit dele.

- [ ] **Step 11: After the merge, turn the waits into decision requests**

Na raiz do checkout, depois do `git pull --ff-only`. Para a #3 e a #10, um pedido em português no formato do `core/templates/decision-request.md` do relentless ("Pergunta", "Contexto", "Opções" com `### 1. …`, "Recomendação", com os dois marcadores do modelo), com o que cada opção muda, o que afeta, os riscos e o custo de voltar atrás, como pede o `orchestrator.md`. Ele vai salvo em `.relentless/review/issue-<n>/decisao.md` e sai com `"$S/request-decision.sh" --repo lipedesign/HexGym --issue <n> --body-file .relentless/review/issue-<n>/decisao.md`:

- **#3:** o clique em "I understand my workflows, go ahead and enable them", na aba Actions do fork, e a mudança na proteção das duas branches para exigir o `tests-ok` agora (os passos 4 e 5 da Task 2) e o `hexgym-ok` quando a CI do HexGym existir (o passo 4 da Task 11), uma parada do relentless. O contexto avisa que o passo 1 da Task 2 abre um PR de teste em rascunho, que fecha sem merge, e que a branch dele (`ci/3-eventos`) e a do passo 5 da Task 11 (`teste/hexgym-ok-vermelho`) saem no fim de cada Task: apagar branch é parada do relentless, e as duas opções autorizam essas duas. 1. Cliquei, e pode mudar a proteção (recomendada); 2. Cliquei, mas a proteção fica como está (o orquestrador confere os dois checks antes de cada merge, mas o GitHub não barra um merge com check vermelho).
- **#10:** onde guardar a cópia de `scripts/hexbody/work/` (281 MB). 1. Um repositório privado, `lipedesign/hexgym-corpo` (recomendada); 2. O iCloud Drive; 3. O Google Drive. A procedência da imagem `ref/referencia-corpo.jpg` não é uma opção: vai na nota do `/decide` (`/decide 10 <opção> <como a imagem foi feita>`).

A #23 (Task 12) não ganha pedido agora: o item 2 da lista do founder abre o projeto Xcode, que só existe depois da Task 9 (#21). O pedido dela sai quando ela ficar pronta, como primeiro passo da Task 12; agora, só um comentário na #23 (`comment-agent.sh`) dizendo que os itens 1, 3, 4 e 5 já podem ser feitos.

Depois, `gh label delete "decisão do founder" -R lipedesign/HexGym --yes`, `gh label delete bloqueado -R lipedesign/HexGym --yes` e o filtro novo da visão "Pede você":

```bash
gh api graphql -f query='mutation($v:ID!,$f:String!){updateProjectV2View(input:{viewId:$v,filter:$f}){projectV2View{name filter}}}' \
  -f v=PVTV_lAHOAYVuVc4Bpo0bzgMV7Lo -f f='label:"human:pending","state:blocked" is:open'
```

Expected: a #3 e a #10 com `human:pending` e `state:blocked`, atribuídas a `lipedesign`; nenhuma das duas etiquetas velhas em `gh label list -R lipedesign/HexGym`; e a visão "Pede você" com o filtro novo.

- [ ] **Step 12: After the merge, give the phase its outcome, its epic and a state on every issue**

A seção Outcome no milestone, mantendo o texto dele:

```bash
d="$(gh api repos/lipedesign/HexGym/milestones/1 --jq .description)"
gh api -X PATCH repos/lipedesign/HexGym/milestones/1 -f description="$(printf '## Outcome\n\n%s' "$d")"
```

O épico: `"$S/create-epic.sh" --repo lipedesign/HexGym --title "Fase 0: Fundação" --milestone 1 --outcome "<a linha Entrega do milestone>" --exit-criterion "<a linha O founder vê>" --plan docs/superpowers/plans/2026-10-31-fase-0-fundacao.md` e `"$S/set-state.sh" --repo lipedesign/HexGym --issue <épico> --state in-progress`. Cada issue do milestone, aberta ou fechada, vira sub-issue dele: `"$S/add-sub-issue.sh" --repo lipedesign/HexGym --parent <épico> --child <n>` para cada número de `gh issue list -R lipedesign/HexGym --milestone "Fase 0: Fundação" --state all --limit 100 --json number,labels --jq '.[] | select(.labels | map(.name) | index("epic") | not) | .number'`. E cada issue aberta do milestone sem nenhuma `state:*` ganha `state:todo`, com `"$S/set-state.sh" --repo lipedesign/HexGym --issue <n> --state todo` para cada número de `gh issue list -R lipedesign/HexGym --milestone "Fase 0: Fundação" --state open --limit 100 --json number,labels --jq '.[] | select([.labels[].name | select(startswith("state:"))] | length == 0) | .number'`.

Run: `"$S/check-milestone-outcomes.sh" --repo lipedesign/HexGym --milestone 1 --allow-pending` e `gh issue list -R lipedesign/HexGym --milestone "Fase 0: Fundação" --state open --limit 100 --json number,labels --jq '[.[] | select([.labels[].name | select(startswith("state:"))] | length != 1) | .number]'`
Expected: o primeiro sai com 0, e o segundo dá `[]`.

- [ ] **Step 13: After the merge, close the Task against the real board**

`"$S/set-state.sh" --repo lipedesign/HexGym --issue 15 --state done`, e então:

Run: `gh issue list -R lipedesign/HexGym --milestone "Fase 0: Fundação" --state open --limit 100 --json number,labels --jq '.[] | "#\(.number) \([.labels[].name | select(startswith("state:") or startswith("human:") or . == "epic")] | join(" "))"'`
Expected: a #3 e a #10 com `human:pending` e `state:blocked`; o épico com `epic` e `state:in-progress`; as outras com `state:todo`, menos a que já tiver um PR aberto, que segue com o estado dela. Pelas linhas `Depende de:`, as prontas para a primeira onda são a #11 e a #16; a #23 espera a #21.

Depois: um comentário na #15 com a saída dos passos 11 a 13 (`comment-agent.sh`); `"$S/worktree-cleanup.sh" --path /Users/lipe/Developer/MyGym/.claude/worktrees/15-relentless --repo lipedesign/HexGym` e `git branch -D feature/15-relentless`; e, na conversa, os dois pedidos para o Lipe, cada um com o comando `/decide`, e o aviso da #23.

---

### Task 2: Os workflows herdados e o check obrigatório

**Issue:** #3. **Quem faz:** o orquestrador, depois do clique do founder e do `/decide 3` (passo 1). Sem código: o único PR é o de teste do passo 1, que fecha sem merge.

- [ ] **Step 1: Confirm the fork's Actions run on events**

O `"enabled":true` de `gh api repos/lipedesign/HexGym/actions/permissions` e os workflows como `active` não provam que eles rodam. Os nove apareceram às 23:48:32Z de 31/10, dois segundos depois do merge do #7 em `develop`: foi o merge que registrou os arquivos. Em 01/11/2026, a abertura do PR #28, um commit novo nele e um push numa branch `ci-*` não dispararam nada, e o `workflow_dispatch` do `test.yml` rodou e passou. Num fork, o GitHub só roda por evento depois que o dono clica em "I understand my workflows, go ahead and enable them", na aba Actions. O clique é do founder: a #3 fica com o pedido de decisão da Task 1 (`human:pending`) até ele responder `/decide 3 <opção>`. As duas opções autorizam o PR de teste deste passo e apagar as branches de teste dela e da Task 11 (apagar branch é uma parada do relentless); só a opção 1 autoriza os passos 4 e 5 desta Task e o passo 4 da Task 11, que mudam a proteção das branches (uma parada do relentless). Um pedido por falha deste passo repete essas duas opções, com o clique feito, e a proteção segue a última resposta a um pedido com elas (passo 4).

O teste usa um PR em rascunho com um commit vazio, criado sem mexer no checkout: `c=$(git commit-tree 'origin/develop^{tree}' -p origin/develop -m "Teste dos eventos da CI (#3)" -m "<a linha Co-Authored-By>")`, `git push origin "$c:refs/heads/ci/3-eventos"` e `gh pr create -R lipedesign/HexGym --draft --base develop --head ci/3-eventos --title "Teste dos eventos da CI" --body "Só para a #3. Fecha sem merge."`. Na volta, o que já existe fica: com o PR aberto (`gh pr list -R lipedesign/HexGym --head ci/3-eventos --state open --json number --jq length` dá `1`), seguir com ele, e, se ele ainda não tem a execução do `Run` abaixo, fechar e reabrir o PR (`gh pr close <pr> -R lipedesign/HexGym` e `gh pr reopen <pr> -R lipedesign/HexGym`), porque nada mais dispara um evento num PR que já existe; com a branch e sem o PR aberto (`git ls-remote --exit-code origin refs/heads/ci/3-eventos` sai com 0), só o `gh pr create`. O evento leva alguns segundos: depois do `gh pr create` ou do `gh pr reopen`, o `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr> --timeout-sec 120` espera por ele antes do `Run` (saindo com 3 e sem o `tests-ok` em `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket`, nada rodou).

Run: `gh run list -R lipedesign/HexGym --workflow test.yml --branch ci/3-eventos --event pull_request --limit 1` e `gh api repos/lipedesign/HexGym/actions/workflows --jq '.workflows[] | "\(.state) \(.path)"'`
Expected: uma execução do `Tests` com evento `pull_request`, no PR de teste, e os sete do passo 2 ainda `disabled_manually`.

- [x] **Step 2: Disable the seven inherited workflows**

`gh workflow disable <id> -R lipedesign/HexGym` para `audit.yml` (403149169), `cla-issue.yml` (403149170), `cla.yml` (403149171), `docker-publish.yml` (403149172), `mirror.yml` (403149174), `pages.yml` (403149175) e `release-check.yml` (403149176). Os sete ficaram `disabled_manually`; `test.yml` (403149177) e `ios.yml` (403149173) seguem ativos. Feito em 31/10/2026.

- [ ] **Step 3: See `tests-ok` pass on a pull request**

Run: `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr>`, de novo enquanto sair com 3, e `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket`, no PR de teste do passo 1, com a execução vinda do `pull_request` (a do `workflow_dispatch` não prova que o check chega sozinho).
Expected: o `wait-ci.sh` sai com 0, e o `tests-ok` está em `pass`.

- [ ] **Step 4: Require `tests-ok` on both branches**

Só com a opção 1 na última resposta a um pedido da #3 com as opções da proteção: o do passo 11 da Task 1 ou um pedido por falha do passo 1, que as repete. A resposta a um pedido é o comentário do `/decide` (com `relentless:decision option=`) entre ele e o pedido seguinte, e a de outro pedido da #3, como o de um check travado no passo 3, não muda a proteção. Com a 2, os passos 4 e 5 ficam de fora, e o comentário do passo 6 diz isso. Hoje `required_status_checks` é nulo nas duas, então vai um `PUT` da proteção inteira, com os valores atuais mais o check. Salvar antes a saída de `gh api repos/lipedesign/HexGym/branches/<branch>/protection`. Depois, `gh api -X PUT repos/lipedesign/HexGym/branches/develop/protection --input <arquivo>`, com:

```json
{
  "required_status_checks": { "strict": false, "checks": [{ "context": "tests-ok", "app_id": 15368 }] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

E o mesmo em `main`, com `"strict": true`.

- [ ] **Step 5: Verify the protection**

Run: `gh api repos/lipedesign/HexGym/branches/develop/protection --jq '.required_status_checks.checks'` e o mesmo para `main`
Expected: `[{"context":"tests-ok","app_id":15368}]` nas duas, `strict` falso em `develop` e verdadeiro em `main`, e o resto igual ao que foi salvo no passo 4.

- [ ] **Step 6: Close the issue**

`gh pr close <pr> -R lipedesign/HexGym --delete-branch`, no PR de teste (a resposta ao pedido da #3 autorizou apagar a branch dele); um comentário na #3 com o que foi feito e a saída dos passos 3 e 5 (`comment-agent.sh`); `gh issue close 3 -R lipedesign/HexGym`; e `"$S/set-state.sh" --repo lipedesign/HexGym --issue 3 --state done`.

Run: `git ls-remote --heads origin ci/3-eventos` e `gh issue view 3 -R lipedesign/HexGym --json state,labels --jq '[.state, (.labels | map(.name) | map(select(startswith("state:"))))]'`
Expected: nenhuma linha no primeiro; `["CLOSED",["state:done"]]` no segundo.

---

### Task 3: As branches e as etiquetas herdadas

**Issue:** #11. **Sem código.** As etiquetas seguem a seção 9.1 da especificação. Apagar branch é uma parada do relentless: as branches herdadas só saem depois do `/decide 11` do founder.

- [ ] **Step 1: Save the current lists**

As listas ficam em `.relentless/review/issue-11/`, fora do git (`.relentless/.gitignore`), a mesma pasta do pedido do passo 4.

Run: `mkdir -p .relentless/review/issue-11`, `git ls-remote --heads origin > .relentless/review/issue-11/heads-antes.txt` e `gh label list -R lipedesign/HexGym --limit 100 --json name,description,color > .relentless/review/issue-11/etiquetas-antes.json`

- [ ] **Step 2: Move the type labels to the relentless ones**

Para cada par, `feature` → `enhancement` e `docs` → `documentation`: `gh issue edit <n> -R lipedesign/HexGym --add-label <nova>` em cada número de `gh issue list -R lipedesign/HexGym --state all --label <velha> --limit 200 --json number --jq '.[].number'`, e só então `gh label delete <velha> -R lipedesign/HexGym --yes`. A `accessibility` vira etiqueta de área (decisão do tech lead, registrada na seção 9.1 da especificação): `gh label edit accessibility -R lipedesign/HexGym --name acessibilidade --description "Área: VoiceOver, Dynamic Type, contraste e movimento reduzido"`. As seis etiquetas padrão do GitHub ficam, porque o bootstrap do relentless as recria.

Run, antes de cada `gh label delete`: `gh issue list -R lipedesign/HexGym --state all --label <velha> --limit 200 --json number --jq length` e o mesmo com `--label <velha> --label <nova>`
Expected: os dois números iguais: toda issue com a velha já tem a nova.

- [ ] **Step 3: List the branches to keep**

`main`, `develop` e as branches dos PRs abertos: `gh pr list -R lipedesign/HexGym --state open --json headRefName --jq '.[].headRefName'`.

- [ ] **Step 4: Ask the founder about the inherited branches**

Os SHAs vêm do `git`, que lê o upstream sem `gh`: `git ls-remote --heads origin` e `git ls-remote --heads upstream` (o remoto `upstream` não tem push). Cada outra branch com o SHA igual nos dois vai para `.relentless/review/issue-11/branches-iguais.txt`, com o SHA; a diferente, ou ausente no upstream, fica, e o motivo vai no pedido. O pedido, no formato do `core/templates/decision-request.md` do relentless, em português, com a lista: 1. Apagar as branches listadas, que existem iguais no openGym (recomendada); 2. Manter todas. Ele sai com `"$S/request-decision.sh" --repo lipedesign/HexGym --issue 11 --body-file .relentless/review/issue-11/decisao.md`, e o orquestrador segue em outras issues.

Run: `gh issue view 11 -R lipedesign/HexGym --json labels --jq '[.labels[].name]'`
Expected: `human:pending` e `state:blocked` entre as etiquetas.

- [ ] **Step 5: Delete the listed branches after the answer**

Com `/decide 11 1`: para cada branch `b` de `branches-iguais.txt` cujo SHA em `git ls-remote --heads origin "$b"` ainda é o da lista, `gh api -X DELETE repos/lipedesign/HexGym/git/refs/heads/$b`; a que mudou fica, com o motivo. Com a opção 2, nada sai.

- [ ] **Step 6: Verify**

Run: `git ls-remote --heads origin` e `gh label list -R lipedesign/HexGym --limit 100 --json name --jq '[.[].name] | sort'`
Expected: só `main`, `develop`, as branches de PR aberto e as que ficaram com motivo (todas as herdadas, com a opção 2); e exatamente estas 36 etiquetas: `acessibilidade`, `bug`, `build`, `chore`, `ci:local`, `dados`, `design-system`, `documentation`, `duplicate`, `enhancement`, `epic`, `good first issue`, `help wanted`, `human:decided`, `human:pending`, `invalid`, `investigation`, `merge:auto`, `merge:human`, `motor`, `orphan:ok`, `question`, `review:approved`, `severity:critical`, `severity:high`, `severity:medium`, `state:blocked`, `state:done`, `state:in-progress`, `state:review`, `state:todo`, `sync`, `upstream`, `watch`, `widgets`, `wontfix`.

- [ ] **Step 7: Close the issue**

Um comentário na #11 com o que saiu, o que ficou e por quê (`comment-agent.sh`), `gh issue close 11 -R lipedesign/HexGym` e `"$S/set-state.sh" --repo lipedesign/HexGym --issue 11 --state done`.

---

### Task 4: O motor sem React

**Issue:** #16. São as três mudanças pequenas no código do openGym da seção 8.2. Cada uma vai num commit com mensagem em inglês, no estilo do openGym (`Área: o que mudou`), para poder ser proposta ao openGym. Propor fica com o founder (seção 9.1: falar com o Duarte).

**Files:**
- Create: `frontend/src/lib/state-core.js`, `frontend/src/lib/state-core.test.js`
- Create: `frontend/src/store/useStore.state-core.test.jsx`
- Modify: `frontend/src/store/useStore.js` (de `DEF`, na linha 90, até `restoredStateFor`, na 356, e `loadState`)
- Modify: `frontend/src/lib/coach.js:21`, `frontend/src/lib/duration.js:5`
- Create: `frontend/src/lib/plan-print.js`
- Modify: `frontend/src/lib/plan-share.js` (o import da linha 27 e a seção "printable PDF", da linha 366 ao fim)
- Modify: `frontend/src/sheets.jsx:39`, `frontend/src/views/RoutineEdit.jsx:20`, `frontend/src/lib/report-print.js:12`, `frontend/src/lib/plan-print.test.js:3`, `frontend/src/lib/speed.test.js:6`, `frontend/src/lib/failure-sets.test.js:10`, `frontend/src/views/RoutineEdit.print.test.jsx:14,23`, `frontend/scripts/pdf/render-samples.mjs:44` (o `npm run pdf:check`, que a CI não roda)
- Modify: o comentário de `frontend/src/lib/mobile.js:318`, que cita o caminho

**Interfaces:**
- Produces, em `frontend/src/lib/state-core.js`:
  - `DEF`, `clone(o)`, `draftOf(prev) → { S, done() }`, `restartedState(cur)`, `hasData(st) → boolean` e `restoredStateFor(local, remote, dirty = false)`, como estão hoje;
  - `detectedLang(tag = globalThis.navigator?.language) → string` e `freshState(tag?) → object`: a língua do aparelho pode vir de fora, e o padrão continua o `navigator`;
  - `stateFromSaved(saved, tag?) → object`, novo: o ramo de `loadState` que lê uma cópia salva (`sanitizeAccent(Object.assign(clone(DEF), saved))`, com `detectedLang(tag)` quando a cópia não tem `lang`). O `loadState` passa a usar.
  - `useStore.js` reexporta `DEF`, `draftOf`, `freshState`, `restartedState`, `restoredStateFor` e `hasData`, e nenhum import do app muda.
- Produces, em `frontend/src/lib/plan-print.js`: `printedName(ex, fallback)`, `planPrintHTML(S, owner, { routineId, probe } = {})` e `printPlan(S, owner, opts)`, saídos de `plan-share.js` sem mudar nada. O `plan-share.js` fica com `buildPlanBundle`, `parsePlan` e `mergePlan`, e não importa mais o `print-doc.js` (que importa o `mobile.js`).
- `coach.js` e `duration.js` importam `t` e `tn` de `i18n-core.js`, as mesmas funções que o `i18n.js` reexporta.

- [ ] **Step 1: Install and take the baseline**

Run: `cd frontend && npm ci && npm test`
Expected: tudo verde. O relatório anota quantos arquivos e testes passaram, para os passos 5 e 9.

- [ ] **Step 2: Write the failing tests for `state-core.js`**

```js
import { test, expect, vi } from 'vitest'
import { DEF, freshState, stateFromSaved, detectedLang } from './state-core.js'

test('a fresh state is what the web app starts with', () => {
  const s = freshState('pt-BR')
  expect([s.lang, s.langAuto, s.weighIn, s.gifSize]).toEqual(['en', true, false, 'mini'])
  expect(freshState('ar-EG').lang).toBe('ar')
})
test('without a navigator the language is English', () => {
  vi.stubGlobal('navigator', undefined)                  // o Node 22 tem navigator.language, da máquina
  try { expect(detectedLang()).toBe('en') } finally { vi.unstubAllGlobals() }
})
test('a saved copy keeps the keys this version does not know', () => {
  const s = stateFromSaved({ chaveDoFuturo: { x: [1, 2] }, unit: 'lb' })
  expect(s.chaveDoFuturo).toEqual({ x: [1, 2] }); expect(s.unit).toBe('lb'); expect(s.routines).toEqual(DEF.routines)
})
test('a saved copy without a language gets the detected one', () => {
  expect(stateFromSaved({}, 'ar-EG').lang).toBe('ar'); expect(stateFromSaved({ lang: 'de' }, 'ar-EG').lang).toBe('de')
})
```

O `state-core.test.js` só importa o `state-core.js`, para rodar também contra o script (Task 6). A reexportação fica num arquivo à parte, `frontend/src/store/useStore.state-core.test.jsx`, com o mesmo cabeçalho `// @vitest-environment happy-dom` e os mesmos dois `vi.mock` de `useStore.default-lang.test.jsx`:

```js
test('useStore re-exports the same objects', () => {
  expect(store.DEF).toBe(DEF); expect(store.freshState).toBe(freshState); expect(store.restartedState).toBe(restartedState)
})
```

- [ ] **Step 3: Run them to verify they fail**

Run: `cd frontend && npx vitest run src/lib/state-core.test.js src/store/useStore.state-core.test.jsx`
Expected: FAIL nos dois, porque `state-core.js` não existe.

- [ ] **Step 4: Move the definitions**

Vão para `state-core.js` como estão, com os comentários; mudam só as duas assinaturas, e entra o `stateFromSaved`. Em `useStore.js` saem os imports que só essas definições usavam, o `loadState` chama `stateFromSaved(JSON.parse(raw))`, o `clone` vem de `state-core.js` e entram as reexportações (o `hasData` continua no `export` do fim do arquivo).

- [ ] **Step 5: Run the whole suite**

Run: `cd frontend && npm test`
Expected: PASS, com os números do passo 1 mais os 5 testes novos.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/lib/state-core.js frontend/src/lib/state-core.test.js frontend/src/store/useStore.state-core.test.jsx frontend/src/store/useStore.js
git commit -m "Engine: DEF and the state helpers in lib/state-core.js, so a host without React can start and read a profile"
```

- [ ] **Step 7: Point `coach.js` and `duration.js` at the i18n core, and commit**

Trocar `from './i18n.js'` por `from './i18n-core.js'` nas duas linhas.

Run: `grep -n "i18n.js'" frontend/src/lib/coach.js frontend/src/lib/duration.js; cd frontend && npx vitest run src/lib/coach src/lib/duration`
Expected: o `grep` não acha nada, e os testes passam.

```bash
git add frontend/src/lib/coach.js frontend/src/lib/duration.js
git commit -m "Engine: coach.js and duration.js read t and tn from i18n-core.js, which does not pull React"
```

- [ ] **Step 8: Move the printable plan to `plan-print.js`**

A seção "printable PDF" de `plan-share.js` vai inteira para `plan-print.js`. O que ela usa do resto de `plan-share.js` (como o `cleanIntensifier`) passa a ser exportado e importado de lá. Os oito importadores da lista de arquivos trocam o caminho: o `vi.mock` de `RoutineEdit.print.test.jsx` passa a mirar `../lib/plan-print.js`, e o `render-samples.mjs` carrega `/src/lib/plan-print.js` para o `planPrintHTML`. O comentário de `mobile.js:318` passa a citar `lib/plan-print.js`.

Run: `grep -n "print-doc" frontend/src/lib/plan-share.js` e `grep -rn "plan-share" frontend/scripts`
Expected: nada, nos dois.

- [ ] **Step 9: Run the whole suite and the locale checks**

Run: `cd frontend && npm test && node scripts/check-locales.mjs && node scripts/check-source-strings.mjs --strict`
Expected: verde, com os mesmos números do passo 5.

- [ ] **Step 10: Commit**

```bash
git add frontend/src/lib/plan-share.js frontend/src/lib/plan-print.js frontend/src/sheets.jsx frontend/src/views/RoutineEdit.jsx frontend/src/lib/report-print.js frontend/src/lib/plan-print.test.js frontend/src/lib/speed.test.js frontend/src/lib/failure-sets.test.js frontend/src/views/RoutineEdit.print.test.jsx frontend/scripts/pdf/render-samples.mjs frontend/src/lib/mobile.js
git commit -m "Plans: the printable plan in lib/plan-print.js, so plan-share.js no longer reaches the print and mobile code"
```

---

### Task 5: O script do motor

**Issue:** #17.

**Files:**
- Create: `apple/Packages/HexEngine/JS/values.js`, `polyfills.js`, `runtime.js`
- Create: `apple/Packages/HexEngine/JS/values.test.mjs`, `polyfills.test.mjs`, `runtime.test.mjs`, `build.test.mjs`
- Create: `apple/Packages/HexEngine/JS/test-fixtures/imports-react.js` (uma linha: `import 'react'`), `dynamic-import.js` (`export const load = name => import(name)`) e `import-meta.js` (`export const here = import.meta.url`)
- Create: `scripts/build-hexgym-engine.mjs`
- Create (gerado): `apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js`
- Create: `apple/.gitattributes`
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs` (parte `engine`)

**Interfaces:**
- Consumes: `state-core.js` e os módulos liberados na Task 4.
- Produces:
  - `values.js`: `encodeValue(v)` e `decodeValue(v)`. JSON comum, mais `{"$date": ms}`, `{"$undefined": true}` e `{"$number": "NaN" | "Infinity" | "-Infinity"}`. Map, Set, função ou símbolo lançam `Error('valor que o motor não sabe passar: <tipo>')`.
  - `polyfills.js`: exporta `cloneStructured(v)` e o instala como `structuredClone` só quando o global não existe. Copia objetos, arrays, `Date`, `Map`, `Set`, valores `undefined` e referências circulares; função ou símbolo lança um erro com `name` `DataCloneError`. Os outros complementos da seção 8.2 (`console` e os timers) vêm do Swift, na Task 7.
  - `runtime.js`, o que o Swift chama, sempre com texto JSON:
    - `info() → string`: `{"exercises": CATALOGUE.length, "openGymVersion": __APP_VERSION__}`, com `"dev"` quando o global não existe (nos testes sem build);
    - `setDeviceLanguage(tag)`;
    - `freshDocument() → string`: o documento passa a ser `freshState(tag)`;
    - `restore(json)`: o documento passa a ser `stateFromSaved(JSON.parse(json), tag)`; o que não for objeto lança `TypeError('HexEngine: o documento não é um objeto JSON')`;
    - `document() → string`: o `stateJson` do documento; antes do primeiro, `Error('HexEngine: nenhum documento aberto')`;
    - `makeCall(modules) → call(name, argsJson) → string`: `name` é `"<caminho do módulo>#<export>"`, como `"frontend/src/lib/onerm.js#estimate1RM"`; os argumentos são `decodeValue(JSON.parse(argsJson))` e a resposta é `JSON.stringify(encodeValue({ returned, args }))`, com os argumentos depois da chamada, para mostrar o que a função mudou; nome que não existe lança um erro que diz o nome.

    Cada troca de documento cura e registra os exercícios personalizados e os apelidos, como o boot do app web (`useStore.js:1352-1354`): `healCustomEx`, `registerCustom` e `registerExerciseAliases`.
  - `scripts/build-hexgym-engine.mjs`: `engineGraph(repo) → Promise<{ [módulo]: string[] }>`, `cleanModules(graph) → string[]` (os `frontend/src/lib/*.js` limpos, em ordem alfabética), `buildEngine(repo, { extra = [] } = {}) → Promise<{ code, modules }>` e `main(argv, io) → Promise<number>`, com `io = { build, readFile, writeFile, out, err }` e os reais como padrão. CLI: `node scripts/build-hexgym-engine.mjs [--check]`.
  - O `hexengine.js`: um script clássico que cria o global `HexEngine` com o que `runtime.js` exporta, `call = makeCall(__modules)` e `__modules`, com cada módulo do motor pelo caminho a partir da raiz do repositório.
  - A parte `engine` do `check.mjs`.

**O que é o motor:** todo módulo de `frontend/src/lib` (sem os testes e sem `fixtures/`) que não alcança, por nenhum caminho de imports estáticos ou dinâmicos, um pacote, um módulo do Node ou um arquivo fora de `frontend/src/lib` e `api/coach/core`, mais os JSON e os módulos de `api/coach/core` que ele importa. Assim, módulo novo do openGym que não puxa o navegador entra sozinho, e o `--check` mostra a mudança.

**As decisões do build:**
- O Vite vem de `frontend/node_modules`, porque a raiz não tem: `createRequire(<frontend/package.json>).resolve('vite')` (no Vite 8, o `exports["."]` é o texto `./dist/node/index.js`), importado por `pathToFileURL`. Sempre com `configFile: false` e `root: repo`, para nada do `vite.config.js` do app entrar.
- `engineGraph` faz um build de sondagem, em formato ES e sem gravar, com uma entrada que importa todo módulo de `frontend/src/lib`. Um plugin anota cada import em `resolveId`, estático e dinâmico, e marca como externo tudo fora das duas pastas. Os caminhos ficam relativos à raiz, os pacotes ficam com o nome (`react`, `@capacitor/core`) e os módulos do Node com `node:`.
- `buildEngine` faz o build de verdade:
  - `build.lib` em `iife` com `name: 'HexEngine'`, `write: false`, `minify: false` (o erro do JS chega ao Swift com uma linha que dá para ler) e `target: 'es2022'`;
  - uma entrada virtual que importa `polyfills.js` primeiro, depois `runtime.js` e um `import * as` para cada módulo limpo, juntos em `__modules`;
  - `define: { __APP_VERSION__: JSON.stringify(<versão de frontend/package.json>) }`;
  - um plugin `enforce: 'pre'` que troca cada `import.meta.env` por `({})`: é o "`import.meta.env` vazio" da seção 8.2, e por isso nenhuma variável `VITE_` da máquina entra no script. Depois da troca, o `transform` dele lê cada `.js` com `this.parse` e, se ainda sobrar um `MetaProperty` com `meta.name === 'import'`, falha com `o motor não pode usar import.meta (em <módulo>)`;
  - um `resolveId` que falha com `o motor não pode importar <x> (em <módulo>)` para qualquer coisa fora das duas pastas e de `apple/Packages/HexEngine/JS`;
  - um `generateBundle` que lê a saída com `this.parse` e falha com `o script do motor ficou com import dinâmico` se achar um `ImportExpression`. As duas conferências vão pela árvore do código, nunca por expressão regular, porque há comentários que falam de `import.meta.glob` e de `import()`;
  - o `banner` `// Gerado por scripts/build-hexgym-engine.mjs a partir do openGym <versão>, com <n> módulos. Não edite à mão.`
- A CLI grava `apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js`. Com `--check`, só compara (arquivo que falta conta como velho) e sai com 1 e `apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js está desatualizado. Rode: node scripts/build-hexgym-engine.mjs`, como os outros `--check` do repositório.
- `apple/.gitattributes` marca `Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js` com `linguist-generated=true -diff` e `Packages/HexEngine/Tests/HexEngineTests/Cases/*.json` (Task 7) com `linguist-generated=true`, para o GitHub dobrar esses diffs. O `-diff` faz o git e o GitHub mostrarem o script como binário, porque o pacote do revisor do relentless leva o `gh pr diff` inteiro, e o script não cabe nele.
- O revisor não vê o conteúdo do script gerado, que o diff do PR mostra como binário. O QA mostra a prova dele: o tamanho em bytes, o número de linhas, o sha256, os módulos do `lib` que entraram e o `node scripts/build-hexgym-engine.mjs --check` passando. Se o `gh pr diff <pr> -R lipedesign/HexGym > /dev/null` falhar (406, acima do limite do diff de PR do GitHub: 20.000 linhas ou 300 arquivos), vale o que diz a nota `2026-11-03-um-orquestrador-so.md`.

- [ ] **Step 1: Write the failing tests for `values.js`, `polyfills.js` and `runtime.js`**

```js
// values.test.mjs
test('dates, undefined and the numbers JSON cannot hold go and come back', () => {
  const v = { d: new Date(0), u: undefined, n: NaN, i: -Infinity, list: [1, { x: undefined }] }
  assert.deepStrictEqual(decodeValue(JSON.parse(JSON.stringify(encodeValue(v)))), v)
})
test('a Map, a Set or a function is refused', () => {
  for (const v of [new Map(), new Set(), () => 1]) assert.throws(() => encodeValue(v), /valor que o motor não sabe passar/)
})

// polyfills.test.mjs
test('the copy matches the native structuredClone', () => {
  const a = { n: 1, u: undefined, d: new Date(5), m: new Map([[1, { y: 2 }]]), s: new Set([1, 2]), list: [1, [2]] }
  a.self = a
  const c = cloneStructured(a)
  assert.deepStrictEqual(c, structuredClone(a)); assert.notEqual(c.list, a.list); assert.equal(c.self, c)
})
test('a function cannot be copied', () => assert.throws(() => cloneStructured({ f() {} }), e => e.name === 'DataCloneError'))
test('the native one stays when it exists', () => assert.notEqual(globalThis.structuredClone, cloneStructured))

// runtime.test.mjs: R é `import * as R from './runtime.js'`; exerciseOf, estimate1RM e isoOf vêm direto de frontend/src/lib
test('a fresh document is the web app first run in the device language', () => {
  R.setDeviceLanguage('ar-EG'); assert.equal(JSON.parse(R.freshDocument()).lang, 'ar')
  R.setDeviceLanguage('pt-BR'); const d = JSON.parse(R.freshDocument())
  assert.deepEqual([d.lang, d.langAuto, d.weighIn, d.gifSize], ['en', true, false, 'mini'])
})
test('restore keeps the keys it does not know', () => {
  R.restore('{"chaveDoFuturo":{"x":[1,2]}}'); assert.deepEqual(JSON.parse(R.document()).chaveDoFuturo, { x: [1, 2] })
})
test('restore refuses what is not a JSON object', () => {
  assert.throws(() => R.restore('[1]'), /o documento não é um objeto JSON/); assert.throws(() => R.restore('{'), SyntaxError)
})
test('each document brings its own custom exercises', () => {
  R.restore('{"customEx":[{"id":"c1","n":"Remada do HexGym","bp":"back"}]}'); assert.equal(exerciseOf('c1')?.n, 'Remada do HexGym')
  R.restore('{}'); assert.equal(exerciseOf('c1'), undefined)
})
test('call runs a function and shows the arguments after the call', () => {
  const call = R.makeCall({ 'frontend/src/lib/onerm.js': { estimate1RM } })
  assert.deepEqual(JSON.parse(call('frontend/src/lib/onerm.js#estimate1RM', '[100,5]')), { returned: estimate1RM(100, 5), args: [100, 5] })
  assert.throws(() => call('frontend/src/lib/nope.js#x', '[]'), /frontend\/src\/lib\/nope\.js#x/)
})
test('call decodes the arguments it receives', () => {
  const call = R.makeCall({ 'frontend/src/lib/format.js': { isoOf } }), noon = Date.UTC(2026, 9, 25, 12)
  assert.equal(JSON.parse(call('frontend/src/lib/format.js#isoOf', JSON.stringify([{ $date: noon }]))).returned, isoOf(new Date(noon)))
})
test('document before any document fails', async () => {
  const fresh = await import('./runtime.js?antes'); assert.throws(() => fresh.document(), /nenhum documento aberto/)
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test 'apple/Packages/HexEngine/JS/*.test.mjs'`
Expected: FAIL, `Cannot find module` para os três módulos.

- [ ] **Step 3: Implement `values.js`, `polyfills.js` and `runtime.js`**

- [ ] **Step 4: Run them to verify they pass**

Run: o comando do passo 2
Expected: PASS, 12 testes.

- [ ] **Step 5: Write the failing tests for the build**

Em `build.test.mjs`, `repo` é a raiz do repositório e `engine()` guarda o resultado do primeiro `buildEngine(repo)` do arquivo. `fakeIo({ built, current })` devolve um `io` cujo `build` resolve `{ code: built, modules: [] }` e cujo `readFile` devolve `current`, e que guarda cada gravação em `writes` e o que foi para `err` em `stderr`:

```js
const L = 'frontend/src/lib/'
test('a module is clean only when nothing it reaches leaves the engine folders', () => {
  const graph = {
    [L + 'a.js']: [L + 'b.js'], [L + 'b.js']: ['react'], [L + 'c.js']: [L + 'a.js'],
    [L + 'd.js']: [L + 'data.json', 'api/coach/core/x.js'], [L + 'data.json']: [], 'api/coach/core/x.js': [],
    [L + 'e.js']: ['frontend/src/store/useStore.js'], [L + 'f.js']: ['node:fs'],
    [L + 'g.js']: [L + 'h.js'], [L + 'h.js']: [L + 'g.js'], [L + 'i.js']: [L + 'j.js'], [L + 'j.js']: [L + 'i.js', '@capacitor/core'],
  }
  assert.deepEqual(cleanModules(graph), [L + 'd.js', L + 'g.js', L + 'h.js'])
})
test('the engine has what the app needs and none of the browser side', async () => {
  const { modules } = await engine()
  for (const m of ['progression', 'sync-merge', 'state-core', 'coach', 'duration', 'plan-share', 'exercises']) assert.ok(modules.includes(`${L}${m}.js`), m)
  for (const m of ['i18n', 'mobile', 'api', 'print-doc', 'plan-print']) assert.ok(!modules.includes(`${L}${m}.js`), m)
})
test('the script is the same on every run, whatever VITE_ variables the machine has', async () => {
  const { code } = await engine(); process.env.VITE_IMG_BASE = 'https://example.com/'
  try { assert.equal((await buildEngine(repo)).code, code) } finally { delete process.env.VITE_IMG_BASE }
})
test('the script has no path of this machine', async () => assert.ok(!(await engine()).code.includes(repo)))
test('a module forced in with a computed import fails the build', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/dynamic-import.js'] }), /o script do motor ficou com import dinâmico/)
})
test('a module forced in with import.meta fails with its name', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/import-meta.js'] }),
    /o motor não pode usar import\.meta \(em apple\/Packages\/HexEngine\/JS\/test-fixtures\/import-meta\.js\)/)
})
test('the script loads and answers', async () => {
  const E = new Function((await engine()).code + '\nreturn HexEngine')()
  assert.ok(JSON.parse(E.info()).exercises > 5000); E.setDeviceLanguage('pt-BR'); assert.equal(JSON.parse(E.freshDocument()).langAuto, true)
})
test('a module forced in that imports a package fails with its name', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/imports-react.js'] }),
    /o motor não pode importar react \(em apple\/Packages\/HexEngine\/JS\/test-fixtures\/imports-react\.js\)/)
})
test('--check reports a stale script and writes nothing', async () => {
  const io = fakeIo({ built: 'novo', current: 'velho' })
  assert.equal(await main(['--check'], io), 1); assert.match(io.stderr, /hexengine\.js está desatualizado/); assert.equal(io.writes.length, 0)
  assert.equal(await main(['--check'], fakeIo({ built: 'novo', current: 'novo' })), 0)
})
```

- [ ] **Step 6: Run them to verify they fail**

Run: `node --test apple/Packages/HexEngine/JS/build.test.mjs`
Expected: FAIL, `Cannot find module` para `scripts/build-hexgym-engine.mjs`.

- [ ] **Step 7: Implement `scripts/build-hexgym-engine.mjs`**

Seguindo as decisões acima.

- [ ] **Step 8: Generate the script and run every test**

Run: `node scripts/build-hexgym-engine.mjs && node --test 'apple/Packages/HexEngine/JS/*.test.mjs'`
Expected: o build imprime o número de módulos e o tamanho do script, e os testes dão PASS, 21 no total.

- [ ] **Step 9: Add the `engine` part to `check.mjs`**

`PARTS.engine`: `node scripts/build-hexgym-engine.mjs --check` e `node --test 'apple/Packages/HexEngine/JS/*.test.mjs'`. Atualizar a mensagem esperada do teste "unknown part".

Run: `node scripts/hexgym/check.mjs scripts engine`
Expected: `ok`.

- [ ] **Step 10: Commit**

```bash
git add scripts/build-hexgym-engine.mjs apple/.gitattributes apple/Packages/HexEngine/JS apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js scripts/hexgym/check.mjs scripts/hexgym/check.test.mjs
git commit -m "Script do motor: os módulos limpos do lib num HexEngine só, com --check"
```

---

### Task 6: Os testes do lib contra o script e a carga no jsc

**Issue:** #18.

**Files:**
- Create: `frontend/vitest.hexengine.config.js`
- Create: `scripts/hexgym/engine-tests.mjs`, `scripts/hexgym/engine-tests.test.mjs`
- Create: `scripts/hexgym/engine-load.mjs`, `scripts/hexgym/engine-load.test.mjs`
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs` (a parte `engine` ganha o Vitest, e entra a parte `load`)

**Interfaces:**
- Consumes: o script, com `__modules` (Task 5); `buildDemoState()` de `frontend/src/lib/demoSeed.js`; `draftOf` e `stateFromSaved` (Task 4); `buildCombinedEntries` de `frontend/src/lib/session-merge.js`.
- Produces:
  - `scripts/hexgym/engine-tests.mjs`: `pickEngineTests(files, engineModules) → { picked: string[], skipped: [{ path, reason }] }`, com `files` como `[{ path, text }]`, `engineModules` como um `Set` e os caminhos sempre a partir da raiz do repositório;
  - `cd frontend && npx vitest run --config vitest.hexengine.config.js`;
  - `node scripts/hexgym/engine-load.mjs [--workouts N]`, que exporta `padHistory(S, total) → S` e `overBudget(results, slack = 1) → string[]`;
  - a parte `load`.

**O config do Vitest:**
- Roda o script uma vez, com `new Function(code + '\nreturn HexEngine')`, para saber os módulos de `__modules` e o que cada um exporta.
- Escolhe os testes com `pickEngineTests`, sobre os `*.test.js` e `*.test.jsx` de `src/lib`. Entra o teste em que cada import (`import … from`, `import '…'`, `export … from` e `import('…')` com texto fixo) é um módulo do script, `vitest`, `fast-check`, um módulo `node:` ou um `.json`, com pelo menos um módulo do script, e que não chama `vi.mock`, `vi.doMock`, `vi.stubEnv` nem `vi.resetModules`: um mock não alcança o código que já está dentro do script, e o ambiente ficou fixo no build. O que fica de fora leva o motivo, nesta ordem: o primeiro import fora da lista (`importa <x>`, com o nome do pacote ou o caminho a partir da raiz), a primeira das quatro chamadas (`chama vi.mock`), ou `não importa nenhum módulo do motor`.
- Tira os de `EXCLUDED`, um objeto `arquivo → motivo` no próprio config, só para teste que falha por causa do redirecionamento. O primeiro candidato é `state-json.test.js`, cuja checagem só existe com `MODE === 'test'`. Cada entrada passa pela revisão.
- Lança erro se a escolha tiver menos de 117 arquivos (o número da seção 8.2) ou se faltar um destes: `progression`, `sync-merge`, `onerm`, `finish-workout`, `recovery`, `workout-model`, `log-workout`, `history`, `supersetFlow`, `routines`, `units`, `measurements`, `plan-share`, `exercises` e `state-core`. Imprime `HexEngine: <n> arquivos de teste contra o script, <m> de fora` e, com `HEXENGINE_SKIPPED=1`, uma linha `fora: <arquivo> (<motivo>)` para cada um dos de fora.
- `test.setupFiles: ['./src/test-setup.js']`, o mesmo do `vite.config.js`, e nada mais dele.
- Um plugin `enforce: 'pre'`: quando um teste escolhido importa um módulo do script, o `resolveId` devolve `\0hexengine:<caminho>`, e o `load` devolve um módulo que pega o script de `\0hexengine-script` (`export default new Function(<texto do script> + '\nreturn HexEngine')()`, avaliado uma vez por arquivo de teste) e reexporta cada nome com `export const <nome> = m.<nome>`, mais o `default`. Nenhum módulo do `lib` exporta `let` ou `var`, então copiar o valor não perde nada.

**O teste de carga** (`engine-load.mjs`):
- Usa o `jsc` de `/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc`. Sem ele, sai com 1 e `o teste de carga precisa do jsc do macOS`.
- Monta no Node o histórico grande com `padHistory(buildDemoState(), total)`: os treinos do demo copiados para trás, uma semana por vez, com `id` novo, até `total` (padrão 1.040, cinco anos de quatro treinos por semana).
- Roda `jsc --useJIT=false` (o iPhone roda o JavaScriptCore sem JIT) num script de medição que carrega o `hexengine.js` com `load()`, mede com `preciseTime()` e imprime um JSON com:
  - `evaluate`: avaliar o script;
  - `restore`: o `HexEngine.restore` do documento;
  - `tick`: a mediana de 20 séries marcadas, cada uma como o `update()` do app web faz: `draftOf(S)`, uma série a mais feita em `active`, `done()`, `stampChange(prev, next, now)` e `stateJson(next)`. A sessão começa como o `beginWorkout` (`sheets.jsx:3120-3135`): as `entries` de `buildCombinedEntries(S, [rotina.id])` (`session-merge.js:22`) e os mesmos campos de `active`;
  - `fatigue`: o `fatigueOf(S.workouts, now)`, só para registro;
  - `structuredClone`: se a cópia de um objeto com `Date`, `Map`, `Set` e referência circular é igual ao original e não é o mesmo objeto.
- O `jsc` roda cinco vezes, um processo novo de cada vez. A tabela usa a mediana das cinco em cada tempo, e o `structuredClone` precisa dar certo nas cinco.
- Imprime uma tabela e sai com 1 quando `overBudget` acha algo: `evaluate + restore` acima de 300 ms, `tick` acima de 30 ms, ou `structuredClone` falso. As metas são do tech lead, a partir da seção 8.13 (o app abre em menos de 1 s e a série aparece em menos de 100 ms), com folga de três vezes para um iPhone mais lento que este Mac. O `slack` multiplica as duas metas: o script lê `HEXGYM_LOAD_SLACK` (padrão 1), e a CI usa 2, porque o runner é mais lento e mais instável que este Mac.

- [ ] **Step 1: Write the failing tests for `pickEngineTests`**

```js
const L = 'frontend/src/lib/', engine = new Set([L + 'onerm.js', L + 'history.js'])
test('a test that only reads engine modules is picked', () => {
  const text = "import { test } from 'vitest'\nimport fc from 'fast-check'\nimport { estimate1RM } from './onerm.js'\n" +
    "import rows from './fixtures/rows.json' with { type: 'json' }\nimport { readFileSync } from 'node:fs'"
  assert.deepEqual(pickEngineTests([{ path: L + 'onerm.test.js', text }], engine).picked, [L + 'onerm.test.js'])
})
test('every other test is left out with its reason', () => {
  const { picked, skipped } = pickEngineTests([
    { path: L + 'a.test.js', text: "import { x } from './onerm.js'\nimport React from 'react'" },
    { path: L + 'b.test.js', text: "import { vi } from 'vitest'\nimport { x } from './onerm.js'\nvi.mock('./history.js')" },
    { path: L + 'c.test.js', text: "export { t } from './i18n.js'\nimport { x } from './onerm.js'" },
    { path: L + 'd.test.js', text: "import { test } from 'vitest'" },
    { path: L + 'e.test.js', text: "import { x } from './history.js'\nconst m = await import('../store/useStore.js')" },
  ], engine)
  assert.deepEqual(picked, [])
  assert.deepEqual(skipped.map(s => [s.path.slice(L.length), s.reason]), [
    ['a.test.js', 'importa react'], ['b.test.js', 'chama vi.mock'], ['c.test.js', 'importa frontend/src/lib/i18n.js'],
    ['d.test.js', 'não importa nenhum módulo do motor'], ['e.test.js', 'importa frontend/src/store/useStore.js']])
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test scripts/hexgym/engine-tests.test.mjs`
Expected: FAIL, `Cannot find module` para `./engine-tests.mjs`.

- [ ] **Step 3: Implement `engine-tests.mjs` and write the config**

Run: o comando do passo 2
Expected: PASS, 2 testes.

- [ ] **Step 4: Run the lib tests against the script**

Run: `cd frontend && HEXENGINE_SKIPPED=1 npx vitest run --config vitest.hexengine.config.js`
Expected: `HexEngine: <n> arquivos de teste contra o script, <m> de fora`, com n de 117 para cima, a lista dos de fora com o motivo (ela vai no PR) e PASS. Teste que falha só pelo redirecionamento entra em `EXCLUDED`, com o motivo. Teste que falha por outro motivo é uma diferença real entre o script e o código: a Task para com BLOCKED e os detalhes, sem excluir nada.

- [ ] **Step 5: Prove the tests read the script**

Trocar à mão, no script gerado, o `return` de `estimate1RM` por `return 0` e rodar o comando do passo 4.
Expected: FAIL em `onerm.test.js`. Depois, `node scripts/build-hexgym-engine.mjs` e o passo 4 de novo, com PASS.

- [ ] **Step 6: Write the failing tests for the load test**

```js
test('padHistory reaches the total with a new id for each copy', () => {
  const S = padHistory(buildDemoState(), 1040)
  assert.equal(S.workouts.length, 1040); assert.equal(new Set(S.workouts.map(w => w.id)).size, 1040)
})
test('overBudget names each limit that was passed', () => {
  assert.deepEqual(overBudget({ evaluate: 100, restore: 150, tick: 10, structuredClone: true }), [])
  assert.deepEqual(overBudget({ evaluate: 200, restore: 150, tick: 31, structuredClone: false }),
    ['evaluate + restore: 350 ms (meta 300)', 'tick: 31 ms (meta 30)', 'structuredClone diferente no JavaScriptCore'])
  assert.deepEqual(overBudget({ evaluate: 200, restore: 150, tick: 31, structuredClone: true }, 2), [])
})
```

- [ ] **Step 7: Run them to verify they fail**

Run: `node --test scripts/hexgym/engine-load.test.mjs`
Expected: FAIL, `Cannot find module` para `./engine-load.mjs`.

- [ ] **Step 8: Implement `engine-load.mjs`**

Importar o arquivo não roda nada; a medição só roda quando ele é o script principal.

- [ ] **Step 9: Run the load test**

Run: `node --test scripts/hexgym/engine-load.test.mjs && node scripts/hexgym/engine-load.mjs`
Expected: PASS nos dois testes e a tabela dentro das metas. A tabela vai no PR, em "Para o founder ver".

- [ ] **Step 10: Add the checks**

Em `PARTS.engine`, depois dos testes do script: `{ name: 'testes do lib contra o script', cmd: 'npx', args: ['vitest', 'run', '--config', 'vitest.hexengine.config.js'], cwd: 'frontend' }`. Parte nova `load`: `node scripts/hexgym/engine-load.mjs`. Como diz a Task 1, cada checagem nova precisa mostrar ao `check.mjs` quantos testes rodou: o Vitest, para a conta da `engine` incluir os testes dele, e o `engine-load.mjs`, senão a parte `load`, que só tem ele, conta zero e falha. Atualizar a mensagem do teste "unknown part".

Run: `node scripts/hexgym/check.mjs scripts engine load`
Expected: `ok`.

- [ ] **Step 11: Commit**

```bash
git add frontend/vitest.hexengine.config.js scripts/hexgym/engine-tests.mjs scripts/hexgym/engine-tests.test.mjs scripts/hexgym/engine-load.mjs scripts/hexgym/engine-load.test.mjs scripts/hexgym/check.mjs scripts/hexgym/check.test.mjs
git commit -m "Os testes do lib contra o script do motor e o teste de carga no jsc sem JIT"
```

---

### Task 7: O pacote HexEngine

**Issue:** #19.

**Files:**
- Create: `apple/.gitignore`
- Create: `apple/Packages/HexEngine/Package.swift`
- Create: `apple/Packages/HexEngine/Sources/HexEngine/HexEngine.swift`, `apple/Packages/HexEngine/Sources/HexEngine/Resources/host.js`
- Create: `apple/Packages/HexEngine/Tests/HexEngineTests/HexEngineTests.swift`, `RecordedCasesTests.swift`
- Create (gerados): `apple/Packages/HexEngine/Tests/HexEngineTests/Cases/America_Sao_Paulo.json`, `Europe_Zurich.json`, `Pacific_Auckland.json`
- Create: `scripts/hexgym/xcode.mjs`, `scripts/hexgym/xcode.test.mjs`
- Create: `scripts/hexgym/engine-cases.mjs`, `scripts/hexgym/record-engine-cases.mjs`, `scripts/hexgym/record-engine-cases.test.mjs`
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs` (a parte `engine` ganha o `--check` dos casos, e entra a parte `packages`)

**Interfaces:**
- Consumes: o script e `values.js` (Task 5).
- Produces:

```swift
public actor HexEngine {
  public init(language: String = Locale.preferredLanguages.first ?? "en")
  public func load() throws -> EngineInfo        // avalia o script na primeira vez; depois devolve o mesmo
  public func freshDocument() throws -> Data     // cria o documento dentro do motor e devolve para gravar
  public func restore(_ document: Data) throws   // troca o documento dentro do motor
  public func document() throws -> Data          // o documento de agora, para gravar
}
public struct EngineInfo: Equatable, Sendable { public let exercises: Int; public let openGymVersion: String }
public enum EngineError: Error, Equatable, Sendable { case scriptMissing, notLoaded, javaScript(String) }
```

  - Internos, para os testes com `@testable import`: `call(_ name: String, json arguments: Data) throws -> Data` e `evaluate(_ script: String) throws -> String`.
  - `scripts/hexgym/xcode.mjs`: `developerDir({ env = process.env, exists = fs.existsSync, selected = () => execFileSync('xcode-select', ['-p'], { encoding: 'utf8' }) } = {}) → string`. A ordem: `DEVELOPER_DIR`, depois `/Applications/Xcode.app`, depois `/Applications/Xcode-beta.app`, depois o que o `xcode-select -p` aponta quando não é a Command Line Tools (o runner `xcode-27` tem nomes com número, como `/Applications/Xcode_27.2.app`). Rodado sozinho, imprime o resultado: `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs)` é como os comandos desta fase escolhem o Xcode.
  - `scripts/hexgym/engine-cases.mjs`: `TIME_ZONES = ['America/Sao_Paulo', 'Europe/Zurich', 'Pacific/Auckland']` e `buildCases(load) → Promise<[{ name, fn, args, ignore? }]>`, em que `load(caminho)` importa um módulo de `frontend/src/lib`.
  - `scripts/hexgym/record-engine-cases.mjs`: `recordZone(zone) → Promise<string>` (o texto do arquivo daquele fuso) e a CLI `[--check]`.
  - A parte `packages` do `check.mjs`, começada aqui; a Task 8 põe o HexStore depois.

**Como o pacote funciona:**
- `load()` cria o `JSContext`, avalia o `host.js` e depois o `hexengine.js` (os dois do `Bundle.module`, com `withSourceURL`), chama `setDeviceLanguage(language)` e lê o `info()`. Sem o script, `.scriptMissing`. Antes do `load()`, toda chamada lança `.notLoaded`.
- O `host.js` traz os complementos do Swift (seção 8.2): `console`, com cada método indo para o `Logger(subsystem: "app.hexgym", category: "motor")` no nível certo, e `setTimeout`/`clearTimeout`, com cada timer guardado num `Map` do JS e disparado por um `Task.sleep` do Swift que volta ao ator. Os blocos Swift que o `host.js` chama capturam o ator com `[weak self]`, para o contexto não prender o motor.
- Swift e JS trocam texto JSON, nunca `JSValue` de objeto. Depois de cada chamada, se `context.exception` não for nulo, ele vira `.javaScript("<mensagem>\n<stack>")` e é limpo, e o contexto segue usável. Exceção dentro de um timer vai para o log como erro.
- `Package.swift`: `swift-tools-version: 6.2`; `platforms: [.iOS(.v26), .macOS(.v26)]`, sem watchOS, porque o Watch não roda JavaScript; produto `HexEngine`; recursos `.copy("Resources/hexengine.js")` e `.copy("Resources/host.js")`; alvo de teste `HexEngineTests` com `.copy("Cases")`. A pasta `JS/` da Task 5 fica fora dos alvos.
- `apple/.gitignore`: `xcuserdata/`, `DerivedData/`, `build/`, `.build/` e `.swiftpm/`.

**Os casos gravados.** O Node grava o que o código do openGym responde, num arquivo por fuso, e o Swift confere que o JavaScriptCore, rodando o script, responde o mesmo (seção 8.2 e Foco da revisão 5).
- `record-engine-cases.mjs` roda um processo filho por fuso de `TIME_ZONES`, com `TZ`. O filho chama `buildCases`, roda cada caso nos módulos de `frontend/src/lib` (como o servidor MCP faz) e devolve `{ name, fn, args, result }`: `args` com `encodeValue` antes da chamada e `result` com `encodeValue({ returned, args })` depois, sem os caminhos de `ignore`. O pai grava `apple/Packages/HexEngine/Tests/HexEngineTests/Cases/<fuso, com _ no lugar de />.json`, com `{ "zone": …, "cases": […] }` e dois espaços de recuo. Com `--check`, compara e sai com 1 e `<arquivo> está desatualizado. Rode: node scripts/hexgym/record-engine-cases.mjs`.
- Só entra caso cuja resposta depende apenas dos argumentos e do fuso. Função que gera `id` entra com o `id` em `ignore`.
- As sessões de treino, no relógio de cada fuso: (1) de 24/10/2026 23:30 a 25/10/2026 00:40, cruzando a meia-noite; (2) 25/10/2026 das 01:30 às 03:30, a volta do horário de verão em Zurique; (3) 29/03/2026 das 01:30 às 03:30, a ida em Zurique; (4) 05/04/2026 das 01:30 às 03:30, a volta em Auckland; (5) 27/09/2026 das 01:30 às 03:30, a ida em Auckland. São Paulo não tem horário de verão. Cada `active` sai de uma rotina com dois exercícios do catálogo, montado como o `beginWorkout` monta (`sheets.jsx:3120-3135`): as `entries` de `buildCombinedEntries(S, [rotina.id])` (`session-merge.js:22`) e os campos das linhas 3125 a 3134, com as séries feitas.
- Os casos:

| Caso | Função | O que prende |
|---|---|---|
| documento novo | `state-core.js#freshState`, com `'pt-BR'` e com `'ar-EG'` | o primeiro uso igual ao do app web |
| cópia salva | `state-core.js#stateFromSaved`, com uma chave desconhecida e sem `lang` | o que a restauração guarda |
| dia | `format.js#isoOf` no começo e no fim de cada sessão | o dia de cada instante no fuso |
| semana | `format.js#weekKey` do dia de cada começo, com `0` e com `1` | a semana que começa no domingo e na segunda |
| tempo atrás | `format.js#fmtAgo(começo, fim)` de cada sessão | o texto relativo, em inglês |
| treino terminado | `finish-workout.js#buildCompletedWorkout(active, { end })` de cada sessão, com `returned.id` em `ignore` | as séries e os recordes, iguais no V8 e no JavaScriptCore |
| dia do treino | `history.js#workoutDay` de cada sessão sem `d`, só com `start` | o dia local de um começo perto da meia-noite ou da troca de horário |
| meio-dia do treino | `history.js#workoutAt` de um treino só com `d`, em cada data das sessões | o meio-dia local, que muda com o fuso e com o horário de verão |
| fadiga | `recovery.js#fatigueOf(treinos, agora)`, com os cinco treinos só com `d` (sem `start`) e `agora` 36 h depois do último | o decaimento contado do meio-dia local, através da troca de horário |
| carimbo | `sync-merge.js#stampChange(prev, next, wall)`, com uma série mudada | o horário de cada campo |
| mesclagem | `sync-merge.js#mergeStates(a, b)`, com duas cópias que mudaram campos diferentes | a junção das duas |
| 1RM | `onerm.js#estimate1RM`, com `[100, 5]`, `[60, 12]` e `[140, 1]`, e `[80, 8]` em cada fórmula de `FORMULAS` | as contas puras |

**O `RecordedCasesTests.swift`:**
- É um `@Suite struct RecordedCasesTests`, o nome que o `--filter` usa.
- Roda só com `HEXGYM_CASES` no ambiente (o `check.mjs` põe junto com o `TZ`), para um `swift test` comum não depender do fuso da máquina: `@Test(.enabled(if: ProcessInfo.processInfo.environment["HEXGYM_CASES"] != nil))`.
- Primeiro, confere que `evaluate("Intl.DateTimeFormat().resolvedOptions().timeZone")` é o fuso de `HEXGYM_CASES`: a prova de que o `TZ` chegou ao JavaScriptCore.
- Depois, para cada caso do arquivo daquele fuso, `call(fn, json: args)`, tira os caminhos de `ignore` e compara com `result`: a mesma estrutura, os mesmos textos e booleanos, e números iguais, com tolerância relativa de `1e-9` para os que não são inteiros (o `Math.exp` e o `Math.pow` podem diferir no último bit entre o V8 e o JavaScriptCore). A falha diz o nome do caso.

- [ ] **Step 1: Write the failing tests for `developerDir`**

```js
test('DEVELOPER_DIR wins', () => assert.equal(developerDir({ env: { DEVELOPER_DIR: '/x' }, exists: () => true }), '/x'))
test('Xcode.app comes before the beta', () =>
  assert.equal(developerDir({ env: {}, exists: () => true }), '/Applications/Xcode.app/Contents/Developer'))
test('the beta when it is the only one', () =>
  assert.equal(developerDir({ env: {}, exists: p => p.includes('Xcode-beta') }), '/Applications/Xcode-beta.app/Contents/Developer'))
test('xcode-select when it points to a full Xcode', () => assert.equal(
  developerDir({ env: {}, exists: () => false, selected: () => '/Applications/Xcode_27.2.app/Contents/Developer\n' }), '/Applications/Xcode_27.2.app/Contents/Developer'))
test('no Xcode says what to do', () => assert.throws(
  () => developerDir({ env: {}, exists: () => false, selected: () => '/Library/Developer/CommandLineTools\n' }), /nenhum Xcode encontrado: instale o Xcode 27\.2 ou defina DEVELOPER_DIR/))
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test scripts/hexgym/xcode.test.mjs`
Expected: FAIL, `Cannot find module` para `./xcode.mjs`.

- [ ] **Step 3: Implement `xcode.mjs` and run the tests**

Run: o comando do passo 2
Expected: PASS, 5 testes.

- [ ] **Step 4: Write `Package.swift` and the failing Swift tests**

Em `HexEngineTests.swift`, `object(_:)` lê um `Data` como `[String: Any]`, `loaded(_ language: String = "en")` devolve um `HexEngine(language:)` já carregado, e `openGymVersion()` lê a versão de `frontend/package.json` a partir do `#filePath`:

```swift
@Test func loadsTheCatalogueAndTheOpenGymVersion() async throws {
  let info = try await HexEngine().load()
  #expect(info.exercises > 5000); #expect(info.openGymVersion == openGymVersion())
}
@Test func callsBeforeLoadFail() async {
  await #expect(throws: EngineError.notLoaded) { try await HexEngine().document() }
}
@Test func loadingTwiceKeepsTheSameContext() async throws {
  let e = try await loaded(); _ = try await e.evaluate("globalThis.marca = 7"); _ = try await e.load()
  #expect(try await e.evaluate("String(globalThis.marca)") == "7")
}
@Test func freshDocumentIsTheWebAppFirstRun() async throws {
  let d = try object(await loaded("pt-BR").freshDocument())
  #expect(d["lang"] as? String == "en"); #expect(d["langAuto"] as? Bool == true); #expect(d["gifSize"] as? String == "mini")
  #expect(try object(await loaded("ar-EG").freshDocument())["lang"] as? String == "ar")
}
@Test func restoreKeepsKeysTheAppDoesNotKnow() async throws {                      // Foco da revisão 2
  let e = try await loaded()
  try await e.restore(Data(#"{"chaveDoFuturo":{"x":[1,2]},"unit":"lb"}"#.utf8))
  let d = try object(await e.document())
  #expect(d["chaveDoFuturo"] as? NSDictionary == ["x": [1, 2]] as NSDictionary); #expect(d["unit"] as? String == "lb")
}
@Test func aHalfEmojiSurvivesTheEngine() async throws {                           // Foco da revisão 2
  let e = try await loaded()
  try await e.restore(Data(#"{"dayNotes":{"2026-10-31":{"text":"\ud83d"}}}"#.utf8))
  #expect(String(decoding: try await e.document(), as: UTF8.self).contains(#""text":"\ud83d""#))
}
@Test func eachDocumentBringsItsOwnCustomExercises() async throws {
  let e = try await loaded(), find = Data(#"["c1"]"#.utf8)
  func found() async throws -> [String: Any]? { try object(await e.call("frontend/src/lib/exercises.js#exerciseOf", json: find))["returned"] as? [String: Any] }
  try await e.restore(Data(#"{"customEx":[{"id":"c1","n":"Remada do HexGym","bp":"back"}]}"#.utf8))
  #expect(try await found()?["n"] as? String == "Remada do HexGym")
  try await e.restore(Data("{}".utf8))
  #expect(try await found()?["$undefined"] as? Bool == true)
}
@Test func anErrorInTheEngineIsThrownAndTheEngineKeepsWorking() async throws {     // Foco da revisão 3
  let e = try await loaded()
  for bad in ["[1]", "{", ""] {
    let error = await #expect(throws: EngineError.self) { try await e.restore(Data(bad.utf8)) }
    #expect(error.map { if case .javaScript(let m) = $0 { !m.isEmpty } else { false } } == true)
  }
  let missing = await #expect(throws: EngineError.self) { _ = try await e.call("frontend/src/lib/nope.js#x", json: Data("[]".utf8)) }
  #expect("\(String(describing: missing))".contains("nope.js#x"))
  try await e.restore(Data("{}".utf8)); #expect(try object(await e.document())["workouts"] != nil)
}
@Test func timersFireOnceAndCanBeCancelled() async throws {
  let e = try await loaded()
  _ = try await e.evaluate("globalThis.hits = 0; setTimeout(() => hits++, 20); clearTimeout(setTimeout(() => hits += 10, 20)); setTimeout(() => { throw new Error('timer') }, 5); 0")
  try await Task.sleep(for: .milliseconds(300))
  #expect(try await e.evaluate("String(hits)") == "1")
}
@Test func consoleAndStructuredCloneWork() async throws {
  #expect(try await loaded().evaluate("console.log('oi'); console.error(new Error('x')); JSON.stringify(structuredClone({ a: [1, { b: 2 }], d: new Date(0) }))")
          == #"{"a":[1,{"b":2}],"d":"1970-01-01T00:00:00.000Z"}"#)
}
@Test func webGlobalsTheEngineDoesNotHaveYet() async throws {
  // URL: cleanUrl, em media-refs.js. fetch: import-hevy.js. TextEncoder, TextDecoder e Blob: zip.js. Cada um tem issue na fase 5.
  #expect(try await loaded().evaluate("[typeof URL, typeof fetch, typeof TextEncoder, typeof TextDecoder, typeof Blob].join()")
          == "undefined,undefined,undefined,undefined,undefined")
}
```

- [ ] **Step 5: Run them to verify they fail**

Run: `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) swift test --package-path apple/Packages/HexEngine`
Expected: FAIL, o alvo `HexEngine` não compila porque ainda não tem código.

- [ ] **Step 6: Implement `HexEngine.swift` and `host.js`**

- [ ] **Step 7: Run them to verify they pass**

Run: o comando do passo 5
Expected: PASS, 11 testes.

- [ ] **Step 8: Write the failing tests for the recorder**

```js
test('the same zone recorded twice gives the same text', async () => {
  assert.equal(await recordZone('Europe/Zurich'), await recordZone('Europe/Zurich'))
})
test('each zone records its own instants', async () => {
  const start = async zone => JSON.parse(await recordZone(zone)).cases.find(c => c.fn === 'frontend/src/lib/format.js#isoOf').args[0].$date
  assert.notEqual(await start('Pacific/Auckland'), await start('Europe/Zurich'))
})
```

- [ ] **Step 9: Run them to verify they fail**

Run: `node --test scripts/hexgym/record-engine-cases.test.mjs`
Expected: FAIL, `Cannot find module` para `./record-engine-cases.mjs`.

- [ ] **Step 10: Implement the cases and the recorder, and record**

Run: `node --test scripts/hexgym/record-engine-cases.test.mjs && node scripts/hexgym/record-engine-cases.mjs`
Expected: PASS, 2 testes, e os três arquivos em `Cases/`.

- [ ] **Step 11: Write `RecordedCasesTests.swift`**

- [ ] **Step 12: Replay the cases in each zone**

Run: `for z in America/Sao_Paulo Europe/Zurich Pacific/Auckland; do TZ=$z HEXGYM_CASES=$z DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) swift test --package-path apple/Packages/HexEngine --filter RecordedCasesTests || exit 1; done`
Expected: PASS nos três. Um caso diferente é uma diferença real entre o JavaScriptCore e o V8: a Task para com BLOCKED e o caso, sem tirar o caso.

- [ ] **Step 13: Prove the zone check works**

Run: `TZ=America/Sao_Paulo HEXGYM_CASES=Europe/Zurich DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) swift test --package-path apple/Packages/HexEngine --filter RecordedCasesTests`
Expected: FAIL na conferência do fuso.

- [ ] **Step 14: Add the checks**

Em `PARTS.engine`: `{ name: 'casos gravados em dia', cmd: 'node', args: ['scripts/hexgym/record-engine-cases.mjs', '--check'] }`. `PARTS.packages`: `swift test --package-path apple/Packages/HexEngine` com `TZ` e `HEXGYM_CASES` no primeiro fuso de `TIME_ZONES`, e uma rodada com `--filter RecordedCasesTests` para cada outro fuso. O `env` de cada uma é uma função que devolve `{ DEVELOPER_DIR: developerDir(), TZ, HEXGYM_CASES }`. Como diz a Task 1, as rodadas do `swift test` precisam mostrar ao `check.mjs` quantos testes rodaram, senão a parte `packages`, que só tem elas, conta zero e falha (a `engine` segue contada pelo `node --test` dela). Atualizar a mensagem do teste "unknown part".

Run: `node scripts/hexgym/check.mjs scripts engine packages`
Expected: `ok`.

- [ ] **Step 15: Commit**

```bash
git add apple/.gitignore apple/Packages/HexEngine/Package.swift apple/Packages/HexEngine/Sources apple/Packages/HexEngine/Tests scripts/hexgym
git commit -m "HexEngine: o motor num JSContext dentro de um ator, com os casos gravados no Node"
```

---

### Task 8: O pacote HexStore

**Issue:** #20.

**Files:**
- Create: `apple/Packages/HexStore/Package.swift`
- Create: `apple/Packages/HexStore/Sources/HexStore/DocumentStore.swift`
- Create: `apple/Packages/HexStore/Tests/HexStoreTests/DocumentStoreTests.swift`
- Modify: `scripts/hexgym/check.mjs` (a parte `packages` ganha o HexStore)

**Interfaces:**
- Consumes: `developerDir()` de `scripts/hexgym/xcode.mjs` (Task 7) na checagem.
- Produces:

```swift
public actor DocumentStore {
  public init(directory: URL)
  public static func appGroupDirectory(_ identifier: String = "group.app.hexgym",
                                       lookup: (String) -> URL? = { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }) throws -> URL
  public func load() throws -> StoredDocument
  public func save(_ document: Data) throws
  public func syncBase() throws -> SyncBase?
  public func saveSyncBase(_ base: SyncBase) throws
}
public enum StoredDocument: Equatable, Sendable { case empty, current(Data), recovered(Data) }
public struct SyncBase: Codable, Equatable, Sendable { public var rev: Int; public var ts: Int?; public var wid: String? }
public enum DocumentStoreError: Error, Equatable { case appGroupUnavailable(String), unreadable, notAnObject }
```

Os arquivos, todos no `directory`: `state.json` (o documento), `state.previous.json` (a cópia anterior), `state.unreadable.json` (o último arquivo ruim, guardado para alguém olhar) e `sync-base.json`. `Package.swift`: `swift-tools-version: 6.2`, `platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)]`, produto `HexStore`, alvo de teste `HexStoreTests`.

- [ ] **Step 1: Write the failing tests**

Swift Testing, cada teste num diretório temporário novo:

```swift
@Test func emptyDirectoryHasNoDocument() async throws { #expect(try await store.load() == .empty) }
@Test func saveThenLoadGivesTheSameBytes() async throws { try await store.save(a); #expect(try await store.load() == .current(a)) }
@Test func secondSaveKeepsThePreviousCopy() async throws {
  try await store.save(a); try await store.save(b)
  #expect(read("state.json") == b); #expect(read("state.previous.json") == a)
}
@Test func truncatedDocumentRecoversFromThePreviousCopy() async throws {   // Foco da revisão 1
  try await store.save(a); try await store.save(b); write("state.json", b.prefix(10))
  #expect(try await store.load() == .recovered(a))
  #expect(read("state.unreadable.json") == b.prefix(10))
}
@Test func bothCopiesBrokenThrowsAndTouchesNothing() async throws {      // Foco da revisão 1
  write("state.json", Data("{".utf8)); write("state.previous.json", Data("x".utf8))
  await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
  #expect(read("state.json") == Data("{".utf8)); #expect(read("state.previous.json") == Data("x".utf8))
}
@Test func brokenDocumentWithoutAPreviousCopyThrows() async throws {     // Foco da revisão 1
  write("state.json", Data("{".utf8))
  await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
  #expect(read("state.json") == Data("{".utf8))
}
@Test func missingDocumentWithAPreviousCopyRecovers() async throws {     // Foco da revisão 1
  write("state.previous.json", a)
  #expect(try await store.load() == .recovered(a))
}
@Test func savingOverABrokenDocumentKeepsTheGoodPreviousCopy() async throws {   // Foco da revisão 1
  try await store.save(a); try await store.save(b); write("state.json", Data("{".utf8))
  try await store.save(c)
  #expect(read("state.json") == c); #expect(read("state.previous.json") == a)
}
@Test func onlyJSONObjectsAreSaved() async throws {
  await #expect(throws: DocumentStoreError.notAnObject) { try await store.save(Data("[1]".utf8)) }
  #expect(try await store.load() == .empty)
}
@Test func unknownKeysSurvive() async throws {                            // Foco da revisão 2
  let doc = Data(#"{"settings":{},"chaveDoFuturo":{"x":[1,2]}}"#.utf8)
  try await store.save(doc); #expect(try await store.load() == .current(doc))
}
@Test func aHalfEmojiIsSavedAndReadAsIs() async throws {                    // Foco da revisão 2
  let doc = Data(#"{"dayNotes":{"2026-10-31":{"text":"\ud83d"}},"x":"\ude00"}"#.utf8)
  try await store.save(doc); #expect(read("state.json") == doc); #expect(try await store.load() == .current(doc))
}
@Test func aDocumentThatCannotBeReadNowThrowsAndTouchesNothing() async throws {   // Foco da revisão 1
  try await store.save(a); try await store.save(b); lock("state.json")
  await #expect(throws: DocumentStoreError.unreadable) { try await store.load() }
  await #expect(throws: DocumentStoreError.unreadable) { try await store.save(c) }
  unlock("state.json"); #expect(read("state.json") == b); #expect(read("state.previous.json") == a)
  #expect(!exists("state.unreadable.json"))
}
@Test func syncBaseRoundTrips() async throws {
  try await store.saveSyncBase(SyncBase(rev: 7, ts: 1_730_000_000_000, wid: "w1"))
  #expect(try await store.syncBase() == SyncBase(rev: 7, ts: 1_730_000_000_000, wid: "w1"))
}
@Test func missingAppGroupThrows() {
  #expect(throws: DocumentStoreError.appGroupUnavailable("group.app.hexgym")) {
    try DocumentStore.appGroupDirectory(lookup: { _ in nil })
  }
}
```

`a`, `b` e `c` são três documentos JSON pequenos e diferentes; `read` e `write` leem e gravam direto no diretório temporário, `lock` e `unlock` põem as permissões do arquivo em `0o000` e em `0o644`, e `exists` diz se o arquivo está lá.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) swift test --package-path apple/Packages/HexStore`
Expected: FAIL, `cannot find 'DocumentStore' in scope`.

- [ ] **Step 3: Implement `DocumentStore`**

O documento é opaco: o pacote só confere que é um objeto JSON e guarda os bytes como vieram.
- "Válido" quer dizer que o `JSON.parse` leria o arquivo como um objeto: o `JSONSerialization` aceita o arquivo, ou aceita uma cópia em que cada escape de surrogate sem par (um `\ud800` a `\udbff` sem um `\udc00` a `\udfff` logo depois, ou um destes sem aquele antes) virou `�`. O `JSONSerialization` recusa os dois tipos de surrogate sozinho, e o `JSON.stringify` grava os dois (conferido nesta máquina em 31/10/2026). A troca serve só para conferir: os bytes gravados e devolvidos são sempre os originais.
- "Falta" quer dizer só o erro `NSFileReadNoSuchFileError`. Qualquer outro erro de leitura (permissão, disco, um aparelho que ligou e ainda não foi desbloqueado) lança `.unreadable` sem mexer em nada, no `load` e no `save`.
- `save` confere o documento novo (um inválido lança `.notAnObject`), depois copia o `state.json` atual para `state.previous.json`, e só se ele for válido, e por fim grava o novo `state.json`. As duas gravações usam `Data.write(to:options: .atomic)`.

`load`, nesta ordem:

| `state.json` | `state.previous.json` | O que faz |
|---|---|---|
| válido | não é lido | `.current(state.json)` |
| falta, ou existe e é ruim | válido | move o `state.json` ruim, se existir, para `state.unreadable.json` e devolve `.recovered(previous)` |
| falta | falta | `.empty` |
| os outros casos, inclusive um erro de leitura em qualquer dos dois | | lança `.unreadable` sem mexer em nada |

A recuperação e o erro vão para o `Logger(subsystem: "app.hexgym", category: "dados")`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: o comando do passo 2
Expected: PASS, 14 testes.

- [ ] **Step 5: Add HexStore to the `packages` check**

Em `PARTS.packages`, depois do HexEngine: `{ name: 'HexStore', cmd: 'swift', args: ['test', '--package-path', 'apple/Packages/HexStore'], env: () => ({ DEVELOPER_DIR: developerDir() }) }`. Como diz a Task 1, a checagem nova precisa mostrar ao `check.mjs` quantos testes rodou, para a conta da parte `packages` incluir os testes do HexStore.

Run: `node scripts/hexgym/check.mjs packages`
Expected: `ok`.

- [ ] **Step 6: Commit**

```bash
git add apple/Packages/HexStore scripts/hexgym/check.mjs
git commit -m "HexStore: o documento de dados no App Group, com cópia anterior"
```

---

### Task 9: O projeto Xcode com os quatro alvos

**Issue:** #21.

**Files:**
- Create: `apple/HexGym.xcodeproj/project.pbxproj`
- Create: `apple/HexGym.xcodeproj/xcshareddata/xcschemes/HexGym.xcscheme`, `HexGymWatch.xcscheme`
- Create: `apple/Shared/Wordmark.swift`
- Create: `apple/HexGym/HexGymApp.swift`, `apple/HexGym/ContentView.swift`, `apple/HexGym/Assets.xcassets`
- Create: `apple/HexGymWidgets/HexGymWidgets.swift`
- Create: `apple/HexGymWatch/HexGymWatchApp.swift`, `apple/HexGymWatch/Assets.xcassets`
- Create: `apple/HexGymWatchWidgets/HexGymWatchWidgets.swift`
- Create: `apple/HexGymTests/SmokeTests.swift`
- Create: `apple/Config/HexGym-Info.plist`, `HexGymWidgets-Info.plist`, `HexGymWatchWidgets-Info.plist`
- Create: `apple/Config/HexGym.entitlements`, `HexGymWidgets.entitlements`, `HexGymWatch.entitlements`, `HexGymWatchWidgets.entitlements`
- Create: `scripts/hexgym/placeholder-icon.swift`
- Create: `scripts/hexgym/project-format.test.mjs`
- Create: `docs/hexgym/prints/<issue>/` (os prints do PR)
- Modify: `scripts/hexgym/check.mjs`, `scripts/hexgym/check.test.mjs` (parte `app`)

**Interfaces:**
- Consumes: os produtos `HexEngine` (Task 7) e `HexStore` (Task 8), ligados só ao alvo `HexGym`. O `HexGymTests`, hospedado no app, importa os dois pelo app: duas cópias estáticas no mesmo processo fariam dois tipos `HexEngine`.
- Produces: os esquemas `HexGym` (compila o app com o Watch e os widgets embutidos e roda o `HexGymTests`) e `HexGymWatch`; a view `Wordmark()`; a parte `app` do `check.mjs`.

As decisões do projeto, que o arquivo precisa seguir:

- **Formato:** `objectVersion = 77`, `preferredProjectObjectVersion = 77`, `LastUpgradeCheck = 2700`, `developmentRegion = en`, `knownRegions = (en, Base, "pt-BR")`.
- **Pastas sincronizadas** (`PBXFileSystemSynchronizedRootGroup`): `HexGym`, `HexGymWidgets`, `HexGymWatch`, `HexGymWatchWidgets` e `HexGymTests`, cada uma no seu alvo; `Shared` entra nos quatro alvos do app. `Config/` não é sincronizada: os Info.plist e os entitlements são citados só pelos ajustes `INFOPLIST_FILE` e `CODE_SIGN_ENTITLEMENTS`.
- **Pacotes:** `XCLocalSwiftPackageReference` com `relativePath = Packages/HexEngine` e `Packages/HexStore`.
- **Alvos:**

| Alvo | Tipo | Bundle ID | Plataforma | Embutido em |
|---|---|---|---|---|
| `HexGym` | `com.apple.product-type.application` | `app.hexgym` | iphoneos | |
| `HexGymWidgets` | `com.apple.product-type.app-extension` | `app.hexgym.widgets` | iphoneos | `HexGym`, fase "Embed Foundation Extensions" (`dstSubfolderSpec = 13`) |
| `HexGymWatch` | `com.apple.product-type.application` | `app.hexgym.watchkitapp` | watchos, `TARGETED_DEVICE_FAMILY = 4` | `HexGym`, fase "Embed Watch Content" (`dstSubfolderSpec = 16`, `dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"`) |
| `HexGymWatchWidgets` | `com.apple.product-type.app-extension` | `app.hexgym.watchkitapp.widgets` | watchos | `HexGymWatch`, "Embed Foundation Extensions" (`13`) |
| `HexGymTests` | `com.apple.product-type.bundle.unit-test` | `app.hexgym.tests` | iphoneos | hospedado no `HexGym` (`TEST_HOST`, `BUNDLE_LOADER`) |

- **Ajustes comuns:** `DEVELOPMENT_TEAM = MPAGLMK4Q2`, `CODE_SIGN_STYLE = Automatic`, `SWIFT_VERSION = 6.0`, `MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 1`, `GENERATE_INFOPLIST_FILE = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`. Nos embutidos, `SKIP_INSTALL = YES`. No app e no Watch, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` e `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` (sem ele, o ícone fica fora do pacote e do Info.plist, e o App Store Connect recusa o envio). Nos alvos do iPhone, `IPHONEOS_DEPLOYMENT_TARGET = 26.0` e `TARGETED_DEVICE_FAMILY = 1`; nos do Watch, `WATCHOS_DEPLOYMENT_TARGET = 26.0` e `TARGETED_DEVICE_FAMILY = 4`.
- **Info do app:** `INFOPLIST_KEY_CFBundleDisplayName = HexGym`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, `INFOPLIST_KEY_UIUserInterfaceStyle = Dark` (só escuro no primeiro TestFlight, seção 11), `INFOPLIST_KEY_UILaunchScreen_Generation = YES`. `Config/HexGym-Info.plist` só traz o `CFBundleURLTypes` com o esquema `hexgym`.
- **Info do Watch:** `INFOPLIST_KEY_WKCompanionAppBundleIdentifier = app.hexgym`, `INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp = NO` (a fase 4 revê). O `WKApplication` o Xcode põe sozinho.
- **Info dos widgets:** os dois Info.plist de `Config/` só trazem `NSExtension` → `NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
- **Entitlements:** os quatro só com `com.apple.security.application-groups = [group.app.hexgym]`.
- **Ícone provisório:** `scripts/hexgym/placeholder-icon.swift` desenha, com `ImageRenderer` do SwiftUI, um PNG de 1024 × 1024 sem canal alfa (o App Store Connect recusa ícone com transparência): a imagem do `ImageRenderer` é redesenhada num `CGContext` sem alfa (`CGImageAlphaInfo.noneSkipLast`) antes de virar PNG. Fundo preto e `HEX` branco, peso heavy, largura condensada, centralizado. Vai como ícone de tamanho único no `AppIcon` do app e do Watch. O ícone de verdade é decisão do founder, na fase 1.
- **As telas provisórias:** `Wordmark()` é `HEX` em peso heavy e largura condensada seguido de `gym` em peso thin, branco, com `accessibilityLabel("HexGym")`. O app e o Watch mostram o `Wordmark` centralizado em fundo preto. Cada pacote de widgets tem um widget, `kind` `HexGymWordmark`: no iPhone, `.systemSmall`; no Watch, `.accessoryRectangular`; os dois com `containerBackground(.black, for: .widget)`.

- [ ] **Step 1: Write the failing format test**

Em `scripts/hexgym/project-format.test.mjs`, lendo `apple/HexGym.xcodeproj/project.pbxproj` e os quatro entitlements:

```js
test('the project stays in the Xcode 16.0 format', () => {
  assert.match(pbx, /objectVersion = 77;/); assert.match(pbx, /preferredProjectObjectVersion = 77;/)
})
test('the four bundle IDs and the team are set', () => {
  for (const id of ['app.hexgym', 'app.hexgym.widgets', 'app.hexgym.watchkitapp', 'app.hexgym.watchkitapp.widgets'])
    assert.match(pbx, new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${id.replaceAll('.', '\\.')};`))
  assert.match(pbx, /DEVELOPMENT_TEAM = MPAGLMK4Q2;/); assert.doesNotMatch(pbx, /DEVELOPMENT_TEAM = (?!MPAGLMK4Q2;)/)
})
test('the deployment targets are 26.0', () => {
  assert.match(pbx, /IPHONEOS_DEPLOYMENT_TARGET = 26\.0;/); assert.match(pbx, /WATCHOS_DEPLOYMENT_TARGET = 26\.0;/)
  assert.doesNotMatch(pbx, /(IPHONEOS|WATCHOS)_DEPLOYMENT_TARGET = (?!26\.0;)/)
})
test('the app icon and the device families are set', () => {
  assert.ok(pbx.match(/ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/g)?.length >= 4)   // Debug e Release do app e do Watch
  assert.match(pbx, /TARGETED_DEVICE_FAMILY = 1;/); assert.match(pbx, /TARGETED_DEVICE_FAMILY = 4;/)
})
test('every target has the app group', () => {
  for (const f of entitlements) assert.match(f, /<string>group\.app\.hexgym<\/string>/)
})
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test scripts/hexgym/project-format.test.mjs`
Expected: FAIL, `ENOENT` no `project.pbxproj`.

- [ ] **Step 3: Write the project, the sources and the icon**

Seguindo as decisões acima. Os identificadores do pbxproj são 24 dígitos hexadecimais, únicos no arquivo. Rodar `swift scripts/hexgym/placeholder-icon.swift apple/HexGym/Assets.xcassets/AppIcon.appiconset/AppIcon.png` e copiar o PNG para o `AppIcon` do Watch.

Run: `sips -g hasAlpha apple/HexGym/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
Expected: `hasAlpha: no`.

- [ ] **Step 4: Add the `app` part to `check.mjs`**

`PARTS.app`, com `env: () => ({ DEVELOPER_DIR: developerDir() })`:
1. `xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination "generic/platform=iOS Simulator" -derivedDataPath apple/DerivedData CODE_SIGNING_ALLOWED=NO build`
2. `xcodebuild -project apple/HexGym.xcodeproj -scheme HexGymWatch -destination "generic/platform=watchOS Simulator" -derivedDataPath apple/DerivedData CODE_SIGNING_ALLOWED=NO build`

Como diz a Task 1, uma checagem que roda testes precisa mostrar ao `check.mjs` quantos rodou, e os dois builds não rodam nenhum: sem uma checagem assim, a parte `app` conta zero e falha. Atualizar a mensagem esperada do teste "unknown part" com as partes que existem.

- [ ] **Step 5: Run the checks**

Run: `node scripts/hexgym/check.mjs scripts app`
Expected: os testes de formato passam e os dois builds terminam com `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify the embedding and the Info.plist**

Run: `find apple/DerivedData/Build/Products/Debug-iphonesimulator/HexGym.app -maxdepth 3 \( -name '*.appex' -o -name '*.app' \)` e `plutil -extract WKCompanionAppBundleIdentifier raw apple/DerivedData/Build/Products/Debug-iphonesimulator/HexGym.app/Watch/HexGymWatch.app/Info.plist`
Expected: `PlugIns/HexGymWidgets.appex`, `Watch/HexGymWatch.app` e, dentro dele, `PlugIns/HexGymWatchWidgets.appex`; e `app.hexgym`.

- [ ] **Step 7: See it run**

O build da checagem é sem assinatura (`CODE_SIGNING_ALLOWED=NO`), e um app sem assinatura não leva os entitlements: para ver rodando, compilar assinado, para um simulador de iPhone com o sistema 26 ou mais novo (`xcrun simctl list devices available`), com a assinatura local que o Xcode faz para simulador: `xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination id=<udid> -derivedDataPath apple/DerivedData build`, e o mesmo com `-scheme HexGymWatch` para um simulador de Apple Watch. Instalar os dois com `xcrun simctl install`.

Run: `xcrun simctl get_app_container <udid> app.hexgym group.app.hexgym`
Expected: a pasta do App Group no simulador, a prova de que o entitlement chegou.

Depois, `xcrun simctl launch` nos dois e print das duas telas com `xcrun simctl io <udid> screenshot`. Os prints vão no PR, em "Para o founder ver", como dizem as Restrições globais.

- [ ] **Step 8: Commit**

```bash
git add apple/HexGym.xcodeproj apple/Shared apple/HexGym apple/HexGymWidgets apple/HexGymWatch apple/HexGymWatchWidgets apple/HexGymTests apple/Config scripts/hexgym docs/hexgym/prints
git commit -m "Projeto Xcode do HexGym com os quatro alvos e o ícone provisório"
```

---

### Task 10: O app abre com o motor e os dados

**Issue:** #22.

**Files:**
- Create: `apple/HexGym/AppModel.swift`
- Modify: `apple/HexGym/HexGymApp.swift`, `apple/HexGym/ContentView.swift`
- Create: `apple/HexGym/Localizable.xcstrings`
- Create: `apple/HexGymTests/AppModelTests.swift` (e remove o `SmokeTests.swift`)
- Create: `docs/hexgym/prints/<issue>/` (os prints do PR)
- Modify: `scripts/hexgym/xcode.mjs`, `scripts/hexgym/xcode.test.mjs`, `scripts/hexgym/check.mjs`

**Interfaces:**
- Consumes: `HexEngine` (Task 7): `init(language:)`, `load() -> EngineInfo`, `freshDocument() -> Data` e `restore(_:)`; `DocumentStore` (Task 8): `appGroupDirectory()`, `load() -> StoredDocument` e `save(_:)`.
- Produces:

```swift
@Observable @MainActor final class AppModel {
  enum State: Equatable { case starting, ready(Status), failed(String) }   // em failed, o detalhe, para o log e os testes
  struct Status: Equatable { var exercises: Int; var origin: Origin }
  enum Origin: Equatable { case created, opened, recovered }
  private(set) var state: State
  init(engine: HexEngine, store: DocumentStore?)   // nil: o App Group não abriu
  func start() async
  static func live() -> AppModel
}
```

- `scripts/hexgym/xcode.mjs` ganha `pickSimulator(simctlJSON, family = 'iPhone') → udid`: o primeiro aparelho disponível com o nome começando por `family`, no iOS mais novo que for 26 ou acima.

`start()`: sem `store`, vira `.failed` na hora, sem carregar o motor nem gravar nada. Com `store`: `engine.load()`; depois `store.load()`. Com `.empty`, `freshDocument()` e `save` do que ele devolveu, origem `.created`. Com `.current`, `restore`, origem `.opened`, e nada é gravado. Com `.recovered`, `restore` e depois `save` dos mesmos bytes recuperados, para o próximo início abrir normal, origem `.recovered`. O documento novo não leva horário: um carimbo de agora ganharia, numa sincronização futura, de um documento de verdade do servidor. Qualquer erro vira `.failed(<descrição do erro>)` e vai para o `Logger(subsystem: "app.hexgym", category: "app")`, e depois de um erro nada é gravado. `live()` tenta `DocumentStore(directory: DocumentStore.appGroupDirectory())` e, se falhar, passa `nil`: nunca inventa outra pasta, porque o documento iria para um lugar que o Watch e os widgets não veem, ou que o sistema limpa.

A tela mostra o `Wordmark` e, embaixo, uma linha por estado:

| Estado | pt-BR | en |
|---|---|---|
| `.starting` | Abrindo… | Opening… |
| `.ready`, sempre | Motor carregado · %lld exercícios | Engine loaded · %lld exercises |
| `.created` | Documento criado | Document created |
| `.opened` | Documento aberto | Document opened |
| `.recovered` | Documento recuperado da cópia anterior | Document restored from the previous copy |
| `.failed` | Não deu para abrir os seus dados. | Couldn't open your data. |

O detalhe do erro vai para o log, nunca para a tela.

- [ ] **Step 1: Write the failing tests**

Em `apple/HexGymTests/AppModelTests.swift`, dentro de `@Suite @MainActor struct AppModelTests` (o alvo de teste não tem o ator principal como padrão, e o `AppModel` é `@MainActor`), cada teste com um `DocumentStore` num diretório temporário, e `read` e `write` como na Task 8:

```swift
@Test func firstRunCreatesAndSavesADocument() async throws {
  let model = AppModel(engine: HexEngine(), store: store); await model.start()
  guard case .ready(let s) = model.state else { Issue.record("\(model.state)"); return }
  #expect(s.origin == .created); #expect(s.exercises > 5000)
  #expect(try JSONSerialization.jsonObject(with: read("state.json")) is [String: Any])
}
@Test func secondRunOpensWithoutWriting() async throws {
  await AppModel(engine: HexEngine(), store: store).start(); let before = read("state.json")
  let model = AppModel(engine: HexEngine(), store: store); await model.start()
  #expect(model.state.origin == .opened); #expect(read("state.json") == before)
}
@Test func bothCopiesBrokenFailsWithoutWriting() async throws {          // Foco da revisão 1
  write("state.json", Data("{".utf8)); write("state.previous.json", Data("x".utf8))
  let model = AppModel(engine: HexEngine(), store: store); await model.start()
  guard case .failed = model.state else { Issue.record("\(model.state)"); return }
  #expect(read("state.json") == Data("{".utf8))
}
@Test func recoveredDocumentIsRestoredAndSaved() async throws {          // Foco da revisão 1
  await AppModel(engine: HexEngine(), store: store).start(); let good = read("state.json")
  try await store.save(good)                                   // deixa a cópia anterior
  write("state.json", Data("{".utf8))
  let model = AppModel(engine: HexEngine(), store: store); await model.start()
  #expect(model.state.origin == .recovered); #expect(read("state.json") == good)
  #expect(read("state.unreadable.json") == Data("{".utf8))
}
@Test func missingAppGroupFailsWithoutWriting() async {
  let model = AppModel(engine: HexEngine(), store: nil); await model.start()
  guard case .failed = model.state else { Issue.record("\(model.state)"); return }
}
```

(`state.origin` é um atalho de teste, numa extensão dentro do `AppModelTests.swift`.)

- [ ] **Step 2: Write the failing test for `pickSimulator`**

Em `scripts/hexgym/xcode.test.mjs`, com um JSON no formato de `xcrun simctl list devices available --json` que tem um iPhone 17 no iOS 26.4, um iPhone 17 Pro no iOS 27.0 e um iPad no iOS 27.0: `pickSimulator(json)` devolve o udid do iPhone 17 Pro; sem nenhum iPhone 26 ou acima, lança `Error` com `nenhum simulador de iPhone com iOS 26 ou mais novo`.

- [ ] **Step 3: Run them to verify they fail**

Run: `node --test scripts/hexgym/xcode.test.mjs` e `DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination id=<udid> -derivedDataPath apple/DerivedData test`
Expected: FAIL, `pickSimulator is not a function` e `cannot find 'AppModel' in scope`.

- [ ] **Step 4: Implement `AppModel`, the screen, the strings and `pickSimulator`**

`HexGymApp` cria o `AppModel.live()` e chama `start()` num `.task` da janela. As chamadas ao motor e ao armazenamento ficam nos atores, fora da thread principal.

- [ ] **Step 5: Add the test run to the `app` part**

Terceira checagem de `PARTS.app`: `xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination id=<udid> -derivedDataPath apple/DerivedData test`, com `args` como função que acha o `udid` com `pickSimulator` na hora de rodar, sobre a saída de `xcrun simctl list devices available --json` no mesmo `DEVELOPER_DIR`. Como diz a Task 1, essa checagem precisa mostrar ao `check.mjs` quantos testes rodou, senão a parte `app`, em que só ela roda testes, conta zero e falha.

- [ ] **Step 6: Run the checks**

Run: `node scripts/hexgym/check.mjs scripts app`
Expected: `ok`, com os cinco testes do `AppModelTests` passando.

- [ ] **Step 7: See it run**

Compilar assinado e instalar no simulador do iPhone, como no passo 7 da Task 9. Os testes hospedados já abriram o app, então antes do primeiro print apagar os `state*.json` da pasta que `xcrun simctl get_app_container <udid> app.hexgym group.app.hexgym` devolve. Abrir o app e tirar print com "Documento criado"; fechar, abrir de novo e tirar print com "Documento aberto". Os dois prints vão no PR, como dizem as Restrições globais.

- [ ] **Step 8: Commit**

```bash
git add apple/HexGym apple/HexGymTests scripts/hexgym docs/hexgym/prints
git commit -m "O app abre com o motor e o documento de dados"
```

---

### Task 11: A CI do HexGym

**Issue:** #9.

**Files:**
- Create: `.github/workflows/hexgym.yml`

**Interfaces:**
- Consumes: as partes `scripts`, `engine`, `load`, `packages` e `app` do `check.mjs` (Tasks 1, 5 a 10).
- Produces: o check `hexgym-ok`, que vira obrigatório em `main` e `develop` depois do merge.

O workflow, com os mesmos pins de ação do `test.yml` e do `ios.yml`:

- `name: HexGym`; `on`: `pull_request`, `push` em `[main, develop]` e `workflow_dispatch`; `permissions: contents: read`; `concurrency` com `group: hexgym-${{ github.ref }}` e `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`.
- Todo `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` leva `persist-credentials: false`: nenhum job usa o token depois do checkout.
- `changes` (`ubuntu-latest`, com `permissions` `contents: read` e `pull-requests: read`, que o filtro usa para listar os arquivos do PR): checkout e `dorny/paths-filter@ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d # v4.0.3` com `id: f`, `base: ${{ github.event_name == 'push' && github.ref_name || '' }}` e três filtros. Cada saída do job é `${{ steps.f.outputs.<filtro> == 'true' || github.event_name == 'workflow_dispatch' }}`, para o disparo à mão rodar tudo:
  - `scripts`: `scripts/hexgym/**`, `apple/HexGym.xcodeproj/**`, `apple/Config/**`, `frontend/src/lib/**`, `.github/workflows/hexgym.yml` (os testes dos scripts também leem o projeto, os entitlements e o `lib`)
  - `engine`: `frontend/src/lib/**`, `api/coach/core/**`, `frontend/package.json`, `frontend/package-lock.json`, `frontend/vitest.hexengine.config.js`, `scripts/build-hexgym-engine.mjs`, `scripts/hexgym/**`, `apple/Packages/HexEngine/**`, `.github/workflows/hexgym.yml`
  - `apple`: `apple/**`, `scripts/hexgym/**`, `.github/workflows/hexgym.yml`
- `scripts` (`ubuntu-latest`, se `scripts`): checkout, `actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0` com Node 22, `node scripts/hexgym/check.mjs scripts`.
- `engine` (`ubuntu-latest`, se `engine`): checkout, setup-node com cache de npm em `frontend/package-lock.json`, `npm ci` em `frontend/`, `node scripts/hexgym/check.mjs engine`.
- `packages` (`runs-on: xcode-27`, se `engine` ou `apple`): checkout, setup-node, `node scripts/hexgym/check.mjs load packages`, com `HEXGYM_LOAD_SLACK: 2` no `env` (Task 6).
- `app` (`runs-on: xcode-27`, se `apple`): checkout, setup-node, `xcodebuild -showsdks | grep -q watchsimulator || xcodebuild -downloadPlatform watchOS`, `node scripts/hexgym/check.mjs app`.
- `hexgym-ok` (`ubuntu-latest`, `needs: [changes, scripts, engine, packages, app]`, `if: always()`): o mesmo passo do `tests-ok` do `test.yml`, que passa quando cada job deu `success` ou `skipped`.
- `timeout-minutes`: 5 no `changes`, `scripts` e `hexgym-ok`; 15 no `engine`; 30 no `packages`; 45 no `app`.
- `xcode-27` é um rótulo de runner hospedado pelo GitHub, disponível para todos desde 15/10/2026 e só em Apple Silicon (changelog do GitHub, "Xcode 27 runner image generally available").

- [ ] **Step 1: Write the workflow**

Seguindo a lista acima. O QA continua rodando o `check.mjs` na worktree, e o portão do merge, depois desta Task, passa a exigir também o `hexgym-ok` com `pass`, pelo nome (nota `2026-11-03-um-orquestrador-so.md`).

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/hexgym.yml
git commit -m "CI do HexGym num workflow próprio, com o resumo hexgym-ok"
```

- [ ] **Step 3: See it pass on this pull request**

Passo do orquestrador antes do merge, depois do `merge-if-ready.sh --dry-run`. As saídas do `wait-ci.sh` seguem o `orchestrator.md`: com a 3, chamar de novo; com a 1, o log do job num comentário na issue e a volta ao implementador, na mesma worktree.

Run: `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr>` e `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket`
Expected: o `wait-ci.sh` sai com 0, e os seis (`changes`, `scripts`, `engine`, `packages`, `app` e `hexgym-ok`) estão em `pass` (o PR mexe em `.github/workflows/hexgym.yml`, então os filtros ligam tudo).

- [ ] **Step 4: After the merge, require `hexgym-ok`**

Só com a opção 1 na última resposta a um pedido da #3 com as opções da proteção (passo 4 da Task 2), que autoriza esta mudança na proteção; com a 2, os passos 4 e 5 ficam de fora, e o comentário depois do merge diz isso. `gh api -X PATCH repos/lipedesign/HexGym/branches/develop/protection/required_status_checks --input <arquivo>` com `{"strict": false, "checks": [{"context": "tests-ok", "app_id": 15368}, {"context": "hexgym-ok", "app_id": 15368}]}`, e o mesmo em `main` com `"strict": true`.

Run: `gh api repos/lipedesign/HexGym/branches/develop/protection --jq '.required_status_checks.checks'` e o mesmo em `main`
Expected: os dois checks, nas duas branches.

- [ ] **Step 5: After the merge, see it block a broken test**

Numa worktree própria, com a branch `teste/hexgym-ok-vermelho` a partir de `origin/develop` (`git worktree add -b teste/hexgym-ok-vermelho .claude/worktrees/9-hexgym-ok-vermelho origin/develop`): trocar uma asserção de `scripts/hexgym/check.test.mjs` para falhar, um commit, `git push -u origin teste/hexgym-ok-vermelho` e um PR para `develop`, fora do rascunho. Na volta, o que já existe fica: com o PR aberto (`gh pr list -R lipedesign/HexGym --head teste/hexgym-ok-vermelho --state open --json number --jq length` dá `1`), seguir com ele; com ele já fechado (a mesma busca com `--state closed` dá `1`), falta só a limpeza, e o comentário leva os checks lidos desse PR; senão, só o que falta, na worktree que já existe.

Run: `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr>`, de novo enquanto sair com 3 (o `hexgym-ok` só sai depois dos jobs do macOS), `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket` e `gh pr view <pr> -R lipedesign/HexGym --json mergeStateStatus`
Expected: o `wait-ci.sh` sai com 1, o `hexgym-ok` está em `fail`, e `BLOCKED` (sem o check obrigatório, seria `UNSTABLE`). Fechar o PR sem merge e limpar, o que ainda existir: `git worktree remove .claude/worktrees/9-hexgym-ok-vermelho`, `gh pr close <pr> -R lipedesign/HexGym --delete-branch` e `git branch -D teste/hexgym-ok-vermelho`. Apagar a branch de teste é uma parada do relentless, já autorizada pela resposta ao pedido da #3 (passo 11 da Task 1).

---

### Task 12: Xcode 27.2, os IDs e o app no App Store Connect

**Issue:** #23, atribuída a `lipedesign`. **Quem faz:** o founder. Quando a #23 fica pronta, depois da Task 9, o primeiro passo do orquestrador é o pedido de decisão com a lista abaixo: 1. Feito; 2. Feito, menos o registro dos IDs: pode registrar pelo `xcodebuild -allowProvisioningUpdates`. Depois do `/decide 23`, ele só confere, sem ler segredo nenhum. Os itens 1, 3, 4 e 5 não precisam do projeto e podem ser feitos antes.

O que o founder faz, como lista na issue:

1. Instalar o Xcode 27.2 pela App Store do Mac (fica em `/Applications/Xcode.app`) e abrir uma vez, para ele instalar os componentes. O Xcode-beta pode ficar até o orquestrador confirmar.
2. Abrir `apple/HexGym.xcodeproj` no Xcode 27.2. Se ele oferecer "Update to recommended settings" ou converter o projeto, recusar: o formato fica o das Restrições globais. Em cada um dos quatro alvos, na aba Signing & Capabilities, com o time dele, deixar o Xcode registrar o App ID e o App Group `group.app.hexgym` (aparece um botão quando falta registrar). Ou responder com a opção 2 do pedido ("pode registrar"), e o orquestrador tenta no passo 3, pelo `xcodebuild -allowProvisioningUpdates` com a conta do Xcode; se o App Group não ficar associado, volta para ele com outro pedido.
3. No App Store Connect, em Apps, o botão "+" e Novo app: iOS, nome "HexGym", idioma principal Português (Brasil), bundle ID `app.hexgym`, SKU `hexgym`. Se o nome não estiver livre, a escolha é dele.
4. Recomendado: uma chave da API do App Store Connect (Usuários e acesso, Integrações, Chaves da equipe), com a função Admin, que os certificados de distribuição na nuvem pedem. O arquivo `AuthKey_<KEY ID>.p8` vai para `~/.appstoreconnect/private_keys/`, e ele manda ao tech lead só o Key ID e o Issuer ID. Sem a chave, os envios usam a conta do Xcode.
5. No TestFlight, em Testes internos, criar o grupo "Founder" e se pôr nele.
6. Ao terminar, responder `/decide 23 1` (ou `2`) numa sessão do Claude Code neste projeto.

- [ ] **Step 1: Verify Xcode 27.2**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version`
Expected: `Xcode 27.2`.

- [ ] **Step 2: Verify the project survived Xcode 27.2**

Run: `node --test scripts/hexgym/project-format.test.mjs && git status --porcelain apple/`
Expected: PASS e nenhuma mudança no projeto.

- [ ] **Step 3: Verify signing for a device**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination generic/platform=iOS -derivedDataPath apple/DerivedData -allowProvisioningUpdates build`
Expected: `** BUILD SUCCEEDED **`, com os perfis de desenvolvimento dos quatro alvos.

- [ ] **Step 4: Verify the key, when there is one**

Run: `test -f ~/.appstoreconnect/private_keys/AuthKey_<KEY ID>.p8 && echo existe`
Expected: `existe`. Só a existência: o conteúdo nunca é lido nem impresso.

- [ ] **Step 5: Close the issue**

Um comentário na #23 com o que foi conferido (`comment-agent.sh`), `gh issue close 23 -R lipedesign/HexGym` e `"$S/set-state.sh" --repo lipedesign/HexGym --issue 23 --state done`.

---

### Task 13: TestFlight a partir desta máquina

**Issue:** #24.

**Files:**
- Create: `scripts/hexgym/testflight.mjs`, `scripts/hexgym/testflight.test.mjs`
- Create: `apple/ExportOptions.plist`

**Interfaces:**
- Consumes: `developerDir()` de `scripts/hexgym/xcode.mjs` (Task 7).
- Produces: `node scripts/hexgym/testflight.mjs [--dry-run]`; exporta `readAuth(env, exists) → { keyPath, keyId, issuerId } | null`, `buildNumber(now = new Date()) → string` e `uploadCommands({ developerDir, buildNumber, auth }) → [{ cmd, args, env }]`.

`apple/ExportOptions.plist`: `method = app-store-connect`, `destination = upload`, `teamID = MPAGLMK4Q2`, `signingStyle = automatic`, `uploadSymbols = true` e `manageAppVersionAndBuildNumber = false` (o número do build é o do script, não o do Xcode).

Os dois comandos:
1. `xcodebuild archive -project apple/HexGym.xcodeproj -scheme HexGym -configuration Release -destination generic/platform=iOS -archivePath apple/build/HexGym.xcarchive -allowProvisioningUpdates CURRENT_PROJECT_VERSION=<n>`
2. `xcodebuild -exportArchive -archivePath apple/build/HexGym.xcarchive -exportOptionsPlist apple/ExportOptions.plist -exportPath apple/build/export -allowProvisioningUpdates`

Com chave (variáveis `HEXGYM_ASC_KEY_ID` e `HEXGYM_ASC_ISSUER_ID`, e o arquivo `~/.appstoreconnect/private_keys/AuthKey_<id>.p8` existindo), os dois ganham `-authenticationKeyPath <arquivo> -authenticationKeyID <id> -authenticationKeyIssuerID <issuer>`; sem chave, usam a conta do Xcode. O número do build é a data e a hora em UTC, `AAAAMMDD.HHMM` (como `20261031.1507`), e só cresce: o `git rev-list --count` repetiria o número na Task 16, porque a branch de release sai de `develop` sem commit novo. Com a árvore suja, o script para, e um arquivo fora do git conta como mudança: numa pasta sincronizada, um arquivo novo entra no build.

- [ ] **Step 1: Write the failing tests**

```js
test('buildNumber is the UTC date and time, and only grows', () => {
  assert.equal(buildNumber(new Date(Date.UTC(2026, 9, 31, 15, 7))), '20261031.1507')
  assert.equal(buildNumber(new Date(Date.UTC(2026, 10, 1, 0, 5))), '20261101.0005')
})
test('commands without a key use the Xcode account', () => {
  const [archive, exp] = uploadCommands({ developerDir: '/Applications/Xcode.app/Contents/Developer', buildNumber: '20261031.1507', auth: null })
  assert.deepEqual(archive.args, ['archive', '-project', 'apple/HexGym.xcodeproj', '-scheme', 'HexGym', '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-archivePath', 'apple/build/HexGym.xcarchive', '-allowProvisioningUpdates', 'CURRENT_PROJECT_VERSION=20261031.1507'])
  assert.ok(!exp.args.some(a => a.startsWith('-authentication')))
  assert.equal(archive.env.DEVELOPER_DIR, '/Applications/Xcode.app/Contents/Developer')
})
test('commands with a key pass the three flags to both steps', () => {
  const auth = { keyPath: '/k/AuthKey_ABC.p8', keyId: 'ABC', issuerId: 'iss' }
  for (const c of uploadCommands({ developerDir: '/x', buildNumber: '20261031.1507', auth }))
    assert.deepEqual(c.args.slice(-6), ['-authenticationKeyPath', '/k/AuthKey_ABC.p8', '-authenticationKeyID', 'ABC', '-authenticationKeyIssuerID', 'iss'])
})
test('readAuth only checks that the key exists', () => {
  const seen = []
  assert.equal(readAuth({}, p => { seen.push(p); return true }), null)
  const a = readAuth({ HEXGYM_ASC_KEY_ID: 'ABC', HEXGYM_ASC_ISSUER_ID: 'iss', HOME: '/h' }, p => { seen.push(p); return true })
  assert.deepEqual(a, { keyPath: '/h/.appstoreconnect/private_keys/AuthKey_ABC.p8', keyId: 'ABC', issuerId: 'iss' })
  assert.equal(readAuth({ HEXGYM_ASC_KEY_ID: 'ABC', HEXGYM_ASC_ISSUER_ID: 'iss', HOME: '/h' }, () => false), null)
})
test('a dirty tree stops the script, untracked files too', async () => {
  for (const status of [' M x\n', '?? apple/HexGym/Novo.swift\n']) {
    const r = await run(['--dry-run'], { git: args => args[0] === 'status' ? status : '' })
    assert.equal(r.code, 2); assert.match(r.stderr, /a árvore tem mudanças/)
  }
})
```

`readAuth` recebe só uma função `exists`: o script nunca lê o arquivo da chave.

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test scripts/hexgym/testflight.test.mjs`
Expected: FAIL, `Cannot find module`.

- [ ] **Step 3: Implement `testflight.mjs` and `ExportOptions.plist`**

`--dry-run` imprime os dois comandos e não roda nada. `apple/build/` já está no `apple/.gitignore` (Task 7).

- [ ] **Step 4: Run them to verify they pass**

Run: `node scripts/hexgym/check.mjs scripts`
Expected: `ok`.

- [ ] **Step 5: Commit**

```bash
git add scripts/hexgym/testflight.mjs scripts/hexgym/testflight.test.mjs apple/ExportOptions.plist
git commit -m "TestFlight a partir desta máquina, com a chave da API ou a conta do Xcode"
```

Os passos 6 a 8 são do orquestrador antes do merge, depois dos portões (o `merge-if-ready.sh --dry-run` e os checks pelo nome, nota `2026-11-03-um-orquestrador-so.md`): com a revisão aprovada no commit atual, na worktree da Task, onde a árvore está limpa (o script só roda assim). O passo 6 sai uma vez só na issue, porque a parada é o primeiro envio; quando um commit novo passa de novo pelo QA e pela revisão, os passos 7 e 8 rodam outra vez, e o número do build, que é a data e a hora, já é outro.

- [ ] **Step 6: Ask the founder before the first upload**

Parada da seção 9.1 (loja): um pedido de decisão na #24, com a saída do `node scripts/hexgym/testflight.mjs --dry-run` e uma opção só, 1. Pode mandar. Enquanto ele não responde, o orquestrador segue em outras issues; depois do `/decide 24 1`, a Task volta no passo 7.

- [ ] **Step 7: Upload**

Run: `node scripts/hexgym/testflight.mjs`
Expected: o export termina com `** EXPORT SUCCEEDED **` e o build aparece no TestFlight do app em alguns minutos.

- [ ] **Step 8: The founder opens it on his iPhone**

Um segundo pedido na #24: o founder instala pelo app TestFlight, do grupo "Founder", e responde se o HexGym abriu com a linha "Documento criado". 1. Abriu; 2. Não abriu (o que apareceu, na nota do `/decide`). É o "o app abre no iPhone dele" da seção 9. Com a 2, o PR não entra, e o orquestrador investiga pela nota: com a causa no código, volta ao implementador, na mesma worktree; com uma causa fora do código (o envio, a assinatura, o TestFlight), comenta a causa e refaz os passos 7 e 8 no mesmo commit, com um envio novo e um pedido novo; sem causa achada, um pedido de decisão com o que viu, que não conta como este passo, com duas opções: 1. Refazer os passos 7 e 8 no mesmo commit, com um envio novo; 2. Voltar às correções (o que mudar, na nota do `/decide`). A Task segue pela opção que veio. O PR só entra com um "Abriu" a um pedido deste passo no commit atual.

---

### Task 14: O README, o CONTRIBUTING e o SECURITY do fork

**Issue:** #8.

**Files:**
- Modify: `.github/README.md` (a versão curta entrou antes, pela #32)
- Create: `.github/CONTRIBUTING.md`, `.github/SECURITY.md`

Em português, simples, sem travessão:

- **README:** a versão curta entrou pela #32 e já diz o que é o HexGym (o app nativo de academia para iPhone e Apple Watch), que é um fork do openGym, com link para `https://github.com/DuarteSantos8/openGym`, com o mesmo motor e os mesmos dados; a licença AGPL-3.0 e o `NOTICE.md`, com a exceção das lojas de apps; a regra das mídias de exercício da seção 5; o estado (fase 0) e o link para o documento de design. Esta tarefa acrescenta como compilar (Xcode 27.2, `node scripts/hexgym/check.mjs`) e o link para o quadro, avisando que o quadro é privado, e atualiza o estado. Não chama "HexGym" de marca registrada: a pesquisa no INPI e no USPTO está pendente (seção 11).
- **CONTRIBUTING:** o caminho de uma issue até o merge (seção 9.1), o Git Flow, o checklist do PR e o relentless, que orquestra o trabalho dos agentes.
- **SECURITY:** como avisar de uma falha sem abrir issue pública, pelo "Report a vulnerability" da aba Security. Ligar esse relato privado é uma configuração do repositório: o ok vem no mesmo pedido do texto (passo 4), e o orquestrador liga depois do merge (passo 5).

- [ ] **Step 1: Finish the README and write the other two files**

- [ ] **Step 2: Commit**

```bash
git add .github/README.md .github/CONTRIBUTING.md .github/SECURITY.md
git commit -m "README, CONTRIBUTING e SECURITY do HexGym em .github/"
```

- [ ] **Step 3: Verify that no root file changed**

Run: `git diff --stat origin/develop...HEAD -- README.md CONTRIBUTING.md SECURITY.md`
Expected: vazio.

- [ ] **Step 4: Founder review**

Passo do orquestrador antes do merge, depois dos portões, com a revisão aprovada no commit atual: o founder lê o texto que vai entrar. Parada da seção 9.1: o texto é a página de entrada do projeto. Um pedido de decisão na #8, com o link dos três arquivos nesse commit: 1. Aprovar o texto e ligar o relato privado de falhas (recomendada); 2. Aprovar o texto sem ligar o relato; 3. Mudar o texto (o que mudar, na nota do `/decide`). Enquanto ele não responde, o orquestrador segue em outras issues; com a opção 3, as mudanças voltam ao implementador, na mesma worktree, o QA e a revisão rodam de novo, e este passo sai outra vez, com um pedido para o commit novo.

- [ ] **Step 5: After the merge, turn on private reporting**

Só com a opção 1: `gh api -X PUT repos/lipedesign/HexGym/private-vulnerability-reporting`.

Run: `gh api repos/lipedesign/HexGym/private-vulnerability-reporting --jq .enabled`
Expected: `true` com a opção 1, e `false` com a 2.

- [ ] **Step 6: After the merge, verify what GitHub shows**

Run: `gh api repos/lipedesign/HexGym/community/profile --jq '.files.readme.html_url, .files.contributing.html_url'` e abrir `https://github.com/lipedesign/HexGym/security/policy`
Expected: as duas URLs em `.github/`, e a política do HexGym na aba Security. Se o GitHub mostrar o `SECURITY.md` da raiz, registrar no comentário deste passo e abrir uma issue da fase (sub-issue do épico, com a linha `Origem:`) com o pedido de decisão ao founder sobre mudar o da raiz: a #8 já fechou com o merge.

---

### Task 15: A cópia dos arquivos do corpo e a procedência da referência

**Issue:** #10. Espera duas respostas do founder: onde guardar, e como a imagem `ref/referencia-corpo.jpg` foi feita (desenho, IA ou foto, e de quem). A recomendação do tech lead é um repositório privado na conta lipedesign, fora da rede de forks do openGym. As duas vêm no pedido de decisão da Task 1: a opção diz onde, e a nota do `/decide 10 <opção> <procedência>` diz como a imagem foi feita.

**Files:**
- Modify: `scripts/hexbody/README.md`

- [ ] **Step 1: Get the two answers**

A issue só fica pronta depois do `/decide 10`, e as duas respostas estão no comentário do `/decide` na issue (com `relentless:decision option=`), que o orquestrador passa ao implementador junto com o critério de aceite. Se a nota não disser como a imagem foi feita, o implementador para e reporta, e o orquestrador pergunta de novo, com outro pedido.

- [ ] **Step 2: Make the copy**

A pasta `scripts/hexbody/work/` fica fora do git e só existe no checkout principal (`/Users/lipe/Developer/MyGym/scripts/hexbody/work/`), não na worktree. No repositório privado: `gh repo create lipedesign/hexgym-corpo --private --description "Arquivos de origem do corpo do HexGym"` (criar repositório na conta dele é a resposta do passo 1 que autoriza). Se algum arquivo de `scripts/hexbody/work/` passar de 100 MB, o limite do GitHub, esses vão por Git LFS. Num iCloud Drive ou Google Drive, quem copia é o founder, ou o orquestrador numa pasta que ele indicar.

- [ ] **Step 3: Write it down**

No `scripts/hexbody/README.md`: onde a cópia fica, como trazer de volta para `scripts/hexbody/work/` e como a imagem de referência foi feita.

- [ ] **Step 4: Verify the restore**

Trazer a cópia para uma pasta limpa e rodar os passos 5 a 7 do README do hexbody.
Expected: as mesmas saídas (mesmo hash) que as de `scripts/hexbody/work/`.

- [ ] **Step 5: Commit**

```bash
git add scripts/hexbody/README.md
git commit -m "Onde ficam os arquivos de origem do corpo e de onde vem a referência"
```

---

### Task 16: A versão 0.1.0

**Issue:** #25. Depende de todas as outras, menos a 15 (o passo 1 decide a #10), e de cada acompanhamento que entrar na fase (nota `2026-11-03-um-orquestrador-so.md`). É a Task da versão: o orquestrador faz os passos dela na ordem, com um comentário na issue por passo, e retoma pelo último comentado (a mesma nota); ela não é uma feature.

- [ ] **Step 1: Check that the phase is done**

Run: `gh issue list -R lipedesign/HexGym --milestone "Fase 0: Fundação" --state open`
Expected: só esta issue e o épico da fase. Qualquer outra issue aberta (a #10, se ainda esperar o `/decide 10`, ou uma que ficou fora da linha `Depende de:` desta) sai do épico (`gh api -X DELETE repos/lipedesign/HexGym/issues/<épico>/sub_issue -F sub_issue_id=$(gh api repos/lipedesign/HexGym/issues/<n> --jq .id)`) e passa para o milestone "Fase 1: Design system", com a etiqueta `orphan:ok` até o épico da fase 1 a adotar e um comentário dizendo por quê. A lista delas vai no PR da versão (passo 6) e no pedido do passo 7.

- [ ] **Step 2: Cut the release branch**

Na primeira vez, `git worktree add .claude/worktrees/release-0.1.0 -b release/0.1.0 origin/develop`. Na volta da opção 2 do passo 7, a worktree já existe: `git fetch origin` e `git -C .claude/worktrees/release-0.1.0 merge --no-edit origin/develop`, com merge, sem rebase. Conferir que `MARKETING_VERSION = 0.1.0`. Os passos 3 a 6 rodam nessa worktree.

- [ ] **Step 3: Take the prints and a short video**

No simulador do iPhone e no do Watch, compilados assinados como no passo 7 da Task 9: o print de cada tela e um vídeo do app abrindo, com até 15 s e menos de 5 MB (`xcrun simctl io <udid> recordVideo --codec h264 <arquivo>.mp4`). Os arquivos vão para `docs/hexgym/prints/<issue>/`, num commit na branch da release.

- [ ] **Step 4: Write the phase status**

`"$S/write-status-snapshot.sh" --repo lipedesign/HexGym --milestone 1 --workdir <worktree> --out <worktree>/docs/status/m1-fundacao-status.md` cria o resumo (sem o `--out`, o nome sairia do título do milestone), e o `relentless:documenter`, na worktree da release, completa esse arquivo: o que a fase entregou, o que ficou para depois (com as issues) e as decisões do `docs/decisions/` tomadas nela. O pedido diz que ele só mexe nesse arquivo, sem alinhar o README nem abrir issues (os passos 4 e 5 do `documenter.md`): a branch da release só leva o resumo e os prints. Um commit na branch da release.

- [ ] **Step 5: Build for TestFlight**

Na worktree da release, depois dos commits: `node scripts/hexgym/testflight.mjs`.

- [ ] **Step 6: Open the release pull request**

`git push -u origin release/0.1.0` e `gh pr create -R lipedesign/HexGym --base main --head release/0.1.0 --title "Versão 0.1.0: a fundação" --body-file <arquivo>`, com o corpo trazendo o que entrou na fase, o que o passo 1 passou para a fase 1, os prints do iPhone e do Watch, o link do vídeo e o número do build no TestFlight, como dizem as Restrições globais. Na volta da opção 2 do passo 7, o PR já existe: `git push` e `gh pr edit <pr> -R lipedesign/HexGym --body-file <arquivo>`, com o corpo novo.

- [ ] **Step 7: Call the founder**

Parada da seção 9.1, fim de fase: um pedido de decisão na #25, com os prints, o vídeo, o build, o link do PR e o commit dele: 1. Aprovar a versão 0.1.0 (recomendada); 2. Pedir mudanças (o que mudar, na nota do `/decide`). Nada segue sem a resposta dele.

Com a 2, cada mudança vira uma issue da fase (sub-issue do épico, com a linha `Origem:`), na linha `Depende de:` desta, feita pelo caminho de sempre, em `develop`: nada entra direto na branch da release. Um comentário na #25 lista as issues, `"$S/set-state.sh" --repo lipedesign/HexGym --issue 25 --state todo` faz a #25 esperar por elas, e o PR da versão fica aberto. Quando elas fecham, a #25 fica pronta de novo, e a Task recomeça no passo 1, com um pedido novo no passo 7.

- [ ] **Step 8: Merge the release**

Depois do `/decide 25 1`. Se o PR já entrou (`gh pr view <pr> -R lipedesign/HexGym --json state --jq .state` dá `MERGED`), falta só o comentário deste passo. Os portões: o `gh pr view <pr> -R lipedesign/HexGym --json state,mergeable` dá `OPEN` e `MERGEABLE`, o `"$S/wait-ci.sh" --repo lipedesign/HexGym --pr <pr>` sai com 0, chamado de novo enquanto sair com 3, e o `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket` traz o `tests-ok` e o `hexgym-ok` em `pass` (nota `2026-11-03-um-orquestrador-so.md`, que diz também o que fazer com um check travado ou sem execução); um check vermelho ou travado, ou um conflito, vira um pedido de decisão na #25, que não conta como este passo: depois do `/decide`, o passo 8 roda de novo, com a resposta. Com a causa no código, a recomendação do pedido é corrigir por uma issue da fase, e, com ela, a Task segue o caminho da opção 2 do passo 7 (uma issue da fase, a #25 em `state:todo` e o recomeço no passo 1, com um pedido novo no passo 7), sem rodar este passo de novo, que só leria o mesmo check vermelho. Então `gh pr merge <pr> -R lipedesign/HexGym --merge --match-head-commit <sha>`, com o commit que o founder aprovou.

- [ ] **Step 9: Tag the version**

Se `gh release view v0.1.0 -R lipedesign/HexGym` ainda não acha a versão: `gh release create v0.1.0 -R lipedesign/HexGym --target main --title "HexGym 0.1.0" --notes-file <notas>`.

Run: `gh release view v0.1.0 -R lipedesign/HexGym`
Expected: a versão "HexGym 0.1.0", com a tag `v0.1.0`.

- [ ] **Step 10: Bring it back to develop**

`git fetch origin`. Se `git merge-base --is-ancestor origin/main origin/develop` sai com 0, a `develop` já tem a versão, e falta só o comentário deste passo. Senão, o PR de `main` para `develop`, quando ainda não há um aberto (`gh pr list -R lipedesign/HexGym --base develop --head main --json number --jq length` dá `0`): `gh pr create -R lipedesign/HexGym --base develop --head main --title "Versão 0.1.0 de volta para develop" --body "Traz a versão 0.1.0 (tag v0.1.0) de volta para develop, com merge normal."`. Os mesmos portões do passo 8 (um pedido aberto por eles também faz este passo rodar de novo depois do `/decide`), com uma diferença: a versão já saiu, e a correção de uma causa no código não recomeça a Task. Ela vai por uma issue da fase, na linha `Depende de:` desta, com a #25 em `state:todo`, e, quando a issue fecha, o passo 10 roda de novo, com o PR fechado e reaberto antes dos portões (`gh pr close <pr> -R lipedesign/HexGym && gh pr reopen <pr> -R lipedesign/HexGym`), para os checks rodarem com a `develop` nova. Essa reabertura vale a cada issue de correção que fecha, e não uma vez por commit, como a da nota de 03/11: a cabeça do PR é a de `main`, que não muda entre uma correção e outra, e reabrir de novo depois de uma queda não estraga nada, porque o `wait-ci.sh` julga, de cada workflow, a execução mais nova no commit. Então `gh pr merge <pr> -R lipedesign/HexGym --merge --match-head-commit <sha>`.

- [ ] **Step 11: Remove the release worktree**

Na raiz do checkout: `git pull --ff-only`, `git worktree remove .claude/worktrees/release-0.1.0` e `git branch -D release/0.1.0`, o que ainda existir (a remota o GitHub apaga no merge).

- [ ] **Step 12: Close the issue and the epic**

Primeiro, com a #25 ainda aberta, o que pode pedir uma decisão: o `"$S/check-milestone-outcomes.sh" --repo lipedesign/HexGym --milestone 1`, sem `--allow-pending` e antes de fechar o milestone, porque o script só lê os abertos, sai com 0, e nenhuma sub-issue do épico está aberta fora a #25 (`gh api 'repos/lipedesign/HexGym/issues/<épico>/sub_issues?per_page=100' --jq '[.[] | select(.state == "open" and .number != 25) | .number]'` dá `[]`). Então, porque um PR para `main` não fecha a issue sozinho: `gh issue close 25 -R lipedesign/HexGym` e `"$S/close-epic.sh" --repo lipedesign/HexGym --epic <épico>`, que só fecha o épico com todas as sub-issues fechadas. Um pedido de decisão deste passo depois do `gh issue close 25` sai com a #25 reaberta antes (`gh issue reopen 25 -R lipedesign/HexGym`): fechada, ela não aparece em "Pede você".

Run: `gh issue view 25 -R lipedesign/HexGym --json state --jq .state` e o mesmo para o épico
Expected: `CLOSED` nos dois. O comentário deste passo leva o PR, a tag, o build e a saída do `check-milestone-outcomes.sh`.

- [ ] **Step 13: Close the phase**

`gh api -X PATCH repos/lipedesign/HexGym/milestones/1 -f state=closed` e o filtro da visão "Fase atual" para a fase seguinte:

```bash
gh api graphql -f query='mutation($v:ID!,$f:String!){updateProjectV2View(input:{viewId:$v,filter:$f}){projectV2View{name filter}}}' \
  -f v=PVTV_lAHOAYVuVc4Bpo0bzgMV7KM -f f='milestone:"Fase 1: Design system"'
```

Run: `gh api 'repos/lipedesign/HexGym/milestones?state=open' --jq 'sort_by(.number) | .[0].title'`
Expected: `Fase 1: Design system`. A página do design ganha o resultado da fase.

Por último, o comentário deste passo e `"$S/set-state.sh" --repo lipedesign/HexGym --issue 25 --state done`. Até aqui, a #25 fica em `state:in-progress`: fechada e com essa etiqueta, ela mostra que a versão não terminou, e quem retoma a acha pela etiqueta (`gh issue list -R lipedesign/HexGym --state all --label state:in-progress`), mesmo com o milestone 1 já fechado, se a sessão cair depois do passo 12. Uma falha neste passo não vira pedido de decisão: fechar o milestone e trocar o filtro se repetem sem problema, então o passo roda de novo, e, sem o `gh`, o aviso vai ao Lipe na conversa.
