// Testes do scripts/hexgym/check.mjs, o comando de teste do HexGym.
//
//   node --test scripts/hexgym/check.test.mjs
//
// A mensagem do teste "unknown part" lista as partes do PARTS: quem acrescenta
// uma parte atualiza a mensagem esperada aqui.
// Os dois testes do link simbólico (issue #39) chamam o check.mjs por links num diretório
// temporário, que cada um apaga no fim.
// Os quatro testes da issue #44 (uma parte que não roda nenhum teste falha) vêm depois deles: a
// regra sem processo; os dois que rodam uma cópia do check.mjs numa pasta temporária, com ou sem
// o NODE_TEST_CONTEXT no ambiente; e o do aviso do isMain(), com uma pasta temporária vazia. Cada
// um apaga a sua pasta no fim.
// Os três da issue #18 (a conta do Vitest e a do engine-load.mjs) vêm depois, também com pastas
// temporárias, e nenhum roda o Vitest de verdade nem o jsc.
// Os cinco da issue #19 (a parte packages, a conta do swift test e a parte sem o swift) vêm no fim,
// com um swift e um xcode.mjs de mentira em pastas temporárias, e nenhum roda o swift de verdade.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { PARTS, planChecks, runChecks, runParts, spawnCheck } from './check.mjs'

test('the scripts part runs the node tests of scripts/hexgym', () => {
  assert.deepEqual(planChecks(['scripts']).map(c => [c.cmd, ...c.args]), [['node', '--test', 'scripts/hexgym/*.test.mjs']])
})
test('no part means every part, in PARTS order', () => {
  assert.deepEqual(planChecks([]), Object.values(PARTS).flat())
})
test('an unknown part fails with the list of parts', () => {
  assert.throws(() => planChecks(['x']), /parte desconhecida: x \(partes: scripts, engine, load, packages\)/)
})
test('runChecks stops at the first failure', async () => {
  const ran = []
  const r = await runChecks([{ name: 'a' }, { name: 'b' }, { name: 'c' }], async c => { ran.push(c.name); return c.name === 'b' ? 1 : 0 })
  assert.deepEqual(r, { ok: false, failed: 'b' }); assert.deepEqual(ran, ['a', 'b'])
})

const HERE = fs.realpathSync(import.meta.dirname)
const REPO = path.join(HERE, '..', '..')

// Um link para esta pasta, o caso da issue #39, e um para o próprio check.mjs, num diretório
// temporário que sai no fim do teste. O rmSync apaga os links, não o que eles apontam.
function linkedScripts(t) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  fs.symlinkSync(HERE, path.join(tmp, 'hexgym'))
  fs.symlinkSync(path.join(HERE, 'check.mjs'), path.join(tmp, 'check.mjs'))
  return [path.join(tmp, 'hexgym', 'check.mjs'), path.join(tmp, 'check.mjs')]
}

test('through a symlink, check.mjs runs as a script, with or without --preserve-symlinks-main', t => {
  for (const script of linkedScripts(t)) {
    for (const flags of [[], ['--preserve-symlinks-main']]) {
      const args = [...flags, script, '--list']
      const r = spawnSync(process.execPath, args, { encoding: 'utf8' })
      assert.equal(r.status, 0, `node ${args.join(' ')}: ${r.stderr}`)
      assert.match(r.stdout, /^scripts\n/, `node ${args.join(' ')}`)
    }
  }
})

// Rodar a parte scripts pelo link chamaria este arquivo de novo, e o node --test aninhado num
// teste pula os arquivos e sai com 0: por isso a checagem aqui só mostra a pasta em que rodou,
// e a saída é só essa pasta, porque importado o check.mjs não roda nada. O --preserve-symlinks
// deixa o import.meta.url com o caminho do link, como o --preserve-symlinks-main faz com o
// script chamado direto.
test('through a symlink, the checks still run at the root of the repository', t => {
  for (const script of linkedScripts(t)) {
    const code = `const { spawnCheck } = await import(${JSON.stringify(pathToFileURL(script).href)})
process.exitCode = await spawnCheck({ name: 'pasta', cmd: process.execPath, args: ['-p', 'process.cwd()'] })`
    const r = spawnSync(process.execPath, ['--preserve-symlinks', '--input-type=module', '-e', code], { encoding: 'utf8' })
    assert.equal(r.status, 0, `${script}: ${r.stderr}`)
    assert.equal(r.stdout, `${REPO}\n`, script)
  }
})

// A regra da issue #44 sem processo: o run de mentira conta os testes de cada checagem e devolve
// o código dela. A parte engine tem a forma da Task 5, uma checagem que não é teste e uma que é.
test('a part passes when its checks pass and, together, ran at least one test', async () => {
  const ran = []
  const run = async (check, count) => { ran.push(check.name); count(check.tests ?? 0); return check.code ?? 0 }
  const engine = [{ name: 'script do motor em dia' }, { name: 'testes do script do motor', tests: 3 }]
  assert.deepEqual(await runParts({ engine }, run), { ok: true })
  assert.deepEqual(await runParts({ load: [{ name: 'carga' }], engine }, run), { ok: false, part: 'load', tests: 0 })
  assert.deepEqual(await runParts({ engine: [{ name: 'quebrado', code: 1 }, ...engine] }, run), { ok: false, failed: 'quebrado', part: 'engine' })
  assert.deepEqual(ran, ['script do motor em dia', 'testes do script do motor', 'carga', 'quebrado'])
})

// Uma cópia do check.mjs numa pasta temporária, que sai no fim do teste, com os arquivos pedidos
// ao lado dela. A raiz da cópia é essa pasta: a parte scripts só acha os testes que estiverem
// ali, e nunca este arquivo, que se chamaria de novo. A cópia roda a parte scripts e, com um
// engine-load.mjs de mentira ao lado dela, a parte load; os arquivos da parte engine não estão
// na pasta. Os dois módulos que o check.mjs importa (xcode.mjs e engine-cases.mjs, desde a issue
// #19) vão junto, porque sem eles a cópia nem abre; nenhum dos dois é teste.
function copiedCheck(t, files = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  const dir = path.join(tmp, 'scripts', 'hexgym')
  fs.mkdirSync(dir, { recursive: true })
  for (const name of ['check.mjs', 'xcode.mjs', 'engine-cases.mjs']) fs.copyFileSync(path.join(HERE, name), path.join(dir, name))
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, name), text)
  return path.join(dir, 'check.mjs')
}

// Todo processo aberto por um node --test herda o NODE_TEST_CONTEXT=child dele. Cada caso diz o
// ambiente que quer: sem a variável, ou com ela.
const { NODE_TEST_CONTEXT: _, ...WITHOUT_CONTEXT } = process.env
const ONE_TEST = "import { test } from 'node:test'\ntest('um', () => {})\n"
const runScripts = (script, env) => spawnSync(process.execPath, [script, 'scripts'], { encoding: 'utf8', env })

test('check.mjs fails when a part finds no test file', t => {
  const r = runScripts(copiedCheck(t), WITHOUT_CONTEXT)
  assert.equal(r.status, 1, r.stdout)
  assert.match(r.stderr, /a parte scripts não rodou nenhum teste/)
  assert.match(r.stdout, /\nfalhou: scripts \(nenhum teste\)\n$/)
})
test('check.mjs counts the tests that node --test ran, and fails when NODE_TEST_CONTEXT makes it skip them', t => {
  const script = copiedCheck(t, { 'um.test.mjs': ONE_TEST })
  const ran = runScripts(script, WITHOUT_CONTEXT)
  assert.equal(ran.status, 0, ran.stderr)
  assert.match(ran.stdout, /\nok\n$/)
  const skipped = runScripts(script, { ...WITHOUT_CONTEXT, NODE_TEST_CONTEXT: 'child' })
  assert.equal(skipped.status, 1, skipped.stdout)
  assert.match(skipped.stderr, /a parte scripts não rodou nenhum teste/)
  assert.match(skipped.stdout, /\nfalhou: scripts \(nenhum teste\)\n$/)
})

// O isMain() que não lê o argv[1] não sai calado. Com o -e, o argv[1] é o primeiro argumento
// depois do código: aqui, um caminho que não existe, dentro de uma pasta temporária vazia.
test('check.mjs says on stderr that nothing ran when it cannot tell whether it is the script', t => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  const code = `await import(${JSON.stringify(pathToFileURL(path.join(HERE, 'check.mjs')).href)})`
  const r = spawnSync(process.execPath, ['--input-type=module', '-e', code, path.join(tmp, 'nao-existe')], { encoding: 'utf8' })
  assert.equal(r.status, 0, r.stderr)
  assert.equal(r.stdout, '')
  assert.match(r.stderr, /check\.mjs: nenhuma checagem rodou/)
})

// A conta da issue #18. A parte load roda numa cópia do check.mjs com um engine-load.mjs de mentira,
// que grava a conta no arquivo de HEXGYM_CHECK_COUNT_FILE como o de verdade grava, ou não grava
// nada. O Vitest é um npx de mentira (fakeVitest).
const COUNTED = "import fs from 'node:fs'\nfs.writeFileSync(process.env.HEXGYM_CHECK_COUNT_FILE, '# tests 3\\n# pass 3\\n# fail 0\\n')\n"
const runPart = (script, part, env) => spawnSync(process.execPath, [script, part], { encoding: 'utf8', env })

test('the load part counts what engine-load.mjs writes in the file of HEXGYM_CHECK_COUNT_FILE, and fails without the file', t => {
  const counted = runPart(copiedCheck(t, { 'engine-load.mjs': COUNTED }), 'load', WITHOUT_CONTEXT)
  assert.equal(counted.status, 0, counted.stderr)
  assert.match(counted.stdout, /\ntestes contados: load 3\nok\n$/)
  const silent = runPart(copiedCheck(t, { 'engine-load.mjs': '' }), 'load', WITHOUT_CONTEXT)
  assert.equal(silent.status, 1, silent.stdout)
  assert.match(silent.stderr, /a parte load não rodou nenhum teste/)
  assert.match(silent.stdout, /\ntestes contados: load 0\nfalhou: load \(nenhum teste\)\n$/)
})

// Um Vitest de mentira, numa pasta que sai no fim do teste: o vitest e o std-env que o spawnCheck lê
// para escolher os reporters da tela (com o isAgent pedido) e um npx que guarda os argumentos que
// recebeu e, com report, grava no arquivo do --outputFile.json um relatório com 7 testes que
// passaram. O npx é um sh que chama o Node, para o caminho dele acabar em npx.
function fakeVitest(t, { isAgent, report = true }) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  const files = {
    'node_modules/vitest/package.json': '{"name":"vitest","version":"0.0.0"}\n',
    'node_modules/std-env/package.json': '{"name":"std-env","type":"module","exports":"./index.mjs"}\n',
    'node_modules/std-env/index.mjs': `export const isAgent = ${isAgent}\n`,
    'npx.cjs': [
      "const fs = require('node:fs')",
      'const argv = process.argv.slice(2)',
      `fs.writeFileSync(${JSON.stringify(path.join(tmp, 'args.json'))}, JSON.stringify(argv))`,
      ...(report ? [
        "const out = argv.find(a => a.startsWith('--outputFile.json='))",
        "fs.writeFileSync(out.slice('--outputFile.json='.length), JSON.stringify({ numPassedTests: 7, numTotalTests: 8 }))",
      ] : []),
    ].join('\n') + '\n',
    npx: `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(path.join(tmp, 'npx.cjs'))} "$@"\n`,
  }
  for (const [name, text] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(tmp, name)), { recursive: true })
    fs.writeFileSync(path.join(tmp, name), text)
  }
  fs.chmodSync(path.join(tmp, 'npx'), 0o755)
  return { cwd: tmp, cmd: path.join(tmp, 'npx'), args: () => JSON.parse(fs.readFileSync(path.join(tmp, 'args.json'), 'utf8')) }
}

test('a Vitest check counts the passed tests of its json report, with the screen reporters Vitest would pick', async t => {
  for (const [isAgent, actions, screen] of [[false, 'false', ['default']], [true, 'true', ['agent', 'github-actions']]]) {
    const vitest = fakeVitest(t, { isAgent })
    let tests
    const check = { name: 'vitest', cmd: vitest.cmd, args: ['vitest', 'run', '--config', 'x.config.js'], cwd: vitest.cwd, env: { GITHUB_ACTIONS: actions } }
    assert.equal(await spawnCheck(check, n => { tests = n }), 0)
    assert.equal(tests, 7)
    const argv = vitest.args(), json = argv.find(a => a.startsWith('--outputFile.json='))
    assert.deepEqual(argv, ['vitest', 'run', ...screen.map(r => `--reporter=${r}`), '--reporter=json', json, '--config', 'x.config.js'])
    assert.ok(!fs.existsSync(path.dirname(json.slice('--outputFile.json='.length))), 'a pasta da checagem sai no fim')
  }
})
test('a Vitest that writes no report counts zero, and its part fails', async t => {
  const vitest = fakeVitest(t, { isAgent: false, report: false })
  const engine = [{ name: 'vitest', cmd: vitest.cmd, args: ['vitest', 'run'], cwd: vitest.cwd, env: { GITHUB_ACTIONS: 'false' } }]
  assert.deepEqual(await runParts({ engine }), { ok: false, part: 'engine', tests: 0 })
})

// A parte packages da issue #19, sem rodar nada: o swift test de todos os testes do HexEngine no
// primeiro fuso, e o dos casos gravados em cada um dos outros dois, com o que o primeiro compilou. O
// DEVELOPER_DIR do ambiente ganha do resto no developerDir, então o args e o env saem iguais em
// qualquer máquina: com /x, o swiftTestFlags não dá nenhum argumento.
test('the packages part runs every HexEngine test in the first zone, and the recorded cases in each other zone', t => {
  const before = process.env.DEVELOPER_DIR
  t.after(() => { if (before === undefined) delete process.env.DEVELOPER_DIR; else process.env.DEVELOPER_DIR = before })
  process.env.DEVELOPER_DIR = '/x'
  const hexengine = ['swift', 'test', '--package-path', 'apple/Packages/HexEngine']
  const recorded = [...hexengine, '--skip-build', '--filter', 'RecordedCasesTests']
  assert.deepEqual(PARTS.packages.map(c => [c.cmd, ...c.args()]), [hexengine, recorded, recorded])
  assert.deepEqual(PARTS.packages.map(c => c.env()), ['America/Sao_Paulo', 'Europe/Zurich', 'Pacific/Auckland'].map(
    zone => ({ DEVELOPER_DIR: '/x', TZ: zone, HEXGYM_CASES: zone })))
  assert.ok(PARTS.engine.some(c => [c.cmd, ...c.args].join(' ') === 'node scripts/hexgym/record-engine-cases.mjs --check'))
})

// Um swift de mentira, numa pasta que sai no fim do teste: um sh que chama o Node, para o caminho
// dele acabar em swift, e guarda, de cada chamada, os argumentos que recebeu e o
// HEXGYM_CHECK_COUNT_FILE, o TZ, o HEXGYM_CASES e o DEVELOPER_DIR que herdou.
// Com report, ele grava no arquivo do --xunit-output um XUnit como o do Swift Testing, com dois
// testes que passaram, um pulado, um que falhou e um com erro, e ao lado dele o arquivo com
// -swift-testing no nome, que o Xcode completo grava, com mais um que passou.
const XUNIT = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
<testsuite name="TestResults" errors="1" tests="5" failures="1" skipped="1" time="0.01">
<testcase classname="HexEngineTests" name="passa()" time="0.001" />
<testcase classname="HexEngineTests" name="1 > 0()" time="0.001">
<system-out>um texto com a palavra skipped</system-out>
</testcase>
<testcase classname="HexEngineTests" name="pulado()" time="0">
<skipped />
</testcase>
<testcase classname="HexEngineTests" name="falha()" time="0.001">
<failure message="esperava 1" />
</testcase>
<testcase classname="HexEngineTests" name="erro()" time="0.001">
<error message="lançou" />
</testcase>
</testsuite>
</testsuites>
`
const XUNIT_SWIFT_TESTING = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
<testsuite name="TestResults" errors="0" tests="1" failures="0" skipped="0" time="0.01">
<testcase classname="RecordedCasesTests" name="casos()" time="0.001" />
</testsuite>
</testsuites>
`
function fakeSwift(t, { report }) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  const seen = path.join(tmp, 'seen.jsonl')
  const files = {
    'swift.cjs': [
      "const fs = require('node:fs')",
      'const argv = process.argv.slice(2)',
      "const { HEXGYM_CHECK_COUNT_FILE: countFile = null, TZ: tz = null, HEXGYM_CASES: cases = null, DEVELOPER_DIR: dev = null } = process.env",
      `fs.appendFileSync(${JSON.stringify(seen)}, JSON.stringify({ argv, countFile, tz, cases, dev }) + '\\n')`,
      ...(report ? [
        "const out = argv[argv.indexOf('--xunit-output') + 1]",
        `fs.writeFileSync(out, ${JSON.stringify(XUNIT)})`,
        `fs.writeFileSync(out.replace(/\\.xml$/, '-swift-testing.xml'), ${JSON.stringify(XUNIT_SWIFT_TESTING)})`,
      ] : []),
    ].join('\n') + '\n',
    swift: `#!/bin/sh\nexec ${JSON.stringify(process.execPath)} ${JSON.stringify(path.join(tmp, 'swift.cjs'))} "$@"\n`,
  }
  for (const [name, text] of Object.entries(files)) fs.writeFileSync(path.join(tmp, name), text)
  fs.chmodSync(path.join(tmp, 'swift'), 0o755)
  return { cwd: tmp, cmd: path.join(tmp, 'swift'), seen: () => fs.readFileSync(seen, 'utf8').trim().split('\n').map(l => JSON.parse(l)) }
}

test('a swift test check counts the passed test cases of its XUnit files, and does not get HEXGYM_CHECK_COUNT_FILE', async t => {
  const swift = fakeSwift(t, { report: true })
  let tests
  const check = { name: 'swift', cmd: swift.cmd, args: ['test', '--package-path', 'x', '--filter', 'Casos'], cwd: swift.cwd }
  assert.equal(await spawnCheck(check, n => { tests = n }), 0)
  assert.equal(tests, 3)
  const [{ argv, countFile }] = swift.seen(), xunit = argv[2]
  assert.deepEqual(argv, ['test', '--xunit-output', xunit, '--package-path', 'x', '--filter', 'Casos'])
  assert.equal(countFile, null)
  assert.ok(!fs.existsSync(path.dirname(xunit)), 'a pasta da checagem sai no fim')
})
test('a swift test that writes no XUnit counts zero, and its part fails', async t => {
  const swift = fakeSwift(t, { report: false })
  const packages = [{ name: 'swift', cmd: swift.cmd, args: ['test'], cwd: swift.cwd }]
  assert.deepEqual(await runParts({ packages }), { ok: false, part: 'packages', tests: 0 })
})

// A parte packages de ponta a ponta, numa cópia do check.mjs: um xcode.mjs de mentira, que dá um
// DEVELOPER_DIR e dois argumentos marcados para ele, e o swift de mentira no começo do PATH. As três
// rodadas levam os mesmos argumentos, inclusive as duas com --skip-build, e cada uma o seu fuso.
const MARKED = [
  "export function developerDir() { return '/caminho/de/mentira' }",
  "export function swiftTestFlags(dir) { return dir === '/caminho/de/mentira' ? ['-Xswiftc', '-marca'] : [] }",
].join('\n') + '\n'
test('every swift test of the packages part gets the same swiftTestFlags, and its own zone', t => {
  const swift = fakeSwift(t, { report: true })
  const r = runPart(copiedCheck(t, { 'xcode.mjs': MARKED }), 'packages', { ...WITHOUT_CONTEXT, PATH: `${swift.cwd}${path.delimiter}${process.env.PATH}` })
  assert.equal(r.status, 0, r.stderr)
  assert.match(r.stdout, /\ntestes contados: packages 9\nok\n$/)
  const calls = swift.seen()
  assert.deepEqual(calls.map(c => c.argv.slice(0, 2)), [['test', '--xunit-output'], ['test', '--xunit-output'], ['test', '--xunit-output']])
  const flags = ['-Xswiftc', '-marca', '--package-path', 'apple/Packages/HexEngine']
  assert.deepEqual(calls.map(({ argv, tz, cases, dev }) => ({ rest: argv.slice(3), tz, cases, dev })), [
    { rest: flags, tz: 'America/Sao_Paulo', cases: 'America/Sao_Paulo', dev: '/caminho/de/mentira' },
    { rest: [...flags, '--skip-build', '--filter', 'RecordedCasesTests'], tz: 'Europe/Zurich', cases: 'Europe/Zurich', dev: '/caminho/de/mentira' },
    { rest: [...flags, '--skip-build', '--filter', 'RecordedCasesTests'], tz: 'Pacific/Auckland', cases: 'Pacific/Auckland', dev: '/caminho/de/mentira' },
  ])
})

// Sem o swift: o developerDir do xcode.mjs de mentira lança como o de verdade numa máquina sem Xcode
// nem Command Line Tools. A cópia abre, o --list e a parte scripts seguem, e só a packages falha, ao
// preparar a primeira checagem dela.
const NO_SWIFT = [
  "export function developerDir() { throw new Error('nenhum Xcode encontrado: instale o Xcode 27.2 ou defina DEVELOPER_DIR') }",
  'export function swiftTestFlags() { return [] }',
].join('\n') + '\n'
test('without swift, only the packages part fails', t => {
  const script = copiedCheck(t, { 'um.test.mjs': ONE_TEST, 'xcode.mjs': NO_SWIFT })
  const list = runPart(script, '--list', WITHOUT_CONTEXT)
  assert.equal(list.status, 0, list.stderr)
  assert.match(list.stdout, /\npackages\n {2}HexEngine, com os casos gravados em America\/Sao_Paulo: swift \(calculado ao rodar\) \[env: \(calculado ao rodar\)\]\n/)
  const r = spawnSync(process.execPath, [script, 'scripts', 'packages'], { encoding: 'utf8', env: WITHOUT_CONTEXT })
  assert.equal(r.status, 1, r.stdout)
  assert.match(r.stderr, /não deu para preparar "HexEngine, com os casos gravados em America\/Sao_Paulo": nenhum Xcode encontrado/)
  assert.match(r.stdout, /\ntestes contados: scripts 1, packages 0\nfalhou: HexEngine, com os casos gravados em America\/Sao_Paulo\n$/)
})
