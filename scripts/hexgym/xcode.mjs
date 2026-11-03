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
//
//   node scripts/hexgym/xcode.mjs           # o Xcode completo: xcodebuild, xcrun e codesign
//   node scripts/hexgym/xcode.mjs --swift   # o do swift test dos pacotes
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift test --package-path apple/Packages/HexEngine
//
// Node 22, sem dependências. Importar este arquivo não roda nada.

import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'

// O caminho de verdade deste arquivo, sem links, como no check.mjs.
const SELF = fs.realpathSync(fileURLToPath(import.meta.url))

const XCODE = '/Applications/Xcode.app/Contents/Developer'
const CLT = '/Library/Developer/CommandLineTools'

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

// A CLI: imprime o caminho e sai com 0; sem Xcode, sai com 1 e o motivo; com argumentos errados, 2.
function main(argv) {
  if (argv.length > 1 || (argv.length === 1 && argv[0] !== '--swift')) {
    console.error('uso: node scripts/hexgym/xcode.mjs [--swift]')
    return 2
  }
  try {
    console.log(developerDir({ swiftOnly: argv[0] === '--swift' }))
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
