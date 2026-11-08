// O idioma do motor (seção 8.9 do design doc e escolha 4 do plano da fase 2). Faz o que o setLang do
// lib/i18n.js faz, sem o navegador: em vez do import.meta.glob, recebe do Swift o texto de dois
// pacotes gerados por scripts/build-hexgym-langs.mjs, o en e o do idioma. Depois dele, t(),
// exerciseNameFor, instrFor e descFor do i18n-core.js respondem no idioma.
//
// O idioma segue o do aparelho e nunca é gravado no documento: nada aqui mexe no documento aberto.
// O nome sai sem o inglês entre parênteses (showEn = false); o inglês aparece no detalhe do
// exercício (escolha recomendada, com a delegação do Lipe de 03/11/2026).
//
// O descTranslated diz se a descrição que o descFor mostra veio do pacote do idioma, e não do inglês,
// como o instrTranslated do i18n-core.js diz dos passos (issue #114). O i18n-core.js não exporta o
// pacote de descrições que guarda, então o motor guarda o mesmo pacote aqui, a cada setLanguage.
import { LANGS, _setDetails, _setLangState, baseLang, derivePack, getLang } from '../../../../frontend/src/lib/i18n-core.js'

const parsed = (json, what) => {
  const pack = JSON.parse(json)
  if (pack === null || typeof pack !== 'object' || Array.isArray(pack)) throw new TypeError(`HexEngine: o pacote ${what} não é um objeto JSON`)
  return pack
}

// O pacote de descrições do idioma, o mesmo que o _setDetails guardou no i18n-core.js.
let ownDescs = null

// enJson é o texto do pacote en; langJson, o do idioma, ou null para o inglês. O tag é o idioma de
// LANGS que o aparelho pediu, e por padrão é o do pacote; um derivado (de-CH) chega com o pacote da
// base (de), e cada parte passa pelo derivePack. Devolve o idioma que ficou.
export function setLanguage(enJson, langJson = null, tag = undefined) {
  const en = parsed(enJson, 'en')
  if (en.lang !== 'en') throw new TypeError(`HexEngine: o primeiro pacote devia ser o en, e veio ${en.lang}`)
  const pack = langJson == null ? null : parsed(langJson, 'do idioma')
  const lang = tag ?? pack?.lang ?? 'en'
  if (!Object.hasOwn(LANGS, lang)) throw new TypeError(`HexEngine: o idioma ${lang} não está no LANGS do openGym`)
  if (pack && baseLang(lang) !== pack.lang) throw new TypeError(`HexEngine: o pacote é do ${pack.lang}, e o idioma ${lang} usa o do ${baseLang(lang)}`)
  const own = part => (pack ? derivePack(lang, pack[part] ?? null) : null)
  const descs = own('desc')
  _setLangState(lang, own('dict'), own('instr'), own('names'), false, false)
  _setDetails(en.instr, en.desc, descs, lang)
  // O _setDetails só guarda as descrições do idioma fora do inglês; aqui, o mesmo.
  ownDescs = lang === 'en' ? null : descs
  return getLang()
}

// A descrição do descFor veio do pacote do idioma, como o instrTranslated dos passos.
export const descTranslated = ex => !!(ownDescs && ex && Object.hasOwn(ownDescs, ex.id) && ownDescs[ex.id])
