// A troca de valores entre o Swift e o motor. O Swift só passa texto JSON ao JavaScriptCore, e o
// JSON não guarda datas, undefined, NaN nem os infinitos, que as funções do lib recebem e
// devolvem. Cada um desses vira um objeto marcado, de uma chave só:
//
//   uma data              {"$date": ms}, e {"$date": null} se for inválida (o JSON faz NaN virar null)
//   undefined             {"$undefined": true}
//   NaN e os infinitos    {"$number": "NaN" | "Infinity" | "-Infinity"}
//
// O resto é JSON comum: texto, número, true e false, null, arrays e objetos de dados. Map, Set,
// função, símbolo, uma referência circular e qualquer objeto de classe lançam um erro, em vez de
// virar {} em silêncio como no JSON.stringify. Um objeto de dados que se leria como um marcado
// (como {"$date": 5}) também lança: assim, o decodeValue sempre devolve o que o encodeValue
// recebeu.

const NUMBERS = new Set(['NaN', 'Infinity', '-Infinity'])

const refuse = kind => new Error(`valor que o motor não sabe passar: ${kind}`)

// O literal {} ou um objeto sem protótipo: dados, sem classe por trás.
function isPlainObject(v) {
  const proto = Object.getPrototypeOf(v)
  return proto === Object.prototype || proto === null
}

// Uma chave como as outras, até a "__proto__", que a atribuição comum trocaria pelo protótipo.
function put(obj, key, value) {
  if (key === '__proto__') Object.defineProperty(obj, key, { value, writable: true, enumerable: true, configurable: true })
  else obj[key] = value
}

// O objeto marcado como o decodeValue lê: { value } com o valor que ele representa, ou null
// para um objeto comum.
function tagged(o) {
  const keys = Object.keys(o)
  if (keys.length !== 1) return null
  const [k] = keys, x = o[k]
  if (k === '$undefined' && x === true) return { value: undefined }
  if (k === '$date' && (typeof x === 'number' || x === null)) return { value: new Date(x ?? NaN) }
  if (k === '$number' && NUMBERS.has(x)) return { value: Number(x) }
  return null
}

export function encodeValue(v) {
  return encode(v, new Set())
}

// open: os objetos que estão sendo passados agora, do topo até aqui, para achar uma volta.
function encode(v, open) {
  if (v === undefined) return { $undefined: true }
  if (v === null || typeof v === 'string' || typeof v === 'boolean') return v
  if (typeof v === 'number') return Number.isFinite(v) ? v : { $number: String(v) }
  if (typeof v !== 'object') throw refuse(typeof v)
  if (v instanceof Date) {
    const ms = v.getTime()
    return { $date: Number.isNaN(ms) ? null : ms }
  }
  if (!Array.isArray(v) && !isPlainObject(v)) throw refuse(v.constructor?.name || 'objeto')
  if (open.has(v)) throw refuse('referência circular')
  open.add(v)
  let out
  if (Array.isArray(v)) out = Array.from(v, x => encode(x, open))
  else {
    out = {}
    for (const k of Object.keys(v)) put(out, k, encode(v[k], open))
    if (tagged(out)) throw refuse(`objeto com a chave ${Object.keys(out)[0]}`)
  }
  open.delete(v)
  return out
}

// v é o que o JSON.parse devolve.
export function decodeValue(v) {
  if (Array.isArray(v)) return v.map(x => decodeValue(x))
  if (v === null || typeof v !== 'object') return v
  const tag = tagged(v)
  if (tag) return tag.value
  const out = {}
  for (const k of Object.keys(v)) put(out, k, decodeValue(v[k]))
  return out
}
