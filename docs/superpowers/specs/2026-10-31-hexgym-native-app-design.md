# HexGym: app nativo para iPhone e Apple Watch

Documento de design. Data: 31/10/2026. Founder: Lipe. Tech lead: Claude.
Status: aprovado pelo founder em 31/10/2026, com as perguntas da seção 11 fechadas.

Página com a proposta visual (cores, telas, temas e a escolha do nome):
https://claude.ai/artifact/6errZFaXL1uhfbzvQRHDBK

## 1. Intenção

O HexGym é um fork do [openGym](https://github.com/DuarteSantos8/openGym), o app open source de
treino de força, reconstruído como app nativo para iPhone e Apple Watch em SwiftUI.

Hoje o app do openGym no iPhone é um app web (React) dentro de uma casca Capacitor, com algumas
peças nativas em volta (Watch, widgets, Live Activity). O HexGym mantém o que o openGym faz e troca
a experiência inteira:

- **Mesmo motor.** Exercícios, progressão de carga, 1RM estimado, mapa muscular, recuperação,
  sincronização e importações seguem as regras do openGym. Quando o openGym evolui, o HexGym recebe.
- **Outra experiência.** Visual, movimento e marca próprios, com Liquid Glass, transições e brilho.
- **Nativo de verdade.** A ideia, nas palavras do founder, é "extrair o máximo possível do que o
  iPhone e o Apple Watch oferecem". Quando a Apple oferece um recurso, ele é usado em vez de imitado.

Depois, numa etapa seguinte, o HexGym se estende ao resto do ecossistema Apple: Mac, Apple TV e o
que mais fizer sentido para quem treina.

O founder quer ver o app funcionando nas mãos dele e dos amigos. Ele decide produto e visual; as
decisões técnicas são do tech lead.

## 2. Objetivos

1. Um app de iPhone e um app de Apple Watch nativos, com as mesmas funções do app do openGym.
2. Uma experiência visual que impressione: o "wow" é o diferencial do fork.
3. Uso profundo dos recursos nativos dos dois aparelhos (lista na seção 7).
4. Um design system próprio, construído antes das telas e documentado em público.
5. Continuar recebendo as atualizações do openGym sem reescrever regras de treino.
6. Funcionar sozinho no aparelho, ou sincronizado com um servidor openGym auto-hospedado,
   como o app do openGym faz hoje.
7. Primeiro build no TestFlight para o founder e os amigos com iPhone e Watch juntos.

## 3. Não objetivos (por enquanto)

- Publicar na App Store. Primeiro vem o TestFlight; a loja pública talvez venha depois (seção 11).
- Mac, Apple TV, iPad e outros aparelhos. Ficam para a etapa seguinte, depois do primeiro TestFlight.
- Android. O HexGym é só Apple.
- Mudar regras de treino do openGym (progressão, 1RM, recuperação). Melhorias nessas regras, se
  surgirem, são propostas ao openGym.
- Servidor próprio. O HexGym usa o servidor do openGym como ele é.
- Monetização.

## 4. Anti-objetivos

O projeto fracassa, mesmo funcionando, se:

- Parecer um app web embrulhado, ou um app genérico de SwiftUI com as cores trocadas.
- Ficar bonito e lento: animação que trava, tela que demora, Watch que atrasa a série.
- Imitar com código próprio algo que a Apple já oferece (vidro, Live Activity, gestos, hápticos).
- Divergir das regras do openGym, a ponto de o mesmo treino dar resultados diferentes nos dois apps.
- Perder ou corromper dados de treino, ou quebrar a sincronização com um servidor openGym.
- Quebrar a licença das mídias de exercício (seção 5).
- Ter um iPhone ótimo e um Watch de segunda classe.

## 5. Restrições

- **Licença do código.** O openGym é AGPL-3.0, e o HexGym também. O código do fork fica público em
  `github.com/lipedesign/HexGym`, que se chamava `lipedesign/openGym` até 01/11/2026 (o endereço
  antigo leva ao novo). O NOTICE.md do openGym traz uma permissão extra (seção 7 da AGPL) para
  distribuir o app por lojas de apps, desde que o código continue disponível; o fork mantém essa
  permissão e o NOTICE.md.
- **Mídias de exercício (fotos e animações).** São licenciadas pela Gym visual ao openGym, fora da
  AGPL. Um fork não comercial pode manter as mídias de 180 px sem modificação, junto com o aviso do
  NOTICE.md. Por isso:
  - o HexGym usa só as mídias de 180 px do repositório, sem editar, recortar ou converter;
  - nunca usa tamanhos maiores, nunca hospeda as mídias num servidor ou CDN nosso;
  - nunca passa as mídias por nenhuma ferramenta de IA, nem para gerar imagem ou vídeo;
  - um uso comercial exigiria licença própria da Gym visual.
  As mídias somam 215 MB (6.554 fotos webp e 6.554 animações mp4).
- **Plataforma.** iOS 26 e watchOS 26 como mínimo. Xcode 27.2 estável, em `/Applications/Xcode.app`
  (usado via `DEVELOPER_DIR`). Até ele chegar, o `swift` das Command Line Tools, só para os pacotes.
- **O Watch não roda JavaScript.** O SDK do watchOS não tem JavaScriptCore; o do iPhone, do Mac e da
  Apple TV têm. Isso pesa na arquitetura (seção 8).
- **Poucas dependências.** O openGym trata isso como regra. No HexGym, nenhum pacote Swift de
  terceiros sem uma razão forte, escrita no PR.
- **Compatibilidade com o openGym.** O mesmo documento de dados, o mesmo protocolo de sincronização
  e o mesmo pareamento de aparelhos que o app do openGym usa hoje.
- **Privacidade.** Sem telemetria, sem conta de terceiros, como no openGym.
- **Texto de interface.** Simples e humano, sem travessão. O openGym tem 20 idiomas, contando o
  inglês; o HexGym começa em português do Brasil e inglês e aproveita as traduções existentes quando
  der.
- **Processo do repositório.** Não mexer no upstream (`DuarteSantos8/openGym`) nem no espelho do
  GitLab. Não commitar `data/`. Não adicionar nada em `catalogue/media/`.

## 6. Decisões do founder

### Nome e marca
- **Nome: HexGym.** "Hex" é a barra hexagonal da academia e o código das cores na tecnologia
  (#8B7BFF é o roxo do tema padrão). "Gym" deixa claro que é app de academia.
- Logotipo de texto: **HEX** em tipografia condensada pesada e caixa alta, seguido de **gym** fino.
- Testes feitos em 31/10/2026: nenhum app com esse nome na App Store dos EUA e do Brasil, só um
  projeto vazio no GitHub, `hexgym.app` e `hexgym.com.br` pareciam livres, `hexgym.com` em uso.
  Marca no INPI e no USPTO ainda não pesquisada (seção 11).

### Linguagem visual
Um sistema só, igual em todas as telas: cerca de 70% marca e 30% Apple. A proporção fala da cara do
app; quais componentes são da Apple e quais são nossos está em "Design system antes das telas".

- **Da marca:** fundo preto com um brilho da cor do tema que "respira"; títulos e números em
  tipografia condensada, sempre grandes; segmentos inclinados para o progresso da série e da semana;
  números que rolam; carimbo de recorde.
- **Da Apple:** Liquid Glass nos cartões de informação e em tudo que flutua; SF Pro nos textos de
  apoio (datas, descrições, listas); barra de abas, telas que sobem de baixo, gestos e hápticos do
  iOS; widgets, Dynamic Island e Watch no padrão Apple, com a tipografia da marca.
- **Assinatura:** o botão "Começar treino" cresce até virar a tela do treino.
- Tipografia condensada proposta: Barlow Condensed (licença SIL OFL, pode ir dentro do app).
  A escolha final sai do design system.

### Cor
Quatro temas, escolhidos pelo usuário. Estudo completo em `docs/brand/estudo-de-cor-2026-10-31.md`.

| Tema | Escuro | Claro | Observação |
|---|---|---|---|
| **Ultravioleta (padrão)** | texto #8B7BFF; botão #6F5CFF com rótulo branco; Watch e Dynamic Island #9D8CFF | #5B45E6 | nenhum app de força usa violeta |
| Giz & Ferro | #F2EFE9 com rótulo preto | #1D1D1F | preto e branco até conquistar cor |
| Ciano Glacial | #4FD8FF com rótulo preto | #00739E | apoio índigo #5E6BFF |
| Cobre Forjado | #F2895A com rótulo preto | #B0521F | apoio aço #8EA4BF |

Regras para todos os temas:
- recorde (PR) sempre em ouro: #FFC94D no escuro, #8A6100 no claro;
- erro sempre em systemRed;
- esforço sempre com número ou rótulo, além da cor;
- variantes de alto contraste definidas, cores em Display P3;
- no Watch, o anel de descanso não pode parecer um dos anéis de atividade da Apple;
- o primeiro TestFlight é só escuro (seção 11). Os valores claros valem onde o iOS força claro
  (widgets, tela bloqueada) e ficam prontos para um modo claro depois.

### Design system antes das telas
Tipografia, cores, espaçamento, componentes e movimento num sistema único, construído antes das
telas e documentado em público.

O sistema é **híbrido**: parte é da Apple, parte é nossa. Nas palavras do founder, ele "usa coisas
da Apple e algumas coisas que são nossas", como o botão e talvez um campo de entrada, onde a
personalização precisa ser maior.

Três camadas (a divisão dos exemplos é proposta do tech lead; o founder ajusta na fase 1):

| Camada | O que é | Exemplos |
|---|---|---|
| **Da Apple, como vem** | Componente do sistema, com o comportamento do sistema. A marca entra só pela cor de destaque e pela tipografia, onde a Apple deixa | navegação e transições, barra de abas, telas que sobem de baixo, menus, alertas, chaves liga/desliga, seletores, listas de ajustes, busca, ações de deslizar, SF Symbols |
| **Da Apple, com a marca** | O material ou a estrutura é da Apple; o HexGym define cor, tipografia e composição | cartões em Liquid Glass tingidos pelo tema, a escala de texto da marca sobre o Dynamic Type, widgets, Live Activity e complicações |
| **Nossos** | Desenhados e construídos pelo HexGym | botão principal e suas variações, campos de entrada do treino (carga, repetições, esforço), número que rola, segmentos inclinados, carimbo de recorde, anel de descanso, a transição de "Começar treino" |

- **Regra para decidir:** se a Apple oferece o componente e o usuário espera o comportamento do
  sistema, ele é da Apple. Vira nosso só quando é parte da identidade do HexGym, ou quando o do
  sistema não serve ao treino (por exemplo, registrar a carga com uma mão, entre séries, com pressa).
- **Nosso não é imitação:** barra de abas, telas que sobem de baixo e vidro continuam sendo os da
  Apple (seção 4).
- **Mesmo cuidado:** todo componente nosso funciona com Dynamic Type, VoiceOver, Reduzir Movimento,
  alto contraste e hápticos, e tem versão para o Watch quando fizer sentido.

### Aparelhos e distribuição
- O primeiro build de TestFlight leva **iPhone e Apple Watch juntos**.
- Distribuição: **TestFlight primeiro**, para o founder e amigos. App Store talvez depois.
- O founder já tem o Apple Developer Program pago.
- Depois do primeiro TestFlight: Mac, Apple TV e outras integrações que façam sentido.

### Como o founder acompanha
- Cada tela nova aparece rodando no simulador do iPhone e do Watch durante o trabalho.
- Cada fase termina num pull request no fork, com prints e um vídeo curto, e num build interno de
  TestFlight para o founder testar nos aparelhos dele.
- O tech lead abre os PRs e faz os merges. O founder entra nas decisões de produto e de visual.
- As decisões que são dele chegam como um pedido de decisão na issue, com as opções numeradas e a
  recomendação, e aparecem na visão "Pede você" do quadro. Ele responde numa sessão do Claude Code
  neste projeto com `/decide <issue> <opção>`, e pode juntar uma nota.

## 7. Recursos nativos

Lista de partida. Cada fase escolhe os que servem ao treino; nenhum entra só para constar.

**iPhone:** Liquid Glass; transições com zoom entre telas; Live Activity na Dynamic Island e na tela
bloqueada durante o treino e o descanso; widgets interativos na tela inicial, na tela bloqueada e
no StandBy; controles na Central de Controle (por exemplo, o descanso); botão de Ação; App Intents,
Siri, Atalhos e Spotlight ("começar treino", "registrar peso"); hápticos para cada momento do treino;
notificações locais para o fim do descanso; HealthKit (treinos, peso, medidas); modelo de linguagem
no aparelho, se o coach do openGym puder usá-lo.

**Apple Watch:** sessão de treino de verdade no HealthKit, com batimento e calorias; registrar série
pelo pulso; Double Tap para marcar a série sem tocar na tela; anel de descanso; Smart Stack;
complicações no mostrador; Live Activity do iPhone aparecendo no Watch; hápticos distintos para
descanso e recorde; funcionar longe do iPhone durante o treino.

**Depois (ecossistema):** Mac para ver histórico e gráficos numa tela grande; Apple TV para o treino
do dia na TV, talvez com o Watch mandando as séries; o que mais fizer sentido.

## 8. Arquitetura

Decisões do tech lead, a partir de um levantamento do código do openGym feito em 31/10/2026.

### 8.1 Visão geral

```
iPhone                                         Apple Watch
┌───────────────────────────────┐              ┌──────────────────────────┐
│ Telas SwiftUI (design system) │              │ Telas SwiftUI (design    │
│              │                │              │ system, versão Watch)    │
│ Modelo do app (@Observable)   │  Watch-      │ WatchCore (Swift)        │
│   │                  │        │  Connectivity│ sessão do treino,        │
│ Motor do openGym   Serviços   │◄────────────►│ descanso, esforço,       │
│ (JS no JavaScript- em Swift   │  snapshot e  │ recordes                 │
│  Core)             (dados,    │  eventos     │ HealthKit (sessão)       │
│                    sync,      │              └──────────────────────────┘
│                    HealthKit, │
│                    notificações, Live Activity, widgets)
└───────────────────────────────┘
        │ App Group: widgets, Live Activity, controles
        │ HTTPS opcional: servidor openGym auto-hospedado
```

### 8.2 O motor do openGym no iPhone

- As regras de treino ficam em JavaScript, em `frontend/src/lib`, e rodam no **JavaScriptCore** do
  iPhone. É o que garante o "mesmo motor": o mesmo código, os mesmos testes, e as atualizações do
  openGym chegam junto.
- O levantamento confirmou que isso funciona: o núcleo do `lib` já é JavaScript puro (o servidor MCP
  do openGym roda ele fora do navegador), não importa nenhum pacote npm, e carregou no JavaScriptCore
  do macOS em 14 ms. Medido sem JIT (como no iPhone), com 280 treinos: mesclar dados 7 ms, montar um
  treino 5 ms, calcular fadiga 58 ms.
- **Um script só.** O JavaScriptCore do iOS não carrega módulos, então um script de build
  (`scripts/build-hexgym-engine.mjs`, com `--check` como os outros arquivos gerados do repositório)
  junta os módulos do motor num único arquivo `HexEngine` usando o Vite que o frontend já tem, sem
  dependência nova. O arquivo gerado é versionado, para o app compilar sem Node.
- **Um contexto só, fora da thread principal.** Um único `JSContext` vive o app inteiro, dentro de um
  `actor` Swift. O documento de dados fica dentro do JS; o Swift troca JSON e modelos de tela
  pequenos, nunca o documento inteiro a cada chamada. Depois de trocar o documento (restauração,
  sincronização), o motor registra de novo exercícios personalizados e apelidos.
- **Complementos para o JavaScriptCore:** `structuredClone`, `setTimeout`/`clearTimeout` com timer
  do Swift, `console` para o log do sistema, `import.meta.env` vazio no build. `fetch` só se o coach
  entrar.
- **Mudanças pequenas no código do openGym**, cada uma testada e escrita para poder ser proposta ao
  openGym:
  - levar `DEF`, `freshState`, `draftOf`, `restoredStateFor` e `hasData` de `store/useStore.js` para
    um módulo em `lib`;
  - `coach.js` e `duration.js` importarem `i18n-core.js` em vez de `i18n.js` (que puxa React);
  - separar `plan-share.js` de `print-doc.js`.
- **Controlador de sessão novo.** A sequência do treino (começar, marcar série, escolher o descanso,
  terminar, detectar recorde) hoje está espalhada em telas React (`sheets.jsx`, `views/Workout.jsx`,
  `store/useUI.js`). Ela vira um módulo puro em `lib`, `session-controller.js`, no formato
  `(estado, ação, agora) → {estado, efeitos}`, com testes que reproduzem o comportamento atual do app
  do openGym. O app web do openGym no fork não muda. A cada atualização do openGym, essas três telas
  são comparadas para trazer qualquer mudança de regra.
- **Testes do motor:** os 117 arquivos de teste do `lib` que só usam o motor rodam também contra o
  script gerado; no Xcode, testes com casos gravados no Node conferem que o JavaScriptCore dá o mesmo
  resultado; um teste de carga roda o motor no `jsc` do macOS.

### 8.3 Dados

- A fonte da verdade é o **mesmo documento de dados do openGym** (as chaves de `gym_state_v1`), salvo
  como arquivo JSON no container do App Group, com gravação atômica e uma cópia de segurança anterior.
  A base de sincronização (`rev`, `ts`, `wid`) fica num arquivo ao lado.
- Toda mudança passa pelo motor, que carimba o horário de cada campo (`stampChange`), como no openGym.
- Widgets, Live Activity e Watch recebem resumos derivados, nunca o documento.

### 8.4 Sincronização com um servidor openGym (opcional)

- O transporte é Swift (`URLSession`); a mescla continua no motor (`mergeStates` e companhia).
- O Swift reproduz exatamente a lógica do cliente do openGym: `PUT /api/data` com `baseRev` e
  `baseWid`, até duas tentativas de mescla em caso de 409, a decisão de puxar com base em `rev`, `wid`
  e `_wids`, e a checagem de `rev` a cada 30 segundos e ao voltar para o app.
- Pareamento pelo código do servidor (`POST /api/pair/redeem`), com o token de sessão guardado no
  Keychain.
- Testes de integração contra o servidor do openGym rodando localmente.

### 8.5 Apple Watch

- O Watch não roda JavaScript. A lógica do treino no pulso é o **WatchCore**, o pacote Swift do
  openGym (sessão, supersets, recordes, esforço, contagem regressiva, inatividade), trazido para
  `apple/` com acesso público e os testes dele.
- O protocolo entre iPhone e Watch continua o do openGym: o iPhone manda um resumo (`Snapshot`, até
  48 KB) e o Watch devolve eventos (`setDone`, `start`, `finish` e outros). O lado do iPhone, que hoje
  é JavaScript dentro da página, é refeito em Swift; a montagem do resumo e a aplicação dos eventos vêm
  do motor sempre que forem funções puras. Os eventos são aplicados uma vez só, pelo id.
- O Watch treina sozinho, longe do iPhone, e sincroniza quando o iPhone volta.
- Sessão de treino no HealthKit (`HKWorkoutSession` com `HKLiveWorkoutBuilder`), Double Tap,
  complicações e Smart Stack.
- As telas do Watch são refeitas no design system.
- **Animações no Watch sem conversão.** O openGym converte as animações em GIF de 160 px para o
  Watch. O HexGym manda o arquivo original de 180 px, sem modificar, e toca com o player nativo; se o
  Watch não tocar o formato, mostra a foto original.

### 8.6 Widgets, Live Activity e controles

- O código SwiftUI de widgets, Live Activity e complicações do openGym é o ponto de partida, com IDs
  novos e o visual do HexGym.
- Os botões da Live Activity continuam como App Intents; quando o app está aberto, aplicam a ação
  direto no motor.
- Os dados vêm do App Group, montados pelo app a partir do motor.

### 8.7 Projeto, alvos e IDs

- O app do HexGym fica em `apple/`; as ferramentas dele ficam em `scripts/` e os documentos em
  `docs/`. A casca Capacitor do openGym (`frontend/ios`) não muda.
- Um projeto Xcode comum, com pastas sincronizadas, sem gerador de projeto. Alvos: `HexGym` (iPhone),
  `HexGymWidgets` (widgets, Live Activity, controles), `HexGymWatch` e `HexGymWatchWidgets`.
- Pacotes Swift locais: `HexEngine` (o motor e os complementos), `WatchCore` (iPhone e Watch),
  `HexDesign` (o design system, iPhone e Watch).
- IDs: `app.hexgym` e derivados (`app.hexgym.widgets`, `app.hexgym.watchkitapp`,
  `app.hexgym.watchkitapp.widgets`), App Group `group.app.hexgym`, esquema de URL `hexgym://`, e
  prefixo `hexgym-` nos registros do HealthKit.

### 8.8 Mídias de exercício

- As mídias são uma **camada opcional**. O app funciona e fica com cara de pronto sem elas, com uma
  arte própria no lugar (por exemplo, o mapa muscular do exercício). Com elas, mostra a foto e a
  animação.
- Quando entram, as 6.554 fotos e animações de 180 px vão dentro do app como estão, copiadas de
  `catalogue/media` por uma etapa do build, sem duplicar no Git. São 215 MB.
- Foto em WebP pelo decodificador do sistema, animação em MP4 pelo AVPlayer em loop.
- O aviso da Gym visual diz que as mídias são "strictly for use within the openGym application" e
  que terceiros não podem colocá-las em apps independentes; o mesmo NOTICE.md permite que um fork
  não comercial mantenha as de 180 px. Um app nativo com outro nome pode ser visto como app
  independente. Por isso, decisão do founder (seção 11): as mídias não entram no build dos amigos
  até o Duarte dar o ok. Até lá, o app usa a arte própria.
- **Corpo muscular próprio.** Dois corpos nossos, masculino e feminino, feitos na Meshy e presos ao
  mesmo esqueleto de movimento, com 36 regiões musculares por lado e os mesmos ids nos dois. As
  regiões acendem por exercício com os pesos do openGym (primário 1, secundário 0,4); Watch e
  widgets usam os 18 grupos do openGym. Em 31/10/2026 o founder escolheu o acabamento **flat** (cor
  chapada com uma sombra). Clay e linha ficam no backlog, prontos para voltar: o corpo e as divisas
  são os mesmos, muda só o material.
- **Qual corpo aparece:** o app pergunta na primeira abertura, e a pessoa troca no perfil.
- O mapa dos músculos vem do MuscleMap (MIT, Melih Colpan) e precisa de crédito na tela de
  licenças. Os scripts que constroem os corpos ficam em `scripts/hexbody/`, e a pesquisa por trás
  deles em `docs/research/`.

### 8.9 Idiomas

- O openGym guarda as traduções como módulos JS chaveados pelo texto em inglês. Uma etapa do build
  gera JSON delas para o motor e para as telas Swift, que leem os mesmos pacotes. Assim os 20 idiomas
  vêm de graça onde o texto é o mesmo.
- Textos novos do HexGym ficam num pacote próprio em `apple/`, por cima dos do openGym, para não
  mexer nos arquivos de tradução do upstream.

### 8.10 Build, testes e TestFlight

- `xcodebuild` com assinatura automática no time do founder.
- **Xcode estável para os amigos.** A Apple não aceita no TestFlight externo um build feito com Xcode
  beta. Os amigos entram como testadores externos, por um link público do TestFlight, sem precisar
  virar usuários da conta; para isso o build sai do Xcode estável e passa pela revisão de beta da
  Apple. O Xcode 27 beta fica só para builds internos, se algum recurso do iOS 27 for usado.
- Os builds de TestFlight saem desta máquina: arquivo, exportação e envio pela API do App Store
  Connect, com uma chave que o founder cria.
- No GitHub Actions, num workflow próprio do HexGym (seção 9.1): a checagem do script do motor, os
  testes do motor e os `swift test` dos pacotes. Se o runner não tiver o Xcode 27, o build do app é
  conferido aqui a cada PR.

### 8.11 Git e as atualizações do openGym

- Git Flow no fork: `develop` integra; `main` recebe uma versão no fim de cada fase, com tag e build
  interno de TestFlight, e o TestFlight externo sai de uma dessas tags; `feature/*`, `release/*` e
  `hotfix/*` como de costume (seção 9.1). PRs sempre para o fork.
- De tempos em tempos, um PR `sync/opengym-<data>`, com a etiqueta `upstream`, traz o `upstream/main`
  para `develop`, gera de novo o script do motor, roda todos os testes, compara as telas de treino do
  openGym (8.2) e compara o WatchCore de `frontend/ios/App/WatchCore` com a cópia em `apple/` (8.5).
- Esse PR entra com merge normal, nunca squash. Um squash deixaria os commits do openGym fora da
  história de `develop`, e o sync seguinte voltaria a dar conflito no que já veio.

### 8.12 Convivência com o openGym

Decisões do tech lead depois da revisão do documento:

- **Tema:** o tema do HexGym fica guardado só no aparelho. O HexGym não escreve `theme` nem `accent`
  no documento compartilhado, para não mudar a aparência do app do openGym de quem usa os dois.
  A cor personalizada e os temas sazonais do openGym não vêm para o HexGym; ícones alternativos,
  um por tema, ficam para a fase 6.
- **Treino em andamento:** fica no aparelho onde começou, como no openGym (o servidor descarta o
  `active` a cada envio). O que precisa bater entre os dois apps são os treinos terminados.
- **Apple Health:** o HexGym marca os registros com o prefixo `hexgym-` e não reenvia ao Health o
  histórico importado. Quem usar o openGym e o HexGym ao mesmo tempo, os dois gravando no Health,
  verá treinos em dobro; a tela de ajustes avisa.
- **Qual openGym copiar:** a paridade do primeiro TestFlight é com a versão do openGym em vigor no
  começo da fase 3. O openGym planeja um motor de progressão novo e treinos em circuito (AMRAP, EMOM,
  Tabata) para a v1.4.7, no fim de dezembro: as regras chegam sozinhas pelo motor; as telas novas
  entram na fase 5 ou depois. Toda função nova do openGym entra no escopo por padrão.

### 8.13 Metas de desempenho

- Marcar uma série reflete na tela em menos de 100 ms.
- Transições e números que rolam sem perder quadro, a 120 Hz nos iPhones com ProMotion.
- O app abre na tela inicial em menos de 1 segundo num iPhone recente.
- Chamadas ao motor nunca na thread principal; cálculos pesados (recuperação, gráficos) guardados em
  cache e medidos num iPhone real com um histórico grande.

## 9. Fases

Proposta do tech lead. Cada fase vira um milestone no GitHub, com as issues no Project HexGym (seção
9.1), e termina numa versão: o PR de `release/<versão>` para `main`, com prints, vídeo curto e um
build interno de TestFlight. O plano detalhado de cada fase sai depois deste documento.

| Fase | Entrega | O founder vê |
|---|---|---|
| **0. Fundação** | O GitHub montado (seção 9.1): issues, o Project, os milestones, as etiquetas, os modelos de issue e PR, a branch `develop`, a proteção das branches e os workflows herdados desligados; projeto Xcode em `apple/` com os quatro alvos compilando; IDs, App Group e assinatura; o motor do openGym rodando no iPhone com testes de contrato; leitura e gravação do documento de dados; build automatizado e a CI | O quadro do Project com as fases e as issues; o app abre no simulador e no iPhone dele, ainda sem telas, com um build interno no TestFlight |
| **1. Design system** | Cores dos quatro temas no escuro (com alto contraste e Display P3; o claro só onde o iOS força), tipografia, espaçamento, movimento e hápticos; as três camadas do sistema híbrido (seção 6), com os componentes nossos: botão principal, campos de entrada do treino, número que rola, segmentos inclinados, carimbo de recorde, anel de descanso, e o cartão de vidro com a marca. Versões para iPhone e Watch. Uma galeria dentro do app e a documentação pública | A galeria rodando, com as três camadas lado a lado, e a troca de tema ao vivo |
| **2. Biblioteca e rotinas** | Primeira abertura (unidade, tema, corpo), os 5.632 exercícios com busca, filtros e a arte própria no lugar das mídias (o corpo muscular com as regiões de cada exercício), criação e edição de rotinas e planos, ajustes básicos | Montar a própria rotina no app |
| **3. Treino no iPhone** | Tela inicial, a transição de "Começar treino", a tela do treino (séries, carga, repetições, esforço, supersets), descanso com notificação e hápticos, Live Activity e Dynamic Island com botões, fim do treino com recorde e progressão aplicada, histórico; Siri para começar o treino | Um treino completo no iPhone |
| **4. Apple Watch** | App do Watch no design system, sessão de treino do HealthKit, registro pelo pulso, Double Tap, anel de descanso, complicações e Smart Stack, conversa com o iPhone, treino longe do iPhone | Um treino completo no Watch, com o iPhone no bolso ou longe |
| **Primeiro TestFlight externo** | iPhone e Watch juntos, para os amigos | |
| **5. O resto do openGym** | Peso e medidas, estatísticas e gráficos, mapa muscular e recuperação, importação (Strong, Hevy, CSV), backup e exportação, sincronização com servidor openGym e pareamento, programas, coach, desafios, lembrete de academia | O app inteiro, igual em funções ao openGym |
| **6. Mais do iPhone** | Widgets interativos (tela inicial, bloqueada, StandBy), controles da Central de Controle, botão de Ação, Spotlight e Atalhos completos | O HexGym espalhado pelo sistema |
| **Depois** | Mac, Apple TV e outras integrações do ecossistema | |

As fases 5 e 6 podem trocar de ordem ou correr juntas. O recurso nativo que é parte de um momento
do treino (Live Activity, hápticos, Siri para começar) entra junto com esse momento, não numa fase
separada.

### 9.1 O pipeline no GitHub e o agente

Todo o trabalho passa pelo GitHub do fork (`lipedesign/HexGym`), num caminho só, e é feito por
agentes de IA com o tech lead orquestrando. O founder acompanha pelo quadro e entra nas decisões
que são dele. Nas palavras do founder: "no final do dia vai ser tudo feito por AI".

A base é o relentless, um plugin do Claude Code ativado só neste projeto, com o orquestrador, os
agentes (implementador, QA, revisor isolado, documentador) e as regras de cada passo. O HexGym usa o
orquestrador do relentless como ele vem, sem outro por cima. Onde o relentless e este documento
divergem, valem as decisões em `docs/decisions/`: o Git Flow abaixo, o squash nas features e a Task
do plano como critério de aceite.

**Onde o trabalho mora**

- **Project "HexGym"** no GitHub ([quadro](https://github.com/users/lipedesign/projects/6), privado),
  com cinco colunas: A fazer, Pronto para começar, Em andamento, Em revisão, Feito. Três visões: Fase
  atual (o quadro do milestone em andamento; o filtro troca quando a fase muda), Todas as fases e
  Pede você (o que está aberto com `human:pending` ou `state:blocked`). O estado que vale é a
  etiqueta `state:*` da issue, que o cartão mostra. As colunas andam pelas automações do próprio
  Project, já ligadas (a issue que entra, o PR ligado a ela, a issue fechada e o PR com merge), e
  nenhum script espelha as etiquetas nelas. Pôr uma issue em Feito fecha a issue.
- **Um milestone por fase** (fases 0 a 6), mais um para o primeiro TestFlight externo, cada um com
  as issues da fase.
- **Issues pequenas:** cada uma cabe num PR. O modelo de tarefa pede o que fazer, por quê, como saber
  que está pronto e, quando houver, o que o founder vê; o de bug pede os passos, onde aconteceu, o
  aparelho com o sistema e a versão do app.
- **Etiquetas** de tipo (`enhancement`, `bug`, `documentation`, `investigation` e `epic`, do
  relentless, mais `chore` e `upstream`), de área (`motor`, `dados`, `sync`, `watch`,
  `design-system`, `widgets`, `build`, `acessibilidade`) e de estado, do relentless: uma só entre
  `state:todo`, `state:in-progress`, `state:review`, `state:done` e `state:blocked`, mais
  `human:pending` enquanto a issue espera o founder. `upstream` é o trabalho de trazer as mudanças
  do openGym original; `sync` é a sincronização com um servidor openGym.
- **O plano de cada fase** é escrito antes de a fase começar, em `docs/superpowers/plans/`, e vira
  as issues do milestone: cada Task, uma issue, sub-issue do épico da fase. O milestone ganha a seção
  Outcome, e o critério de aceite de cada issue é a Task dela no plano.

**O caminho de uma issue**

```
issue (state:todo)
  → worktree e branch feature/<número>-<nome>, a partir de develop
  → código e testes → PR para develop, com "Closes #<número>"
  → QA (checagens e o app rodando) → revisão isolada de outro agente
  → CI verde → merge em develop (squash) → state:done, Feito
fim da fase → release/<versão>, a partir de develop → build interno no TestFlight
  → o founder vê e aprova (/decide) → merge em main, com a tag v<versão> → PR de main para develop
```

- `develop` é a branch padrão do fork: os PRs já abrem contra ela, e o "Closes #<número>" fecha a
  issue no merge (o GitHub só fecha a issue no merge na branch padrão).
- `main` e `develop` são protegidas, também para a conta admin: só recebem PR, sem force push e sem
  apagar a branch. Os checks obrigatórios são o `tests-ok` e, quando o workflow do HexGym nascer na
  fase 0, o `hexgym-ok` (veja "Onde roda"). Torná-los obrigatórios muda a proteção, uma parada do
  relentless: o founder dá o ok no pedido da issue #3, junto com o clique que liga as Actions do
  fork. Até lá, nenhum check roda, e o que garante um PR é a revisão isolada. Depois da #3, com ou
  sem a proteção, o agente confere os checks pelo nome antes de cada merge.
- O merge de uma feature em `develop` é do agente, em squash, quando a CI passa e a revisão isolada
  aprova o último commit do PR (`review:approved`).
- Entram com merge normal, para guardar a história: o PR de sync com o openGym (seção 8.11) e as
  versões. `release/*` sai de `develop` e `hotfix/*` sai de `main`; as duas entram em `main`, e um PR
  de `main` para `develop` traz a versão de volta. A branch é apagada depois do merge; `main` e
  `develop`, protegidas, ficam.
- PR que muda o visual leva prints, e um vídeo curto quando há movimento, sem as imagens e animações
  de exercício da Gym visual.

**O que o agente faz sozinho**

Pega a próxima issue pronta do milestone atual, cria a worktree e a branch, escreve o código e os
testes, roda as checagens, abre o PR, faz o QA, pede a revisão isolada de outro agente, corrige o que
ela apontar, faz o merge em `develop`, troca a etiqueta de estado (o quadro acompanha) e fecha a
issue. Abre issues novas quando acha um problema, como sub-issues do épico da fase, e decide a ordem
do trabalho dentro da fase (seção 10).

**Quando ele para e chama o founder**

- decisão de visual ou de produto;
- tudo que envolva dinheiro, contas, loja ou falar com o Duarte, e o primeiro envio ao TestFlight;
- o texto público do projeto (README e afins);
- as paradas do relentless: um ADR, segredos e credenciais, a proteção das branches, apagar branch
  ou reescrever histórico, e publicar num registro;
- o fim de cada fase, com o PR, os prints, o vídeo curto e o build interno de TestFlight;
- quando trava de verdade, depois de tentar os caminhos que tem.

Cada parada é um pedido de decisão na issue: a pergunta, o contexto, as opções numeradas e a
recomendação. A issue ganha `human:pending` e `state:blocked`, aparece em "Pede você", e o agente
segue em outra issue. O founder responde com `/decide <issue> <opção>`, com uma nota se quiser; um
passo que é só dele (um clique, uma instalação) vem com a opção "feito". O agente nunca responde por
ele.

O chamado aparece na conversa com o tech lead e como comentário na issue ou no PR.

**Onde roda**

- Os agentes rodam nesta máquina, onde estão o Xcode, a assinatura e o simulador. O GitHub Actions
  confere o que não precisa de assinatura (seção 8.10).
- Os workflows herdados do openGym que publicam ou atendem o projeto original (espelho do GitLab,
  imagens Docker, demo no GitHub Pages, CLA, auditoria semanal, checagem de release) ficam
  desligados no fork pelo próprio GitHub, sem apagar os arquivos, para o sync com o openGym não ter
  conflito.
- Os testes do openGym continuam: o `test.yml`, cujo resumo, o job `tests-ok`, é check obrigatório,
  e o `ios.yml`, que compila a casca do openGym quando um PR mexe nela. Os dois olham só o código do
  openGym: num PR só do HexGym, o `tests-ok` fica verde sem rodar nada.
- As checagens do HexGym (seção 8.10) ficam num workflow próprio, `.github/workflows/hexgym.yml`, que
  o openGym não tem e por isso não dá conflito no sync. O resumo dele, o job `hexgym-ok`, também vira
  check obrigatório em `main` e `develop`, com o mesmo ok do founder. Ele nasce na fase 0, com o
  projeto Xcode (issue #9).
- Os modelos de issue e de PR do fork são do HexGym. No sync com o openGym, conflito neles fica com a
  versão do HexGym: um modelo que o fork apagou e o openGym mudou volta como conflito, resolvido com
  `git rm`, e um modelo novo do openGym também é apagado no sync.

## 10. O que fica com o tech lead

Sem precisar voltar ao founder, a não ser que mude o que ele vê:

- a divisão exata de módulos, pacotes e arquivos; os nomes internos;
- a lista de módulos do motor, os complementos e a forma de chamar o motor;
- a ordem das tarefas dentro de cada fase, e trocar as fases 5 e 6 de lugar;
- a estratégia de testes, a CI e a medição de desempenho;
- como tocar as animações no Watch, dentro da regra das mídias;
- os detalhes de cada componente e animação, mostrados ao founder no simulador antes de seguir.

Voltam ao founder: a tipografia final, qualquer mudança no visual aprovado, recursos novos que mudem
o que o usuário vê, e tudo que envolva dinheiro, contas, loja ou falar com o Duarte.

## 11. Pendências fora do código

**Perguntas fechadas em 31/10/2026.** Saíram da revisão do documento; o founder aceitou as
recomendações do tech lead:

1. **Mídias no build dos amigos:** não entram antes de o Duarte dar o ok. O app sai com a arte
   própria (seção 8.8).
2. **Histórico no openGym:** ninguém tem histórico confirmado para trazer desde o começo, então a
   importação de backup fica na fase 5. Se aparecer, ela vem para a fase 2.
3. **Só escuro ou também claro:** só escuro no primeiro TestFlight. As cores ficam preparadas para
   um modo claro depois; os valores claros valem onde o iOS força claro (widgets, tela bloqueada).
4. **Qual corpo muscular:** o app pergunta na primeira abertura e deixa trocar no perfil.
5. **O agente no dia a dia:** faz sozinho o trabalho das issues até o merge em `develop`, e para e
   chama o founder nas decisões dele, no fim de cada fase e quando trava (seção 9.1).

**Fora do código, com o founder:**

- **Marca registrada:** pesquisar HexGym no INPI e no USPTO antes de investir na marca.
- **Domínios:** o founder registra `hexgym.app` e `hexgym.com.br`.
- **Nome no App Store Connect:** o founder cria o registro do app "HexGym" no App Store Connect na
  fase 0. Isso reserva o nome na loja e é preciso para o TestFlight.
- **Chave da API do App Store Connect:** o founder cria na fase 0, para os builds saírem desta
  máquina (seção 8.10).
- **Xcode estável:** o founder instala o Xcode estável nesta máquina (pede o Apple ID dele) antes do
  primeiro TestFlight externo. Hoje só existe o Xcode 27 beta.
- **Licença e o Duarte:** a permissão extra do NOTICE.md fala do "openGym mobile application", e não
  está claro se cobre um fork com outro nome. Para o TestFlight com amigos o risco é baixo. Antes de
  uma App Store pública, conversar com o Duarte (autor do openGym) sobre o fork e o uso das mídias;
  uma publicação comercial exigiria licença própria das mídias na Gym visual.
- **Pacotes de animação em alta resolução:** os do openGym ficam na conta dele no App Store Connect e
  não servem ao HexGym. O HexGym fica com as mídias de 180 px.
