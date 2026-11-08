#!/usr/bin/env python3
"""Gera exercise_regions_v2.json: para cada exercício do catálogo do openGym, as regiões do
corpo do HexGym (o modelo v2, 36 regiões pintadas por lado) que acendem como primárias (cor do
tema) e secundárias (40% dela). Grava também regions_v2.json, a tabela das 36 regiões, e o JSON
compacto que o app lê, exercise-regions.json no pacote HexBody (issue #95).

    python3 -I scripts/hexbody/regions/build_exercise_regions.py           grava os dois JSON ao lado deste script
                                                                           e o do app no pacote HexBody
    python3 -I scripts/hexbody/regions/build_exercise_regions.py --check   não grava nada; sai com 1, dizendo o
                                                                           arquivo e o exercício, quando um JSON
                                                                           não bate com o que sairia do catálogo
    python3 -I scripts/hexbody/regions/build_exercise_regions.py --report  também imprime as contagens das notas

--out <pasta> troca a pasta dos dois JSON, e --app <arquivo>, o caminho do JSON do app (os testes
do --check usam uma pasta temporária para os três).

O JSON do app: {"regions": [{"id", "group", "watchGroup"}], "exercises": {"<id>": [primário,
secundário, ênfase]}}, as regiões na ordem do regions_v2.json e cada lista com os índices delas,
sem o nome e sem a fonte. Os desenhos femininos entram pelo id deles, com as regiões do exercício.
Só biblioteca padrão. A v1 (29 regiões por lado, exercise_regions.json) ficou na história do git.

Só lê texto (catalogue/exercises/*.json, frontend/src/lib/exercises.js e
scripts/catalogue/validate.mjs). Nunca abre nada de catalogue/media/: as imagens e animações
são licenciadas da Gym visual e não podem ser lidas nem passadas a ferramentas de IA. O nome do
arquivo de mídia é o id do exercício (media/still/<id>.webp, media/clip/<id>.mp4), então a
junção mídia -> músculos é pela chave do JSON, sem abrir mídia nenhuma.

Precedência, igual à do app (frontend/src/lib/muscles.js, weightsOf):
  1. "muscleMap": o muscleMap curado do catálogo. Com "weights", eles mandam (1 = primário,
     0 < w < 1 = secundário, 0 = associação explícita sem crédito, não acende). Sem weights,
     valem as listas primaries/secondaries. O muscleMap só fala em grupos (vocabulário do mapa
     2D); um grupo é estreitado para as sub-regiões que o texto livre do mesmo exercício nomeia,
     quando o texto só nomeia sub-partes daquele grupo (ex.: alvo "lats" -> só upperBack).
  2. "curated": texto livre mais o SECONDARY_ADDITIONS de exercises.js (sem muscleMap).
  3. "freetext": target -> primário; secondaryMuscles -> secundário.
  4. "bodypart": nada desenhável no texto; usa BY_BODYPART de muscles.js (maior peso ->
     primário, demais -> secundário). O app nunca chega aqui para exercícios do catálogo,
     porque conta "cardiovascular system" como pseudo-músculo; o modelo 3D não desenha isso.

Campos extras opcionais:
  "emphasis": sub-regiões que o texto livre nomeia dentro de um grupo que está inteiro no
              primário (ex.: alvo "pectorals" + secundário "upper chest" -> ["upperChest"]).
              Sai do primário de depois das regras por nome (as da v2 e as da pesquisa, #13),
              nunca com o abdômen baixo, e é descartada quando cobre todas as regiões de um
              grupo do primário ou quando fica igual ao primário, porque aí não diz nada a
              mais. É uma dica de ênfase, não muda primary/secondary.
  "variantOf": o id é um desenho (figura feminina) de outro exercício; regiões copiadas dele.
"""
import argparse
import collections
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[3]
CATALOGUE = ROOT / 'catalogue' / 'exercises'
EXERCISES_JS = ROOT / 'frontend' / 'src' / 'lib' / 'exercises.js'
VALIDATE_MJS = ROOT / 'scripts' / 'catalogue' / 'validate.mjs'
EXERCISE_JSON = 'exercise_regions_v2.json'
REGIONS_JSON = 'regions_v2.json'
# O JSON que o app lê, no pacote HexBody, gravado e conferido junto com os dois desta pasta.
APP_JSON = ROOT / 'apple' / 'Packages' / 'HexBody' / 'Sources' / 'HexBody' / 'Resources' / 'exercise-regions.json'
APP_LISTS = ('primary', 'secondary', 'emphasis')   # as três listas de cada exercício, nessa ordem

# A v1 do modelo, base de que a v2 parte (as tabelas da v2 trocam estas mais abaixo, em _use_v2).
# Os 18 grupos do app (ordem cabeça-pés de MUSCLES em muscles.js) e as regiões do MuscleMap.
# Atenção: "chest", "deltoids", "quadriceps" e "trapezius" são ao mesmo tempo nome de grupo
# (no app) e de UMA região (no modelo). Aqui uma região "chest" sozinha é só o peitoral médio.
GROUP_REGIONS = {
    'trapezius': ['upperTrapezius', 'trapezius', 'lowerTrapezius'],
    'deltoids': ['frontDeltoid', 'deltoids', 'rearDeltoid'],
    'chest': ['upperChest', 'chest', 'lowerChest'],
    'upper-back': ['upperBack', 'rhomboids', 'rotatorCuff'],
    'serratus': ['serratus'],
    'biceps': ['biceps'],
    'triceps': ['triceps'],
    'forearm': ['forearm'],
    'abs': ['upperAbs', 'lowerAbs'],
    'obliques': ['obliques'],
    'lower-back': ['lowerBack'],
    'gluteal': ['gluteal'],
    'quadriceps': ['quadriceps', 'innerQuad', 'outerQuad'],
    'hamstring': ['hamstring'],
    'adductors': ['adductors'],
    'hip-flexors': ['hipFlexors'],
    'calves': ['calves'],
    'tibialis': ['tibialis'],
}
V1_GROUP_REGIONS = GROUP_REGIONS
REGION_ORDER = [r for regions in GROUP_REGIONS.values() for r in regions]
GROUP_OF = {r: g for g, regions in GROUP_REGIONS.items() for r in regions}

G = GROUP_REGIONS
# Todo termo que o catálogo usa em "target" e "secondaryMuscles" -> regiões. [] = não desenhável.
TERM_REGIONS = {
    # alvos (target)
    'abs': G['abs'],
    'pectorals': G['chest'],
    'biceps': G['biceps'],
    'glutes': G['gluteal'],
    'delts': G['deltoids'],
    'triceps': G['triceps'],
    'upper back': G['upper-back'],
    'lats': ['upperBack'],
    'calves': G['calves'],
    'quads': G['quadriceps'],
    'forearms': G['forearm'],
    'hamstrings': G['hamstring'],
    'spine': G['lower-back'],
    'traps': G['trapezius'],
    'adductors': G['adductors'],
    'serratus anterior': G['serratus'],
    'abductors': G['gluteal'],             # glúteo médio/mínimo: o modelo só tem "gluteal"
    'levator scapulae': ['upperTrapezius'],  # fica sob o trapézio superior; pescoço é pele
    'cardiovascular system': [],
    # secundários (secondaryMuscles)
    'shoulders': G['deltoids'],
    'deltoids': G['deltoids'],
    'rear deltoids': ['rearDeltoid'],
    'rotator cuff': ['rotatorCuff'],
    'chest': G['chest'],
    'upper chest': ['upperChest'],
    'brachialis': G['biceps'],             # sem região própria; o app também manda para bíceps
    'wrists': G['forearm'],
    'wrist flexors': G['forearm'],
    'wrist extensors': G['forearm'],
    'grip muscles': G['forearm'],
    'back': G['upper-back'],               # genérico; o app manda para upper-back
    'latissimus dorsi': ['upperBack'],
    'rhomboids': ['rhomboids'],
    'trapezius': G['trapezius'],
    'lower back': G['lower-back'],
    'core': G['abs'],                      # o app manda "core" só para abs (sem oblíquos)
    'abdominals': G['abs'],
    'obliques': G['obliques'],
    'lower abs': ['lowerAbs'],
    'hip flexors': G['hip-flexors'],
    'quadriceps': G['quadriceps'],
    'inner thighs': G['adductors'],
    'groin': G['adductors'],
    'soleus': G['calves'],                 # sem região própria (gastrocnêmio e sóleo juntos)
    'shins': G['tibialis'],
    'ankles': [], 'ankle stabilizers': [], 'feet': [], 'hands': [],
    'sternocleidomastoid': [],             # pescoço é pele no modelo
}


def is_subpart(term):
    """True quando o termo acende só parte de um grupo (ex.: "upper chest", "lats")."""
    regions = TERM_REGIONS[term]
    return bool(regions) and set(regions) < set(G[GROUP_OF[regions[0]]])


# ---------------------------------------------------------------- modelo v2

# v2: sete regiões novas por lado. O manguito passa a contar no ombro (como no app) e o redondo
# maior, separado, nas costas. "neck" é grupo só do boneco: no Watch e no widget fica inerte.
V2_GROUP_REGIONS = {
    'trapezius': ['upperTrapezius', 'trapezius', 'lowerTrapezius'],
    'deltoids': ['frontDeltoid', 'deltoids', 'rearDeltoid', 'rotatorCuff'],
    'chest': ['upperChest', 'chest', 'lowerChest'],
    'upper-back': ['upperBack', 'teresMajor', 'rhomboids'],
    'serratus': ['serratus'],
    'biceps': ['biceps', 'brachialis'],
    'triceps': ['tricepsLongHead', 'triceps'],
    'forearm': ['forearm'],
    'abs': ['upperAbs', 'lowerAbs'],
    'obliques': ['obliques'],
    'lower-back': ['lowerBack'],
    'gluteal': ['gluteal', 'gluteusMedius'],
    'quadriceps': ['quadriceps', 'innerQuad', 'outerQuad'],
    'hamstring': ['hamstring'],
    'adductors': ['adductors'],
    'hip-flexors': ['hipFlexors'],
    'calves': ['calves', 'soleus'],
    'tibialis': ['tibialis'],
    'neck': ['sternocleidomastoid', 'neckBack'],
}
V2_NEW = ['gluteusMedius', 'soleus', 'brachialis', 'teresMajor', 'sternocleidomastoid', 'neckBack', 'tricepsLongHead']
# Quando o muscleMap nomeia o grupo e o texto não estreita, estas regiões NÃO acendem sozinhas:
# só por nome (manguito, braquial, glúteo médio). O resto do grupo acende inteiro.
V2_BY_NAME_ONLY = {'rotatorCuff', 'brachialis', 'gluteusMedius'}
V2_HEADS = ['frontDeltoid', 'deltoids', 'rearDeltoid']
V2_TERM_CHANGES = {
    'delts': V2_HEADS, 'shoulders': V2_HEADS, 'deltoids': V2_HEADS,
    'biceps': ['biceps'],
    'brachialis': ['brachialis'],
    'glutes': ['gluteal'],
    'abductors': ['gluteusMedius'],
    'soleus': ['soleus'],
    'lats': ['upperBack', 'teresMajor'],
    'latissimus dorsi': ['upperBack', 'teresMajor'],
    'sternocleidomastoid': ['sternocleidomastoid'],
    'levator scapulae': ['neckBack'],
}
# Nome no app (os 18 grupos do Watch e do widget) e nome em português de cada região pintada.
V2_REGION_PT = {
    'upperTrapezius': 'Trapézio superior', 'trapezius': 'Trapézio médio', 'lowerTrapezius': 'Trapézio inferior',
    'frontDeltoid': 'Deltoide frontal', 'deltoids': 'Deltoide lateral', 'rearDeltoid': 'Deltoide posterior',
    'rotatorCuff': 'Manguito rotador', 'upperChest': 'Peito alto', 'chest': 'Peito médio', 'lowerChest': 'Peito baixo',
    'upperBack': 'Dorsal', 'teresMajor': 'Redondo maior', 'rhomboids': 'Romboides', 'serratus': 'Serrátil anterior',
    'biceps': 'Bíceps', 'brachialis': 'Braquial', 'tricepsLongHead': 'Tríceps, cabeça longa',
    'triceps': 'Tríceps, cabeças lateral e medial', 'forearm': 'Antebraço', 'upperAbs': 'Reto abdominal',
    'lowerAbs': 'Abdômen baixo', 'obliques': 'Oblíquo externo', 'lowerBack': 'Lombar',
    'gluteal': 'Glúteo máximo', 'gluteusMedius': 'Glúteo médio', 'quadriceps': 'Reto femoral',
    'innerQuad': 'Vasto medial', 'outerQuad': 'Vasto lateral', 'hamstring': 'Posterior de coxa',
    'adductors': 'Adutores', 'hipFlexors': 'Flexores do quadril', 'calves': 'Gastrocnêmio', 'soleus': 'Sóleo',
    'tibialis': 'Tibial anterior', 'sternocleidomastoid': 'Esternocleidomastóideo',
    'neckBack': 'Nuca (esplênios e levantador da escápula)',
}
V2_DEFAULT = {}   # grupo -> regiões quando o muscleMap nomeia o grupo sem estreitar (preenchido em _use_v2)


def _use_v2():
    """Troca as tabelas do módulo pelas da v2 (as funções leem os globais na hora da chamada).
    Roda uma vez só, ao importar: a v2 é o modelo do app."""
    global GROUP_REGIONS, REGION_ORDER, GROUP_OF, G, TERM_REGIONS
    GROUP_REGIONS = V2_GROUP_REGIONS
    REGION_ORDER = [r for regions in GROUP_REGIONS.values() for r in regions]
    GROUP_OF = {r: g for g, regions in GROUP_REGIONS.items() for r in regions}
    G = GROUP_REGIONS
    old = TERM_REGIONS
    TERM_REGIONS = {}
    for t, regs in old.items():   # termo que apontava para um grupo inteiro aponta para o grupo v2
        whole = next((g for g, rr in V1_GROUP_REGIONS.items() if regs and set(regs) == set(rr)), None)
        TERM_REGIONS[t] = list(G[whole]) if whole else list(regs)
    TERM_REGIONS['rotator cuff'] = ['rotatorCuff']
    TERM_REGIONS.update(V2_TERM_CHANGES)
    V2_DEFAULT.update({g: [r for r in rr if r not in V2_BY_NAME_ONLY] for g, rr in G.items()})


_use_v2()


NECK_SIDE = re.compile(r'side|lateral|inclination')


def curl_kind(n):
    """'hammer' ou 'reverse' quando o nome é uma rosca martelo ou inversa de braço; None fora disso.
    A rosca de perna fica fora pelo "leg curl", não por "leg" solto: as roscas com toalha presa
    nas pernas (3830, 3850, 3851 e 3831) são roscas de braço (#13)."""
    if not re.search(r'\bcurl', n) or re.search(r'wrist|\bleg curl|hamstring|calf|nordic|toe', n):
        return None
    return 'hammer' if 'hammer' in n else 'reverse' if 'reverse' in n else None


def v2_name_rules(e, p, s):
    """Regras por nome da v2 (relatório, seção de regras). Mudam primário e secundário."""
    n = e['name'].lower()
    stretch = 'stretch' in n or e.get('category') == 'stretching'
    if re.search(r'abduct', n) and 'gluteusMedius' in p and 'gluteal' in p:
        p.discard('gluteal'); s.add('gluteal')                         # abdução: médio, não máximo
    # Joelho dobrado: sóleo. "sitting" e "toe raise" entraram na #13 (o 9509, lever sitting toe raise).
    if re.search(r'(seated|sitting).*(calf|toe raise)|calf.*(seated|sitting)', n) and not stretch and 'calves' in p:
        p.discard('calves'); p.add('soleus'); s.add('calves')
    if e['target'] == 'triceps' and re.search(r'overhead|french|behind (the )?head|above head', n) and not stretch:
        if 'triceps' in p:
            p.discard('triceps'); p.add('tricepsLongHead'); s.add('triceps')
    kind = curl_kind(n)
    if kind == 'hammer':
        p |= {'brachialis', 'forearm'}
    elif kind == 'reverse':
        if 'biceps' in p:
            p.discard('biceps'); s.add('biceps')
        p |= {'brachialis', 'forearm'}
    if e['bodyPart'] == 'neck' and not stretch:
        flex, ext = 'flexion' in n, 'extension' in n or 'bridge' in n
        if NECK_SIDE.search(n) and (flex or re.search(r'raise|lifting|bend', n)):
            p.clear(); p |= {'sternocleidomastoid', 'neckBack'}
        elif flex and ext:
            p.clear(); p |= {'sternocleidomastoid', 'neckBack'}
        elif flex:
            p.clear(); p.add('sternocleidomastoid'); s.clear()
        elif ext:
            p.clear(); p.add('neckBack'); s.clear(); s.add('upperTrapezius')
    s -= p
    return p, s


# ---------------------------------------------------------------- regras por nome da pesquisa

# A tabela "A evidência confirma o banco inclinado e derruba o abdômen inferior" do relatório
# (docs/research/reports/Sistema muscular para o HexGym.md), como a issue #13 a fixou. Cada regra
# troca o primário e o secundário pelos da tabela; só o agachamento guarda os secundários que já
# tinha. As regiões que o texto do catálogo nomeia uma a uma (V2_BY_NAME_ONLY: o manguito no face
# pull, por exemplo) ficam no secundário. Cada regra só vale quando o primário é o grupo que ela
# espera: um exercício com outro alvo, ou que junta dois movimentos, fica como estava.
CHEST = frozenset(G['chest'])
HEADS = frozenset(V2_HEADS)
TRAPS = frozenset(G['trapezius'])
UPPER_BACK = frozenset(G['upper-back'])
ABS = frozenset(G['abs'])
LEGS = frozenset(G['quadriceps'] + G['adductors'] + ['gluteal'])

CHEST_MOVE = re.compile(r'bench press|chest press|floor press|\bpress\b|\bpress[- ]?ups?\b|push[- ]?ups?\b'
                        r'|\bfly\b|\bflyes?\b|\bflys\b|cross[- ]?over|pec (deck|dec)\b')
CHEST_FLY = re.compile(r'\bfly\b|\bflyes?\b|\bflys\b|cross[- ]?over|pec (deck|dec)\b')
PUSH_UP = re.compile(r'push[- ]?ups?\b|\bpress[- ]?ups?\b')
# O giro do tronco corta (twisting, rotational push up, "with twist"); o do punho não (twisted fly,
# twist press, rotational grip). A flexão pliométrica (plyo, clap) e a archer seguem como flexão.
# O push press é o desenvolvimento com o impulso das pernas, não o supino: fica fora (1851, #106).
CHEST_COMBO = re.compile(r'\bto\b|\band\b|\bplus\b|jump|burpee|\bwalk|\btaps?\b|crawl|\brows?\b|\brotation\b'
                         r'|twisting|\btwist\b(?! (fly|press))|rotational(?! grip)|spider|pike|hindu|\bdive|depth'
                         r'|superman|plank|\bdips?\b|pull|lunge|\bjack|kick|toe touch|raise|thrust|bridge|tuck'
                         r'|bird dog|child pose|slide|push press')
# O cabo de baixo para cima, de cima para baixo, e o nome que já diz a parte: ficam fora da regra do reto.
CHEST_ANGLED = re.compile(r'upper chest|lower chest|low chest|\blow (fly|crossover)|\bhigh (fly|crossover)')
INCLINE, DECLINE = re.compile(r'\bincline\b'), re.compile(r'\bdecline\b')
ANGLE = re.compile(r'(\d+)\s*(?:°|degrees?)')
OVERHEAD_PRESS = re.compile(r'shoulders? press|overhead press|military press|arnold press|push press|pike press'
                            r'|behind (the )?neck press|bradford|\bz press|viking press|strict press|landmine (\w+ )*press')
# Com o deltoide inteiro no primário, um "press" sem outra palavra também é o desenvolvimento
# (dumbbell seated alternate press, kettlebell seesaw press, e no plural o standing plate presses,
# 1225); o supino, o pallof e a planche não. Revista com o catálogo de 08/11/2026 (#106): os 20
# que ela pega a mais que o OVERHEAD_PRESS são desenvolvimentos pela descrição.
OVERHEAD_PLAIN = re.compile(r'\bpress(es)?\b')
OVERHEAD_COMBO = re.compile(r'clean|thruster|lunge|squat(?! cage)|\bto\b|\band\b|devil|external rotation|cuban'
                            r'|side bend|plank|incline|kick|face down|bench press|pallof|planche')
LATERAL_RAISE = re.compile(r'lateral raises?|side raises?|side lateral|lateral delt raise')
LATERAL_COMBO = re.compile(r'rear|front|plank|\bto\b|\band\b|lunge|squat|bent over')
REAR_DELT = re.compile(r'rear delt|rear deltoid|deltoid rear|reverse delt|reverse fly|reverse flye|revers fly|rear fly'
                       r'|rear lateral|face pull|reverse pec|bent over .*lateral raise')
REAR_COMBO = re.compile(r'plank|\bto\b|\band\b|wake up|lunge|step')
SHRUG = re.compile(r'\bshrugs?\b')
# Encolhimento para baixo ou para trás (nas paralelas, pendurado, invertido, reverso) não é o trapézio superior.
SHRUG_OTHER = re.compile(r'inverted|parallel bars|hanging|reverse|horizontal')
Y_RAISE = re.compile(r'\by[- ]?(raises?|lateral raises?|elevation)\b')
ROTATION = re.compile(r'\btwists?\b|russian twist|wood ?chop|woodchopper|\bchop\b|(torso|trunk) rotation')
ROTATION_COMBO = re.compile(r'crunch|sit[- ]?up|jackknife|raise|push|squat|lunge|single leg|leg lift|\brows?\b|press|step'
                            r'|jump|toe touch')
SIDE_PLANK = re.compile(r'side plank|side bridge|lateral (side )?plank')
SIDE_PLANK_ABDUCTION = re.compile(r'abduct|leg (raise|lift)|raised leg|clam|glute raise|\bstar\b')
SIDE_PLANK_COMBO = re.compile(r'push|\brows?\b|\bfly\b|raise|pull|adduct|reach')
SQUAT = re.compile(r'\bsquats?\b')
SQUAT_COMBO = re.compile(r'split|bulgarian|single|one[- ]leg|one arm|pistol|sissy|hack|skater|cossack|curtsey|shrimp'
                         r'|lunge|jump|plyo|thrust|jack|jerk|clean|snatch|get up|press|\brows?\b|curl|raise|deadlift'
                         r'|good morning|wood ?chop|twist|hold|walk|hop|kick|punch|reach|rotation|step|\bto\b|\band\b'
                         r'|burpee|wall|ball|pulse|lateral|side(?! pov)|shuffle|abduct|knees?\)|on knees|kneeling'
                         r'|tip toe|with (calf|arms|heel|band|reach|rotation|twist|knee|leg|hip)'
                         r'|pull|hip flexion|reverse squat')
SQUAT_MACHINES = {'leverage machine', 'sled machine', 'assisted'}
HIP_ADDUCTION = re.compile(r'\badduct(ion|ors?)\b')
ADDUCTION_COMBO = re.compile(r'plank|squat|press|thrust|scapular|shoulder|\barm\b|wrist')
# A elevação de quadril deitado (lying flat, incline, leg and hip) é o mesmo enrolar da pelve da reverse crunch.
LEG_RAISE = re.compile(r'\b(leg|legs|knee|knees)[- ](hip )?raises?\b|leg-hip raise|reverse crunch|toes to bar'
                       r'|knees to elbows|\bleg lift|lying flat hip raise|incline hip raise|leg and hip raise')
LEG_RAISE_COMBO = re.compile(r'oblique|twist|side|plank|press|military|step|lunge|squat|curl|push|circle|dragon'
                             r'|(?<!reverse )crunch|\bto\b(?! bar| elbows)')


def incline_level(n):
    """'baixo' (até cerca de 30°) ou 'alto' (45° ou mais) pelo nome; None sem "incline" ou entre os dois.
    Sem ângulo no nome é 'baixo', a não ser que o nome diga "shoulders press": aí o banco está alto."""
    if not INCLINE.search(n):
        return None
    m = ANGLE.search(n)
    if m:
        angle = int(m.group(1))
        return 'alto' if angle >= 45 else 'baixo' if angle <= 30 else None
    return 'alto' if re.search(r'shoulders? press', n) else 'baixo'


def research_name_rules(e, p, s):
    """As regras por nome do relatório da pesquisa (issue #13). Mudam primário e secundário.
    Rodam depois das regras da v2 e antes da ênfase."""
    n = e['name'].lower()
    if 'stretch' in n or e.get('category') in ('stretching', 'mobility'):
        return p, s
    keep = s & V2_BY_NAME_ONLY   # o que o texto nomeia uma a uma fica, se a regra não puser no primário

    def rule(primary, secondary):
        return set(primary), (set(secondary) | keep) - set(primary)

    level = incline_level(n)
    # Peito: o banco decide a parte. Supino e flexão levam o tríceps; o crucifixo não.
    if level == 'alto' and p in (CHEST, HEADS) and (CHEST_MOVE.search(n) or OVERHEAD_PRESS.search(n)) \
            and not CHEST_COMBO.search(n) and not PUSH_UP.search(n):
        return rule({'frontDeltoid'}, {'upperChest'} | (set() if CHEST_FLY.search(n) else {'triceps'}))
    if p == CHEST and CHEST_MOVE.search(n) and not CHEST_COMBO.search(n) and not CHEST_ANGLED.search(n):
        fly = bool(CHEST_FLY.search(n))
        if PUSH_UP.search(n) and 'elevated' in n:
            return p, s   # a flexão com as mãos no alto é a flexão inclinada (3812)
        if INCLINE.search(n) or DECLINE.search(n):
            # A flexão inclinada ou declinada não é o banco, e entre 30° e 45° não há regra: ficam como estavam.
            tri = set() if fly else {'triceps'}
            if PUSH_UP.search(n):
                return p, s
            if level == 'baixo':
                return rule({'upperChest'}, {'frontDeltoid'} | tri)
            if DECLINE.search(n) and not INCLINE.search(n):
                return rule({'lowerChest', 'chest'}, {'frontDeltoid'} | tri)
            return p, s
        tri = set() if fly else {'triceps', 'tricepsLongHead'}
        return rule({'chest', 'lowerChest'}, {'upperChest', 'frontDeltoid'} | tri)   # sai o lateral e o posterior
    # Ombro e trapézio.
    if p == HEADS and (OVERHEAD_PRESS.search(n) or OVERHEAD_PLAIN.search(n)) and not OVERHEAD_COMBO.search(n):
        return rule({'frontDeltoid'}, {'deltoids', 'triceps', 'upperTrapezius'})
    if p in (HEADS, UPPER_BACK, TRAPS) and Y_RAISE.search(n):
        return rule({'lowerTrapezius'}, {'deltoids'})
    if p == HEADS and LATERAL_RAISE.search(n) and not LATERAL_COMBO.search(n):
        return rule({'deltoids'}, {'rearDeltoid', 'upperTrapezius'})
    if p in (HEADS, UPPER_BACK) and REAR_DELT.search(n) and not REAR_COMBO.search(n):
        return rule({'rearDeltoid'}, {'rhomboids', 'trapezius'})
    if p == TRAPS and SHRUG.search(n) and not SHRUG_OTHER.search(n):
        return rule({'upperTrapezius'}, set())
    # Tronco: a prancha lateral com abdução vai para o glúteo médio; sem abdução, e as rotações, oblíquos.
    if SIDE_PLANK.search(n) and SIDE_PLANK_ABDUCTION.search(n) and p in (ABS, {'gluteusMedius'}):
        return rule({'gluteusMedius'}, {'gluteal', 'obliques'})
    if p == ABS and ((SIDE_PLANK.search(n) and not SIDE_PLANK_COMBO.search(n))
                     or (ROTATION.search(n) and not ROTATION_COMBO.search(n))):
        return rule({'obliques'}, {'upperAbs'})
    if p == ABS and LEG_RAISE.search(n) and not LEG_RAISE_COMBO.search(n):
        return rule({'hipFlexors', 'upperAbs', 'lowerAbs'}, set())   # o abdômen baixo nunca sozinho
    # Pernas.
    if p and p <= LEGS and p & (LEGS - set(G['adductors'])) and SQUAT.search(n) and not SQUAT_COMBO.search(n) \
            and e.get('category') in ('strength', 'calisthenics', 'olympic') and e.get('equipment') not in SQUAT_MACHINES:
        legs = {'outerQuad', 'innerQuad', 'gluteal', 'adductors'}
        return legs, (s | p | {'quadriceps'}) - legs   # o reto femoral só no secundário
    if p == {'adductors'} and HIP_ADDUCTION.search(n) and not ADDUCTION_COMBO.search(n):
        return rule({'adductors'}, set())
    return p, s


def lower_abs_never_alone(p, s):
    """O abdômen baixo nunca acende sozinho (relatório, #13): com ele no primário, o reto abdominal
    também vai para o primário; com ele só no secundário, o reto abdominal vai junto para o
    secundário, como a elevação de pernas faz no primário (0459 e 2770, #106)."""
    if 'lowerAbs' in p:
        p.add('upperAbs')
    elif 'lowerAbs' in s and 'upperAbs' not in p:
        s.add('upperAbs')
    s -= p
    return p, s


def regions_v2_rows():
    """Cada região pintada da v2, seu grupo no boneco e o grupo que o Watch mostra."""
    return [{'region': r, 'name': V2_REGION_PT[r], 'group': g, 'watchGroup': None if g == 'neck' else g,
             'new': r in V2_NEW} for g, rr in V2_GROUP_REGIONS.items() for r in rr]


def regions_text(rows):
    """O texto de regions_v2.json, com as linhas de regions_v2_rows()."""
    return json.dumps(rows, ensure_ascii=False, indent=1) + '\n'


# BY_BODYPART de muscles.js (fallback do app), com os mesmos pesos.
BY_BODYPART = {
    'chest': {'chest': 1},
    'back': {'upper-back': 0.75, 'lower-back': 0.25},
    'shoulders': {'deltoids': 1},
    'upper arms': {'biceps': 0.5, 'triceps': 0.5},
    'lower arms': {'forearm': 1},
    'waist': {'abs': 0.7, 'obliques': 0.3},
    'upper legs': {'quadriceps': 0.4, 'hamstring': 0.35, 'gluteal': 0.25},
    'lower legs': {'calves': 0.8, 'tibialis': 0.2},
    'neck': {'trapezius': 1},
    'full body': {'chest': 0.2, 'upper-back': 0.2, 'gluteal': 0.2, 'quadriceps': 0.2, 'hamstring': 0.1, 'abs': 0.1},
    'cardio': {},
}


def ordered(regions):
    s = set(regions)
    return [r for r in REGION_ORDER if r in s]


def read_vocabulary():
    """TARGETS e SECONDARY de validate.mjs: falha se surgir um termo que este script não conhece."""
    src = VALIDATE_MJS.read_text(encoding='utf-8')
    out = {}
    for name in ('TARGETS', 'SECONDARY'):
        m = re.search(r"export const %s = list\('([^']*)'\)" % name, src)
        if not m:
            sys.exit(f'não achei {name} em {VALIDATE_MJS}')
        out[name] = [t.strip() for t in m.group(1).split(',') if t.strip()]
    return out


def read_secondary_additions():
    """O SECONDARY_ADDITIONS de exercises.js (secundários extras que o app aplica por cima)."""
    src = EXERCISES_JS.read_text(encoding='utf-8')
    m = re.search(r'const SECONDARY_ADDITIONS = \{(.*?)\n\}', src, re.S)
    if not m:
        return {}
    out = {}
    for id_, items in re.findall(r"'(\d+)':\s*\[([^\]]*)\]", m.group(1)):
        out[id_] = re.findall(r"'([^']+)'", items)
    return out


# Erros do catálogo que o gerador corrige sem mexer no catalogue/, pelo id: os campos daqui trocam
# os do exercício antes de tudo. O 0459 flutter kicks tem o alvo "glutes", mas a descrição fala do
# abdômen baixo e dos flexores do quadril, e as outras versões (1179 e 1244) têm o alvo "abs" (#106).
CATALOGUE_FIXES = {
    '0459': {'target': 'abs'},
}


def load_catalogue():
    """O catálogo como está no catalogue/, sem as correções de CATALOGUE_FIXES (o build as aplica)."""
    exercises, variants = {}, {}
    for path in sorted(CATALOGUE.glob('*.json')):
        e = json.loads(path.read_text(encoding='utf-8'))
        (variants if e.get('variantOf') else exercises)[e['id']] = e
    return exercises, variants


def regions_of_terms(terms):
    out = set()
    for t in terms:
        out |= set(TERM_REGIONS[t])
    return out


def emphasis_of(primary, sub_terms):
    """Sub-regiões nomeadas dentro de grupos que estão inteiros no primário. Roda com o primário
    de depois das regras por nome; a ênfase que fica sai de kept_emphasis."""
    out = set()
    for t in sub_terms:
        regs = set(TERM_REGIONS[t])
        group = set(G[GROUP_OF[next(iter(regs))]])
        if group <= primary:
            out |= regs
    return out


NEVER_EMPHASIS = {'lowerAbs'}   # o abdômen baixo nunca acende sozinho, nem como ênfase (relatório, #13)


def kept_emphasis(emph, primary, banned=frozenset()):
    """A ênfase com o primário que já passou pelas regras por nome: só as regiões que estão nele,
    sem o abdômen baixo e sem as que a regra do exercício tira (banned: o bíceps na rosca martelo),
    e nenhuma quando ela cobre todas as regiões de um grupo do primário ou fica igual ao primário,
    porque aí não diz nada a mais."""
    out = (emph & primary) - NEVER_EMPHASIS - banned   # um grupo inteiro na ênfase está inteiro no primário
    if out == primary or any(set(rr) <= out for rr in G.values()):
        return set()
    return out


def from_freetext(e, extra):
    sec_terms = list(dict.fromkeys(e['secondaryMuscles'] + extra))
    primary = set(TERM_REGIONS[e['target']])
    secondary = regions_of_terms(sec_terms) - primary
    return primary, secondary, [t for t in sec_terms if is_subpart(t)]


def refine_group(group, text_terms):
    """Regiões de um grupo do muscleMap, estreitadas pelo texto livre quando ele só nomeia sub-partes."""
    full = set(V2_DEFAULT.get(group) or G[group])
    named = [t for t in text_terms if TERM_REGIONS[t] and GROUP_OF[TERM_REGIONS[t][0]] == group]
    if not named or any(not is_subpart(t) for t in named):
        return full
    return regions_of_terms(named)


def from_musclemap(e, extra):
    m = e['muscleMap']
    weights = m.get('weights')
    if weights:
        pg = [g for g, w in weights.items() if w >= 1]
        sg = [g for g, w in weights.items() if 0 < w < 1]
    else:
        pg = list(m.get('primaries') or [])
        sg = [g for g in (m.get('secondaries') or []) if g not in pg]
    text_terms = list(dict.fromkeys([e['target']] + e['secondaryMuscles'] + extra))
    primary, secondary = set(), set()
    for g in pg:
        primary |= refine_group(g, text_terms)
    for g in sg:
        secondary |= refine_group(g, text_terms)
    secondary -= primary
    return primary, secondary, [t for t in text_terms if is_subpart(t)]


def from_bodypart(e):
    bp = (e.get('muscleMap') or {}).get('bodyPart') or e['bodyPart']
    weights = BY_BODYPART.get(bp) or {}
    if not weights:
        return set(), set()
    top = max(weights.values())
    primary = {r for g, w in weights.items() if w == top for r in G[g]}
    secondary = {r for g, w in weights.items() if w < top for r in G[g]}
    return primary, secondary


def build():
    vocab = read_vocabulary()
    unknown = [t for t in vocab['TARGETS'] + vocab['SECONDARY'] if t not in TERM_REGIONS]
    if unknown:
        sys.exit('termos novos no catálogo sem mapeamento em TERM_REGIONS: ' + ', '.join(unknown))
    additions = read_secondary_additions()
    exercises, variants = load_catalogue()

    out = {}
    for id_, e in exercises.items():
        e = {**e, **CATALOGUE_FIXES.get(id_, {})}
        extra = [t for t in additions.get(id_, []) if t not in e['secondaryMuscles']]
        if e.get('muscleMap'):
            p, s, sub_terms = from_musclemap(e, extra)
            source = 'muscleMap'
        else:
            p, s, sub_terms = from_freetext(e, extra)
            source = 'curated' if extra else 'freetext'
        if not p and not s:
            p, s = from_bodypart(e)
            sub_terms = []
            source = 'bodypart'
        p, s = v2_name_rules(e, set(p), set(s))
        p, s = research_name_rules(e, p, s)
        p, s = lower_abs_never_alone(p, s)
        # A ênfase sai do primário de depois das regras, que podem mudar o primário.
        # Na rosca martelo o braquial e o antebraço entram pela regra: o bíceps não é a ênfase (1615).
        banned = {'biceps'} if curl_kind(e['name'].lower()) == 'hammer' else set()
        emph = kept_emphasis(emphasis_of(p, sub_terms), p, banned)
        row = {'name': e['name'], 'primary': ordered(p), 'secondary': ordered(s), 'source': source}
        if emph:
            row['emphasis'] = ordered(emph)
        out[id_] = row
    for id_, v in variants.items():
        base = out[v['variantOf']]
        out[id_] = {**base, 'variantOf': v['variantOf']}
    return dict(sorted(out.items(), key=lambda kv: (int(kv[0]), kv[0]))), exercises, additions


def exercises_text(rows):
    """O texto de exercise_regions_v2.json: uma linha por id, para o diff mostrar o exercício."""
    lines = [f'  {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}' for k, v in rows.items()]
    return '{\n' + ',\n'.join(lines) + '\n}\n'


def app_text(rows, regions):
    """O texto do JSON do app: compacto, sem espaço, com uma linha por região e por exercício para o
    diff mostrar o que mudou. As listas levam o índice de cada região no regions_v2.json."""
    index = {r['region']: i for i, r in enumerate(regions)}
    compact = {'separators': (',', ':')}
    head = [json.dumps({'id': r['region'], 'group': r['group'], 'watchGroup': r['watchGroup']}, **compact)
            for r in regions]
    body = [json.dumps(k) + ':' + json.dumps([[index[x] for x in v.get(f, [])] for f in APP_LISTS], **compact)
            for k, v in rows.items()]
    return '{"regions":[\n' + ',\n'.join(head) + '\n],"exercises":{\n' + ',\n'.join(body) + '\n}}\n'


# ---------------------------------------------------------------- --check

SHOWN = 10   # quantos exercícios ou regiões o --check lista por arquivo


REGION, EXERCISE = 'a região', 'o exercício'


def by_id(rows, field):
    """Uma lista de linhas pelo id de cada uma (o campo), ou pelo número da linha sem ele."""
    rows = rows if isinstance(rows, list) else []
    return {(r.get(field) if isinstance(r, dict) else None) or f'linha {i + 1}': r for i, r in enumerate(rows)}


def keyed(name, data):
    """O JSON por chave, (o que é, o id): o exercício, ou a região na tabela das regiões. O JSON do
    app tem os dois."""
    if name == REGIONS_JSON:
        return {(REGION, k): v for k, v in by_id(data, 'region').items()}
    if name == APP_JSON.name:
        data = data if isinstance(data, dict) else {}
        exercises = data.get('exercises') if isinstance(data.get('exercises'), dict) else {}
        return {**{(REGION, k): v for k, v in by_id(data.get('regions'), 'id').items()},
                **{(EXERCISE, k): v for k, v in exercises.items()}}
    return {(EXERCISE, k): v for k, v in data.items()} if isinstance(data, dict) else {}


def changed_fields(a, b):
    """Os campos que mudaram numa linha: as chaves de um objeto, ou as três listas do app."""
    if isinstance(a, dict) and isinstance(b, dict):
        return sorted(f for f in {*a, *b} if a.get(f) != b.get(f))
    if isinstance(a, list) and isinstance(b, list) and len(b) == len(APP_LISTS):
        return [f for i, f in enumerate(APP_LISTS) if i >= len(a) or a[i] != b[i]]
    return []


def differences(name, text, path, names=None):
    """O que não bate entre o texto que sairia do catálogo e o arquivo, uma linha por problema. O
    names dá o nome de cada exercício pelo id, para o JSON do app, que não tem nome."""
    if not path.is_file():
        return [f'{name}: o arquivo não existe ({path})']
    current = path.read_text(encoding='utf-8')
    if current == text:
        return []
    try:
        old = keyed(name, json.loads(current))
    except ValueError as err:
        return [f'{name}: não é um JSON válido ({err})']
    new = keyed(name, json.loads(text))
    source = {REGION: 'a tabela do gerador', EXERCISE: 'o catálogo'}

    def label(key):
        """O que é e o id, com o nome do exercício ao lado (o do catálogo, ou o do arquivo se o
        catálogo não tem)."""
        what, id_ = key
        title = None
        if what == EXERCISE:
            row = new.get(key) if isinstance(new.get(key), dict) else old.get(key)
            title = (names or {}).get(id_) or (row.get('name') if isinstance(row, dict) else None)
        return f'{what} {id_} ({title})' if isinstance(title, str) else f'{what} {id_}'

    out = []
    for key in dict.fromkeys([*new, *old]):
        if key not in old:
            out.append(f'{name}: {label(key)} falta no arquivo')
        elif key not in new:
            out.append(f'{name}: {label(key)} sobra no arquivo, e {source[key[0]]} não tem')
        elif old[key] != new[key]:
            fields = changed_fields(old[key], new[key])
            out.append(f'{name}: {label(key)} não bate com {source[key[0]]}' + (f' ({", ".join(fields)})' if fields else ''))
    if len(out) > SHOWN:
        out = out[:SHOWN] + [f'{name}: e mais {len(out) - SHOWN}']
    return out or [f'{name}: o conteúdo bate, mas o texto do arquivo não (formatação ou ordem)']


# ---------------------------------------------------------------- relatório (--report)

LEG = r'leg curl|hamstring|nordic|leg extension'
FAMILIES = [  # (rótulo, regex no nome em minúsculas, regex de exclusão, categoria)
    ('supino / chest press (bench|chest|floor press)', r'bench press|chest press|floor press', None, None),
    ('inclinado (incline)', r'\bincline\b', None, None),
    ('declinado (decline)', r'\bdecline\b', None, None),
    ('crucifixo / fly (fly|flye|crossover|pec deck)', r'\bfly\b|\bflye|crossover|pec deck', r'rear|reverse', None),
    ('flexão de braço (push-up)', r'push[- ]?up', None, None),
    ('mergulho (dip)', r'\bdips?\b', None, None),
    ('desenvolvimento (shoulder/overhead/military/arnold/push press)', r'shoulder press|overhead press|military press|arnold press|push press', None, None),
    ('elevação lateral (lateral raise)', r'lateral raise', r'rear', None),
    ('remada alta (upright row)', r'upright row', None, None),
    ('elevação frontal (front raise)', r'front raise', None, None),
    ('deltoide posterior (rear delt|reverse/rear fly|face pull|pull apart)', r'rear delt|reverse fly|rear fly|face pull|pull apart|rear lateral', None, None),
    ('rotação de ombro (external/internal rotation)', r'external rotation|internal rotation|shoulder rotation', r'stretch', None),
    ('remada (row, sem upright)', r'\brows?\b', r'upright', None),
    ('puxada / barra (pulldown|pull-up|chin-up)', r'pulldown|pull[- ]?down|pull[- ]?up|chin[- ]?up', None, None),
    ('pullover', r'pullover', None, None),
    ('encolhimento (shrug)', r'\bshrug', None, None),
    ('rosca (curl, sem leg curl)', r'\bcurl', LEG, None),
    ('tríceps (triceps|pushdown|kickback|skull crusher)', r'triceps|pushdown|push-down|kickback|skull', LEG, None),
    ('agachamento (squat)', r'\bsquat', None, None),
    ('afundo (lunge|split squat|step-up)', r'\blunge|split squat|step[- ]?up', None, None),
    ('terra / stiff (deadlift|rdl|romanian|good morning)', r'deadlift|\brdl\b|romanian|good morning', None, None),
    ('elevação de quadril (hip thrust|bridge)', r'hip thrust|glute bridge|\bbridge\b', None, None),
    ('leg press', r'leg press', None, None),
    ('cadeira extensora (leg extension)', r'leg extension', None, None),
    ('mesa flexora (leg curl|nordic)', r'leg curl|hamstring curl|nordic', None, None),
    ('abdução de quadril (abduction)', r'abduct', None, None),
    ('adução de quadril (adduction)', r'adduct', None, None),
    ('panturrilha (calf raise|calf press)', r'\bcalf\b', r'stretch', None),
    ('abdominal (crunch|sit-up)', r'crunch|sit[- ]?up', None, None),
    ('elevação de pernas (leg raise|knee raise|leg lift)', r'leg raise|knee raise|leg lift', None, None),
    ('prancha (plank)', r'\bplank', None, None),
    ('rotação de tronco (twist|russian|woodchop|side bend)', r'twist|russian|wood ?chop|side bend', None, None),
    ('extensão lombar (back extension|hyperextension|superman)', r'back extension|hyperextension|superman', None, None),
    ('pescoço (bodyPart neck)', None, None, 'bp:neck'),
    ('alongamento (category stretching)', None, None, 'stretching'),
    ('cardio (category cardio)', None, None, 'cardio'),
    ('olímpicos (category olympic)', None, None, 'olympic'),
]


def family_members(exercises, rx, exclude, cat):
    out = []
    for e in exercises.values():
        n = e['name'].lower()
        if cat and cat.startswith('bp:'):
            if e['bodyPart'] != cat[3:]:
                continue
        elif cat:
            if e['category'] != cat:
                continue
        if rx and not re.search(rx, n):
            continue
        if exclude and re.search(exclude, n):
            continue
        out.append(e)
    return out


def report(rows, exercises, additions):
    ex_rows = {k: v for k, v in rows.items() if 'variantOf' not in v}
    n = len(ex_rows)
    print(f'# exercícios: {n}; desenhos variantes: {len(rows) - n}; total de chaves: {len(rows)}')
    print('fontes:', dict(collections.Counter(v['source'] for v in ex_rows.values())))
    print('com >=1 região primária:', sum(1 for v in ex_rows.values() if v['primary']))
    print('sem primária mas com secundária:', sum(1 for v in ex_rows.values() if not v['primary'] and v['secondary']))
    print('sem nenhuma região:', sum(1 for v in ex_rows.values() if not v['primary'] and not v['secondary']))

    def partial(regs):
        by = collections.defaultdict(set)
        for r in regs:
            by[GROUP_OF[r]].add(r)
        return {g for g, rs in by.items() if rs < set(G[g])}
    sub_any = sub_p = 0
    for v in ex_rows.values():
        pp = partial(v['primary'])
        ss = partial([r for r in v['secondary']])
        if pp or ss:
            sub_any += 1
        if pp:
            sub_p += 1
    print('acendem sub-parte (algum grupo parcial em primary ou secondary):', sub_any, '| no primário:', sub_p)
    print('com emphasis:', sum(1 for v in ex_rows.values() if v.get('emphasis')))

    # termos: quantos exercícios cada termo acende, por papel
    tc, sc = collections.Counter(), collections.Counter()
    for id_, e in exercises.items():
        tc[e['target']] += 1
        for t in set(e['secondaryMuscles'] + additions.get(id_, [])):
            sc[t] += 1
    print('\n## termos (exercícios como alvo / como secundário) -> regiões')
    for t in sorted(TERM_REGIONS, key=lambda t: -(tc[t] + sc[t])):
        mark = ' [sub-parte]' if is_subpart(t) else ''
        print(f'  {t}: alvo={tc[t]} sec={sc[t]} -> {TERM_REGIONS[t]}{mark}')

    print('\n## regiões (exercícios que acendem como primária / secundária)')
    rp = collections.Counter(r for v in ex_rows.values() for r in v['primary'])
    rs = collections.Counter(r for v in ex_rows.values() for r in v['secondary'])
    for r in REGION_ORDER:
        print(f'  {r}: primária={rp[r]} secundária={rs[r]}')

    print('\n## famílias (regiões primárias >= 30%, secundárias >= 25% dos membros)')
    for label, rx, exclude, cat in FAMILIES:
        mem = family_members(exercises, rx, exclude, cat)
        if not mem:
            continue
        k = len(mem)
        pc = collections.Counter(r for e in mem for r in rows[e['id']]['primary'])
        sc2 = collections.Counter(r for e in mem for r in rows[e['id']]['secondary'])
        ec = collections.Counter(r for e in mem for r in rows[e['id']].get('emphasis', []))
        tg = collections.Counter(e['target'] for e in mem)
        src = collections.Counter(rows[e['id']]['source'] for e in mem)
        fmt = lambda c, lim: ', '.join(f'{r} {round(100 * x / k)}%' for r, x in c.most_common() if x / k >= lim)
        print(f'- {label}: n={k}; alvos={dict(tg.most_common(4))}; fontes={dict(src)}')
        print(f'    primárias: {fmt(pc, 0.30)}')
        print(f'    secundárias: {fmt(sc2, 0.25)}')
        if ec:
            print(f'    ênfase: {fmt(ec, 0.05)}')


def main():
    ap = argparse.ArgumentParser(
        description='Gera exercise_regions_v2.json, regions_v2.json e o JSON do app a partir do texto do catálogo.')
    ap.add_argument('--check', action='store_true',
                    help='não grava nada; sai com 1 quando um dos três JSON não bate com o que sairia do catálogo')
    ap.add_argument('--out', type=Path, default=HERE, metavar='PASTA',
                    help='a pasta dos dois JSON (padrão: a deste script)')
    ap.add_argument('--app', type=Path, default=APP_JSON, metavar='ARQUIVO',
                    help='o JSON do app (padrão: exercise-regions.json no pacote HexBody)')
    ap.add_argument('--report', action='store_true', help='também imprime as contagens usadas nas notas')
    args = ap.parse_args()
    rows, exercises, additions = build()
    regions = regions_v2_rows()
    names = {k: v['name'] for k, v in rows.items()}
    app = app_text(rows, regions)
    files = [(EXERCISE_JSON, exercises_text(rows), args.out / EXERCISE_JSON),
             (REGIONS_JSON, regions_text(regions), args.out / REGIONS_JSON),
             (APP_JSON.name, app, args.app)]
    size = f'{len(app.encode("utf-8"))} bytes'
    if args.check:
        problems = [line for name, text, path in files for line in differences(name, text, path, names)]
        if problems:
            print('\n'.join(problems), file=sys.stderr)
            print('rode python3 -I scripts/hexbody/regions/build_exercise_regions.py e commite os três JSON', file=sys.stderr)
            return 1
        print(f'em dia: {EXERCISE_JSON} ({len(rows)} chaves), {REGIONS_JSON} ({len(regions)} regiões por lado)'
              f' e {APP_JSON.name} ({size})')
    else:
        for name, text, path in files:
            path.write_text(text, encoding='utf-8')
        print(f'{EXERCISE_JSON}: {len(rows)} chaves; {REGIONS_JSON}: {len(regions)} regiões pintadas por lado;'
              f' {APP_JSON.name}: {size}', file=sys.stderr)
    if args.report:
        report(rows, exercises, additions)
    return 0


if __name__ == '__main__':
    sys.exit(main())
