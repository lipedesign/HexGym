# O gerador de regiões

Para cada exercício do catálogo do openGym, as regiões do corpo do HexGym (o modelo v2, 36 regiões
pintadas por lado) que acendem como primárias e secundárias, e a ênfase quando o texto do
exercício diz algo a mais. O app acende o corpo a partir daqui.

| Arquivo | O que é |
|---|---|
| `build_exercise_regions.py` | o gerador |
| `exercise_regions_v2.json` | a saída: uma linha por id, 6.554 chaves (os 5.632 exercícios e os 922 desenhos femininos, que copiam as regiões do exercício pelo `variantOf`) |
| `regions_v2.json` | as 36 regiões, com o nome em português, o grupo no corpo e o grupo que o Watch mostra |
| `apple/Packages/HexBody/Sources/HexBody/Resources/exercise-regions.json` | o JSON compacto que o app lê, no pacote HexBody (abaixo) |
| `test_build_exercise_regions.py` | os testes (`unittest`) |
| `run_tests.py` | roda os testes e grava a conta para o `scripts/hexgym/check.mjs` |

## O que ele lê

Só texto: `catalogue/exercises/*.json`, o `SECONDARY_ADDITIONS` de `frontend/src/lib/exercises.js` e
as listas de termos de `scripts/catalogue/validate.mjs`. Nunca abre nada de `catalogue/media/`: as
fotos e animações são licenciadas da Gym visual e não podem ser abertas, copiadas, convertidas nem
passadas a uma ferramenta de IA. A mídia e as regiões se ligam só pelo id do exercício.

Python 3 da máquina, sempre com `-I`, e só a biblioteca padrão.

## Os dois comandos

Da raiz do repositório:

```sh
python3 -I scripts/hexbody/regions/build_exercise_regions.py           # grava os três JSON
python3 -I scripts/hexbody/regions/build_exercise_regions.py --check   # confere, sem gravar nada
python3 -I scripts/hexbody/regions/run_tests.py                        # os testes
```

O `--check` sai com 1 quando um JSON não bate com o que sairia do catálogo, e diz o arquivo e o
exercício, com o id e o nome (ou a região). Quando o catálogo muda, rode o gerador e commite os
três JSON junto. O `--report` imprime as contagens das notas da pesquisa. O `--out <pasta>` troca
a pasta dos dois JSON desta pasta, e o `--app <arquivo>`, o caminho do JSON do app; só os testes
do `--check` usam os dois.

## O JSON do app

O gerador também grava o `exercise-regions.json` do pacote HexBody (issue #95), que o app lê pelo
`RegionCatalog`. É compacto, sem espaço, com uma linha por região e por exercício para o diff
mostrar o que mudou:

```
{"regions":[
{"id":"upperTrapezius","group":"trapezius","watchGroup":"trapezius"},
...
],"exercises":{
"0025":[[8,9],[3,7,16,17],[]],
...
}}
```

As regiões vão na ordem do `regions_v2.json`, sem o nome (o pacote tem os nomes em português e em
inglês no `Regions.strings`), e o `watchGroup` é `null` no pescoço. Cada exercício tem três listas,
o primário, o secundário e a ênfase, com o índice de cada região, sem o nome e sem a fonte. Os 922
desenhos femininos entram pelo id deles, com as regiões do exercício de que são o desenho.

A parte `scripts` do `node scripts/hexgym/check.mjs` roda o `--check` ("regiões em dia") e os
testes ("testes do gerador de regiões"). O workflow do HexGym da issue #9, quando entrar, roda o
`check.mjs` e, com ele, as duas rodadas.

## As regras por nome

Depois do catálogo, duas levas de regras pelo nome do exercício mudam o primário e o secundário:
as da v2 (panturrilha sentada, cabeça longa do tríceps, rosca martelo e inversa, abdução, pescoço)
e as da tabela "A evidência confirma o banco inclinado e derruba o abdômen inferior" do relatório
(issue #13: o banco inclinado, reto e declinado, o desenvolvimento, a elevação lateral, o
deltoide posterior, o encolhimento, a elevação em "Y", os oblíquos, a prancha lateral com
abdução, o agachamento, a adução e a elevação de pernas). Cada regra da tabela troca o primário e
o secundário pelos dela, e só o agachamento guarda os secundários que já tinha; as regiões que o
texto nomeia uma a uma (manguito, braquial, glúteo médio) ficam no secundário. Uma regra só vale
quando o primário é o grupo que ela espera, então um exercício com outro alvo, ou que junta dois
movimentos (a flexão com remada, o agachamento com desenvolvimento), fica como estava. A flexão
inclinada ou declinada não é o banco e fica fora das regras do peito. Cada regra tem um teste com
exercícios reais do catálogo.

Depois das regras, o abdômen baixo nunca acende sozinho: com ele no primário, o reto abdominal
vai junto para o primário; com ele só no secundário, vai junto para o secundário (o 2770 hip
flexion, issue #106).

## As correções do catálogo

O `CATALOGUE_FIXES` do gerador troca, pelo id, campos que o catálogo tem errados, antes de tudo e
sem mexer no `catalogue/`. Hoje é um só: o 0459 flutter kicks tem o alvo "glutes", mas a descrição
fala do abdômen baixo e dos flexores do quadril, e as outras versões (1179 e 1244) têm o alvo
"abs" (issue #106).

## A ênfase

A ênfase são as sub-regiões que o texto livre nomeia dentro de um grupo que está inteiro no
primário (o alvo "pectorals" com o secundário "upper chest" dá `upperChest`). Ela sai do primário
de depois das regras por nome (o braquial na rosca martelo, por exemplo), nunca com o abdômen
baixo, que não acende sozinho, e é descartada quando cobre todas as regiões de um grupo do
primário ou quando fica igual ao primário, porque aí não diz nada a mais. Nas abduções sentadas
(0597 e 3006, e os desenhos 3611 e 3005), o glúteo máximo, que as regras mandam para o
secundário, fica fora da ênfase. Na rosca martelo, o bíceps também fica fora dela (1615).

## De onde veio

O gerador e os dois JSON nasceram na pesquisa do corpo muscular, em
`docs/research/research_notes/Sistema muscular para o HexGym/`, e vieram para cá na issue #12. A v1
(29 regiões por lado, `exercise_regions.json`) fica na história do git. As regras e as escolhas
estão no relatório `docs/research/reports/Sistema muscular para o HexGym.md` e na nota
`catalogo_para_modelo.md` da pesquisa.
