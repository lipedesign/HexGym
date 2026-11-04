#!/usr/bin/env node
// Os pacotes de idioma do motor do HexGym (seção 8.9 do design doc). O dicionário das telas, os
// nomes, os passos e as descrições dos exercícios ficam em módulos de frontend/src fora do lib, que
// o app web carrega sob demanda pelo import.meta.glob do Vite; o script do motor não leva nenhum
// deles. Este build junta, para cada idioma do LANGS do openGym, os quatro num JSON só:
//
//   { "lang", "dict", "names", "instr", "desc" }
//
// a partir de frontend/src/locales/<idioma>.js, exercise-names/<idioma>.js, instr/<idioma>.js e
// exercise-desc/<idioma>.js, lidos com import() do Node (o que falta fica null). O pt-BR já vem com a
// herança do pt, porque o próprio locales/pt-BR.js importa o pt.js. O pacote en leva só o instr/en.js
// e o exercise-desc/en.js, que todo idioma usa quando o dele não tem o exercício. Um idioma derivado
// (o de-CH, do DERIVED_LOCALES do i18n-core.js) não tem pacote: o index.json aponta para o arquivo
// do idioma base, e o setLanguage do motor (apple/Packages/HexEngine/JS/language.js) aplica o
// derivePack.
//
// Cada pacote vai comprimido em DEFLATE cru no nível 9, como o script do motor, em
// apple/Packages/HexEngine/Sources/HexEngine/Resources/langs/<idioma>.json.deflate, e o index.json ao
// lado diz, para cada idioma do LANGS, o arquivo e o sha256 do texto: { "<idioma>": { "file",
// "sha256" } }. Nada de frontend/ muda.
//
//   node scripts/build-hexgym-langs.mjs           # grava os pacotes que mudaram e o index.json
//   node scripts/build-hexgym-langs.mjs --check   # só compara, e sai com 1 se algum estiver velho
//
// Node 22, sem dependência nova.

import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import zlib from 'node:zlib'

// O caminho de verdade deste arquivo, sem links, como no scripts/build-hexgym-engine.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const REPO = path.join(path.dirname(SELF), '..')

// A pasta dos pacotes, a partir da raiz.
export const LANGS_DIR = 'apple/Packages/HexEngine/Sources/HexEngine/Resources/langs'
const SRC = 'frontend/src'
const INDEX = 'index.json'
const fileOf = lang => `${lang}.json.deflate`
const sha256 = text => crypto.createHash('sha256').update(text).digest('hex')

// O export default de um módulo de frontend/src, ou null quando o arquivo não existe.
async function defaultOf(repo, rel) {
  const file = path.join(repo, SRC, rel)
  if (!fs.existsSync(file)) return null
  return (await import(pathToFileURL(file).href)).default ?? null
}

// Os pacotes e o index.json, em texto, como o build grava: { packs: { <idioma>: texto }, index:
// texto }. Um idioma do LANGS que não tem nenhuma das quatro partes fica sem pacote e fora do índice,
// e o motor cai no inglês; o en sempre tem.
export async function buildLangs(repo = REPO) {
  const { LANGS, DERIVED_LOCALES } = await import(pathToFileURL(path.join(repo, SRC, 'lib/i18n-core.js')).href)
  const packs = {}
  for (const lang of Object.keys(LANGS)) {
    if (DERIVED_LOCALES[lang]) continue
    const pack = {
      lang,
      dict: lang === 'en' ? null : await defaultOf(repo, `locales/${lang}.js`),
      names: lang === 'en' ? null : await defaultOf(repo, `exercise-names/${lang}.js`),
      instr: await defaultOf(repo, `instr/${lang}.js`),
      desc: await defaultOf(repo, `exercise-desc/${lang}.js`),
    }
    if (lang !== 'en' && !pack.dict && !pack.names && !pack.instr && !pack.desc) continue
    packs[lang] = JSON.stringify(pack)
  }
  const index = {}
  for (const lang of Object.keys(LANGS)) {
    const base = DERIVED_LOCALES[lang]?.base ?? lang
    if (packs[base] !== undefined) index[lang] = { file: fileOf(base), sha256: sha256(packs[base]) }
  }
  return { packs, index: `${JSON.stringify(index, null, 2)}\n` }
}

// Um pacote guardado, lido de volta como objeto (para os testes).
export function readPack(lang, dir = path.join(REPO, LANGS_DIR)) {
  return JSON.parse(zlib.inflateRawSync(fs.readFileSync(path.join(dir, fileOf(lang)))).toString('utf8'))
}

// O texto de um pacote guardado, descomprimido, ou null quando ele falta ou não descomprime.
function storedPack(dir, file) {
  let packed
  try {
    packed = fs.readFileSync(path.join(dir, file))
  } catch (e) {
    if (e?.code === 'ENOENT') return null
    throw e
  }
  try {
    return zlib.inflateRawSync(packed).toString('utf8')
  } catch (e) {
    // Os erros do zlib têm um código Z_: não é o que o build grava.
    if (String(e?.code).startsWith('Z_')) return null
    throw e
  }
}

function storedIndex(dir) {
  try {
    return fs.readFileSync(path.join(dir, INDEX), 'utf8')
  } catch (e) {
    if (e?.code === 'ENOENT') return null
    throw e
  }
}

// O que não bate entre o build e a pasta: os pacotes velhos ou que faltam, os que sobram (de um
// idioma que saiu) e o index.json.
function differences(built, dir) {
  const stale = Object.entries(built.packs).filter(([lang, text]) => storedPack(dir, fileOf(lang)) !== text).map(([lang]) => lang)
  const wanted = new Set([...Object.keys(built.packs).map(fileOf), INDEX])
  const extra = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.json.deflate') && !wanted.has(f)) : []
  const index = storedIndex(dir) !== built.index
  return { stale, extra, index }
}

const kb = bytes => Math.round(bytes / 1024)
const packedSize = (dir, files) => files.reduce((n, f) => n + fs.statSync(path.join(dir, f)).size, 0)

// A CLI. Com --check, só compara o texto de cada pacote, descomprimido, nunca os bytes comprimidos,
// e o index.json; sai com 1 quando algo não bate. Sem --check, grava só os pacotes que mudaram e o
// index.json, e apaga um pacote que sobrou. O io.dir troca a pasta dos pacotes (os testes usam uma
// cópia temporária). Devolve o código de saída.
export async function main(argv = [], io = {}) {
  const { dir = path.join(REPO, LANGS_DIR), repo = REPO, out = l => console.log(l), err = l => console.error(l) } = io
  if (argv.some(a => a !== '--check')) {
    err('uso: node scripts/build-hexgym-langs.mjs [--check]')
    return 2
  }
  let built
  try {
    built = await buildLangs(repo)
  } catch (e) {
    err(`os pacotes de idioma não saíram: ${e.message}`)
    return 1
  }
  const { stale, extra, index } = differences(built, dir)
  const files = Object.keys(built.packs).map(fileOf)
  if (!stale.length && !extra.length && !index) {
    out(`Os pacotes de idioma estão em dia (${LANGS_DIR}): ${files.length} pacotes, ${kb(packedSize(dir, files))} KB comprimidos.`)
    return 0
  }
  if (argv.includes('--check')) {
    const what = [
      ...stale.map(l => `${fileOf(l)} velho ou faltando`),
      ...extra.map(f => `${f} sobrando`),
      ...(index ? [`${INDEX} velho ou faltando`] : []),
    ]
    err(`Os pacotes de idioma estão desatualizados (${LANGS_DIR}): ${what.join(', ')}. Rode: node scripts/build-hexgym-langs.mjs`)
    return 1
  }
  fs.mkdirSync(dir, { recursive: true })
  for (const lang of stale) fs.writeFileSync(path.join(dir, fileOf(lang)), zlib.deflateRawSync(Buffer.from(built.packs[lang], 'utf8'), { level: 9 }))
  for (const f of extra) fs.rmSync(path.join(dir, f))
  if (index) fs.writeFileSync(path.join(dir, INDEX), built.index)
  const changed = [...stale.map(fileOf), ...(index ? [INDEX] : [])]
  out(`Gravei ${changed.join(', ') || 'nada'}${extra.length ? ` e apaguei ${extra.join(', ')}` : ''} em ${LANGS_DIR}: ${files.length} pacotes, ${kb(packedSize(dir, files))} KB comprimidos.`)
  return 0
}

// Chamado como script, e não importado: as duas pontas passam pelo realpath. Um argv[1] que não
// existe (node -e, por exemplo) quer dizer que não é este arquivo.
function isMain() {
  try {
    return Boolean(process.argv[1]) && fs.realpathSync(process.argv[1]) === SELF
  } catch {
    return false
  }
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
