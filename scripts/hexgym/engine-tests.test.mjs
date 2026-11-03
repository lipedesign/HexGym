// Testes do scripts/hexgym/engine-tests.mjs, que escolhe os testes do lib que rodam contra o script
// do motor (frontend/vitest.hexengine.config.js).
//
//   node --test scripts/hexgym/engine-tests.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { pickEngineTests } from './engine-tests.mjs'

const L = 'frontend/src/lib/', engine = new Set([L + 'onerm.js', L + 'history.js'])
test('a test that only reads engine modules is picked', () => {
  const text = "import { test } from 'vitest'\nimport fc from 'fast-check'\nimport { estimate1RM } from './onerm.js'\n" +
    "import rows from './fixtures/rows.json' with { type: 'json' }\nimport { readFileSync } from 'node:fs'"
  assert.deepEqual(pickEngineTests([{ path: L + 'onerm.test.js', text }], engine).picked, [L + 'onerm.test.js'])
})
test('every other test is left out with its reason', () => {
  const { picked, skipped } = pickEngineTests([
    { path: L + 'a.test.js', text: "import { x } from './onerm.js'\nimport React from 'react'" },
    { path: L + 'b.test.js', text: "import { vi } from 'vitest'\nimport { x } from './onerm.js'\nvi.mock('./history.js')" },
    { path: L + 'c.test.js', text: "export { t } from './i18n.js'\nimport { x } from './onerm.js'" },
    { path: L + 'd.test.js', text: "import { test } from 'vitest'" },
    { path: L + 'e.test.js', text: "import { x } from './history.js'\nconst m = await import('../store/useStore.js')" },
  ], engine)
  assert.deepEqual(picked, [])
  assert.deepEqual(skipped.map(s => [s.path.slice(L.length), s.reason]), [
    ['a.test.js', 'importa react'], ['b.test.js', 'chama vi.mock'], ['c.test.js', 'importa frontend/src/lib/i18n.js'],
    ['d.test.js', 'não importa nenhum módulo do motor'], ['e.test.js', 'importa frontend/src/store/useStore.js']])
})
