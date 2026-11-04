#!/usr/bin/env node
// O teste de carga do motor do HexGym (seções 8.2 e 8.13 do design doc): o script do motor no
// JavaScriptCore do macOS, sem JIT, como o iPhone o roda, com um histórico grande, de 1.040 treinos
// (cinco anos de quatro treinos por semana).
//
//   node scripts/hexgym/engine-load.mjs                    # 1.040 treinos, quatro por semana
//   node scripts/hexgym/engine-load.mjs --workouts 2000    # outro tamanho
//   node scripts/hexgym/engine-load.mjs --lang de-CH       # com o pacote de outro idioma (pt-BR sem ele)
//   HEXGYM_LOAD_SLACK=2 node scripts/hexgym/engine-load.mjs   # as duas metas vezes 2, como na CI
//
// O histórico é montado no Node, com padHistory(buildDemoState(), total). Depois vêm cinco rodadas do
// jsc --useJIT=false, um processo novo em cada, com o script do motor descomprimido (o jsc não
// descomprime) num arquivo temporário, que sai no fim, e os dois pacotes de idioma que o load() do
// Swift carrega (o en e o do idioma, de Resources/langs), também descomprimidos. Cada rodada mede com
// o preciseTime() do jsc:
//   evaluate         avaliar o script, pelo load() do jsc;
//   idioma           ler os dois pacotes e o HexEngine.setLanguage deles;
//   restore          o HexEngine.restore do documento;
//   tick             a mediana de 20 séries marcadas, cada uma como o update() do app web faz;
//   fatigue          o fatigueOf do histórico, só para registro;
//   structuredClone  se a cópia de um objeto com Date, Map, Set e referência circular é igual ao
//                    original e não é o mesmo objeto.
// A tabela usa a mediana das cinco rodadas em cada tempo, e o structuredClone precisa dar certo nas
// cinco. As metas são do tech lead, a partir da seção 8.13 (o app abre em menos de 1 s e a série
// aparece em menos de 100 ms), com folga de três vezes para um iPhone mais lento que este Mac:
// evaluate + idioma + restore até 300 ms e tick até 30 ms. Fora delas, o script sai com 1. A
// descompressão dos pacotes, que no app é do Swift, fica fora da medida do jsc.
//
// Chamado pelo scripts/hexgym/check.mjs, na parte load, ele grava no arquivo que o check.mjs passa
// em HEXGYM_CHECK_COUNT_FILE quantas metas conferiu e quantas passaram, para a parte contar os
// testes dela.
//
// Node 22, sem dependências. Importar este arquivo não roda nada.

import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import zlib from 'node:zlib'
import { buildDemoState } from '../../frontend/src/lib/demoSeed.js'
import { readEngine } from '../build-hexgym-engine.mjs'
import { LANGS_DIR } from '../build-hexgym-langs.mjs'

// O caminho de verdade deste arquivo, sem links, como no check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const ROOT = path.join(path.dirname(SELF), '..', '..')

export const JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'
const RUNS = 5
const TICKS = 20
// Cinco anos de quatro treinos por semana.
const WORKOUTS = 1040
// O idioma da medida, sem o --lang: o do founder.
const LANG = 'pt-BR'
// As metas, em ms, e o que o teste confere, na ordem da tabela.
const OPEN_MS = 300
const TICK_MS = 30
const METAS = ['evaluate + idioma + restore', 'tick', 'structuredClone']
// A variável em que o check.mjs passa o arquivo da conta (o COUNT_FILE de lá).
const COUNT_FILE = 'HEXGYM_CHECK_COUNT_FILE'

const DAY = 86400000
// Um dia em ISO (AAAA-MM-DD) como o número de dias desde 1970, sem fuso, e de volta.
const dayNumber = iso => Date.UTC(Number(iso.slice(0, 4)), Number(iso.slice(5, 7)) - 1, Number(iso.slice(8, 10))) / DAY
const isoOfDay = n => new Date(n * DAY).toISOString().slice(0, 10)
// O mesmo instante n dias antes, na mesma hora do relógio daqui, como o app vê a hora de um treino.
const daysBefore = (ms, n) => {
  const t = new Date(ms)
  t.setDate(t.getDate() - n)
  return t.getTime()
}
const byTime = (a, b) => (a.d === b.d ? (a.start || 0) - (b.start || 0) : a.d < b.d ? -1 : 1)

// Um treino copiado n dias para trás, com outro id: d, start e end recuam, e o resto fica igual.
function copied(w, days, id) {
  const c = { ...structuredClone(w), id, d: isoOfDay(dayNumber(w.d) - days) }
  if (Number.isFinite(w.start)) c.start = daysBefore(w.start, days)
  if (Number.isFinite(w.end)) c.end = daysBefore(w.end, days)
  return c
}

// O estado com total treinos: os de S e, antes deles, cópias deles para trás, uma semana por vez. O
// histórico de S é tomado como um bloco de semanas (de segunda a domingo), e o bloco se repete para
// trás: a semana antes da mais antiga leva a cópia da mais nova do bloco, a semana antes dessa leva
// a da penúltima, e assim por diante, até o total, voltando ao fim do bloco quando ele acaba. Numa
// semana que não cabe inteira, entram os treinos mais novos dela. Cada cópia leva o id do treino com
// as semanas que recuou. Com total menor que o histórico, ficam os treinos mais novos. A ordem é a
// do app, do mais antigo ao mais novo, e o S que entra não muda. No ritmo do demo, de uns três
// treinos por semana, os 1.040 cobrem mais de cinco anos; o que o teste de carga mede é o total.
export function padHistory(S, total) {
  if (!Number.isInteger(total) || total < 1) throw new RangeError(`padHistory: o total precisa ser um inteiro maior que zero (veio ${total})`)
  const own = Array.isArray(S?.workouts) ? S.workouts : []
  if (!own.length) throw new Error('padHistory: o estado não tem nenhum treino para copiar')
  if (total <= own.length) return { ...S, workouts: own.slice(own.length - total) }
  const first = Math.min(...own.map(w => dayNumber(w.d)))
  const monday = first - ((new Date(first * DAY).getUTCDay() + 6) % 7)
  const weekOf = w => Math.floor((dayNumber(w.d) - monday) / 7)
  const span = Math.max(...own.map(weekOf)) + 1
  const weeks = Array.from({ length: span }, (_, i) => own.filter(w => weekOf(w) === i).sort(byTime))
  const copies = []
  for (let back = 1; own.length + copies.length < total; back++) {
    const weeksBack = span * Math.ceil(back / span)
    const week = weeks[span - 1 - ((back - 1) % span)]
    for (const w of [...week].reverse()) {
      if (own.length + copies.length === total) break
      copies.push(copied(w, weeksBack * 7, `${w.id}-${weeksBack}`))
    }
  }
  return { ...S, workouts: [...copies.sort(byTime), ...own] }
}

// Com uma casa decimal, sem zero sobrando: 350, 31, 300.4.
const round = v => Math.round(v * 10) / 10

// O que passou das metas, uma linha por meta, vazio quando tudo cabe. O slack multiplica as duas
// metas de tempo. Um tempo que não é número conta como fora.
export function overBudget(results, slack = 1) {
  const over = []
  const open = results.evaluate + results.language + results.restore
  if (!(open <= OPEN_MS * slack)) over.push(`evaluate + idioma + restore: ${round(open)} ms (meta ${round(OPEN_MS * slack)})`)
  if (!(results.tick <= TICK_MS * slack)) over.push(`tick: ${round(results.tick)} ms (meta ${round(TICK_MS * slack)})`)
  if (results.structuredClone !== true) over.push('structuredClone diferente no JavaScriptCore')
  return over
}

const median = xs => {
  const s = [...xs].sort((a, b) => a - b)
  const h = s.length >> 1
  return s.length % 2 ? s[h] : (s[h - 1] + s[h]) / 2
}

// O que cada rodada do jsc roda. Esta função não roda no Node: o texto dela vai para o jsc, que a
// chama com os caminhos do script e do documento, o número de séries, os caminhos dos dois pacotes de
// idioma (o do idioma vazio para o inglês) e o idioma. Por isso ela só usa o que tem dentro dela e o
// que o jsc oferece (load, readFile, preciseTime, print e printErr).
function measure(enginePath, docPath, ticks, enPath, langPath, tag) {
  // O jsc não tem console; o app terá o do Swift (Task 7). Aqui ele vai para o stderr, e a saída
  // fica só com o JSON do fim.
  const say = (...a) => printErr(a.map(String).join(' '))
  globalThis.console = { log: say, info: say, warn: say, error: say, debug: say }
  // O jsc não tem clearTimeout, que o _setDetails do i18n-core.js chama ao receber os pacotes; no
  // app, ele vem do host.js. Aqui não há timer para cancelar.
  if (typeof globalThis.clearTimeout !== 'function') globalThis.clearTimeout = () => {}
  const ms = (from, to) => (to - from) * 1000
  const median = xs => {
    const s = [...xs].sort((a, b) => a - b)
    const h = s.length >> 1
    return s.length % 2 ? s[h] : (s[h - 1] + s[h]) / 2
  }

  let t = preciseTime()
  load(enginePath)
  const evaluate = ms(t, preciseTime())
  t = preciseTime()
  const chosen = HexEngine.setLanguage(readFile(enPath), langPath ? readFile(langPath) : null, tag)
  const language = ms(t, preciseTime())
  if (chosen !== tag) throw new Error(`o setLanguage deixou ${chosen}, e o pedido era ${tag}`)
  const json = readFile(docPath)
  t = preciseTime()
  HexEngine.restore(json)
  const restore = ms(t, preciseTime())

  const M = HexEngine.__modules
  const { draftOf, clone } = M['frontend/src/lib/state-core.js']
  const { stampChange } = M['frontend/src/lib/sync-merge.js']
  const { stateJson } = M['frontend/src/lib/state-json.js']
  const { buildCombinedEntries, deriveSessionName } = M['frontend/src/lib/session-merge.js']
  const { uid, todayISO } = M['frontend/src/lib/format.js']
  const { fatigueOf } = M['frontend/src/lib/recovery.js']

  // Uma mudança como o update() do app web (store/useStore.js): o rascunho de S, a mudança nele, o
  // done(), os mapas deleted e edited copiados quando o rascunho ainda os divide com S, os carimbos
  // do stampChange e o texto que o app grava (stateJson).
  const update = (prev, change) => {
    const draft = draftOf(prev)
    change(draft.S)
    const next = draft.done()
    for (const k of ['deleted', 'edited']) if (next[k] && typeof next[k] === 'object' && next[k] === prev[k]) next[k] = clone(next[k])
    next._ts = stampChange(prev, next, Date.now())
    stateJson(next)
    return next
  }

  // O documento como o motor o tem depois do restore. A sessão começa como o beginWorkout
  // (sheets.jsx), com as entries de buildCombinedEntries de uma rotina: a de mais séries, para
  // caberem as séries marcadas.
  let S = JSON.parse(HexEngine.document())
  const setsIn = s => s.entries.reduce((n, e) => n + e.sets.length, 0)
  const session = S.routines.map(r => buildCombinedEntries(S, [r.id])).reduce((a, b) => (setsIn(b) > setsIn(a) ? b : a))
  if (setsIn(session) < ticks) throw new Error(`a rotina com mais séries tem ${setsIn(session)}, e o tick marca ${ticks}`)
  const startAt = Date.now()
  S = update(S, s => {
    s.active = {
      id: uid(), d: todayISO(), start: startAt, routineIds: session.routineIds,
      name: deriveSessionName(session.routines.map(r => r.name)),
      bw: null, cur: 0, entries: session.entries, workoutView: S.workoutView || 'cards',
    }
  })

  // As séries, na ordem do treino, uma marcada por vez, como o toggle de views/Workout.jsx.
  const order = []
  S.active.entries.forEach((e, i) => e.sets.forEach((_, j) => order.push([i, j])))
  const times = []
  for (const [i, j] of order.slice(0, ticks)) {
    t = preciseTime()
    S = update(S, s => {
      const set = s.active.entries[i].sets[j]
      set.done = true
      set.at = Date.now()
    })
    times.push(ms(t, preciseTime()))
  }
  const marked = S.active.entries.reduce((n, e) => n + e.sets.filter(x => x.done).length, 0)
  if (marked !== ticks) throw new Error(`o tick devia deixar ${ticks} séries feitas, e deixou ${marked}`)

  t = preciseTime()
  fatigueOf(S.workouts, Date.now())
  const fatigue = ms(t, preciseTime())

  // Igual peça por peça, sem dividir nenhum objeto com o original e com a volta no lugar: cada
  // objeto do original corresponde a um só da cópia.
  const original = { n: 1, d: new Date(5), m: new Map([[1, { y: 2 }]]), s: new Set([1, 'dois']), list: [1, [2]] }
  original.self = original
  const copy = structuredClone(original)
  const pairs = new Map()
  const same = (a, b) => {
    if (a === null || typeof a !== 'object') return Object.is(a, b)
    if (b === null || typeof b !== 'object' || a === b) return false
    if (pairs.has(a)) return pairs.get(a) === b
    pairs.set(a, b)
    if (Object.getPrototypeOf(a) !== Object.getPrototypeOf(b)) return false
    if (a instanceof Date) return a.getTime() === b.getTime()
    if (a instanceof Map || a instanceof Set) {
      const x = [...a], y = [...b]
      return x.length === y.length && x.every((v, i) => same(v, y[i]))
    }
    const ka = Object.keys(a), kb = Object.keys(b)
    return ka.length === kb.length && ka.every((k, i) => k === kb[i] && same(a[k], b[k]))
  }

  print(JSON.stringify({
    evaluate, language, restore, tick: median(times), fatigue, structuredClone: same(original, copy),
    workouts: S.workouts.length, ticks: times.length,
  }))
}

// Uma rodada: um processo novo do jsc, sem JIT. Devolve o que ela mediu; um jsc que falha, ou uma
// medição que não veio inteira, lança o erro.
function runJsc(jsc, files) {
  const r = spawnSync(jsc, ['--useJIT=false', files.measure, '--', files.engine, files.doc, String(TICKS), files.en, files.lang, files.tag], {
    encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, timeout: 120000,
  })
  if (r.error) throw new Error(`não deu para rodar o jsc: ${r.error.message}`)
  const said = [r.stdout, r.stderr].map(s => s.trim()).filter(Boolean).join('\n')
  if (r.status !== 0) throw new Error(`o jsc saiu com ${r.status ?? r.signal}:\n${said}`)
  if (r.stderr.trim()) process.stderr.write(r.stderr)
  const line = r.stdout.trim().split('\n').at(-1)
  let out
  try {
    out = JSON.parse(line)
  } catch {
    throw new Error(`o jsc não deu o JSON da medição:\n${said}`)
  }
  for (const k of ['evaluate', 'language', 'restore', 'tick', 'fatigue']) {
    if (!Number.isFinite(out[k])) throw new Error(`a medição do jsc veio sem ${k}: ${line}`)
  }
  if (typeof out.structuredClone !== 'boolean' || out.ticks !== TICKS) throw new Error(`a medição do jsc veio incompleta: ${line}`)
  return out
}

// A tabela, em Markdown, para ir ao PR como está.
function table(results, runs, { total, slack, tag }) {
  const ms = v => `${v.toFixed(1)} ms`
  const each = key => runs.map(r => r[key].toFixed(1)).join(', ')
  const meta = v => `${round(v * slack)} ms`
  const rows = [
    ['evaluate (avaliar o script)', ms(results.evaluate), each('evaluate'), ''],
    [`idioma (ler ${tag === 'en' ? 'o pacote en' : `os pacotes en e ${tag}`} e o setLanguage)`, ms(results.language), each('language'), ''],
    ['restore (abrir o documento)', ms(results.restore), each('restore'), ''],
    ['evaluate + idioma + restore', ms(results.evaluate + results.language + results.restore), '', meta(OPEN_MS)],
    [`tick (mediana de ${TICKS} séries marcadas)`, ms(results.tick), each('tick'), meta(TICK_MS)],
    ['fatigue (só para registro)', ms(results.fatigue), each('fatigue'), ''],
    ['structuredClone', results.structuredClone ? 'igual nas 5' : 'diferente', runs.map(r => (r.structuredClone ? 'igual' : 'diferente')).join(', '), 'igual'],
  ]
  return [
    `O motor no jsc do macOS sem JIT (--useJIT=false), com ${total} treinos no histórico e o idioma ${tag}, neste Mac (${os.cpus()[0]?.model ?? 'processador desconhecido'}):`,
    `a mediana de ${RUNS} rodadas, um processo novo em cada${slack === 1 ? '' : `, com as metas vezes ${slack} (HEXGYM_LOAD_SLACK)`}.`,
    '',
    '| medida | mediana | as 5 rodadas | meta |',
    '| --- | ---: | --- | ---: |',
    ...rows.map(r => `| ${r.join(' | ')} |`),
  ].join('\n')
}

// O slack do HEXGYM_LOAD_SLACK, 1 sem ele. Um valor que não é número maior que zero é erro, e não
// uma meta que nunca falha.
function slackOf(env) {
  const raw = env.HEXGYM_LOAD_SLACK
  if (raw === undefined || raw === '') return 1
  const n = Number(raw)
  if (!Number.isFinite(n) || n <= 0) throw new Error(`HEXGYM_LOAD_SLACK precisa ser um número maior que zero (veio ${JSON.stringify(raw)})`)
  return n
}

// A CLI. O jsc e o ambiente podem vir de fora, para quem a chama de um teste. Devolve o código de
// saída: 0 dentro das metas, 1 fora delas ou quando a medição não sai, 2 com argumentos errados.
export async function main(argv = [], { jsc = JSC, env = process.env } = {}) {
  let total = WORKOUTS
  let tag = LANG
  const usage = () => {
    console.error('uso: node scripts/hexgym/engine-load.mjs [--workouts N] [--lang IDIOMA]')
    return 2
  }
  for (let i = 0; i < argv.length; i += 2) {
    const [flag, v] = [argv[i], argv[i + 1]]
    if (flag === '--workouts' && /^[1-9]\d*$/.test(v ?? '')) total = Number(v)
    else if (flag === '--lang' && v) tag = v
    else return usage()
  }
  let packs
  try {
    packs = JSON.parse(fs.readFileSync(path.join(ROOT, LANGS_DIR, 'index.json'), 'utf8'))
  } catch (e) {
    console.error(`não deu para ler os pacotes de idioma (${LANGS_DIR}/index.json): ${e.message}`)
    return 1
  }
  if (!packs[tag]) {
    console.error(`não há pacote para o idioma ${tag} (idiomas: ${Object.keys(packs).join(', ')})`)
    return 2
  }
  let slack
  try {
    slack = slackOf(env)
  } catch (e) {
    console.error(e.message)
    return 1
  }
  if (!fs.existsSync(jsc)) {
    console.error(`o teste de carga precisa do jsc do macOS (${jsc})`)
    return 1
  }
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-load-'))
  try {
    const files = {
      engine: path.join(tmp, 'hexengine.js'), doc: path.join(tmp, 'state.json'), measure: path.join(tmp, 'measure.js'),
      en: path.join(tmp, 'en.json'), lang: tag === 'en' ? '' : path.join(tmp, 'lang.json'), tag,
    }
    fs.writeFileSync(files.engine, readEngine(ROOT))
    // Os pacotes descomprimidos, como o Swift os passa ao motor (o jsc não descomprime).
    const unpacked = lang => zlib.inflateRawSync(fs.readFileSync(path.join(ROOT, LANGS_DIR, packs[lang].file)))
    fs.writeFileSync(files.en, unpacked('en'))
    if (files.lang) fs.writeFileSync(files.lang, unpacked(tag))
    fs.writeFileSync(files.doc, JSON.stringify(padHistory(buildDemoState(), total)))
    fs.writeFileSync(files.measure, `${measure.toString()}\nmeasure(arguments[0], arguments[1], Number(arguments[2]), arguments[3], arguments[4], arguments[5])\n`)
    const runs = []
    for (let i = 0; i < RUNS; i++) runs.push(runJsc(jsc, files))
    const bad = runs.find(r => r.workouts !== total)
    if (bad) throw new Error(`o jsc abriu ${bad.workouts} treinos, e o histórico tem ${total}`)
    const results = {
      evaluate: median(runs.map(r => r.evaluate)),
      language: median(runs.map(r => r.language)),
      restore: median(runs.map(r => r.restore)),
      tick: median(runs.map(r => r.tick)),
      fatigue: median(runs.map(r => r.fatigue)),
      structuredClone: runs.every(r => r.structuredClone),
    }
    const over = overBudget(results, slack)
    console.log(table(results, runs, { total, slack, tag }))
    console.log('')
    if (over.length) console.log(`Fora das metas:\n${over.map(o => `- ${o}`).join('\n')}`)
    else console.log('Dentro das metas.')
    if (env[COUNT_FILE]) {
      const passed = METAS.length - over.length
      fs.writeFileSync(env[COUNT_FILE], `# tests ${METAS.length}\n# pass ${passed}\n# fail ${over.length}\n`)
    }
    return over.length ? 1 : 0
  } catch (e) {
    console.error(`o teste de carga não saiu: ${e.message}`)
    return 1
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true })
  }
}

// Chamado como script, e não importado: as duas pontas passam pelo realpath. Um argv[1] que não
// existe (node -e, por exemplo) quer dizer que não é este arquivo.
function isMain() {
  try {
    return Boolean(process.argv[1]) && fs.realpathSync(process.argv[1]) === SELF
  } catch {
    return false
  }
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
