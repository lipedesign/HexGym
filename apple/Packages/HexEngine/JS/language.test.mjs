// Testes do language.js, o idioma do motor, rodando direto no Node, sem o build, com os pacotes
// guardados em Sources/HexEngine/Resources/langs (os mesmos que o app carrega).
//
//   node --test apple/Packages/HexEngine/JS/language.test.mjs
//
// Os testes dividem o estado do i18n-core.js, como o JSContext do app: cada um chama o setLanguage
// antes de olhar.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import { setLanguage } from './language.js'
import { descFor, exerciseNameFor, getLang, instrFor, t } from '../../../../frontend/src/lib/i18n-core.js'
import { EXIDX } from '../../../../frontend/src/lib/exercises.js'

// O texto de um pacote guardado, descomprimido.
const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
const en = pack('en')
const source = async file => (await import(`../../../../frontend/src/${file}`)).default

test('after setLanguage(en, pt-BR) the names, steps and descriptions answer in the language, without the English in parentheses', async () => {
  setLanguage(en, pack('pt-BR'))
  const ex = EXIDX['0025']
  assert.equal(getLang(), 'pt-BR')
  assert.equal(exerciseNameFor(ex), (await source('exercise-names/pt-BR.js'))['0025'])
  assert.doesNotMatch(exerciseNameFor(ex), /\(/)
  assert.deepEqual(instrFor(ex), (await source('instr/pt-BR.js'))['0025'])
  // O pt-BR não tem descrições: vale a inglesa, que veio no pacote en.
  assert.equal(descFor(ex), (await source('exercise-desc/en.js'))['0025'])
})

test('t() in pt-BR inherits from pt.js', () => {
  setLanguage(en, pack('pt-BR'))
  assert.equal(t('Routine'), 'Rotina')
})

test('de-CH loads the de pack and derives it: the German wording, with ss in place of ß', async () => {
  setLanguage(en, pack('de'), 'de-CH')
  const de = await source('locales/de.js')
  const key = 'All exercises done. Nice work! Finish up, or add another one if you’ve got more in you.'
  assert.equal(getLang(), 'de-CH')
  assert.equal(t('Routine'), de['Routine'])
  assert.match(de[key], /ß/)
  assert.equal(t(key), de[key].replace(/ß/g, 'ss'))
  assert.equal(exerciseNameFor(EXIDX['1056']), (await source('exercise-names/de.js'))['1056'].replace(/ß/g, 'ss'))
})
