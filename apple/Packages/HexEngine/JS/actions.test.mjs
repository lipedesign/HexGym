// Testes do actions.js, as ações sobre o documento e as leituras das telas, pelo que o Swift chama no
// runtime.js (entra e sai texto JSON), rodando direto no Node, sem o build, com o documento do
// freshState e o pacote pt-BR guardado em Sources/HexEngine/Resources/langs.
//
//   node --test apple/Packages/HexEngine/JS/actions.test.mjs
//
// Os testes dividem o documento aberto, como o JSContext do app: cada um abre o que quer antes. Os
// 18 primeiros são um por ação, na ordem do plano (Task 5 do plano da fase 2); os 10 seguintes são os
// do Foco da revisão e os limites; os 4 últimos, os da leitura starterPlanChanges (issue #120).

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import zlib from 'node:zlib'
import * as R from './runtime.js'
import { t } from '../../../../frontend/src/lib/i18n-core.js'
import { pickedExerciseConfig, setsRepsOf } from '../../../../frontend/src/lib/history.js'
import { replaceSlotExercise } from '../../../../frontend/src/lib/routines.js'
import { starterPlanDays, starterPlanOptions } from '../../../../frontend/src/lib/starter.js'
import { convertWeight } from '../../../../frontend/src/lib/units.js'
import { defaultIncrement } from '../../../../frontend/src/lib/exercises.js'

const pack = lang => zlib.inflateRawSync(fs.readFileSync(new URL(`../Sources/HexEngine/Resources/langs/${lang}.json.deflate`, import.meta.url))).toString('utf8')
R.setLanguage(pack('en'), pack('pt-BR'))

const NOW = Date.UTC(2026, 10, 4, 12)
const slot = (id, extra = {}) => ({ id, sets: 3, reps: 10, weight: 60, mode: 'reps', ...extra })
const PUSH = { id: 'r-push', name: 'Push', emoji: 'barbell', ex: [slot('0025'), slot('0047'), slot('0426')] }
const PULL = { id: 'r-pull', name: 'Pull', emoji: 'pullup', ex: [slot('0027')] }
const CUSTOM = { id: 'custom-hexgym-1', n: 'Remada do HexGym', bp: 'back', custom: true }

// Abre o documento do primeiro uso com as chaves de extra por cima, como o app abre uma cópia salva.
function open(extra = {}) {
  const doc = JSON.parse(R.freshDocument())
  R.restore(JSON.stringify({ ...doc, ...structuredClone(extra) }))
}
const act = (action, now = NOW) => JSON.parse(R.apply(JSON.stringify(action), now))
const doc = () => JSON.parse(R.document())
const routine = id => doc().routines.find(r => r.id === id)
const ids = list => list.map(x => x.id)
// Uma ação inválida lança TypeError, e o documento fica como estava.
function rejects(action) {
  const before = R.document()
  assert.throws(() => R.apply(JSON.stringify(action), NOW), TypeError, JSON.stringify(action))
  assert.equal(R.document(), before)
}

test('routine.create adds a routine at the end, named as openGym names a new one', () => {
  open({ routines: [PUSH] })
  const { changed, result } = act({ type: 'routine.create', name: '  Peito  ' })
  assert.equal(changed, true)
  const r = doc().routines.at(-1)
  assert.deepEqual([r.id, r.name, r.emoji, r.ex], [result.id, 'Peito', 'figureStrength', []])
  act({ type: 'routine.create', name: '   ' })
  assert.equal(doc().routines.at(-1).name, t('New routine')); assert.equal(t('New routine'), 'Nova rotina')
  rejects({ type: 'routine.create', name: 5 })
})

test('routine.rename trims, and an empty name becomes the editor default', () => {
  open({ routines: [PUSH] })
  act({ type: 'routine.rename', id: 'r-push', name: ' Empurrar ' }); assert.equal(routine('r-push').name, 'Empurrar')
  act({ type: 'routine.rename', id: 'r-push', name: '' }); assert.equal(routine('r-push').name, t('Routine'))
  rejects({ type: 'routine.rename', id: 'nao-existe', name: 'X' })
})

test('routine.glyph takes only one of the ROUTINE_GLYPHS', () => {
  open({ routines: [PUSH] })
  act({ type: 'routine.glyph', id: 'r-push', glyph: 'heart' }); assert.equal(routine('r-push').emoji, 'heart')
  rejects({ type: 'routine.glyph', id: 'r-push', glyph: 'trophy' })
  rejects({ type: 'routine.glyph', id: 'r-push', glyph: '💪' })
})

test('routine.duplicate puts the copy right after the original', () => {
  open({ routines: [PUSH, PULL] })
  const { result } = act({ type: 'routine.duplicate', id: 'r-push' })
  const list = doc().routines
  assert.deepEqual(ids(list), ['r-push', result.id, 'r-pull'])
  assert.equal(list[1].name, `Push (${t('Copy')})`); assert.deepEqual(ids(list[1].ex), ids(PUSH.ex))
  rejects({ type: 'routine.duplicate', id: 'nao-existe' })
})

test('routine.move reorders the list and stamps the order', () => {
  open({ routines: [PUSH, PULL] })
  assert.equal(act({ type: 'routine.move', from: 0, to: 1 }).changed, true)
  assert.deepEqual(ids(doc().routines), ['r-pull', 'r-push']); assert.equal(doc().edited.routineOrder, NOW)
  assert.equal(act({ type: 'routine.move', from: 1, to: 1 }).changed, false)
  rejects({ type: 'routine.move', from: 0, to: 2 })
})

test('routine.delete removes the routine and its days, and gives the snapshot with the marks', () => {
  open({ routines: [PUSH, PULL], week: { 1: ['r-push'], 3: ['r-pull'] } })
  const { result } = act({ type: 'routine.delete', id: 'r-push' })
  assert.deepEqual(ids(doc().routines), ['r-pull']); assert.deepEqual(doc().week, { 3: ['r-pull'] })
  assert.equal(doc().deleted.routines['r-push'], NOW)
  assert.equal(result.snapshot.routine.id, 'r-push'); assert.deepEqual(result.snapshot.week, { 1: 0 })
  assert.deepEqual(Object.keys(result.snapshot.marks), ['week.1'])
  rejects({ type: 'routine.delete', id: 'r-push' })
})

test('routine.restore puts the routine back, and a second time changes nothing', () => {
  open({ routines: [PUSH, PULL], week: { 1: ['r-push'] } })
  const { snapshot } = act({ type: 'routine.delete', id: 'r-push' }).result
  assert.equal(act({ type: 'routine.restore', snapshot }, NOW + 1000).changed, true)
  assert.deepEqual(ids(doc().routines), ['r-push', 'r-pull']); assert.deepEqual(doc().week, { 1: ['r-push'] })
  assert.equal(act({ type: 'routine.restore', snapshot }, NOW + 2000).changed, false)
  rejects({ type: 'routine.restore', snapshot: { routine: { id: 'x' } } })
})

test('slot.add adds each exercise with the picker config, at the end or at a place', () => {
  open({ routines: [PULL] })
  act({ type: 'slot.add', routineId: 'r-pull', exerciseIds: ['0025', '2330'] })
  assert.deepEqual(routine('r-pull').ex.slice(1), [{ id: '0025', ...pickedExerciseConfig('0025') }, { id: '2330', ...pickedExerciseConfig('2330') }])
  act({ type: 'slot.add', routineId: 'r-pull', exerciseIds: ['0047'], at: 0 })
  assert.deepEqual(ids(routine('r-pull').ex), ['0047', '0027', '0025', '2330'])
  rejects({ type: 'slot.add', routineId: 'r-pull', exerciseIds: ['nao-existe'] })
  rejects({ type: 'slot.add', routineId: 'r-pull', exerciseIds: ['0025'], at: 9 })
  rejects({ type: 'slot.add', routineId: 'r-pull', exerciseIds: [] })
})

test('slot.remove takes the exercise out, and its superset partner left alone loses the link', () => {
  open({ routines: [{ ...PUSH, ex: [slot('0025', { sg: 'g1' }), slot('0047', { sg: 'g1' }), slot('0426')] }] })
  act({ type: 'slot.remove', routineId: 'r-push', index: 1 })
  const ex = routine('r-push').ex
  assert.deepEqual(ids(ex), ['0025', '0426']); assert.equal(ex[0].sg, undefined)
  rejects({ type: 'slot.remove', routineId: 'r-push', index: 5 })
})

test('slot.move moves one exercise and cleans a superset it broke', () => {
  open({ routines: [{ ...PUSH, ex: [slot('0025', { sg: 'g1' }), slot('0047', { sg: 'g1' }), slot('0426')] }] })
  act({ type: 'slot.move', routineId: 'r-push', from: 0, to: 2 })
  const ex = routine('r-push').ex
  assert.deepEqual(ids(ex), ['0047', '0426', '0025']); assert.ok(ex.every(e => e.sg === undefined))
  rejects({ type: 'slot.move', routineId: 'r-push', from: 0, to: 3 })
})

test('slot.replace keeps the slot and swaps the exercise, as replaceSlotExercise does', () => {
  open({ routines: [PUSH] })
  act({ type: 'slot.replace', routineId: 'r-push', index: 0, exerciseId: '0047' })
  assert.deepEqual(routine('r-push').ex[0], replaceSlotExercise(PUSH.ex[0], '0047', null, 'r-push'))
  assert.deepEqual([routine('r-push').ex[0].id, routine('r-push').ex[0].weight], ['0047', 60])
  rejects({ type: 'slot.replace', routineId: 'r-push', index: 0, exerciseId: 'nao-existe' })
})

test('slot.superset joins an exercise with the next one', () => {
  open({ routines: [PUSH] })
  act({ type: 'slot.superset', routineId: 'r-push', index: 0 })
  const ex = routine('r-push').ex
  assert.ok(ex[0].sg); assert.equal(ex[0].sg, ex[1].sg); assert.equal(ex[2].sg, undefined)
  rejects({ type: 'slot.superset', routineId: 'r-push', index: 2 })
})

test('slot.unsuperset takes an exercise out of its superset', () => {
  open({ routines: [{ ...PUSH, ex: [slot('0025', { sg: 'g1' }), slot('0047', { sg: 'g1' }), slot('0426')] }] })
  act({ type: 'slot.unsuperset', routineId: 'r-push', index: 1 })
  assert.ok(routine('r-push').ex.every(e => e.sg === undefined))
  assert.equal(act({ type: 'slot.unsuperset', routineId: 'r-push', index: 2 }).changed, false)
})

test('slot.update changes only the fields it knows, and the note as the sheet saves it', () => {
  open({ routines: [PUSH] })
  act({ type: 'slot.update', routineId: 'r-push', index: 0, fields: { sets: 5, reps: 12, repsMin: 8, weight: 62.5, note: '  banco 4 ' } })
  const s = routine('r-push').ex[0]
  assert.deepEqual([s.sets, s.reps, s.repsMin, s.weight, s.note], [5, 12, 8, 62.5, 'banco 4'])
  act({ type: 'slot.update', routineId: 'r-push', index: 0, fields: { note: '', mode: 'time' } })
  assert.deepEqual([routine('r-push').ex[0].note, routine('r-push').ex[0].mode, routine('r-push').ex[0].sec], [undefined, 'time', 45])
  rejects({ type: 'slot.update', routineId: 'r-push', index: 0, fields: { inc: 5 } })
  rejects({ type: 'slot.update', routineId: 'r-push', index: 1, fields: { repsMin: 11 } })
  rejects({ type: 'slot.update', routineId: 'r-push', index: 1, fields: { mode: 'cardio' } })
})

test('week.set sets a day, an empty list clears it, and week() runs in the profile order', () => {
  open({ routines: [PUSH, PULL] })
  act({ type: 'week.set', day: 2, routineIds: ['r-push', 'r-pull'] }); assert.deepEqual(doc().week, { 2: ['r-push', 'r-pull'] })
  assert.equal(doc().edited['week.2'], NOW)
  const w = JSON.parse(R.week())
  assert.deepEqual([w.weekStart, w.days.map(d => d.day)], [1, [1, 2, 3, 4, 5, 6, 0]])
  assert.deepEqual(w.days[1], { day: 2, routineIds: ['r-push', 'r-pull'] })
  act({ type: 'week.set', day: 2, routineIds: [] }); assert.deepEqual(doc().week, {})
  rejects({ type: 'week.set', day: 7, routineIds: [] })
  rejects({ type: 'week.set', day: 1, routineIds: ['nao-existe'] })
  rejects({ type: 'week.set', day: 1, routineIds: ['r-push', 'r-push'] })
})

test('plan.starter loads a plan on its days, with the names in English', () => {
  open({ week: { 0: ['x'] } })
  const { result } = act({ type: 'plan.starter', planId: 'ppl' })
  const d = doc()
  assert.equal(result.routines, 3); assert.deepEqual(d.routines.map(r => r.name), ['Push Day', 'Pull Day', 'Leg Day'])
  assert.deepEqual(Object.keys(d.week).sort(), ['0', '1', '3', '5']); assert.deepEqual(d.week[1], [d.routines[0].id])
  assert.deepEqual(JSON.parse(R.starterPlans()), starterPlanOptions().map(o => ({ ...o, weekdays: starterPlanDays(o.id) })))
  assert.deepEqual(JSON.parse(R.starterPlans()).map(o => o.weekdays), [[1, 3, 5], [1, 2, 4, 5], [1, 3, 5], [1, 3, 5]])
  rejects({ type: 'plan.starter', planId: 'nao-existe' })
})

test('settings.set changes the five settings within their values, and settings() reads them', () => {
  open()
  for (const [key, value] of [['body', 'female'], ['weekStart', 0], ['restSec', 120], ['effort', 'rpe']]) act({ type: 'settings.set', key, value })
  assert.deepEqual(JSON.parse(R.settings()), { unit: 'kg', body: 'female', weekStart: 0, restSec: 120, effort: 'rpe' })
  assert.equal(JSON.parse(R.week()).days[0].day, 0)
  assert.equal(act({ type: 'settings.set', key: 'unit', value: 'kg' }).changed, false)
  rejects({ type: 'settings.set', key: 'restSec', value: 901 })
  rejects({ type: 'settings.set', key: 'weekStart', value: 2 })
  rejects({ type: 'settings.set', key: 'unit', value: 'st' })
  rejects({ type: 'settings.set', key: 'sound', value: false })
})

test('favourite.toggle adds and takes off a favourite', () => {
  open()
  act({ type: 'favourite.toggle', id: '0025' }); assert.deepEqual(doc().favEx, ['0025'])
  act({ type: 'favourite.toggle', id: '0025' }); assert.deepEqual(doc().favEx, [])
  rejects({ type: 'favourite.toggle', id: 'nao-existe' })
})

test('apply stamps the routine it changed with now, or after the highest stamp, and leaves the others', () => {
  open({ routines: [{ ...PUSH, _ts: 1000 }, { ...PULL, _ts: 2000 }] })
  act({ type: 'routine.rename', id: 'r-push', name: 'A' })
  assert.deepEqual([routine('r-push')._ts, routine('r-pull')._ts, doc()._ts], [NOW, 2000, NOW])
  open({ routines: [{ ...PUSH, _ts: 1000 }, { ...PULL, _ts: NOW + 5000 }] })
  act({ type: 'routine.rename', id: 'r-push', name: 'B' })
  assert.deepEqual([routine('r-push')._ts, routine('r-pull')._ts], [NOW + 5001, NOW + 5000])
  // Uma ação que não mudou nada não carimba.
  const before = R.document()
  assert.equal(act({ type: 'routine.rename', id: 'r-push', name: 'B' }).changed, false); assert.equal(R.document(), before)
})

test('a document with a key HexGym does not know and a custom exercise keeps both', () => {  // Foco da revisão 1
  open({ 'x-futuro': 1, customEx: [CUSTOM] })
  act({ type: 'routine.create', name: 'Nova' })
  act({ type: 'slot.add', routineId: doc().routines[0].id, exerciseIds: [CUSTOM.id] })
  const d = doc()
  assert.equal(d['x-futuro'], 1); assert.deepEqual(d.customEx.map(e => [e.id, e.n]), [[CUSTOM.id, CUSTOM.n]])
  assert.equal(Object.hasOwn(d, 'lang'), false)
})

test('a routine with an exercise that no longer exists reads as Unknown exercise', () => {  // Foco da revisão 1
  open({ routines: [{ id: 'r1', name: 'Velha', emoji: '💪', ex: [{ id: 'nao-existe', sets: 3, reps: 10, weight: 0 }, slot('0025')] }] })
  const [r] = JSON.parse(R.routines())
  assert.equal(r.glyph, '💪')
  assert.deepEqual([r.slots[0].known, r.slots[0].name], [false, t('Unknown exercise')])
  assert.equal(r.slots[1].known, true); assert.equal(r.slots[1].setsReps, setsRepsOf(slot('0025')))
  assert.ok(r.muscles.chest > 0)
})

test('a slot of one side at a time steps its reps by two, as the openGym sheet does', () => {
  open({ routines: [{ id: 'r1', name: 'Lados', emoji: 'dumbbell', ex: [slot('0025'), { id: '1048', ...pickedExerciseConfig('1048') }] }] })
  const [r] = JSON.parse(R.routines())
  assert.deepEqual(r.slots.map(s => [s.id, s.repStep, s.reps]), [['0025', 1, slot('0025').reps], ['1048', 2, 20]])
})

test('kg to lb converts the routine weights as convertStateUnit does, and back gives the value before', () => {  // Foco da revisão 3
  open({ routines: [PUSH] })
  act({ type: 'settings.set', key: 'unit', value: 'lb' })
  const [inLb] = JSON.parse(R.routines())
  assert.equal(inLb.slots[0].weight, convertWeight(60, 'kg', 'lb')); assert.equal(inLb.slots[0].increment, defaultIncrement('0025', 'lb'))
  assert.equal(doc().unitSet.convert, true); assert.equal(JSON.parse(R.settings()).unit, 'lb')
  act({ type: 'settings.set', key: 'unit', value: 'kg' }, NOW + 1000)
  assert.equal(JSON.parse(R.routines())[0].slots[0].weight, 60)
})

test('deleting a routine on Monday and Thursday takes it off both, and restoring brings both back', () => {  // Foco da revisão 4
  open({ routines: [PUSH, PULL], week: { 1: ['r-push'], 4: ['r-push', 'r-pull'] } })
  const { snapshot } = act({ type: 'routine.delete', id: 'r-push' }).result
  assert.deepEqual(doc().week, { 4: ['r-pull'] })
  act({ type: 'routine.restore', snapshot }, NOW + 1000)
  assert.deepEqual(doc().week, { 1: ['r-push'], 4: ['r-push', 'r-pull'] })
  assert.deepEqual(JSON.parse(R.routines()).find(r => r.id === 'r-push').days, [1, 4])
})

test('settings.set never writes theme, accent or lang', () => {
  open()
  rejects({ type: 'settings.set', key: 'theme', value: 'light' })
  rejects({ type: 'settings.set', key: 'accent', value: 'sky' })
  rejects({ type: 'settings.set', key: 'lang', value: 'pt-BR' })
  rejects({ type: 'nao.existe' })
})

test('restoring a routine that was on Monday and Thursday marks both days as undone', () => {
  open({ routines: [PUSH, PULL], week: { 1: ['r-push'], 4: ['r-push', 'r-pull'] } })
  const { snapshot } = act({ type: 'routine.delete', id: 'r-push' }).result
  assert.deepEqual(Object.keys(snapshot.marks).sort(), ['week.1', 'week.4'])
  act({ type: 'routine.restore', snapshot }, NOW + 1000)
  const undone = doc().undone
  assert.deepEqual(Object.keys(undone).sort(), ['week.1', 'week.4'])
  assert.deepEqual(undone['week.1'], [0, NOW, NOW + 1000])
})

test('slot.update refuses 0 sets and values above the limits, and a document above them still opens', () => {
  open({ routines: [{ ...PUSH, ex: [slot('0025', { sets: 30 })] }] })
  assert.equal(JSON.parse(R.routines())[0].slots[0].sets, 30)
  for (const fields of [{ sets: 0 }, { sets: 21 }, { sets: 2.5 }, { reps: 101 }, { sec: 3601 }, { weight: 1000.5 }, { weight: -1 }, { note: 'x'.repeat(501) }]) {
    rejects({ type: 'slot.update', routineId: 'r-push', index: 0, fields })
  }
  act({ type: 'slot.update', routineId: 'r-push', index: 0, fields: { sets: 20, reps: 100, weight: 1000 } })
  assert.equal(routine('r-push').ex[0].sets, 20)
})

test('loading the ppl plan twice does not duplicate its routines', () => {
  open()
  act({ type: 'plan.starter', planId: 'ppl' })
  const first = doc()
  const { result } = act({ type: 'plan.starter', planId: 'ppl' }, NOW + 1000)
  assert.equal(result.routines, 0)
  assert.deepEqual(ids(doc().routines), ids(first.routines)); assert.deepEqual(doc().week, first.week)
})

// Os exercícios do Push Day do PPL (lib/starter.js), na ordem, para uma rotina igual à do plano.
const PPL_PUSH = ['0025', '0047', '0426', '0334', '0241', '0251']
const changes = planId => JSON.parse(R.starterPlanChanges(planId))
// O que o plan.starter faz de verdade: os dias que tinham rotina e mudaram, pela leitura week(). O
// documento volta como estava depois.
function changedByAction(planId) {
  const before = R.document(), days = JSON.parse(R.week()).days
  act({ type: 'plan.starter', planId })
  const after = JSON.parse(R.week()).days
  R.restore(before)
  return days.filter((d, i) => d.routineIds.length && JSON.stringify(d.routineIds) !== JSON.stringify(after[i].routineIds)).map(d => d.day)
}

test('starterPlanChanges gives the days a plan really changes, and leaves the document as it was', () => {  // issue #120
  // A segunda com uma rotina que o plano troca, a terça com duas, a quarta com um id velho (que não
  // conta) e a sexta com o Push Day igual ao do plano, que ele reaproveita mas tira da sexta.
  const pushDay = { id: 'r-pd', name: 'Push Day', emoji: 'barbell', ex: PPL_PUSH.map(id => slot(id)) }
  open({ routines: [PUSH, PULL, pushDay], week: { 1: ['r-push'], 2: ['r-push', 'r-pull'], 3: ['nao-existe'], 5: ['r-pd'] } })
  const before = R.document()
  assert.deepEqual(changes('ppl'), [1, 5])
  assert.deepEqual(changes('upper-lower'), [1, 2, 5])
  assert.equal(R.document(), before, 'a leitura não muda o documento aberto')
  for (const plan of ['ppl', 'upper-lower', 'full-body', '5x5']) assert.deepEqual(changes(plan), changedByAction(plan), plan)
  assert.equal(R.document(), before)
  // O Push Day já na segunda: o ppl o reaproveita ali, e a segunda não é trocada.
  open({ routines: [pushDay], week: { 1: ['r-pd'] } })
  assert.deepEqual(changes('ppl'), [])
  assert.deepEqual(changes('5x5'), [1])
})

test('starterPlanChanges counts a null item in a routine as the engine does, and the day is changed', () => {  // nota 3 do QA do PR #119
  // O Push Day de um documento quebrado: os exercícios do plano e um nulo no fim. O routines() deixa o
  // nulo de fora, mas o sameLift do plan.starter o conta, e o plano cria outra rotina para a segunda.
  const broken = { id: 'r-pd', name: 'Push Day', emoji: 'barbell', ex: [...PPL_PUSH.map(id => slot(id)), null] }
  open({ routines: [broken], week: { 1: ['r-pd'] } })
  assert.deepEqual(JSON.parse(R.routines())[0].slots.map(s => s.id), PPL_PUSH)
  assert.deepEqual(changes('ppl'), [1])
  assert.deepEqual(changedByAction('ppl'), [1])
  // O nulo no meio também.
  open({ routines: [{ ...broken, ex: [slot('0025'), null, ...PPL_PUSH.slice(1).map(id => slot(id))] }], week: { 1: ['r-pd'] } })
  assert.deepEqual(changes('ppl'), [1])
})

test('starterPlanChanges is empty for a plan that changes no day, and null for a plan that does not exist', () => {  // issue #120
  // Sem rotina na semana, nenhum plano troca dia: ele só preenche.
  open({ week: { 0: ['nao-existe'] } })
  for (const plan of ['ppl', 'upper-lower', 'full-body', '5x5']) assert.deepEqual(changes(plan), [], plan)
  // Com o ppl carregado, o ppl de novo volta às mesmas rotinas e não troca nada.
  act({ type: 'plan.starter', planId: 'ppl' })
  assert.deepEqual(changes('ppl'), [])
  assert.deepEqual(changes('full-body'), [1, 3, 5])
  const before = R.document()
  for (const id of ['nao-existe', '', 'constructor', '__proto__', 5, null, undefined]) assert.equal(changes(id), null, String(id))
  assert.equal(R.document(), before)
})

test('starterPlanChanges follows the week of the profile, from Sunday or from Monday', () => {  // issue #120
  // Nenhum plano usa o domingo, então o começo da semana não muda a resposta, só a ordem em que ela
  // seria lida; a lista sai na ordem do week().
  for (const weekStart of [0, 1]) {
    open({ weekStart, routines: [PUSH, PULL], week: { 0: ['r-push'], 1: ['r-pull'], 2: ['r-push'], 4: ['r-pull'], 5: ['r-push'] } })
    assert.deepEqual(JSON.parse(R.week()).days[0].day, weekStart)
    assert.deepEqual(changes('upper-lower'), [1, 2, 4, 5], `semana começando em ${weekStart}`)
    assert.deepEqual(changes('ppl'), [1, 5])
    assert.deepEqual(changes('ppl'), changedByAction('ppl'))
  }
})
