// Testes do formato do apple/HexGym.xcodeproj (Task 9 do plano da fase 0, issue #21): o projeto fica
// no formato 77, com os quatro bundle IDs, o time, os mínimos de iOS 26 e watchOS 26, o ícone, as
// famílias de aparelho e o App Group nos quatro entitlements. Eles só leem os arquivos, sem o Xcode.
//
//   node --test scripts/hexgym/project-format.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const APPLE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'apple')
const pbx = fs.readFileSync(path.join(APPLE, 'HexGym.xcodeproj', 'project.pbxproj'), 'utf8')
const entitlements = ['HexGym', 'HexGymWidgets', 'HexGymWatch', 'HexGymWatchWidgets']
  .map(name => fs.readFileSync(path.join(APPLE, 'Config', `${name}.entitlements`), 'utf8'))

test('the project stays in the Xcode 16.0 format', () => {
  assert.match(pbx, /objectVersion = 77;/); assert.match(pbx, /preferredProjectObjectVersion = 77;/)
})
test('the four bundle IDs and the team are set', () => {
  for (const id of ['app.hexgym', 'app.hexgym.widgets', 'app.hexgym.watchkitapp', 'app.hexgym.watchkitapp.widgets'])
    assert.match(pbx, new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${id.replaceAll('.', '\\.')};`))
  assert.match(pbx, /DEVELOPMENT_TEAM = MPAGLMK4Q2;/); assert.doesNotMatch(pbx, /DEVELOPMENT_TEAM = (?!MPAGLMK4Q2;)/)
})
test('the deployment targets are 26.0', () => {
  assert.match(pbx, /IPHONEOS_DEPLOYMENT_TARGET = 26\.0;/); assert.match(pbx, /WATCHOS_DEPLOYMENT_TARGET = 26\.0;/)
  assert.doesNotMatch(pbx, /(IPHONEOS|WATCHOS)_DEPLOYMENT_TARGET = (?!26\.0;)/)
})
test('the app icon and the device families are set', () => {
  assert.ok(pbx.match(/ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/g)?.length >= 4)   // Debug e Release do app e do Watch
  assert.match(pbx, /TARGETED_DEVICE_FAMILY = 1;/); assert.match(pbx, /TARGETED_DEVICE_FAMILY = 4;/)
})
test('every target has the app group', () => {
  for (const f of entitlements) assert.match(f, /<string>group\.app\.hexgym<\/string>/)
})
