<h1 align="center">
  <img src="/.github/readme/hero.webp" alt="HexGym: mesmo motor, outra experiência. App nativo de treino de força. Um fork do openGym para iPhone e Apple Watch, feito em SwiftUI: as regras de treino são as mesmas, mudam o visual, o movimento e a marca. Selo: conceito de design, o app está em construção. Ao lado, o conceito da tela do treino no iPhone: Push A aos 24:10, supino reto na série 2 de 4, 80 kg por 8 repetições com o carimbo de recorde, a última vez com 77,5 kg por 8, que subiu pela progressão, e o descanso de 1:30, com o desenvolvimento a seguir.">
</h1>

<p align="center">
  App nativo de treino de força para iPhone e Apple Watch, feito em SwiftUI.
</p>

<p align="center">
  <a href="https://github.com/DuarteSantos8/openGym">Fork do openGym</a> ·
  <a href="https://github.com/lipedesign/HexGym/milestones">As fases</a> ·
  <a href="https://github.com/lipedesign/HexGym/blob/develop/docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md">Documento de design</a> ·
  <a href="https://github.com/lipedesign/HexGym/blob/develop/LICENSE">Licença AGPL-3.0</a>
</p>

> [!NOTE]
> Em construção. A fundação (fase 0) e o design system (fase 1) estão em andamento, e ainda não há app para baixar. As imagens desta página mostram o conceito de design, feito em HTML, e não o app rodando.

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
| [0. Fundação](https://github.com/lipedesign/HexGym/milestone/1) | O repositório e o jeito de trabalhar, o projeto do Xcode e o motor do openGym rodando no iPhone, ainda sem telas | Em andamento |
| [1. Design system](https://github.com/lipedesign/HexGym/milestone/2) | As cores dos quatro temas, tipografia, espaçamento, movimento e vibrações, os componentes próprios e uma galeria dentro do app | Em andamento |
| [2. Biblioteca e rotinas](https://github.com/lipedesign/HexGym/milestone/3) | A primeira abertura, os 5.632 exercícios com busca, filtros e arte própria, e a criação de rotinas e planos | A fazer |
| [3. Treino no iPhone](https://github.com/lipedesign/HexGym/milestone/4) | A tela inicial, o treino com séries, carga e descanso, a Live Activity na Dynamic Island, o recorde, a progressão e o histórico | A fazer |
| [4. Apple Watch](https://github.com/lipedesign/HexGym/milestone/5) | O treino pelo pulso, com o anel de descanso, as complicações e o treino longe do iPhone | A fazer |
| [Primeiro TestFlight externo](https://github.com/lipedesign/HexGym/milestone/6) | iPhone e Apple Watch juntos, para os amigos | A fazer |
| [5. O resto do openGym](https://github.com/lipedesign/HexGym/milestone/7) | Peso e medidas, gráficos, mapa muscular e recuperação, importação, backup e a sincronização com um servidor openGym | A fazer |
| [6. Mais do iPhone](https://github.com/lipedesign/HexGym/milestone/8) | Widgets interativos, Central de Controle, botão de Ação, Spotlight e Atalhos | A fazer |
| Depois | Mac, Apple TV e outras integrações | Sem data |

## Como é feito

- O app vai ser escrito em SwiftUI. As regras de treino continuam em JavaScript, em `frontend/src/lib`, como no openGym: um script junta esses módulos num arquivo só, o HexEngine, que o app vai rodar pelo JavaScriptCore. Assim os dois apps vão usar o mesmo código e os mesmos testes, e as atualizações do openGym vão chegar junto.
- O trabalho anda por issues, com um [marco por fase](https://github.com/lipedesign/HexGym/milestones), e segue o Git Flow: tudo entra na `develop` por pull request, e cada fase termina numa versão na `main`.
- O código é escrito com o [Claude Code](https://claude.com/claude-code) e o plugin [relentless](https://github.com/marcelusfernandes/relentless). Cada pull request passa por QA e por uma revisão isolada antes do merge, e as decisões que duram ficam em [`docs/decisions`](https://github.com/lipedesign/HexGym/tree/develop/docs/decisions).
- O [documento de design](https://github.com/lipedesign/HexGym/blob/develop/docs/superpowers/specs/2026-10-31-hexgym-native-app-design.md) diz o que o HexGym vai ser, as fases e as decisões tomadas até aqui.
- A marca usa a fonte [Barlow Condensed](https://fonts.google.com/specimen/Barlow+Condensed), sob a SIL Open Font License 1.1.

## Licença

O código segue a licença do openGym, a AGPL-3.0 ([LICENSE](https://github.com/lipedesign/HexGym/blob/develop/LICENSE)). O [NOTICE.md](https://github.com/lipedesign/HexGym/blob/develop/NOTICE.md) traz uma permissão extra (seção 7 da AGPL) para distribuir o app do openGym por lojas como a App Store, desde que o código-fonte continue disponível sob a AGPL.

As fotos e as animações dos exercícios são licenciadas pela Gym visual ao openGym e ficam fora da AGPL. O NOTICE.md permite que um fork não comercial mantenha as versões de 180 px, sem modificação e com o aviso dele, e é só isso que este repositório guarda. As mídias não podem ser usadas para treinar sistemas de IA, alimentá-los ou fazer pedidos a eles, nem como base para gerar imagens, animações ou vídeos. Qualquer outro uso exige licença própria da [Gym visual](https://gymvisual.com/).
