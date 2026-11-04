// A biblioteca do motor (seções 8.2 e 8.9 do design doc, Task 4 do plano da fase 2): o catálogo, a
// busca, os filtros e o detalhe de cada exercício, para as telas do app. Tudo aqui vem do openGym: a
// busca é o searchExercises (sem acento, no nome traduzido e no inglês), os grupos são os do
// muscles.js e os favoritos, os do favourites.js; nada de busca própria. Os nomes saem no idioma do
// language.js. Cada função recebe o documento aberto, e o runtime.js passa o dele e troca o JSON
// com o Swift.
import { BODYPARTS, EXIDX, allExercises, categoriesOf, equipmentOf, isCustomEx, matchExercise, searchExercises } from '../../../../frontend/src/lib/exercises.js'
import { aliasSnapshot } from '../../../../frontend/src/lib/exercise-aliases.js'
import { MUSCLES, MUSCLE_NAME, matchesMuscleGroups, muscleWeightsOf } from '../../../../frontend/src/lib/muscles.js'
import { favIds, sortFavouritesFirst } from '../../../../frontend/src/lib/favourites.js'
import { descFor, exerciseNameFor, getVersion, instrFor, t } from '../../../../frontend/src/lib/i18n-core.js'

// Uma lista de texto vinda do Swift; o que não é lista conta como nenhum filtro.
const strings = value => (Array.isArray(value) ? value.filter(v => typeof v === 'string') : [])

// O que a lista de exercícios mostra de cada um. O equipamento é o e.eq numa lista (vazia num
// personalizado antigo, que não tem), e a categoria, o e.cat (null num personalizado).
function summary(e, favourites) {
  return {
    id: e.id,
    name: exerciseNameFor(e),
    bp: e.bp || '',
    equipment: e.eq ? [e.eq] : [],
    category: e.cat || null,
    muscles: muscleWeightsOf(e),
    favourite: favourites.has(e.id),
    custom: isCustomEx(e),
  }
}

// O índice de texto da busca. O searchExercises do openGym guarda, para cada exercício, o texto
// normalizado (sem acento, em minúsculas, com o nome no idioma e o inglês) e refaz quando o idioma ou
// os apelidos mudam (corpusOf, lib/exercises.js). Montar ele para os 5.632 exercícios é quase toda a
// primeira busca: no jsc sem JIT, passava da meta de 100 ms por letra. Por isso o catálogo, que a
// lista pede antes da primeira letra, monta o índice uma vez por idioma, passando cada exercício pelo
// matchExercise do openGym com um texto que não casa com nada. Cada documento aberto registra os
// apelidos dele (runtime.js), e o openGym refaz o índice com eles; por isso a chave leva também os
// apelidos. A busca continua a do openGym; aqui só se adianta o índice dela.
const NOTHING = '\u0000'
let indexed = null

function prepareSearch(S) {
  const key = { version: getVersion(), aliases: aliasSnapshot() }
  if (indexed && indexed.version === key.version && indexed.aliases === key.aliases) return
  for (const e of allExercises(S)) matchExercise(e, NOTHING)
  indexed = key
}

// Todos os exercícios, na ordem do allExercises (os personalizados primeiro). Monta o índice da
// busca, quando o idioma ou os apelidos mudaram.
export function catalogue(S) {
  const favourites = new Set(favIds(S))
  const list = allExercises(S).map(e => summary(e, favourites))
  prepareSearch(S)
  return list
}

// Os ids que a busca e os filtros deixam, com os favoritos primeiro. Como a Biblioteca do openGym
// (views/Library.jsx): o texto primeiro, no catálogo inteiro, para o searchExercises decidir a
// tolerância a erro de digitação olhando todos; depois os filtros, cada um com "algum dos
// escolhidos"; por fim, o sortFavouritesFirst. Sem texto e sem filtro, a ordem do catálogo.
export function search(S, query) {
  const q = query && typeof query === 'object' ? query : {}
  const muscles = strings(q.muscles)
  const equipment = new Set(strings(q.equipment))
  const categories = new Set(strings(q.categories))
  const favourites = new Set(favIds(S))
  let list = searchExercises(allExercises(S), typeof q.query === 'string' ? q.query : '')
  if (muscles.length) list = list.filter(e => matchesMuscleGroups(e, muscles))
  if (equipment.size) list = list.filter(e => equipment.has(e.eq))
  if (categories.size) list = list.filter(e => categories.has(e.cat))
  if (q.favouritesOnly === true) list = list.filter(e => favourites.has(e.id))
  return { ids: sortFavouritesFirst(list, S).map(e => e.id) }
}

// O detalhe de um exercício, com o nome em inglês, os passos e a descrição no idioma (o inglês
// quando o idioma não tem). Um id que não existe (apagado, ou personalizado de outro aparelho) é o
// "Exercício desconhecido" do openGym (exOr), com known: false, e não derruba a tela.
export function exercise(S, id) {
  const favourite = favIds(S).includes(id)
  const e = typeof id === 'string' && Object.hasOwn(EXIDX, id) ? EXIDX[id] : null
  if (!e) {
    return {
      id: String(id), name: t('Unknown exercise'), nameEnglish: '', bp: '', equipment: [], category: null, muscles: {},
      instructions: [], description: null, favourite, custom: false, known: false,
    }
  }
  const { custom, ...rest } = summary(e, new Set(favIds(S)))
  return {
    ...rest,
    nameEnglish: e.n || '',
    instructions: strings(instrFor(e)),
    description: descFor(e) || null,
    custom,
    known: true,
  }
}

// As opções dos filtros, com os nomes pelo t(): os grupos na ordem do MUSCLES; o equipamento do
// equipmentOf, só o que filtra alguma coisa, do mais comum ao menos; as categorias do categoriesOf,
// na ordem do CATEGORIES; e as partes do corpo do bp, na ordem do BODYPARTS.
export function facets(S) {
  const list = allExercises(S)
  const named = id => ({ id, name: t(id) })
  return {
    muscles: MUSCLES.map(id => ({ id, name: t(MUSCLE_NAME[id]) })),
    equipment: equipmentOf(list).map(named),
    categories: categoriesOf(list).map(named),
    bodyParts: BODYPARTS.map(named),
  }
}
