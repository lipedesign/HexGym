// Testes do scripts/hexgym/xcode.mjs, que diz qual Xcode os comandos do HexGym usam. Nenhum deles
// olha o disco nem chama o xcode-select de verdade: o exists e o selected vêm de cada teste.
//
//   node --test scripts/hexgym/xcode.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { developerDir } from './xcode.mjs'

test('DEVELOPER_DIR wins', () => assert.equal(developerDir({ env: { DEVELOPER_DIR: '/x' }, exists: () => true }), '/x'))
test('Xcode.app comes first', () =>
  assert.equal(developerDir({ env: {}, exists: () => true }), '/Applications/Xcode.app/Contents/Developer'))
test('the beta is never chosen', () => assert.throws(
  () => developerDir({ env: {}, exists: p => p.includes('Xcode-beta'), selected: () => '/Library/Developer/CommandLineTools\n' }), /nenhum Xcode encontrado/))
test('xcode-select when it points to a full Xcode', () => assert.equal(
  developerDir({ env: {}, exists: () => false, selected: () => '/Applications/Xcode_27.2.app/Contents/Developer\n' }), '/Applications/Xcode_27.2.app/Contents/Developer'))
test('no Xcode says what to do', () => assert.throws(
  () => developerDir({ env: {}, exists: () => false, selected: () => '/Library/Developer/CommandLineTools\n' }), /nenhum Xcode encontrado: instale o Xcode 27\.2 ou defina DEVELOPER_DIR/))
test('swift packages fall back to the Command Line Tools, never the beta', () => assert.equal(
  developerDir({ env: {}, swiftOnly: true, exists: p => p.includes('Xcode-beta') || p.startsWith('/Library/Developer/CommandLineTools'), selected: () => '/Library/Developer/CommandLineTools\n' }), '/Library/Developer/CommandLineTools'))
test('swift packages still prefer Xcode.app', () => assert.equal(
  developerDir({ env: {}, swiftOnly: true, exists: () => true }), '/Applications/Xcode.app/Contents/Developer'))
