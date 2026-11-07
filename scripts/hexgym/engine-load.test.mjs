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
  const library = { catalogue: 200, search: 50, searchAfterRestore: 60, catalogueAfterAliases: 250, searchAfterAliases: 70 }
  assert.deepEqual(overBudget({ evaluate: 100, language: 40, restore: 150, tick: 10, ...library, structuredClone: true }), [])
  const slow = {
    evaluate: 200, language: 40, restore: 150, tick: 31, catalogue: 401, search: 101, searchAfterRestore: 119, catalogueAfterAliases: 380,
    searchAfterAliases: 110,
  }
  assert.deepEqual(overBudget({ ...slow, structuredClone: false }),
    ['evaluate + idioma + restore: 390 ms (meta 300)', 'tick: 31 ms (meta 30)', 'catálogo: 401 ms (meta 400)', 'busca: 101 ms (meta 100)',
      'busca depois do restore: 119 ms (meta 100)', 'reabrir com outros apelidos: catálogo 380 ms (meta 400), busca 110 ms (meta 100)',
      'structuredClone diferente no JavaScriptCore'])
  assert.deepEqual(overBudget({ ...slow, structuredClone: true }, 2), [])
  assert.deepEqual(overBudget({ evaluate: 100, restore: 150, tick: 10, catalogue: 200, search: 50, structuredClone: true }),
    ['evaluate + idioma + restore: NaN ms (meta 300)', 'busca depois do restore: NaN ms (meta 100)',
      'reabrir com outros apelidos: catálogo NaN ms (meta 400), busca NaN ms (meta 100)'])
})
