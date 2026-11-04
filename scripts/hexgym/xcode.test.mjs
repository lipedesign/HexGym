// Testes do scripts/hexgym/xcode.mjs, que diz qual Xcode os comandos do HexGym usam e quais
// argumentos o swift test leva com ele. Nenhum deles olha o disco nem chama o xcode-select de
// verdade: o exists e o selected vêm de cada teste. Os sete primeiros são os da issue #19; depois
// vêm o do xcode-select que aponta para o beta e os quatro do swiftTestFlags. O do pickSimulator, da
// issue #22, vem no fim, com um JSON no formato do xcrun simctl list devices available --json.
//
//   node --test scripts/hexgym/xcode.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import * as xcode from './xcode.mjs'
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

// Um iPhone 17 no iOS 26.4, e um iPad e um iPhone 17 Pro no iOS 27.0, o iPad antes: o iOS mais novo
// ganha, e nele, o primeiro aparelho com o nome começando por iPhone. Sem nenhum iPhone no iOS 26 ou
// acima (um no 18.6, e só o iPad no 27.0), o erro diz o que falta.
// Pelo namespace, e não por um import com nome: sem o pickSimulator, só este teste falha, e os outros
// rodam.
const { pickSimulator } = xcode
const runtime = version => `com.apple.CoreSimulator.SimRuntime.iOS-${version}`
const device = (udid, name) => ({ udid, name, isAvailable: true, state: 'Shutdown', deviceTypeIdentifier: `com.apple.CoreSimulator.SimDeviceType.${name.replaceAll(' ', '-')}` })
const IPAD = device('0E263758-BDC6-4924-930C-6D2FC92A545D', 'iPad (A16)')
test('pickSimulator picks the first iPhone of the newest iOS that is 26 or later', () => {
  const json = JSON.stringify({ devices: {
    [runtime('26-4')]: [device('A0C4D3F2-C323-4966-8241-83A9FDADD60E', 'iPhone 17')],
    [runtime('27-0')]: [IPAD, device('C7976575-8AEE-427B-AB22-EB5C92AE5817', 'iPhone 17 Pro')],
  } })
  assert.equal(pickSimulator(json), 'C7976575-8AEE-427B-AB22-EB5C92AE5817')
  const none = JSON.stringify({ devices: { [runtime('18-6')]: [device('B8C9992E-9C57-458D-A14C-11DAB1126D70', 'iPhone 16')], [runtime('27-0')]: [IPAD] } })
  assert.throws(() => pickSimulator(none), { name: 'Error', message: /nenhum simulador de iPhone com iOS 26 ou mais novo/ })
})
