# O gerador de regiões

Para cada exercício do catálogo do openGym, as regiões do corpo do HexGym (o modelo v2, 36 regiões
pintadas por lado) que acendem como primárias e secundárias, e a ênfase quando o texto do
exercício diz algo a mais. O app acende o corpo a partir daqui.

| Arquivo | O que é |
|---|---|
| `build_exercise_regions.py` | o gerador |
| `exercise_regions_v2.json` | a saída: uma linha por id, 6.554 chaves (os 5.632 exercícios e os 922 desenhos femininos, que copiam as regiões do exercício pelo `variantOf`) |
| `regions_v2.json` | as 36 regiões, com o nome em português, o grupo no corpo e o grupo que o Watch mostra |
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
python3 -I scripts/hexbody/regions/build_exercise_regions.py           # grava os dois JSON
python3 -I scripts/hexbody/regions/build_exercise_regions.py --check   # confere, sem gravar nada
python3 -I scripts/hexbody/regions/run_tests.py                        # os testes
```

O `--check` sai com 1 quando um JSON não bate com o que sairia do catálogo, e diz o arquivo e o
exercício (ou a região). Quando o catálogo muda, rode o gerador e commite os dois JSON junto. O
`--report` imprime as contagens das notas da pesquisa. O `--out <pasta>` troca a pasta dos dois
JSON, e só os testes do `--check` usam.

A parte `scripts` do `node scripts/hexgym/check.mjs` roda o `--check` ("regiões em dia") e os
testes ("testes do gerador de regiões"). O workflow do HexGym da issue #9, quando entrar, roda o
`check.mjs` e, com ele, as duas rodadas.

## A ênfase

A ênfase são as sub-regiões que o texto livre nomeia dentro de um grupo que está inteiro no
primário (o alvo "pectorals" com o secundário "upper chest" dá `upperChest`). Ela sai depois das
regras por nome, só com as regiões que estão no primário, e é descartada quando cobre todas as
regiões de um grupo do primário ou quando fica igual ao primário, porque aí não diz nada a mais.
Nas abduções sentadas (0597 e 3006, e os desenhos 3611 e 3005), o glúteo máximo, que as regras
mandam para o secundário, fica fora da ênfase.

## De onde veio

O gerador e os dois JSON nasceram na pesquisa do corpo muscular, em
`docs/research/research_notes/Sistema muscular para o HexGym/`, e vieram para cá na issue #12. A v1
(29 regiões por lado, `exercise_regions.json`) fica na história do git. As regras e as escolhas
estão no relatório `docs/research/reports/Sistema muscular para o HexGym.md` e na nota
`catalogo_para_modelo.md` da pesquisa.
