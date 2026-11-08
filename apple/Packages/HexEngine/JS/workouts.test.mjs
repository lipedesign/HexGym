// Testes do workouts.js, o histórico no documento aberto (a lista, o detalhe) e da ação
// workout.delete do actions.js, pelo que o Swift chama no runtime.js (entra e sai texto JSON),
// rodando direto no Node, sem o build, com o documento do freshState e o pacote pt-BR guardado em
// Sources/HexEngine/Resources/langs. Um teste por item da Task 5 do plano da fase 3.
//
//   node --test apple/Packages/HexEngine/JS/workouts.test.mjs
//
// Os testes dividem o documento aberto, como o JSContext do app: cada um abre o que quer antes.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import * as R from './runtime.js'
import { sessionVolume, setsDone, workSetsDone } from '../../../../frontend/src/lib/history.js'
import { isoOf } from '../../../../frontend/src/lib/format.js'
import { legacySyncKey } from '../../../../frontend/src/lib/workout-date.js'

const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
R.setLanguage(pack('en'), pack('pt-BR'))

const MIN = 60 * 1000
// Segunda-feira, 9 de novembro de 2026, 10 h no relógio da máquina.
const NOW = new Date(2026, 10, 9, 10, 0).getTime()
const BENCH = '0025'   // supino com barra
const INCLINE = '0047' // supino inclinado com barra
const CURL = '0294'    // rosca com halteres
const GONE = 'exercicio-de-outro-aparelho'

// Um treino salvo como o buildCompletedWorkout grava, no dia day de novembro de 2026, começando às
// hour horas e durando 50 minutos.
function saved(id, day, hour, extra = {}) {
  const start = new Date(2026, 10, day, hour, 0).getTime()
  const w = { d: isoOf(new Date(start)), start, end: start + 50 * MIN, routineIds: [], routineId: null, name: `Treino ${id ?? day}`, bw: 80, entries: [], prs: [], ...extra }
  return id == null ? w : { id, ...w }
}
const set = (w, r, extra = {}) => ({ w, r, done: true, ...extra })

// Abre o documento do primeiro uso com as chaves de extra por cima, como o app abre uma cópia salva.
function open(extra = {}) {
  const doc = JSON.parse(R.freshDocument())
  R.restore(JSON.stringify({ ...doc, ...structuredClone(extra) }))
}
const doc = () => JSON.parse(R.document())
const history = query => JSON.parse(R.history(JSON.stringify(query)))
const detail = key => JSON.parse(R.workoutDetail(key))
const apply = (action, now = NOW) => JSON.parse(R.apply(JSON.stringify(action), now))
const keys = page => page.items.map(i => i.key)

test('history lists the newest first, by the day and then the start, in pages of limit with the right more', () => {
  // Guardados fora de ordem: o b e o c no mesmo dia, o c guardado depois mas começando antes; o d
  // no dia 0, que é 31 de outubro.
  open({ workouts: [saved('a', 2, 8), saved('b', 6, 18), saved('c', 6, 7), saved('d', 0, 9), saved('e', 4, 12)] })
  const first = history({ limit: 2 })
  assert.deepEqual(keys(first), ['b', 'c']); assert.equal(first.more, true)
  const second = history({ before: 'c', limit: 2 })
  assert.deepEqual(keys(second), ['e', 'a']); assert.equal(second.more, true)
  const last = history({ before: 'a', limit: 2 })
  assert.deepEqual(keys(last), ['d']); assert.equal(last.more, false)
  assert.deepEqual(keys(history({ limit: 5 })), ['b', 'c', 'e', 'a', 'd']); assert.equal(history({ limit: 5 }).more, false)
  // O Início e o Histórico concordam sobre qual é o último treino (a mesma ordem, do session.js).
  assert.equal(JSON.parse(R.home(NOW)).last.id, history({ limit: 1 }).items[0].id)
  // A página depois de uma chave que não existe, ou um limit que não é um inteiro de 1 para cima,
  // lança.
  assert.throws(() => history({ before: 'nao-existe', limit: 2 }), TypeError)
  for (const limit of [0, -1, 1.5, '2', undefined]) assert.throws(() => history({ limit }), TypeError)
  // O histórico vazio.
  open()
  assert.deepEqual(history({ limit: 60 }), { items: [], more: false })
})

test('an item carries the duration, the sets, the volume and the records, as the openGym row reads them', () => {
  const w = saved('w1', 6, 18, {
    prs: [BENCH],
    entries: [
      { id: BENCH, target: { sets: 3, reps: 8, weight: 60 }, sets: [set(40, 8, { warmup: true }), set(60, 8), set(62.5, 8), set(62.5, 7), { w: 62.5, r: 8, done: false }] },
      { id: CURL, target: { sets: 2, reps: 10, weight: 12 }, sets: [set(12, 10), set(12, 10)] },
    ],
  })
  // Um treino antigo sem as séries, só com o volume guardado.
  const legacy = saved('w0', 2, 8, { entries: undefined, vol: 4321 })
  open({ workouts: [legacy, w] })
  const [item, old] = history({ limit: 10 }).items
  assert.deepEqual(item, {
    key: 'w1', id: 'w1', d: '2026-11-06', name: 'Treino w1', start: w.start, end: w.end, durationMs: 50 * MIN,
    sets: { done: setsDone(w), work: workSetsDone(w) }, volume: sessionVolume(w, doc()), unit: 'kg', prs: [BENCH],
  })
  // O aquecimento conta nas séries feitas e fica fora das de trabalho e do volume.
  assert.deepEqual(item.sets, { done: 6, work: 5 })
  assert.equal(item.volume, 60 * 8 + 62.5 * 8 + 62.5 * 7 + 2 * 12 * 10)
  assert.deepEqual([old.volume, old.sets, old.prs], [4321, { done: 0, work: 0 }, []])
  // Com "Contar aquecimento no volume" do openGym, o volume da tela conta o aquecimento.
  open({ workouts: [w], volumeWarmups: true, unit: 'lb' })
  const lb = history({ limit: 1 }).items[0]
  assert.equal(lb.volume, 40 * 8 + 60 * 8 + 62.5 * 8 + 62.5 * 7 + 2 * 12 * 10); assert.equal(lb.unit, 'lb')
})

test('the detail carries the lines, the warm-up marked and the record set', () => {
  const w = saved('w1', 6, 18, {
    prs: [BENCH], note: 'Bom treino',
    entries: [
      { id: BENCH, target: { sets: 3, reps: 8, weight: 60 }, sets: [set(40, 8, { warmup: true }), set(60, 8), set(62.5, 8, { hr: { avg: 132, max: 151 } }), set(62.5, 7, { rir: 2 }), { w: 62.5, r: 8, done: false }] },
      { id: CURL, target: { sets: 2, reps: 10, weight: 12 }, sg: 'g1', sets: [set(12, 10), set(12, 9, { failure: true })] },
      { id: INCLINE, target: { sets: 1, reps: 10, weight: 40 }, sg: 'g1', sets: [set(40, 10)] },
      { id: GONE, target: { sets: 1, reps: 5, weight: 20 }, sets: [set(20, 5)] },
    ],
  })
  open({ workouts: [w] })
  const d = detail('w1')
  assert.deepEqual([d.key, d.name, d.d, d.start, d.end, d.durationMs, d.unit, d.note, d.bw, d.prs], ['w1', 'Treino w1', '2026-11-06', w.start, w.end, 50 * MIN, 'kg', 'Bom treino', 80, [BENCH]])
  assert.equal(d.volume, history({ limit: 1 }).items[0].volume)
  assert.deepEqual(d.entries.map(e => [e.id, e.name, e.known, e.sg, e.sgLetter, e.pr]), [
    [BENCH, 'supino com barra', true, null, null, true],
    [CURL, 'Rosca bíceps com halteres', true, 'g1', 'A', false],
    [INCLINE, 'supino inclinado com barra', true, 'g1', 'A', false],
    // O exercício que não existe neste aparelho (Foco da revisão 5).
    [GONE, 'Exercício desconhecido', false, null, null, false],
  ])
  // Só as séries feitas, como o detalhe do openGym (sheets.jsx:2808); o recorde é a primeira série
  // de trabalho com a melhor carga; o openGym escreve a falha, o esforço e o batimento depois da
  // carga.
  assert.deepEqual(d.entries[0].sets, [
    { line: '40 kg × 8', done: true, warmup: true, pr: false },
    { line: '60 kg × 8', done: true, warmup: false, pr: false },
    { line: '62,5 kg × 8 ♥ 132/151', done: true, warmup: false, pr: true },
    { line: '62,5 kg × 7 (RIR 2)', done: true, warmup: false, pr: false },
  ])
  assert.deepEqual(d.entries[1].sets.map(s => s.line), ['12 kg × 10', '12 kg × 9 F'])
  assert.equal(d.entries[1].sets.some(s => s.pr), false)
  // Uma chave que não existe dá null.
  assert.equal(detail('nao-existe'), null)
})

test('a legacy workout without an id shows, opens and is deleted by its key, without taking the others without an id', () => {  // sheets.jsx:2929
  const old1 = saved(null, 2, 8, { name: 'Antigo 1', entries: [{ id: BENCH, sets: [set(50, 5)] }] })
  const old2 = saved(null, 3, 8, { name: 'Antigo 2' })
  const old3 = saved(null, 4, 8, { name: 'Antigo 3' })
  const withId = saved('w1', 5, 8)
  open({ workouts: [old1, old2, old3, withId] })
  const key = legacySyncKey(old2)
  const items = history({ limit: 10 }).items
  assert.deepEqual(items.map(i => [i.key, i.id]), [['w1', 'w1'], [legacySyncKey(old3), null], [key, null], [legacySyncKey(old1), null]])
  assert.equal(detail(key).name, 'Antigo 2')
  assert.equal(detail(legacySyncKey(old1)).entries[0].sets[0].line, '50 kg × 5')
  // A página depois de um treino sem id.
  assert.deepEqual(keys(history({ before: key, limit: 10 })), [legacySyncKey(old1)])
  const out = apply({ type: 'workout.delete', key })
  assert.equal(out.changed, true)
  assert.deepEqual(doc().workouts.map(w => w.name), ['Antigo 1', 'Antigo 3', 'Treino w1'])
  assert.equal(detail(key), null)
})

test('workout.delete stamps the change, and an unknown key throws', () => {
  const a = saved('a', 2, 8), b = saved('b', 3, 8)
  open({ workouts: [a, b], _ts: 5 })
  const before = doc()
  const out = apply({ type: 'workout.delete', key: 'a' })
  assert.deepEqual(out, { changed: true, result: {} })
  const after = doc()
  assert.equal(after._ts, NOW)
  // A remoção fica registrada para a sincronização não trazer o treino de volta.
  assert.equal(after.deleted.workouts.a, NOW); assert.equal(Object.hasOwn(after.deleted.workouts, 'b'), false)
  assert.deepEqual(after.workouts, [b]); assert.deepEqual(after.routines, before.routines)
  // A chave que não existe (o treino já apagado) e a que não é texto lançam, e o documento fica.
  for (const key of ['a', 'nao-existe', 7, undefined]) {
    assert.throws(() => apply({ type: 'workout.delete', key }, NOW + MIN), TypeError)
  }
  assert.deepEqual(doc(), after)
})
