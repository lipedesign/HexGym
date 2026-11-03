#!/usr/bin/env node
// As checagens do HexGym, por parte. É o comando de teste do projeto: o checks.test do
// .relentless/config.json, o QA e a CI chamam este mesmo script.
//
//   node scripts/hexgym/check.mjs                # todas as partes, na ordem do PARTS
//   node scripts/hexgym/check.mjs scripts        # só as partes pedidas
//   node scripts/hexgym/check.mjs --list         # mostra os comandos e não roda nada
//
// Node 22, sem dependências. Cada checagem é { name, cmd, args, cwd?, env? }: o cwd é
// relativo à raiz do repositório, e o env se soma ao process.env. O args e o env podem ser
// uma função que devolve o valor, chamada só quando aquela checagem vai rodar: assim, uma
// parte que precisa do Xcode não quebra as outras nem o --list numa máquina sem ele.
// Uma parte só passa se as checagens dela passam e se, somadas, rodaram pelo menos um teste
// (issue #44): um node --test que não acha arquivo, ou que roda dentro de outro e pula os
// arquivos, sai com 0 sem testar nada.

import { spawn } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// O caminho de verdade deste arquivo, sem links. Chamado por um link simbólico com
// --preserve-symlinks-main, o import.meta.url fica com o caminho do link: o ROOT sairia de
// fora do repositório, e o isMain() não se reconheceria.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const ROOT = path.join(path.dirname(SELF), '..', '..')

// Sempre nesta ordem, e cada Task põe a sua parte no lugar dela:
// scripts, engine, load, packages, app.
// Cada parte mostra quantos testes rodou, e a que não rodou nenhum falha. Hoje, só o node --test
// mostra: o spawnCheck conta os testes que passaram nele por um segundo reporter (por isso, a
// checagem não leva --test-reporter). Uma parte sem node --test (só com o Vitest, o swift test ou
// o xcodebuild, por exemplo) precisa ensinar o spawnCheck a contar os testes dela; sem isso, ela
// conta zero e falha.
export const PARTS = {
  scripts: [
    { name: 'testes dos scripts', cmd: 'node', args: ['--test', 'scripts/hexgym/*.test.mjs'] },
  ],
  engine: [
    { name: 'script do motor em dia', cmd: 'node', args: ['scripts/build-hexgym-engine.mjs', '--check'] },
    { name: 'testes do script do motor', cmd: 'node', args: ['--test', 'apple/Packages/HexEngine/JS/*.test.mjs'] },
  ],
}

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

// Quantos testes passaram, pelo "# pass" do fim do tap: um teste pulado ou todo não conta. Sem o
// arquivo, nenhum: com o NODE_TEST_CONTEXT herdado de outro node --test, o Node pula os arquivos
// e não grava os reporters pedidos.
function passedTests(file) {
  let tap
  try {
    tap = fs.readFileSync(file, 'utf8')
  } catch (err) {
    if (err.code !== 'ENOENT') console.error(`não deu para ler quantos testes rodaram: ${err.message}`)
    return 0
  }
  const pass = [...tap.matchAll(/^# pass (\d+)$/gm)].at(-1)
  return pass ? Number(pass[1]) : 0
}

// Roda uma checagem e devolve o código de saída. Um args ou env que não sai, ou um comando
// que nem começa, conta como falha dessa checagem, com o motivo no stderr. Num node --test, o
// count recebe quantos testes passaram. O tap dele fica numa pasta própria em os.tmpdir(), que
// sai quando a checagem acaba.
export function spawnCheck(check, count = () => {}) {
  return new Promise(resolve => {
    let args, env, tmp
    try {
      args = value(check.args) ?? []
      env = { ...process.env, ...value(check.env) }
      if (isNodeTest(check.cmd, args)) {
        tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
        args = withTapFile(args, path.join(tmp, 'tap'))
      }
    } catch (err) {
      console.error(`não deu para preparar "${check.name}": ${err.message}`)
      resolve(1)
      return
    }
    let settled = false
    const finish = code => {
      if (settled) return
      settled = true
      if (tmp) {
        count(passedTests(path.join(tmp, 'tap')))
        fs.rmSync(tmp, { recursive: true, force: true })
      }
      resolve(code)
    }
    const child = spawn(check.cmd, args, { cwd: path.resolve(ROOT, check.cwd ?? '.'), env, stdio: 'inherit' })
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
  const result = await runParts(plan, (check, count) => {
    console.log(`▶ ${check.name}`)
    return spawnCheck(check, count)
  })
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
