// Testes do library.js, a biblioteca do motor, pelo que o Swift chama no runtime.js (entra e sai
// texto JSON), rodando direto no Node, sem o build, com o documento do freshState e o pacote pt-BR
// guardado em Sources/HexEngine/Resources/langs (os mesmos que o app carrega).
//
//   node --test apple/Packages/HexEngine/JS/library.test.mjs
//
// Os testes dividem o documento aberto e o idioma, como o JSContext do app: cada um abre o
// documento que quer antes de olhar.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import * as R from './runtime.js'
import { CATALOGUE, EXIDX } from '../../../../frontend/src/lib/exercises.js'
import { MUSCLES } from '../../../../frontend/src/lib/muscles.js'

// O texto de um pacote guardado, descomprimido.
const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
const ptBR = async () => (await import('../../../../frontend/src/exercise-names/pt-BR.js')).default

R.setLanguage(pack('en'), pack('pt-BR'))

// Um personalizado antigo: sem categoria e sem equipamento.
const CUSTOM = { id: 'custom-hexgym-1', n: 'Remada do HexGym', bp: 'back', custom: true }

// Abre o documento do primeiro uso com as chaves de extra por cima, como o app abre uma cópia salva.
function open(extra = {}) {
  const doc = JSON.parse(R.freshDocument())
  R.restore(JSON.stringify({ ...doc, ...extra }))
}
const catalogue = () => JSON.parse(R.catalogue())
const search = query => JSON.parse(R.search(JSON.stringify(query))).ids

test('catalogue() lists every exercise in the language, the custom one without a category', async () => {
  open({ customEx: [CUSTOM] })
  const list = catalogue()
  assert.equal(list.length, CATALOGUE.length + 1)
  assert.equal(CATALOGUE.length, 5632)
  // A ordem do allExercises: os personalizados primeiro.
  assert.deepEqual(list[0], {
    id: CUSTOM.id, name: CUSTOM.n, bp: 'back', equipment: [], category: null, muscles: list[0].muscles, favourite: false, custom: true,
  })
  const bench = list.find(e => e.id === '0025')
  assert.equal(bench.name, (await ptBR())['0025'])
  assert.equal(bench.muscles.chest, 1)
  assert.deepEqual([bench.bp, bench.equipment, bench.category, bench.custom], ['chest', ['barbell'], 'strength', false])
})

test('search finds the same first result for supino, SUPINO and supíno, and it is the 0025', () => {
  open()
  const results = ['supino', 'SUPINO', 'supíno'].map(query => search({ query }))
  for (const ids of results) {
    assert.ok(ids.length > 0)
    assert.equal(ids[0], '0025')
  }
})

test('search finds the 0025 by its English name with the device in pt-BR', () => {
  open()
  assert.ok(search({ query: 'bench press' }).includes('0025'))
})

test('the chest filter keeps only exercises that train the chest', () => {
  open()
  const muscles = new Map(catalogue().map(e => [e.id, e.muscles]))
  const ids = search({ muscles: ['chest'] })
  assert.ok(ids.length > 0 && ids.length < CATALOGUE.length)
  for (const id of ids) assert.ok(Object.hasOwn(muscles.get(id), 'chest'), id)
  assert.ok(ids.includes('0025'))
})

test('favouritesOnly keeps only the favourites', () => {
  open({ favEx: ['0043', '0025'] })
  assert.deepEqual(new Set(search({ favouritesOnly: true })), new Set(['0043', '0025']))
  assert.deepEqual(search({ query: 'supino', favouritesOnly: true }), ['0025'])
})

test('a favourite comes first, in the search and without one', () => {
  open()
  const plain = search({ query: 'supino' })
  const second = plain[1]
  open({ favEx: [second] })
  const ranked = search({ query: 'supino' })
  assert.equal(ranked[0], second)
  assert.deepEqual(new Set(ranked), new Set(plain))
  const all = search({})
  assert.equal(all[0], second)
  assert.equal(all.length, CATALOGUE.length)
  assert.deepEqual(catalogue().filter(e => e.favourite).map(e => e.id), [second])
})

test('an id that does not exist is an unknown exercise, with the name from t()', () => {
  open()
  const detail = JSON.parse(R.exercise('nao-existe'))
  assert.equal(detail.known, false)
  assert.equal(detail.name, 'Exercício desconhecido')
  const bench = JSON.parse(R.exercise('0025'))
  assert.equal(bench.known, true)
  assert.equal(bench.nameEnglish, EXIDX['0025'].n)
  assert.ok(bench.instructions.length > 0)
})

// Issue #97: um grupo fora do MUSCLES (o "cardiovascular system" do burpee, 1160, e de um
// personalizado de cardio do openGym) também vem com o nome no idioma, pelo MUSCLE_NAME e o t().
test('exercise() names every muscle group it has, the ones outside MUSCLES too', () => {
  open({ customEx: [{ id: 'custom-cardio', n: 'Corrida do HexGym', bp: 'cardio', custom: true, primaries: ['cardiovascular system'] }] })
  const burpee = JSON.parse(R.exercise('1160'))
  assert.equal(burpee.muscles['cardiovascular system'], 1)
  assert.equal(burpee.muscleNames['cardiovascular system'], 'sistema cardiovascular')
  assert.equal(burpee.muscleNames.chest, 'Peito')
  assert.deepEqual(Object.keys(burpee.muscleNames).sort(), Object.keys(burpee.muscles).sort())
  const custom = JSON.parse(R.exercise('custom-cardio'))
  assert.equal(custom.muscleNames['cardiovascular system'], 'sistema cardiovascular')
  assert.deepEqual(JSON.parse(R.exercise('nao-existe')).muscleNames, {})
})

test('facets() has the 18 muscle groups and the 11 body parts, named in the language', () => {
  open()
  const facets = JSON.parse(R.facets())
  assert.deepEqual(facets.muscles.map(m => m.id), MUSCLES)
  assert.equal(facets.muscles.length, 18)
  assert.equal(facets.muscles.find(m => m.id === 'chest').name, 'Peito')
  assert.equal(facets.bodyParts.length, 11)
  assert.equal(facets.bodyParts.find(b => b.id === 'upper legs').name, 'pernas')
  assert.equal(facets.equipment.length, 34)
  assert.equal(facets.categories[0].id, 'strength')
})

// Issue #114: o exercise() diz se os passos e a descrição vieram do pacote do idioma ou do inglês, o
// fallback do instrFor e do descFor (o instrTranslated do openGym). Em pt-BR, o pacote traduz os passos
// de 1.324 exercícios e nenhuma descrição; o de tem 12 descrições. Em inglês, nada vem de um pacote de
// idioma, e os dois são false, como o instrTranslated do openGym.
test('exercise() says whether the steps and the description came translated', () => {
  open({ customEx: [{ id: 'custom-passos', n: 'Remada do HexGym', bp: 'back', custom: true, st: ['Puxe a barra.'] }] })
  const flags = id => {
    const detail = JSON.parse(R.exercise(id))
    return [detail.instructionsTranslated, detail.descriptionTranslated]
  }
  assert.deepEqual(flags('0025'), [true, false])
  assert.ok(JSON.parse(R.exercise('0264')).instructions.length > 0)
  assert.deepEqual(flags('0264'), [false, false])
  // O personalizado mostra os passos dele, e não os de um pacote: false, como no openGym.
  assert.deepEqual(JSON.parse(R.exercise('custom-passos')).instructions, ['Puxe a barra.'])
  assert.deepEqual(flags('custom-passos'), [false, false])
  assert.deepEqual(flags('nao-existe'), [false, false])
  try {
    R.setLanguage(pack('en'), pack('de'))
    assert.deepEqual(flags('1000'), [true, true])
    assert.equal(flags('0025')[1], false)
    R.setLanguage(pack('en'))
    assert.deepEqual(flags('0025'), [false, false])
  } finally {
    R.setLanguage(pack('en'), pack('pt-BR'))
  }
})
