// Testes do texts.js e dos textos que o motor entrega às telas (issue #161), pelo que o Swift chama no
// runtime.js, rodando direto no Node, sem o build, com o pacote pt-BR guardado em
// Sources/HexEngine/Resources/langs:
//   - nenhuma leitura das telas tem travessão (U+2014), meia-risca (U+2013), "undefined" nem "NaN", com
//     os documentos preparados semana-ppl, veio-do-opengym e lados-e-faixa (o FixtureDocuments.swift do
//     app, lido daqui), antes e depois de terminar o treino deles;
//   - a faixa da progressão dupla sai "8-12", e o lado ainda não feito, "D -";
//   - o alvo sem repetições do veio-do-opengym perde as repetições;
//   - a série com tempo por lado chega com o lado de cada linha, e a Live Activity conta os pares.
//
//   node --test apple/Packages/HexEngine/JS/texts.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import * as R from './runtime.js'
import { plain, readableTarget, setsRepsText, targetText } from './texts.js'

const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
R.setLanguage(pack('en'), pack('pt-BR'))

const MIN = 60 * 1000
const DASHES = /[\u2013\u2014]/
const BROKEN = /undefined|NaN/

// Os documentos preparados do app, como texto JSON, pelo nome da constante no FixtureDocuments.swift.
const SWIFT = fs.readFileSync(new URL('../../../HexGym/Fixtures/FixtureDocuments.swift', import.meta.url), 'utf8')
function fixture(name) {
  const m = SWIFT.match(new RegExp(`static let ${name} = #"""\\n([\\s\\S]*?)\\n\\s*"""#`))
  assert.ok(m, `não achei o documento ${name} no FixtureDocuments.swift`)
  const doc = JSON.parse(m[1])
  const now = doc._fixtureNow
  delete doc._fixtureNow
  return { doc, now }
}
const FIXTURES = { 'semana-ppl': 'semanaPPL', 'veio-do-opengym': 'veioDoOpenGym', 'lados-e-faixa': 'ladosEFaixa' }
function open(name) {
  const { doc, now } = fixture(FIXTURES[name])
  R.restore(JSON.stringify(doc))
  return now
}
const act = (action, now) => JSON.parse(R.sessionApply(JSON.stringify(action), now))
const active = now => JSON.parse(R.activeWorkout(now))
const live = now => JSON.parse(R.liveActivity(now))

// Todas as leituras das telas do documento aberto: o treino em andamento, a Live Activity, o Início,
// o histórico inteiro, página por página, o detalhe de cada treino, e as leituras das rotinas da fase 2.
function readings(now) {
  const out = {
    activeWorkout: active(now), liveActivity: live(now), home: JSON.parse(R.home(now)),
    routines: JSON.parse(R.routines()), week: JSON.parse(R.week()), settings: JSON.parse(R.settings()),
    starterPlans: JSON.parse(R.starterPlans()), history: [], workoutDetail: [],
  }
  for (let before = null, more = true; more;) {
    const page = JSON.parse(R.history(JSON.stringify(before == null ? { limit: 5 } : { before, limit: 5 })))
    out.history.push(page)
    for (const item of page.items) out.workoutDetail.push(JSON.parse(R.workoutDetail(item.key)))
    more = page.more
    before = page.items.at(-1)?.key
  }
  out.starterPlanChanges = out.starterPlans.map(p => JSON.parse(R.starterPlanChanges(p.id)))
  return out
}

// Cada texto de um valor, com o caminho dele.
function* texts(value, at = '') {
  if (typeof value === 'string') yield [at, value]
  else if (Array.isArray(value)) for (const [i, v] of value.entries()) yield* texts(v, `${at}[${i}]`)
  else if (value && typeof value === 'object') for (const [k, v] of Object.entries(value)) yield* texts(v, `${at}.${k}`)
}

function assertReadable(name, now) {
  const seen = readings(now)
  let count = 0
  for (const [at, text] of texts(seen)) {
    count++
    assert.doesNotMatch(text, DASHES, `${name}${at}: ${text}`)
    assert.doesNotMatch(text, BROKEN, `${name}${at}: ${text}`)
  }
  return { seen, count }
}

test('no reading has a dash, an en dash, undefined or NaN, before and after the workout ends', () => {
  for (const name of Object.keys(FIXTURES)) {
    const now = open(name)
    const { count } = assertReadable(name, now)
    assert.ok(count > 50, `${name}: só ${count} textos`)
    // O treino em andamento terminado leva as linhas dele para o histórico e para o detalhe.
    if (active(now)) {
      for (let next = active(now).next, i = 1; next; next = active(now + i * MIN).next, i++) act({ type: 'set.mark', ...next, done: true }, now + i * MIN)
      act({ type: 'finish' }, now + 30 * MIN)
      assert.equal(active(now + 30 * MIN), null)
      assertReadable(`${name} terminado`, now + 30 * MIN)
    }
  }
})

test('a rep range reads 8-12 with a plain hyphen, in the workout and in the routine editor', () => {
  const now = open('lados-e-faixa')
  const targets = active(now).entries.map(e => e.target)
  assert.deepEqual(targets, ['2 × 0:30 · por lado', '3 × 8-12 · 60 kg', '3 × 16-20 · 10 kg · 8-10/lado', '10 · 8 · 6 · 80 kg'])
  assert.deepEqual(JSON.parse(R.routines())[0].slots.map(s => s.setsReps), ['2 × 0:30', '3 × 8-12', '3 × 16-20', '10 · 8 · 6'])
  // A progressão tripla tem a faixa das séries também.
  assert.equal(setsRepsText({ mode: 'reps', sets: 3, setsMax: 5, reps: 12, repsMin: 8 }), '3-5 × 8-12')
  assert.equal(plain('a \u2014 b \u2013 c'), 'a - b - c')
})

test('the side not done yet reads with a plain hyphen, where openGym writes an en dash', () => {
  const now = open('veio-do-opengym')
  const curl = active(now).entries[2]
  assert.deepEqual(curl.sets.map(s => s.line), ['E 10×8 · D -', 'E 10×8 · D 10×8'])
})

test('a target without reps loses the reps instead of saying undefined', () => {
  const now = open('veio-do-opengym')
  // A rosca do treino que veio do openGym tem só o modo e o lado no alvo, e o exLine dava
  // "1 × undefined · 0/lado".
  assert.equal(active(now).entries[2].target, '1 série · por lado')
  assert.equal(targetText({ mode: 'reps', sets: 3 }, 'kg'), '3 séries')
  assert.equal(targetText({ mode: 'reps', sets: 3, weight: 20 }, 'kg'), '3 séries · 20 kg')
  assert.equal(targetText({ mode: 'reps', sets: 3, setsMax: 4, weight: 20, bodyweight: true }, 'kg'), '3-4 séries · +20 kg')
  assert.equal(setsRepsText({ mode: 'reps', sets: 2 }), '2 séries')
  // Um número que não é número sai do alvo: as séries ficam com o padrão do openGym (1), e a carga some.
  assert.equal(targetText({ mode: 'reps', sets: 'três', reps: 8, weight: NaN }, 'kg'), '1 × 8')
  assert.equal(targetText({ mode: 'reps', reps: null, weight: 'x' }, 'kg'), '1 série')
  // Uma pirâmide sem nenhum alvo que se leia sai, e o alvo volta a ser o de séries e repetições.
  assert.equal(targetText({ mode: 'reps', sets: 2, reps: 8, pyramid: [null, 'x'] }, 'kg'), '2 × 8')
  assert.equal(targetText({ mode: 'reps', pyramid: [12, null, 'max'] }, 'kg'), '12 · Máx')
  assert.deepEqual(readableTarget(null), {})
  // O alvo de tempo e o cardio ficam com os padrões do openGym.
  assert.equal(targetText({ mode: 'time', sets: 2, sec: 'x', side: true }, 'kg'), '2 × 0:45 · por lado')
  assert.equal(targetText({ mode: 'cardio', min: NaN }, 'kg'), '1 × 20 min @ 8 km/h')
})

test('a timed per-side set reaches the screen with its side, and the Live Activity counts pairs', () => {
  const now = open('lados-e-faixa')
  const plank = active(now).entries[0]
  assert.equal(plank.mode, 'time')
  assert.deepEqual(plank.sets.map(s => s.side), ['L', 'R', 'L', 'R'])
  assert.deepEqual(plank.sets.map(s => s.line), ['0:30', '0:30', '0:30', '0:30'])
  // Só a série com tempo por lado tem lado: a com lados de repetições leva os dois numa linha só.
  assert.ok(active(now).entries.slice(1).every(e => e.sets.every(s => s.side === null)))
  const la = live(now)
  assert.equal(la.cur.setLine, 'Série 1 de 2 (Direita) · 0:30')
  assert.deepEqual(la.ahead.slice(0, 3).map(x => x.setLine), ['Série 2 de 2 (Esquerda) · 0:30', 'Série 2 de 2 (Direita) · 0:30', 'Série 1 de 3 · 60 kg × 12'])
  // Uma série a mais, num treino começado no próprio HexGym, entra como um par com os dois lados.
  act({ type: 'set.add', entry: 0 }, now + MIN)
  assert.deepEqual(active(now + MIN).entries[0].sets.map(s => s.side), ['L', 'R', 'L', 'R', 'L', 'R'])
  assert.equal(live(now + MIN).ahead[1].setLine, 'Série 2 de 3 (Direita) · 0:30')
})
