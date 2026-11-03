// Testes do scripts/hexgym/xcode.mjs, que diz qual Xcode os comandos do HexGym usam e quais
// argumentos o swift test leva com ele. Nenhum deles olha o disco nem chama o xcode-select de
// verdade: o exists e o selected vêm de cada teste. Os sete primeiros são os da issue #19; depois
// vêm o do xcode-select que aponta para o beta e os quatro do swiftTestFlags.
//
//   node --test scripts/hexgym/xcode.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { CLT, developerDir, swiftTestFlags } from './xcode.mjs'

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
test('the beta is refused when xcode-select points to it', () => assert.throws(
  () => developerDir({ env: {}, exists: p => p.includes('Xcode-beta'), selected: () => '/Applications/Xcode-beta.app/Contents/Developer\n' }), /nenhum Xcode encontrado/))

const PLUGIN = '/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib'
const FLAGS = ['-Xswiftc', '-load-plugin-library', '-Xswiftc', PLUGIN]
test('the Command Line Tools with the TestingMacros plugin get the four flags', () => {
  assert.equal(CLT, '/Library/Developer/CommandLineTools')
  assert.deepEqual(swiftTestFlags(CLT, { exists: p => p === PLUGIN }), FLAGS)
})
test('the Command Line Tools without the plugin get none', () =>
  assert.deepEqual(swiftTestFlags(CLT, { exists: () => false }), []))
test('Xcode.app, or a DEVELOPER_DIR somewhere else, gets none', () => {
  assert.deepEqual(swiftTestFlags('/Applications/Xcode.app/Contents/Developer', { exists: () => true }), [])
  assert.deepEqual(swiftTestFlags(developerDir({ env: { DEVELOPER_DIR: '/x' }, swiftOnly: true }), { exists: () => true }), [])
})
test('a DEVELOPER_DIR that points to the Command Line Tools gets the four flags', () => assert.deepEqual(
  swiftTestFlags(developerDir({ env: { DEVELOPER_DIR: '/Library/Developer/CommandLineTools/' }, swiftOnly: true }), { exists: p => p === PLUGIN }), FLAGS))
