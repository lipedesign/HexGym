// Testes do runtime.js, o que o Swift chama, rodando direto no Node, sem o build.
//
//   node --test apple/Packages/HexEngine/JS/runtime.test.mjs
//
// Os testes rodam na ordem e dividem o documento aberto, como o JSContext do app; o último
// abre outra cópia do runtime.js, que ainda não tem documento nenhum. exerciseOf, estimate1RM
// e isoOf vêm direto de frontend/src/lib.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import * as R from './runtime.js'
import { exerciseOf } from '../../../../frontend/src/lib/exercises.js'
import { estimate1RM } from '../../../../frontend/src/lib/onerm.js'
import { isoOf } from '../../../../frontend/src/lib/format.js'

// O documento novo e o restore nunca põem um lang: o HexGym segue o idioma do aparelho (escolha 4 do
// plano da fase 2). O lang de uma cópia do openGym fica como veio.
test('a fresh document is the web app first run, without a language', () => {
  const d = JSON.parse(R.freshDocument())
  assert.deepEqual([Object.hasOwn(d, 'lang'), d.langAuto, d.weighIn, d.gifSize], [false, true, false, 'mini'])
})
test('restore keeps the keys it does not know', () => {
  R.restore('{"chaveDoFuturo":{"x":[1,2]}}'); const d = JSON.parse(R.document())
  assert.deepEqual(d.chaveDoFuturo, { x: [1, 2] }); assert.equal(Object.hasOwn(d, 'lang'), false)
  R.restore('{"lang":"de"}'); assert.equal(JSON.parse(R.document()).lang, 'de')
})
test('restore refuses what is not a JSON object', () => {
  assert.throws(() => R.restore('[1]'), /o documento não é um objeto JSON/); assert.throws(() => R.restore('{'), SyntaxError)
})
test('each document brings its own custom exercises', () => {
  R.restore('{"customEx":[{"id":"c1","n":"Remada do HexGym","bp":"back"}]}'); assert.equal(exerciseOf('c1')?.n, 'Remada do HexGym')
  R.restore('{}'); assert.equal(exerciseOf('c1'), undefined)
})
test('call runs a function and shows the arguments after the call', () => {
  const call = R.makeCall({ 'frontend/src/lib/onerm.js': { estimate1RM } })
  assert.deepEqual(JSON.parse(call('frontend/src/lib/onerm.js#estimate1RM', '[100,5]')), { returned: estimate1RM(100, 5), args: [100, 5] })
  assert.throws(() => call('frontend/src/lib/nope.js#x', '[]'), /frontend\/src\/lib\/nope\.js#x/)
})
test('call decodes the arguments it receives', () => {
  const call = R.makeCall({ 'frontend/src/lib/format.js': { isoOf } }), noon = Date.UTC(2026, 9, 25, 12)
  assert.equal(JSON.parse(call('frontend/src/lib/format.js#isoOf', JSON.stringify([{ $date: noon }]))).returned, isoOf(new Date(noon)))
})
test('document before any document fails', async () => {
  const fresh = await import('./runtime.js?antes'); assert.throws(() => fresh.document(), /nenhum documento aberto/)
})
