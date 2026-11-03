// Testes do values.js, a troca de valores entre o Swift e o motor.
//
//   node --test apple/Packages/HexEngine/JS/values.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { decodeValue, encodeValue } from './values.js'

test('dates, undefined and the numbers JSON cannot hold go and come back', () => {
  const v = { d: new Date(0), u: undefined, n: NaN, i: -Infinity, list: [1, { x: undefined }] }
  assert.deepStrictEqual(decodeValue(JSON.parse(JSON.stringify(encodeValue(v)))), v)
})
test('a Map, a Set or a function is refused', () => {
  for (const v of [new Map(), new Set(), () => 1]) assert.throws(() => encodeValue(v), /valor que o motor não sabe passar/)
})
