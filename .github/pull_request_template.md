<!-- Um PR, uma issue. O título diz o que muda. Squash em develop depois da CI verde e da revisão. -->
<!-- Num PR sync/opengym-<data> (seção 9.1, etiqueta upstream), os itens de issue única e de catalogue/media não valem, porque ele traz o que mudou no openGym. Esse PR entra com merge normal, nunca squash. -->
<!-- A linha ADRs aparece uma vez só, e o merge do relentless recusa o PR sem ela: os caminhos das decisões de docs/decisions/adr/ que o PR segue, ou none com o motivo entre parênteses, como em "none (só documentação)". -->

Closes #

ADRs: none ()

## O que muda
<!-- Uma ou duas frases: o que e por quê. -->

## Como foi testado
- [ ] Testes novos ou atualizados, passando
- [ ] Simulador do iPhone
- [ ] Simulador do Apple Watch
- [ ] iPhone ou Watch de verdade
- [ ] Só documentação ou configuração

## QA / dogfood result
<!-- O orquestrador preenche com o `fill-qa-section.sh` do relentless. -->

## Para o founder ver
<!-- Prints de antes e depois quando o visual muda, e um vídeo curto quando há movimento. No PR de fim de fase, o link do build interno do TestFlight. Não mostre as fotos e animações de exercício da Gym visual: os PRs são lidos por agentes de IA, e essas mídias não podem passar por eles. -->

## Checklist
- [ ] Uma issue só, e o "Closes #" aponta para ela
- [ ] CI verde em todos os checks obrigatórios
- [ ] Nenhuma dependência nova, ou o porquê está aqui
- [ ] Nenhuma mídia de exercício nova ou acima de 180 px, e nada novo em `data/` ou `catalogue/media/`
- [ ] Texto para o usuário simples, sem travessão
- [ ] Revisão isolada aprovada (`review:approved`) no último commit do PR
