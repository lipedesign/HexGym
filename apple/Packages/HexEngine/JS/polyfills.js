// O que o JavaScriptCore não tem e o motor usa: o structuredClone, com que routines.js,
// session-routines.js e session-edit.js copiam rotinas e sessões. O script do motor importa este
// arquivo antes de todo o resto, para o global existir quando os módulos do lib rodam
// (scripts/build-hexgym-engine.mjs). Os outros complementos da seção 8.2 do design doc, o console
// e os timers, vêm do Swift.
//
// cloneStructured copia, como o structuredClone do navegador, o que o motor usa: objetos, arrays,
// Date, Map, Set, valores undefined e referências repetidas ou circulares, que continuam
// apontando para a mesma cópia. Um objeto de classe vira um objeto de dados, como no nativo.
// Função e símbolo lançam um erro com name DataCloneError, como lá; os outros tipos que o nativo
// copia (RegExp, Error, ArrayBuffer e afins) o motor não usa, e aqui lançam o mesmo erro, em vez
// de sair uma cópia errada.

class DataCloneError extends Error {
  constructor(what) {
    super(`structuredClone não sabe copiar ${what}`)
    this.name = 'DataCloneError'
  }
}

// Uma chave como as outras, até a "__proto__", que a atribuição comum trocaria pelo protótipo.
function put(obj, key, value) {
  if (key === '__proto__') Object.defineProperty(obj, key, { value, writable: true, enumerable: true, configurable: true })
  else obj[key] = value
}

export function cloneStructured(value) {
  const copies = new Map()
  const copy = v => {
    if (typeof v === 'function' || typeof v === 'symbol') throw new DataCloneError(typeof v)
    if (v === null || typeof v !== 'object') return v
    if (copies.has(v)) return copies.get(v)
    const kind = Object.prototype.toString.call(v).slice(8, -1)
    let out
    switch (kind) {
      case 'Date':
        out = new Date(v.getTime())
        copies.set(v, out)
        return out
      case 'Map':
        out = new Map()
        copies.set(v, out)
        for (const [k, x] of v) out.set(copy(k), copy(x))
        return out
      case 'Set':
        out = new Set()
        copies.set(v, out)
        for (const x of v) out.add(copy(x))
        return out
      case 'Array':
        out = new Array(v.length)
        break
      case 'Object':
        out = {}
        break
      default:
        throw new DataCloneError(kind)
    }
    copies.set(v, out)
    for (const k of Object.keys(v)) put(out, k, copy(v[k]))
    return out
  }
  return copy(value)
}

if (typeof globalThis.structuredClone === 'undefined') {
  Object.defineProperty(globalThis, 'structuredClone', { value: cloneStructured, writable: true, configurable: true })
}
