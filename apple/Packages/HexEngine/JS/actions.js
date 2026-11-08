// As ações sobre o documento e as leituras das telas (seção 8.2 do design doc, Task 5 do plano da
// fase 2). Toda mudança é a do update() do store/useStore.js do openGym: um rascunho do documento
// (draftOf), a mudança nele e, se ela mudou alguma coisa, o carimbo (stampChange), que marca só o que
// mudou, para o documento continuar valendo no openGym e em outro aparelho. As regras são as do lib
// do openGym (routines.js, history.js, starter.js, units.js, favourites.js); aqui só ficam a
// conferência do que o Swift mandou e o caminho até elas. O runtime.js passa o documento aberto e
// troca o JSON com o Swift.
//
// Uma ação inválida lança TypeError antes de qualquer mudança chegar ao documento: o rascunho copia
// cada campo na primeira leitura e nunca escreve no documento de antes, então um erro no meio só
// joga o rascunho fora. O HexGym nunca grava theme, accent nem lang (seção 8.12 e escolha 4 do
// plano): o settings.set recusa as três.
import { clone, draftOf } from '../../../../frontend/src/lib/state-core.js'
import { highestStamp, markUndone, stampChange, undoMarks } from '../../../../frontend/src/lib/sync-merge.js'
import { copyRoutine, deleteRoutine, replaceSlotExercise, restoreRoutine, routineSnapshot } from '../../../../frontend/src/lib/routines.js'
import { NOTE_MAX, cleanupSg, effortOf, modeOf, pairAdjacent, pickedExerciseConfig, repStep, setsRepsOf, unpairSuperset } from '../../../../frontend/src/lib/history.js'
import { buildStarterPlan, starterPlanOptions } from '../../../../frontend/src/lib/starter.js'
import { convertStateUnit } from '../../../../frontend/src/lib/units.js'
import { favIds, toggleFav } from '../../../../frontend/src/lib/favourites.js'
import { loadOfRoutine } from '../../../../frontend/src/lib/muscles.js'
import { EXIDX, defaultIncrement } from '../../../../frontend/src/lib/exercises.js'
import { weightIncrement } from '../../../../frontend/src/lib/progression.js'
import { uid, weekOrder, weekStartOf } from '../../../../frontend/src/lib/format.js'
import { REST_MAX } from '../../../../frontend/src/lib/duration.js'
import { exerciseNameFor, t } from '../../../../frontend/src/lib/i18n-core.js'
import { DEFAULT_GLYPH, ROUTINE_GLYPHS, glyphStr } from '../../../../api/coach/core/glyphs.js'
import { sameWorkout } from '../../../../frontend/src/lib/workout-date.js'
import { keyText } from './workouts.js'

// Os limites do slot.update. O openGym não tem teto (o salvar da sheet só faz Math.max(1, ...)):
// estes são escolha recomendada, com a delegação do Lipe de 03/11/2026. Só um valor novo é
// conferido; um documento do openGym com um valor acima abre normalmente.
export const SLOT_LIMITS = { sets: [1, 20], reps: [1, 100], sec: [1, 3600], weight: [0, 1000] }

const isMap = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const list = v => (Array.isArray(v) ? v : [])
const isIndex = (i, length) => Number.isInteger(i) && i >= 0 && i < length

// O erro de uma ação inválida, sempre um TypeError com o tipo da ação.
function fail(type, why) {
  throw new TypeError(`HexEngine: ${type}: ${why}`)
}
function need(ok, type, why) {
  if (!ok) fail(type, why)
}

const text = (a, key) => {
  need(typeof a[key] === 'string', a.type, `${key} precisa ser texto`)
  return a[key]
}
const integer = (a, key) => {
  need(Number.isInteger(a[key]), a.type, `${key} precisa ser um número inteiro`)
  return a[key]
}

// A rotina do rascunho com o id pedido, ou o erro. Ler s.routines copia só as rotinas.
function routineIn(s, a, key = 'routineId') {
  const id = text(a, key)
  const r = list(s.routines).find(x => x?.id === id)
  if (!r) fail(a.type, `não existe a rotina ${id}`)
  if (!Array.isArray(r.ex)) r.ex = []
  return r
}
// O índice de um exercício da rotina.
function slotIndex(r, a, key = 'index') {
  const i = integer(a, key)
  need(isIndex(i, r.ex.length), a.type, `${key} ${i} fora da rotina, que tem ${r.ex.length}`)
  return i
}
// Um exercício que existe: do catálogo ou personalizado deste documento (registerCustom, runtime.js).
function exerciseId(type, id) {
  need(typeof id === 'string' && Object.hasOwn(EXIDX, id), type, `não existe o exercício ${String(id)}`)
  return id
}
// Tira um item de uma lista e põe na posição final to, como o reordenar do openGym
// (views/Plan.jsx, Routines).
function moveIn(items, from, to) {
  const [m] = items.splice(from, 1)
  items.splice(to, 0, m)
}

// O nome de uma rotina como o openGym grava: aparado, e o texto padrão quando fica vazio.
const routineName = (a, fallback) => text(a, 'name').trim() || t(fallback)

// O slot.update: cada campo com o tipo e o limite dele. Um campo que não está na lista lança.
const SLOT_FIELDS = {
  sets: v => Number.isInteger(v) && v >= SLOT_LIMITS.sets[0] && v <= SLOT_LIMITS.sets[1],
  reps: v => Number.isInteger(v) && v >= SLOT_LIMITS.reps[0] && v <= SLOT_LIMITS.reps[1],
  // O repsMin vai até o reps do slot, já com o reps novo quando ele vem junto (conferido em update).
  repsMin: v => Number.isInteger(v) && v >= 1,
  sec: v => Number.isInteger(v) && v >= SLOT_LIMITS.sec[0] && v <= SLOT_LIMITS.sec[1],
  weight: v => typeof v === 'number' && Number.isFinite(v) && v >= SLOT_LIMITS.weight[0] && v <= SLOT_LIMITS.weight[1],
  mode: v => v === 'reps' || v === 'time',
  note: v => typeof v === 'string' && v.trim().length <= NOTE_MAX,
}

function updateSlot(slot, a) {
  const fields = a.fields
  need(isMap(fields), a.type, 'fields precisa ser um objeto')
  for (const [k, v] of Object.entries(fields)) {
    need(Object.hasOwn(SLOT_FIELDS, k), a.type, `o campo ${k} não muda por aqui`)
    need(SLOT_FIELDS[k](v), a.type, `${k} fora do limite: ${JSON.stringify(v)}`)
  }
  const reps = fields.reps ?? slot.reps
  if ('repsMin' in fields) need(Number.isInteger(reps) && fields.repsMin <= reps, a.type, `repsMin ${fields.repsMin} acima do reps ${reps}`)
  for (const k of ['sets', 'reps', 'repsMin', 'sec', 'weight', 'mode']) if (k in fields) slot[k] = fields[k]
  // A nota como o salvar da sheet do openGym grava (sheets.jsx): aparada, e sem a chave quando vazia.
  if ('note' in fields) {
    const note = fields.note.trim()
    if (note) slot.note = note
    else delete slot.note
  }
  // Na troca de modo, o número que o modo novo pede, quando o slot não tem: o padrão do salvar da
  // sheet (45 s no tempo, 10 repetições).
  if (fields.mode === 'time' && !(slot.sec > 0)) slot.sec = 45
  if (fields.mode === 'reps' && !(slot.reps > 0)) slot.reps = 10
}

// Um ajuste do settings.set: o que o valor precisa ser.
const SETTINGS = {
  body: v => v === 'male' || v === 'female',
  weekStart: v => v === 0 || v === 1,
  restSec: v => Number.isInteger(v) && v >= 0 && v <= REST_MAX,
  effort: v => v === 'none' || v === 'rir' || v === 'rpe',
}
// O que o HexGym nunca grava no documento compartilhado: o tema e a cor ficam no aparelho (seção
// 8.12), e o idioma segue o do aparelho (escolha 4 do plano).
const NEVER = new Set(['theme', 'accent', 'lang'])

// Cada ação: o run muda o rascunho s e devolve o result; o prev é o documento de antes, que só se
// lê (ler o rascunho copia o campo, e o histórico inteiro não precisa ser copiado para nada aqui).
// O after, quando há, completa o result com o documento já carimbado.
const ACTIONS = {
  // A rotina nova como a do openGym (views/Plan.jsx, addRoutine), no fim da lista.
  'routine.create': {
    run(s, a) {
      const r = { id: uid(), name: routineName(a, 'New routine'), emoji: DEFAULT_GLYPH, ex: [] }
      s.routines = [...list(s.routines), r]
      return { id: r.id }
    },
  },
  // Vazio vira t('Routine'), como no editor do openGym (views/RoutineEdit.jsx).
  'routine.rename': {
    run(s, a) {
      routineIn(s, a, 'id').name = routineName(a, 'Routine')
    },
  },
  'routine.glyph': {
    run(s, a) {
      const glyph = text(a, 'glyph')
      need(ROUTINE_GLYPHS.includes(glyph), a.type, `o ícone ${glyph} não é um dos ROUTINE_GLYPHS`)
      routineIn(s, a, 'id').emoji = glyph
    },
  },
  // A cópia logo depois da original, com o nome do "Copiar rotina" (views/Plan.jsx, duplicate).
  'routine.duplicate': {
    run(s, a) {
      const r = routineIn(s, a, 'id')
      const copy = copyRoutine(r, t('Copy'))
      s.routines.splice(s.routines.indexOf(r) + 1, 0, copy)
      return { id: copy.id }
    },
  },
  'routine.move': {
    run(s, a) {
      const n = list(s.routines).length
      const from = integer(a, 'from'), to = integer(a, 'to')
      need(isIndex(from, n) && isIndex(to, n), a.type, `from ${from} ou to ${to} fora da lista, que tem ${n}`)
      moveIn(s.routines, from, to)
    },
  },
  // O apagar com desfazer do openGym (views/Plan.jsx, deleteRoutineWithUndo): o snapshot de antes, e
  // as marcas do que a remoção mexeu, lidas do documento já carimbado.
  'routine.delete': {
    run(s, a, prev) {
      const id = text(a, 'id')
      const snapshot = routineSnapshot(prev, id)
      if (!snapshot) fail(a.type, `não existe a rotina ${id}`)
      deleteRoutine(s, id)
      return { snapshot }
    },
    after(prev, S, result) {
      result.snapshot.marks = undoMarks(prev, S)
    },
  },
  // O desfazer do openGym (views/Plan.jsx, undoDeleteRoutine). Falso no restoreRoutine quer dizer
  // que a rotina já voltou por outro caminho, e nada muda.
  'routine.restore': {
    run(s, a) {
      const snap = a.snapshot
      need(isMap(snap) && isMap(snap.routine) && typeof snap.routine.id === 'string' && Number.isInteger(snap.index) &&
        isMap(snap.week) && Object.values(snap.week).every(Number.isInteger) && isMap(snap.dayPlan) &&
        Number.isInteger(snap.seqAt) && Number.isInteger(snap.queueAt), a.type, 'o snapshot não é o do routine.delete')
      const marks = snap.marks
      need(marks === undefined || (isMap(marks) && Object.values(marks).every(m => Array.isArray(m) && m.length === 3)),
        a.type, 'as marcas do snapshot não são as do undoMarks')
      if (restoreRoutine(s, snap) && marks) markUndone(s, marks)
    },
  },
  // Como o seletor do editor do openGym adiciona (views/RoutineEdit.jsx, addExercise).
  'slot.add': {
    run(s, a) {
      const r = routineIn(s, a)
      need(Array.isArray(a.exerciseIds) && a.exerciseIds.length > 0, a.type, 'exerciseIds precisa ser uma lista com algum exercício')
      const ids = a.exerciseIds.map(id => exerciseId(a.type, id))
      const at = a.at ?? r.ex.length
      need(Number.isInteger(at) && at >= 0 && at <= r.ex.length, a.type, `at ${at} fora da rotina, que tem ${r.ex.length}`)
      r.ex.splice(at, 0, ...ids.map(id => ({ id, ...pickedExerciseConfig(id) })))
      cleanupSg(r.ex)
    },
  },
  // Como o remover do editor (views/RoutineEdit.jsx, removeRoutineExercise): o par que fica sozinho
  // perde o superset.
  'slot.remove': {
    run(s, a) {
      const r = routineIn(s, a)
      r.ex.splice(slotIndex(r, a), 1)
      cleanupSg(r.ex)
    },
  },
  'slot.move': {
    run(s, a) {
      const r = routineIn(s, a)
      const from = slotIndex(r, a, 'from'), to = slotIndex(r, a, 'to')
      moveIn(r.ex, from, to)
      cleanupSg(r.ex)
    },
  },
  // O trocar exercício do editor (replaceSlotExercise), com o histórico do documento de antes.
  'slot.replace': {
    run(s, a, prev) {
      const r = routineIn(s, a)
      const i = slotIndex(r, a)
      r.ex[i] = replaceSlotExercise(r.ex[i], exerciseId(a.type, a.exerciseId), prev, r.id)
    },
  },
  // Junta o exercício com o seguinte (pairAdjacent); o nome e o descanso do superset seguem os
  // membros (cleanupSg).
  'slot.superset': {
    run(s, a) {
      const r = routineIn(s, a)
      const i = slotIndex(r, a)
      need(i + 1 < r.ex.length, a.type, `o exercício ${i} é o último, e não tem com quem juntar`)
      r.ex = pairAdjacent(r.ex, i, i + 1)
      cleanupSg(r.ex)
    },
  },
  'slot.unsuperset': {
    run(s, a) {
      const r = routineIn(s, a)
      r.ex = unpairSuperset(r.ex, slotIndex(r, a))
      cleanupSg(r.ex)
    },
  },
  'slot.update': {
    run(s, a) {
      const r = routineIn(s, a)
      updateSlot(r.ex[slotIndex(r, a)], a)
    },
  },
  // Um dia da semana fixa, como a folha do dia do openGym (sheets.jsx, DayAssign): uma lista de
  // rotinas, e o dia sai quando ela fica vazia (nunca []).
  'week.set': {
    run(s, a, prev) {
      const day = integer(a, 'day')
      need(day >= 0 && day <= 6, a.type, `day ${day} fora de 0 a 6`)
      need(Array.isArray(a.routineIds), a.type, 'routineIds precisa ser uma lista')
      const known = new Set(list(prev.routines).map(r => r?.id))
      for (const id of a.routineIds) need(typeof id === 'string' && known.has(id), a.type, `não existe a rotina ${String(id)}`)
      need(new Set(a.routineIds).size === a.routineIds.length, a.type, 'routineIds tem uma rotina repetida')
      s.week = isMap(s.week) ? s.week : {}
      if (a.routineIds.length) s.week[day] = [...a.routineIds]
      else delete s.week[day]
    },
  },
  // O loadStarterPlan do sheets.jsx, sem o perfil de equipamento (o sheets.jsx puxa o React e não
  // entra no motor): as rotinas iguais de antes (mesmo nome e mesmos exercícios) são reaproveitadas,
  // e só os dias do plano mudam. Os nomes ficam em inglês, como no openGym (lib/starter.js). O
  // result diz quantas rotinas entraram de novo.
  'plan.starter': {
    run(s, a) {
      const plan = buildStarterPlan(text(a, 'planId'))
      if (!plan) fail(a.type, `não existe o plano ${a.planId}`)
      s.routines = list(s.routines)
      s.week = isMap(s.week) ? s.week : {}
      const idOf = {}
      let added = 0
      const sameLift = (x, y) => list(x.ex).length === y.ex.length && y.ex.every((e, i) => e.id === x.ex[i]?.id)
      for (const r of plan.routines) {
        const have = s.routines.find(x => x?.name === r.name && sameLift(x, r))
        if (have) idOf[r.id] = have.id
        else { s.routines.push(r); idOf[r.id] = r.id; added++ }
      }
      for (const { day, routineId } of plan.schedule) s.week[day] = [idOf[routineId]]
      return { routines: added }
    },
  },
  'settings.set': {
    run(s, a) {
      const key = text(a, 'key')
      need(!NEVER.has(key), a.type, `o HexGym não grava ${key} no documento`)
      need(Object.hasOwn(SETTINGS, key), a.type, `o ajuste ${key} não muda por aqui`)
      need(SETTINGS[key](a.value), a.type, `${key} não aceita ${JSON.stringify(a.value)}`)
      s[key] = a.value
    },
    // A unidade não passa pelo rascunho: é o setUnit do store/useStore.js do openGym, que converte
    // todo peso guardado (convertStateUnit) e marca a escolha no unitSet, sem o stampChange; a
    // sincronização junta duas cópias em unidades diferentes por ele (lib/sync-merge.js).
    whole(prev, a, now) {
      if (a.key !== 'unit') return null
      need(a.value === 'kg' || a.value === 'lb', a.type, `unit não aceita ${JSON.stringify(a.value)}`)
      if ((prev.unit || 'kg') === a.value) return { doc: prev, changed: false, result: {} }
      const doc = convertStateUnit(prev, a.value)
      doc.unitSet = { at: Math.max(Number(now) || 0, highestStamp(prev) + 1), convert: true }
      return { doc, changed: true, result: {} }
    },
  },
  // O "Apagar treino" do detalhe do openGym (sheets.jsx:2931): o treino sai pelo sameWorkout, e não
  // pelo id, porque um treino antigo não tem id, e comparar o id levava junto todos os outros sem id
  // (o comentário do sheets.jsx:2929). A key é a do workouts.js, o id ou o legacySyncKey. O carimbo do
  // apply registra a remoção no deleted.workouts, para a sincronização não trazer o treino de volta.
  'workout.delete': {
    run(s, a, prev) {
      const key = text(a, 'key')
      const target = list(prev.workouts).find(w => isMap(w) && keyText(w) === key)
      if (!target) fail(a.type, `não existe o treino ${key}`)
      s.workouts = s.workouts.filter(x => !sameWorkout(x, target))
    },
  },
  // O favorito da biblioteca (toggleFav). Um id que não existe mais só pode sair dos favoritos.
  'favourite.toggle': {
    run(s, a, prev) {
      const id = text(a, 'id')
      need(Object.hasOwn(EXIDX, id) || favIds(prev).includes(id), a.type, `não existe o exercício ${id}`)
      toggleFav(s, id)
    },
  },
}

// Se o rascunho saiu diferente do documento de antes. O campo que a ação nem leu continua o mesmo
// objeto (draftOf), e só os lidos são comparados pelo texto.
function changedFrom(prev, S) {
  for (const k of new Set([...Object.keys(prev), ...Object.keys(S)])) {
    if (prev[k] === S[k]) continue
    if (!(k in prev) || !(k in S) || JSON.stringify(prev[k]) !== JSON.stringify(S[k])) return true
  }
  return false
}

// Roda a ação no documento prev e devolve { doc, changed, result }: o documento novo, carimbado como
// o update() do openGym carimba (S._ts = stampChange(prev, S, now)), ou o mesmo prev quando nada
// mudou. Uma ação inválida lança TypeError, e o prev fica como estava.
export function apply(prev, action, now) {
  need(isMap(action) && typeof action.type === 'string', 'apply', 'a ação precisa ser um objeto com type')
  need(Object.hasOwn(ACTIONS, action.type), 'apply', `não existe a ação ${action.type}`)
  need(typeof now === 'number' && Number.isFinite(now), action.type, 'now precisa ser um número')
  const spec = ACTIONS[action.type]
  const whole = spec.whole?.(prev, action, now)
  if (whole) return whole
  const draft = draftOf(prev)
  const result = spec.run(draft.S, action, prev) ?? {}
  const S = draft.done()
  if (!changedFrom(prev, S)) return { doc: prev, changed: false, result }
  // Os carimbos escrevem nesses dois mapas no lugar; um rascunho que não os tocou ainda os divide
  // com o documento de antes (store/useStore.js, update).
  for (const k of ['deleted', 'edited']) if (isMap(S[k]) && S[k] === prev[k]) S[k] = clone(S[k])
  S._ts = stampChange(prev, S, now)
  spec.after?.(prev, S, result)
  return { doc: S, changed: true, result }
}

// Um número inteiro do documento para o Swift, que decodifica Int: arredondado, ou null.
const int = v => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : null)
const num = v => (typeof v === 'number' && Number.isFinite(v) ? v : null)

// O passo da carga de um slot na unidade do perfil: o inc do slot no modo de repetições, como a
// sessão do openGym (lib/session-start.js); no de tempo o inc é de segundos, e vale o padrão.
const incrementOf = (slot, unit) => (modeOf(slot) === 'reps' ? weightIncrement(slot, unit) : defaultIncrement(slot.id, unit))

function slotSummary(slot, unit) {
  const known = typeof slot?.id === 'string' && Object.hasOwn(EXIDX, slot.id)
  return {
    id: String(slot?.id ?? ''),
    // Um exercício que não existe mais é o "Exercício desconhecido" do openGym (exOr), e não derruba
    // a tela (Foco da revisão 1).
    name: known ? exerciseNameFor(EXIDX[slot.id]) : t('Unknown exercise'),
    known,
    setsReps: setsRepsOf(slot),
    increment: incrementOf(slot, unit),
    // O passo das repetições: de 2 em 2 num exercício por lado, como o Stepper da sheet do openGym.
    repStep: repStep(slot),
    sets: int(slot.sets), reps: int(slot.reps), repsMin: int(slot.repsMin), weight: num(slot.weight), sec: int(slot.sec),
    mode: modeOf(slot),
    note: typeof slot.note === 'string' ? slot.note : null,
    superset: typeof slot.sg === 'string' && slot.sg ? slot.sg : null,
  }
}

// Os dias da semana em que uma rotina está, na ordem da semana do perfil.
const daysOf = (S, id) => weekOrder(weekStartOf(S)).filter(d => [].concat(S.week?.[d] ?? []).includes(id))

// As rotinas para as telas: o ícone pelo glyphStr (um emoji antigo passa como está), os exercícios,
// a carga de cada grupo muscular (loadOfRoutine) e os dias da semana.
export function routines(S) {
  const unit = S.unit === 'lb' ? 'lb' : 'kg'
  return list(S.routines).filter(isMap).map(r => ({
    id: String(r.id),
    name: typeof r.name === 'string' ? r.name : '',
    glyph: glyphStr(r.emoji),
    slots: list(r.ex).filter(isMap).map(slot => slotSummary(slot, unit)),
    muscles: loadOfRoutine({ ...r, ex: list(r.ex).filter(isMap) }),
    days: daysOf(S, r.id),
  }))
}

// A semana fixa, os sete dias na ordem do perfil. Um id que não é mais rotina fica de fora, como o
// openGym mostra o dia dele como descanso.
export function week(S) {
  const weekStart = weekStartOf(S)
  const known = new Set(list(S.routines).map(r => r?.id))
  return {
    weekStart,
    days: weekOrder(weekStart).map(day => ({ day, routineIds: [].concat(S.week?.[day] ?? []).filter(id => known.has(id)) })),
  }
}

// Os ajustes que as telas mostram, como o openGym os lê.
export function settings(S) {
  return {
    unit: S.unit === 'lb' ? 'lb' : 'kg',
    body: S.body === 'female' ? 'female' : 'male',
    weekStart: weekStartOf(S),
    restSec: int(S.restSec) ?? 90,
    effort: effortOf(S),
  }
}

export function starterPlans() {
  return starterPlanOptions()
}
