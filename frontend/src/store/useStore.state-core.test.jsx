// @vitest-environment happy-dom
// DEF and the state helpers live in lib/state-core.js; the store re-exports them, so everything
// that imports them from here keeps working and gets the very same objects.
import { expect, test, vi } from 'vitest'

vi.mock('../lib/api.js', () => ({ api: vi.fn() }))
vi.mock('./useUI.js', () => ({ useUI: { getState: () => ({ toast: vi.fn() }) } }))

import * as store from './useStore.js'
import { DEF, draftOf, freshState, restartedState, restoredStateFor, hasData } from '../lib/state-core.js'

test('useStore re-exports the same objects', () => {
  expect(store.DEF).toBe(DEF); expect(store.freshState).toBe(freshState); expect(store.restartedState).toBe(restartedState)
  expect(store.draftOf).toBe(draftOf); expect(store.restoredStateFor).toBe(restoredStateFor); expect(store.hasData).toBe(hasData)
})
