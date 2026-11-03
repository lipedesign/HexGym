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

import { spawn } from 'node:child_process'
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

// Sempre nesta ordem, e cada Task põe a sua parte no lugar dela:
// scripts, engine, load, packages, app.
// Cada parte mostra quantos testes rodou, e a que não rodou nenhum falha. O spawnCheck conta os
// testes que passaram sempre por um arquivo que a ferramenta grava na pasta temporária da checagem,
// nunca pela saída da tela, e sem o arquivo a checagem conta zero:
//   - o node --test, por um segundo reporter, tap (por isso, a checagem não leva --test-reporter);
//   - o Vitest (npx vitest), por um segundo reporter, json (por isso, a checagem não leva --reporter
//     nem --outputFile, e o config dela não escolhe reporters);
//   - qualquer outro comando, pelo arquivo que o spawnCheck passa em HEXGYM_CHECK_COUNT_FILE, onde
//     ele grava quantos testes passaram no formato do fim do tap (# pass <n>). É o que o
//     engine-load.mjs faz, com as metas que conferiu e que passaram.
// Um comando que não grava nada (o build --check, o swift test ou o xcodebuild, por exemplo) conta
// zero, e a parte dele precisa de outra checagem que conte, ou de ensinar o spawnCheck a contar.
export const PARTS = {
  scripts: [
    { name: 'testes dos scripts', cmd: 'node', args: ['--test', 'scripts/hexgym/*.test.mjs'] },
  ],
  engine: [
    { name: 'script do motor em dia', cmd: 'node', args: ['scripts/build-hexgym-engine.mjs', '--check'] },
    { name: 'testes do script do motor', cmd: 'node', args: ['--test', 'apple/Packages/HexEngine/JS/*.test.mjs'] },
    { name: 'testes do lib contra o script', cmd: 'npx', args: ['vitest', 'run', '--config', 'vitest.hexengine.config.js'], cwd: 'frontend' },
  ],
  load: [
    { name: 'teste de carga do motor no jsc', cmd: 'node', args: ['scripts/hexgym/engine-load.mjs'] },
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

// Roda uma checagem e devolve o código de saída. Um args ou env que não sai, ou um comando
// que nem começa, conta como falha dessa checagem, com o motivo no stderr. O count recebe quantos
// testes passaram, pelo arquivo que a ferramenta gravou numa pasta própria em os.tmpdir(), que sai
// quando a checagem acaba: o tap do node --test, o json do Vitest ou, para qualquer outro comando,
// o arquivo de COUNT_FILE. Só esse outro comando recebe a variável: um node --test ou um Vitest
// aberto aqui não a herda de quem chamou o check.mjs, e nenhum processo dentro deles grava a conta
// de outra checagem.
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
