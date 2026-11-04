#!/usr/bin/env node
// As checagens do HexGym, por parte. É o comando de teste do projeto: o checks.test do
// .relentless/config.json, o QA e a CI chamam este mesmo script.
//
//   node scripts/hexgym/check.mjs                # todas as partes, na ordem do PARTS
//   node scripts/hexgym/check.mjs scripts        # só as partes pedidas
//   node scripts/hexgym/check.mjs --list         # mostra os comandos e não roda nada
//
// Node 22, sem dependências: para um Vitest, ele só lê o std-env do próprio Vitest da pasta da
// checagem, para escolher os reporters da tela como o Vitest escolheria (vitestScreen). Cada
// checagem é { name, cmd, args, cwd?, env? }: o cwd é relativo à raiz do repositório, e o env se
// soma ao process.env. O args e o env podem ser uma função que devolve o valor, chamada só quando
// aquela checagem vai rodar: assim, uma parte que precisa do Xcode não quebra as outras nem o
// --list numa máquina sem ele.
// Uma parte só passa se as checagens dela passam e se, somadas, rodaram pelo menos um teste
// (issue #44): um node --test que não acha arquivo, ou que roda dentro de outro e pula os
// arquivos, sai com 0 sem testar nada. Como cada checagem conta os testes dela está no PARTS.

import { execFileSync, spawn } from 'node:child_process'
import fs from 'node:fs'
import { createRequire } from 'node:module'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

// O caminho de verdade deste arquivo, sem links. Chamado por um link simbólico com
// --preserve-symlinks-main, o import.meta.url fica com o caminho do link: o ROOT sairia de
// fora do repositório, e o isMain() não se reconheceria.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const ROOT = path.join(path.dirname(SELF), '..', '..')

// Os módulos que moram ao lado deste arquivo, importados pelo caminho de verdade dele: pelo mesmo
// link, um import comum os procuraria ao lado do link. Nenhum dos dois roda nada ao ser importado,
// e o developerDir, o swiftTestFlags e o pickSimulator só são chamados quando uma checagem da parte
// packages ou da parte app vai rodar.
const sibling = name => import(pathToFileURL(path.join(path.dirname(SELF), name)).href)
const { developerDir, pickSimulator, swiftTestFlags } = await sibling('xcode.mjs')
const { TIME_ZONES } = await sibling('engine-cases.mjs')

// Uma rodada do swift test do HexEngine. O args leva, logo depois do test, os argumentos do
// swiftTestFlags para o swift do xcode.mjs (o Xcode completo ou, sem ele, as Command Line Tools, que
// recebem o caminho do plugin do TestingMacros), os mesmos em toda rodada, para o plano de compilação
// ser o mesmo em todas. O env leva esse swift e o fuso, no TZ do processo e no HEXGYM_CASES, que diz
// ao RecordedCasesTests quais casos gravados rodar.
const swiftDir = () => developerDir({ swiftOnly: true })
const hexEngineTest = (...rest) => ['test', ...swiftTestFlags(swiftDir()), '--package-path', 'apple/Packages/HexEngine', ...rest]
const swiftIn = zone => ({ DEVELOPER_DIR: swiftDir(), TZ: zone, HEXGYM_CASES: zone })

// O Xcode completo, para o xcodebuild e o xcrun da parte app.
const xcodeIn = () => ({ DEVELOPER_DIR: developerDir() })
const PROJECT = ['-project', 'apple/HexGym.xcodeproj']
const DERIVED = ['-derivedDataPath', 'apple/DerivedData']
// Os dois builds da Task 9, sem assinatura: o app, com o Watch e os widgets embutidos, e o Watch.
const appBuild = (scheme, platform) =>
  [...PROJECT, '-scheme', scheme, '-destination', `generic/platform=${platform}`, ...DERIVED, 'CODE_SIGNING_ALLOWED=NO', 'build']
// A rodada de testes do esquema HexGym, no iPhone que o pickSimulator escolhe na hora, entre os
// simuladores que existem, com a assinatura local que o Xcode faz para simulador. O
// -parallel-testing-enabled NO faz os testes rodarem no próprio simulador, e não num clone que o
// xcodebuild cria desligando o original (QA do PR #81).
const appTests = () => {
  const simctl = execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '--json'], { encoding: 'utf8', env: { ...process.env, ...xcodeIn() } })
  return [...PROJECT, '-scheme', 'HexGym', '-destination', `id=${pickSimulator(simctl)}`, ...DERIVED, '-parallel-testing-enabled', 'NO', 'test']
}

// Sempre nesta ordem, e cada Task põe a sua parte no lugar dela:
// scripts, engine, load, packages, app.
// Cada parte mostra quantos testes rodou, e a que não rodou nenhum falha. O spawnCheck conta os
// testes que passaram sempre por um arquivo que a ferramenta grava na pasta temporária da checagem,
// nunca pela saída da tela, e sem o arquivo a checagem conta zero:
//   - o node --test, por um segundo reporter, tap (por isso, a checagem não leva --test-reporter);
//   - o Vitest (npx vitest), por um segundo reporter, json (por isso, a checagem não leva --reporter
//     nem --outputFile, e o config dela não escolhe reporters);
//   - o swift test, pelo XUnit do --xunit-output (por isso, a checagem não leva --xunit-output): cada
//     <testcase> sem <skipped>, <failure> nem <error> dentro, e um teste pulado não conta;
//   - o xcodebuild ... test, pelo resultado do -resultBundlePath (por isso, a checagem não leva
//     -resultBundlePath): o passedTests do xcrun xcresulttool get test-results summary, no mesmo
//     DEVELOPER_DIR, e um teste pulado ou que falhou não conta;
//   - qualquer outro comando, pelo arquivo que o spawnCheck passa em HEXGYM_CHECK_COUNT_FILE, onde
//     ele grava quantos testes passaram no formato do fim do tap (# pass <n>). É o que o
//     engine-load.mjs faz, com as metas que conferiu e que passaram, e o run_tests.py do gerador de
//     regiões, com os testes do unittest que passaram.
// Um comando que não grava nada (os --check e o xcodebuild ... build, por exemplo) conta zero, e a
// parte dele precisa de outra checagem que conte, ou de ensinar o spawnCheck a contar.
// Na parte scripts, depois dos testes dos scripts, as duas rodadas do gerador de regiões (issue #12),
// no Python 3 da máquina, isolado (-I) e só com a biblioteca padrão: o --check não conta teste, e o
// run_tests.py grava a conta no arquivo de COUNT_FILE.
// Na parte engine, os pacotes de idioma (scripts/build-hexgym-langs.mjs) vêm antes do script do
// motor: o --check deles não conta teste, e o language.test.mjs, que lê os pacotes guardados, cai no
// glob dos testes do script do motor.
export const PARTS = {
  scripts: [
    { name: 'testes dos scripts', cmd: 'node', args: ['--test', 'scripts/hexgym/*.test.mjs'] },
    { name: 'regiões em dia', cmd: 'python3', args: ['-I', 'scripts/hexbody/regions/build_exercise_regions.py', '--check'] },
    { name: 'testes do gerador de regiões', cmd: 'python3', args: ['-I', 'scripts/hexbody/regions/run_tests.py'] },
  ],
  engine: [
    { name: 'idiomas em dia', cmd: 'node', args: ['scripts/build-hexgym-langs.mjs', '--check'] },
    { name: 'script do motor em dia', cmd: 'node', args: ['scripts/build-hexgym-engine.mjs', '--check'] },
    { name: 'casos gravados em dia', cmd: 'node', args: ['scripts/hexgym/record-engine-cases.mjs', '--check'] },
    { name: 'testes do script do motor', cmd: 'node', args: ['--test', 'apple/Packages/HexEngine/JS/*.test.mjs'] },
    { name: 'testes do lib contra o script', cmd: 'npx', args: ['vitest', 'run', '--config', 'vitest.hexengine.config.js'], cwd: 'frontend' },
  ],
  load: [
    { name: 'teste de carga do motor no jsc', cmd: 'node', args: ['scripts/hexgym/engine-load.mjs'] },
  ],
  // Todos os testes do HexEngine no primeiro fuso, com os casos gravados dele, e os casos gravados de
  // novo em cada outro fuso. Só a primeira rodada compila: as outras rodam o que ela compilou
  // (--skip-build), porque o swift test refaz parte da compilação a cada chamada, mesmo sem mudança.
  // Depois, todos os testes do HexStore, com o mesmo swift e os mesmos swiftTestFlags; eles não
  // dependem do fuso, e o env não põe nenhum. Por fim, todos os do HexDesign, como os do HexStore. Os
  // testes de print do HexDesign só rodam com HEXDESIGN_PRINTS no ambiente: sem ela, ficam pulados e
  // não contam.
  // O args e o env são funções: sem o swift, só esta parte falha.
  packages: [
    { name: `HexEngine, com os casos gravados em ${TIME_ZONES[0]}`, cmd: 'swift', args: () => hexEngineTest(), env: () => swiftIn(TIME_ZONES[0]) },
    ...TIME_ZONES.slice(1).map(zone => ({
      name: `HexEngine, casos gravados em ${zone}`, cmd: 'swift',
      args: () => hexEngineTest('--skip-build', '--filter', 'RecordedCasesTests'), env: () => swiftIn(zone),
    })),
    {
      name: 'HexStore', cmd: 'swift',
      args: () => ['test', ...swiftTestFlags(developerDir({ swiftOnly: true })), '--package-path', 'apple/Packages/HexStore'],
      env: () => ({ DEVELOPER_DIR: developerDir({ swiftOnly: true }) }),
    },
    {
      name: 'HexDesign', cmd: 'swift',
      args: () => ['test', ...swiftTestFlags(developerDir({ swiftOnly: true })), '--package-path', 'apple/Packages/HexDesign'],
      env: () => ({ DEVELOPER_DIR: developerDir({ swiftOnly: true }) }),
    },
  ],
  // Os dois builds da Task 9 e a rodada de testes do app, com os testes do AppModel. Só a rodada de
  // testes conta, porque build não roda teste. O env de todas e o args da rodada são funções: sem o
  // Xcode, ou sem um simulador de iPhone com iOS 26 ou mais novo, só esta parte falha.
  app: [
    { name: 'build do app', cmd: 'xcodebuild', args: appBuild('HexGym', 'iOS Simulator'), env: xcodeIn },
    { name: 'build do Watch', cmd: 'xcodebuild', args: appBuild('HexGymWatch', 'watchOS Simulator'), env: xcodeIn },
    { name: 'testes do app', cmd: 'xcodebuild', args: appTests, env: xcodeIn },
  ],
}

// A variável com o arquivo em que um comando que não é node --test nem Vitest grava a conta dele.
// O engine-load.mjs lê o mesmo nome.
export const COUNT_FILE = 'HEXGYM_CHECK_COUNT_FILE'

const LATER = '(calculado ao rodar)'
const value = x => (typeof x === 'function' ? x() : x)

// As partes pedidas, na ordem do PARTS; sem nenhuma, todas.
function partNames(parts) {
  const known = Object.keys(PARTS)
  for (const p of parts) {
    if (!known.includes(p)) throw new Error(`parte desconhecida: ${p} (partes: ${known.join(', ')})`)
  }
  return parts.length ? known.filter(p => parts.includes(p)) : known
}

export function planChecks(parts) {
  return partNames(parts).flatMap(p => PARTS[p])
}

// Cada parte pedida com as checagens dela.
function planParts(parts) {
  return Object.fromEntries(partNames(parts).map(p => [p, PARTS[p]]))
}

// Um node --test: o --test vem antes do primeiro argumento que não é opção, o primeiro arquivo.
function isNodeTest(cmd, args) {
  if (cmd !== process.execPath && path.basename(cmd) !== 'node') return false
  const i = args.indexOf('--test')
  return i >= 0 && args.slice(0, i).every(a => a.startsWith('-'))
}

// O node --test com um segundo reporter, tap, gravado no arquivo, ao lado do da tela. O da tela
// é o que o node --test usaria sem a opção: no Node 22, spec num terminal e tap fora dele, e
// depois dele, sempre spec (medido no 22.19 e no 24.18). A saída continua a de sempre.
function withTapFile(args, file) {
  const screen = process.stdout.isTTY || Number(process.versions.node.split('.')[0]) > 22 ? 'spec' : 'tap'
  const i = args.indexOf('--test') + 1
  return [...args.slice(0, i), `--test-reporter=${screen}`, '--test-reporter-destination=stdout',
    '--test-reporter=tap', `--test-reporter-destination=${file}`, ...args.slice(i)]
}

// Um Vitest: o npx com o vitest como primeiro argumento.
function isVitest(cmd, args) {
  return path.basename(cmd) === 'npx' && args[0] === 'vitest'
}

// Os reporters da tela que o Vitest da pasta cwd usaria sem a opção. É a regra do Vitest 4 (o
// resolveConfig dele; no 4.1.12, em vitest/dist/chunks/coverage.*.js), para um config sem reporters:
// agent quando o std-env dele acha um agente de IA no ambiente, senão default, e mais o
// github-actions dentro da Actions. O std-env é o que o próprio Vitest usa, e ele lê o ambiente do
// check.mjs, que o Vitest herda.
async function vitestScreen(cwd, env) {
  const vitest = createRequire(path.join(cwd, 'package.json')).resolve('vitest/package.json')
  const { isAgent } = await import(pathToFileURL(createRequire(vitest).resolve('std-env')).href)
  return [isAgent ? 'agent' : 'default', ...(env.GITHUB_ACTIONS === 'true' ? ['github-actions'] : [])]
}

// O Vitest com um segundo reporter, json, gravado no arquivo, ao lado dos da tela. Um --reporter na
// linha de comando troca todos os reporters do Vitest, então os da tela vão junto, e a saída
// continua a de sempre, mais a linha em que o json diz onde gravou.
function withJsonFile(args, file, screen) {
  const i = args[1] === 'run' ? 2 : 1
  return [...args.slice(0, i), ...screen.map(r => `--reporter=${r}`), '--reporter=json', `--outputFile.json=${file}`, ...args.slice(i)]
}

// O texto que a ferramenta gravou no arquivo, ou null sem ele. Outro erro de leitura sai no stderr.
function report(file) {
  try {
    return fs.readFileSync(file, 'utf8')
  } catch (err) {
    if (err.code !== 'ENOENT') console.error(`não deu para ler quantos testes rodaram: ${err.message}`)
    return null
  }
}

// Quantos testes passaram, pelo "# pass" do fim do tap: um teste pulado ou todo não conta. Sem o
// arquivo, nenhum: com o NODE_TEST_CONTEXT herdado de outro node --test, o Node pula os arquivos
// e não grava os reporters pedidos. É também o formato do arquivo de COUNT_FILE.
function passedTests(file) {
  const tap = report(file)
  const pass = tap === null ? undefined : [...tap.matchAll(/^# pass (\d+)$/gm)].at(-1)
  return pass ? Number(pass[1]) : 0
}

// Quantos testes passaram no Vitest, pelo numPassedTests do reporter json: um teste pulado ou todo
// não conta. Sem o arquivo, ou com um que não é o relatório, nenhum.
function passedVitest(file) {
  const text = report(file)
  if (text === null) return 0
  let passed
  try {
    passed = JSON.parse(text).numPassedTests
  } catch (err) {
    console.error(`não deu para ler quantos testes rodaram: ${err.message}`)
    return 0
  }
  return Number.isInteger(passed) && passed >= 0 ? passed : 0
}

// Um swift test: o swift com o test como primeiro argumento.
function isSwiftTest(cmd, args) {
  return path.basename(cmd) === 'swift' && args[0] === 'test'
}

// O swift test com o --xunit-output no arquivo. O Swift Testing grava ali o resultado em XUnit, e a
// tela continua a de sempre.
function withXunitFile(args, file) {
  return [args[0], '--xunit-output', file, ...args.slice(1)]
}

// Os <testcase> que passaram num XUnit: os que não têm <skipped>, <failure> nem <error> dentro. Um
// <testcase .../> fechado nele mesmo passou; um que não fecha não conta.
function passedCases(xml) {
  let passed = 0
  for (const m of xml.matchAll(/<testcase\b((?:[^>"']|"[^"]*"|'[^']*')*)>/g)) {
    if (m[1].trimEnd().endsWith('/')) {
      passed++
      continue
    }
    const from = m.index + m[0].length, to = xml.indexOf('</testcase>', from)
    if (to >= 0 && !/<(skipped|failure|error)\b/.test(xml.slice(from, to))) passed++
  }
  return passed
}

// Quantos testes passaram no swift test, somados os XUnit que ele gravou na pasta da checagem: o
// arquivo do --xunit-output e, com o XCTest de um Xcode completo rodando junto, o do Swift Testing
// ao lado dele, com -swift-testing no nome. Sem nenhum, zero.
function passedXunit(dir) {
  let names
  try {
    names = fs.readdirSync(dir).filter(n => n.endsWith('.xml')).sort()
  } catch (err) {
    console.error(`não deu para ler quantos testes rodaram: ${err.message}`)
    return 0
  }
  return names.reduce((sum, name) => sum + passedCases(report(path.join(dir, name)) ?? ''), 0)
}

// Um xcodebuild que roda testes: o xcodebuild com a ação test no fim.
function isXcodebuildTest(cmd, args) {
  return path.basename(cmd) === 'xcodebuild' && args.at(-1) === 'test'
}

// O xcodebuild test com o -resultBundlePath no caminho, logo antes da ação. O xcodebuild grava ali o
// resultado, e a tela continua a de sempre. O caminho não pode existir antes: o xcodebuild recusa.
function withResultBundle(args, bundle) {
  return [...args.slice(0, -1), '-resultBundlePath', bundle, args.at(-1)]
}

// Quantos testes passaram no xcodebuild test, pelo passedTests do resumo que o xcresulttool lê do
// resultado, com o env da checagem (o mesmo DEVELOPER_DIR). Sem o resultado, ou com um resumo que não
// se lê, nenhum.
function passedXcresult(bundle, env) {
  if (!fs.existsSync(bundle)) return 0
  let passed
  try {
    const summary = execFileSync('xcrun', ['xcresulttool', 'get', 'test-results', 'summary', '--path', bundle, '--compact'],
      { encoding: 'utf8', env, stdio: ['ignore', 'pipe', 'inherit'] })
    passed = JSON.parse(summary).passedTests
  } catch (err) {
    console.error(`não deu para ler quantos testes rodaram: ${err.message}`)
    return 0
  }
  return Number.isInteger(passed) && passed >= 0 ? passed : 0
}

// Roda uma checagem e devolve o código de saída. Um args ou env que não sai, ou um comando
// que nem começa, conta como falha dessa checagem, com o motivo no stderr. O count recebe quantos
// testes passaram, pelo arquivo que a ferramenta gravou numa pasta própria em os.tmpdir(), que sai
// quando a checagem acaba: o tap do node --test, o json do Vitest, o XUnit do swift test, o resultado
// do xcodebuild test ou, para qualquer outro comando, o arquivo de COUNT_FILE. Só esse outro comando
// recebe a variável: um node --test, um Vitest, um swift test ou um xcodebuild test aberto aqui não a
// herda de quem chamou o check.mjs, e nenhum processo dentro deles grava a conta de outra checagem.
export async function spawnCheck(check, count = () => {}) {
  let args, env, cwd, tmp, passed
  try {
    args = value(check.args) ?? []
    env = { ...process.env, ...value(check.env) }
    delete env[COUNT_FILE]
    cwd = path.resolve(ROOT, check.cwd ?? '.')
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
    if (isNodeTest(check.cmd, args)) {
      args = withTapFile(args, path.join(tmp, 'tap'))
      passed = () => passedTests(path.join(tmp, 'tap'))
    } else if (isVitest(check.cmd, args)) {
      args = withJsonFile(args, path.join(tmp, 'vitest.json'), await vitestScreen(cwd, env))
      passed = () => passedVitest(path.join(tmp, 'vitest.json'))
    } else if (isSwiftTest(check.cmd, args)) {
      args = withXunitFile(args, path.join(tmp, 'xunit.xml'))
      passed = () => passedXunit(tmp)
    } else if (isXcodebuildTest(check.cmd, args)) {
      const bundle = path.join(tmp, 'tests.xcresult')
      args = withResultBundle(args, bundle)
      passed = () => passedXcresult(bundle, env)
    } else {
      env[COUNT_FILE] = path.join(tmp, 'count')
      passed = () => passedTests(path.join(tmp, 'count'))
    }
  } catch (err) {
    console.error(`não deu para preparar "${check.name}": ${err.message}`)
    if (tmp) fs.rmSync(tmp, { recursive: true, force: true })
    return 1
  }
  return new Promise(resolve => {
    let settled = false
    const finish = code => {
      if (settled) return
      settled = true
      count(passed())
      fs.rmSync(tmp, { recursive: true, force: true })
      resolve(code)
    }
    const child = spawn(check.cmd, args, { cwd, env, stdio: 'inherit' })
    child.on('error', err => {
      console.error(`não deu para rodar ${check.cmd}: ${err.message}`)
      finish(1)
    })
    child.on('close', code => finish(code ?? 1))
  })
}

// Na ordem, parando na primeira que falhar. O run devolve o código de saída da checagem.
export async function runChecks(checks, run = spawnCheck) {
  for (const check of checks) {
    if ((await run(check)) !== 0) return { ok: false, failed: check.name }
  }
  return { ok: true }
}

// Parte por parte, na ordem, parando na primeira falha: uma checagem que falha, ou uma parte que,
// somadas as checagens, não rodou nenhum teste. O run é como o spawnCheck: recebe a checagem e um
// count, que chama com os testes que ela rodou, e devolve o código de saída.
export async function runParts(parts, run = spawnCheck) {
  for (const [part, checks] of Object.entries(parts)) {
    let tests = 0
    const result = await runChecks(checks, check => run(check, n => { tests += n }))
    if (!result.ok) return { ...result, part }
    if (tests === 0) return { ok: false, part, tests }
  }
  return { ok: true }
}

const shown = a => (/[\s"'\\]/.test(a) ? JSON.stringify(a) : a)

function describe(check) {
  const args = typeof check.args === 'function' ? [LATER] : (check.args ?? []).map(shown)
  const extra = []
  if (check.cwd) extra.push(`pasta: ${check.cwd}`)
  if (typeof check.env === 'function') extra.push(`env: ${LATER}`)
  else if (check.env) extra.push(`env: ${Object.entries(check.env).map(([k, v]) => `${k}=${shown(String(v))}`).join(' ')}`)
  return [check.cmd, ...args].join(' ') + extra.map(e => ` [${e}]`).join('')
}

async function main(argv) {
  const list = argv.includes('--list')
  let plan
  try {
    plan = planParts(argv.filter(a => a !== '--list'))
  } catch (err) {
    console.error(err.message)
    return 2
  }
  if (list) {
    for (const [part, checks] of Object.entries(plan)) {
      console.log(part)
      for (const check of checks) console.log(`  ${check.name}: ${describe(check)}`)
    }
    return 0
  }
  // Quantos testes cada parte que rodou contou, numa linha antes do resultado, que fica a última.
  const partOf = new Map(Object.entries(plan).flatMap(([part, checks]) => checks.map(c => [c, part])))
  const tests = {}
  const result = await runParts(plan, (check, count) => {
    console.log(`▶ ${check.name}`)
    const part = partOf.get(check)
    tests[part] ??= 0
    return spawnCheck(check, n => {
      tests[part] += n
      count(n)
    })
  })
  console.log(`testes contados: ${Object.entries(tests).map(([part, n]) => `${part} ${n}`).join(', ')}`)
  if (result.ok) {
    console.log('ok')
    return 0
  }
  if (result.tests === 0) {
    // Dentro de outro node --test, o NODE_TEST_CONTEXT herdado faz o node --test pular os
    // arquivos. Ele fica como veio: sem ele, o check.mjs chamado pelos próprios testes rodaria
    // esses testes de novo, sem fim.
    const ctx = process.env.NODE_TEST_CONTEXT
    const why = ctx === undefined ? '' : ` (com NODE_TEST_CONTEXT=${ctx} no ambiente, o node --test pula os arquivos)`
    console.error(`a parte ${result.part} não rodou nenhum teste${why}`)
    console.log(`falhou: ${result.part} (nenhum teste)`)
  } else {
    console.log(`falhou: ${result.failed}`)
  }
  return 1
}

// Chamado como script, e não importado: as duas pontas passam pelo realpath. Se o realpath do
// argv[1] falhar, nada roda, e o aviso no stderr diz isso, para a saída 0 não passar calada.
function isMain() {
  if (!process.argv[1]) return false
  try {
    return fs.realpathSync(process.argv[1]) === SELF
  } catch (err) {
    console.error(`check.mjs: nenhuma checagem rodou, porque não deu para saber se ele foi chamado como script (${err.message})`)
    return false
  }
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
