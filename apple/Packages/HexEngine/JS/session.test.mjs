// Testes do session.js, o treino em andamento no documento aberto e as leituras das telas, pelo que o
// Swift chama no runtime.js (entra e sai texto JSON), rodando direto no Node, sem o build, com o
// documento do freshState e o pacote pt-BR guardado em Sources/HexEngine/Resources/langs. As regras
// do treino têm os testes delas no frontend/src/lib/session-controller.test.js; aqui ficam o carimbo,
// as leituras e os eventos da Live Activity, um teste por item da Task 4 do plano da fase 3.
//
//   node --test apple/Packages/HexEngine/JS/session.test.mjs
//
// Os testes dividem o documento aberto, como o JSContext do app: cada um abre o que quer antes.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import * as R from './runtime.js'
import { LIVE_AHEAD, LIVE_BUDGET, LIVE_NAME_MAX, liveBytes } from './session.js'
import { restSecFor } from '../../../../frontend/src/lib/supersetFlow.js'
import { setUnitsTotal, setsDoneActive } from '../../../../frontend/src/lib/history.js'
import { isoOf } from '../../../../frontend/src/lib/format.js'

const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
R.setLanguage(pack('en'), pack('pt-BR'))

const SEC = 1000
const MIN = 60 * SEC
// Segunda-feira, 9 de novembro de 2026, 10 h no relógio da máquina.
const NOW = new Date(2026, 10, 9, 10, 0).getTime()
const BENCH = '0025'   // supino com barra
const INCLINE = '0047' // supino inclinado com barra
const CURL = '0294'    // rosca com halteres
const ROW = '0027'     // remada curvada com barra
const SQUAT = '0043'   // agachamento com barra
const PLANK = '0464'   // prancha, isométrico
const GONE = 'exercicio-de-outro-aparelho'

const slot = (id, extra = {}) => ({ id, sets: 3, reps: 8, weight: 60, mode: 'reps', ...extra })
// A semana de PPL: Push na segunda (com um superset de rosca e supino inclinado), Pull na quarta e
// Legs na sexta, cada rotina com o _ts da última edição.
const PUSH = { id: 'r-push', name: 'Push', emoji: 'barbell', _ts: 11, ex: [slot(BENCH), slot(CURL, { sets: 2, reps: 10, weight: 12, sg: 'g1' }), slot(INCLINE, { sets: 2, reps: 10, weight: 40, sg: 'g1' })] }
const PULL = { id: 'r-pull', name: 'Pull', emoji: 'pullup', _ts: 12, ex: [slot(ROW)] }
const LEGS = { id: 'r-legs', name: 'Legs', emoji: 'figureStrength', _ts: 13, ex: [slot(SQUAT, { reps: 5, weight: 100 })] }
const PPL = { routines: [PUSH, PULL, LEGS], week: { 1: ['r-push'], 3: ['r-pull'], 5: ['r-legs'] } }

// Abre o documento do primeiro uso com as chaves de extra por cima, como o app abre uma cópia salva.
function open(extra = {}) {
  const doc = JSON.parse(R.freshDocument())
  R.restore(JSON.stringify({ ...doc, ...structuredClone(extra) }))
}
const act = (action, now = NOW) => JSON.parse(R.sessionApply(JSON.stringify(action), now))
const doc = () => JSON.parse(R.document())
const active = now => JSON.parse(R.activeWorkout(now))
const homeAt = now => JSON.parse(R.home(now))
const live = now => JSON.parse(R.liveActivity(now))
const events = (list, now) => JSON.parse(R.liveEvents(JSON.stringify(list), now))
const types = effects => effects.map(e => e.type)

// Marca a série que o "Série feita" marca até não sobrar nenhuma, uma por minuto depois de at.
function markAll(at) {
  for (let next = active(at).next, i = 1; next; next = active(at + i * MIN).next, i++) act({ type: 'set.mark', ...next, done: true }, at + i * MIN)
}

test('sessionApply stamps the change: the moved active takes the now, and the routines keep their stamps', () => {
  open(PPL)
  const before = doc()
  const started = act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  assert.equal(started.changed, true)
  assert.deepEqual(started.result, { id: 'w-1' }); assert.deepEqual(types(started.effects), ['activity.start'])
  const after = doc()
  assert.equal(after._ts, NOW); assert.equal(after.active.id, 'w-1')
  assert.deepEqual(after.routines.map(r => r._ts), [11, 12, 13]); assert.deepEqual(after.edited, before.edited)
  act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + MIN)
  assert.equal(doc()._ts, NOW + MIN)
  // O mesmo estado de novo não muda nada, e o carimbo fica.
  assert.deepEqual(act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + 2 * MIN), { changed: false, effects: [], result: null })
  assert.equal(doc()._ts, NOW + MIN)
  // O finish devolve as rotinas e o dayPlan pelo refillAfter com o mesmo conteúdo: o stampChange
  // compara por valor, e nenhum dos dois ganha carimbo (nota da Task 3 na issue #133).
  const edited = doc().edited
  const finished = act({ type: 'finish' }, NOW + 10 * MIN)
  assert.equal(finished.changed, true); assert.equal(finished.result.id, 'w-1')
  const end = doc()
  assert.deepEqual(end.routines.map(r => r._ts), [11, 12, 13]); assert.deepEqual(end.dayPlan, before.dayPlan)
  assert.deepEqual(end.edited, edited); assert.equal(end.active, null)
})

test('an invalid action throws and leaves the document as it was', () => {
  open(PPL)
  const rejects = action => {
    const before = R.document()
    assert.throws(() => R.sessionApply(JSON.stringify(action), NOW), TypeError, JSON.stringify(action))
    assert.equal(R.document(), before)
  }
  rejects({ type: 'set.mark', entry: 0, set: 0, done: true })   // sem treino
  rejects({ type: 'start', routineIds: ['r-push'] })            // sem id
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  rejects({ type: 'set.mark', entry: 9, set: 0, done: true })
  rejects({ type: 'set.update', entry: 0, set: 0, fields: { w: 1001 } })
  rejects({ type: 'treino.inventado' })
  rejects({ type: 'start', routineIds: [], id: 'w-2' })         // já há um treino
})

test('activeWorkout reads the PPL Push in pt-BR, with the lines, the superset letter, the next set and the counts', () => {
  open(PPL)
  assert.equal(R.activeWorkout(NOW), 'null')
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + MIN)
  const w = active(NOW + MIN + 10 * SEC)
  assert.deepEqual([w.id, w.name, w.start, w.unit, w.effort, w.cur], ['w-1', 'Push', NOW, 'kg', 'none', 0])
  assert.deepEqual(w.entries.map(e => e.name), ['supino com barra', 'Rosca bíceps com halteres', 'supino inclinado com barra'])
  assert.deepEqual(w.entries.map(e => [e.sg, e.sgLetter]), [[null, null], ['g1', 'A'], ['g1', 'A']])
  assert.deepEqual(w.entries[0].sets.map(s => s.line), ['60 kg × 8', '60 kg × 8', '60 kg × 8'])
  assert.deepEqual(w.entries[0].sets[0], { index: 0, w: 60, r: 8, sec: null, rir: null, rpe: null, done: true, warmup: false, kind: 'normal', line: '60 kg × 8' })
  assert.deepEqual([w.entries[0].target, w.entries[0].increment, w.entries[0].known, w.entries[0].mode], ['3 × 8 · 60 kg', 2.5, true, 'reps'])
  assert.deepEqual(w.next, { entry: 0, set: 1 })
  assert.deepEqual([w.done, w.total], [1, 7])
  assert.deepEqual(w.rest, { endsAt: NOW + MIN + 90 * SEC, total: 90, forIdx: 0, forSet: 0, kind: 'rest', remaining: 80 })
  // O exercício atual feito leva o next ao superset, que vai volta por volta.
  act({ type: 'set.mark', entry: 0, set: 1, done: true }, NOW + 3 * MIN)
  act({ type: 'set.mark', entry: 0, set: 2, done: true }, NOW + 5 * MIN)
  assert.deepEqual(active(NOW + 5 * MIN).next, { entry: 1, set: 0 })
  act({ type: 'set.mark', entry: 1, set: 0, done: true }, NOW + 7 * MIN)
  assert.deepEqual(active(NOW + 7 * MIN).next, { entry: 2, set: 0 })

  // Um exercício que não existe neste aparelho é o "Exercício desconhecido", e não derruba a tela
  // (Foco da revisão 5); a série com lados conta um por lado, como a barra do openGym.
  const side = { sec: 30, w: 0, done: false }
  open({ ...PPL, active: {
    id: 'w-2', d: isoOf(new Date(NOW)), start: NOW, routineIds: [], name: 'Livre', bw: null, cur: 0, workoutView: 'cards',
    entries: [
      { id: GONE, target: { sets: 1, reps: 5, weight: 20, mode: 'reps' }, sets: [{ w: 20, r: 5, done: false }] },
      { id: PLANK, target: { mode: 'time', sec: 30, side: true }, sets: [{ ...side, side: 'L' }, { ...side, side: 'R' }] },
      { id: CURL, target: { mode: 'reps', side: true }, sets: [{ w: 10, r: 16, done: false, sides: { L: { w: 10, r: 8, done: true }, R: { w: 10, r: 8, done: false } } }] },
    ],
  } })
  const odd = active(NOW)
  assert.deepEqual([odd.entries[0].known, odd.entries[0].name, odd.entries[0].sets[0].line], [false, 'Exercício desconhecido', '20 kg × 5'])
  assert.deepEqual(odd.entries[2].sets[0].kind, 'sides')
  assert.deepEqual([odd.done, odd.total], [setsDoneActive(doc().active), setUnitsTotal(doc().active.entries)])
  assert.deepEqual([odd.done, odd.total], [1, 5])
})

test('home gives the PPL week: planned on Monday, rest on Sunday, done after the workout, the week in order and the last workout', t => {
  // O streakWeeks do openGym lê o relógio por dentro: o relógio falso do node --test o prende.
  t.mock.timers.enable({ apis: ['Date'], now: NOW })
  open(PPL)
  const monday = homeAt(NOW)
  assert.deepEqual(monday.today, { date: '2026-11-09', status: 'planned', routines: [{ id: 'r-push', name: 'Push', glyph: 'barbell' }] })
  assert.deepEqual(monday.week.map(d => d.day), [1, 2, 3, 4, 5, 6, 0])
  assert.deepEqual(monday.week.map(d => d.date), ['2026-11-09', '2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13', '2026-11-14', '2026-11-15'])
  assert.deepEqual(monday.week.map(d => d.planned), [true, false, true, false, true, false, false])
  assert.deepEqual(monday.week.map(d => d.today), [true, false, false, false, false, false, false])
  assert.deepEqual([monday.active, monday.streakWeeks, monday.weekCount, monday.total, monday.last], [null, 0, 0, 0, null])
  const sunday = new Date(2026, 10, 15, 10).getTime()
  assert.deepEqual([homeAt(sunday).today.status, homeAt(sunday).today.routines], ['rest', []])

  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + MIN)
  assert.deepEqual(homeAt(NOW + MIN).active, { name: 'Push', start: NOW, done: 1, total: 7 })
  act({ type: 'finish' }, NOW + 20 * MIN)
  const after = homeAt(NOW + 30 * MIN)
  assert.equal(after.today.status, 'done'); assert.equal(after.active, null)
  assert.deepEqual(after.week.map(d => d.trained), [true, false, false, false, false, false, false])
  assert.deepEqual([after.streakWeeks, after.weekCount, after.total], [1, 1, 1])
  assert.deepEqual(after.last, { key: 'w-1', id: 'w-1', name: 'Push', d: '2026-11-09', durationMs: 20 * MIN, sets: 1 })

  // A semana que começa no domingo, e o documento novo, sem rotinas e sem histórico (Foco da revisão 5).
  open({ ...PPL, weekStart: 0 })
  assert.deepEqual(homeAt(NOW).week.map(d => d.day), [0, 1, 2, 3, 4, 5, 6])
  assert.equal(homeAt(NOW).week[0].date, '2026-11-08')
  open()
  const empty = homeAt(NOW)
  assert.deepEqual([empty.today.status, empty.today.routines, empty.streakWeeks, empty.weekCount, empty.total, empty.last], ['none', [], 0, 0, 0, null])
})

test('liveActivity carries the next set, the rest and up to 8 sets after it, within the byte budget', () => {
  open(PPL)
  assert.equal(R.liveActivity(NOW), 'null')
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + MIN)
  // Lida no mesmo ms em que o descanso começou, como o app lê logo depois da ação: o cur marca depois
  // do descanso que conta, e o descanso dele sai inteiro (rodada 2 do PR #156).
  assert.equal(live(NOW + MIN).cur.restAfter, 90)
  const at = NOW + MIN + 10 * SEC
  const la = live(at)
  const next = active(at).next
  assert.deepEqual([la.cur.entry, la.cur.set], [next.entry, next.set])
  assert.deepEqual(la.cur, { entry: 0, set: 1, exId: BENCH, exercise: 'Supino Com Barra', setLine: 'Série 2 de 3 · 60 kg × 8', restAfter: 90 })
  assert.deepEqual([la.name, la.done, la.total, la.restEndsAt, la.restTotal], ['Push', 1, 7, NOW + MIN + 90 * SEC, 90])
  // O resto do supino e o superset volta por volta, que só descansa no fim da volta (o maior dos
  // dois descansos do grupo, pelo restSecFor).
  const group = restSecFor(doc().active.entries, [1, 2], 90)
  assert.deepEqual(la.ahead.map(x => [x.entry, x.set, x.restAfter]), [[0, 2, 90], [1, 0, 0], [2, 0, group], [1, 1, 0], [2, 1, 0]])
  assert.ok(!la.ahead.some(x => x.entry === la.cur.entry && x.set === la.cur.set))

  // Nomes de 70 letras de duas vezes 2 bytes: cortados em 40, e o JSON abaixo dos 3.600 bytes.
  const long = 'ã'.repeat(70)
  const custom = { id: 'custom-longo', n: long, bp: 'back', custom: true }
  open({ customEx: [custom], routines: [{ id: 'r-l', name: long, ex: [slot('custom-longo', { sets: 12 })] }] })
  act({ type: 'start', routineIds: ['r-l'], id: 'w-2' })
  const big = live(NOW)
  assert.equal(big.ahead.length, LIVE_AHEAD)
  assert.equal(Array.from(big.cur.exercise).length, LIVE_NAME_MAX); assert.equal(Array.from(big.name).length, LIVE_NAME_MAX)
  assert.ok(liveBytes(big) < LIVE_BUDGET, `${liveBytes(big)} bytes`)

  // Nomes de 4 bytes por letra e drop sets de 20 quedas passam do orçamento com as 8 séries pela
  // frente: o ahead encolhe do fim até o JSON caber nos 3.600 bytes.
  const drops = Array.from({ length: 20 }, (_, k) => ({ w: 58 - 2 * k, r: 6 }))
  const heavy = { id: 'custom-quedas', n: '💪'.repeat(70), bp: 'chest', custom: true }
  open({ customEx: [heavy], active: {
    id: 'w-4', d: isoOf(new Date(NOW)), start: NOW, routineIds: [], name: '💪'.repeat(70), bw: null, cur: 0, workoutView: 'cards',
    entries: [{ id: 'custom-quedas', target: { mode: 'reps', sets: 12, reps: 8, weight: 60 }, sets: Array.from({ length: 12 }, () => ({ w: 60, r: 8, done: false, type: 'dropset', drops })) }],
  } })
  const trimmed = live(NOW)
  assert.ok(trimmed.ahead.length > 0 && trimmed.ahead.length < LIVE_AHEAD, `${trimmed.ahead.length} séries pela frente`)
  assert.ok(liveBytes(trimmed) <= LIVE_BUDGET, `${liveBytes(trimmed)} bytes`)
  assert.deepEqual(trimmed.ahead.map(x => x.set), Array.from({ length: trimmed.ahead.length }, (_, k) => k + 1))

  // O done e o total da Live Activity contam linhas, como o buildLiveActivity do openGym: a série
  // com lados é uma linha, feita só com os dois lados feitos. A tela do treino conta por lado.
  const sideRow = (L, R) => ({ w: 10, r: 16, done: L && R, sides: { L: { w: 10, r: 8, done: L }, R: { w: 10, r: 8, done: R } } })
  open({ active: {
    id: 'w-5', d: isoOf(new Date(NOW)), start: NOW, routineIds: [], name: 'Livre', bw: null, cur: 0, workoutView: 'cards',
    entries: [{ id: CURL, target: { mode: 'reps', side: true }, sets: [sideRow(true, true), sideRow(true, false)] }],
  } })
  assert.deepEqual([live(NOW).done, live(NOW).total], [1, 2])
  assert.deepEqual([active(NOW).done, active(NOW).total], [3, 4])

  // A pausa de trocar de lado não aparece na Live Activity.
  const side = { sec: 30, w: 0, done: false }
  open({ active: {
    id: 'w-3', d: isoOf(new Date(NOW)), start: NOW, routineIds: [], name: 'Livre', bw: null, cur: 0, workoutView: 'cards',
    entries: [{ id: PLANK, target: { mode: 'time', sec: 30, side: true }, sets: [{ ...side, side: 'L' }, { ...side, side: 'R' }, { ...side, side: 'L' }, { ...side, side: 'R' }] }],
  } })
  act({ type: 'set.mark', entry: 0, set: 0, done: true })
  assert.equal(active(NOW).rest.kind, 'switch')
  assert.deepEqual([live(NOW).restEndsAt, live(NOW).restTotal], [null, null])
})

test('liveEvents applies each event once, at the tap, and ignores what no longer means anything', () => {
  open(PPL)
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  const tap = (id, extra) => ({ id, wid: 'w-1', kind: 'set.done', entry: 0, set: 0, exId: BENCH, at: NOW + MIN, ...extra })

  // O mesmo set.done duas vezes marca uma vez só (Foco da revisão 3). O at do Swift chega com fração
  // de ms, e a série guarda o ms inteiro.
  const first = events([tap('e-1', { at: NOW + MIN + 0.4 }), tap('e-1', { at: NOW + MIN + 0.4 })], NOW + MIN + 5 * SEC)
  assert.deepEqual(first.applied, ['e-1'])
  assert.deepEqual(types(first.effects), ['haptic', 'rest.started', 'activity.update'])
  assert.deepEqual(first.effects[1], { type: 'rest.started', endsAt: NOW + MIN + 90 * SEC, total: 90, kind: 'rest' })
  assert.equal(doc().active.entries[0].sets[0].at, NOW + MIN); assert.equal(doc()._ts, NOW + MIN + 5 * SEC)
  assert.deepEqual(doc().active.liveSeen, ['e-1'])
  // Um set.done de uma série já feita, e um evento de outro treino, não mudam nada.
  const before = doc().active
  assert.deepEqual(events([tap('e-2'), tap('e-3', { wid: 'outro', set: 1 })], NOW + 2 * MIN), { applied: [], effects: [] })
  assert.deepEqual(doc().active.entries, before.entries); assert.deepEqual(doc().active.rest, before.rest)

  // Ouvido 20 minutos depois: o at do toque fica na série, e o descanso que já acabou não começa
  // (Foco da revisão 1). Ouvido 30 s depois: o descanso conta do toque.
  const late = events([tap('e-4', { set: 1, at: NOW + 3 * MIN })], NOW + 23 * MIN)
  assert.equal(doc().active.entries[0].sets[1].at, NOW + 3 * MIN)
  assert.ok(!types(late.effects).includes('rest.started')); assert.equal(doc().active.rest, null)
  const soon = events([tap('e-5', { set: 2, at: NOW + 24 * MIN })], NOW + 24 * MIN + 30 * SEC)
  assert.deepEqual(soon.effects.find(e => e.type === 'rest.started'), { type: 'rest.started', endsAt: NOW + 24 * MIN + 90 * SEC, total: 90, kind: 'rest' })
  // O mesmo "+15 s" duas vezes soma 15 s uma vez só: o id já visto não roda de novo.
  const plus = { id: 'e-r1', wid: 'w-1', kind: 'rest.adjust', by: 15, at: NOW + 24 * MIN + 35 * SEC }
  const added = events([plus, plus], NOW + 24 * MIN + 40 * SEC)
  assert.deepEqual(added.applied, ['e-r1'])
  assert.equal(doc().active.rest.endsAt, NOW + 24 * MIN + 105 * SEC)
  assert.deepEqual(added.effects, [{ type: 'rest.started', endsAt: NOW + 24 * MIN + 105 * SEC, total: 90, kind: 'rest' }, { type: 'activity.update' }])
  assert.deepEqual(events([plus], NOW + 24 * MIN + 45 * SEC), { applied: [], effects: [] })
  assert.equal(doc().active.rest.endsAt, NOW + 24 * MIN + 105 * SEC)

  // Adicionar um exercício muda as posições: o evento acha a entrada pelo exId (escolha do tech lead
  // nesta Task), e o de um exercício que saiu do treino é ignorado.
  act({ type: 'focus', entry: 0 }, NOW + 25 * MIN)
  act({ type: 'exercise.remove', entry: 1 }, NOW + 25 * MIN)
  act({ type: 'exercise.add', exerciseIds: [ROW] }, NOW + 25 * MIN)
  assert.deepEqual(doc().active.entries.map(e => e.id), [BENCH, ROW, INCLINE])
  const moved = events([tap('e-6', { entry: 1, set: 0, exId: INCLINE, at: NOW + 26 * MIN }), tap('e-7', { entry: 1, set: 0, exId: CURL, at: NOW + 26 * MIN })], NOW + 26 * MIN)
  assert.deepEqual(moved.applied, ['e-6'])
  assert.deepEqual(doc().active.entries.map(e => e.sets[0].done), [true, false, true])

  // O "Pular" na pausa de trocar de lado não muda nada.
  const side = { sec: 30, w: 0, done: false }
  open({ active: {
    id: 'w-2', d: isoOf(new Date(NOW)), start: NOW, routineIds: [], name: 'Livre', bw: null, cur: 0, workoutView: 'cards',
    entries: [{ id: PLANK, target: { mode: 'time', sec: 30, side: true }, sets: [{ ...side, side: 'L' }, { ...side, side: 'R' }] }],
  } })
  act({ type: 'set.mark', entry: 0, set: 0, done: true })
  const pause = doc().active.rest
  assert.deepEqual(events([{ id: 'e-8', wid: 'w-2', kind: 'rest.skip', at: NOW + 2 * SEC }], NOW + 3 * SEC), { applied: [], effects: [] })
  assert.deepEqual(doc().active.rest, pause)
  assert.deepEqual(doc().active.liveSeen, ['e-8'])
  // O treino guarda os últimos 64 ids vistos, e o mais velho sai.
  const many = Array.from({ length: 70 }, (_, k) => ({ id: `x-${k}`, wid: 'w-2', kind: 'rest.skip', at: NOW + 4 * SEC }))
  events(many, NOW + 5 * SEC)
  assert.deepEqual(doc().active.liveSeen, many.slice(-64).map(e => e.id))
})

test('a workout with a rest, reopened by restore, keeps counting from the endsAt', () => {
  open(PPL)
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  act({ type: 'set.mark', entry: 0, set: 0, done: true }, NOW + MIN)
  const saved = R.document()
  assert.equal(active(NOW + MIN).rest.remaining, 90)
  // O app morto e aberto de novo, 30 s depois e depois do fim (Foco da revisão 1).
  open()
  R.restore(saved)
  assert.equal(active(NOW + MIN + 30 * SEC).rest.remaining, 60)
  assert.deepEqual(active(NOW + MIN + 30 * SEC).entries[0].sets[0].done, true)
  const over = active(NOW + 5 * MIN).rest
  assert.equal(over.remaining, 0); assert.equal(over.endsAt, NOW + MIN + 90 * SEC)
})

test('a whole workout through sessionApply ends in the history, and home says done', () => {
  open(PPL)
  act({ type: 'start', routineIds: ['r-push'], id: 'w-1' })
  markAll(NOW)
  const w = active(NOW + 10 * MIN)
  assert.equal(w.next, null); assert.deepEqual([w.done, w.total], [7, 7])
  const finished = act({ type: 'finish' }, NOW + 10 * MIN)
  assert.deepEqual(types(finished.effects), ['workout.finished', 'activity.end'])
  assert.deepEqual([finished.result.sets.done, finished.result.name, finished.result.durationMs], [7, 'Push', 10 * MIN])
  const saved = doc()
  assert.equal(saved.active, null)
  assert.deepEqual(saved.workouts.map(x => x.id), ['w-1'])
  assert.equal(homeAt(NOW + 11 * MIN).today.status, 'done')
})
