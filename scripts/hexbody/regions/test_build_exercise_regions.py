#!/usr/bin/env python3
"""Testes do gerador de regiões: as regras da v2, a ênfase e o --check.

    python3 -I scripts/hexbody/regions/run_tests.py

Lê só o texto do catálogo, como o gerador. Cada caso é um exercício real pelo id. Os testes do
--check rodam o gerador num processo à parte, contra uma pasta temporária (--out), e nunca
gravam nada nesta pasta.
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
SEATED_ABDUCTIONS = ('0597', '3006', '3611', '3005')   # as duas abduções sentadas e os desenhos delas


def run_check(folder):
    """O --check contra a pasta, num processo à parte, como o check.mjs roda."""
    return subprocess.run([sys.executable, '-I', str(SCRIPT), '--check', '--out', str(folder)],
                          capture_output=True, text=True)


def copy_of_jsons(test):
    """Uma pasta temporária com uma cópia dos dois JSON do repositório; sai no fim do teste."""
    tmp = Path(tempfile.mkdtemp(prefix='hexgym-regions-'))
    test.addCleanup(shutil.rmtree, tmp, True)
    for name in JSONS:
        shutil.copyfile(B.HERE / name, tmp / name)
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


if __name__ == '__main__':
    unittest.main()
