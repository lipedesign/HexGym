// Testes do scripts/hexgym/engine-load.mjs, o teste de carga do motor no jsc. Nenhum deles roda o
// jsc: só o histórico grande e as metas.
//
//   node --test scripts/hexgym/engine-load.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { buildDemoState } from '../../frontend/src/lib/demoSeed.js'
import { overBudget, padHistory } from './engine-load.mjs'

test('padHistory reaches the total with a new id for each copy', () => {
  const S = padHistory(buildDemoState(), 1040)
  assert.equal(S.workouts.length, 1040); assert.equal(new Set(S.workouts.map(w => w.id)).size, 1040)
})
test('overBudget names each limit that was passed', () => {
  assert.deepEqual(overBudget({ evaluate: 100, restore: 150, tick: 10, structuredClone: true }), [])
  assert.deepEqual(overBudget({ evaluate: 200, restore: 150, tick: 31, structuredClone: false }),
    ['evaluate + restore: 350 ms (meta 300)', 'tick: 31 ms (meta 30)', 'structuredClone diferente no JavaScriptCore'])
  assert.deepEqual(overBudget({ evaluate: 200, restore: 150, tick: 31, structuredClone: true }, 2), [])
})
