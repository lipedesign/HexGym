// Testes do scripts/hexgym/check.mjs, o comando de teste do HexGym.
//
//   node --test scripts/hexgym/check.test.mjs
//
// A mensagem do teste "unknown part" lista as partes do PARTS: quem acrescenta
// uma parte atualiza a mensagem esperada aqui.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { PARTS, planChecks, runChecks } from './check.mjs'

test('the scripts part runs the node tests of scripts/hexgym', () => {
  assert.deepEqual(planChecks(['scripts']).map(c => [c.cmd, ...c.args]), [['node', '--test', 'scripts/hexgym/*.test.mjs']])
})
test('no part means every part, in PARTS order', () => {
  assert.deepEqual(planChecks([]), Object.values(PARTS).flat())
})
test('an unknown part fails with the list of parts', () => {
  assert.throws(() => planChecks(['x']), /parte desconhecida: x \(partes: scripts\)/)
})
test('runChecks stops at the first failure', async () => {
  const ran = []
  const r = await runChecks([{ name: 'a' }, { name: 'b' }, { name: 'c' }], async c => { ran.push(c.name); return c.name === 'b' ? 1 : 0 })
  assert.deepEqual(r, { ok: false, failed: 'b' }); assert.deepEqual(ran, ['a', 'b'])
})
