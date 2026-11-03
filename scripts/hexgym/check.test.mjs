// Testes do scripts/hexgym/check.mjs, o comando de teste do HexGym.
//
//   node --test scripts/hexgym/check.test.mjs
//
// A mensagem do teste "unknown part" lista as partes do PARTS: quem acrescenta
// uma parte atualiza a mensagem esperada aqui.
// Os dois testes do link simbólico (issue #39) chamam o check.mjs por links num diretório
// temporário, que cada um apaga no fim.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { PARTS, planChecks, runChecks } from './check.mjs'

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
