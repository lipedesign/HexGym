#!/usr/bin/env node
// O script do motor do HexGym (seção 8.2 do design doc). O JavaScriptCore do iPhone não carrega
// módulos, então este build junta num script clássico só, o HexEngine, os módulos de
// frontend/src/lib que não puxam o navegador, com o Vite que o frontend já tem. O script gerado é
// versionado, para o app compilar sem Node.
//
//   node scripts/build-hexgym-engine.mjs           # grava o script
//   node scripts/build-hexgym-engine.mjs --check   # só compara, e sai com 1 se ele estiver velho
//
// O motor é todo módulo de frontend/src/lib (sem os testes e sem fixtures/) que não alcança, por
// nenhum caminho de imports estáticos ou dinâmicos, um pacote, um módulo do Node ou um arquivo
// fora de frontend/src/lib e api/coach/core, mais os JSON e os módulos de api/coach/core que ele
// importa. Assim, módulo novo do openGym que não puxa o navegador entra sozinho, e o --check
// mostra a mudança.
//
// Node 22, sem dependência nova. O Vite vem de frontend/node_modules, porque a raiz não tem, e
// nada do vite.config.js do app entra (configFile: false).

import fs from 'node:fs'
import { createRequire, isBuiltin } from 'node:module'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

// O caminho de verdade deste arquivo, sem links, como no scripts/hexgym/check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))
const REPO = path.join(path.dirname(SELF), '..')

const OUT = 'apple/Packages/HexEngine/Sources/HexEngine/Resources/hexengine.js'
const LIB = 'frontend/src/lib/'
// As duas pastas do motor.
const FOLDERS = [LIB, 'api/coach/core/']
// A dos complementos e das funções que o Swift chama (polyfills.js, values.js e runtime.js).
const JS = 'apple/Packages/HexEngine/JS/'
// A entrada dos dois builds, que só existe aqui dentro.
const ENTRY = '\0hexgym-engine'

// O Vite do frontend, pelo caminho do pacote (no Vite 8, o exports["."] é o texto
// ./dist/node/index.js).
async function loadVite(repo) {
  const require = createRequire(path.join(repo, 'frontend', 'package.json'))
  return import(pathToFileURL(require.resolve('vite')).href)
}

// O caminho de um arquivo a partir da raiz, com /, sem a query (?raw e afins).
const relative = (repo, id) => path.relative(repo, id.split('?')[0]).split(path.sep).join('/')
const inFolders = (name, folders) => folders.some(f => name.startsWith(f))
const importerName = (repo, importer) => (importer === ENTRY ? ENTRY.slice(1) : relative(repo, importer))

// O nome de um import que não é caminho: node:<nome> para um módulo do Node, o nome do pacote
// para um pacote (react, @capacitor/core) e o texto inteiro para um endereço (https:, data:).
function packageName(source) {
  if (isBuiltin(source)) return source.startsWith('node:') ? source : `node:${source}`
  if (/^[a-z][a-z\d+.-]*:/i.test(source)) return source
  return source.split('/').slice(0, source.startsWith('@') ? 2 : 1).join('/')
}

// Aonde um import leva, visto do resolveId de um plugin: o nome dele no grafo e nas mensagens
// (o caminho a partir da raiz, para um arquivo) e, para um arquivo que o Vite acha, a resolução.
async function target(ctx, repo, source, importer, options) {
  if (!source.startsWith('.') && !path.isAbsolute(source)) return { name: packageName(source), resolved: null }
  const resolved = await ctx.resolve(source, importer, { ...options, skipSelf: true })
  if (!resolved) return { name: relative(repo, path.resolve(path.dirname(importer), source)), resolved: null }
  return { name: path.isAbsolute(resolved.id) ? relative(repo, resolved.id) : resolved.id, resolved }
}

// Cada nó da árvore ESTree, sem recursão (os JSON do catálogo viram objetos enormes), até o
// primeiro em que visit devolve true.
function walk(ast, visit) {
  const stack = [ast]
  while (stack.length) {
    const n = stack.pop()
    if (!n || typeof n !== 'object') continue
    if (Array.isArray(n)) {
      for (let i = n.length - 1; i >= 0; i--) stack.push(n[i])
      continue
    }
    if (typeof n.type === 'string' && visit(n)) return true
    for (const k of Object.keys(n)) if (n[k] && typeof n[k] === 'object') stack.push(n[k])
  }
  return false
}

const isImportMeta = n => n?.type === 'MetaProperty' && n.meta?.name === 'import'
const propertyName = n => (n.computed ? (n.property.type === 'Literal' ? n.property.value : null) : n.property.name)

// Cada import.meta.env vira ({}): é o "import.meta.env vazio" da seção 8.2, e por isso nenhuma
// variável VITE_ da máquina entra no script.
function withEmptyEnv(code, ast) {
  const spots = []
  walk(ast, n => {
    if (n.type === 'MemberExpression' && isImportMeta(n.object) && propertyName(n) === 'env') spots.push(n)
    return false
  })
  let out = code
  for (const n of spots.sort((a, b) => b.start - a.start)) out = out.slice(0, n.start) + '({})' + out.slice(n.end)
  return out
}

// O que os dois builds dividem: nada do vite.config.js do app, de .env nem da pasta public, e nada
// gravado. O cwd do Rolldown é a raiz: ele põe o caminho de cada módulo num comentário, relativo
// ao cwd, e sem isso o script mudaria com a pasta de quem roda e levaria o caminho desta máquina.
// Sem log: um erro chega pela rejeição do build, com a mensagem do plugin, e a sondagem avisaria
// de cada import dinâmico que não separa nada (INEFFECTIVE_DYNAMIC_IMPORT), o que não muda o grafo.
function viteConfig(repo, { define, plugins, build }) {
  return {
    configFile: false,
    root: repo,
    envDir: false,
    publicDir: false,
    logLevel: 'silent',
    define,
    plugins,
    build: {
      write: false,
      emptyOutDir: false,
      copyPublicDir: false,
      reportCompressedSize: false,
      ...build,
      rolldownOptions: { ...build.rolldownOptions, cwd: repo },
    },
  }
}

// O grafo de imports do lib, por um build de sondagem em formato ES e sem gravar, com uma entrada
// que importa todo módulo de frontend/src/lib. O resolveId anota cada import, estático ou
// dinâmico, e marca como externo tudo fora das duas pastas, que o grafo mostra sem seguir: um
// arquivo pelo caminho a partir da raiz, um pacote pelo nome e um módulo do Node com node:.
export async function engineGraph(repo) {
  repo = fs.realpathSync(repo)
  const vite = await loadVite(repo)
  const lib = fs.readdirSync(path.join(repo, LIB), { withFileTypes: true })
    .filter(f => f.isFile() && f.name.endsWith('.js') && !f.name.includes('.test.'))
    .map(f => LIB + f.name)
    .sort()
  const graph = new Map(lib.map(m => [m, new Set()]))
  const node = name => graph.get(name) ?? graph.set(name, new Set()).get(name)
  const entry = lib.map(m => `import ${JSON.stringify(path.join(repo, m))}`).join('\n') + '\n'
  await vite.build(viteConfig(repo, {
    plugins: [{
      name: 'hexgym-engine-graph',
      enforce: 'pre',
      async resolveId(source, importer, options) {
        if (options.isEntry) return ENTRY
        if (!importer || importer === ENTRY || source.startsWith('\0')) return null
        const to = await target(this, repo, source, importer, options)
        node(relative(repo, importer)).add(to.name)
        if (!inFolders(to.name, FOLDERS) || !to.resolved) return { id: source, external: true }
        node(to.name)
        return to.resolved
      },
      load: id => (id === ENTRY ? entry : null),
    }],
    build: { lib: { entry: ENTRY.slice(1), formats: ['es'], fileName: () => 'sondagem.js' } },
  }))
  return Object.fromEntries([...graph.keys()].sort().map(m => [m, [...graph.get(m)].sort()]))
}

// Os frontend/src/lib/*.js do grafo que não alcançam, por nenhum caminho, um pacote, um módulo do
// Node ou um arquivo fora das duas pastas, em ordem alfabética. Um arquivo das pastas que não está
// no grafo também conta como fora, porque não dá para saber o que ele importa.
export function cleanModules(graph) {
  const known = name => inFolders(name, FOLDERS) && Object.hasOwn(graph, name)
  const importers = new Map()
  const dirty = new Set()
  for (const [m, deps] of Object.entries(graph)) {
    if (!known(m)) dirty.add(m)
    for (const d of deps) {
      if (!importers.has(d)) importers.set(d, [])
      importers.get(d).push(m)
      if (!known(d)) dirty.add(d)
    }
  }
  // Quem importa um módulo sujo fica sujo, até não sobrar ninguém, com voltas ou sem.
  const queue = [...dirty]
  while (queue.length) {
    for (const m of importers.get(queue.pop()) ?? []) {
      if (!dirty.has(m)) { dirty.add(m); queue.push(m) }
    }
  }
  return Object.keys(graph)
    .filter(m => m.startsWith(LIB) && !m.slice(LIB.length).includes('/') && m.endsWith('.js') && !dirty.has(m))
    .sort()
}

// O plugin do build de verdade, com as três conferências: nenhum import para fora das duas pastas
// e de apple/Packages/HexEngine/JS; nenhum import.meta além do env, que vira um objeto vazio; e
// nenhum import dinâmico na saída. As duas últimas vão pela árvore do código (this.parse), nunca
// por expressão regular, porque há comentários que falam de import.meta.glob e de import().
function enginePlugin(repo, entry) {
  const allowed = [...FOLDERS, JS]
  return {
    name: 'hexgym-engine',
    enforce: 'pre',
    async resolveId(source, importer, options) {
      if (options.isEntry) return ENTRY
      if (!importer || source.startsWith('\0')) return null
      const to = await target(this, repo, source, importer, options)
      if (!inFolders(to.name, allowed)) this.error(`o motor não pode importar ${to.name} (em ${importerName(repo, importer)})`)
      return to.resolved
    },
    load: id => (id === ENTRY ? entry : null),
    transform(code, id) {
      if (id.startsWith('\0') || !/\.[cm]?js$/.test(id.split('?')[0])) return null
      const ast = this.parse(code)
      const out = withEmptyEnv(code, ast)
      if (walk(out === code ? ast : this.parse(out), isImportMeta)) this.error(`o motor não pode usar import.meta (em ${relative(repo, id)})`)
      return out === code ? null : out
    },
    generateBundle(options, bundle) {
      for (const file of Object.values(bundle)) {
        if (file.type === 'chunk' && walk(this.parse(file.code), n => n.type === 'ImportExpression')) this.error('o script do motor ficou com import dinâmico')
      }
    },
  }
}

// O script do motor: um script clássico que cria o global HexEngine com o que runtime.js exporta,
// call = makeCall(__modules) e os __modules, com cada módulo limpo (e cada extra, que os testes
// forçam para dentro) pelo caminho a partir da raiz. O polyfills.js vem antes de todo o resto.
// Sem minificar, para o erro do JS chegar ao Swift com uma linha que dá para ler.
export async function buildEngine(repo, { extra = [] } = {}) {
  repo = fs.realpathSync(repo)
  const modules = [...new Set([...cleanModules(await engineGraph(repo)), ...extra])]
  const vite = await loadVite(repo)
  const version = JSON.parse(fs.readFileSync(path.join(repo, 'frontend', 'package.json'), 'utf8')).version
  const at = m => JSON.stringify(path.join(repo, m))
  const entry = [
    `import ${at(JS + 'polyfills.js')}`,
    `import { makeCall } from ${at(JS + 'runtime.js')}`,
    `export * from ${at(JS + 'runtime.js')}`,
    ...modules.map((m, i) => `import * as m${i} from ${at(m)}`),
    `export const __modules = { ${modules.map((m, i) => `${JSON.stringify(m)}: m${i}`).join(', ')} }`,
    'export const call = makeCall(__modules)',
  ].join('\n') + '\n'
  const banner = `// Gerado por scripts/build-hexgym-engine.mjs a partir do openGym ${version}, com ${modules.length} módulos. Não edite à mão.`
  const result = await vite.build(viteConfig(repo, {
    define: { __APP_VERSION__: JSON.stringify(version) },
    plugins: [enginePlugin(repo, entry)],
    build: {
      lib: { entry: ENTRY.slice(1), name: 'HexEngine', formats: ['iife'], fileName: () => 'hexengine.js' },
      minify: false,
      target: 'es2022',
      rolldownOptions: { output: { banner } },
    },
  }))
  const chunk = [result].flat().flatMap(r => r.output).find(f => f.type === 'chunk')
  return { code: chunk.code, modules }
}

const realIo = {
  build: () => buildEngine(REPO),
  readFile: file => fs.promises.readFile(path.join(REPO, file), 'utf8'),
  async writeFile(file, text) {
    const at = path.join(REPO, file)
    await fs.promises.mkdir(path.dirname(at), { recursive: true })
    await fs.promises.writeFile(at, text)
  },
  out: line => console.log(line),
  err: line => console.error(line),
}

// A CLI: grava o script e diz quantos módulos e quanto ele tem; com --check, só compara (o
// arquivo que falta conta como velho) e sai com 1 quando ele está velho. Devolve o código de saída.
export async function main(argv = [], io = {}) {
  const { build, readFile, writeFile, out, err } = { ...realIo, ...io }
  if (argv.some(a => a !== '--check')) {
    err('uso: node scripts/build-hexgym-engine.mjs [--check]')
    return 2
  }
  let built
  try {
    built = await build()
  } catch (e) {
    // O Rolldown junta os erros dos plugins em e.errors; o e.message deles traz também a pilha.
    for (const reason of e.errors?.map(x => x.message) ?? [e.message]) err(`o script do motor não saiu: ${reason}`)
    return 1
  }
  const size = `${built.modules.length} módulos, ${Math.round(Buffer.byteLength(built.code) / 1024)} KB`
  if (argv.includes('--check')) {
    let current = null
    try {
      current = await readFile(OUT)
    } catch (e) {
      if (e?.code !== 'ENOENT') {
        err(`não deu para ler ${OUT}: ${e.message}`)
        return 1
      }
      // O arquivo que falta conta como velho.
    }
    if (current !== built.code) {
      err(`${OUT} está desatualizado. Rode: node scripts/build-hexgym-engine.mjs`)
      return 1
    }
    out(`${OUT} está em dia (${size}).`)
    return 0
  }
  await writeFile(OUT, built.code)
  out(`Gravei ${OUT}: ${size}.`)
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
