// lib/state-core.js on its own: what a profile started from nothing holds, and how a saved copy
// is read back. Nothing but state-core.js is imported here, so these run wherever that module
// does, with no store, no React and no browser storage around it.
import { test, expect, vi } from 'vitest'
import { DEF, freshState, stateFromSaved, detectedLang } from './state-core.js'

test('a fresh state is what the web app starts with', () => {
  const s = freshState('pt-BR')
  expect([s.lang, s.langAuto, s.weighIn, s.gifSize]).toEqual(['en', true, false, 'mini'])
  expect(freshState('ar-EG').lang).toBe('ar')
})
test('without a navigator the language is English', () => {
  vi.stubGlobal('navigator', undefined)                  // Node 22 has a navigator.language, the machine's
  try { expect(detectedLang()).toBe('en') } finally { vi.unstubAllGlobals() }
})
test('a saved copy keeps the keys this version does not know', () => {
  const s = stateFromSaved({ chaveDoFuturo: { x: [1, 2] }, unit: 'lb' })
  expect(s.chaveDoFuturo).toEqual({ x: [1, 2] }); expect(s.unit).toBe('lb'); expect(s.routines).toEqual(DEF.routines)
})
test('a saved copy without a language gets the detected one', () => {
  expect(stateFromSaved({}, 'ar-EG').lang).toBe('ar'); expect(stateFromSaved({ lang: 'de' }, 'ar-EG').lang).toBe('de')
})
