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

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { PARTS, planChecks, runChecks, runParts } from './check.mjs'

test('the scripts part runs the node tests of scripts/hexgym', () => {
  assert.deepEqual(planChecks(['scripts']).map(c => [c.cmd, ...c.args]), [['node', '--test', 'scripts/hexgym/*.test.mjs']])
})
test('no part means every part, in PARTS order', () => {
  assert.deepEqual(planChecks([]), Object.values(PARTS).flat())
})
test('an unknown part fails with the list of parts', () => {
  assert.throws(() => planChecks(['x']), /parte desconhecida: x \(partes: scripts\)/)
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
// ali, e nunca este arquivo, que se chamaria de novo. A cópia roda só a parte scripts, porque os
// arquivos das outras partes não estão na pasta.
function copiedCheck(t, files = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-check-'))
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }))
  const dir = path.join(tmp, 'scripts', 'hexgym')
  fs.mkdirSync(dir, { recursive: true })
  fs.copyFileSync(path.join(HERE, 'check.mjs'), path.join(dir, 'check.mjs'))
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
