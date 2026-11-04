// Testes do scripts/build-hexgym-langs.mjs, que gera os pacotes de idioma do motor do HexGym.
//
//   node --test scripts/hexgym/build-hexgym-langs.test.mjs
//
// O segundo teste mexe num pacote de uma cópia temporária da pasta dos pacotes, que sai no fim; os
// pacotes do repositório nunca mudam aqui.

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import zlib from 'node:zlib'
import crypto from 'node:crypto'
import { LANGS_DIR, main, readPack } from '../build-hexgym-langs.mjs'

const REPO = path.join(fs.realpathSync(import.meta.dirname), '..', '..')
const quiet = lines => ({ out: l => lines.push(l), err: l => lines.push(l) })

test('--check passes with the packs in the repository', async () => {
  const lines = []
  assert.equal(await main(['--check'], quiet(lines)), 0, lines.join('\n'))
})

test('--check fails with a pack that was changed, in a temporary copy', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hexgym-langs-'))
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }))
  fs.cpSync(path.join(REPO, LANGS_DIR), dir, { recursive: true })
  // O pacote mexido fica coerente com o index.json (o sha256 do texto novo), para o --check ter de
  // comparar com o que o build gera, e não só com o sha256.
  const pack = readPack('pt-BR', dir)
  pack.names['0025'] = 'supino mexido'
  const text = JSON.stringify(pack)
  fs.writeFileSync(path.join(dir, 'pt-BR.json.deflate'), zlib.deflateRawSync(Buffer.from(text), { level: 9 }))
  const index = JSON.parse(fs.readFileSync(path.join(dir, 'index.json'), 'utf8'))
  index['pt-BR'].sha256 = crypto.createHash('sha256').update(text).digest('hex')
  fs.writeFileSync(path.join(dir, 'index.json'), `${JSON.stringify(index, null, 2)}\n`)
  const lines = []
  assert.equal(await main(['--check'], { dir, ...quiet(lines) }), 1)
  assert.match(lines.join('\n'), /pt-BR/)
})

test('the pt-BR pack has the name of 0025 from frontend/src/exercise-names/pt-BR.js', async () => {
  const names = (await import('../../frontend/src/exercise-names/pt-BR.js')).default
  assert.equal(readPack('pt-BR').names['0025'], names['0025'])
})
