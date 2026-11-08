// Testes do scripts/hexgym/record-routine-cases.mjs, que grava no Node os casos do addStep e do LEGACY
// do openGym que o RoutineCasesTests.swift confere no app (issue #116). O --check roda contra uma
// cópia do arquivo numa pasta temporária, que sai no fim do teste: o arquivo do repositório não muda.
//
//   node --test scripts/hexgym/record-routine-cases.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { addStep } from '../../frontend/src/lib/progression.js'
import { CASES_FILE, codesOf, main, recordText } from './record-routine-cases.mjs'

// Uma pasta temporária, que sai no fim do teste, e o console calado, para a saída do teste ficar limpa.
function sandbox(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-routine-cases-'))
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }))
  t.mock.method(console, 'log', () => {})
  t.mock.method(console, 'error', () => {})
  return path.join(dir, 'RoutineCases.json')
}

test('the same cases recorded twice give the same text, in the file the app test reads', async () => {
  assert.equal(await recordText(), await recordText())
  assert.equal(CASES_FILE, 'apple/HexGymTests/RoutineCases.json')
})

test('the cases cover kg and lb, the loads from 0 to 1010 and both directions, and the 42 old emoji', async () => {
  const { addStep: groups, legacy, glyphOf } = JSON.parse(await recordText())
  assert.deepEqual([...new Set(groups.map(g => g.unit))], ['kg', 'lb'])
  for (const unit of ['kg', 'lb']) {
    const incs = groups.filter(g => g.unit === unit).map(g => g.increment)
    for (const inc of [0.5, 1, 1.25, 2, 2.5, 5, 10]) assert.ok(incs.includes(inc), `${unit} sem o incremento ${inc}`)
  }
  // O 1,25 kg trazido para lb pelo convertWeight.
  assert.ok(groups.some(g => g.unit === 'lb' && g.increment === 3))
  for (const { unit, increment, cases } of groups) {
    const loads = cases.map(c => c[0])
    assert.equal(loads[0], 0, `${unit} ${increment} começa em 0`)
    assert.equal(loads.at(-1), 1010, `${unit} ${increment} acaba em 1010`)
    for (const [load, up, down] of cases) {
      assert.equal(up, addStep(load, increment, increment))
      assert.equal(down, addStep(load, -increment, increment))
    }
  }
  assert.equal(legacy.length, 42)
  assert.deepEqual(legacy[0], { emoji: '💪', codes: '1F4AA', key: 'arm' })
  for (const e of [...legacy, ...glyphOf]) assert.equal(codesOf(e.emoji ?? e.input), e.codes)
  // Com o tom de pele, o mapa não acha, e o glyphOf tenta de novo com o primeiro caractere.
  assert.equal(glyphOf.find(e => e.input === '💪🏽').key, 'arm')
  assert.equal(glyphOf.find(e => e.input === '🐙').key, 'figureStrength')
})

test('--check fails when the file is stale or missing, and recording brings it back', async t => {
  const file = sandbox(t)
  // Sem o arquivo, o --check falha e não grava nada.
  assert.equal(await main(['--check'], file), 1)
  assert.equal(fs.existsSync(file), false)
  // Gravado, o --check passa.
  assert.equal(await main([], file), 0)
  const text = fs.readFileSync(file, 'utf8')
  assert.equal(text, await recordText())
  assert.equal(await main(['--check'], file), 0)
  // Um valor mudado no arquivo, e o --check falha, sem consertar o arquivo.
  const stale = text.replace('[0,2.5,0]', '[0,2.6,0]')
  assert.notEqual(stale, text)
  fs.writeFileSync(file, stale)
  assert.equal(await main(['--check'], file), 1)
  assert.equal(fs.readFileSync(file, 'utf8'), stale)
  // Um emoji antigo mudado também.
  fs.writeFileSync(file, text.replace('"codes": "1F4AA", "key": "arm"', '"codes": "1F4AA", "key": "legs"'))
  assert.equal(await main(['--check'], file), 1)
  // Gravar de novo conserta.
  assert.equal(await main([], file), 0)
  assert.equal(fs.readFileSync(file, 'utf8'), text)
})

test('an unknown argument is a usage error', async t => {
  const file = sandbox(t)
  assert.equal(await main(['--force'], file), 2)
  assert.equal(fs.existsSync(file), false)
})
