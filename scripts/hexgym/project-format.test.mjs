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
// Task 10 do plano da fase 1 (issue #64): o HexDesign entra como o HexEngine e o HexStore, um pacote
// local, e o produto vai para os quatro alvos do app, porque o logotipo está nos quatro. Task 8 do
// plano da fase 2 (issue #95): o HexBody entra do mesmo jeito, só no alvo HexGym, porque só o
// iPhone mostra o corpo nesta fase; os widgets e o Watch não o têm.
const TARGETS = ['HexGym', 'HexGymWidgets', 'HexGymWatch', 'HexGymWatchWidgets']
const PACKAGES = { HexDesign: TARGETS, HexBody: ['HexGym'] }
test('the HexDesign package is linked to the four app targets, and HexBody to the app only', () => {
  for (const [name, linked] of Object.entries(PACKAGES)) {
    assert.match(pbx, new RegExp(`relativePath = Packages/${name};`))
    const products = [...pbx.matchAll(new RegExp(`/\\* ${name} \\*/ = \\{\\s*isa = XCSwiftPackageProductDependency;\\s*productName = ${name};`, 'g'))]
    assert.equal(products.length, linked.length, `os produtos do ${name}`)
    for (const target of TARGETS) {
      const block = pbx.match(new RegExp(`/\\* ${target} \\*/ = \\{\\s*isa = PBXNativeTarget;[\\s\\S]*?packageProductDependencies = \\(([^)]*)\\);`))
      assert.ok(block, `o alvo ${target} existe`)
      const count = linked.includes(target) ? 1 : 0
      assert.equal([...block[1].matchAll(new RegExp(`/\\* ${name} \\*/`, 'g'))].length, count, `o ${name} no alvo ${target}`)
    }
  }
})
// Task 6 do plano da fase 3 (issue #135): os documentos preparados do -HexGymFixture só existem no build
// Debug. A pasta apple/HexGym é um grupo sincronizado do Xcode, sem exceções, e tudo nela entra nos dois
// builds; por isso, os dois arquivos ficam inteiros dentro de um #if DEBUG: a primeira linha de código
// abre o bloco, a última fecha, e nenhuma linha de código fica fora dele no meio. As linhas em branco e
// os comentários de linha não contam.
test('the prepared documents stay entirely inside #if DEBUG', () => {
  for (const name of ['FixtureLoader.swift', 'FixtureDocuments.swift']) {
    const code = fs.readFileSync(path.join(APPLE, 'HexGym', 'Fixtures', name), 'utf8')
      .split('\n').map(line => line.trim()).filter(line => line && !line.startsWith('//'))
    assert.equal(code[0], '#if DEBUG', `a primeira linha de código do ${name}`)
    assert.equal(code.at(-1), '#endif', `a última linha de código do ${name}`)
    let depth = 0
    code.forEach((line, i) => {
      if (/^#if\b/.test(line)) depth++
      if (/^#endif\b/.test(line)) depth--
      if (i < code.length - 1) assert.ok(depth >= 1, `a linha ${i + 1} de código do ${name} fica fora do #if DEBUG: ${line}`)
    })
    assert.equal(depth, 0, `os #if e os #endif do ${name}`)
  }
})
