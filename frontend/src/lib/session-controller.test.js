// O controlador do treino (session-controller.js), Tasks 1 e 2 do plano da fase 3 do HexGym: começar,
// as séries, o descanso e os exercícios no meio do treino. Os documentos saem do freshState, com as
// rotinas montadas aqui, e cada resultado esperado vem das mesmas funções do lib que o openGym
// chama, para o teste seguir o openGym quando ele mudar. Só importa módulos do motor, então roda
// também contra o script dele.
import { describe, it, expect, vi, afterEach } from 'vitest'
import { step } from './session-controller.js'
import { clone, freshState } from './state-core.js'
import { buildCombinedEntries } from './session-merge.js'
import { restSecFor } from './supersetFlow.js'
import { bestWeightForEntry as bestWeight, freestyleConfig, pickedExerciseConfig } from './history.js'
import { buildSessionEntry } from './session-start.js'
import { sessionHistory } from './backfill.js'
import { swapActiveExercise } from './active-exercise-swap.js'
import { stepWeight, weightIncrement } from './progression.js'
import { ownedWeightsFor, stepOwned } from './dumbbells.js'
import { hasCompletedWork, makeSideSet, toggleSide } from './workout-model.js'
import { REST_MAX } from './duration.js'
import { isoOf } from './format.js'
import { t } from './i18n-core.js'

const SQUAT = '0043'   // agachamento com barra
const BENCH = '0025'   // supino com barra
const CURL = '0294'    // rosca com halteres
const PLANK = '0464'   // prancha, isométrico
const RUN = '0685'     // corrida, cardio

const SEC = 1000
const NOW = new Date(2026, 10, 8, 10, 0, 0).getTime()

function doc(extra = {}) {
  return {
    ...freshState('en'),
    bodyweight: [{ d: '2026-11-01', w: 81 }, { d: '2026-11-07', w: 80.4 }],
    routines: [
      { id: 'ra', name: 'A', ex: [{ id: SQUAT, sets: 3, reps: 5, weight: 60, mode: 'reps', inc: 2.5 }] },
      { id: 'rb', name: 'B', ex: [{ id: BENCH, sets: 2, reps: 8, weight: 50, mode: 'reps' }] },
      { id: 'rs', name: 'Superset', ex: [
        { id: CURL, sets: 2, reps: 10, weight: 12, mode: 'reps', sg: 'g1', restSec: 60 },
        { id: BENCH, sets: 2, reps: 10, weight: 40, mode: 'reps', sg: 'g1', restSec: 120 },
      ] },
      { id: 'rt', name: 'Two', ex: [
        { id: SQUAT, sets: 2, reps: 5, weight: 60, mode: 'reps' },
        { id: BENCH, sets: 1, reps: 8, weight: 50, mode: 'reps' },
      ] },
    ],
    ...extra,
  }
}

const begin = (S, routineIds = ['ra']) => step(S, { type: 'start', routineIds, id: 'w1' }, NOW).state
const mark = (S, entry, set, done = true, now = NOW) => step(S, { type: 'set.mark', entry, set, done }, now)
const types = out => out.effects.map(e => e.type)
// Um treino montado à mão, nas formas que o openGym grava.
const withEntries = (S, entries, extra = {}) => ({
  ...S,
  active: { id: 'w1', d: '2026-11-08', start: NOW, routineIds: [], name: 'Freestyle', bw: null, cur: 0, entries, workoutView: 'cards', rest: null, progress: entries.map(() => 0), ...extra },
})
const withRest = (S, rest) => ({ ...S, active: { ...S.active, rest } })
const rows = (S, entry = 0) => S.active.entries[entry].sets

function deepFreeze(o) {
  if (o && typeof o === 'object' && !Object.isFrozen(o)) {
    Object.freeze(o)
    for (const v of Object.values(o)) deepFreeze(v)
  }
  return o
}

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('o controlador do treino: começar', () => {
  it('start de uma rotina monta o active como o beginWorkout, e o efeito é activity.start', () => {
    const S = doc()
    const out = step(S, { type: 'start', routineIds: ['ra'], id: 'w1' }, NOW)
    const built = buildCombinedEntries(S, ['ra'])
    const A = out.state.active
    expect(Object.keys(A)).toEqual(['id', 'd', 'start', 'routineIds', 'name', 'bw', 'cur', 'entries', 'workoutView', 'rest', 'progress'])
    expect(A).toEqual({
      id: 'w1', d: isoOf(new Date(NOW)), start: NOW, routineIds: built.routineIds, name: 'A', bw: 80.4,
      cur: 0, entries: built.entries, workoutView: 'cards', rest: null, progress: [0],
    })
    expect(A.d).toBe('2026-11-08')
    expect(out.result).toEqual({ id: 'w1' })
    expect(out.effects).toEqual([{ type: 'activity.start' }])
    // Um perfil em lista começa em lista, e sem pesagem o bw é null.
    const list = step(doc({ workoutView: 'list', bodyweight: [] }), { type: 'start', routineIds: ['ra'], id: 'w2' }, NOW).state.active
    expect(list.workoutView).toBe('list')
    expect(list.bw).toBe(null)
  })

  it('start com duas rotinas dá o nome "A + B", e com [] dá o Freestyle sem entradas', () => {
    const S = doc()
    const two = step(S, { type: 'start', routineIds: ['ra', 'rb'], id: 'w1' }, NOW).state.active
    expect(two.name).toBe('A + B')
    expect(two.routineIds).toEqual(['ra', 'rb'])
    expect(two.entries).toEqual(buildCombinedEntries(S, ['ra', 'rb']).entries)
    expect(two.progress).toEqual([0, 0])
    const free = step(S, { type: 'start', routineIds: [], id: 'w1' }, NOW).state.active
    expect(free.name).toBe(t('Freestyle'))
    expect(free.entries).toEqual([])
    expect(free.routineIds).toEqual([])
    expect(free.progress).toEqual([])
  })

  it('start com um treino em andamento, ou sem id, lança TypeError', () => {
    const S = begin(doc())
    expect(() => step(S, { type: 'start', routineIds: ['rb'], id: 'w2' }, NOW)).toThrow(TypeError)
    const fresh = doc()
    expect(() => step(fresh, { type: 'start', routineIds: ['ra'] }, NOW)).toThrow(TypeError)
    expect(() => step(fresh, { type: 'start', routineIds: ['ra'], id: '' }, NOW)).toThrow(TypeError)
    expect(fresh.active).toBe(null)
  })
})

describe('o controlador do treino: as séries', () => {
  it('set.mark com done true grava done e at, tira o planSec e dá o háptico, o descanso e o update', () => {
    const S = begin(doc())
    S.active.entries[0].sets[0].planSec = 45
    const at = NOW + 60 * SEC
    const out = mark(S, 0, 0, true, at)
    expect(rows(out.state)[0]).toEqual({ w: 60, r: 5, done: true, at })
    const rest = { endsAt: at + 1000 * S.restSec, total: S.restSec, forIdx: 0, forSet: 0, kind: 'rest' }
    expect(out.state.active.rest).toEqual(rest)
    expect(out.effects).toEqual([
      { type: 'haptic', kind: 'setLogged' },
      { type: 'rest.started', endsAt: rest.endsAt, total: rest.total, kind: 'rest' },
      { type: 'activity.update' },
    ])
    expect(out.state.active.progress).toEqual([1])
  })

  it('set.mark com done false tira o done, deixa o at e o descanso que estava contando', () => {
    const marked = mark(begin(doc()), 0, 0, true, NOW).state
    const out = mark(marked, 0, 0, false, NOW + 10 * SEC)
    expect(rows(out.state)[0]).toEqual({ w: 60, r: 5, done: false, at: NOW })
    expect(out.state.active.rest).toEqual(marked.active.rest)
    expect(out.effects).toEqual([{ type: 'activity.update' }])
  })

  it('set.mark com o estado que a série já tem devolve o mesmo S e nenhum efeito', () => {
    const marked = mark(begin(doc()), 0, 0).state
    const again = mark(marked, 0, 0, true, NOW + 2 * SEC)
    expect(again.state).toBe(marked)
    expect(again.effects).toEqual([])
    const undone = mark(marked, 0, 1, false)
    expect(undone.state).toBe(marked)
    expect(undone.effects).toEqual([])
  })

  it('a última série de um exercício grava o topW, começa o descanso e, em cards, deixa o cur', () => {
    let S = begin(doc({ collapseCompleted: true }), ['rt'])
    S = mark(S, 0, 0).state
    const out = mark(S, 0, 1, true, NOW + 90 * SEC)
    const entry = out.state.active.entries[0]
    expect(entry.topW).toBe(bestWeight(entry))
    expect(entry.topW).toBe(60)
    expect(types(out)).toEqual(['haptic', 'rest.started', 'activity.update'])
    expect(out.state.active.rest.forSet).toBe(1)
    expect(out.state.active.cur).toBe(0)
  })

  it('num superset, a série do primeiro leva ao segundo sem descanso, e a do segundo descansa o maior do grupo', () => {
    const S = begin(doc(), ['rs'])
    const first = mark(S, 0, 0)
    expect(types(first)).toEqual(['haptic', 'activity.update'])
    expect(first.state.active.rest).toBe(null)
    expect(first.state.active.cur).toBe(1)
    const second = mark(first.state, 1, 0, true, NOW + 30 * SEC)
    const total = restSecFor(second.state.active.entries, [0, 1], S.restSec)
    expect(total).toBe(120)
    expect(second.state.active.rest).toEqual({ endsAt: NOW + 30 * SEC + total * SEC, total, forIdx: 1, forSet: 0, kind: 'rest' })
    expect(types(second)).toEqual(['haptic', 'rest.started', 'activity.update'])
    // A volta acabou: o cur volta ao primeiro do grupo, como o supersetFlowStep manda.
    expect(second.state.active.cur).toBe(0)
  })

  it('o descanso de cada série vale como no toggle: perfil sem descanso, série, pirâmide, aquecimento e lados', () => {
    // Sem descanso no perfil.
    const off = mark(begin(doc({ restSec: 0 })), 0, 0)
    expect(off.state.active.rest).toBe(null)
    expect(types(off)).toEqual(['haptic', 'activity.update'])
    // O descanso próprio da série (o menu da série do openGym).
    const own = withEntries(doc(), [{ id: SQUAT, target: { mode: 'reps' }, sets: [{ w: 60, r: 5, done: false, restSec: 45 }, { w: 60, r: 5, done: false }] }])
    expect(mark(own, 0, 0).state.active.rest.total).toBe(45)
    // A pirâmide: o descanso da segunda série é o segundo da lista.
    const pyr = withEntries(doc(), [{ id: SQUAT, target: { mode: 'reps', pyramid: [8, 6, 4], pyramidRest: [60, 75, 120] }, sets: [{ w: 50, r: 8, done: true, at: NOW }, { w: 60, r: 6, done: false }, { w: 70, r: 4, done: false }] }], { progress: [1] })
    expect(mark(pyr, 0, 1).state.active.rest.total).toBe(75)
    // O aquecimento: entre as séries de aquecimento, o do perfil; da última para a de trabalho, o normal.
    const warm = withEntries(doc({ warmupRestSec: 30 }), [{ id: SQUAT, target: { mode: 'reps' }, sets: [
      { w: 30, r: 5, done: false, phase: 'warmup' }, { w: 45, r: 5, done: false, phase: 'warmup' }, { w: 60, r: 5, done: false }, { w: 60, r: 5, done: false },
    ] }])
    const w1 = mark(warm, 0, 0)
    expect(w1.state.active.rest.total).toBe(30)
    expect(mark(w1.state, 0, 1, true, NOW + 30 * SEC).state.active.rest.total).toBe(90)
    // Entre a linha L e a R de uma série com tempo por lado: a pausa de trocar de lado, de 10 s.
    const sides = [{ sec: 30, w: 0, done: false, side: 'L' }, { sec: 30, w: 0, done: false, side: 'R' }, { sec: 30, w: 0, done: false, side: 'L' }, { sec: 30, w: 0, done: false, side: 'R' }]
    const plank = withEntries(doc(), [
      { id: PLANK, target: { mode: 'time', sec: 30, side: true }, sets: sides },
      { id: SQUAT, target: { mode: 'reps' }, sets: [{ w: 60, r: 5, done: false }] },
    ])
    const left = mark(plank, 0, 0)
    expect(left.state.active.rest).toEqual({ endsAt: NOW + 10 * SEC, total: 10, forIdx: 0, forSet: 0, kind: 'switch' })
    expect(left.effects[1]).toEqual({ type: 'rest.started', endsAt: NOW + 10 * SEC, total: 10, kind: 'switch' })
    // Acabada a pausa, ela sai do treino como o tique do openGym a tira: mudar a carga ou o
    // exercício da frente não agenda descanso nenhum.
    for (const a of [{ type: 'set.update', entry: 1, set: 0, fields: { w: 65 } }, { type: 'focus', entry: 1 }]) {
      const later = step(left.state, a, NOW + 30 * SEC)
      expect(types(later)).toEqual(['activity.update'])
      expect(later.state.active.rest).toBe(null)
    }
    const right = mark(left.state, 0, 1, true, NOW + 45 * SEC)
    expect(right.state.active.rest).toEqual({ endsAt: NOW + 135 * SEC, total: 90, forIdx: 0, forSet: 1, kind: 'rest' })
    // Com o sideRestOff, o descanso que estava contando acaba e nenhum começa entre os lados.
    const offSides = withEntries(doc(), [
      { id: SQUAT, target: { mode: 'reps' }, sets: [{ w: 60, r: 5, done: false }, { w: 60, r: 5, done: false }] },
      { id: PLANK, target: { mode: 'time', sec: 30, side: true, sideRestOff: true }, sets: sides },
    ])
    const counting = mark(offSides, 0, 0).state
    expect(counting.active.rest).not.toBe(null)
    const noPause = mark(counting, 1, 0, true, NOW + 20 * SEC)
    expect(noPause.state.active.rest).toBe(null)
    expect(types(noPause)).toEqual(['haptic', 'rest.cleared', 'activity.update'])
  })

  it('a última série do treino dá workout.complete e nenhum descanso', () => {
    let S = begin(doc())
    S = mark(S, 0, 0).state
    S = mark(S, 0, 1, true, NOW + 100 * SEC).state
    expect(S.active.rest).not.toBe(null)
    const out = mark(S, 0, 2, true, NOW + 150 * SEC)
    expect(types(out)).toEqual(['haptic', 'workout.complete', 'rest.cleared', 'activity.update'])
    expect(out.state.active.rest).toBe(null)
  })

  it('desmarcar e marcar de novo não começa outro descanso com um contando; acabado, começa, e o progress não anda', () => {
    const first = mark(begin(doc()), 0, 0, true, NOW).state
    const rest = first.active.rest
    const off = mark(first, 0, 0, false, NOW + 5 * SEC).state
    const again = mark(off, 0, 0, true, NOW + 10 * SEC)
    expect(again.state.active.rest).toEqual(rest)
    expect(types(again)).toEqual(['haptic', 'activity.update'])
    expect(again.state.active.progress).toEqual([1])
    const later = NOW + 200 * SEC
    const off2 = mark(again.state, 0, 0, false, later).state
    const back = mark(off2, 0, 0, true, later)
    expect(back.state.active.rest).toEqual({ endsAt: later + 90 * SEC, total: 90, forIdx: 0, forSet: 0, kind: 'rest' })
    expect(types(back)).toEqual(['haptic', 'rest.started', 'activity.update'])
    expect(back.state.active.progress).toEqual([1])
  })

  it('set.update de w grava weightOrigin manual e leva a carga às séries seguintes não feitas; null apaga; 1001 lança', () => {
    const S = mark(begin(doc()), 0, 1).state
    const out = step(S, { type: 'set.update', entry: 0, set: 0, fields: { w: 65 } }, NOW)
    expect(rows(out.state)[0]).toEqual({ w: 65, r: 5, done: false, weightOrigin: 'manual' })
    expect(rows(out.state)[1].w).toBe(60)
    expect(rows(out.state)[2]).toEqual({ w: 65, r: 5, done: false })
    expect(types(out)).toEqual(['activity.update'])
    const cleared = step(out.state, { type: 'set.update', entry: 0, set: 0, fields: { w: null } }, NOW).state
    expect('w' in rows(cleared)[0]).toBe(false)
    expect('w' in rows(cleared)[2]).toBe(false)
    expect(() => step(S, { type: 'set.update', entry: 0, set: 0, fields: { w: 1001 } }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'set.update', entry: 0, set: 0, fields: { r: 101 } }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'set.update', entry: 0, set: 0, fields: { r: 2.5 } }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'set.update', entry: 0, set: 0, fields: { note: 'x' } }, NOW)).toThrow(TypeError)
    expect(rows(S)[0].w).toBe(60)
  })

  it('set.step anda a carga pelo incremento e pelos pesos próprios, as repetições pelo repStep e o esforço pelo stepEffort', () => {
    const S = begin(doc())
    const cfg = { ...S.active.entries[0].target, id: SQUAT }
    const up = step(S, { type: 'set.step', entry: 0, set: 0, field: 'w', direction: 'up' }, NOW).state
    expect(rows(up)[0].w).toBe(stepWeight(60, weightIncrement(cfg, 'kg'), 1))
    expect(rows(up)[0].w).toBe(62.5)
    expect(rows(up)[0].weightOrigin).toBe('manual')
    const down = step(S, { type: 'set.step', entry: 0, set: 0, field: 'w', direction: 'down' }, NOW).state
    expect(rows(down)[0].w).toBe(57.5)
    // Com os halteres do perfil, o passo vai de um peso que existe para o seguinte.
    const bells = withEntries(doc({ dumbbells: { kg: { weights: [10, 12, 14, 17], _ts: 1 } } }), [{ id: CURL, target: { mode: 'reps' }, sets: [{ w: 12, r: 10, done: false }] }])
    const curl = { mode: 'reps', id: CURL }
    const owned = ownedWeightsFor(bells, curl)
    expect(owned).not.toBe(null)
    const bell = step(bells, { type: 'set.step', entry: 0, set: 0, field: 'w', direction: 'up' }, NOW).state
    expect(rows(bell)[0].w).toBe(stepOwned(owned, 12, 1))
    expect(rows(bell)[0].w).not.toBe(stepWeight(12, weightIncrement(curl, 'kg'), 1))
    // As repetições: de 1 em 1, e de 2 em 2 no exercício por lado, um a mais em cada lado.
    expect(rows(step(S, { type: 'set.step', entry: 0, set: 0, field: 'r', direction: 'up' }, NOW).state)[0].r).toBe(6)
    const perSide = withEntries(doc(), [{ id: CURL, target: { mode: 'reps', side: true }, sets: [makeSideSet({ w: 10, r: 16 })] }])
    const pair = rows(step(perSide, { type: 'set.step', entry: 0, set: 0, field: 'r', direction: 'up' }, NOW).state)[0]
    expect(pair.r).toBe(18)
    expect([pair.sides.L.r, pair.sides.R.r]).toEqual([9, 9])
    // Os segundos, de 5 em 5.
    const hold = withEntries(doc(), [{ id: PLANK, target: { mode: 'time', sec: 30 }, sets: [{ sec: 30, w: 0, done: false }] }])
    expect(rows(step(hold, { type: 'set.step', entry: 0, set: 0, field: 'sec', direction: 'up' }, NOW).state)[0].sec).toBe(35)
    // O esforço na escala do perfil: vazio sobe para o piso, e descer do piso apaga.
    const rir = begin(doc({ effort: 'rir' }))
    const e1 = step(rir, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'up' }, NOW).state
    expect(rows(e1)[0].rir).toBe(0)
    const e2 = step(e1, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'up' }, NOW).state
    expect(rows(e2)[0].rir).toBe(0.5)
    const e3 = step(step(e2, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'down' }, NOW).state, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'down' }, NOW).state
    expect('rir' in rows(e3)[0]).toBe(false)
    expect(rows(e2)[0].done).toBe(false)
    const rpe = begin(doc({ effort: 'rpe' }))
    expect(rows(step(rpe, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'up' }, NOW).state)[0].rpe).toBe(6)
    // O esforço da outra escala, e o esforço num perfil sem esforço, lançam.
    expect(() => step(rir, { type: 'set.update', entry: 0, set: 0, fields: { rpe: 8 } }, NOW)).toThrow(TypeError)
    expect(step(rir, { type: 'set.update', entry: 0, set: 0, fields: { rir: 2 } }, NOW).state.active.entries[0].sets[0].rir).toBe(2)
    expect(() => step(S, { type: 'set.step', entry: 0, set: 0, field: 'effort', direction: 'up' }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'set.step', entry: 0, set: 0, field: 'w', direction: 'left' }, NOW)).toThrow(TypeError)
  })

  it('set.add dá a série como o addSet, e set.remove nunca esvazia o exercício e só acaba o descanso da série removida', () => {
    const S = begin(doc())
    const added = step(S, { type: 'set.add', entry: 0 }, NOW)
    expect(rows(added.state)).toHaveLength(4)
    expect(rows(added.state)[3]).toEqual({ w: 60, r: 5, done: false })
    expect(types(added)).toEqual(['activity.update'])
    const perSide = withEntries(doc(), [{ id: CURL, target: { mode: 'reps', side: true }, sets: [makeSideSet({ w: 10, r: 16 })] }])
    expect(rows(step(perSide, { type: 'set.add', entry: 0 }, NOW).state)[1]).toEqual(makeSideSet({ w: 10, r: 16 }))
    const plank = withEntries(doc(), [{ id: PLANK, target: { mode: 'time', sec: 30, side: true }, sets: [{ sec: 30, w: 0, done: false, side: 'L' }, { sec: 30, w: 0, done: false, side: 'R' }] }])
    expect(rows(step(plank, { type: 'set.add', entry: 0 }, NOW).state).slice(2)).toEqual([{ sec: 30, w: 0, done: false, side: 'L' }, { sec: 30, w: 0, done: false, side: 'R' }])
    // Uma série só: nada muda.
    const one = withEntries(doc(), [{ id: SQUAT, target: { mode: 'reps' }, sets: [{ w: 60, r: 5, done: false }] }])
    const kept = step(one, { type: 'set.remove', entry: 0, set: 0 }, NOW)
    expect(kept.state).toBe(one)
    expect(kept.effects).toEqual([])
    // O descanso é da série 0: tirar a 2 deixa ele; tirar a 0 acaba com ele.
    const resting = mark(S, 0, 0).state
    const other = step(resting, { type: 'set.remove', entry: 0, set: 2 }, NOW + SEC)
    expect(rows(other.state)).toHaveLength(2)
    expect(other.state.active.rest).toEqual(resting.active.rest)
    expect(types(other)).toEqual(['activity.update'])
    const own = step(resting, { type: 'set.remove', entry: 0, set: 0 }, NOW + SEC)
    expect(own.state.active.rest).toBe(null)
    expect(types(own)).toEqual(['rest.cleared', 'activity.update'])
    // Tirar uma série acima da do descanso leva o descanso junto, e o marco desce com a série feita.
    const two = mark(mark(S, 0, 0).state, 0, 1, true, NOW + 100 * SEC).state
    expect(two.active.progress).toEqual([2])
    const shifted = step(two, { type: 'set.remove', entry: 0, set: 0 }, NOW + 101 * SEC).state
    expect(shifted.active.rest).toEqual({ ...two.active.rest, forSet: 0 })
    expect(shifted.active.progress).toEqual([1])
  })

  it('focus troca o cur, e um índice fora lança', () => {
    const S = begin(doc(), ['rt'])
    const out = step(S, { type: 'focus', entry: 1 }, NOW)
    expect(out.state.active.cur).toBe(1)
    expect(types(out)).toEqual(['activity.update'])
    const same = step(out.state, { type: 'focus', entry: 1 }, NOW)
    expect(same.state).toBe(out.state)
    expect(same.effects).toEqual([])
    expect(() => step(S, { type: 'focus', entry: 2 }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'focus', entry: -1 }, NOW)).toThrow(TypeError)
    expect(() => step(S, { type: 'focus', entry: 0.5 }, NOW)).toThrow(TypeError)
  })
})

describe('o controlador do treino: o descanso', () => {
  it('rest.adjust e rest.skip seguem o addRest e o stopRest do openGym', () => {
    const S = mark(begin(doc()), 0, 0, true, NOW).state
    const T = NOW + 10 * SEC   // faltam 80 s
    // Contando: +15 e -15 mudam o endsAt; o -15 não baixa o total.
    const plus = step(S, { type: 'rest.adjust', by: 15 }, T)
    expect(plus.state.active.rest).toEqual({ endsAt: NOW + 105 * SEC, total: 95, forIdx: 0, forSet: 0, kind: 'rest' })
    expect(plus.effects).toEqual([{ type: 'rest.started', endsAt: NOW + 105 * SEC, total: 95, kind: 'rest' }, { type: 'activity.update' }])
    const minus = step(S, { type: 'rest.adjust', by: -15 }, T)
    expect(minus.state.active.rest).toEqual({ endsAt: NOW + 75 * SEC, total: 90, forIdx: 0, forSet: 0, kind: 'rest' })
    expect(minus.effects[0]).toEqual({ type: 'rest.started', endsAt: NOW + 75 * SEC, total: 90, kind: 'rest' })
    // Faltando 10 s, o -15 acaba o descanso.
    const zero = step(S, { type: 'rest.adjust', by: -15 }, NOW + 80 * SEC)
    expect(zero.state.active.rest).toBe(null)
    expect(types(zero)).toEqual(['rest.cleared', 'activity.update'])
    // O teto do REST_MAX: o +15 só vai até ele, e no teto não muda nada.
    const near = withRest(S, { endsAt: NOW + (REST_MAX - 5) * SEC, total: REST_MAX - 5, forIdx: 0, forSet: 0, kind: 'rest' })
    const capped = step(near, { type: 'rest.adjust', by: 15 }, NOW)
    expect(capped.state.active.rest).toEqual({ endsAt: NOW + REST_MAX * SEC, total: REST_MAX, forIdx: 0, forSet: 0, kind: 'rest' })
    const atCap = step(capped.state, { type: 'rest.adjust', by: 15 }, NOW)
    expect(atCap.state).toBe(capped.state)
    expect(atCap.effects).toEqual([])
    // Acabado (o "Pronto"): o +15 começa outro de 15 s para a mesma série; o -15 acaba.
    const over = NOW + 95 * SEC
    const again = step(S, { type: 'rest.adjust', by: 15 }, over)
    expect(again.state.active.rest).toEqual({ endsAt: over + 15 * SEC, total: 15, forIdx: 0, forSet: 0, kind: 'rest' })
    expect(again.effects[0]).toEqual({ type: 'rest.started', endsAt: over + 15 * SEC, total: 15, kind: 'rest' })
    const done = step(S, { type: 'rest.adjust', by: -15 }, over)
    expect(done.state.active.rest).toBe(null)
    expect(types(done)).toEqual(['rest.cleared', 'activity.update'])
    // A pausa de trocar de lado: contando, o +15 fica no kind dela; acabada, o openGym já a tirou
    // (o tique do useUI.js põe o timer em null), então nem o +15 nem o -15 mudam alguma coisa.
    const sw = withRest(S, { endsAt: NOW + 10 * SEC, total: 10, forIdx: 0, forSet: 0, kind: 'switch' })
    const swPlus = step(sw, { type: 'rest.adjust', by: 15 }, NOW + 2 * SEC)
    expect(swPlus.state.active.rest).toEqual({ endsAt: NOW + 25 * SEC, total: 23, forIdx: 0, forSet: 0, kind: 'switch' })
    expect(swPlus.effects[0]).toEqual({ type: 'rest.started', endsAt: NOW + 25 * SEC, total: 23, kind: 'switch' })
    expect(step(sw, { type: 'rest.adjust', by: 15 }, NOW + 12 * SEC).state).toBe(sw)
    expect(step(sw, { type: 'rest.adjust', by: -15 }, NOW + 12 * SEC).state).toBe(sw)
    // rest.skip acaba o descanso contando, o acabado e a pausa de trocar de lado.
    for (const [doc0, at] of [[S, T], [S, over], [sw, NOW + 2 * SEC]]) {
      const skip = step(doc0, { type: 'rest.skip' }, at)
      expect(skip.state.active.rest).toBe(null)
      expect(types(skip)).toEqual(['rest.cleared', 'activity.update'])
    }
    // Sem descanso, nenhuma muda nada.
    const none = begin(doc())
    for (const a of [{ type: 'rest.adjust', by: 15 }, { type: 'rest.adjust', by: -15 }, { type: 'rest.skip' }]) {
      const out = step(none, a, T)
      expect(out.state).toBe(none)
      expect(out.effects).toEqual([])
    }
    expect(() => step(S, { type: 'rest.adjust', by: 10 }, T)).toThrow(TypeError)
  })
})

describe('o controlador do treino: o treino que veio do openGym', () => {
  it('cada linha é marcada inteira, os lados com o at na linha, e o resto do objeto continua igual', () => {
    const T0 = NOW - 20 * 60 * SEC
    const entries = [
      { id: SQUAT, rid: 'ra', noProg: true, target: { id: SQUAT, mode: 'reps', sets: 3, reps: 8, pyramid: [8, 6, 4], pyramidRest: [60, 90, 120] }, plan: { kind: 'off' }, sets: [
        { w: 40, r: 5, done: true, at: T0, phase: 'warmup' },
        { w: 60, r: 8, done: true, at: T0 + 60 * SEC },
        { w: 70, r: 6, done: false, rir: 2 },
        { w: 80, r: 4, done: false, type: 'dropset', drops: [{ w: 60, r: 4 }] },
      ] },
      { id: BENCH, rid: 'ra', target: { id: BENCH, mode: 'reps', sets: 1, reps: 8 }, sets: [{ w: 60, r: 8, done: false, type: 'restpause', clusters: [{ r: 3, restSec: 15 }] }] },
      { id: CURL, target: { id: CURL, mode: 'reps', side: true }, sets: [toggleSide(makeSideSet({ w: 10, r: 16 }), 'L'), makeSideSet({ w: 10, r: 16 })] },
      { id: RUN, target: { id: RUN, mode: 'cardio', min: 20, speed: 9 }, sets: [{ min: 20, speed: 9, done: false, incline: 2 }] },
      { id: PLANK, target: { id: PLANK, mode: 'time', sec: 45 }, sets: [{ sec: 45, w: 0, done: false, planSec: 30 }] },
    ]
    // Sem rest e sem progress, como o openGym grava, em lista e com os feitos recolhidos.
    const active = { id: 'og', d: '2026-11-08', start: T0, routineIds: ['ra'], name: 'A', bw: 80, cur: 0, entries, workoutView: 'list', collapseCompleted: true }
    const S = { ...doc(), active }
    const before = structuredClone(active)

    // A série de pirâmide: o marco nasce das séries feitas (2) e anda para 3.
    const a = mark(S, 0, 2)
    const A1 = a.state.active
    expect(A1.entries[0].sets[2]).toEqual({ w: 70, r: 6, done: true, rir: 2, at: NOW })
    expect(A1.progress).toEqual([3, 0, 0, 0, 0])
    expect(A1.rest.total).toBe(90)
    // Fora da série marcada, do progress e do rest, tudo igual campo a campo.
    for (const k of Object.keys(before)) if (k !== 'entries') expect(A1[k]).toEqual(before[k])
    expect(Object.keys(A1).sort()).toEqual([...Object.keys(before), 'progress', 'rest'].sort())
    for (let e = 1; e < entries.length; e++) expect(A1.entries[e]).toEqual(before.entries[e])
    for (const k of Object.keys(before.entries[0])) if (k !== 'sets') expect(A1.entries[0][k]).toEqual(before.entries[0][k])
    for (const i of [0, 1, 3]) expect(A1.entries[0].sets[i]).toEqual(before.entries[0].sets[i])
    for (const k of Object.keys(S)) if (k !== 'active') expect(a.state[k]).toBe(S[k])

    // O drop set, inteiro: o exercício acaba, grava o topW e, em lista com os feitos recolhidos, o cur anda.
    const b = mark(a.state, 0, 3, true, NOW + 90 * SEC).state
    expect(b.active.entries[0].sets[3]).toEqual({ ...before.entries[0].sets[3], done: true, at: NOW + 90 * SEC })
    expect(b.active.entries[0].topW).toBe(bestWeight(b.active.entries[0]))
    expect(b.active.cur).toBe(1)
    // O rest-pause, inteiro, e o cur segue.
    const c = mark(b, 1, 0, true, NOW + 200 * SEC).state
    expect(c.active.entries[1].sets[0]).toEqual({ ...before.entries[1].sets[0], done: true, at: NOW + 200 * SEC })
    expect(c.active.cur).toBe(2)
    // A linha com só o lado L feito: marcar faz os dois, com o at na linha e nunca no lado.
    const d = mark(c, 2, 0, true, NOW + 300 * SEC).state
    const row = d.active.entries[2].sets[0]
    expect(row.done).toBe(true)
    expect(row.sides.L.done && row.sides.R.done).toBe(true)
    expect(row.at).toBe(NOW + 300 * SEC)
    expect('at' in row.sides.L || 'at' in row.sides.R).toBe(false)
    expect(hasCompletedWork(row)).toBe(true)
    // O cardio e a série com tempo, inteiros; a série com tempo perde o planSec.
    const e = mark(mark(d, 3, 0, true, NOW + 400 * SEC).state, 4, 0, true, NOW + 500 * SEC).state
    expect(e.active.entries[3].sets[0]).toEqual({ min: 20, speed: 9, done: true, incline: 2, at: NOW + 400 * SEC })
    expect(e.active.entries[4].sets[0]).toEqual({ sec: 45, w: 0, done: true, at: NOW + 500 * SEC })

    // Desmarcar a linha com só um lado feito desmarca o lado, e ela deixa de contar.
    const undone = mark(S, 2, 0, false)
    const half = undone.state.active.entries[2].sets[0]
    expect(undone.state).not.toBe(S)
    expect(half.sides.L.done).toBe(false)
    expect(hasCompletedWork(half)).toBe(false)
    expect(undone.state.active.progress).toEqual([2, 0, 0, 0, 0])
    expect(active).toEqual(before)
  })
})

describe('o controlador do treino: exercícios no meio do treino', () => {
  const add = (S, exerciseIds, now = NOW) => step(S, { type: 'exercise.add', exerciseIds }, now)
  const replace = (S, entry, exerciseId, extra = {}, now = NOW) => step(S, { type: 'exercise.replace', entry, exerciseId, ...extra }, now)
  const remove = (S, entry, now = NOW) => step(S, { type: 'exercise.remove', entry }, now)
  const ids = S => S.active.entries.map(e => e.id)
  const routine = (S, id) => S.routines.find(r => r.id === id)
  const withDeload = () => {
    const S = doc()
    S.routines.push({ id: 'rd', name: 'Deload', excludeFromProgression: true, ex: [{ id: SQUAT, sets: 2, reps: 5, weight: 40, mode: 'reps' }] })
    return S
  }
  // Um treino gravado de agachamento, para o treino livre ter de onde tirar a semente.
  const squatDay = {
    id: 'h1', d: '2026-11-01', start: NOW - 7 * 86400 * SEC, end: NOW - 7 * 86400 * SEC + 3600 * SEC,
    entries: [{ id: SQUAT, target: { id: SQUAT, sets: 4, reps: 6, weight: 70, mode: 'reps' }, sets: [
      { w: 70, r: 6, done: true }, { w: 70, r: 6, done: true }, { w: 72.5, r: 5, done: true }, { w: 72.5, r: 5, done: true },
    ] }],
  }

  it('exercise.add numa rotina entra depois da unidade atual, com o rid e o addedInSession, e o cur vai para ele; no treino livre, sem rid e com a semente do freestyleConfig', () => {
    const S = begin(doc(), ['rt'])
    const cur = S.active.entries[0]
    const out = add(S, [CURL])
    const A = out.state.active
    expect(ids(out.state)).toEqual([SQUAT, CURL, BENCH])
    expect(A.entries[1]).toEqual({
      id: CURL, ...buildSessionEntry(S, CURL, pickedExerciseConfig(CURL), routine(S, 'rt'), cur), rid: 'rt', addedInSession: true,
    })
    expect(A.cur).toBe(1)
    expect(A.progress).toEqual([0, 0, 0])
    expect(out.result).toBe(null)
    expect(out.effects).toEqual([{ type: 'activity.update' }])
    // Dois de uma vez entram em ordem, e o cur fica no segundo, como somar um por vez.
    const two = add(S, [CURL, PLANK]).state.active
    expect(two.entries.map(e => e.id)).toEqual([SQUAT, CURL, PLANK, BENCH])
    expect(two.entries[2]).toEqual({
      id: PLANK, ...buildSessionEntry(S, PLANK, pickedExerciseConfig(PLANK), routine(S, 'rt'), cur), rid: 'rt', addedInSession: true,
    })
    expect(two.cur).toBe(2)

    // O treino livre: sem rotina, a semente é o último treino do exercício.
    const F = begin(doc({ workouts: [squatDay] }), [])
    const free = add(F, [SQUAT]).state.active
    const seed = freestyleConfig(sessionHistory(F), { id: SQUAT, ...pickedExerciseConfig(SQUAT) })
    expect(seed.sets).toBe(4)
    expect(free.entries).toEqual([{ id: SQUAT, ...buildSessionEntry(F, SQUAT, seed, null, undefined) }])
    expect('rid' in free.entries[0] || 'addedInSession' in free.entries[0]).toBe(false)
    expect(free.entries[0].sets.map(s => s.w)).toEqual([70, 70, 72.5, 72.5])
    expect(free.cur).toBe(0)
    expect(free.progress).toEqual([0])
  })

  it('com três ids, eles entram na ordem, depois do superset inteiro', () => {
    const S = begin(doc(), ['rs'])
    const A = add(S, [SQUAT, PLANK, RUN]).state.active
    expect(A.entries.map(e => e.id)).toEqual([CURL, BENCH, SQUAT, PLANK, RUN])
    expect(A.entries.map(e => e.sg)).toEqual(['g1', 'g1', undefined, undefined, undefined])
    expect(A.entries.slice(2).every(e => e.rid === 'rs' && e.addedInSession === true)).toBe(true)
    expect(A.cur).toBe(4)
    expect(A.progress).toEqual([0, 0, 0, 0, 0])
  })

  it('o forIdx de um descanso depois do ponto de inserção acompanha, o de antes fica, e o progress fica igual às séries feitas de agora', () => {
    // O marco do agachamento fica em 1 com a série desmarcada; adicionar refaz o marco pelas feitas.
    let S = begin(doc(), ['rt'])
    S = mark(S, 0, 0, true, NOW).state
    S = mark(S, 0, 0, false, NOW + 5 * SEC).state
    S = mark(S, 1, 0, true, NOW + 10 * SEC).state
    S = step(S, { type: 'focus', entry: 0 }, NOW + 11 * SEC).state
    expect(S.active.progress).toEqual([1, 1])
    const rest = S.active.rest
    expect(rest.forIdx).toBe(1)
    const out = add(S, [CURL], NOW + 20 * SEC)
    expect(ids(out.state)).toEqual([SQUAT, CURL, BENCH])
    expect(out.state.active.rest).toEqual({ ...rest, forIdx: 2 })
    expect(out.state.active.progress).toEqual([0, 0, 1])
    // O descanso não mudou de tempo, então não há rest.started de novo.
    expect(out.effects).toEqual([{ type: 'activity.update' }])

    // O descanso da entrada atual, antes do ponto de inserção, fica onde estava.
    const before = mark(begin(doc(), ['rt']), 0, 0, true, NOW).state
    const kept = add(before, [CURL], NOW + 10 * SEC).state.active
    expect(kept.rest).toEqual(before.active.rest)
    expect(kept.progress).toEqual([1, 0, 0])
  })

  it('num bloco com noProg, o exercício adicionado sai com noProg; num treino fora da progressão por inteiro, também', () => {
    const S = begin(withDeload(), ['rd'])
    expect(S.active.entries[0].noProg).toBe(true)
    const A = add(S, [BENCH]).state.active
    expect(A.entries[1]).toEqual({
      id: BENCH, ...buildSessionEntry(S, BENCH, pickedExerciseConfig(BENCH), routine(S, 'rd'), S.active.entries[0]),
      rid: 'rd', addedInSession: true, noProg: true,
    })
    expect(A.entries[1].plan.kind).toBe('off')

    // O treino inteiro fora da progressão (o menu do cabeçalho): o novo entra fora também (joinSessionNoProg).
    const whole = begin(doc(), ['ra'])
    whole.active.noProg = true
    whole.active.entries[0].noProg = true
    expect(add(whole, [BENCH]).state.active.entries[1].noProg).toBe(true)
    // E num bloco comum, o novo conta.
    expect('noProg' in add(begin(doc(), ['ra']), [BENCH]).state.active.entries[1]).toBe(false)
  })

  it('exercise.replace sem séries feitas troca no lugar, com o rid e o noProg do lugar, e acaba o descanso', () => {
    const S = begin(withDeload(), ['rd'])
    const out = replace(S, 0, BENCH)
    const want = clone(S.active)
    const built = buildSessionEntry(S, BENCH, pickedExerciseConfig(BENCH), routine(S, 'rd'), S.active.entries[0])
    swapActiveExercise(want, 0, { id: BENCH, ...built, rid: 'rd', noProg: true })
    expect(out.state.active).toEqual(want)
    const e = out.state.active.entries[0]
    expect([e.id, e.rid, e.noProg, e.plan.kind]).toEqual([BENCH, 'rd', true, 'off'])
    expect(out.state.active.entries).toHaveLength(1)
    expect(out.result).toEqual({ inserted: false, index: 0 })

    // O descanso de outra série acaba com a troca, como o stopRest do commitActiveSwap.
    const R = mark(step(begin(doc(), ['rt']), { type: 'focus', entry: 1 }, NOW).state, 1, 0, true, NOW).state
    expect(R.active.rest).not.toBe(null)
    const swapped = replace(R, 0, CURL, {}, NOW + 10 * SEC)
    expect(ids(swapped.state)).toEqual([CURL, BENCH])
    expect(swapped.state.active.entries[0].rid).toBe('rt')
    expect(swapped.state.active.cur).toBe(0)
    expect(swapped.state.active.rest).toBe(null)
    expect(types(swapped)).toEqual(['rest.cleared', 'activity.update'])

    // O marco na troca no lugar não é refeito como as séries feitas de agora: o número de entradas
    // não muda (Workout.jsx:1078-1080), e ele só abaixa quando a nova tem menos séries (1084-1093).
    // Marcada e desmarcada, a série deixa o marco em 1; com a nova de mais séries, ele fica.
    const undone = mark(mark(begin(doc(), ['rt']), 0, 0, true, NOW).state, 0, 0, false, NOW + 5 * SEC).state
    expect(undone.active.progress).toEqual([1, 0])
    const more = replace(undone, 0, CURL, {}, NOW + 10 * SEC).state.active
    expect(more.entries[0].sets.length).toBeGreaterThanOrEqual(undone.active.entries[0].sets.length)
    expect(more.progress).toEqual([1, 0])
    // Com a nova de menos séries, o marco abaixa até as feitas dela.
    const S5 = doc()
    S5.routines.push({ id: 'r5', name: 'Five', ex: [{ id: SQUAT, sets: 5, reps: 5, weight: 60, mode: 'reps' }] })
    const undone5 = mark(mark(begin(S5, ['r5']), 0, 0, true, NOW).state, 0, 0, false, NOW + 5 * SEC).state
    expect(undone5.active.progress).toEqual([1])
    const fewer = replace(undone5, 0, CURL, {}, NOW + 10 * SEC).state.active
    expect(fewer.entries[0].sets.length).toBeLessThan(5)
    expect(fewer.progress).toEqual([0])
  })

  it('com séries feitas, sem confirmLogged, devolve needs confirm e o mesmo S; com ele, a troca entra ao lado e o descanso acaba', () => {
    const S = mark(begin(doc(), ['rt']), 0, 0, true, NOW).state
    expect(S.active.rest).not.toBe(null)
    const ask = replace(S, 0, CURL, {}, NOW + 10 * SEC)
    expect(ask.state).toBe(S)
    expect(ask.effects).toEqual([])
    expect(ask.result).toEqual({ needs: 'confirm', grouped: false })
    expect(replace(S, 0, CURL, { confirmLogged: false }).state).toBe(S)

    const out = replace(S, 0, CURL, { confirmLogged: true }, NOW + 10 * SEC)
    const A = out.state.active
    expect(ids(out.state)).toEqual([SQUAT, CURL, BENCH])
    expect(A.entries[0]).toEqual(S.active.entries[0])
    expect(A.entries[1]).toEqual({
      id: CURL, ...buildSessionEntry(S, CURL, pickedExerciseConfig(CURL), routine(S, 'rt'), S.active.entries[0]), rid: 'rt',
    })
    expect(A.cur).toBe(1)
    expect(A.rest).toBe(null)
    expect(A.progress).toEqual([1, 0, 0])
    expect(out.result).toEqual({ inserted: true, index: 1 })
    expect(types(out)).toEqual(['rest.cleared', 'activity.update'])
  })

  it('num superset com séries feitas, confirmLogged sem group devolve needs confirm com grouped; keep fica no grupo e detach sai dele', () => {
    const S = mark(begin(doc(), ['rs']), 0, 0, true, NOW).state
    expect(replace(S, 0, SQUAT).result).toEqual({ needs: 'confirm', grouped: true })
    const ask = replace(S, 0, SQUAT, { confirmLogged: true })
    expect(ask.state).toBe(S)
    expect(ask.result).toEqual({ needs: 'confirm', grouped: true })

    const detach = replace(S, 0, SQUAT, { confirmLogged: true, group: 'detach' }).state.active
    expect(detach.entries.map(e => [e.id, e.sg])).toEqual([[CURL, 'g1'], [BENCH, 'g1'], [SQUAT, undefined]])
    expect(detach.cur).toBe(2)
    expect(detach.progress).toEqual([1, 0, 0])

    const keep = replace(S, 0, SQUAT, { confirmLogged: true, group: 'keep' }).state.active
    expect(keep.entries.map(e => [e.id, e.sg])).toEqual([[CURL, 'g1'], [SQUAT, 'g1'], [BENCH, 'g1']])
    expect(keep.cur).toBe(1)
    expect(() => replace(S, 0, SQUAT, { confirmLogged: true, group: 'other' })).toThrow(TypeError)
  })

  it('exercise.remove tira, limpa o superset desfeito, ajusta o cur e o descanso e refaz o progress', () => {
    let S = begin(doc(), ['rs', 'ra'])
    expect(ids(S)).toEqual([CURL, BENCH, SQUAT])
    S = mark(S, 1, 0, true, NOW).state
    S = mark(S, 1, 0, false, NOW + 5 * SEC).state
    S = step(S, { type: 'focus', entry: 2 }, NOW + 6 * SEC).state
    S = mark(S, 2, 0, true, NOW + 10 * SEC).state
    expect(S.active.progress).toEqual([0, 1, 1])
    const rest = S.active.rest
    expect(rest.forIdx).toBe(2)

    // Tirar o supino desfaz o superset (cleanupSg), puxa o cur e o descanso, e o marco é refeito.
    const out = remove(S, 1, NOW + 20 * SEC)
    const A = out.state.active
    expect(ids(out.state)).toEqual([CURL, SQUAT])
    expect('sg' in A.entries[0]).toBe(false)
    expect(A.cur).toBe(1)
    expect(A.rest).toEqual({ ...rest, forIdx: 1 })
    expect(A.progress).toEqual([0, 1])
    expect(out.effects).toEqual([{ type: 'activity.update' }])

    // Tirar o dono do descanso acaba o descanso.
    const owner = remove(out.state, 1, NOW + 30 * SEC)
    expect(ids(owner.state)).toEqual([CURL])
    expect(owner.state.active.rest).toBe(null)
    expect(owner.state.active.cur).toBe(0)
    expect(types(owner)).toEqual(['rest.cleared', 'activity.update'])

    // Tirar o último deixa entries vazio, e o treino continua.
    const empty = remove(owner.state, 0, NOW + 40 * SEC).state.active
    expect(empty).not.toBe(null)
    expect(empty.entries).toEqual([])
    expect(empty.cur).toBe(0)
    expect(empty.progress).toEqual([])
    expect(() => remove(owner.state, 1)).toThrow(TypeError)
  })

  it('um id desconhecido em exercise.add lança e não muda nada', () => {
    const S = deepFreeze(begin(doc(), ['ra']))
    const text = JSON.stringify(S)
    // O erro é o do exercício, e não o de uma ação que não existe.
    expect(() => add(S, ['nao-existe'])).toThrow(TypeError)
    expect(() => add(S, ['nao-existe'])).toThrow(/não existe o exercício nao-existe/)
    expect(() => add(S, [CURL, 'nao-existe'])).toThrow(/não existe o exercício nao-existe/)
    expect(() => add(S, [])).toThrow(/exerciseIds/)
    expect(() => add(S, CURL)).toThrow(/exerciseIds/)
    expect(() => replace(S, 0, 'nao-existe')).toThrow(/não existe o exercício nao-existe/)
    expect(JSON.stringify(S)).toBe(text)
  })
})

describe('o controlador do treino: puro', () => {
  // Todas as ações das Tasks 1 e 2, em ordem, num treino com superset, lados e esforço.
  const script = [
    [{ type: 'start', routineIds: ['rs', 'ra'], id: 'w1' }, 0],
    [{ type: 'set.mark', entry: 0, set: 0, done: true }, 10],
    [{ type: 'set.mark', entry: 1, set: 0, done: true }, 40],
    [{ type: 'set.mark', entry: 1, set: 0, done: false }, 45],
    [{ type: 'set.mark', entry: 1, set: 0, done: true }, 50],
    [{ type: 'set.update', entry: 2, set: 0, fields: { w: 62.5, r: 6, rir: 1 } }, 60],
    [{ type: 'set.step', entry: 2, set: 1, field: 'w', direction: 'up' }, 61],
    [{ type: 'set.step', entry: 2, set: 1, field: 'r', direction: 'down' }, 62],
    [{ type: 'set.step', entry: 2, set: 1, field: 'effort', direction: 'up' }, 63],
    [{ type: 'set.add', entry: 2 }, 64],
    [{ type: 'set.remove', entry: 2, set: 3 }, 65],
    [{ type: 'focus', entry: 2 }, 66],
    [{ type: 'rest.adjust', by: 15 }, 70],
    [{ type: 'rest.adjust', by: -15 }, 71],
    [{ type: 'rest.skip' }, 72],
    [{ type: 'set.mark', entry: 2, set: 0, done: true }, 80],
    [{ type: 'rest.adjust', by: 15 }, 400],
    [{ type: 'exercise.add', exerciseIds: [PLANK, CURL] }, 410],
    [{ type: 'exercise.replace', entry: 3, exerciseId: RUN }, 411],
    [{ type: 'exercise.replace', entry: 0, exerciseId: SQUAT }, 412],
    [{ type: 'exercise.replace', entry: 0, exerciseId: SQUAT, confirmLogged: true, group: 'detach' }, 413],
    [{ type: 'exercise.remove', entry: 1 }, 414],
  ]

  it('roda todas as ações com o Date.now e o Math.random trocados por funções que lançam', () => {
    const S = doc({ effort: 'rir' })
    const RealDate = Date
    class NoClock extends RealDate {
      constructor(...a) {
        if (!a.length) throw new Error('o controlador leu o relógio')
        super(...a)
      }
      static now() { throw new Error('o controlador leu o Date.now') }
    }
    vi.spyOn(Date, 'now').mockImplementation(() => { throw new Error('o controlador leu o Date.now') })
    vi.spyOn(Math, 'random').mockImplementation(() => { throw new Error('o controlador leu o Math.random') })
    vi.stubGlobal('Date', NoClock)
    const seen = []
    let s = S
    let failure = null
    try {
      for (const [action, sec] of script) {
        const out = step(s, action, NOW + sec * SEC)
        seen.push(out.effects.map(e => e.type))
        s = out.state
      }
    } catch (err) {
      failure = err
    } finally {
      vi.unstubAllGlobals()
      vi.restoreAllMocks()
    }
    expect(failure).toBe(null)
    expect(seen).toHaveLength(script.length)
    expect(s.active.entries[2].sets[0].done).toBe(true)
  })

  it('o S de entrada, congelado por inteiro, passa por todas as ações sem mudar', () => {
    let s = deepFreeze(doc({ effort: 'rir' }))
    for (const [action, sec] of script) {
      const text = JSON.stringify(s)
      const out = step(s, action, NOW + sec * SEC)
      expect(JSON.stringify(s)).toBe(text)
      s = deepFreeze(out.state)
    }
    expect(s.active.entries.map(e => e.id)).toEqual([CURL, SQUAT, SQUAT, RUN, CURL])
  })
})
