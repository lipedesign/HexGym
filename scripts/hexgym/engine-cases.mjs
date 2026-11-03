// Os casos de contrato do motor (seção 8.2 do design doc e Foco da revisão 5 do plano da fase 0):
// chamadas a funções de frontend/src/lib cuja resposta depende só dos argumentos e do fuso. O
// scripts/hexgym/record-engine-cases.mjs roda cada caso no Node, num processo por fuso de
// TIME_ZONES, e grava o que o código do openGym respondeu; o RecordedCasesTests.swift roda os
// mesmos casos no JavaScriptCore, pelo script do motor, e confere que a resposta é a mesma.
//
// Cada caso é { name, fn, args, ignore? }. O fn é "<caminho do módulo>#<export>", o nome que o call
// do motor recebe (apple/Packages/HexEngine/JS/runtime.js); o args é a lista dos argumentos, com
// datas e undefined, que o gravador passa pelo encodeValue; e o ignore lista os caminhos da
// resposta ({ returned, args }) que a função gera e que ficam fora da comparação, como "returned.id".
//
// As cinco sessões de treino ficam no relógio de cada fuso, então o mesmo horário é um instante
// diferente em cada um. Cada uma cai num ponto difícil: a meia-noite, e a ida e a volta do horário
// de verão em Zurique e em Auckland (São Paulo não tem horário de verão).
//
// Node 22, sem dependências. O buildCases(load) importa os módulos pelo load, que o gravador dá:
// load(caminho) importa um módulo de frontend/src/lib, pelo caminho a partir da raiz.

export const TIME_ZONES = ['America/Sao_Paulo', 'Europe/Zurich', 'Pacific/Auckland']

const LIB = 'frontend/src/lib/'
const HOUR = 3600000

// [ano, mês, dia, hora, minuto], no relógio do fuso do processo.
const SESSIONS = [
  { name: 'que cruza a meia-noite', from: [2026, 10, 24, 23, 30], to: [2026, 10, 25, 0, 40] },
  { name: 'da volta do horário de verão em Zurique', from: [2026, 10, 25, 1, 30], to: [2026, 10, 25, 3, 30] },
  { name: 'da ida do horário de verão em Zurique', from: [2026, 3, 29, 1, 30], to: [2026, 3, 29, 3, 30] },
  { name: 'da volta do horário de verão em Auckland', from: [2026, 4, 5, 1, 30], to: [2026, 4, 5, 3, 30] },
  { name: 'da ida do horário de verão em Auckland', from: [2026, 9, 27, 1, 30], to: [2026, 9, 27, 3, 30] },
]
const instant = ([year, month, day, hour, minute]) => new Date(year, month - 1, day, hour, minute).getTime()

// A rotina das cinco sessões, com dois exercícios do catálogo, o supino reto e o agachamento. Duas
// séries em cada bastam para os casos, e cada série a mais pesa nos arquivos gravados, que vão
// inteiros no diff do PR.
const ROUTINE = {
  id: 'rotina-1', name: 'Supino e agachamento',
  ex: [{ id: '0025', sets: 2, reps: 8, weight: 60 }, { id: '0043', sets: 2, reps: 5, weight: 100 }],
}

export async function buildCases(load) {
  const [stateCore, format, sessionMerge, finish, history, syncMerge, onerm] = await Promise.all(
    ['state-core', 'format', 'session-merge', 'finish-workout', 'history', 'sync-merge', 'onerm'].map(m => load(`${LIB}${m}.js`)))
  const { freshState, clone } = stateCore
  const { isoOf } = format
  const S = { ...freshState('en'), routines: [ROUTINE] }

  // A sessão como o beginWorkout a monta (frontend/src/sheets.jsx:3120-3135), com um id e um começo
  // dados, como os do Apple Watch: as entries de buildCombinedEntries(S, [rotina.id]) e os campos de
  // active. O id é fixo, para o arquivo sair igual a cada gravação. Todas as séries ficam feitas,
  // como o toggle de views/Workout.jsx as marca (done e at), uma a cada intervalo igual da sessão.
  const sessions = SESSIONS.map((session, i) => {
    const start = instant(session.from), end = instant(session.to)
    const { entries, routineIds, routines } = sessionMerge.buildCombinedEntries(S, [ROUTINE.id])
    const sets = entries.flatMap(e => e.sets)
    sets.forEach((set, k) => {
      set.done = true
      set.at = start + Math.round(((end - start) * (k + 1)) / (sets.length + 1))
    })
    const active = {
      id: `treino-${i + 1}`, d: isoOf(new Date(start)), start, routineIds,
      name: sessionMerge.deriveSessionName(routines.map(r => r.name)),
      bw: null, cur: 0, entries, workoutView: S.workoutView || 'cards',
    }
    return { ...session, label: `sessão ${i + 1}, ${session.name}`, start, end, active }
  })
  const finished = sessions.map(s => finish.buildCompletedWorkout(s.active, { end: s.end }))

  const fn = (file, name) => `${LIB}${file}#${name}`
  const cases = []
  const add = (name, file, exported, args, ignore) => cases.push({ name, fn: fn(file, exported), args, ...(ignore ? { ignore } : {}) })

  // O primeiro uso igual ao do app web, e o que a restauração guarda.
  for (const tag of ['pt-BR', 'ar-EG']) add(`documento novo em ${tag}`, 'state-core.js', 'freshState', [tag])
  add('cópia salva com uma chave desconhecida e sem lang', 'state-core.js', 'stateFromSaved',
    [{ chaveDoFuturo: { x: [1, 2] }, unit: 'lb', restSec: 120 }, 'ar-EG'])

  // O dia de cada instante no fuso, a semana que começa no domingo e na segunda, e o texto relativo.
  for (const s of sessions) {
    add(`dia do começo da ${s.label}`, 'format.js', 'isoOf', [new Date(s.start)])
    add(`dia do fim da ${s.label}`, 'format.js', 'isoOf', [new Date(s.end)])
  }
  for (const s of sessions) {
    for (const ws of [0, 1]) add(`semana do dia da ${s.label}, começando ${ws ? 'na segunda' : 'no domingo'}`, 'format.js', 'weekKey', [isoOf(new Date(s.start)), ws])
  }
  for (const s of sessions) add(`tempo da ${s.label}`, 'format.js', 'fmtAgo', [s.start, s.end])

  // As séries e os recordes de cada sessão terminada. O id do treino vem da sessão, que o app gera.
  for (const s of sessions) add(`treino terminado da ${s.label}`, 'finish-workout.js', 'buildCompletedWorkout', [s.active, { end: s.end }], ['returned.id'])

  // O dia local de um começo perto da meia-noite ou da troca de horário, e o meio-dia local de um dia.
  for (const s of sessions) add(`dia do treino só com o começo da ${s.label}`, 'history.js', 'workoutDay', [{ start: s.start }])
  for (const s of sessions) add(`meio-dia do treino só com o dia da ${s.label}`, 'history.js', 'workoutAt', [{ d: isoOf(new Date(s.start)) }])

  // A fadiga dos cinco treinos só com o dia, contada do meio-dia local, 36 h depois do último.
  const byDay = finished.map(({ start, end, ...w }) => w).sort((a, b) => (a.d < b.d ? -1 : a.d > b.d ? 1 : 0))
  add('fadiga dos cinco treinos 36 h depois do último', 'recovery.js', 'fatigueOf', [byDay, history.workoutAt(byDay.at(-1)) + 36 * HOUR])

  // O horário de cada campo numa série mudada, e a junção de duas cópias que mudaram campos diferentes,
  // com o treino da primeira sessão só com o primeiro exercício: o que os dois casos prendem são os
  // carimbos, e o treino aparece várias vezes em cada um.
  const first = sessions[0], logged = { ...finished[0], entries: finished[0].entries.slice(0, 1), _ts: first.end }
  const prev = { _ts: first.end, workouts: [logged] }
  const next = clone(prev)
  next.workouts[0].entries[0].sets[0].r = 6
  syncMerge.stampWorkout(next.workouts[0], first.end + HOUR)
  add('carimbo de uma série mudada', 'sync-merge.js', 'stampChange', [prev, next, first.end + HOUR])

  const change = (from, wall, edit) => {
    const copy = clone(from)
    edit(copy)
    copy._ts = syncMerge.stampChange(from, copy, wall)
    return copy
  }
  const base = { _ts: first.end, restSec: 90, routines: [{ ...ROUTINE, _ts: first.start }], workouts: [logged] }
  const phone = change(base, first.end + HOUR, s => { s.restSec = 120 })
  const web = change(base, first.end + 2 * HOUR, s => {
    s.workouts[0].note = 'ombro doeu'
    syncMerge.stampWorkout(s.workouts[0], first.end + 2 * HOUR)
  })
  add('mesclagem de duas cópias que mudaram campos diferentes', 'sync-merge.js', 'mergeStates', [phone, web])

  // As contas puras do 1RM, e cada fórmula com a mesma série.
  for (const [w, r] of [[100, 5], [60, 12], [140, 1]]) add(`1RM de ${w} x ${r}`, 'onerm.js', 'estimate1RM', [w, r])
  for (const formula of Object.keys(onerm.FORMULAS)) add(`1RM de 80 x 8 pela fórmula ${formula}`, 'onerm.js', 'estimate1RM', [80, 8, formula])

  return cases
}
