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
import { CASES_FILE, codesOf, loadGlyphs, main, recordText } from './record-routine-cases.mjs'

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
    for (const inc of [0.1, 0.2, 0.5, 1, 1.25, 2, 2.5, 5, 10]) assert.ok(incs.includes(inc), `${unit} sem o incremento ${inc}`)
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
  // Cada emoji antigo também com o ZWJ na frente (QA do PR #148). O corte tira o ZWJ e acha o 💪; o
  // ⛰️ não, porque o primeiro caractere fica sem o seletor, e o LEGACY só tem o ⛰️ com ele.
  for (const e of legacy) assert.ok(glyphOf.some(g => g.codes === `200D ${e.codes}`), `sem o ZWJ na frente de ${e.codes}`)
  assert.equal(glyphOf.find(g => g.codes === '200D 1F4AA').key, 'arm')
  assert.equal(glyphOf.find(g => g.codes === '200D 26F0 FE0F').key, 'figureStrength')
})

// O glyphs.js de verdade, com uma mudança no texto.
const glyphsSource = () => fs.readFileSync(new URL('../../frontend/src/lib/glyphs.js', import.meta.url), 'utf8')

test('the glyphs.js loader takes an exported LEGACY as it is', async () => {
  const source = glyphsSource().replace(/^const LEGACY = \{/m, 'export const LEGACY = {')
  const { LEGACY, glyphOf } = await loadGlyphs(source)
  assert.equal(Object.keys(LEGACY).length, 42)
  assert.equal(glyphOf('💪'), 'arm')
  // Sem o const LEGACY nos dois jeitos, a mensagem diz isso.
  await assert.rejects(loadGlyphs(glyphsSource().replace(/^const LEGACY = /m, 'const OLD = ')),
    { message: 'o frontend/src/lib/glyphs.js não tem o const LEGACY nem o export const LEGACY' })
})

test('an extra import in glyphs.js says which one, without the base64 URL', async () => {
  const source = `import { x } from './outro.js'\n${glyphsSource()}`
  await assert.rejects(loadGlyphs(source), err => {
    assert.equal(err.message, 'o frontend/src/lib/glyphs.js importa outro módulo além do Icon.jsx (./outro.js)')
    assert.doesNotMatch(err.message, /base64/)
    return true
  })
  // Outro erro ao carregar também sai sem a URL.
  await assert.rejects(loadGlyphs(`${glyphsSource()}\nexport const = 1\n`), err => {
    assert.match(err.message, /^o frontend\/src\/lib\/glyphs\.js não carregou: /)
    assert.doesNotMatch(err.message, /base64/)
    return true
  })
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
