// O controlador do treino (seção 8.2 do design doc do HexGym, Tasks 1 a 3 do plano da fase 3): a
// sequência do treino em andamento como uma função pura, step(S, ação, agora) → { state, effects,
// result }, montada só com as funções que o lib já tem. O iPhone (pelo script do motor), o Watch e,
// um dia, o próprio openGym seguem as mesmas regras por aqui. O app web do openGym ainda não usa
// este módulo: o que ele reproduz está na tela e nos stores, e as linhas estão listadas abaixo para
// o PR de sync com o openGym comparar (seção 8.11).
//
// Puro: não lê o relógio (o agora vem de fora, em ms), não usa o Math.random (o id do treino vem
// na ação, então o uid() do format.js não entra), não muda o S que recebe e devolve o mesmo objeto
// quando nada muda. Não carimba: quem carimba é o session.js do HexEngine (Task 4). Uma ação
// inválida lança TypeError e não muda nada. Não toca som, vibração, aviso nem folha: o que a tela
// do openGym faz além do documento vira um efeito, que o app executa.
//
// O que cada ação reproduz do openGym (frontend/src):
//   start        sheets.jsx:3121-3140 (beginWorkout), sem a pesagem: o bw é o último peso do
//                documento (escolha 12 do plano).
//   set.mark     views/Workout.jsx:1776-1908 (toggle): a marca em 1785-1811, o descanso e o cur em
//                1827-1907; o listMode e o collapseOn em 1006-1008 e 1022; o marco de séries feitas
//                (progressHighWater) em 1074-1093; o SWITCH_SIDES_SEC em 108. A linha com lados é
//                marcada inteira (os dois lados), e o esforço não marca a série, ao contrário do
//                effortCell de 523-551 (escolha 7).
//   set.update   views/Workout.jsx:1275-1288 (setField) e, na linha com lados, 176-185 (setSide).
//   set.step     views/Workout.jsx:288-293 e 326-338 (bump), 542 (o passo do esforço) e 556-564
//                (sideBump).
//   set.add      views/Workout.jsx:1290-1313 (addSet).
//   set.remove   views/Workout.jsx:858-886 (deleteActiveSet) e 840-847 (shiftRowRefs).
//   focus        views/Workout.jsx:1974 (o next do bindLiveActions).
//   rest.adjust  store/useUI.js:336-354 (addRest).
//   rest.skip    store/useUI.js:382-389 (stopRest).
// O descanso, o timer do store/useUI.js no openGym, mora aqui em active.rest (escolha 13):
// startRest em useUI.js:284-307 (começar troca o que estava contando, e 0 s não começa nenhum) e o
// tique em 166-209 (a pausa de trocar de lado some quando acaba, 177-183; o descanso comum fica
// "Pronto", 185-202).
//
// Os campos do treino que são só do aparelho (escolha 13; o active nunca sai do aparelho):
//   active.rest      { endsAt, total, forIdx, forSet, kind } ou null; kind é 'rest' ou 'switch'.
//   active.progress  o marco de séries feitas de cada entrada (o progressHighWater do openGym).

import { draftOf, clone } from './state-core.js'
import { isoOf } from './format.js'
import { t } from './i18n-core.js'
import { buildCombinedEntries, deriveSessionName } from './session-merge.js'
import {
  nextUnfinishedUnit, ownSetRest, restAfterSet, restOnRecheck, restSecFor, setProgressHighWater,
  sideRestFor, supersetFlowStep, warmupRestSecFor,
} from './supersetFlow.js'
import { pyramidRestFor } from './pyramid.js'
import {
  EFFORT, bestWeightForEntry, cascadeWeight, effortOf, isPerSide, lastBW, modeOf, removeRowAt,
  repStep, setSpanAt, stepEffort, supersetUnits, unitOf,
} from './history.js'
import { stepWeight, weightIncrement } from './progression.js'
import { ownedWeightsFor, stepOwned } from './dumbbells.js'
import { inclineFrom } from './incline.js'
import { WEIGHT_ORIGIN_MANUAL, isSideSet, isWarmupRow, makeSideSet, setSideField, toggleSide } from './workout-model.js'
import { REST_MAX } from './duration.js'

// A pausa entre os dois lados de uma série com tempo, copiada do views/Workout.jsx:108 (está na
// tela do openGym, não no lib).
export const SWITCH_SIDES_SEC = 10

// Os limites de um valor novo numa série. O openGym não tem teto (o bump só não deixa ficar abaixo
// de 0): estes são do HexGym, como os SLOT_LIMITS do actions.js. Um treino do openGym com um valor
// fora deles abre normalmente; só o valor novo é conferido.
export const SET_LIMITS = { w: [0, 1000], r: [0, 100], sec: [1, 3600] }

const isMap = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const isIndex = (i, length) => Number.isInteger(i) && i >= 0 && i < length
const round2 = v => Math.round(v * 100) / 100

function fail(type, why) {
  throw new TypeError(`session: ${type}: ${why}`)
}
function need(ok, type, why) {
  if (!ok) fail(type, why)
}

// A configuração de uma entrada como a tela do openGym monta: o alvo com o id do exercício.
const cfgOf = e => ({ ...(e.target || {}), id: e.id })
// As séries feitas de uma entrada, como o useRef do progressHighWater conta (Workout.jsx:1074).
const doneCount = e => (Array.isArray(e?.sets) ? e.sets.filter(s => s.done).length : 0)

/**
 * O marco de séries feitas do treino: o active.progress quando ele tem um número por entrada, ou o
 * que o useRef do openGym teria ao nascer, as séries feitas de cada entrada agora. Um active vindo
 * do openGym não tem progress, e um com outro número de entradas é refeito, como o efeito do
 * Workout.jsx:1078-1080.
 */
export function progressOf(A) {
  const entries = Array.isArray(A?.entries) ? A.entries : []
  const p = A?.progress
  if (Array.isArray(p) && p.length === entries.length && p.every(n => Number.isInteger(n) && n >= 0)) return p.slice()
  return entries.map(doneCount)
}

/**
 * O descanso que existe agora, ou null. A pausa de trocar de lado que já acabou não existe mais:
 * no openGym, o tique a tira (store/useUI.js:177-183). O descanso comum que acabou continua, como o
 * "Pronto" do openGym, até alguém mexer nele.
 */
export function restNow(rest, now) {
  if (!isMap(rest) || !Number.isFinite(rest.endsAt)) return null
  if (rest.kind === 'switch' && now >= rest.endsAt) return null
  return rest
}
/** Se o descanso está contando (o timer do openGym que não está "Pronto"). */
export const restRunning = (rest, now) => !!restNow(rest, now) && now < rest.endsAt

// O startRest do store/useUI.js:284-288: começar troca o que estava contando, e 0 s (o descanso
// desligado) só para o que estava.
function startRest(A, sec, forIdx, forSet, now, kind = 'rest') {
  A.rest = sec > 0 ? { endsAt: now + sec * 1000, total: sec, forIdx, forSet, kind } : null
}

// O treino em andamento do rascunho (ler s.active copia só ele), ou o erro.
function activeOf(s, type) {
  const A = s.active
  need(isMap(A) && Array.isArray(A.entries), type, 'não há treino em andamento')
  return A
}
function entryAt(A, a) {
  need(isIndex(a.entry, A.entries.length), a.type, `não existe a entrada ${a.entry}`)
  const e = A.entries[a.entry]
  need(isMap(e) && Array.isArray(e.sets), a.type, `a entrada ${a.entry} não tem séries`)
  return e
}
function rowAt(A, a) {
  const e = entryAt(A, a)
  need(isIndex(a.set, e.sets.length), a.type, `não existe a série ${a.set} na entrada ${a.entry}`)
  need(isMap(e.sets[a.set]), a.type, `a série ${a.set} não é um objeto`)
  return e
}

// As colunas que a tela do openGym mostra para uma série, pelo modo (Workout.jsx:297-323): carga,
// repetições e esforço nas repetições; segundos e carga no tempo; nada disso no cardio.
function columnsOf(mode, kind) {
  if (mode === 'reps') return ['w', 'r', ...(EFFORT[kind] ? [EFFORT[kind].f] : [])]
  if (mode === 'time') return ['sec', 'w']
  return []
}

// Confere um valor novo de um campo. null apaga.
function checkValue(type, field, v, kind) {
  if (v === null) return
  need(typeof v === 'number' && Number.isFinite(v), type, `${field} precisa ser um número ou null`)
  if (field === 'rir' || field === 'rpe') {
    const e = EFFORT[kind]
    need(v >= e.min && v <= e.max && Number.isInteger(v * 2), type, `${field} vai de ${e.min} a ${e.max}, de 0,5 em 0,5`)
    return
  }
  const [min, max] = SET_LIMITS[field]
  need(v >= min && v <= max, type, `${field} vai de ${min} a ${max}`)
  if (field !== 'w') need(Number.isInteger(v), type, `${field} precisa ser um número inteiro`)
}

// O setField do Workout.jsx:1275-1288 numa série. Na linha com lados (a do exercício por lado), o
// valor vale para os dois lados, como o setSide de 176-185 feito em cada um: a carga e o esforço
// iguais, e as repetições, que são o total da linha, divididas ao meio (a sobra no L).
function setField(e, i, field, v) {
  const row = e.sets[i]
  if (isSideSet(row) && field !== 'sec') {
    const L = field === 'r' && v != null ? Math.ceil(v / 2) : v
    const R = field === 'r' && v != null ? v - L : v
    let out = setSideField(setSideField(row, 'L', field, L), 'R', field, R)
    if (field === 'w') {
      out = { ...out, sides: { L: { ...out.sides.L, weightOrigin: WEIGHT_ORIGIN_MANUAL }, R: { ...out.sides.R, weightOrigin: WEIGHT_ORIGIN_MANUAL } } }
      e.sets[i] = out
      e.sets = cascadeWeight(e.sets, i, v, undefined, e.target?.backoffStep)
    } else {
      e.sets[i] = out
    }
    return
  }
  if (v == null) delete row[field]
  else row[field] = v
  if (field === 'sec') delete row.planSec
  if (field === 'w') {
    row.weightOrigin = WEIGHT_ORIGIN_MANUAL
    e.sets = cascadeWeight(e.sets, i, v, undefined, e.target?.backoffStep)
  }
}

// O ramo de marcar do toggle (Workout.jsx:1785-1811 e 1827-1907), sem som, vibração, aviso, folha
// nem navegação. A linha é marcada inteira: a com lados fica com os dois feitos pelo toggleSide, e o
// at vai na linha, que é o que o sessionEnd e o finishedRow leem.
function markDone(A, idx, i, S, now, effects) {
  const e = A.entries[idx]
  let row = e.sets[i]
  if (isSideSet(row)) {
    for (const side of ['L', 'R']) if (!row.sides[side].done) row = toggleSide(row, side)
  } else {
    row = { ...row, done: true }
  }
  row.at = now
  if (row.planSec != null) delete row.planSec
  e.sets[i] = row
  effects.push({ type: 'haptic', kind: 'setLogged' })

  // A unidade dona da série marcada, não a do cur (Workout.jsx:1798-1803).
  const units = supersetUnits(A.entries)
  const unitDone = unitOf(units, idx).every(ui => A.entries[ui].sets.every(x => x.done))
  const workoutDone = unitDone && !nextUnfinishedUnit(A.entries, units, idx)
  if (e.sets.every(x => x.done)) e.topW = bestWeightForEntry(e) || null
  if (workoutDone) effects.push({ type: 'workout.complete' })

  // Só o progresso além do marco anda o cur ou muda o descanso (Workout.jsx:1827-1832).
  const progress = setProgressHighWater(e, A.progress[idx] || 0)
  A.progress[idx] = progress.highWater

  const freshUnit = units.find(u => u.includes(idx))
  const freshUnitDone = freshUnit?.every(ui => A.entries[ui].sets.every(x => x.done))
  const nextUnit = freshUnitDone ? nextUnfinishedUnit(A.entries, units, idx) : null
  const freshWorkoutDone = freshUnitDone && !nextUnit
  const restBeforeWarmup = nextUnit?.some(ui => A.entries[ui].sets.some(set => isWarmupRow(set) && !set.done))
  const setRest = { idx, sec: pyramidRestFor(e.target, e.sets, i) }
  const restSec = restSecFor(A.entries, freshUnit || [idx], S.restSec, setRest)
  const ownRest = ownSetRest(e.sets[setSpanAt(e.sets, i)[0]])
  const restAfter = ownRest ?? warmupRestSecFor(e, i, restSec, S.warmupRestSec)

  // A série marcada de novo (Workout.jsx:1858-1862): começa um descanso só se nenhum está contando.
  if (!progress.isNew) {
    if (!restBeforeWarmup && restOnRecheck({ timerRunning: restRunning(A.rest, now), unitDone: freshUnitDone, lastUnit: freshWorkoutDone })) startRest(A, restAfter, idx, i, now)
    return
  }

  // Em lista com os feitos recolhidos, o exercício que acabou sai da frente (Workout.jsx:1864-1872).
  const requested = A.workoutView || S.workoutView
  const listMode = requested === 'list' || requested === 'compact'
  const collapseOn = listMode && !!(A.collapseCompleted ?? S.collapseCompleted)
  if (collapseOn && freshUnitDone && nextUnit && freshUnit?.includes(A.cur)) A.cur = nextUnit[0]

  // Entre os dois lados de uma série com tempo, a pausa de trocar de lado (Workout.jsx:1874-1886).
  const mode = modeOf(cfgOf(e))
  const rows = e.sets
  const sideOf = r => (r && !isWarmupRow(r) ? r.side : null)
  const partner = sideOf(rows[i]) === 'L' && sideOf(rows[i + 1]) === 'R' ? rows[i + 1]
    : sideOf(rows[i]) === 'R' && sideOf(rows[i - 1]) === 'L' ? rows[i - 1] : null
  if (mode === 'time' && partner && !partner.done) {
    const pause = sideRestFor(e.target, { timed: true, restAfter, switchSec: SWITCH_SIDES_SEC })
    if (pause > 0) { startRest(A, pause, idx, i, now, 'switch'); return }
    if (e.target?.sideRestOff === true) { A.rest = null; return }
  }

  // O exercício simples e o superset (Workout.jsx:1888-1907).
  if (freshUnitDone) A.rest = null
  if (!freshUnit || freshUnit.length <= 1) {
    if (!restBeforeWarmup && restAfterSet({ unitDone: freshUnitDone, lastUnit: freshWorkoutDone })) startRest(A, restAfter, idx, i, now)
    return
  }
  const flow = supersetFlowStep(A.entries, freshUnit, idx)
  if (!flow) return
  if (flow.unitDone) {
    if (nextUnit?.length && !restBeforeWarmup) startRest(A, restAfter, idx, i, now)
  } else {
    if (flow.nextIdx != null) A.cur = flow.nextIdx
    if (flow.roundDone) startRest(A, restAfter, idx, i, now)
  }
}

// Cada ação: o run muda o rascunho s e devolve o result; S é o documento de antes, que só se lê
// (ler o rascunho copia o campo). O activity diz qual efeito da Live Activity sai quando a ação
// mudou o documento.
const ACTIONS = {
  start: {
    activity: 'activity.start',
    run(s, a, S, now) {
      need(S.active == null, a.type, 'já há um treino em andamento')
      need(typeof a.id === 'string' && a.id.length > 0, a.type, 'id precisa ser um texto')
      need(Array.isArray(a.routineIds) && a.routineIds.every(id => typeof id === 'string'), a.type, 'routineIds precisa ser uma lista de textos')
      const { entries, routineIds, routines } = buildCombinedEntries(S, a.routineIds)
      const bw = Array.isArray(S.bodyweight) ? lastBW(S)?.w : null
      s.active = {
        id: a.id, d: isoOf(new Date(now)), start: now,
        routineIds,
        name: routines.length ? deriveSessionName(routines.map(r => r.name)) : t('Freestyle'),
        bw: bw || null, cur: 0, entries: clone(entries),
        workoutView: S.workoutView || 'cards',
        rest: null, progress: entries.map(doneCount),
      }
      return { id: a.id }
    },
  },

  // Põe a série no estado pedido. Igual ao de agora (o done da linha e o de cada lado), nada muda.
  'set.mark': {
    run(s, a, S, now, effects) {
      need(typeof a.done === 'boolean', a.type, 'done precisa ser true ou false')
      const A = activeOf(s, a.type)
      const e = rowAt(A, a)
      const row = e.sets[a.set]
      const sides = isSideSet(row)
      if (row.done === a.done && (!sides || (row.sides.L.done === a.done && row.sides.R.done === a.done))) return null
      A.progress = progressOf(A)
      if (a.done) { markDone(A, a.entry, a.set, S, now, effects); return null }
      // Desmarcar tira o done (dos lados também) e deixa o at e o descanso, como o toggle.
      if (sides) {
        let out = row
        for (const side of ['L', 'R']) if (out.sides[side].done) out = toggleSide(out, side)
        e.sets[a.set] = out
      } else {
        row.done = false
      }
      return null
    },
  },

  'set.update': {
    run(s, a, S) {
      need(isMap(a.fields), a.type, 'fields precisa ser um objeto')
      const keys = Object.keys(a.fields)
      need(keys.length > 0, a.type, 'fields está vazio')
      const A = activeOf(s, a.type)
      const e = rowAt(A, a)
      const kind = effortOf(S)
      const allowed = columnsOf(modeOf(cfgOf(e)), kind)
      for (const k of keys) {
        need(allowed.includes(k), a.type, `a série não tem o campo ${k}`)
        checkValue(a.type, k, a.fields[k], kind)
      }
      for (const k of ['w', 'r', 'sec', 'rir', 'rpe']) if (keys.includes(k)) setField(e, a.set, k, a.fields[k])
      return null
    },
  },

  // O passo das entradas do HexDesign, como o bump do openGym: a entrada não decide o passo.
  'set.step': {
    run(s, a, S) {
      need(['w', 'r', 'sec', 'effort'].includes(a.field), a.type, 'field precisa ser w, r, sec ou effort')
      need(a.direction === 'up' || a.direction === 'down', a.type, 'direction precisa ser up ou down')
      const dir = a.direction === 'up' ? 1 : -1
      const A = activeOf(s, a.type)
      const e = rowAt(A, a)
      const row = e.sets[a.set]
      const cfg = cfgOf(e)
      const mode = modeOf(cfg)
      const kind = effortOf(S)
      const field = a.field === 'effort' ? EFFORT[kind]?.f : a.field
      need(field && columnsOf(mode, kind).includes(field), a.type, `a série não tem o campo ${a.field}`)
      let next
      if (a.field === 'effort') {
        next = stepEffort(kind, row[field] ?? null, dir)
      } else if (field === 'w' && mode === 'reps') {
        const owned = ownedWeightsFor(S, cfg)
        next = owned ? stepOwned(owned, row.w, dir) : stepWeight(row.w, weightIncrement(cfg, S.unit), dir)
      } else {
        const by = field === 'w' ? 2.5 : field === 'r' ? repStep(cfg) : 5
        next = Math.max(0, round2((Number(row[field]) || 0) + dir * by))
      }
      if (next != null && SET_LIMITS[field]) next = Math.min(SET_LIMITS[field][1], Math.max(SET_LIMITS[field][0], next))
      setField(e, a.set, field, next)
      return null
    },
  },

  'set.add': {
    run(s, a) {
      const A = activeOf(s, a.type)
      const e = entryAt(A, a)
      const l = e.sets[e.sets.length - 1]
      const tg = e.target || {}
      const cfg = cfgOf(e)
      const m = modeOf(cfg)
      if (m === 'cardio') e.sets.push({ min: l ? l.min : (tg.min || 20), speed: l ? l.speed : (tg.speed || 8), ...inclineFrom(l || tg), done: false })
      else if (m === 'time') {
        const sec = l ? l.sec : (tg.sec || 45)
        const w = l ? (l.w || 0) : (tg.weight || 0)
        if (isPerSide(cfg)) e.sets.push({ sec, w, done: false, side: 'L' }, { sec, w, done: false, side: 'R' })
        else e.sets.push({ sec, w, done: false })
      } else {
        const row = { w: l ? l.w : 0, r: l ? l.r : tg.reps, done: false, ...(l && l.max ? { max: true } : {}) }
        e.sets.push(isPerSide(cfg)
          ? (l && isSideSet(l) ? makeSideSet({ w: l.sides.L.w, r: (l.sides.L.r || 0) * 2 }) : makeSideSet(row))
          : row)
      }
      return null
    },
  },

  // Tira a série (as duas linhas de um par L e R) e deixa pelo menos uma. O descanso acaba só
  // quando era dela; o de uma série abaixo acompanha a linha.
  'set.remove': {
    run(s, a) {
      const A = activeOf(s, a.type)
      const e = rowAt(A, a)
      const [start, count] = setSpanAt(e.sets, a.set)
      if (e.sets.length <= count) return null
      A.progress = progressOf(A)
      const inSpan = j => j != null && j >= start && j < start + count
      const rest = A.rest
      if (isMap(rest) && rest.forIdx === a.entry && inSpan(rest.forSet)) A.rest = null
      else if (isMap(rest) && rest.forIdx === a.entry && rest.forSet != null && rest.forSet >= start + count) A.rest = { ...rest, forSet: rest.forSet - count }
      e.sets = removeRowAt(e.sets, a.set)
      // A série tirada leva a marca junto (Workout.jsx:1084-1093).
      A.progress[a.entry] = Math.min(A.progress[a.entry] || 0, doneCount(e))
      return null
    },
  },

  focus: {
    run(s, a) {
      const A = activeOf(s, a.type)
      need(isIndex(a.entry, A.entries.length), a.type, `não existe a entrada ${a.entry}`)
      A.cur = a.entry
      return null
    },
  },

  'rest.adjust': {
    run(s, a, S, now) {
      need(a.by === 15 || a.by === -15, a.type, 'by precisa ser 15 ou -15')
      const A = activeOf(s, a.type)
      const tm = restNow(A.rest, now)
      if (!tm) return null
      // Acabado (o "Pronto"): o +15 começa outro, comum, para a mesma série; o -15 acaba.
      if (now >= tm.endsAt) {
        if (a.by > 0) startRest(A, Math.min(a.by, REST_MAX), tm.forIdx, tm.forSet, now)
        else A.rest = null
        return null
      }
      const left = Math.max(0, Math.round((tm.endsAt - now) / 1000))
      const by = a.by > 0 ? Math.min(a.by, Math.max(0, REST_MAX - left)) : a.by
      if (!by) return null
      const total = left + by
      if (total <= 0) { A.rest = null; return null }
      A.rest = { ...tm, total: Math.max(tm.total || total, total), endsAt: tm.endsAt + by * 1000 }
      return null
    },
  },

  'rest.skip': {
    run(s, a, S, now) {
      const A = activeOf(s, a.type)
      if (restNow(A.rest, now)) A.rest = null
      return null
    },
  },
}

// Se o rascunho saiu diferente do documento de antes, como o changedFrom do actions.js: o campo que
// a ação nem leu continua o mesmo objeto (draftOf), e só os lidos são comparados pelo texto.
function changedFrom(prev, S) {
  for (const k of new Set([...Object.keys(prev), ...Object.keys(S)])) {
    if (prev[k] === S[k]) continue
    if (!(k in prev) || !(k in S) || JSON.stringify(prev[k]) !== JSON.stringify(S[k])) return true
  }
  return false
}

// O efeito do descanso: o que existia antes da ação contra o que ficou depois.
function restEffect(before, after) {
  const a = isMap(after) ? after : null
  if (!a) return before ? { type: 'rest.cleared' } : null
  if (before && before.endsAt === a.endsAt && before.total === a.total && before.kind === a.kind) return null
  return { type: 'rest.started', endsAt: a.endsAt, total: a.total, kind: a.kind }
}

/**
 * Roda uma ação no documento S, com o agora em ms. Devolve { state, effects, result }: o documento
 * novo (o mesmo S quando nada mudou, e então nenhum efeito), os efeitos na ordem em que acontecem e
 * o resultado da ação (null quando ela não tem). Os efeitos:
 *   { type: 'haptic', kind: 'setLogged' }            ao marcar uma série;
 *   { type: 'workout.complete' }                     quando a última série do treino fica feita;
 *   { type: 'rest.started', endsAt, total, kind }    quando o descanso começa ou muda;
 *   { type: 'rest.cleared' }                         quando ele acaba;
 *   { type: 'activity.start' } ou { type: 'activity.update' }, por último, quando o treino mudou.
 */
export function step(S, action, now) {
  need(isMap(S), 'step', 'o documento precisa ser um objeto')
  need(isMap(action) && typeof action.type === 'string', 'step', 'a ação precisa ser um objeto com type')
  need(Object.hasOwn(ACTIONS, action.type), 'step', `não existe a ação ${action.type}`)
  need(typeof now === 'number' && Number.isFinite(now), action.type, 'now precisa ser um número')
  const spec = ACTIONS[action.type]
  const draft = draftOf(S)
  const effects = []
  const result = spec.run(draft.S, action, S, now, effects) ?? null
  const next = draft.done()
  if (!changedFrom(S, next)) return { state: S, effects: [], result }
  // Um active do openGym, sem marco, ganha o de antes da ação, como o useRef nasce com a tela.
  if (isMap(next.active) && next.active !== S.active && isMap(S.active) && !Array.isArray(next.active.progress)) next.active.progress = progressOf(S.active)
  // A pausa de trocar de lado que já acabou sai do treino, como o tique do openGym põe o timer em
  // null (store/useUI.js:177-183): ela não existe mais, e nenhuma ação depois dela agenda descanso.
  if (isMap(next.active) && next.active !== S.active && isMap(next.active.rest) && !restNow(next.active.rest, now)) next.active.rest = null
  const rest = restEffect(restNow(S.active?.rest, now), restNow(next.active?.rest, now))
  if (rest) effects.push(rest)
  effects.push({ type: spec.activity || 'activity.update' })
  return { state: next, effects, result }
}
