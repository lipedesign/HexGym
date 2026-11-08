#!/usr/bin/env node
// Grava no Node os casos das duas regras do openGym que o editor de rotina do app copiou para o Swift
// (issue #116), para o RoutineCasesTests.swift conferir as cópias contra o código de verdade:
//   - o passo da carga, o addStep de frontend/src/lib/progression.js, que o SlotDraft copia
//     (apple/HexGym/Routines/RoutineEditorModel.swift);
//   - os emojis antigos, o mapa LEGACY e o glyphOf de frontend/src/lib/glyphs.js, que o RoutineGlyph
//     copia (apple/HexGym/Routines/RoutineGlyph.swift).
//
//   node scripts/hexgym/record-routine-cases.mjs           # grava o arquivo, se ele mudou
//   node scripts/hexgym/record-routine-cases.mjs --check   # só compara, e sai com 1 se ele estiver velho
//
// O arquivo, apple/HexGymTests/RoutineCases.json, entra sozinho no alvo de testes do app (a pasta é um
// grupo sincronizado do Xcode), e o teste o acha pelo Bundle dele. Ele é um objeto com:
//   - "addStep": um grupo por unidade e incremento, { unit, increment, cases }, e cada caso é
//     [carga, addStep(carga, +incremento, incremento), addStep(carga, -incremento, incremento)];
//   - "legacy": cada entrada do LEGACY, { emoji, codes, key }, com os pontos de código em hexadecimal;
//   - "glyphOf": cada entrada que o glyphOf leu, { input, codes, key }.
// Um caso por linha, para o diff do PR mostrar só o que mudou.
//
// A grade da carga (escolha recomendada, com a delegação do Lipe de 03/11/2026): a grade inteira do QA
// do PR #115 (282.884 casos) daria um arquivo de vários megabytes, então ficam as bordas:
//   - os incrementos de cada unidade são os do QA (0,5, 1, 1,25, 2, 2,5, 5 e 10, que têm os padrões das
//     duas unidades), o 0,1 e o 0,2 (QA do PR #148: num incremento menor que 0,25, a borda de 0,1 do
//     "na grade" chega perto do meio do passo, e só ali um arredondamento trocado ou uma borda que
//     encolhe com o incremento mudam a resposta) e cada um deles trazido da outra unidade pelo
//     convertWeight do openGym, como a troca de unidade faz com o inc de um exercício (1,25 kg vira 3 lb);
//   - as cargas, de 0 a 1.010: de 0 a 3, de 0,05 em 0,05 (o piso do 0 para baixo); em volta de
//     múltiplos do incremento (os primeiros e os vizinhos de 100, 250, 500, 1.000 e 1.010), a 0, 0,05,
//     0,1 e 0,15 para cada lado, que é a borda do "na grade" do addStep; de 10,05 em 10,05, para as
//     casas decimais variarem pela faixa toda; e de 999 a 1.001 e de 1.009 a 1.010, de 0,05 em 0,05;
//   - nos dois incrementos padrão de cada unidade, também as cargas que a troca de unidade dá: cada
//     múltiplo de 2,5 da outra unidade até 1.010, convertido pelo convertWeight.
//
// O glyphs.js importa o Icon.jsx, que o Node não lê, e não exporta o LEGACY. O gravador lê o glyphs.js
// como texto, troca aquele import por uma lista vazia de ICON_NAMES, exporta o LEGACY (se ele já não
// for um export const) e importa o resultado. Com a lista vazia, o glyphOf só responde como o de verdade para uma entrada que não é o
// nome de um ícone; por isso, toda entrada aqui é vazia ou tem um caractere fora do ASCII, e os nomes
// dos ícones são ASCII.
//
// Node 22, sem dependências. Importar este arquivo não roda nada.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

// O caminho de verdade deste arquivo, sem links, como no check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const ROOT = path.join(path.dirname(SELF), '..', '..')

// O arquivo gravado, a partir da raiz.
export const CASES_FILE = 'apple/HexGymTests/RoutineCases.json'

const LIB = path.join(ROOT, 'frontend', 'src', 'lib')
const ICON_IMPORT = "import { ICON_NAMES } from '../components/Icon.jsx'"

// Os incrementos do QA do PR #115, mais os dois pequenos do QA do PR #148, e o limite de cima da grade.
const BASE_INCREMENTS = [0.1, 0.2, 0.5, 1, 1.25, 2, 2.5, 5, 10]
const TOP = 1010

// Um número com até duas casas, o double mais perto do decimal, como uma carga digitada ou gravada.
const two = x => Number(x.toFixed(2))
// De from a to, de by em by, com cada valor no double do decimal.
const range = (from, to, by) => Array.from({ length: Math.round((to - from) / by) + 1 }, (_, i) => two(from + i * by))

// O glyphs.js do openGym, importado sem o Icon.jsx e com o LEGACY exportado. O source é o texto do
// arquivo; o teste do script passa outro. Um export const LEGACY já sai exportado, e um const LEGACY
// ganha o export no fim. Um import a mais no arquivo quebra o import do data: (ele não acha o caminho
// a partir dele), e a mensagem diz qual, sem a URL em base64, que tem o arquivo inteiro.
const DATA_URL = /data:text\/javascript;base64,[A-Za-z0-9+/=]+/g
export async function loadGlyphs(source = fs.readFileSync(path.join(LIB, 'glyphs.js'), 'utf8')) {
  const file = 'frontend/src/lib/glyphs.js'
  if (source.split(ICON_IMPORT).length !== 2) throw new Error(`o ${file} não tem, uma vez só, a linha: ${ICON_IMPORT}`)
  const exported = /^export const LEGACY = \{/m.test(source)
  if (!exported && !/^const LEGACY = \{/m.test(source)) throw new Error(`o ${file} não tem o const LEGACY nem o export const LEGACY`)
  const code = source.replace(ICON_IMPORT, 'const ICON_NAMES = []') + (exported ? '' : '\nexport { LEGACY }\n')
  try {
    return await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`)
  } catch (err) {
    if (err.code === 'ERR_UNSUPPORTED_RESOLVE_REQUEST') {
      const which = err.message.match(/specifier "([^"]+)"/)?.[1]
      throw new Error(`o ${file} importa outro módulo além do Icon.jsx${which ? ` (${which})` : ''}`)
    }
    throw new Error(`o ${file} não carregou: ${String(err.message).replace(DATA_URL, file)}`)
  }
}

// Os pontos de código de um texto, em hexadecimal maiúsculo, separados por espaço.
export const codesOf = text => [...text].map(c => c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')).join(' ')

// Os incrementos de uma unidade: os do QA e cada um deles convertido da outra unidade, sem repetir.
function incrementsOf(unit, convertWeight) {
  const other = unit === 'kg' ? 'lb' : 'kg'
  const all = [...BASE_INCREMENTS, ...BASE_INCREMENTS.map(x => convertWeight(x, other, unit))].filter(x => x > 0)
  return [...new Set(all)].sort((a, b) => a - b)
}

// As cargas de um incremento, de 0 a TOP, sem repetir e em ordem.
function loadsOf(inc, extra = []) {
  const near = [1, 2, 3, 4, 5, 7, 10, 13]
  for (const t of [100, 250, 500, 1000, TOP]) near.push(Math.floor(t / inc), Math.ceil(t / inc))
  const loads = [...range(0, 3, 0.05), ...range(0, TOP, 10.05), ...range(999, 1001, 0.05), ...range(1009, TOP, 0.05), ...extra]
  for (const k of near) for (const d of [-0.15, -0.1, -0.05, 0, 0.05, 0.1, 0.15]) loads.push(two(k * inc + d))
  return [...new Set(loads)].filter(x => x >= 0 && x <= TOP).sort((a, b) => a - b)
}

// Os casos, montados e rodados nos módulos do openGym.
export async function buildCases() {
  const lib = name => import(pathToFileURL(path.join(LIB, name)).href)
  const [{ addStep, defaultIncrement }, { convertWeight }, { LEGACY, glyphOf }] = await Promise.all([lib('progression.js'), lib('units.js'), loadGlyphs()])

  const groups = []
  for (const unit of ['kg', 'lb']) {
    const other = unit === 'kg' ? 'lb' : 'kg'
    // Os padrões da unidade, num exercício de perna e num de peito (o agachamento e o supino reto).
    const defaults = new Set([defaultIncrement('0043', unit), defaultIncrement('0025', unit)])
    const converted = range(2.5, TOP, 2.5).map(x => convertWeight(x, other, unit))
    for (const increment of incrementsOf(unit, convertWeight)) {
      const cases = loadsOf(increment, defaults.has(increment) ? converted : [])
        .map(load => [load, addStep(load, increment, increment), addStep(load, -increment, increment)])
      groups.push({ unit, increment, cases })
    }
  }

  const legacy = Object.entries(LEGACY).map(([emoji, key]) => ({ emoji, codes: codesOf(emoji), key }))

  // Cada emoji antigo como está, com um tom de pele, com e sem o seletor de variação, com o seletor
  // ou o ZWJ na frente (QA do PR #148: só ali o corte do ZWJ muda a resposta) e com um ZWJ a mais; e
  // entradas que caem no padrão ou só no primeiro caractere.
  const strip = text => [...text].filter(c => c !== '\u{FE0F}' && c !== '\u{200D}').join('')
  const inputs = ['', '\u{FE0F}', '\u{200D}', '\u{FE0F}\u{200D}', '🐙', '🐙💪', '💪🐙', '❤️', '♀️', '🏳️‍🌈', '🇧🇷', '🏋️‍♂️', '💪🏽']
  for (const emoji of Object.keys(LEGACY)) {
    inputs.push(emoji, `${emoji}\u{1F3FD}`, `${emoji}\u{FE0F}`, strip(emoji), `\u{FE0F}${emoji}`, `\u{200D}${emoji}`,
      `${emoji}\u{200D}\u{2642}\u{FE0F}`)
  }
  const glyphs = []
  for (const input of [...new Set(inputs)]) {
    if (input !== '' && /^[\x00-\x7F]*$/.test(input)) throw new Error(`a entrada "${input}" do glyphOf é só ASCII, e pode ser o nome de um ícone`)
    glyphs.push({ input, codes: codesOf(input), key: glyphOf(input) })
  }

  return { addStep: groups, legacy, glyphOf: glyphs }
}

// O texto do arquivo: dois espaços de recuo e um caso por linha.
export function render({ addStep, legacy, glyphOf }) {
  const j = JSON.stringify
  const list = (items, line, indent) => items.map(line).map(l => `${indent}${l}`).join(',\n')
  const group = g => `{ "unit": ${j(g.unit)}, "increment": ${j(g.increment)}, "cases": [\n${list(g.cases, j, '      ')}\n    ] }`
  return [
    '{',
    `  "source": ${j('frontend/src/lib/progression.js#addStep e frontend/src/lib/glyphs.js (LEGACY e glyphOf); gravado por scripts/hexgym/record-routine-cases.mjs')},`,
    `  "addStep": [\n${list(addStep, group, '    ')}\n  ],`,
    `  "legacy": [\n${list(legacy, e => `{ "emoji": ${j(e.emoji)}, "codes": ${j(e.codes)}, "key": ${j(e.key)} }`, '    ')}\n  ],`,
    `  "glyphOf": [\n${list(glyphOf, e => `{ "input": ${j(e.input)}, "codes": ${j(e.codes)}, "key": ${j(e.key)} }`, '    ')}\n  ]`,
    '}',
    '',
  ].join('\n')
}

// O texto que o gravador escreveria agora.
export async function recordText() {
  return render(await buildCases())
}

// O texto guardado, ou null sem o arquivo. Outro erro de leitura sobe.
function stored(file) {
  try {
    return fs.readFileSync(file, 'utf8')
  } catch (err) {
    if (err.code === 'ENOENT') return null
    throw err
  }
}

// A CLI. Sem --check, grava o arquivo se ele mudou ou falta, e diz o que fez. Com --check, só compara,
// e sai com 1 quando o arquivo falta ou não bate. O file é o caminho do arquivo, a partir da raiz ou
// absoluto; o teste do script passa um numa pasta temporária. Devolve o código de saída.
export async function main(argv = [], file = CASES_FILE) {
  if (argv.some(a => a !== '--check')) {
    console.error('uso: node scripts/hexgym/record-routine-cases.mjs [--check]')
    return 2
  }
  const check = argv.includes('--check')
  let text
  try {
    text = await recordText()
  } catch (err) {
    console.error(`os casos do editor de rotina não saíram: ${err.message}`)
    return 1
  }
  const full = path.resolve(ROOT, file), current = stored(full)
  const { addStep, legacy, glyphOf } = JSON.parse(text)
  const count = `${addStep.reduce((n, g) => n + g.cases.length, 0)} cargas, ${legacy.length} emojis antigos e ${glyphOf.length} entradas do glyphOf`
  if (current === text) {
    console.log(`${file} está em dia (${count}).`)
    return 0
  }
  if (check) {
    console.error(`${file} está desatualizado. Rode: node scripts/hexgym/record-routine-cases.mjs`)
    return 1
  }
  fs.mkdirSync(path.dirname(full), { recursive: true })
  fs.writeFileSync(full, text)
  console.log(`Gravei ${file} (${count}), porque ${current === null ? 'ele faltava' : 'os casos mudaram'}.`)
  return 0
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
