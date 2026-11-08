// O que o Swift chama no motor (seção 8.2 do design doc). O script do motor põe o que este módulo
// exporta no global HexEngine, junto com call = makeCall(__modules) e os __modules
// (scripts/build-hexgym-engine.mjs). Entra e sai sempre texto JSON. O documento de dados fica
// aqui dentro, aberto uma vez, e não vai e volta a cada chamada.
import { CATALOGUE, healCustomEx, registerCustom } from '../../../../frontend/src/lib/exercises.js'
import { aliasSnapshot, registerExerciseAliases } from '../../../../frontend/src/lib/exercise-aliases.js'
import { freshState, stateFromSaved } from '../../../../frontend/src/lib/state-core.js'
import { stateJson } from '../../../../frontend/src/lib/state-json.js'
import * as actions from './actions.js'
import * as library from './library.js'
import * as session from './session.js'
import { decodeValue, encodeValue } from './values.js'

// O idioma das telas, dos nomes e dos passos (language.js), que o load() do Swift chama com os
// pacotes de Resources/langs. Não muda o documento.
export { setLanguage } from './language.js'

// O documento aberto; null antes do primeiro.
let current = null

// O tamanho do catálogo e a versão do openGym de que o script saiu ("dev" fora do build, que
// define o __APP_VERSION__ como o vite.config.js do app).
export function info() {
  return JSON.stringify({ exercises: CATALOGUE.length, openGymVersion: typeof __APP_VERSION__ === 'string' ? __APP_VERSION__ : 'dev' })
}

// Os apelidos como o registerExerciseAliases guarda: o mapa, ou {} no lugar do que não é um.
const aliasMap = map => (map && typeof map === 'object' && !Array.isArray(map) ? map : {})

// Cada troca de documento faz o que o boot do app web faz depois de ler a cópia salva
// (store/useStore.js): cura os exercícios personalizados e registra eles e os apelidos, que
// ficam no módulo e não no documento. Sem isso, valeriam os do documento anterior. Os apelidos só
// são registrados quando mudaram de conteúdo: o índice da busca do openGym (corpusOf,
// lib/exercises.js) compara o mapa registrado pela identidade e se refaz inteiro quando ele é
// outro objeto, e todo restore traz um objeto novo, mesmo com os mesmos apelidos. Refazer custava
// mais de 100 ms na primeira busca depois de um restore, no jsc sem JIT (engine-load.mjs).
function open(doc) {
  doc.customEx = healCustomEx(doc.customEx)
  registerCustom(doc.customEx)
  if (JSON.stringify(aliasMap(doc.exAliases)) !== JSON.stringify(aliasSnapshot())) registerExerciseAliases(doc.exAliases)
  current = doc
}

// O primeiro uso, como o do app web (freshState), sem o lang: o HexGym segue o idioma do aparelho
// e nunca grava o lang no documento compartilhado (escolha 4 do plano da fase 2), para não mudar o
// idioma do openGym de quem usa os dois. O langAuto fica: no openGym, ele quer dizer que ninguém
// escolheu o idioma, e o openGym então usa o do navegador (lib/default-lang.js) em vez de gravar um.
export function freshDocument() {
  const doc = freshState()
  delete doc.lang
  open(doc)
  return document()
}

// Uma cópia salva, lida como o app web lê a do aparelho: as chaves dela por cima do DEF, e as
// que esta versão não conhece ficam como estão. O lang fica como veio: o stateFromSaved põe o do
// DEF, ou o detectado, numa cópia sem ele, e o HexGym não grava nenhum (escolha 4). Texto que não é
// JSON lança o SyntaxError do JSON.parse; o documento aberto continua o mesmo.
export function restore(json) {
  const saved = JSON.parse(json)
  if (saved === null || typeof saved !== 'object' || Array.isArray(saved)) throw new TypeError('HexEngine: o documento não é um objeto JSON')
  const doc = stateFromSaved(saved)
  if (Object.hasOwn(saved, 'lang')) doc.lang = saved.lang
  else delete doc.lang
  open(doc)
}

// O documento aberto, no mesmo texto que o app web grava (lib/state-json.js).
export function document() {
  return stateJson(opened())
}

// O documento aberto, ou o erro de antes do primeiro.
function opened() {
  if (!current) throw new Error('HexEngine: nenhum documento aberto')
  return current
}

// A biblioteca (library.js) sobre o documento aberto, para as telas do app: o catálogo, a busca, o
// detalhe de um exercício e as opções dos filtros. A busca recebe o texto JSON da LibraryQuery do
// Swift.
export function catalogue() {
  return JSON.stringify(library.catalogue(opened()))
}

export function search(queryJson) {
  return JSON.stringify(library.search(opened(), JSON.parse(queryJson)))
}

export function exercise(id) {
  return JSON.stringify(library.exercise(opened(), id))
}

export function facets() {
  return JSON.stringify(library.facets(opened()))
}

// As ações sobre o documento aberto (actions.js), com o carimbo do openGym. Recebe o texto JSON da
// EngineAction do Swift e o instante em ms, troca o documento aberto quando a ação mudou alguma
// coisa e devolve { changed, result }. Uma ação inválida lança TypeError, e o documento aberto fica
// o mesmo. Nenhuma ação mexe nos personalizados nem nos apelidos, então não há o que registrar de
// novo (open).
export function apply(actionJson, now) {
  const { doc, changed, result } = actions.apply(opened(), JSON.parse(actionJson), now)
  current = doc
  return JSON.stringify({ changed, result })
}

// As leituras das telas, sem mudar nada: as rotinas, a semana, os ajustes e os planos prontos.
export function routines() {
  return JSON.stringify(actions.routines(opened()))
}

export function week() {
  return JSON.stringify(actions.week(opened()))
}

export function settings() {
  return JSON.stringify(actions.settings(opened()))
}

export function starterPlans() {
  return JSON.stringify(actions.starterPlans())
}

// O treino em andamento (session.js), com o controlador do openGym e o carimbo do update(). Recebe o
// texto JSON da SessionAction do Swift e o instante em ms, troca o documento aberto quando a ação
// mudou alguma coisa e devolve { changed, effects, result }. Uma ação inválida lança TypeError, e o
// documento aberto fica o mesmo. Nenhuma ação do treino mexe nos personalizados nem nos apelidos.
export function sessionApply(actionJson, now) {
  const { doc, changed, effects, result } = session.apply(opened(), JSON.parse(actionJson), now)
  current = doc
  return JSON.stringify({ changed, effects, result })
}

// As leituras das telas do treino, sem mudar nada, no instante em ms: o treino em andamento (ou
// null), a tela inicial e a Live Activity (ou null).
export function activeWorkout(now) {
  return JSON.stringify(session.activeWorkout(opened(), now))
}

export function home(now) {
  return JSON.stringify(session.home(opened(), now))
}

export function liveActivity(now) {
  return JSON.stringify(session.liveActivity(opened(), now))
}

// Os eventos dos botões da Live Activity, em texto JSON, escoados no instante now em ms. Devolve
// { applied, effects } e troca o documento aberto quando algum evento mudou o treino.
export function liveEvents(eventsJson, now) {
  const { doc, applied, effects } = session.liveEvents(opened(), JSON.parse(eventsJson), now)
  current = doc
  return JSON.stringify({ applied, effects })
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
