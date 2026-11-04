#!/usr/bin/env node
// Qual Xcode os comandos do HexGym usam, pelo DEVELOPER_DIR: o xcode-select desta máquina aponta
// para as Command Line Tools, que rodam o swift test dos pacotes, mas não o xcodebuild. A ordem:
//   1. o DEVELOPER_DIR do ambiente, que é a escolha de quem chama e vale como vem;
//   2. o /Applications/Xcode.app (o 27.2 estável, que o founder instala na Task 12);
//   3. o que o xcode-select -p aponta, quando não é a Command Line Tools nem um beta (o runner
//      xcode-27 tem nomes com número, como /Applications/Xcode_27.2.app);
//   4. só para os pacotes Swift (swiftOnly), as Command Line Tools, quando têm o swift.
// O Xcode-beta nunca é escolhido: é pré-lançamento, e o desta máquina está sem os componentes da
// primeira abertura (decisão do tech lead, 03/11/2026). Sem nenhum, um erro diz o que fazer.
// O swiftTestFlags dá os argumentos que o swift test precisa com aquele swift: com as Command Line
// Tools, o caminho do plugin do TestingMacros, e com um Xcode completo, nenhum. O pickSimulator
// escolhe, entre os simuladores que já existem, o iPhone em que a parte app do check.mjs roda os
// testes.
//
//   node scripts/hexgym/xcode.mjs                    # o Xcode completo: xcodebuild, xcrun e codesign
//   node scripts/hexgym/xcode.mjs --swift            # o do swift test dos pacotes
//   node scripts/hexgym/xcode.mjs --swift-test-flags # os argumentos do swift test, para esse swift
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) \
//     --package-path apple/Packages/HexEngine
//
// Node 22, sem dependências. Importar este arquivo não roda nada.

import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'

// O caminho de verdade deste arquivo, sem links, como no check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))

const XCODE = '/Applications/Xcode.app/Contents/Developer'
export const CLT = '/Library/Developer/CommandLineTools'
// O plugin dos macros do Swift Testing (@Test, @Suite, #expect) nas Command Line Tools.
const TESTING_MACROS = `${CLT}/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib`

// Um Xcode de pré-lançamento, pelo nome do .app: o Xcode-beta.app daqui, ou um Xcode_27.0_beta.app.
const isBeta = dir => /\/[^/]*beta[^/]*\.app(\/|$)/i.test(dir)

export function developerDir({
  env = process.env,
  exists = fs.existsSync,
  selected = () => execFileSync('xcode-select', ['-p'], { encoding: 'utf8' }),
  swiftOnly = false,
} = {}) {
  if (env.DEVELOPER_DIR) return env.DEVELOPER_DIR
  if (exists(XCODE)) return XCODE
  // Um xcode-select que falha (numa máquina sem ferramentas da Apple) não aponta para nada; o
  // motivo vai junto no erro do fim, se nenhum outro servir.
  let chosen = '', why = ''
  try {
    chosen = selected().trim().replace(/\/+$/, '')
  } catch (err) {
    why = ` (o xcode-select -p falhou: ${String(err.message).split('\n')[0]})`
  }
  if (chosen && chosen !== CLT && !isBeta(chosen)) return chosen
  if (swiftOnly && exists(`${CLT}/usr/bin/swift`)) return CLT
  throw new Error(`nenhum Xcode encontrado: instale o Xcode 27.2 ou defina DEVELOPER_DIR${why}`)
}

// Os argumentos que o swift test precisa com o swift do dir. Com as Command Line Tools, o swift 6.4
// às vezes compila os testes sem o plugin do TestingMacros e falha ao acaso com "plugin for module
// 'TestingMacros' not found" (issue #19, decisão do tech lead de 03/11): o -load-plugin-library dá
// ao compilador o caminho do plugin. Com outro dir, ou sem o plugin no disco, nenhum. Com o Xcode
// 27.2, o developerDir escolhe o Xcode.app, e os argumentos somem sozinhos.
export function swiftTestFlags(dir, { exists = fs.existsSync } = {}) {
  if (String(dir).replace(/\/+$/, '') !== CLT || !exists(TESTING_MACROS)) return []
  return ['-Xswiftc', '-load-plugin-library', '-Xswiftc', TESTING_MACROS]
}

// O udid do simulador em que os testes do app rodam, pelo texto de xcrun simctl list devices available
// --json: no iOS mais novo que for 26 ou acima, o primeiro aparelho disponível com o nome começando
// por family. Só escolhe entre os que existem: não cria, não liga e não apaga nenhum. Sem nenhum, um
// erro diz o que falta.
export function pickSimulator(simctlJSON, family = 'iPhone') {
  const { devices = {} } = JSON.parse(simctlJSON)
  let best = null
  for (const [runtime, list] of Object.entries(devices)) {
    // com.apple.CoreSimulator.SimRuntime.iOS-27-0: o sistema e a versão, com o terceiro número opcional.
    const m = /\.iOS-(\d+)-(\d+)(?:-(\d+))?$/.exec(runtime)
    if (!m) continue
    const version = m.slice(1).map(n => Number(n ?? 0))
    if (version[0] < 26 || (best && compareVersions(version, best.version) <= 0)) continue
    const device = list.find(d => d.isAvailable === true && typeof d.name === 'string' && d.name.startsWith(family))
    if (device) best = { version, udid: device.udid }
  }
  if (!best) throw new Error(`nenhum simulador de ${family} com iOS 26 ou mais novo`)
  return best.udid
}

// Compara duas versões [maior, menor, correção]: negativo, zero ou positivo.
function compareVersions(a, b) {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] - b[i]
  return 0
}

// A CLI: imprime o caminho, ou os argumentos do swift test separados por espaço (nada, quando não há
// nenhum), e sai com 0; sem Xcode, sai com 1 e o motivo; com argumentos errados, 2.
function main(argv) {
  if (argv.length > 1 || (argv.length === 1 && !['--swift', '--swift-test-flags'].includes(argv[0]))) {
    console.error('uso: node scripts/hexgym/xcode.mjs [--swift | --swift-test-flags]')
    return 2
  }
  try {
    if (argv[0] === '--swift-test-flags') {
      const flags = swiftTestFlags(developerDir({ swiftOnly: true }))
      if (flags.length) console.log(flags.join(' '))
    } else {
      console.log(developerDir({ swiftOnly: argv[0] === '--swift' }))
    }
    return 0
  } catch (err) {
    console.error(err.message)
    return 1
  }
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

if (isMain()) process.exitCode = main(process.argv.slice(2))
