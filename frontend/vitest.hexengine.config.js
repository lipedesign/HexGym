// Os testes do lib contra o script do motor do HexGym (seção 8.2 do design doc): os testes de
// frontend/src/lib que só usam o motor rodam também contra o script gerado, o mesmo que o iPhone
// carrega, e não contra o código de src/lib.
//
//   cd frontend && npx vitest run --config vitest.hexengine.config.js
//   cd frontend && HEXENGINE_SKIPPED=1 npx vitest run --config vitest.hexengine.config.js   # e os de fora, com o motivo
//
// O script vem do readEngine, guardado e descomprimido, como o app o recebe; ele roda uma vez aqui,
// para saber os módulos de __modules e o que cada um exporta. A escolha dos testes é a do
// scripts/hexgym/engine-tests.mjs. Num teste escolhido, cada import de um módulo do script vira um
// módulo que reexporta o que o script tem com aquele caminho. O script é avaliado uma vez por
// arquivo de teste, como um módulo de src/lib seria.
//
// Do vite.config.js do app, só o setupFiles vem junto.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { readEngine } from '../scripts/build-hexgym-engine.mjs'
import { pickEngineTests } from '../scripts/hexgym/engine-tests.mjs'

const FRONTEND = path.dirname(fileURLToPath(import.meta.url))
const REPO = path.dirname(FRONTEND)
const LIB = 'frontend/src/lib/'

// A seção 8.2 conta 117 arquivos de teste do lib que só usam o motor, e estes módulos precisam
// estar entre eles.
const AT_LEAST = 117
const REQUIRED = ['progression', 'sync-merge', 'onerm', 'finish-workout', 'recovery', 'workout-model', 'log-workout', 'history',
  'supersetFlow', 'routines', 'units', 'measurements', 'plan-share', 'exercises', 'state-core']

// Os testes escolhidos que falham só por rodarem contra o script, cada um com o motivo. Um teste que
// falha por outro motivo é uma diferença entre o script e o código, e não entra aqui.
const EXCLUDED = {
  'frontend/src/lib/state-json.test.js':
    'a checagem do histórico mudado no lugar só existe com import.meta.env.MODE igual a test, e o build deixa o import.meta.env do script vazio',
}

const code = readEngine(REPO)
const modules = new Function(code + '\nreturn HexEngine')().__modules
// O que cada módulo exporta. O nome entra no código dos módulos que reexportam, então só passa nome
// de identificador.
const exportsOf = Object.fromEntries(Object.entries(modules).map(([m, ns]) => {
  const names = Object.keys(ns)
  const odd = names.find(n => !/^[A-Za-z_$][\w$]*$/.test(n))
  if (odd !== undefined) throw new Error(`HexEngine: ${m} exporta ${JSON.stringify(odd)}, que não é um nome que o config saiba reexportar`)
  return [m, names]
}))

const files = fs.readdirSync(path.join(REPO, LIB))
  .filter(f => /\.test\.jsx?$/.test(f))
  .sort()
  .map(f => ({ path: LIB + f, text: fs.readFileSync(path.join(REPO, LIB, f), 'utf8') }))
const { picked, skipped } = pickEngineTests(files, new Set(Object.keys(modules)))

for (const f of Object.keys(EXCLUDED)) {
  if (!picked.includes(f)) throw new Error(`HexEngine: o EXCLUDED tem ${f}, que a escolha já deixa de fora`)
}
const chosen = picked.filter(f => !Object.hasOwn(EXCLUDED, f))
const left = [...skipped, ...picked.filter(f => Object.hasOwn(EXCLUDED, f)).map(f => ({ path: f, reason: EXCLUDED[f] }))]
  .sort((a, b) => (a.path < b.path ? -1 : 1))

if (chosen.length < AT_LEAST) throw new Error(`HexEngine: só ${chosen.length} arquivos de teste contra o script, e a seção 8.2 pede ${AT_LEAST} ou mais`)
const missing = REQUIRED.filter(m => !chosen.includes(`${LIB}${m}.test.js`))
if (missing.length) throw new Error(`HexEngine: faltam na escolha os testes de ${missing.join(', ')} (${LIB}<módulo>.test.js)`)

console.log(`HexEngine: ${chosen.length} arquivos de teste contra o script, ${left.length} de fora`)
if (process.env.HEXENGINE_SKIPPED === '1') for (const s of left) console.log(`fora: ${s.path} (${s.reason})`)

// O script e os módulos que reexportam o que ele tem. Os nomes começam com \0, como os módulos
// virtuais do Vite, para nenhum outro plugin mexer neles.
const SCRIPT = '\0hexengine-script'
const PREFIX = '\0hexengine:'
const chosenFiles = new Set(chosen.map(f => path.join(REPO, f)))

// O caminho, a partir da raiz, do arquivo que um import relativo alcança.
const fromRoot = (source, importer) => path.relative(REPO, path.resolve(path.dirname(importer), source)).split(path.sep).join('/')

const hexengine = {
  name: 'hexgym-engine-tests',
  enforce: 'pre',
  resolveId(source, importer) {
    if (source === SCRIPT) return SCRIPT
    if (!importer || !source.startsWith('.') || source.includes('?')) return null
    if (!chosenFiles.has(importer.split('?')[0])) return null
    const name = fromRoot(source, importer.split('?')[0])
    return Object.hasOwn(modules, name) ? PREFIX + name : null
  },
  load(id) {
    if (id === SCRIPT) return `export default new Function(${JSON.stringify(code)} + '\\nreturn HexEngine')()\n`
    if (!id.startsWith(PREFIX)) return null
    const name = id.slice(PREFIX.length)
    const names = exportsOf[name]
    return [
      `import E from ${JSON.stringify(SCRIPT)}`,
      `const m = E.__modules[${JSON.stringify(name)}]`,
      ...names.filter(n => n !== 'default').map(n => `export const ${n} = m.${n}`),
      ...(names.includes('default') ? ['export default m.default'] : []),
    ].join('\n') + '\n'
  },
}

// A raiz é a pasta do frontend, de onde quer que o Vitest seja chamado.
export default {
  root: FRONTEND,
  plugins: [hexengine],
  test: {
    include: chosen.map(f => path.posix.relative('frontend', f)),
    setupFiles: ['./src/test-setup.js'],
  },
}
