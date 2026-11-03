// Quais testes do lib rodam também contra o script do motor (seção 8.2 do design doc). Quem chama é
// o frontend/vitest.hexengine.config.js, com os *.test.js e *.test.jsx de frontend/src/lib e os
// módulos de __modules do script. Node 22, sem dependências.
//
// Entra o teste em que cada import (import … from, import '…', export … from e import('…') com
// texto fixo) é um módulo do script, vitest, fast-check, um módulo do Node ou um .json, com pelo
// menos um módulo do script, e que não chama vi.mock, vi.doMock, vi.stubEnv nem vi.resetModules: um
// mock não alcança o código que já está dentro do script, e o ambiente ficou fixo no build. O que
// fica de fora leva o motivo, nesta ordem: o primeiro import fora da lista ("importa <x>", com o
// nome do pacote ou o caminho a partir da raiz), a primeira das quatro chamadas ("chama vi.mock") ou
// "não importa nenhum módulo do motor".
//
// A escolha lê o texto e não roda nada. Comentários, strings, templates e expressões regulares não
// contam: um import ou um vi.mock citado num comentário não muda a escolha.

import { isBuiltin } from 'node:module'
import path from 'node:path'

// Os pacotes que um teste escolhido pode importar, além dos módulos do Node e dos .json.
const PACKAGES = new Set(['vitest', 'fast-check'])

// As chamadas que tiram um teste da escolha.
const CALLS = /(?<![\w$.])vi\s*\.\s*(mock|doMock|stubEnv|resetModules)\s*\(/

// As formas de import, procuradas no código, com a aspa que abre o caminho no fim: import … from '…'
// e import '…', e export … from '…'. O import('…') vem à parte, porque depois da aspa que fecha só
// pode vir o fim da chamada ou a vírgula das opções.
const STATIC = [
  /(?<![\w$.])import(?![\w$])\s*(?:[\w$]+\s*(?:,\s*)?)?(?:\*\s*as\s+[\w$]+\s*|\{[^}]*\}\s*)?(?:from\s*)?(['"])/g,
  /(?<![\w$.])export(?![\w$])\s*(?:\*\s*(?:as\s+[\w$]+\s*)?|\{[^}]*\}\s*)from\s*(['"])/g,
]
const DYNAMIC = /(?<![\w$.])import\s*\(\s*(['"`])/g
const DYNAMIC_END = /\s*[,)]/y

// Palavras depois das quais uma / abre uma expressão regular, e não uma divisão.
const BEFORE_REGEX = new Set(['return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void', 'throw', 'case', 'do', 'else', 'yield', 'await'])

// O texto com o que não é código trocado por espaços, nas mesmas posições: os comentários e o que
// vai dentro de strings, templates e expressões regulares. Os delimitadores ficam (as aspas mostram
// onde começa e acaba o caminho de um import), e o código de um ${ } dentro de um template também.
// As quebras de linha ficam onde estão.
function codeOnly(text) {
  const out = text.split('')
  const blank = (from, to) => {
    for (let k = from; k < Math.min(to, out.length); k++) if (out[k] !== '\n') out[k] = ' '
  }
  // Para cada ${ aberto, quantas chaves de código estavam abertas antes dele.
  const open = []
  let braces = 0
  // O texto de um template a partir de start, até a crase do fim ou até um ${. Devolve onde o
  // código continua.
  const template = start => {
    let j = start
    while (j < text.length && text[j] !== '`') {
      if (text[j] === '\\') { j += 2; continue }
      if (text[j] === '$' && text[j + 1] === '{') {
        blank(start, j)
        open.push(braces)
        return j + 2
      }
      j++
    }
    blank(start, j)
    return j + 1
  }
  let i = 0
  while (i < text.length) {
    const c = text[i]
    if (c === '/' && text[i + 1] === '/') {
      const end = text.indexOf('\n', i)
      const stop = end < 0 ? text.length : end
      blank(i, stop)
      i = stop
    } else if (c === '/' && text[i + 1] === '*') {
      const end = text.indexOf('*/', i + 2)
      const stop = end < 0 ? text.length : end + 2
      blank(i, stop)
      i = stop
    } else if (c === '"' || c === "'") {
      const close = stringEnd(text, i)
      blank(i + 1, close)
      i = close + 1
    } else if (c === '`') {
      i = template(i + 1)
    } else if (c === '}' && open.length && braces === open.at(-1)) {
      open.pop()
      i = template(i + 1)
    } else if (c === '/' && regexAllowed(out, i)) {
      const close = regexEnd(text, i)
      blank(i + 1, close)
      i = close + 1
    } else {
      if (c === '{') braces++
      else if (c === '}') braces--
      i++
    }
  }
  return out.join('')
}

// A aspa que fecha a string aberta em i, ou a quebra de linha de uma string sem fim.
function stringEnd(text, i) {
  let j = i + 1
  while (j < text.length && text[j] !== text[i] && text[j] !== '\n') j += text[j] === '\\' ? 2 : 1
  return Math.min(j, text.length)
}

// A / que fecha a expressão regular aberta em i, sem contar a de dentro de uma classe ([/]).
function regexEnd(text, i) {
  let j = i + 1
  let inClass = false
  while (j < text.length && text[j] !== '\n') {
    if (text[j] === '\\') { j += 2; continue }
    if (text[j] === '[') inClass = true
    else if (text[j] === ']') inClass = false
    else if (text[j] === '/' && !inClass) return j
    j++
  }
  return Math.min(j, text.length)
}

// Se a / em i abre uma expressão regular: sim depois de um operador, de um parêntese que abre, do
// começo do texto ou de uma palavra como return; não depois de um valor (um nome, um número, um
// parêntese ou colchete que fecha, uma string), que faz dela uma divisão. Olha o código já limpo.
function regexAllowed(out, i) {
  let j = i - 1
  while (j >= 0 && /\s/.test(out[j])) j--
  if (j < 0) return true
  const c = out[j]
  if (/[\w$]/.test(c)) {
    let k = j
    while (k > 0 && /[\w$]/.test(out[k - 1])) k--
    return BEFORE_REGEX.has(out.slice(k, j + 1).join(''))
  }
  return !/[)\]}'"`/]/.test(c)
}

// Cada import do texto, na ordem em que aparece, com o caminho como está escrito. code é o texto
// pelo codeOnly. Um import('…') só conta com texto fixo: um caminho montado na hora, com + ou com
// ${ }, não diz o que importa.
function importsOf(text, code) {
  const found = []
  for (const pattern of [...STATIC, DYNAMIC]) {
    for (const m of code.matchAll(pattern)) {
      const quote = m.index + m[0].length - 1
      const close = code.indexOf(m[1], quote + 1)
      if (close < 0) continue
      if (pattern === DYNAMIC) {
        if (m[1] === '`' && code.slice(quote, close).includes('${')) continue
        DYNAMIC_END.lastIndex = close + 1
        if (!DYNAMIC_END.test(code)) continue
      }
      found.push({ at: m.index, source: text.slice(quote + 1, close) })
    }
  }
  return found.sort((a, b) => a.at - b.at).map(f => f.source)
}

// O nome de um import nas mensagens e na lista: o caminho a partir da raiz para um arquivo,
// node:<nome> para um módulo do Node, o texto inteiro para um endereço (https:, data:) e o nome do
// pacote para um pacote (react, @capacitor/core).
function nameOf(source, from) {
  if (source.startsWith('.')) return path.posix.normalize(path.posix.join(path.posix.dirname(from), source))
  if (source.startsWith('/')) return source
  if (isBuiltin(source)) return source.startsWith('node:') ? source : `node:${source}`
  if (/^[a-z][a-z\d+.-]*:/i.test(source)) return source
  return source.split('/').slice(0, source.startsWith('@') ? 2 : 1).join('/')
}

// O motivo de um teste ficar de fora, ou null quando ele entra.
function reasonOf(file, engineModules) {
  const code = codeOnly(file.text)
  let engine = false
  for (const source of importsOf(file.text, code)) {
    const name = nameOf(source, file.path)
    if (engineModules.has(name)) { engine = true; continue }
    if (name.startsWith('node:') || PACKAGES.has(name) || name.endsWith('.json')) continue
    return `importa ${name}`
  }
  const call = code.match(CALLS)
  if (call) return `chama vi.${call[1]}`
  return engine ? null : 'não importa nenhum módulo do motor'
}

// files: [{ path, text }], com o caminho a partir da raiz do repositório. engineModules: um Set com
// os caminhos, também a partir da raiz, dos módulos de __modules. A ordem dos arquivos fica.
export function pickEngineTests(files, engineModules) {
  const picked = []
  const skipped = []
  for (const file of files) {
    const reason = reasonOf(file, engineModules)
    if (reason === null) picked.push(file.path)
    else skipped.push({ path: file.path, reason })
  }
  return { picked, skipped }
}
