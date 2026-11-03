// Testes do polyfills.js, o que o JavaScriptCore não tem e o motor usa.
//
//   node --test apple/Packages/HexEngine/JS/polyfills.test.mjs
//
// O Node já tem structuredClone: o primeiro teste compara a cópia com a dele.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { cloneStructured } from './polyfills.js'

test('the copy matches the native structuredClone', () => {
  const a = { n: 1, u: undefined, d: new Date(5), m: new Map([[1, { y: 2 }]]), s: new Set([1, 2]), list: [1, [2]] }
  a.self = a
  const c = cloneStructured(a)
  assert.deepStrictEqual(c, structuredClone(a)); assert.notEqual(c.list, a.list); assert.equal(c.self, c)
})
test('a function cannot be copied', () => assert.throws(() => cloneStructured({ f() {} }), e => e.name === 'DataCloneError'))
test('the native one stays when it exists', () => assert.notEqual(globalThis.structuredClone, cloneStructured))
