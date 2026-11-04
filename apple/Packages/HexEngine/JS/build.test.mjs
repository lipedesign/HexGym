// Testes do scripts/build-hexgym-engine.mjs, o script do motor.
//
//   node --test apple/Packages/HexEngine/JS/build.test.mjs
//
// Cada buildEngine faz dois builds do Vite, o de sondagem e o de verdade; engine() guarda o
// primeiro do arquivo, para os testes que só leem o resultado. Os fixtures de test-fixtures/
// entram no build pelo extra, para ver cada recusa com o nome do módulo. O último teste grava o
// script com o io de verdade numa pasta temporária, apagada no fim.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import zlib from 'node:zlib'
import { buildEngine, cleanModules, engineIo, main } from '../../../../scripts/build-hexgym-engine.mjs'

const repo = path.join(fs.realpathSync(import.meta.dirname), '..', '..', '..', '..')
let first = null
const engine = () => (first ??= buildEngine(repo))

// Um io de mentira para o main: o build dá { code: built, modules: [] }, o readFile dá current,
// cada gravação fica em writes e o que vai para err fica em stderr.
function fakeIo({ built, current }) {
  const io = {
    writes: [], stdout: '', stderr: '',
    build: async () => ({ code: built, modules: [] }),
    readFile: async () => current,
    writeFile: async code => { io.writes.push(code) },
    out: line => { io.stdout += line + '\n' },
    err: line => { io.stderr += line + '\n' },
  }
  return io
}

const L = 'frontend/src/lib/'
test('a module is clean only when nothing it reaches leaves the engine folders', () => {
  const graph = {
    [L + 'a.js']: [L + 'b.js'], [L + 'b.js']: ['react'], [L + 'c.js']: [L + 'a.js'],
    [L + 'd.js']: [L + 'data.json', 'api/coach/core/x.js'], [L + 'data.json']: [], 'api/coach/core/x.js': [],
    [L + 'e.js']: ['frontend/src/store/useStore.js'], [L + 'f.js']: ['node:fs'],
    [L + 'g.js']: [L + 'h.js'], [L + 'h.js']: [L + 'g.js'], [L + 'i.js']: [L + 'j.js'], [L + 'j.js']: [L + 'i.js', '@capacitor/core'],
  }
  assert.deepEqual(cleanModules(graph), [L + 'd.js', L + 'g.js', L + 'h.js'])
})
test('the engine has what the app needs and none of the browser side', async () => {
  const { modules } = await engine()
  for (const m of ['progression', 'sync-merge', 'state-core', 'coach', 'duration', 'plan-share', 'exercises']) assert.ok(modules.includes(`${L}${m}.js`), m)
  for (const m of ['i18n', 'mobile', 'api', 'print-doc', 'plan-print']) assert.ok(!modules.includes(`${L}${m}.js`), m)
})
test('the script is the same on every run, whatever VITE_ variables the machine has', async () => {
  const { code } = await engine(); process.env.VITE_IMG_BASE = 'https://example.com/'
  try { assert.equal((await buildEngine(repo)).code, code) } finally { delete process.env.VITE_IMG_BASE }
})
test('the script has no path of this machine', async () => assert.ok(!(await engine()).code.includes(repo)))
test('a module forced in with a computed import fails the build', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/dynamic-import.js'] }), /o script do motor ficou com import dinâmico/)
})
test('a module forced in with import.meta fails with its name', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/import-meta.js'] }),
    /o motor não pode usar import\.meta \(em apple\/Packages\/HexEngine\/JS\/test-fixtures\/import-meta\.js\)/)
})
test('the script loads and answers', async () => {
  const E = new Function((await engine()).code + '\nreturn HexEngine')()
  assert.ok(JSON.parse(E.info()).exercises > 5000); const d = JSON.parse(E.freshDocument())
  assert.equal(d.langAuto, true); assert.equal(Object.hasOwn(d, 'lang'), false)
})
test('a module forced in that imports a package fails with its name', async () => {
  await assert.rejects(buildEngine(repo, { extra: ['apple/Packages/HexEngine/JS/test-fixtures/imports-react.js'] }),
    /o motor não pode importar react \(em apple\/Packages\/HexEngine\/JS\/test-fixtures\/imports-react\.js\)/)
})
test('--check reports a stale script and writes nothing', async () => {
  const io = fakeIo({ built: 'novo', current: 'velho' })
  assert.equal(await main(['--check'], io), 1); assert.match(io.stderr, /hexengine\.js está desatualizado/); assert.equal(io.writes.length, 0)
  assert.equal(await main(['--check'], fakeIo({ built: 'novo', current: 'novo' })), 0)
})
test('the real io keeps the script compressed with its sha256, rewrites only what changed, and --check sees a wrong sha256 and a missing file', async () => {
  const { code } = await engine(), dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hexengine-'))
  const at = name => path.join(dir, 'apple/Packages/HexEngine/Sources/HexEngine/Resources', name)
  const io = { ...engineIo(dir), build: async () => ({ code, modules: [] }), stdout: '', out: line => { io.stdout += line + '\n' }, err: () => {} }
  try {
    await io.writeFile(code); assert.equal(await io.readFile(), code); assert.equal(await main(['--check'], io), 0)
    const packed = fs.readFileSync(at('hexengine.js.deflate')); assert.ok(packed.subarray(0, 8000).includes(0), 'o git vê como binário')
    const level1 = zlib.deflateRawSync(code, { level: 1 }); assert.ok(!level1.equals(packed)); fs.writeFileSync(at('hexengine.js.deflate'), level1)
    assert.equal(await main(['--check'], io), 0); assert.equal(await main([], io), 0); assert.ok(fs.readFileSync(at('hexengine.js.deflate')).equals(level1))
    fs.writeFileSync(at('hexengine.js.sha256'), '0'.repeat(64) + '\n'); assert.equal(await main(['--check'], io), 1)
    assert.equal(await main([], io), 0); assert.match(io.stdout, /eles não batiam/); assert.equal(await main(['--check'], io), 0)
    assert.equal(await main([], { ...io, build: async () => ({ code: code + '// outro\n', modules: [] }) }), 0); assert.match(io.stdout, /o script mudou/)
    fs.rmSync(at('hexengine.js.deflate')); assert.equal(await main(['--check'], io), 1); assert.equal(await io.readFile(), null)
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})
