// O histórico no documento aberto: a lista dos treinos feitos e o detalhe de um (seção 9 do design
// doc, Task 5 do plano da fase 3). Os números são os das funções do openGym que a linha da lista e o
// detalhe de lá usam (o WorkoutRow e o WorkoutDetail do sheets.jsx): a duração pelo workoutDuration,
// as séries pelo setsDone e pelo workSetsDone, o volume pelo sessionVolume, as linhas pelo setLabel e
// pelo hrLabel, e os nomes pelo exerciseNameFor. Apagar um treino é a ação workout.delete do
// actions.js. Cada função recebe o documento, e o runtime.js passa o aberto e troca o JSON com o
// Swift.
//
// Cada treino tem uma chave, a do sameWorkout do openGym: o id, ou o legacySyncKey quando o treino é
// antigo e não tem id (o keyOf do session.js, que o último treino do Início também usa). Para o Swift,
// a chave vai sempre em texto, como a sincronização a guarda (o entryKey do lib/sync-merge.js).
import { setLabel, setsDone, sessionVolume, workSetsDone, workoutDay, workoutDuration, bestWeightForEntry } from '../../../../frontend/src/lib/history.js'
import { hasCompletedWork, isSideSet, isWarmupRow } from '../../../../frontend/src/lib/workout-model.js'
import { hrLabel } from '../../../../frontend/src/lib/heart-rate.js'
import { speedUnitOf } from '../../../../frontend/src/lib/speed.js'
import { fmtNum } from '../../../../frontend/src/lib/format.js'
import { byNewest, groupOf, keyText, knownEx, lineOf, nameOf, supersetLetters } from './session.js'

const isMap = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const list = v => (Array.isArray(v) ? v : [])
const num = v => (typeof v === 'number' && Number.isFinite(v) ? v : null)

export { keyOf, keyText } from './session.js'

// O treino com as entradas e as séries que as funções do openGym leem sem conferir (o setsDone lê
// w.entries e e.sets direto), para um treino estragado de outro aparelho não derrubar a tela. Sem
// entradas, o treino continua sem elas: o sessionVolume lê então o vol guardado, como no openGym.
function readable(w) {
  if (!Array.isArray(w.entries)) return w
  return { ...w, entries: w.entries.filter(isMap).map(e => ({ ...e, sets: list(e.sets).filter(isMap) })) }
}
const entriesOf = w => list(readable(w).entries)

// Os treinos do documento que dão para ler, do mais novo para o mais antigo (byNewest, a ordem do
// último treino do Início).
const ordered = S => byNewest(list(S.workouts).filter(isMap))

// Os recordes do treino, os ids dos exercícios que o fim do treino gravou no prs.
const prsOf = w => list(w.prs).filter(x => typeof x === 'string' || typeof x === 'number').map(String)
const unitOf = S => (S.unit === 'lb' ? 'lb' : 'kg')

function summary(S, w) {
  const r = readable(w)
  const counted = { entries: entriesOf(w) }
  return {
    key: keyText(w),
    id: w.id != null ? String(w.id) : null,
    d: workoutDay(w),
    name: typeof w.name === 'string' ? w.name : '',
    start: num(w.start),
    end: num(w.end),
    durationMs: workoutDuration(w),
    // As séries feitas, como a linha do openGym (o setsDone, com o aquecimento), e as de trabalho
    // (o workSetsDone), como o resumo do fim do treino.
    sets: { done: setsDone(counted), work: workSetsDone(counted) },
    volume: sessionVolume(r, S),
    unit: unitOf(S),
    prs: prsOf(w),
  }
}

// O limit de uma página: um inteiro de 1 para cima.
function limitOf(q) {
  if (!Number.isInteger(q?.limit) || q.limit < 1) throw new TypeError(`HexEngine: history: limit precisa ser um inteiro de 1 para cima, veio ${JSON.stringify(q?.limit)}`)
  return q.limit
}

// O fim da sequência de treinos vizinhos com a mesma chave que começa em i: o índice do último deles.
function runEnd(all, i) {
  const key = keyText(all[i])
  while (i + 1 < all.length && keyText(all[i + 1]) === key) i++
  return i
}

/**
 * Uma página do histórico, do mais novo para o mais antigo: os limit treinos depois do de chave
 * before (ou do começo, sem before), e se há mais depois deles. Um before que não é a chave de nenhum
 * treino lança TypeError (o treino saiu do histórico, apagado aqui ou em outro aparelho): a tela lê
 * de novo do começo.
 *
 * Dois treinos com a mesma chave (dois antigos com o mesmo dia e começo, ou um id 5 e um "5") são o
 * mesmo treino para o sameWorkout do openGym, e o before não diz qual deles foi o último da página.
 * Por isso a página nunca corta no meio de treinos vizinhos com a mesma chave: o corte estica até o
 * último deles, e o before continua depois dele. Quando os dois não são vizinhos, o before vale pelo
 * primeiro com a chave: a página seguinte pode repetir treinos que já vieram (a tela tira as chaves
 * que já tem), mas nunca pula um.
 */
export function history(S, query) {
  if (!isMap(query)) throw new TypeError('HexEngine: history: a consulta precisa ser um objeto')
  const limit = limitOf(query)
  const all = ordered(S)
  let from = 0
  if (query.before != null) {
    const before = String(query.before)
    const at = all.findIndex(w => keyText(w) === before)
    if (at < 0) throw new TypeError(`HexEngine: history: não existe o treino ${before}`)
    from = runEnd(all, at) + 1
  }
  const to = from + limit <= all.length ? runEnd(all, from + limit - 1) + 1 : all.length
  return { items: all.slice(from, to).map(w => summary(S, w)), more: to < all.length }
}

// A linha de uma série feita no detalhe: a do treino em andamento ("60 kg × 8", o lineOf do
// session.js) e, depois dela, o que o detalhe do openGym escreve depois da carga (sheets.jsx:2808):
// a falha ("F") e o esforço ("(RIR 2)") que o setLabel põe atrás de "60×8", e o batimento do Apple
// Watch do hrLabel ("♥ 132/151"). Quando a linha já é a do setLabel (lados, drop set, rest-pause,
// peso do corpo, halter, tempo, cardio), ela vem inteira de lá.
function lineFor(S, e, s) {
  const line = lineOf(S, e, s)
  let label = ''
  try {
    label = setLabel(e.id, s, e.target, speedUnitOf(S))
  } catch {
    // Uma série que o setLabel não lê fica só com a linha.
  }
  const head = `${fmtNum(s.w || 0)}×${s.r || 0}`
  const tail = line !== label && label.startsWith(head) ? label.slice(head.length) : ''
  return line + tail + hrLabel(s)
}

// As cargas feitas de uma série: os dois lados de uma série com lados, ou a carga dela.
const loadsOf = s => (isSideSet(s) ? [s.sides.L, s.sides.R].filter(x => x?.done === true).map(x => Number(x.w)) : [Number(s.w)])

// A série do recorde de uma entrada, pelo índice nas séries dela, ou -1: num exercício dos prs, a
// primeira série de trabalho feita com a melhor carga do treino (bestWeightForEntry, a que o fim do
// treino grava no exWeights). O openGym marca só o exercício; a série é a que levou a carga do
// recorde. Um treino antigo que só tem o topW não tem série marcada, e o exercício continua marcado.
function recordSetOf(e, prs) {
  if (!prs.includes(String(e.id))) return -1
  const best = bestWeightForEntry(e)
  return e.sets.findIndex(s => !isWarmupRow(s) && hasCompletedWork(s) && loadsOf(s).includes(best))
}

/**
 * O detalhe de um treino pela chave, ou null quando não há treino com ela. As séries são as feitas,
 * como o detalhe do openGym mostra (sheets.jsx:2808, o filter(hasCompletedWork)); o done de uma série
 * com lados é falso quando só um lado foi feito. Um exercício que não existe neste aparelho sai com
 * known: false e o "Exercício desconhecido" (o openGym mostra o id dele; Foco da revisão 5). O pr da
 * entrada é o selo do exercício no openGym (w.prs.includes(e.id)), e o da série é a série do recorde
 * (recordSetOf).
 */
export function workoutDetail(S, key) {
  const k = String(key)
  const w = list(S.workouts).find(x => isMap(x) && keyText(x) === k)
  if (!w) return null
  const prs = prsOf(w)
  const entries = entriesOf(w)
  const letters = supersetLetters(entries)
  return {
    key: keyText(w),
    name: typeof w.name === 'string' ? w.name : '',
    d: workoutDay(w),
    start: num(w.start),
    end: num(w.end),
    durationMs: workoutDuration(w),
    volume: sessionVolume(readable(w), S),
    unit: unitOf(S),
    // O peso do corpo do treino, que o cabeçalho do detalhe do openGym mostra.
    bw: num(w.bw) && w.bw > 0 ? w.bw : null,
    note: typeof w.note === 'string' && w.note.trim() ? w.note : null,
    prs,
    entries: entries.map((e, index) => {
      const record = recordSetOf(e, prs)
      return {
        id: String(e.id ?? ''),
        name: nameOf(e.id),
        known: knownEx(e.id),
        sg: groupOf(e),
        sgLetter: letters.get(index) ?? null,
        pr: prs.includes(String(e.id)),
        sets: e.sets.flatMap((s, i) => (hasCompletedWork(s) ? [{ line: lineFor(S, e, s), done: s.done === true, warmup: isWarmupRow(s), pr: i === record }] : [])),
      }
    }),
  }
}
