# Como o trabalho anda no HexGym

O HexGym é um fork do [openGym](https://github.com/DuarteSantos8/openGym) para iPhone e Apple Watch. Este guia conta como o trabalho anda aqui: o caminho de uma issue até o merge, o Git Flow, o checklist do pull request e o relentless. A versão completa está na seção 9.1 do [documento de design](/docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md), e as regras que valem por cima dela ficam em [`docs/decisions`](/docs/decisions/README.md).

## Quem faz o trabalho

O código é escrito por agentes de IA, no [Claude Code](https://claude.com/claude-code), com o tech lead orquestrando. O founder acompanha pelo [quadro do projeto](https://github.com/users/lipedesign/projects/6), que é privado, e entra nas decisões que são dele.

A base é o [relentless](https://github.com/marcelusfernandes/relentless), um plugin do Claude Code ativado só neste projeto, na versão 1.4.11. Ele traz o orquestrador, os agentes (implementador, QA, revisor isolado e documentador) e as regras de cada passo. O HexGym usa o orquestrador do relentless como ele vem, sem outro por cima, e só escreve a configuração (`.relentless/config.json`), os modelos de issue e de pull request e as decisões de `docs/decisions`. Onde o relentless e o documento de design divergem, valem essas decisões: o Git Flow abaixo, o squash nas features e a Task do plano como critério de aceite.

Achou um problema? Abra uma issue pelo modelo de bug. Para uma falha de segurança, não abra issue: veja o [SECURITY](/.github/SECURITY.md).

## Antes de começar

- Leia [`docs/decisions`](/docs/decisions/README.md). Um ADR muda como o sistema é feito ou o que ele promete, e fica proposto até o founder decidir. Uma nota registra o que já é feito de propósito, como o [relentless no Git Flow](/docs/decisions/notes/2026-11-01-relentless-no-git-flow.md) e [um orquestrador só](/docs/decisions/notes/2026-11-03-um-orquestrador-so.md).
- Cada fase ganha um plano em [`docs/superpowers/plans`](/docs/superpowers/plans), escrito antes de ela começar. Cada Task do plano vira uma issue.

## Uma issue

- Uma issue cabe num pull request. Se ficou grande, vira mais de uma.
- Ela nasce pelos modelos: o de tarefa pede o que fazer, por quê, como saber que está pronto e o que o founder vê; o de bug pede os passos, o que você esperava, o que aconteceu, onde, o aparelho com o sistema e a versão do app. Issue em branco não abre.
- Cada issue fica no marco da fase dela, como sub-issue do épico da fase.
- A linha `Plano:` aponta a Task do plano, e essa Task é o critério de aceite. Uma issue sem `Plano:`, como um achado de revisão, usa o próprio corpo.
- A linha `Depende de:` lista as issues que vêm antes. A issue só começa quando todas as de lá fecharam.
- O estado é uma etiqueta só, entre `state:todo`, `state:in-progress`, `state:review`, `state:done` e `state:blocked`, mais `human:pending` enquanto a issue espera o founder. O cartão do quadro mostra a etiqueta. Só o orquestrador troca o estado, pelo `set-state.sh` do relentless.

## O caminho de uma issue até o merge

```
issue (state:todo)
  → worktree e branch feature/<número>-<nome>, a partir de develop
  → código e testes → PR para develop, com "Closes #<número>"
  → QA (checagens e o app rodando) → revisão isolada de outro agente
  → CI verde → merge em develop (squash) → state:done, Feito
fim da fase → release/<versão>, a partir de develop → build interno no TestFlight
  → o founder vê e aprova (/decide) → merge em main, com a tag v<versão> → PR de main para develop
```

1. **Uma worktree por implementador.** Cada issue ganha uma worktree própria e a branch `feature/<número>-<nome>`, sempre a partir da `origin/develop` mais nova, nunca de outra feature. A branch no GitHub marca que a issue tem dono.
2. **Código e testes.** O comando de teste é o `node scripts/hexgym/check.mjs` (veja "Como compilar" no [README](/.github/README.md)). Mudança no código que veio do openGym é pequena, com teste, num commit que possa ser proposto ao openGym, e o `cd frontend && npm test` continua verde.
3. **O pull request.** Vai para `develop`, pelo modelo, com `Closes #<número>` e a linha `ADRs:`.
4. **QA.** O agente de QA roda as checagens e o app, e o orquestrador põe o resultado na seção "QA / dogfood result" do pull request.
5. **Revisão isolada.** Outro agente, que não viu a conversa de quem escreveu, lê a issue, a Task e o diff, e dá o veredito. O que ele apontar volta ao implementador, na mesma worktree, e o QA e a revisão rodam de novo. A aprovação vale para o último commit e aparece como `review:approved`.
6. **CI verde.** Hoje nenhum check roda nos pull requests: as Actions do fork ligam com a issue #3, e o workflow do HexGym vem com a #9. Até lá, o que garante um pull request é a revisão isolada.
7. **Merge em `develop`, em squash.** O tech lead ou o founder faz o merge quando a revisão aprovou o último commit, a linha `ADRs:` está certa, o pull request não tem conflito e a CI passou. O `merge-if-ready.sh --dry-run` do relentless confere a revisão e a linha `ADRs:`, e também que um ADR aceito no pull request veio do `/decide` do founder; o conflito e a CI, quem faz o merge confere. O título do pull request vira o commit do squash. A issue fecha, ganha `state:done` e vai para Feito no quadro.

## Git Flow

- `develop` é a branch padrão e integra o trabalho. `main` só recebe versões, uma no fim de cada fase.
- As duas são protegidas, também para a conta admin: só recebem pull request, sem push forçado e sem apagar a branch.
- `feature/<número>-<nome>` sai de `develop` e entra nela em squash.
- Entram com merge normal, para guardar a história: `release/<versão>`, que sai de `develop`, e `hotfix/*`, que sai de `main`, as duas em `main`; o pull request de `main` para `develop`, que traz a versão de volta; e o `sync/opengym-<data>`, com a etiqueta `upstream`, que traz o que mudou no openGym. Um squash no sync deixaria os commits do openGym fora da história de `develop`, e o sync seguinte voltaria a dar conflito.
- Os ganchos de git do relentless recusam commit e push na `main` e push forçado em qualquer branch. Por isso, um conflito com a `develop` se resolve com merge, nunca com rebase, e o pull request volta ao QA e à revisão.
- Nunca mexa no openGym original nem no espelho dele no GitLab: todo pull request vai para o fork.

## O pull request

O [modelo](/.github/pull_request_template.md) já traz as seções:

- `Closes #<número>` e a linha `ADRs:`, uma vez só. A linha lista os ADRs de `docs/decisions/adr/` que o pull request segue, ou diz `none` com o motivo entre parênteses. O merge do relentless recusa o pull request sem ela.
- **O que muda**, em uma ou duas frases.
- **Como foi testado**: testes, simulador do iPhone, simulador do Watch, aparelho de verdade, ou só documentação.
- **QA / dogfood result**, que o orquestrador preenche.
- **Para o founder ver**: prints de antes e depois quando o visual muda, e um vídeo curto quando há movimento. Eles ficam em `docs/hexgym/prints/<issue>/`, no commit do próprio pull request.

O título fica em português, simples, dizendo o que muda. O prefixo de conventional commits não é exigido aqui.

### O checklist

- Uma issue só, e o `Closes #` aponta para ela.
- CI verde em todos os checks obrigatórios.
- Nenhuma dependência nova, ou o porquê está no pull request. O openGym trata poucas dependências como regra, e o HexGym também: nenhum pacote Swift de terceiros sem uma razão forte, escrita no pull request.
- Nenhuma mídia de exercício nova ou acima de 180 px, e nada novo em `data/` ou `catalogue/media/`.
- Texto para o usuário simples, sem travessão.
- Revisão isolada aprovada (`review:approved`) no último commit do pull request.

No `sync/opengym-<data>`, os itens de issue única e de `catalogue/media/` não valem, porque ele traz o que mudou no openGym.

## Quando o founder decide

O agente faz sozinho o trabalho das issues até o merge em `develop`, e para nestes casos:

- decisão de visual ou de produto;
- tudo que envolva dinheiro, contas, loja ou falar com o Duarte, e o primeiro envio ao TestFlight;
- o texto público do projeto, como este arquivo;
- as paradas do relentless: um ADR, segredos e credenciais, a proteção das branches, apagar branch ou reescrever histórico, e publicar num registro;
- o fim de cada fase, com o pull request, os prints, o vídeo curto e o build interno de TestFlight;
- quando trava de verdade, depois de tentar os caminhos que tem.

Cada parada é um pedido de decisão na issue: a pergunta, o contexto, as opções numeradas e a recomendação. A issue ganha `human:pending` e `state:blocked` e aparece na visão "Pede você" do quadro, e o agente segue em outra issue. O founder responde com `/decide <issue> <opção>`, na sessão dele, fora da do agente. O agente nunca responde por ele: não roda `/decide`, e um ADR só passa de proposto a aceito por essa resposta.

## Mídias de exercício

As fotos e as animações dos exercícios são licenciadas pela Gym visual ao openGym e ficam fora da AGPL (veja o [NOTICE.md](/NOTICE.md)). O HexGym usa só as de 180 px do repositório, sem editar, recortar ou converter, e nunca as passa por nenhuma ferramenta de IA. Como as issues e os pull requests são lidos por agentes de IA, nenhum print, vídeo ou anexo mostra essas mídias.
