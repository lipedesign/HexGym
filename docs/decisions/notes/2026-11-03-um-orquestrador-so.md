# 2026-11-03: um orquestrador só, o do relentless

- **Data:** 2026-11-03 (America/Sao_Paulo)
- **Origem:** issue #15 (Tarefa 1 da fase 0)
- **Quem decidiu:** o founder, na conversa de 03/11/2026: usar só o orquestrador do relentless, como
  ele vem, e tirar o que o duplicava, sem mexer no plugin. As regras abaixo são do tech lead
  (seção 9.1 da especificação).
- **Substitui:** a nota `2026-11-01-orquestrador-sobre-o-relentless.md`.

## Contexto

Em 03/11/2026, uma leitura do repositório de fora mostrou que o HexGym tinha dois orquestradores no
papel. A Tarefa 1, revista no PR #30, criava a skill `hexgym-orquestrador`, que fazia o papel do
orquestrador do relentless e refazia o laço dele com código nosso: a fila e a retomada
(`board.mjs next`), a espera pelos checks (`board.mjs checks`), as colunas do quadro
(`board.mjs sync`), a brief do implementador, o pacote do revisor e o QA no corpo do PR
(`context.mjs`), e um registro que esperava fora do git. O cabeçalho do plano da fase 0 ainda pedia
o superpowers:subagent-driven-development para executar as Tasks, um terceiro jeito de tocar o mesmo
trabalho. Nada disso chegou a existir: a Tarefa 1 não tinha começado.

## Decisão

- **O orquestrador é o do relentless** (`agents/orchestrator.md` do plugin), como ele vem: pega a
  issue, cria a worktree, chama o implementador, o QA e o revisor isolado, aplica o veredito e
  passa pelo `merge-if-ready.sh`. O HexGym não escreve skill, agente nem script que refaça esse
  laço, e não muda o plugin.
- **O HexGym só configura e escreve regras:** o `.relentless/config.json`, os modelos de issue e de
  PR, e as decisões de `docs/decisions/`, que o relentless manda ler antes de planejar ou
  implementar. Nenhuma regra daqui muda o laço; elas dizem o que é próprio deste repositório.
- **Saem do plano da fase 0:** a skill `hexgym-orquestrador`, o `scripts/hexgym/board.mjs`, o
  `scripts/hexgym/context.mjs`, o `scripts/hexgym/project.json` e o registro pendente. Sai também,
  do cabeçalho do plano, o superpowers como executor: ele continua só para escrever os planos
  (superpowers:writing-plans).
- **Fica o `scripts/hexgym/check.mjs`:** é o comando de teste do projeto, não orquestra nada. O
  `checks.test` do relentless, o QA e a CI chamam o mesmo comando.
- **A Tarefa 1 (#15) liga o relentless no HexGym:** atualiza o plugin para a versão publicada mais
  nova, só neste projeto, com o marketplace fixado na tag dessa versão, porque a `main` do relentless
  já tem mudanças sem versão (a 1.4.10 já trouxe as correções do macOS, e a correção local deixa de
  ser usada); põe o `check.mjs` no `checks.test` e `merge.allow_issue_override` em `false`; ajusta
  os modelos; troca as esperas da #3 e da #10 por pedidos de decisão; e dá à fase 0 a seção Outcome,
  o épico e uma etiqueta `state:*` em cada issue.

## O que o orquestrador do relentless precisa saber do HexGym

- **Git Flow:** a nota `2026-11-01-relentless-no-git-flow.md`. A worktree sai de `develop`
  (`worktree-create.sh … --base develop`), o PR vai para `develop`, as features entram em squash,
  e release, hotfix, a volta de `main` e o sync com o openGym entram com merge normal.
- **Merge:** `merge.default` fica `human`, e `merge.allow_issue_override` fica `false`: a etiqueta
  `merge:auto` numa issue não vale, porque o merge automático do relentless é `gh pr merge --merge`.
  Com os portões abertos, o tech lead faz o squash, como no modo `human`:
  `gh pr merge <pr> -R lipedesign/HexGym --squash --match-head-commit <sha>`. Por ser o merge do modo
  `human`, ele não ganha a linha `merge` no `log.jsonl`, que o `orchestrator.md` pede para o merge do
  próprio orquestrador.
- **Os portões do merge:** o `merge-if-ready.sh --dry-run` sai com 0, o PR está `OPEN` e
  `MERGEABLE`, e a CI passa. Até a #3, nenhum check roda nos PRs: o `wait-ci.sh` sai sempre com 3, o
  implementador roda uma vez e reporta, e valem os dois primeiros portões. Depois da #3, o
  `wait-ci.sh --repo lipedesign/HexGym --pr <pr>` sai com 0, chamado de novo enquanto sair com 3, e
  o `gh pr checks <pr> -R lipedesign/HexGym --json name,bucket` traz o `tests-ok` e, depois da #9, o
  `hexgym-ok` em `pass`: um workflow que não rodou no commit não aparece para o `wait-ci.sh`.
- **Check travado ou sem execução:** um check que segue pendente por mais de uma hora e meia no mesmo
  commit travou (como a execução 41267573719, presa em `queued` desde 01/11): um comentário na issue
  com o estado e o link da execução, e um pedido de decisão. Um PR aberto antes de as Actions rodarem
  por evento, ou antes de o workflow de um check existir em `develop`, não ganha execução sozinho:
  fechar e reabrir o PR dispara o `pull_request` com a base atual, uma vez por commit, com um
  comentário na issue dizendo por quê.
- **Conflito com a `develop`:** a branch traz a `origin/develop` com merge, sem rebase (os ganchos
  recusam push forçado), e o PR volta ao QA e à revisão.
- **Critério de aceite:** a Task do plano da fase que a linha `Plano:` da issue aponta. O contexto do
  implementador (o critério, os arquivos, os ADRs e o que fica de fora, como pede o
  `orchestrator.md`) sai dela e das Restrições globais do plano, e o QA e o revisor leem a Task pela
  mesma linha. Uma issue sem `Plano:`, como um achado de revisão, usa o próprio corpo.
- **Dependências:** a linha `Depende de:` das issues faz o papel da `Blocked by:` do relentless. A
  issue só começa com as issues de lá fechadas.
- **Paradas do founder:** as da seção 9.1 da especificação, e todas cabem nos portões do relentless
  (ADR e `/decide`, publicar, proteção de branch, apagar branch): decisão de visual ou de produto;
  dinheiro, contas, loja ou falar com o Duarte; o primeiro envio ao TestFlight; o texto público do
  projeto; o fim de cada fase e tudo que entra em `main`. Cada uma é um pedido de decisão
  (`request-decision.sh`), em português, que o founder responde com `/decide`.
- **Revisão isolada:** só pelo `run-isolated-review.sh`, em primeiro plano, como manda o
  `orchestrator.md`, e nunca com o revisor chamado como subagente. O script roda o `claude -p` com o
  agente `relentless:reviewer` e a lista de comandos de leitura dele; ele roda de dentro do checkout
  ou da worktree do PR, onde o plugin está ligado.
- **QA no corpo do PR:** o `fill-qa-section.sh` troca a seção `## QA / dogfood result` até o próximo
  título `## `. Por isso, nenhuma linha do QA começa com `## `, nem dentro de bloco de código: a troca
  seguinte pararia nela e deixaria o resto do QA velho no corpo.
- **Registro (`docs/decisions/log.jsonl`):** segue o `orchestrator.md`. A decisão de uma Task sem PR
  próprio, como o `/decide 3`, entra pelo PR seguinte do orquestrador.
- **Tarefa sem código** (como as Tasks 2, 3 e 12) **e a Task da versão** (a última do plano): o
  orquestrador faz os passos dela na ordem, com um comentário na issue por passo e a prova, e
  retoma pelo último comentado. A Task da versão não é uma feature: tem a branch `release/<versão>`
  e entra em `main` com merge normal.
- **Achado que fica para depois:** uma issue no milestone da fase, sub-issue do épico, com a linha
  `Origem:` do relentless, e na linha `Depende de:` da issue da versão, para a versão esperar por
  ela. O que pode esperar a fase seguinte vai para o milestone dela, com `orphan:ok`.
- **PR que passa do limite do diff do GitHub** (20.000 linhas ou 300 arquivos, como o do script
  gerado do motor, na Task 5): o `gh pr diff` responde 406, e o pacote do revisor do relentless vai
  sem diff. O corpo do PR avisa o revisor e manda ler os arquivos pelo
  `gh api --method GET 'repos/lipedesign/HexGym/pulls/<pr>/files' --paginate`, em que o GitHub
  deixa sem o patch os arquivos muito grandes, e o QA mostra o `--check` do arquivo gerado passando.
  Fazer o pacote cair nessa lista quando o `gh pr diff` falha é uma mudança para propor ao
  relentless, com o ok do founder.
- **Quadro:** o Project 6 anda pelas automações do próprio GitHub, já ligadas (issue adicionada, PR
  ligado à issue, issue fechada, PR com merge), e cada cartão mostra a etiqueta `state:*`. Nenhum
  script espelha as etiquetas nas colunas. A visão "Pede você" filtra
  `label:"human:pending","state:blocked" is:open`.

## Doutrina para quem escreve

- Para trocar o estado, `set-state.sh`; nunca `gh issue edit` com `state:*`. Uma issue aberta sem
  nenhuma `state:*` (criada fora dos formulários) ganha `state:todo` pelo mesmo script.
- `human:pending` só entra pelo `request-decision.sh` e só sai pelo `/decide` do founder. Agente não
  roda `/decide` nem `decide.sh`.
- Apagar a branch local de um PR que já entrou é limpeza: a remota o GitHub apaga no merge. Apagar
  uma branch no GitHub é parada, a não ser que um `/decide` já tenha autorizado, como o da #3 para
  as branches de teste das Tasks 2 e 11.
- Os nomes desta nota são os do relentless 1.4.11, a versão que a Tarefa 1 fixa. Trocar de versão
  é fixar a tag nova. Antes, o tech lead relê o `agents/orchestrator.md` dela e, se ele mudar o que
  esta nota diz, acerta a nota num PR.

## Evidência

- No relentless 1.4.11 (commit `ee722b8` de `marcelusfernandes/relentless`):
  - o `agents/orchestrator.md` manda rodar o `run-isolated-review.sh` e as esperas pela CI em
    primeiro plano (linha 48) e o revisor só por esse script, nunca como subagente (linha 50);
  - `fill-qa-section.sh` comenta o QA no PR e troca a seção `## QA / dogfood result` do corpo até a
    próxima linha que começa com `## `, sem olhar blocos de código, lendo o texto pelo `ENVIRON` (o
    `awk -v` da 1.4.8 perdia as quebras de linha no macOS);
  - `wait-ci.sh` julga os checks do commit do PR pelo nome e, de cada workflow, a execução mais nova
    nesse commit (saídas: 0 verde, 1 vermelho, 3 pendente, 4 sem cota);
  - `merge-if-ready.sh` lê o `allow_issue_override` (sem a chave, vale `true`) e faz o merge com
    `gh pr merge --merge`;
  - `worktree-create.sh` usa `--base main` quando não recebe outra;
  - `build-review-bundle.sh` (linha 19) lê o diff com `gh pr diff` e, se o comando falha, segue sem
    ele;
  - `run-isolated-review.sh` sempre monta o pacote pelo `build-review-bundle.sh`, exporta
    `RELENTLESS_ROLE` e `CLAUDE_AGENT` para os ganchos de isolamento e roda o
    `claude -p --agent relentless:reviewer` com a lista de comandos do revisor.
- Em 03/11/2026, a `main` do relentless (commit `191463b`) já tinha dois commits depois da tag
  `v1.4.11`, os PRs #27 e #28 de lá (o "corte mínimo"), e o `plugin.json` dela ainda dizia 1.4.11.
  Atualizar o plugin pela ponta do marketplace traria esse código com o número da 1.4.11.
- A documentação do Claude Code, lida em 03/11/2026 (as páginas `plugins/marketplace-reference`,
  `plugins/loading` e `plugins/cli-reference` de https://code.claude.com/docs/en/), diz que a fonte
  `github` de um marketplace aceita `ref` (branch ou tag), que uma declaração cuja fonte mudou é
  buscada de novo, e que o `claude plugin update` não troca a cópia instalada quando o número da
  versão é o mesmo.
- Os três scripts da revisão isolada (`run-isolated-review.sh`, `build-review-bundle.sh` e
  `apply-review-verdict.sh`) são iguais na 1.4.8 instalada e na 1.4.11; o `fill-qa-section.sh` e o
  `merge-if-ready.sh` mudaram.
- Em 03/11/2026, um `claude -p` rodou de dentro de uma sessão do Claude Code desta máquina (versão
  2.1.317, com `CLAUDECODE=1`): o caminho do `run-isolated-review.sh` funciona aqui. Os PRs #29, #30,
  #33 e #34 foram revisados pelo Agent tool, em que a lista de comandos do `reviewer.md` não vale e o
  gancho de isolamento não reconhece o papel.
- A API do diff de PR do GitHub responde 406 acima de 20.000 linhas ou 300 arquivos (por exemplo,
  https://github.com/reviewdog/reviewdog/issues/1696). Em 03/11/2026, o diff da API de comparação
  (`application/vnd.github.diff`) de um commit com um arquivo de 25.000 linhas marcado com
  `-diff linguist-generated=true` no `.gitattributes` trouxe as 25.000 linhas, como sem o `-diff`:
  a API ignora o `.gitattributes`. Os dois commits de teste ficaram em refs fora das branches,
  apagadas depois.
- Em 03/11/2026, o Project 6 tinha ligadas as automações "Auto-add sub-issues to project",
  "Auto-close issue", "Item added to project", "Item closed", "Pull request linked to issue" e
  "Pull request merged" (o campo `workflows` do `ProjectV2` no GraphQL), e a visão "Pede você"
  filtrava `label:"decisão do founder",bloqueado is:open`.
- Os fatos do GitHub medidos em 01/11/2026 para a CI (a execução 41267573719 presa em `queued`, os
  jobs da tentativa 1 só com `filter=all`, o `reopened` que dispara o `pull_request`, o
  `gh pr checks --required` que sai com 1 sem check obrigatório) estão na Evidência da nota anterior,
  no commit `0252537`.
