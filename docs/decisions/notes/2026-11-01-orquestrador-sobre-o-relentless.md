# 2026-11-01: o orquestrador do HexGym em cima do relentless

- **Data:** 2026-11-01 (America/Sao_Paulo)
- **Origem:** issue #15 (Tarefa 1 da fase 0, o orquestrador)
- **Quem decidiu:** o tech lead. São decisões técnicas (seção 9.1 da especificação); nada aqui muda
  produto ou visual.

## Contexto

A Tarefa 1 do plano da fase 0 criava um orquestrador próprio: dois agentes (`hexgym-implementador` e
`hexgym-revisor`), um quadro que movia os cartões do Project 6 e duas etiquetas de espera
(`decisão do founder` e `bloqueado`). Com o relentless 1.4.8 ativado neste projeto (nota
`2026-11-01-relentless-no-git-flow.md`), boa parte disso já existe: os papéis (implementador, QA,
revisor isolado, planner, documenter), as etiquetas `state:*` e `human:*`, o pedido de decisão com o
`/decide` e os portões do merge. Esta nota diz o que o HexGym usa do relentless, o que fica nosso e
por quê. O plano da fase 0 e a seção 9.1 da especificação mudam junto com ela.

## Decisão

### Papéis

- A sessão principal do Claude Code faz o papel do orquestrador do relentless, pela skill
  `hexgym-orquestrador`. A skill lê o `agents/orchestrator.md` do plugin (a pasta vem de
  `claude plugin list --json`, campo `installPath`) e diz onde o HexGym muda.
- Os agentes são os do relentless, chamados com o modelo escrito: `relentless:implementer`,
  `relentless:qa` e `relentless:reviewer`. O `relentless:documenter` escreve o resumo no fim de cada
  fase, só no arquivo que o `write-status-snapshot.sh --out` cria em
  `docs/status/m<n>-<nome>-status.md` (sem o `--out`, o nome sai do título do milestone), e sem
  alinhar o README nem abrir issues na branch da release. Os planos continuam saindo do
  superpowers:writing-plans, aprovados pelo founder; o `relentless:planner` não escreve plano de
  fase.
- Os agentes `hexgym-implementador` e `hexgym-revisor` não são criados.
- Uma issue de cada vez.

### O estado e o quadro

- A verdade é a etiqueta `state:*` da issue, uma só, que só o orquestrador troca (`set-state.sh`).
- O `board.mjs sync` espelha as etiquetas no Project 6: `state:todo` pronta vai para "Pronto para
  começar", e as outras `state:todo` para "A fazer"; `state:in-progress`, "Em andamento";
  `state:review`, "Em revisão"; `state:done` ou fechada, "Feito"; `state:blocked` fica onde está.
  Ele também põe no Project a issue que falta e dá `state:todo` à issue aberta sem `state:*`.
- Pronta quer dizer: aberta, no milestone da fase atual, `state:todo`, sem `human:pending`, sem a
  etiqueta `epic` e com as dependências fechadas (linha `Depende de:` ou `Blocked by:`).
- O `board.mjs next` retoma primeiro a issue em `state:review`, depois a em `state:in-progress`, e só
  então pega a pronta de menor número. Nunca devolve um épico. O `move` e o `refresh` do plano antigo
  saem.
- O merge com `Closes #<n>` fecha a issue antes dos passos que vêm depois dele. Por isso o `next`
  também retoma a issue fechada que ainda não chegou a `state:done`, de qualquer fase (a issue da
  versão fecha o milestone antes do próprio `state:done`), o `set-state done` vem por último, e cada
  passo depois do merge ganha um comentário, para a retomada saber onde parou. Uma decisão que um
  desses passos peça vai numa issue nova: numa fechada, o pedido some da visão "Pede você", e a
  resposta não volta pelo `next`.
- Mover um cartão à mão não muda o estado: na próxima volta, o quadro volta a seguir a etiqueta.

### As esperas pelo founder

- Toda espera é um pedido de decisão do relentless. O `request-decision.sh` põe `human:pending` e
  `state:blocked` e atribui a issue ao Lipe. O texto vai em português, no formato de
  `core/templates/decision-request.md`: a pergunta, o contexto, as opções numeradas (prós, contras, o
  que muda, o que afeta, os riscos e o custo de voltar atrás) e a recomendação, com os marcadores
  `<!-- relentless:author=agent -->` e `<!-- relentless:decision-request -->`.
- O Lipe responde numa sessão do Claude Code neste projeto com `/decide <issue> <opção> [nota]`. O
  gancho do relentless grava a decisão, troca `human:pending` por `human:decided` e devolve a issue
  para `state:todo`. O gancho acha o repositório pelo `gh repo view`, que neste checkout resolve para
  `lipedesign/HexGym` (`gh repo set-default`).
- Um passo do founder (um clique, uma instalação) também é um pedido, com a opção 1 "feito".
- Uma issue que volta de um `/decide` não começa de novo. Com código, ela é retomada pelo estado do
  PR. Sem código, pelo último passo comentado: numa Tarefa sem código, o orquestrador comenta cada
  passo feito na issue, com a prova, e o pedido de decisão que o passo manda fazer conta como esse
  passo. Um pedido aberto porque um passo não deu certo (um check vermelho ou travado, um conflito,
  a assinatura, um envio) não conta: depois do `/decide`, o passo roda de novo. Sem essa regra, a
  retomada pularia o passo, e no fim da fase a versão sairia sem o merge.
- Os passos que uma Task com código dá ao orquestrador antes do merge (o envio ao TestFlight da
  Task 13, a leitura do texto público pelo founder na Task 14) rodam logo antes do merge, depois de
  a revisão isolada aprovar o commit atual e de os portões abrirem, e cada comentário leva esse
  commit. Assim o founder vê, e o TestFlight recebe, o que vai entrar. Um commit novo depois deles
  volta ao QA e à revisão e refaz esses passos.
- A resposta do founder entra no critério de aceite: o `context.mjs` põe na brief e no pacote de
  revisão os pedidos e as respostas da issue (os comentários com `relentless:decision-request` e com
  `relentless:decision option=`).
- As etiquetas `decisão do founder` e `bloqueado` saem. A visão "Pede você" passa a filtrar
  `label:"human:pending","state:blocked" is:open`.
- O orquestrador para na lista fechada do relentless (ADR; segredos e credenciais; proteção de
  branch; publicação num registro; `state:blocked`; apagar branch ou reescrever histórico) e nas
  paradas da seção 9.1: decisão de visual ou de produto; dinheiro, contas, loja ou falar com o Duarte;
  o fim de cada fase e tudo que entra em `main`; o primeiro envio ao TestFlight; o texto público do
  projeto (README e afins); e quando trava de verdade.
- Apagar branch é parada, com duas exceções: a branch local de um PR que já entrou (a remota o
  GitHub apaga no merge) e a branch de teste que o próprio orquestrador criou na mesma Task, sem
  trabalho de ninguém (o PR de teste da Task 2 e o da Task 11).

### Base `develop` e squash

- O orquestrador cria a worktree antes de chamar o implementador, porque o `relentless:implementer`
  diz `origin/main` e `--type feat`:
  `worktree-create.sh --repo lipedesign/HexGym --workdir <checkout> --issue <n> --slug <nome> --type feature --base develop --path <checkout>/.claude/worktrees/<n>-<nome>`.
- O merge segue a nota anterior: `merge-if-ready.sh --dry-run` saindo com 0 (uma linha `ADRs:`,
  `review:approved` e o veredito no commit atual; no modo `human`, o dry-run sai antes de olhar a
  CI, e não confere se o PR está aberto), o PR aberto e sem conflito (`state` igual a `OPEN` e
  `mergeable` igual a `MERGEABLE`), os checks verdes depois da #3 e o squash à mão com
  `gh pr merge --squash --match-head-commit`. O `merge.default` continua `human`: quem faz o merge
  é o tech lead, como diz a seção 9.1. Um PR fechado só volta a abrir quando é o fechar e reabrir
  do orquestrador que parou no meio, que ele marca com um comentário na issue antes de fechar;
  fechado por outra razão, como à mão, vira pedido.
- Com o dry-run em 1, a mensagem diz o que falta: a linha `ADRs:` sem motivo volta ao implementador,
  e um veredito velho ou sem o commit volta ao QA e à revisão. O `orchestrator.md` (linha 46) manda
  pôr `human:pending` à mão nesse caso; aqui, ele só entra pelo `request-decision.sh`.
- Os checks são lidos pelo nome, no `gh pr checks <pr> --json name,bucket,link`: o `tests-ok` e,
  depois da #9, o `hexgym-ok`, cada um com `pass`. O `wait-ci.sh` só olha a última execução da
  branch, e o `--required` só lista os checks que a proteção exige: sem nenhum, o `gh` sai com 1, o
  que aconteceria sempre se o founder não autorizasse a mudança na proteção (o pedido da #3). Um
  pedido por falha do passo 1 da Task 2 repete as duas opções da proteção, e vale a última resposta
  a um pedido com elas: a de outro pedido da #3, como o de um check travado, não muda a proteção.
- A espera pelos checks fica no primeiro plano e tem limite, como a do `wait_ci` do
  `merge-if-ready.sh` (`orchestrator.md`, linha 48). O `board.mjs checks` lê os checks a cada 30 s
  por até 8 minutos, abaixo dos 10 da ferramenta Bash, e o orquestrador o chama de novo enquanto a
  saída for 3, até 12 vezes no mesmo commit (cerca de uma hora e meia, o que cobre os jobs do
  macOS). Passado isso, o check travou: um pedido de decisão, com o estado de cada check e o link da
  execução. CI pendente não é parada: esperar o Lipe pediria uma pessoa fora da lista fechada, e um
  job preso na fila pararia a fase sem nenhum pedido. Check vermelho volta ao implementador com o
  log; job cancelado ou com falha fora do código roda de novo uma vez por execução
  (`gh run rerun --failed`), só com ela na tentativa 1 e sem um `rerun` dela já comentado no
  commit, e a falha que se repete vira pedido. Depois disso, ou de um PR reaberto, a lista pode
  trazer ainda o check velho até o job novo começar, ou nem trazer o check. Por isso, o `checks`
  confere no GitHub a execução de cada job: uma que ainda roda deixa o check pendente, e uma criada
  antes do último `reopened` do PR não conta (no mesmo segundo, conta). Nada disso depende de um
  instante anotado num comentário, e a retomada só lê tudo de novo.
  Um nome que não aparece, sem nenhuma execução do workflow no commit (`gh run list --commit`), é um
  PR aberto antes de o workflow existir em `develop` ou de as Actions rodarem por evento: nenhum
  evento novo chega a ele sozinho. Fechar e reabrir o PR dispara o `pull_request` (o `reopened`)
  com a base atual, sem mudar o commit nem o veredito. Um comentário na issue antes de fechar marca
  esse fechar e reabrir: só com ele o portão reabre um PR que ficou fechado, porque o `gh` usa a
  conta do founder, e quem fechou não diz nada. O PR de teste da #3 faz o mesmo quando volta de um
  `/decide` ainda sem execução. Uma falha do próprio `gh` sai com 4, e não com 1, para não passar
  por check vermelho.
- Conflito com `develop`: o implementador traz o `origin/develop` para a branch com merge, sem
  rebase (reescrever histórico é parada), e o PR volta ao QA e à revisão.
- O implementador roda o `wait-ci.sh` uma vez só e não fica esperando: com a saída 3 (pendente),
  roda as checagens locais e reporta, e quem confere a CI é o portão do merge. Até a #3, a saída é
  sempre 3, porque nenhum check roda nos PRs.
- Os commits usam a mensagem que a Task pede, sem o prefixo de conventional commits. O
  `check-commit-msg.sh` não vale aqui: o squash leva só o título do PR.
- O repositório apaga a branch do PR no merge. O `worktree-cleanup.sh` tira a worktree e deixa a
  branch local, que o orquestrador apaga depois do merge.

### A Task do plano é o critério de aceite

- O `build-review-bundle.sh` usa o corpo da issue como critério de aceite e manda o diff inteiro. No
  HexGym, o requisito é a Task do plano, e o diff do motor traz um script gerado de uns 2 MB.
- O `scripts/hexgym/context.mjs` monta os dois textos. O `brief` junta as Restrições globais, o Foco
  da revisão e a Task. O `review` monta o pacote do relentless, com os mesmos títulos
  (`## Issue (acceptance criteria)`, `## PR body (for QA / dogfood section only)` e
  `## Diff (lockfiles excluded)`), mais a Task lida de `origin/develop`, sem os lockfiles e sem os
  arquivos gerados de `reviewExclude`, e diz o que ficou de fora. O diff sai do `git` local
  (`git diff origin/<base>...<commit do PR>`), e não do `gh pr diff`: a API do GitHub recusa o diff
  de um PR grande (HTTP 406), e o PR do script do motor pode passar do limite.
- Issue sem linha `Plano:` (um achado de revisão, por exemplo) usa o próprio corpo como requisito,
  com as Restrições globais e o Foco da revisão do plano da fase.
- A revisão: o `relentless:reviewer` recebe só o caminho do pacote; a resposta inteira vai para
  `.relentless/review/<pr>/agent-out.md`; e o `run-isolated-review.sh --from-output` lê a última
  linha (`Verdict: approved` ou `Verdict: changes_requested`), comenta o veredito no PR, com o
  commit, e troca as etiquetas. O arquivo não pode ser o `reviewer-out.md` da mesma pasta: o script
  copia a saída para lá, e o `cp` de um arquivo nele mesmo falha.
- O comentário do veredito só leva os achados com `changes_requested`, e só as linhas com a
  severidade entre colchetes (`[blocker]`, `[major]`, `[minor]` ou `[nit]`, o formato do
  `reviewer.md`). Por isso o `agent-out.md` é a fonte dos achados: com `changes_requested`, o
  implementador recebe o arquivo inteiro; com `approved`, só as linhas `[minor]` e `[nit]` vão num
  comentário no PR, sem os marcadores do começo do arquivo e antes do comentário do veredito (o
  `merge-if-ready.sh` toma como veredito o último comentário em que o texto
  `relentless:review-verdict` aparece, em qualquer parte do corpo, e um sem o commit trava o merge),
  e o que fica para depois vira issue.
- Pelo Agent tool, a lista de comandos do `reviewer.md` não é aplicada. Na revisão da PR #30, o
  revisor rodou `sed`, `awk`, `node` e `git` sem bloqueio, e o `pretool-reviewer-isolation.sh` não
  reconhece o papel sem `RELENTLESS_ROLE` ou `CLAUDE_AGENT` no ambiente. O isolamento fica no
  contexto novo e no pedido, que diz que ele só lê. O caminho `claude -p` do
  `run-isolated-review.sh` exporta as duas variáveis e passa a lista ao `claude`.
- Antes de aplicar o veredito, o commit do PR tem que ser o mesmo do pacote. Se mudou, o pacote e a
  revisão são refeitos.

### QA

- O `relentless:qa` roda `node scripts/hexgym/check.mjs <partes>` na worktree e usa o app de verdade
  quando a Task tem tela (simulador, com os prints e vídeos das Restrições globais).
- O `qa.md` do relentless (linha 14) manda o QA abrir uma issue para cada lacuna. Aqui, o pedido diz
  que ele só reporta: quem abre o acompanhamento é o orquestrador, no milestone da fase e como
  sub-issue do épico, para o `board.mjs` e a issue da versão o verem.
- O orquestrador publica o QA em duas partes. O comentário no PR sai do
  `fill-qa-section.sh --no-patch-body`. A seção `## QA / dogfood result` do corpo sai do
  `context.mjs qa`, que troca a seção até o próximo título `## `, passa a `###` os títulos `#` e
  `##` do QA que estão fora de bloco de código e fecha o bloco que o QA deixa aberto, para a troca
  seguinte não parar no meio dele nem engolir o resto do corpo. O `fill-qa-section.sh` não troca o
  corpo aqui: ele usa `awk -v qa="$QA"`, e o `/usr/bin/awk` do macOS (versão 20200816) recusa um
  `-v` com quebra de linha (`newline in string`) e sai com 2, depois de o comentário já ter saído.
- O modelo de PR passa a usar `##` em todos os títulos, para a troca parar no título seguinte.

### O registro

- O `docs/decisions/log.jsonl` segue a doutrina do relentless: uma linha por decisão do founder
  (`human_decide`) e por decisão do orquestrador (`merge`, `changes_requested`, `state_change`), com
  os campos do `orchestrator.md`.
- As linhas esperam em `.claude/hexgym/log-pendente.jsonl`, fora do git, e entram no primeiro commit
  da branch da próxima issue com código, só quando nenhum outro PR está aberto para `develop`: as
  linhas vão no fim do arquivo, e dois PRs abertos que acrescentam no fim entram em conflito. Nunca
  entram num PR em revisão.

### Etiquetas, modelos e milestones

- A Tarefa 1 troca as esperas da #3 e da #10 por pedidos de decisão e apaga `decisão do founder` e
  `bloqueado`. A #23 ganha o pedido dela quando ficar pronta, depois da Task 9: a lista do founder
  abre o projeto Xcode, que só existe a partir dali.
- A Task 3 (#11) passa `feature` para `enhancement` e `docs` para `documentation`, apaga `feature` e
  `docs` e troca `accessibility` por `acessibilidade`. `chore` e `upstream` ficam como tipos só do
  HexGym. As seis etiquetas padrão do GitHub ficam, porque o bootstrap do relentless as recria.
  Apagar as branches herdadas passa por um pedido de decisão.
- Os formulários Tarefa e Bug ganham `state:todo`. Os três do relentless ficam.
- O milestone de cada fase ganha a seção `## Outcome`, e a fase ganha um épico com todas as issues
  dela como sub-issues. A fase 0 recebe os dois na Tarefa 1; as outras, quando o plano delas for
  escrito. Antes de pegar issue, o orquestrador confere a fase: sem épico, faz esse começo, e, sem
  o plano dela, avisa o Lipe e para. Uma retomada vem antes dessa conferência.
- No `.relentless/config.json`, `checks.test` passa a ser `node scripts/hexgym/check.mjs` e
  `checks.install`, `npm ci && npm ci --prefix frontend`.

## Doutrina para quem escreve

- Para trocar o estado, `set-state.sh`; nunca `gh issue edit` com `state:*`. A exceção é o
  `board.mjs sync`, que dá `state:todo` à issue aberta sem nenhuma `state:*`: é o estado inicial, e
  ele não troca nenhum outro.
- `human:pending` só entra pelo `request-decision.sh` e só sai pelo `/decide` do Lipe. Agente não
  roda `/decide` nem `decide.sh`.
- Achado de revisão, de QA ou de CI que fica para depois vira uma issue no milestone da fase,
  sub-issue do épico, com a linha `Origem: achado durante <revisão|QA|CI> da PR #<n>`, e entra na
  linha `Depende de:` da issue da versão, para a versão esperar por ele. O que pode esperar a fase
  seguinte vai para o milestone dela, com `orphan:ok`, até o épico daquela fase o adotar.
- A Task da versão, a última do plano, tem a própria worktree (`release/<versão>`) e entra em `main`
  com merge normal: o orquestrador segue os passos dela, sem o laço das outras. Quando o founder pede
  mudanças no fim da fase, cada uma vira uma issue da fase, feita pelo laço em `develop`; a versão
  espera por elas e recomeça do primeiro passo, com a `develop` trazida para a branch da release.
  Nos merges dela, um check vermelho com a causa no código segue o mesmo caminho, e no PR de volta
  para `develop` só esse merge se refaz, porque a versão já saiu. O que pode pedir uma decisão no
  fechamento roda antes de fechar a issue da versão, e um pedido depois disso sai com ela reaberta.
- Os nomes e as opções desta nota são os do relentless 1.4.8. Depois de atualizar o plugin, reler o
  `agents/orchestrator.md` e os scripts que a skill chama.

## Evidência

- `run-isolated-review.sh`, linhas 91 a 99: com `--from-output`, copia o arquivo para
  `.relentless/review/<pr>/reviewer-out.md` e aplica o veredito, sem chamar outro `claude`.
- `apply-review-verdict.sh`: o comentário do veredito leva o commit e, só com `changes_requested`,
  as linhas com `[blocker|major|minor|nit]` (`collect_findings`); as etiquetas só mudam depois dele.
- `fill-qa-section.sh`: comenta primeiro (linha 29) e só depois troca o corpo, com `awk -v` (linhas
  34 a 43), sob `set -euo pipefail`; com um QA de mais de uma linha, o awk do macOS sai com 2, e o
  corpo fica sem QA. O mesmo texto passado pelo ambiente (`QA="..." awk 'BEGIN{print ENVIRON["QA"]}'`)
  funciona, e a correção pode ir ao relentless.
- `merge-if-ready.sh`, linhas 634 a 638: no modo `auto`, `gh pr merge --merge`.
- `worktree-cleanup.sh`: remove a worktree e não apaga a branch.
- `pretool-protect-worktree-write.sh` (linha 9): só barra escrita fora da worktree quando o checkout
  tem `.relentless/worktree.json` ou o ambiente tem `RELENTLESS_ROLE=implementer` ou
  `RELENTLESS_WORKTREE`.
- Neste checkout, `gh repo set-default --view` imprime `lipedesign/HexGym`, e o repositório tem
  `delete_branch_on_merge` ligado.
- `updateProjectV2View` com `filter` testado sem mudar nada na visão "Pede você", em 01/11/2026.
- `lib/human-decision.sh` (usado pelo `decide.sh` e pelo gancho do `/decide`): o comentário da
  resposta leva `<!-- relentless:decision option="<K>" -->` e a nota; a issue troca `human:pending`
  por `human:decided` e volta para `state:todo`.
- `check-milestone-outcomes.sh` só lê os milestones abertos (`milestones?state=open`): no fim da
  fase, ele roda antes de o milestone fechar.
- `merge-if-ready.sh`, linhas 600 a 614: no modo `human`, o `--dry-run` sai antes do `finish_ci`,
  sem olhar a CI (o `finish_ci` só vem na linha 616).
- `wait-ci.sh`, linha 106: lê só a última execução da branch (`gh run list --branch … --limit 1`).
- Em 01/11/2026, num PR sem nenhum check, `gh pr checks 30 -R lipedesign/HexGym --required` e o
  mesmo com `--json name,bucket` imprimiram "no checks reported" e saíram com 1; e
  `required_status_checks` de `develop` respondeu 404, "Required status checks not enabled".
- `pretool-reviewer-isolation.sh`, linhas 131 e 132: lê o papel de `RELENTLESS_ROLE` e de
  `CLAUDE_AGENT`. O `run-isolated-review.sh` exporta as duas nas linhas 141 e 142 e passa a lista de
  comandos ao `claude -p` (linha 147).
- `merge-if-ready.sh`, linhas 531 a 557 (`wait_ci`): espera a CI no primeiro plano, até 36 vezes o
  `wait-ci.sh --timeout-sec 20` com 10 s entre elas (uns 18 minutos), e desiste com 3.
- `merge-if-ready.sh`, linhas 116 a 127: `ADRs: none` sem um motivo entre parênteses sai com 1; linha
  302: o veredito é o último comentário que contém o texto `relentless:review-verdict`, em qualquer
  parte do corpo.
- `agents/orchestrator.md`, linha 46: quando o `merge-if-ready` sai com erro, pôr `human:pending` à
  mão; linha 48: a espera da CI fica no primeiro plano, sem `run_in_background` nem `gh run watch`.
- `agents/qa.md`, linha 14: o QA abre uma issue para cada lacuna.
- `gh pr checks --json` (gh 2.96): os `bucket` são `pass`, `fail`, `pending`, `skipping` e
  `cancel`, e o `link` de um job das Actions é `.../actions/runs/<execução>/job/<job>`; o de um
  check de outro app não tem `/actions/`. O `gh run view --json` traz o `attempt`, o `status` e o
  `createdAt`, e os eventos do PR (`repos/.../issues/<pr>/events`) trazem cada `reopened` com a
  hora, ao segundo, como o `createdAt`. Logo depois de um `rerun`, a execução já está em `queued`,
  com o mesmo `createdAt`, e o `attempt` não muda enquanto a tentativa nova espera na fila; o
  `check-runs` do commit, no filtro padrão, não traz nenhum, e os jobs da tentativa 1 só aparecem
  com `filter=all` (execução 41267573719, 01/11/2026).
- O `test.yml` e o `hexgym.yml` da Task 11 ouvem `pull_request` sem `types`, o que inclui o
  `reopened`. O merge de um workflow novo em `develop` não gera evento nos PRs já abertos, e o
  `gh run list` (gh 2.96) aceita `--commit`.
