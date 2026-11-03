#!/usr/bin/env node
// As checagens do HexGym, por parte. É o comando de teste do projeto: o checks.test do
// .relentless/config.json, o QA e a CI chamam este mesmo script.
//
//   node scripts/hexgym/check.mjs                # todas as partes, na ordem do PARTS
//   node scripts/hexgym/check.mjs scripts        # só as partes pedidas
//   node scripts/hexgym/check.mjs --list         # mostra os comandos e não roda nada
//
// Node 22, sem dependências. Cada checagem é { name, cmd, args, cwd?, env? }: o cwd é
// relativo à raiz do repositório, e o env se soma ao process.env. O args e o env podem ser
// uma função que devolve o valor, chamada só quando aquela checagem vai rodar: assim, uma
// parte que precisa do Xcode não quebra as outras nem o --list numa máquina sem ele.

import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..')

// Sempre nesta ordem, e cada Task põe a sua parte no lugar dela:
// scripts, engine, load, packages, app.
export const PARTS = {
  scripts: [
    { name: 'testes dos scripts', cmd: 'node', args: ['--test', 'scripts/hexgym/*.test.mjs'] },
  ],
}

const LATER = '(calculado ao rodar)'
const value = x => (typeof x === 'function' ? x() : x)

// As partes pedidas, na ordem do PARTS; sem nenhuma, todas.
function partNames(parts) {
  const known = Object.keys(PARTS)
  for (const p of parts) {
    if (!known.includes(p)) throw new Error(`parte desconhecida: ${p} (partes: ${known.join(', ')})`)
  }
  return parts.length ? known.filter(p => parts.includes(p)) : known
}

export function planChecks(parts) {
  return partNames(parts).flatMap(p => PARTS[p])
}

// Roda uma checagem e devolve o código de saída. Um args ou env que não sai, ou um comando
// que nem começa, conta como falha dessa checagem, com o motivo no stderr.
export function spawnCheck(check) {
  return new Promise(resolve => {
    let args, env
    try {
      args = value(check.args) ?? []
      env = { ...process.env, ...value(check.env) }
    } catch (err) {
      console.error(`não deu para preparar "${check.name}": ${err.message}`)
      resolve(1)
      return
    }
    let settled = false
    const finish = code => {
      if (settled) return
      settled = true
      resolve(code)
    }
    const child = spawn(check.cmd, args, { cwd: path.resolve(ROOT, check.cwd ?? '.'), env, stdio: 'inherit' })
    child.on('error', err => {
      console.error(`não deu para rodar ${check.cmd}: ${err.message}`)
      finish(1)
    })
    child.on('close', code => finish(code ?? 1))
  })
}

// Na ordem, parando na primeira que falhar. O run devolve o código de saída da checagem.
export async function runChecks(checks, run = spawnCheck) {
  for (const check of checks) {
    if ((await run(check)) !== 0) return { ok: false, failed: check.name }
  }
  return { ok: true }
}

const shown = a => (/[\s"'\\]/.test(a) ? JSON.stringify(a) : a)

function describe(check) {
  const args = typeof check.args === 'function' ? [LATER] : (check.args ?? []).map(shown)
  const extra = []
  if (check.cwd) extra.push(`pasta: ${check.cwd}`)
  if (typeof check.env === 'function') extra.push(`env: ${LATER}`)
  else if (check.env) extra.push(`env: ${Object.entries(check.env).map(([k, v]) => `${k}=${shown(String(v))}`).join(' ')}`)
  return [check.cmd, ...args].join(' ') + extra.map(e => ` [${e}]`).join('')
}

async function main(argv) {
  const list = argv.includes('--list')
  const parts = argv.filter(a => a !== '--list')
  let checks
  try {
    checks = planChecks(parts)
  } catch (err) {
    console.error(err.message)
    return 2
  }
  if (list) {
    for (const p of partNames(parts)) {
      console.log(p)
      for (const check of PARTS[p]) console.log(`  ${check.name}: ${describe(check)}`)
    }
    return 0
  }
  const result = await runChecks(checks, check => {
    console.log(`▶ ${check.name}`)
    return spawnCheck(check)
  })
  console.log(result.ok ? 'ok' : `falhou: ${result.failed}`)
  return result.ok ? 0 : 1
}

function isMain() {
  try {
    return Boolean(process.argv[1]) && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)
  } catch {
    return false
  }
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
