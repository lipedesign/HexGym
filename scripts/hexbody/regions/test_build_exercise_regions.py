#!/usr/bin/env python3
"""Testes do gerador de regiões: as regras da v2, a ênfase e o --check.

    python3 -I scripts/hexbody/regions/run_tests.py

Lê só o texto do catálogo, como o gerador. Cada caso é um exercício real pelo id. Os testes do
--check rodam o gerador num processo à parte, contra uma pasta temporária (--out, e --app para o
JSON do app), e nunca gravam nada nesta pasta nem no pacote HexBody.
"""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import build_exercise_regions as B

ROWS, _, _ = B.build()


def regions(id_):
    r = ROWS[id_]
    return set(r['primary']), set(r['secondary'])


SCRIPT = Path(B.__file__).resolve()
JSONS = ('exercise_regions_v2.json', 'regions_v2.json')
APP = B.APP_JSON.name   # exercise-regions.json, o JSON do pacote HexBody
SEATED_ABDUCTIONS = ('0597', '3006', '3611', '3005')   # as duas abduções sentadas e os desenhos delas


def run_check(folder):
    """O --check contra a pasta, num processo à parte, como o check.mjs roda. O JSON do app é o
    da mesma pasta."""
    return subprocess.run([sys.executable, '-I', str(SCRIPT), '--check', '--out', str(folder), '--app', str(folder / APP)],
                          capture_output=True, text=True)


def copy_of_jsons(test):
    """Uma pasta temporária com uma cópia dos três JSON do repositório (os dois desta pasta e o do
    app); sai no fim do teste."""
    tmp = Path(tempfile.mkdtemp(prefix='hexgym-regions-'))
    test.addCleanup(shutil.rmtree, tmp, True)
    for name in JSONS:
        shutil.copyfile(B.HERE / name, tmp / name)
    shutil.copyfile(B.APP_JSON, tmp / APP)
    return tmp


class V2Rules(unittest.TestCase):
    def test_seated_calf_is_soleus(self):
        p, s = regions('0088')                       # barbell seated calf raise
        self.assertEqual(p, {'soleus'})
        self.assertIn('calves', s)

    def test_standing_calf_keeps_both(self):
        ids = [k for k, v in ROWS.items() if v['name'] == 'lever standing calf raise' and 'variantOf' not in v]
        self.assertTrue(ids)
        p, _ = regions(ids[0])
        self.assertLessEqual({'calves', 'soleus'}, p)

    def test_hammer_curl_adds_brachialis(self):
        p, _ = regions('0166')                       # cable hammer curl
        self.assertLessEqual({'biceps', 'brachialis', 'forearm'}, p)

    def test_reverse_curl_moves_biceps_to_secondary(self):
        p, s = regions('0080')                       # barbell reverse curl
        self.assertLessEqual({'brachialis', 'forearm'}, p)
        self.assertNotIn('biceps', p)
        self.assertIn('biceps', s)

    def test_plain_curl_has_no_brachialis_primary(self):
        ids = [k for k, v in ROWS.items() if v['name'] == 'dumbbell biceps curl' and 'variantOf' not in v]
        self.assertTrue(ids)
        self.assertNotIn('brachialis', regions(ids[0])[0])

    def test_overhead_triceps_is_long_head(self):
        p, s = regions('0092')                       # barbell seated overhead triceps extension
        self.assertEqual(p, {'tricepsLongHead'})
        self.assertIn('triceps', s)

    def test_hip_abduction_is_gluteus_medius(self):
        p, _ = regions('4031')                       # band hip abduction
        self.assertIn('gluteusMedius', p)
        self.assertNotIn('gluteal', p)

    def test_squat_does_not_light_gluteus_medius(self):
        rows = [v for v in ROWS.values() if v['name'] == 'barbell full squat' and 'variantOf' not in v]
        self.assertTrue(rows)
        for v in rows:
            self.assertNotIn('gluteusMedius', v['primary'] + v['secondary'])

    def test_lat_pulldown_lights_teres_major(self):
        p, _ = regions('2330')                       # cable lat pulldown full range of motion
        self.assertLessEqual({'upperBack', 'teresMajor'}, p)

    def test_upper_back_no_longer_holds_rotator_cuff(self):
        self.assertNotIn('rotatorCuff', B.G['upper-back'])
        self.assertIn('rotatorCuff', B.G['deltoids'])

    def test_lateral_raise_does_not_light_rotator_cuff(self):
        rows = [v for v in ROWS.values() if v['name'] == 'dumbbell lateral raise' and 'variantOf' not in v]
        self.assertTrue(rows)
        for v in rows:
            self.assertNotIn('rotatorCuff', v['primary'])

    def test_neck_flexion_and_extension(self):
        self.assertEqual(regions('10780')[0], {'sternocleidomastoid'})      # lying neck flexion
        self.assertEqual(regions('2411')[0], {'neckBack'})                  # cable seated neck extension
        self.assertEqual(regions('2283')[0], {'sternocleidomastoid', 'neckBack'})  # side flexion

    def test_every_region_is_named_and_mapped(self):
        rows = B.regions_v2_rows()
        self.assertEqual(len(rows), 36)
        watch = {r['watchGroup'] for r in rows} - {None}
        self.assertEqual(len(watch), 18)
        self.assertEqual({r['region'] for r in rows if r['watchGroup'] is None}, {'sternocleidomastoid', 'neckBack'})

    def test_regions_v2_json_is_current(self):
        committed = json.loads((B.HERE / 'regions_v2.json').read_text(encoding='utf-8'))
        self.assertEqual(committed, B.regions_v2_rows())



class ResearchRules(unittest.TestCase):
    """As regras por nome da tabela "A evidência confirma o banco inclinado e derruba o abdômen
    inferior" do relatório (issue #13), uma por teste, cada uma com exercícios reais do catálogo."""

    def assertRegions(self, id_, primary, secondary):
        p, s = regions(id_)
        self.assertEqual((p, s), (set(primary), set(secondary)), f'{id_} {ROWS[id_]["name"]}')

    def test_low_incline_press_is_upper_chest(self):
        self.assertRegions('0047', {'upperChest'}, {'frontDeltoid', 'triceps'})   # barbell incline bench press
        self.assertRegions('6218', {'upperChest'}, {'frontDeltoid', 'triceps'})   # dumbbell incline twist press (o punho gira)
        self.assertRegions('0331', {'upperChest'}, {'frontDeltoid'})              # dumbbell incline twisted flyes

    def test_high_incline_press_is_front_deltoid(self):
        # dumbbell incline shoulders press: o banco a 60° ou 75°, e o nome diz "shoulders press"
        self.assertRegions('5261', {'frontDeltoid'}, {'upperChest', 'triceps'})

    def test_flat_press_fly_and_push_up_are_mid_and_low_chest(self):
        press = {'upperChest', 'frontDeltoid', 'triceps', 'tricepsLongHead'}
        self.assertRegions('0025', {'chest', 'lowerChest'}, press)                 # barbell bench press
        self.assertRegions('0308', {'chest', 'lowerChest'}, {'upperChest', 'frontDeltoid'})   # dumbbell fly
        self.assertRegions('4835', {'chest', 'lowerChest'}, press)   # dumbbell rotational grip bench press
        self.assertRegions('4342', {'chest', 'lowerChest'}, {'upperChest', 'frontDeltoid'})   # dumbbell twisted fly
        for id_ in ('3294', '1306', '1273'):                        # archer, plyo e clap push up: flexão
            self.assertRegions(id_, {'chest', 'lowerChest'}, press)
        # Ficam fora: a flexão inclinada (incline e elevated push-up) e o deslizar na parede com toalha.
        for id_ in ('0493', '3812', '10927'):
            self.assertEqual(regions(id_)[0], set(B.G['chest']), id_)

    def test_decline_press_is_low_chest(self):
        self.assertRegions('0033', {'lowerChest', 'chest'}, {'triceps', 'frontDeltoid'})   # barbell decline bench press
        self.assertRegions('0307', {'lowerChest', 'chest'}, {'frontDeltoid'})              # dumbbell decline twist fly

    def test_overhead_press_is_front_deltoid(self):
        ohp = {'deltoids', 'triceps', 'upperTrapezius'}
        self.assertRegions('0091', {'frontDeltoid'}, ohp)   # barbell seated overhead press
        self.assertRegions('1045', {'frontDeltoid'}, ohp)   # barbell seated military press (inside squat cage)
        self.assertRegions('0388', {'frontDeltoid'}, ohp)   # dumbbell seated alternate press: "press" com o deltoide inteiro
        self.assertRegions('2927', {'frontDeltoid'}, ohp | {'rotatorCuff'})   # kettlebell kneeling one arm bottoms up press

    def test_lateral_raise_is_lateral_deltoid(self):
        self.assertRegions('0334', {'deltoids'}, {'rearDeltoid', 'upperTrapezius'})   # dumbbell lateral raise

    def test_reverse_fly_and_face_pull_are_rear_deltoid(self):
        self.assertRegions('0378', {'rearDeltoid'}, {'rhomboids', 'trapezius'})   # dumbbell rear fly
        # cable standing face pull: o manguito, que o texto nomeia, fica no secundário
        self.assertRegions('5609', {'rearDeltoid'}, {'rhomboids', 'trapezius', 'rotatorCuff'})
        # cable bent over one arm lateral raise, lever incline chest supported reverse delt fly (plate loaded),
        # dumbbell lying one arm deltoid rear e cable cross-over revers fly
        for id_ in ('3912', '11718', '0341', '0154'):
            self.assertRegions(id_, {'rearDeltoid'}, {'rhomboids', 'trapezius'})

    def test_shrug_is_upper_trapezius_only(self):
        self.assertRegions('0095', {'upperTrapezius'}, set())   # barbell shrug

    def test_y_raise_is_lower_trapezius(self):
        self.assertRegions('3403', {'lowerTrapezius'}, {'deltoids'})   # standing y raise (alvo traps)
        self.assertRegions('1017', {'lowerTrapezius'}, {'deltoids'})   # band y-raise (alvo delts)

    def test_rotation_and_side_plank_are_obliques(self):
        self.assertRegions('0687', {'obliques'}, {'upperAbs'})    # russian twist
        self.assertRegions('11251', {'obliques'}, {'upperAbs'})   # cable kneeling woodchop v. 3
        self.assertRegions('0715', {'obliques'}, {'upperAbs'})    # side plank

    def test_side_plank_with_abduction_is_gluteus_medius(self):
        self.assertRegions('0703', {'gluteusMedius'}, {'gluteal', 'obliques'})   # side bridge hip abduction (star)
        self.assertRegions('4863', {'gluteusMedius'}, {'gluteal', 'obliques'})   # side plank leg lift

    def test_squat_is_vasti_gluteus_and_adductors(self):
        legs = {'outerQuad', 'innerQuad', 'gluteal', 'adductors'}
        p, s = regions('0043')                                   # barbell full squat
        self.assertEqual(p, legs)
        self.assertLessEqual({'quadriceps', 'hamstring', 'lowerBack', 'calves'}, s)   # os secundários que já tinha
        p, s = regions('2966')                                   # dumbbell front squat (alvo quads)
        self.assertEqual(p, legs)
        self.assertIn('quadriceps', s)
        # with rack, side pov, with chains, with v bar: o mesmo agachamento
        for id_ in ('0878', '1462', '4064', '7578'):
            self.assertEqual(regions(id_)[0], legs, id_)

    def test_hip_adduction_is_adductors_only(self):
        self.assertRegions('0168', {'adductors'}, set())   # cable hip adduction

    def test_leg_raise_lights_hip_flexors_and_whole_abs(self):
        whole = {'hipFlexors', 'upperAbs', 'lowerAbs'}
        self.assertRegions('0472', whole, set())   # hanging leg raise
        self.assertRegions('0872', whole, set())   # reverse crunch
        self.assertRegions('1163', whole, set())   # lying leg raise, que tinha "lower abs" no texto
        self.assertNotIn('emphasis', ROWS['1163'])
        for id_ in ('4886', '9049', '0910'):   # lying flat hip raise, incline hip raise, band lying leg and hip raise
            self.assertRegions(id_, whole, set())


class OutsideRows(unittest.TestCase):
    """As linhas da tabela que a issue #13 deixou fora e que o JSON não seguia (a rosca martelo e
    a inversa com toalha, e a panturrilha sentada com outro nome)."""

    def test_towel_hammer_and_reverse_curls_follow_the_curl_rule(self):
        p, _ = regions('3830')                       # lying double legs hammer curl with towel
        self.assertLessEqual({'biceps', 'brachialis', 'forearm'}, p)
        p, s = regions('3850')                       # two legs reverse biceps curl with towel v. 2
        self.assertEqual(p, {'brachialis', 'forearm'})
        self.assertIn('biceps', s)
        # Na rosca martelo o bíceps não é a ênfase (1615 lever hammer grip preacher curl).
        self.assertNotIn('biceps', ROWS['1615'].get('emphasis', []))

    def test_sitting_toe_raise_is_soleus(self):
        p, s = regions('9509')                       # lever sitting toe raise
        self.assertEqual(p, {'soleus'})
        self.assertIn('calves', s)


class Emphasis(unittest.TestCase):
    """A ênfase sai depois das regras por nome, dentro do primário, e só quando diz algo a mais."""

    def with_emphasis(self):
        rows = {k: v for k, v in ROWS.items() if v.get('emphasis')}
        self.assertTrue(rows)
        return rows

    def test_emphasis_stays_inside_primary(self):
        for id_, v in self.with_emphasis().items():
            self.assertLessEqual(set(v['emphasis']), set(v['primary']), f'{id_} {v["name"]}')

    def test_emphasis_never_equals_primary_or_a_whole_group(self):
        for id_, v in self.with_emphasis().items():
            emph = set(v['emphasis'])
            self.assertNotEqual(emph, set(v['primary']), f'{id_} {v["name"]}')
            for group, regions in B.V2_GROUP_REGIONS.items():
                if set(regions) <= set(v['primary']):
                    self.assertFalse(set(regions) <= emph, f'{id_} {v["name"]}: a ênfase cobre o grupo {group}')

    def test_seated_abduction_has_no_gluteus_maximus_emphasis(self):
        for id_ in SEATED_ABDUCTIONS:
            self.assertIn('seated hip abduction', ROWS[id_]['name'], id_)
            self.assertNotIn('gluteal', ROWS[id_].get('emphasis', []), id_)


class Check(unittest.TestCase):
    def test_check_passes_when_fresh(self):
        r = run_check(copy_of_jsons(self))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_check_fails_when_stale(self):
        tmp = copy_of_jsons(self)
        path = tmp / 'exercise_regions_v2.json'
        rows = json.loads(path.read_text(encoding='utf-8'))
        rows['0001']['primary'] = rows['0001']['primary'][1:]   # o exercício perde uma região
        stale = json.dumps(rows, ensure_ascii=False)
        path.write_text(stale, encoding='utf-8')
        r = run_check(tmp)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn('exercise_regions_v2.json', r.stderr)
        self.assertIn('0001', r.stderr)
        self.assertEqual(path.read_text(encoding='utf-8'), stale, 'o --check não grava nada')

    def test_check_names_the_exercise_that_lost_a_region(self):
        # Só a linha do 0025 muda (uma região a menos no primário); o resto do arquivo fica igual.
        tmp = copy_of_jsons(self)
        path = tmp / 'exercise_regions_v2.json'
        lines = path.read_text(encoding='utf-8').split('\n')
        i = next(i for i, line in enumerate(lines) if line.startswith('  "0025": '))
        row = json.loads(lines[i][len('  "0025": '):].rstrip(','))
        row['primary'] = row['primary'][:-1]
        lines[i] = '  "0025": ' + json.dumps(row, ensure_ascii=False) + (',' if lines[i].endswith(',') else '')
        path.write_text('\n'.join(lines), encoding='utf-8')
        r = run_check(tmp)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn('0025 (barbell bench press)', r.stderr)
        self.assertIn('(primary)', r.stderr)
        self.assertEqual(r.stderr.count('não bate'), 1, r.stderr)   # só o 0025, nenhum outro

    def test_check_fails_when_the_app_json_is_stale(self):
        # O JSON do app perde o peito médio no primário do 0025; os dois JSON desta pasta ficam iguais.
        tmp = copy_of_jsons(self)
        path = tmp / APP
        app = json.loads(path.read_text(encoding='utf-8'))
        chest = [r['id'] for r in app['regions']].index('chest')
        app['exercises']['0025'][0].remove(chest)
        stale = json.dumps(app, separators=(',', ':'))
        path.write_text(stale, encoding='utf-8')
        r = run_check(tmp)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn(f'{APP}: o exercício 0025 (barbell bench press) não bate com o catálogo (primary)', r.stderr)
        self.assertEqual(r.stderr.count('não bate'), 1, r.stderr)   # só o 0025, e só no JSON do app
        self.assertEqual(path.read_text(encoding='utf-8'), stale, 'o --check não grava nada')


if __name__ == '__main__':
    unittest.main()
