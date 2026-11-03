// Testes do scripts/hexgym/record-engine-cases.mjs, que grava no Node, um arquivo por fuso, os
// casos que o JavaScriptCore confere no RecordedCasesTests.swift. Cada recordZone abre um processo
// filho com o TZ do fuso e não grava nada no disco.
//
//   node --test scripts/hexgym/record-engine-cases.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { recordZone } from './record-engine-cases.mjs'

test('the same zone recorded twice gives the same text', async () => {
  assert.equal(await recordZone('Europe/Zurich'), await recordZone('Europe/Zurich'))
})
test('each zone records its own instants', async () => {
  const start = async zone => JSON.parse(await recordZone(zone)).cases.find(c => c.fn === 'frontend/src/lib/format.js#isoOf').args[0].$date
  assert.notEqual(await start('Pacific/Auckland'), await start('Europe/Zurich'))
})
