// O treino em andamento no documento aberto e as leituras das telas (seções 8.2 e 8.6 do design doc,
// Task 4 do plano da fase 3). As regras do treino são as do controlador do openGym
// (frontend/src/lib/session-controller.js, Tasks 1 a 3); aqui ficam o carimbo do update() do
// store/useStore.js, os eventos da Live Activity e o que cada tela lê: o treino em andamento, a tela
// inicial e a Live Activity. Cada função recebe o documento, e o runtime.js passa o aberto e troca o
// JSON com o Swift.
//
// As horas entram e saem em ms. Nenhuma função daqui lê o relógio: o agora vem do Swift. As do lib
// que só leem o relógio por dentro (o streakWeeks) rodam como estão.
import { clone } from '../../../../frontend/src/lib/state-core.js'
import { stampChange } from '../../../../frontend/src/lib/sync-merge.js'
import { restNow, step } from '../../../../frontend/src/lib/session-controller.js'
import {
  effectiveRoutineIds, effortOf, exLine, isBw, modeOf, nextTrainingDay, setUnitsTotal, setLabel, setsDone, setsDoneActive, streakWeeks,
  supersetUnits, workoutDay, workoutDuration,
} from '../../../../frontend/src/lib/history.js'
import { nextUnfinishedUnit } from '../../../../frontend/src/lib/supersetFlow.js'
import { queueOf, weekTally } from '../../../../frontend/src/lib/queue.js'
import { fmtNum, isoOf, startOfWeek, weekOrder, weekStartOf, exerciseNameText } from '../../../../frontend/src/lib/format.js'
import { speedUnitOf } from '../../../../frontend/src/lib/speed.js'
import { bellsIn, dbLoadOf } from '../../../../frontend/src/lib/dumbbells.js'
import { clustersOf, dropsOf, isDropSet, isRestPauseSet, isSideSet, isWarmupRow } from '../../../../frontend/src/lib/workout-model.js'
import { EXIDX, defaultIncrement } from '../../../../frontend/src/lib/exercises.js'
import { weightIncrement } from '../../../../frontend/src/lib/progression.js'
import { exerciseNameFor, t } from '../../../../frontend/src/lib/i18n-core.js'
import { glyphStr } from '../../../../api/coach/core/glyphs.js'

// As séries depois da atual que a Live Activity leva, para o "Série feita" dela andar sem o app
// (o LIVE_AHEAD do lib/live-activity.js do openGym).
export const LIVE_AHEAD = 8
// O orçamento do JSON da Live Activity em bytes (o LIVE_BUDGET do lib/live-activity.js): o
// ActivityKit recusa uma atualização acima de 4 KB.
export const LIVE_BUDGET = 3600
// O corte dos nomes na Live Activity, em letras. O corte é do HexGym; o openGym só encolhe a lista.
export const LIVE_NAME_MAX = 40
// Os ids de eventos da Live Activity já aplicados que o treino guarda (active.liveSeen).
export const LIVE_SEEN_MAX = 64

const isMap = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const list = v => (Array.isArray(v) ? v : [])
const isIndex = (i, length) => Number.isInteger(i) && i >= 0 && i < length
// Um número do documento para o Swift: o número, ou null. O int arredonda, para o Swift ler Int.
const num = v => (typeof v === 'number' && Number.isFinite(v) ? v : null)
const int = v => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : null)

// O treino em andamento que as telas leem, ou null. A edição de um treino salvo (o editingWorkoutId
// do openGym) não é um treino em andamento aqui, como no buildLiveActivity de lá.
function runningOf(S) {
  const A = S?.active
  return isMap(A) && Array.isArray(A.entries) && !A.editingWorkoutId ? A : null
}

// O carimbo do update() do store/useStore.js, como o apply do actions.js: os mapas deleted e edited
// copiados quando o documento novo ainda os divide com o de antes, e o S._ts do stampChange.
function stamped(prev, S, now) {
  for (const k of ['deleted', 'edited']) if (isMap(S[k]) && S[k] === prev[k]) S[k] = clone(S[k])
  S._ts = stampChange(prev, S, now)
  return S
}

/**
 * Roda uma ação do controlador no documento prev, com o agora em ms, e devolve { doc, changed,
 * effects, result }: o documento novo, carimbado, ou o mesmo prev quando nada mudou. Uma ação
 * inválida lança o TypeError do controlador, e o prev fica como estava.
 */
export function apply(prev, action, now) {
  const { state, effects, result } = step(prev, action, now)
  if (state === prev) return { doc: prev, changed: false, effects, result }
  return { doc: stamped(prev, state, now), changed: true, effects, result }
}

/* ---------- o treino em andamento ---------- */

// A configuração de uma entrada como a tela do openGym monta: o alvo com o id do exercício.
const cfgOf = e => ({ ...(isMap(e?.target) ? e.target : {}), id: e?.id })
const knownEx = id => typeof id === 'string' && Object.hasOwn(EXIDX, id)
// O nome de um exercício, ou o "Exercício desconhecido" do openGym (exOr) quando ele não existe
// neste aparelho (apagado, ou personalizado de outro), sem derrubar a tela (Foco da revisão 5).
const nameOf = id => (knownEx(id) ? exerciseNameFor(EXIDX[id]) : t('Unknown exercise'))

// O sg de uma entrada, em texto, ou null.
function groupOf(e) {
  const v = e?.sg
  return (typeof v === 'string' || typeof v === 'number') && String(v) ? String(v) : null
}

// A letra de cada superset, na ordem em que aparecem: A, B, C... Só os supersets de verdade (dois ou
// mais exercícios vizinhos com o mesmo sg, as unidades do supersetUnits) ganham letra.
function supersetLetters(entries) {
  const letters = new Map()
  for (const unit of supersetUnits(entries)) {
    if (unit.length < 2) continue
    const letter = String.fromCharCode(65 + (letters.size % 26))
    for (const i of unit) letters.set(i, letter)
  }
  return letters
}

// O tipo de uma série, para a tela desenhar: o cardio pelo modo, a série com lados, o drop set e o
// rest-pause pelo workout-model.js, e o resto normal.
function kindOf(mode, s) {
  if (mode === 'cardio') return 'cardio'
  if (isSideSet(s)) return 'sides'
  if (isDropSet(s)) return 'drop'
  if (isRestPauseSet(s)) return 'restpause'
  return 'normal'
}

// A linha curta de uma série: "60 kg × 8" na série comum de repetições com carga. A série com lados,
// o drop set, o rest-pause, o peso do corpo, o halter que diz "cada" ou "total", a de tempo e o
// cardio leem como o setLabel do openGym os escreve ("L 15×8 · R 15×7", "0:45 · 10",
// "20 min @ 8 km/h"), porque é lá que mora o formato de cada um.
function lineOf(S, e, s) {
  const cfg = cfgOf(e)
  const mode = modeOf(cfg)
  const plain = mode === 'reps' && !isSideSet(s) && !dropsOf(s).length && !clustersOf(s).length && !isBw(cfg)
    && !(bellsIn(cfg) === 2 && dbLoadOf(cfg.dbLoad))
  if (plain) return `${fmtNum(Number(s.w) || 0)} ${S.unit === 'lb' ? 'lb' : 'kg'} × ${Number(s.r) || 0}`
  try {
    return setLabel(e.id, s, e.target, speedUnitOf(S))
  } catch {
    // Uma série que o setLabel não lê (um treino estragado de outro aparelho) fica sem linha, e a
    // tela continua.
    return ''
  }
}

// O passo da carga na unidade do perfil, como o slotSummary do actions.js: o inc do alvo no modo de
// repetições, e o padrão nos outros.
const incrementOf = (cfg, unit) => (modeOf(cfg) === 'reps' ? weightIncrement(cfg, unit) : defaultIncrement(cfg.id, unit))

// A primeira série por fazer de uma entrada, ou null.
function openSetOf(A, i) {
  const sets = A.entries[i]?.sets
  const j = Array.isArray(sets) ? sets.findIndex(s => isMap(s) && !s.done) : -1
  return j >= 0 ? { entry: i, set: j } : null
}
const curOf = A => (A.entries.length ? Math.max(0, Math.min(A.entries.length - 1, Number.isInteger(A.cur) ? A.cur : 0)) : 0)

/**
 * A série que o "Série feita" marca: a primeira por fazer do exercício atual; sem ela, a de um
 * parceiro de superset dele; sem ela, a primeira da unidade que o nextUnfinishedUnit do openGym dá
 * (a seguinte com série por fazer, voltando ao começo). null quando tudo está feito.
 */
export function nextSetOf(A) {
  if (!A.entries.length) return null
  const cur = curOf(A)
  const units = supersetUnits(A.entries)
  const own = units.find(u => u.includes(cur)) || [cur]
  for (const i of [cur, ...own.filter(i => i !== cur)]) {
    const found = openSetOf(A, i)
    if (found) return found
  }
  for (const i of nextUnfinishedUnit(A.entries, units, cur) || []) {
    const found = openSetOf(A, i)
    if (found) return found
  }
  return null
}

// O descanso da tela, ou null: o que existe agora (a pausa de trocar de lado que acabou não existe
// mais; o descanso comum que acabou continua, como o "Pronto" do openGym), com o que falta em
// segundos, arredondado como o tique do store/useUI.js:171, nunca abaixo de 0.
function restView(A, now) {
  const r = restNow(A.rest, now)
  if (!r) return null
  return {
    endsAt: r.endsAt, total: int(r.total) ?? 0, forIdx: int(r.forIdx), forSet: int(r.forSet), kind: r.kind === 'switch' ? 'switch' : 'rest',
    remaining: Math.max(0, Math.round((r.endsAt - now) / 1000)),
  }
}

/** O modelo da tela do treino em andamento, ou null sem treino. */
export function activeWorkout(S, now) {
  const A = runningOf(S)
  if (!A) return null
  const unit = S.unit === 'lb' ? 'lb' : 'kg'
  const letters = supersetLetters(A.entries)
  return {
    id: String(A.id ?? ''),
    name: typeof A.name === 'string' ? A.name : '',
    start: num(A.start),
    unit,
    effort: effortOf(S),
    cur: curOf(A),
    // As contas da barra do openGym (Workout.jsx:1264-1265): o lado de uma série com lados conta um.
    done: setsDoneActive(A),
    total: setUnitsTotal(A.entries),
    rest: restView(A, now),
    next: nextSetOf(A),
    entries: A.entries.map((e, index) => {
      const cfg = cfgOf(e)
      const mode = modeOf(cfg)
      return {
        index,
        id: String(e?.id ?? ''),
        name: nameOf(e?.id),
        known: knownEx(e?.id),
        mode,
        sg: groupOf(e),
        sgLetter: letters.get(index) ?? null,
        target: exLine(cfg, unit, speedUnitOf(S)),
        increment: incrementOf(cfg, unit),
        sets: list(e?.sets).map((s, i) => (isMap(s) ? {
          index: i,
          w: num(s.w), r: int(s.r), sec: int(s.sec), rir: num(s.rir), rpe: num(s.rpe),
          done: s.done === true,
          warmup: isWarmupRow(s),
          kind: kindOf(mode, s),
          line: lineOf(S, e, s),
        } : { index: i, w: null, r: null, sec: null, rir: null, rpe: null, done: false, warmup: false, kind: 'normal', line: '' })),
      }
    }),
  }
}

/* ---------- a tela inicial ---------- */

// O documento com os campos que as funções do plano do openGym leem sem conferir (o dayPlan[iso], o
// week[wd] e o routines.some), para um documento antigo ou estragado não derrubar a tela.
const planned = S => ({
  ...S,
  dayPlan: isMap(S.dayPlan) ? S.dayPlan : {},
  week: isMap(S.week) ? S.week : {},
  routines: list(S.routines).filter(isMap),
  workouts: list(S.workouts).filter(isMap),
})

// O treino mais novo, pelo dia (workoutDay) e depois o começo.
function newest(workouts) {
  let best = null
  let key = null
  for (const w of workouts) {
    const k = [workoutDay(w) || '', Number(w.start) || 0]
    if (!best || k[0] > key[0] || (k[0] === key[0] && k[1] >= key[1])) { best = w; key = k }
  }
  return best
}

/**
 * O resumo da tela inicial no dia do now. O status de hoje: done quando as rotinas de hoje já foram
 * feitas e há treino no dia (o doneToday do views/Home.jsx:59-62, que num dia de descanso vale para
 * qualquer treino do dia); planned com rotinas para hoje; rest num dia sem rotina de uma semana que
 * tem treino em outro dia (o nextTrainingDay) ou num dia marcado como descanso; none sem nada
 * planejado. O total é o número de treinos do histórico.
 */
export function home(S0, now) {
  const S = planned(S0)
  const today = isoOf(new Date(now))
  const ids = effectiveRoutineIds(S, today, today)
  const routines = ids.map(id => S.routines.find(r => r.id === id)).filter(Boolean)
  const loggedToday = S.workouts.filter(w => w.d === today)
  const queueIds = list(queueOf(S)?.ids)
  const covered = id => !queueIds.includes(id) && loggedToday.some(w => (Array.isArray(w.routineIds) ? w.routineIds : [w.routineId]).includes(id))
  const done = loggedToday.length > 0 && routines.every(r => covered(r.id))
  const status = done ? 'done' : routines.length ? 'planned' : S.dayPlan[today] === 'rest' || nextTrainingDay(S, today) ? 'rest' : 'none'

  const ws = weekStartOf(S)
  const first = startOfWeek(today, ws)
  const trained = new Set(S.workouts.map(workoutDay).filter(Boolean))
  const week = weekOrder(ws).map((day, i) => {
    const d = new Date(first)
    d.setDate(first.getDate() + i)
    const date = isoOf(d)
    return { day, date, trained: trained.has(date), planned: effectiveRoutineIds(S, date, today).length > 0, today: date === today }
  })

  const A = runningOf(S)
  const last = newest(S.workouts)
  return {
    today: { date: today, status, routines: routines.map(r => ({ id: String(r.id), name: typeof r.name === 'string' ? r.name : '', glyph: glyphStr(r.emoji) })) },
    active: A ? { name: typeof A.name === 'string' ? A.name : '', start: num(A.start), done: setsDoneActive(A), total: setUnitsTotal(A.entries) } : null,
    week,
    streakWeeks: streakWeeks(S),
    weekCount: weekTally(S, today).done,
    total: S.workouts.length,
    last: last ? {
      id: last.id != null ? String(last.id) : null,
      name: typeof last.name === 'string' ? last.name : '',
      d: workoutDay(last),
      durationMs: workoutDuration(last),
      sets: setsDone({ entries: list(last.entries).map(e => ({ sets: list(e?.sets).filter(isMap) })) }),
    } : null,
  }
}

/* ---------- a Live Activity ---------- */

/**
 * As séries por fazer, na ordem do upcomingSets do lib/live-activity.js do openGym (que não entra no
 * motor, porque importa o mobile.js, o i18n.js e o @capacitor/core): da unidade do exercício atual em
 * diante, o superset volta por volta (a1, b1, a2, b2), depois as unidades seguintes e por fim as de
 * antes que ainda têm série por fazer.
 */
function upcomingSets(A) {
  const units = supersetUnits(A.entries)
  const cur = curOf(A)
  const start = Math.max(0, units.findIndex(u => u.includes(cur)))
  const out = []
  for (const unit of [...units.slice(start), ...units.slice(0, start)]) {
    const rounds = Math.max(0, ...unit.map(i => list(A.entries[i]?.sets).length))
    for (let r = 0; r < rounds; r++) {
      for (const i of unit) {
        const s = A.entries[i]?.sets?.[r]
        if (isMap(s) && !s.done) out.push({ entry: i, set: r })
      }
    }
  }
  return out
}

/**
 * O descanso que vem depois de cada série da lista, marcando uma por uma, na ordem, numa cópia do
 * documento pelo próprio controlador: cada marca no instante em que o descanso da anterior acaba,
 * como quem treina. Assim, o descanso é o mesmo que o app daria (o do perfil, do exercício, da
 * pirâmide, do aquecimento e do superset, que só descansa no fim da volta), e 0 quando nenhum
 * começa (o fim do treino) ou quando o que começa é a pausa de trocar de lado, que a Live Activity
 * não mostra. O documento aberto não muda.
 */
function restsAfter(S, refs, now) {
  let doc = S
  let at = now
  return refs.map(ref => {
    let out
    try {
      out = step(doc, { type: 'set.mark', entry: ref.entry, set: ref.set, done: true }, at)
    } catch {
      // Uma série que o controlador não marca (um treino estragado) não tem descanso para mostrar.
      return 0
    }
    doc = out.state
    const rest = doc.active?.rest
    if (isMap(rest) && Number.isFinite(rest.endsAt)) at = Math.max(at, rest.endsAt)
    at += 1000
    const started = out.effects.find(e => e.type === 'rest.started')
    return started && started.kind !== 'switch' ? Math.max(0, Math.round(started.total)) : 0
  })
}

// O texto cortado em max letras (pontos de código, para não partir um emoji), com reticências.
function cut(text, max = LIVE_NAME_MAX) {
  const letters = Array.from(String(text ?? ''))
  return letters.length <= max ? letters.join('') : letters.slice(0, max - 1).join('') + '…'
}

// Os bytes do texto em UTF-8, contados à mão: o motor não tem TextEncoder.
function utf8Length(text) {
  let n = 0
  for (const ch of text) {
    const c = ch.codePointAt(0)
    n += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
  }
  return n
}
export const liveBytes = model => utf8Length(JSON.stringify(model))

// Uma série na Live Activity, como o setView do lib/live-activity.js: o exercício com as maiúsculas
// da tela (exerciseNameText) e "Série 2 de 3 · 60 kg × 8" (ou "Aquecimento 1 · ...").
function liveItem(S, A, ref, restAfter) {
  const e = A.entries[ref.entry]
  const s = e.sets[ref.set]
  const sets = list(e.sets).filter(isMap)
  const warmup = isWarmupRow(s)
  const work = sets.filter(x => !isWarmupRow(x))
  const n = warmup ? sets.filter(isWarmupRow).indexOf(s) + 1 : work.indexOf(s) + 1
  const label = warmup ? `${t('Warm-up')} ${n}` : t('Set {0} of {1}', n, work.length)
  const line = lineOf(S, e, s)
  return {
    entry: ref.entry,
    set: ref.set,
    exId: String(e.id ?? ''),
    exercise: cut(knownEx(e.id) ? exerciseNameText(EXIDX[e.id]) : t('Unknown exercise')),
    setLine: line ? `${label} · ${line}` : label,
    restAfter,
  }
}

/**
 * O que a Live Activity mostra, ou null sem treino. O cur é a série que o "Série feita" marca (o
 * next do activeWorkout), e o ahead são as até 8 séries por fazer que vêm depois dela, cada uma com
 * o descanso depois dela, para a Live Activity andar sozinha (Task 14). Cada série leva o id do
 * exercício (exId), para um evento achar a entrada quando adicionar, trocar ou remover um exercício
 * mudou as posições. O done e o total contam linhas, como o buildLiveActivity do openGym
 * (live-activity.js:121-122): o "Série feita" da Live Activity marca uma linha e soma uma. A pausa de
 * trocar de lado e o descanso que já acabou não aparecem (live-activity.js:123). O JSON fica abaixo
 * de 3.600 bytes: o ahead encolhe do fim até caber.
 */
export function liveActivity(S, now) {
  const A = runningOf(S)
  if (!A) return null
  const next = nextSetOf(A)
  const refs = next ? [next, ...upcomingSets(A).filter(r => r.entry !== next.entry || r.set !== next.set)].slice(0, 1 + LIVE_AHEAD) : []
  const rests = restsAfter(S, refs, now)
  const items = refs.map((ref, i) => liveItem(S, A, ref, rests[i]))
  let done = 0
  let total = 0
  for (const e of A.entries) for (const s of list(e?.sets)) { total++; if (s?.done) done++ }
  const r = restNow(A.rest, now)
  const rest = r && r.kind !== 'switch' && now < r.endsAt ? r : null
  const model = {
    name: cut(typeof A.name === 'string' ? A.name : ''),
    done, total,
    restEndsAt: rest ? rest.endsAt : null,
    restTotal: rest ? int(rest.total) : null,
    cur: items[0] ?? null,
    ahead: items.slice(1),
  }
  while (model.ahead.length && liveBytes(model) > LIVE_BUDGET) model.ahead.pop()
  return model
}

/* ---------- os eventos da Live Activity ---------- */

// A entrada de um evento: a da posição, quando ela ainda é o exercício do evento (o exId), ou a
// primeira com aquele exercício, como o entryIndexOf do lib/live-activity.js; -1 quando ele saiu do
// treino. Sem exId, vale a posição.
function entryOf(A, ev) {
  if (typeof ev.exId !== 'string') return isIndex(ev.entry, A.entries.length) ? ev.entry : -1
  if (isIndex(ev.entry, A.entries.length) && String(A.entries[ev.entry]?.id) === ev.exId) return ev.entry
  return A.entries.findIndex(e => String(e?.id) === ev.exId)
}

// Se o "Pular" tocado em at é deste descanso, como o restSkipApplies do lib/live-activity.js: a
// pausa de trocar de lado não se pula por ali, o descanso já acabado (o "Pronto") se pula, e um
// descanso que começou mais de 1 s depois do toque é outro.
function skipApplies(rest, at, now) {
  if (!isMap(rest) || !Number.isFinite(rest.endsAt) || rest.kind === 'switch') return false
  if (now >= rest.endsAt) return true
  const started = Number.isFinite(rest.total) ? rest.endsAt - rest.total * 1000 : null
  return started == null || started <= at + 1000
}

// A ação do controlador para um evento, ou null quando ele não quer dizer nada agora: a série que
// saiu do treino, o "Pular" de outro descanso, o tipo que não existe.
function actionOf(A, ev, at, now) {
  if (ev.kind === 'set.done') {
    const entry = entryOf(A, ev)
    if (entry < 0 || !isIndex(ev.set, list(A.entries[entry]?.sets).length)) return null
    return { type: 'set.mark', entry, set: ev.set, done: true }
  }
  if (ev.kind === 'rest.skip') return skipApplies(A.rest, at, now) ? { type: 'rest.skip' } : null
  if (ev.kind === 'rest.adjust') return ev.by === 15 || ev.by === -15 ? { type: 'rest.adjust', by: ev.by } : null
  return null
}

const sameRest = (a, b) => (!a && !b) || (!!a && !!b && a.endsAt === b.endsAt && a.total === b.total && a.kind === b.kind)

/**
 * Aplica os eventos dos botões da Live Activity no documento S, com o now do escoamento, e devolve
 * { doc, changed, applied, effects }. Cada evento é { id, wid, kind, entry?, set?, exId?, by?, at }:
 *   - vale uma vez só, pelo id, guardado nos últimos 64 de active.liveSeen; o de outro treino (o wid)
 *     ou sem treino é ignorado;
 *   - roda o controlador com o now igual ao at do toque, como o bindLiveActions do openGym
 *     (Workout.jsx:1965-1979): a série fica com o at do toque, e o descanso que ela começa conta dele;
 *   - set.done é o set.mark com done: true (Foco da revisão 3): numa série já feita, não muda nada.
 * Depois de todos, um descanso que os eventos começaram e que já acabou no now sai, como o
 * addRest(-late) do openGym (store/useUI.js:346), e o efeito do descanso é um só, do de antes para o
 * de agora, com o mesmo endsAt que o LiveAdvance agendou (Foco da revisão 1). O documento é carimbado
 * com o now, não com o at. O applied lista os ids que mudaram o treino.
 */
export function liveEvents(S, events, now) {
  if (!Array.isArray(events)) throw new TypeError('HexEngine: liveEvents: os eventos precisam ser uma lista')
  let doc = S
  const before = restNow(runningOf(S)?.rest, now)
  const applied = []
  const effects = []
  let moved = false
  for (const ev of events) {
    if (!isMap(ev) || typeof ev.id !== 'string') continue
    const A = runningOf(doc)
    if (!A || ev.wid !== String(A.id)) continue
    const seen = list(A.liveSeen)
    if (seen.includes(ev.id)) continue
    // O at vem do Swift com fração de ms (o Date em ms), e a série guarda ms inteiros, como o Date.now.
    const at = Number.isFinite(ev.at) ? Math.round(ev.at) : now
    const action = actionOf(A, ev, at, now)
    if (action) {
      let out = null
      try {
        out = step(doc, action, at)
      } catch (err) {
        // Um evento é dado, não ordem: um que o controlador recusa (uma série que não se marca num
        // treino estragado) não segura os outros da fila, e conta como visto.
        if (!(err instanceof TypeError)) throw err
      }
      if (out && out.state !== doc) {
        doc = out.state
        moved = true
        applied.push(ev.id)
        for (const e of out.effects) if (!e.type.startsWith('rest.') && !e.type.startsWith('activity.')) effects.push(e)
      }
    }
    const active = { ...doc.active, liveSeen: [...list(doc.active.liveSeen), ev.id].slice(-LIVE_SEEN_MAX) }
    doc = { ...doc, active }
  }
  if (doc === S) return { doc: S, changed: false, applied, effects: [] }

  const A = doc.active
  if (isMap(A.rest) && !sameRest(A.rest, runningOf(S)?.rest) && !(restNow(A.rest, now) && now < A.rest.endsAt)) {
    doc = { ...doc, active: { ...A, rest: null } }
  }
  const after = restNow(doc.active.rest, now)
  if (!sameRest(before, after)) effects.push(after ? { type: 'rest.started', endsAt: after.endsAt, total: after.total, kind: after.kind } : { type: 'rest.cleared' })
  if (moved) effects.push({ type: 'activity.update' })
  return { doc: stamped(S, doc, now), changed: true, applied, effects }
}
