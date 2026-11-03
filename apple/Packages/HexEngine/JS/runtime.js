// O que o Swift chama no motor (seção 8.2 do design doc). O script do motor põe o que este módulo
// exporta no global HexEngine, junto com call = makeCall(__modules) e os __modules
// (scripts/build-hexgym-engine.mjs). Entra e sai sempre texto JSON. O documento de dados fica
// aqui dentro, aberto uma vez, e não vai e volta a cada chamada.
import { CATALOGUE, healCustomEx, registerCustom } from '../../../../frontend/src/lib/exercises.js'
import { registerExerciseAliases } from '../../../../frontend/src/lib/exercise-aliases.js'
import { freshState, stateFromSaved } from '../../../../frontend/src/lib/state-core.js'
import { stateJson } from '../../../../frontend/src/lib/state-json.js'
import { decodeValue, encodeValue } from './values.js'

// A língua do aparelho, que o Swift diz. Até lá, nenhuma: o documento novo sai em inglês, como no
// JavaScriptCore, que não tem navigator, e não na língua do Node que roda os testes.
let deviceTag = ''
// O documento aberto; null antes do primeiro.
let current = null

// O tamanho do catálogo e a versão do openGym de que o script saiu ("dev" fora do build, que
// define o __APP_VERSION__ como o vite.config.js do app).
export function info() {
  return JSON.stringify({ exercises: CATALOGUE.length, openGymVersion: typeof __APP_VERSION__ === 'string' ? __APP_VERSION__ : 'dev' })
}

export function setDeviceLanguage(tag) {
  deviceTag = tag
}

// Cada troca de documento faz o que o boot do app web faz depois de ler a cópia salva
// (store/useStore.js): cura os exercícios personalizados e registra eles e os apelidos, que
// ficam no módulo e não no documento. Sem isso, valeriam os do documento anterior.
function open(doc) {
  doc.customEx = healCustomEx(doc.customEx)
  registerCustom(doc.customEx)
  registerExerciseAliases(doc.exAliases)
  current = doc
}

// O primeiro uso, como o do app web: freshState na língua do aparelho.
export function freshDocument() {
  open(freshState(deviceTag))
  return document()
}

// Uma cópia salva, lida como o app web lê a do aparelho: as chaves dela por cima do DEF, e as
// que esta versão não conhece ficam como estão. Texto que não é JSON lança o SyntaxError do
// JSON.parse; o documento aberto continua o mesmo.
export function restore(json) {
  const saved = JSON.parse(json)
  if (saved === null || typeof saved !== 'object' || Array.isArray(saved)) throw new TypeError('HexEngine: o documento não é um objeto JSON')
  open(stateFromSaved(saved, deviceTag))
}

// O documento aberto, no mesmo texto que o app web grava (lib/state-json.js).
export function document() {
  if (!current) throw new Error('HexEngine: nenhum documento aberto')
  return stateJson(current)
}

// O nome de uma função é "<caminho do módulo>#<export>", como "frontend/src/lib/onerm.js#estimate1RM".
function lookup(modules, name) {
  const at = typeof name === 'string' ? name.lastIndexOf('#') : -1
  const file = at < 0 ? '' : name.slice(0, at)
  const key = at < 0 ? '' : name.slice(at + 1)
  const mod = Object.hasOwn(modules, file) ? modules[file] : null
  const fn = mod && Object.hasOwn(mod, key) ? mod[key] : undefined
  if (fn === undefined) throw new Error(`HexEngine: não existe ${name}`)
  if (typeof fn !== 'function') throw new TypeError(`HexEngine: ${name} não é uma função`)
  return fn
}

// call(name, argsJson) roda uma função dos módulos. argsJson é a lista dos argumentos, na troca
// de values.js; a resposta traz o que a função devolveu e os argumentos depois da chamada, para
// mostrar o que ela mudou neles.
export function makeCall(modules) {
  return function call(name, argsJson) {
    const fn = lookup(modules, name)
    const args = decodeValue(JSON.parse(argsJson))
    if (!Array.isArray(args)) throw new TypeError(`HexEngine: os argumentos de ${name} não são uma lista JSON`)
    const returned = fn(...args)
    return JSON.stringify(encodeValue({ returned, args }))
  }
}
