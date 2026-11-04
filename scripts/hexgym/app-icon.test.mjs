// Testes do ícone do HexGym (Task 12 do plano da fase 1, issue #66): os quatro PNGs que o
// app-icon.swift desenha têm 1024 × 1024, são RGB de 8 bits sem canal alfa (o App Store Connect
// recusa ícone com transparência), o iPhone tem as aparências normal, escura e tingida, e o Watch tem
// um ícone só. Eles só leem os arquivos, sem o Xcode.
//
//   node --test scripts/hexgym/app-icon.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const APPLE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'apple')
const PHONE = path.join(APPLE, 'HexGym', 'Assets.xcassets', 'AppIcon.appiconset')
const WATCH = path.join(APPLE, 'HexGymWatch', 'Assets.xcassets', 'AppIcon.appiconset')

const icons = [
  path.join(PHONE, 'AppIcon.png'), path.join(PHONE, 'AppIcon-dark.png'), path.join(PHONE, 'AppIcon-tinted.png'),
  path.join(WATCH, 'AppIcon.png'),
]
const phone = JSON.parse(fs.readFileSync(path.join(PHONE, 'Contents.json'), 'utf8'))
const watch = JSON.parse(fs.readFileSync(path.join(WATCH, 'Contents.json'), 'utf8'))

// O cabeçalho do PNG: a assinatura de 8 bytes, e logo depois o bloco IHDR (4 bytes de tamanho e 4 do
// nome), com a largura e a altura em 4 bytes cada, a profundidade e o tipo de cor (2 é RGB, sem alfa).
function ihdr(file) {
  const bytes = fs.readFileSync(file)
  assert.equal(bytes.toString('latin1', 12, 16), 'IHDR', `${file} não começa pelo IHDR`)
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), depth: bytes[24], colorType: bytes[25] }
}

test('every icon is 1024 square, RGB and without alpha', () => {
  for (const f of icons) assert.deepEqual(Object.values(ihdr(f)), [1024, 1024, 8, 2], f)
})
test('the iPhone icon has the any, dark and tinted looks', () => {
  assert.deepEqual(phone.images.map(i => i.appearances?.[0]?.value ?? 'any'), ['any', 'dark', 'tinted'])
  assert.ok(phone.images.every(i => i.size === '1024x1024' && i.platform === 'ios'))
})
test('the Watch has one icon', () => assert.deepEqual(watch.images.map(i => i.platform), ['watchos']))
