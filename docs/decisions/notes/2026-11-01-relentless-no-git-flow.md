# 2026-11-01: o relentless no Git Flow do HexGym

- **Data:** 2026-11-01 (America/Sao_Paulo)
- **Origem:** issue #15 (Tarefa 1 da fase 0)

## Contexto

O HexGym passa a usar o relentless (1.4.11) como base do trabalho feito por agentes. O plugin fica
ativado só neste projeto, em `.claude/settings.json`, que o git não vê.

O relentless supõe um repositório com `main` como base:

- o `worktree-segura` e os agentes dizem `origin/main`;
- o `worktree-create.sh` usa `--base main` quando não recebe outra;
- o `merge-if-ready.sh` faz o merge com `gh pr merge --merge`;
- o bootstrap grava o `relentless-ci.yml`, que falha de propósito quando não acha comando de teste.

O fork segue o Git Flow da seção 9.1 de `docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md`:
`develop` é a branch padrão e integra o trabalho, e `main` só recebe versões.

## Decisão

- **Base `develop`.** Onde o relentless diz `origin/main`, leia `origin/develop`. A worktree sai assim,
  com `<checkout>` sendo o checkout principal (nesta máquina, `/Users/lipe/Developer/MyGym`):
  `worktree-create.sh --repo lipedesign/HexGym --workdir <checkout> --issue <n> --slug <nome> --type feature --base develop --path <checkout>/.claude/worktrees/<n>-<nome>`.
  O branch fica `feature/<n>-<nome>`, e o PR vai para `develop` com `Closes #<n>`.
- **Squash nas features.** O `merge-if-ready.sh` vai com `--dry-run`: ele confere `review:approved`,
  o commit revisado, a linha `ADRs:` e os ADRs aceitos, e sai sem esperar a CI. Sem o `--dry-run`, no
  modo `human`, ele espera a CI antes de comentar que o PR está pronto e, sem nenhum check, desiste
  com o código 3. O merge é `gh pr merge <PR> -R lipedesign/HexGym --squash --match-head-commit <sha>`,
  feito pelo tech lead ou pelo Lipe, com os portões da nota `2026-11-03-um-orquestrador-so.md`
  abertos: o `--dry-run` sai com 0, o PR está `OPEN` e `MERGEABLE`, e a CI passa (até a #3, nenhum
  check roda nos PRs, e valem os dois primeiros).
- **Sem `merge:auto`.** O `merge.allow_issue_override` fica `false` no `.relentless/config.json`, e a
  etiqueta `merge:auto` numa issue não vale, porque o merge automático do relentless é
  `gh pr merge --merge`, e as features entram em squash.
- **Merge normal, nunca squash:** `release/*` e `hotfix/*` em `main`, o PR de `main` para `develop` e
  o sync `sync/opengym-<data>` (seção 8.11).
- **CI:** o `test.yml` (job `tests-ok`) e, a partir da #9, o `hexgym.yml` (job `hexgym-ok`). O
  `relentless-ci.yml` não fica no repositório. Os `checks` de `.relentless/config.json` passam a
  chamar o `scripts/hexgym/check.mjs` na Tarefa 1 (#15).
- **Etiquetas e modelos:** a revisão da #15 casou as nossas com as do relentless e mudou a Task 3
  (#11) junto (PR #30). A lista que vale está na seção 9.1 da especificação.
- **Nenhuma onda do relentless antes de a Tarefa 1 (#15) terminar.** É ela que atualiza o plugin,
  põe o `check.mjs` nos `checks` e dá à fase 0 a seção Outcome, o épico e uma etiqueta `state:*` em
  cada issue (nota `2026-11-03-um-orquestrador-so.md`).
- **Título do PR** em português, simples, dizendo o que muda, porque vira o commit do squash. O
  prefixo de conventional commits não é exigido.
- **Linha `ADRs:`** no corpo do PR, uma vez só. O modelo de PR já traz.
- **Proteção das branches** não vem do bootstrap: fica com a #3.

## Doutrina para quem escreve

- Leia `docs/decisions/` antes de planejar ou implementar.
- O bootstrap, rodado de novo, desfaz ajustes deste repositório:
  - regrava o `.github/ISSUE_TEMPLATE/config.yml`, os três modelos de issue dele (o `epic.yml` volta
    com o YAML quebrado do original) e o `relentless-ci.yml`;
  - reescreve `stack`, `package_manager`, `checks` e `merge.default` do `.relentless/config.json`;
  - volta a cor e a descrição das 26 etiquetas dele (a `bug` perde a descrição em português).

  Depois dele, volte os arquivos com `git restore` e a descrição "Tipo: algo não funciona como
  deveria" com `gh label edit`, e apague o `relentless-ci.yml`.
- Os ganchos de git valem no checkout cujo branch já traz `.relentless/githooks`: a `develop` e as
  features a partir deste PR, e a `main` só depois da primeira versão. Eles só guardam a `main` e
  recusam push forçado em qualquer branch. A
  `develop` e a `main` ficam guardadas também pela proteção do GitHub (PR obrigatório, também para
  admin, sem push forçado e sem apagar).
- O gancho `protect-main` do Claude Code barra qualquer push feito com a `main` em uso, até o de tag.
  A tag da versão sai de outro branch (`git tag v<versão> origin/main` e `git push origin v<versão>`)
  ou com `gh release create v<versão> --target main`.
- No sync com o openGym, um conflito no fim do `CLAUDE.md` fica com as duas partes: o texto do
  openGym e o bloco do relentless.
- O `.worktreeinclude` leva o `.claude/settings.json` para cada worktree nova, para o relentless
  continuar ativado nela.
- O marketplace do relentless fica fixado na tag da versão (`"ref": "v1.4.11"` na fonte dele, no
  `.claude/settings.json`), porque a `main` de lá traz mudanças ainda sem versão. Trocar de versão é
  fixar a tag nova, reler o `agents/orchestrator.md` dela e acertar as notas.

## Evidência

- `bootstrap.sh --apply` em 01/11/2026: 19 etiquetas novas (de 21 para 40), `.relentless/config.json`
  com `merge.default` em `human` e o decisor Lipe (`lipedesign`), e `core.hooksPath` em
  `.relentless/githooks`.
- Com a correção, as suítes do próprio relentless passam no bash 3.2: 176 de 176 testes.
- A revisão do agente revisor do relentless no PR #29 achou o YAML quebrado do `epic.yml` (o Psych
  recusa a linha 14) e a espera pela CI no `merge-if-ready.sh` sem `--dry-run` (`wait-ci.sh` sai com 3
  no PR, que não tem checks).
