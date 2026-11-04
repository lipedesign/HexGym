<h1 align="center">
  <img src="/.github/readme/hero.webp" alt="HexGym: mesmo motor, outra experiência. App nativo de treino de força. Um fork do openGym para iPhone e Apple Watch, feito em SwiftUI: as regras de treino são as mesmas, mudam o visual, o movimento e a marca. Selo: conceito de design, o app está em construção. Ao lado, o conceito da tela do treino no iPhone: Push A aos 24:10, supino reto na série 2 de 4, 80 kg por 8 repetições com o carimbo de recorde, a última vez com 77,5 kg por 8, que subiu pela progressão, e o descanso de 1:30, com o desenvolvimento a seguir.">
</h1>

<p align="center">
  App nativo de treino de força para iPhone e Apple Watch, feito em SwiftUI.
</p>

<p align="center">
  <a href="https://github.com/DuarteSantos8/openGym">Fork do openGym</a> ·
  <a href="https://github.com/lipedesign/HexGym/milestones">As fases</a> ·
  <a href="https://github.com/users/lipedesign/projects/6">O quadro (privado)</a> ·
  <a href="https://github.com/lipedesign/HexGym/blob/develop/docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md">Documento de design</a> ·
  <a href="https://github.com/lipedesign/HexGym/blob/develop/LICENSE">Licença AGPL-3.0</a>
</p>

> [!NOTE]
> Em construção, e ainda não há app para baixar. Na fundação (fase 0), o app já existe no Xcode e traz o motor do openGym: ele abre no simulador com o motor carregado e cria ou abre o documento de dados, ainda sem telas. O que falta nela depende do founder: a CI, o registro do app no App Store Connect, o TestFlight e a versão 0.1.0. No design system (fase 1), as cores, a tipografia, o movimento, os componentes e a [documentação](/docs/hexgym/design-system/README.md) já entraram, e faltam a galeria dentro do app, a versão do Apple Watch e o ícone. As imagens desta página mostram o conceito de design, feito em HTML, e não o app rodando.

## O que é

O HexGym é um fork do [openGym](https://github.com/DuarteSantos8/openGym), o app open source de treino de força. Ele segue as mesmas regras de treino do openGym (exercícios, progressão de carga, 1RM estimado, recuperação e sincronização), guarda os dados no mesmo formato e recebe as melhorias quando o openGym evolui. O que muda é a experiência: as telas, o movimento, o Apple Watch, os widgets e os recursos nativos do iPhone.

![Três pilares. 5.632, o motor do openGym, inteiro: os 5.632 exercícios, a progressão de carga, o 1RM estimado, a recuperação e a sincronização seguem as regras do openGym, e quando ele evolui, o HexGym recebe. 100%, nativo de verdade: SwiftUI do começo ao fim, com Liquid Glass, Dynamic Island, Live Activity, widgets, Apple Watch, Siri e vibrações; quando a Apple oferece um recurso, ele é usado em vez de imitado. 1, marca e design system próprios: tipografia, cores, espaçamento, componentes e movimento num sistema único, construído antes das telas e documentado em público.](/.github/readme/pilares.webp)

## A cara do app

Quatro temas para a mesma tela inicial, com o Ultravioleta como padrão. Em todos eles, três cores têm papel fixo: o recorde é sempre ouro, o erro é sempre vermelho, e o esforço aparece sempre com número, não só com cor.

![A tela inicial em quatro iPhones, um por tema: Ultravioleta, o padrão, Giz & Ferro, Ciano Glacial e Cobre Forjado. Cada tela mostra a data, terça-feira, 3 de novembro, a saudação Olá, Lipe, o treino de hoje, Push A, com um boneco de peito e ombros acesos na cor do tema, peito, ombros e tríceps em 55 minutos, o botão Começar treino, o peso de 78,4 kg, 0,3 kg a menos na semana, a semana 3 de 4, com 4 semanas seguidas, e o treino de amanhã, Pull A. Embaixo, as três regras: recorde sempre em ouro, erro sempre em vermelho, esforço sempre com número, além da cor.](/.github/readme/temas.webp)

O descanso entre as séries vai aparecer também fora do app, na Dynamic Island do iPhone e no Apple Watch.

![O descanso de 1:12 na Dynamic Island, com o supino na série 3 de 4, e o mesmo descanso no Apple Watch.](/.github/readme/pulso.webp)

## As fases

Cada fase é um marco no GitHub e termina numa versão. O primeiro TestFlight externo, para os amigos, leva o iPhone e o Apple Watch juntos.

![As fases em ordem: 0, Fundação; 1, Design system; 2, Biblioteca e rotinas; 3, Treino no iPhone; 4, Apple Watch; TF, o primeiro TestFlight externo; 5, O resto do openGym; 6, Mais do iPhone; e, depois, Mac e Apple TV. A legenda separa as fases até o primeiro TestFlight, o TestFlight para os amigos, com iPhone e Apple Watch juntos, e as fases depois dele.](/.github/readme/fases.webp)

| Fase | O que entra | Estado |
| --- | --- | --- |
| [0. Fundação](https://github.com/lipedesign/HexGym/milestone/1) | O repositório e o jeito de trabalhar, o projeto do Xcode e o motor do openGym rodando no iPhone, ainda sem telas | Em andamento: falta o que depende do founder |
| [1. Design system](https://github.com/lipedesign/HexGym/milestone/2) | As cores dos quatro temas, tipografia, espaçamento, movimento e vibrações, os componentes próprios e uma galeria dentro do app | Em andamento: faltam a galeria, o Watch e o ícone |
| [2. Biblioteca e rotinas](https://github.com/lipedesign/HexGym/milestone/3) | A primeira abertura, os 5.632 exercícios com busca, filtros e arte própria, e a criação de rotinas e planos | A fazer |
| [3. Treino no iPhone](https://github.com/lipedesign/HexGym/milestone/4) | A tela inicial, o treino com séries, carga e descanso, a Live Activity na Dynamic Island, o recorde, a progressão e o histórico | A fazer |
| [4. Apple Watch](https://github.com/lipedesign/HexGym/milestone/5) | O treino pelo pulso, com o anel de descanso, as complicações e o treino longe do iPhone | A fazer |
| [Primeiro TestFlight externo](https://github.com/lipedesign/HexGym/milestone/6) | iPhone e Apple Watch juntos, para os amigos | A fazer |
| [5. O resto do openGym](https://github.com/lipedesign/HexGym/milestone/7) | Peso e medidas, gráficos, mapa muscular e recuperação, importação, backup e a sincronização com um servidor openGym | A fazer |
| [6. Mais do iPhone](https://github.com/lipedesign/HexGym/milestone/8) | Widgets interativos, Central de Controle, botão de Ação, Spotlight e Atalhos | A fazer |
| Depois | Mac, Apple TV e outras integrações | Sem data |

## Como é feito

- O app vai ser escrito em SwiftUI. As regras de treino continuam em JavaScript, em `frontend/src/lib`, como no openGym: um script junta esses módulos num arquivo só, o HexEngine, que o app vai rodar pelo JavaScriptCore. Assim os dois apps vão usar o mesmo código e os mesmos testes, e as atualizações do openGym vão chegar junto.
- O trabalho anda por issues, com um [marco por fase](https://github.com/lipedesign/HexGym/milestones), e segue o Git Flow: tudo entra na `develop` por pull request, e cada fase termina numa versão na `main`. As issues de todas as fases ficam no [quadro do projeto](https://github.com/users/lipedesign/projects/6), que é privado: quem não é do projeto vê uma página de erro, e os marcos mostram as mesmas issues.
- Como uma issue chega ao merge, as regras do pull request e o papel do relentless estão no [CONTRIBUTING](/.github/CONTRIBUTING.md). Para avisar de uma falha de segurança sem abrir issue pública, veja o [SECURITY](/.github/SECURITY.md).
- O código é escrito com o [Claude Code](https://claude.com/claude-code) e o plugin [relentless](https://github.com/marcelusfernandes/relentless). Cada pull request passa por QA e por uma revisão isolada antes do merge, e as decisões que duram ficam em [`docs/decisions`](https://github.com/lipedesign/HexGym/tree/develop/docs/decisions).
- O [documento de design](https://github.com/lipedesign/HexGym/blob/develop/docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md) diz o que o HexGym vai ser, as fases e as decisões tomadas até aqui.
- A marca usa a fonte [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed), sob a SIL Open Font License 1.1.

## Como compilar

Hoje o app compila e abre no simulador do iPhone, ainda sem telas, e o app do Watch compila ao lado dele. Para isso, é preciso um Mac com:

- o Xcode 27.2, o estável, em `/Applications/Xcode.app`, e um simulador de iPhone com iOS 26 ou mais novo. O Xcode beta não serve: a Apple não aceita no TestFlight externo um build feito com ele, e os scripts do HexGym nunca o escolhem;
- o Node 22, a versão que o openGym usa.

Depois de clonar, na pasta do repositório:

```bash
cd frontend && npm ci
cd ..
node scripts/hexgym/check.mjs
```

O `npm ci` instala o que o frontend do openGym usa, e a parte do motor precisa dele. O `check.mjs` é o comando de teste do HexGym: o QA roda o mesmo comando, e a CI do HexGym vai rodar o mesmo quando entrar. Ele roda as cinco partes, nesta ordem:

| Parte | O que confere |
| --- | --- |
| `scripts` | Os testes dos scripts do HexGym |
| `engine` | O script do motor e os casos gravados em dia, e os testes do openGym rodando contra o script do motor |
| `load` | O teste de carga do motor no JavaScriptCore |
| `packages` | O `swift test` dos pacotes HexEngine, HexStore e HexDesign |
| `app` | O build do app e do Watch, e os testes do app no simulador |

Uma parte roda sozinha pelo nome, como `node scripts/hexgym/check.mjs app`, e o `node scripts/hexgym/check.mjs --list` mostra os comandos sem rodar nada.

Os comandos do HexGym escolhem o Xcode pelo `DEVELOPER_DIR`, e não pelo `xcode-select`, que pode apontar para outro. O `node scripts/hexgym/xcode.mjs` diz qual Xcode eles usam. Para compilar o app à mão, sem assinatura:

```bash
DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) xcodebuild -project apple/HexGym.xcodeproj -scheme HexGym -destination "generic/platform=iOS Simulator" -derivedDataPath apple/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Licença

O código segue a licença do openGym, a AGPL-3.0 ([LICENSE](https://github.com/lipedesign/HexGym/blob/develop/LICENSE)). O [NOTICE.md](https://github.com/lipedesign/HexGym/blob/develop/NOTICE.md) traz uma permissão extra (seção 7 da AGPL) para distribuir o app do openGym por lojas como a App Store, desde que o código-fonte continue disponível sob a AGPL.

As fotos e as animações dos exercícios são licenciadas pela Gym visual ao openGym e ficam fora da AGPL. O NOTICE.md permite que um fork não comercial mantenha as versões de 180 px, sem modificação e com o aviso dele, e é só isso que este repositório guarda. As mídias não podem ser usadas para treinar sistemas de IA, alimentá-los ou fazer pedidos a eles, nem como base para gerar imagens, animações ou vídeos. Qualquer outro uso exige licença própria da [Gym visual](https://gymvisual.com/).
