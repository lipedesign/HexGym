#!/usr/bin/env node
// Grava no Node os casos de contrato do motor (scripts/hexgym/engine-cases.mjs), um arquivo por fuso,
// para o RecordedCasesTests.swift conferir que o JavaScriptCore, rodando o script do motor, responde
// o mesmo que o código do openGym responde no V8 (seção 8.2 do design doc e Foco da revisão 5).
//
//   node scripts/hexgym/record-engine-cases.mjs           # grava os arquivos que mudaram
//   node scripts/hexgym/record-engine-cases.mjs --check   # só compara, e sai com 1 se um estiver velho
//
// Cada fuso de TIME_ZONES roda num processo filho com o TZ dele. O filho monta os casos e roda cada
// um nos módulos de frontend/src/lib, como o servidor MCP faz. A função recebe os argumentos como o
// call do motor os recebe, o encodeValue deles lido de volta pelo decodeValue (values.js). O caso
// gravado é { name, fn, args, ignore?, result }: o args é o encodeValue dos argumentos antes da
// chamada, e o result, o encodeValue de { returned, args } depois dela, sem os caminhos de ignore.
// O arquivo, apple/Packages/HexEngine/Tests/HexEngineTests/Cases/<fuso, com _ no lugar de />.json,
// é { "zone": …, "cases": […] }, com dois espaços de recuo.
//
// Node 22, sem dependências. Importar este arquivo não roda nada.

import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { TIME_ZONES, buildCases } from './engine-cases.mjs'

// O caminho de verdade deste arquivo, sem links, como no check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const ROOT = path.join(path.dirname(SELF), '..', '..')
const CASES = 'apple/Packages/HexEngine/Tests/HexEngineTests/Cases'
const VALUES = 'apple/Packages/HexEngine/JS/values.js'

// O arquivo de um fuso, a partir da raiz.
export const caseFile = zone => `${CASES}/${zone.replaceAll('/', '_')}.json`

const moduleUrl = file => pathToFileURL(path.join(ROOT, file)).href

// Tira da resposta um caminho de ignore, como "returned.id". Um caminho que não existe é um erro no
// caso, e não algo para pular calado.
function drop(result, where, name) {
  const keys = where.split('.')
  let at = result
  for (const k of keys.slice(0, -1)) at = at !== null && typeof at === 'object' ? at[k] : undefined
  const last = keys.at(-1)
  if (at === null || typeof at !== 'object' || !Object.hasOwn(at, last)) throw new Error(`o caso "${name}" ignora ${where}, que não está na resposta`)
  delete at[last]
}

// O que o filho faz, no fuso do TZ dele: os casos, cada um rodado e com a resposta.
export async function casesHere() {
  const { encodeValue, decodeValue } = await import(moduleUrl(VALUES))
  const load = file => import(moduleUrl(file))
  const recorded = []
  for (const c of await buildCases(load)) {
    const at = c.fn.lastIndexOf('#')
    const fn = (await load(c.fn.slice(0, at)))[c.fn.slice(at + 1)]
    if (typeof fn !== 'function') throw new Error(`o caso "${c.name}" chama ${c.fn}, que não é uma função`)
    const args = encodeValue(c.args)
    const given = decodeValue(JSON.parse(JSON.stringify(args)))
    const returned = fn(...given)
    const result = encodeValue({ returned, args: given })
    for (const where of c.ignore ?? []) drop(result, where, c.name)
    recorded.push({ name: c.name, fn: c.fn, args, ...(c.ignore ? { ignore: c.ignore } : {}), result })
  }
  return recorded
}

// O texto do arquivo de um fuso, com os casos rodados num processo filho com o TZ dele. O filho
// importa este arquivo e escreve os casos em JSON na saída; o erro dele vai para o stderr de quem
// chamou. O aviso MODULE_TYPELESS_PACKAGE_JSON do values.js (o package.json da raiz não tem
// "type": "module") fica de fora, porque não diz nada sobre os casos.
export function recordZone(zone) {
  const code = `const { casesHere } = await import(${JSON.stringify(pathToFileURL(SELF).href)})\nprocess.stdout.write(JSON.stringify(await casesHere()))`
  const args = ['--disable-warning=MODULE_TYPELESS_PACKAGE_JSON', '--input-type=module', '-e', code]
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, { cwd: ROOT, env: { ...process.env, TZ: zone }, stdio: ['ignore', 'pipe', 'inherit'] })
    const chunks = []
    child.stdout.on('data', chunk => chunks.push(chunk))
    child.on('error', err => reject(new Error(`não deu para rodar o Node para ${zone}: ${err.message}`)))
    child.on('close', (code, signal) => {
      if (code !== 0) return reject(new Error(`os casos de ${zone} não saíram: o Node saiu com ${code ?? signal}`))
      let cases
      try {
        cases = JSON.parse(Buffer.concat(chunks).toString('utf8'))
      } catch (err) {
        return reject(new Error(`os casos de ${zone} não vieram em JSON: ${err.message}`))
      }
      resolve(JSON.stringify({ zone, cases }, null, 2) + '\n')
    })
  })
}

// O texto guardado, ou null sem o arquivo. Outro erro de leitura sobe.
function stored(file) {
  try {
    return fs.readFileSync(path.join(ROOT, file), 'utf8')
  } catch (err) {
    if (err.code === 'ENOENT') return null
    throw err
  }
}

// A CLI. Os três fusos rodam juntos, cada um no seu processo. Sem --check, grava só o arquivo que
// mudou ou falta, e diz qual foi. Com --check, só compara, e sai com 1 quando um arquivo falta ou
// não bate. Devolve o código de saída.
export async function main(argv = []) {
  if (argv.some(a => a !== '--check')) {
    console.error('uso: node scripts/hexgym/record-engine-cases.mjs [--check]')
    return 2
  }
  const check = argv.includes('--check')
  let texts
  try {
    texts = await Promise.all(TIME_ZONES.map(recordZone))
  } catch (err) {
    console.error(err.message)
    return 1
  }
  let stale = 0
  for (const [i, zone] of TIME_ZONES.entries()) {
    const file = caseFile(zone), text = texts[i], current = stored(file)
    const count = JSON.parse(text).cases.length
    if (current === text) {
      console.log(`${file} está em dia (${count} casos).`)
    } else if (check) {
      console.error(`${file} está desatualizado. Rode: node scripts/hexgym/record-engine-cases.mjs`)
      stale++
    } else {
      fs.mkdirSync(path.join(ROOT, CASES), { recursive: true })
      fs.writeFileSync(path.join(ROOT, file), text)
      console.log(`Gravei ${file} (${count} casos), porque ${current === null ? 'ele faltava' : 'os casos mudaram'}.`)
    }
  }
  return stale ? 1 : 0
}

// Chamado como script, e não importado: as duas pontas passam pelo realpath. Um argv[1] que não
// existe (node -e, por exemplo, como no filho) quer dizer que não é este arquivo.
function isMain() {
  try {
    return Boolean(process.argv[1]) && fs.realpathSync(process.argv[1]) === SELF
  } catch {
    return false
  }
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
