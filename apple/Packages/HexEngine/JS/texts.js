// Os textos que o motor escreve para as telas, a partir das funções do openGym (issue #161): o alvo de
// um exercício (o exLine), as séries e as repetições de um slot (o setsRepsOf) e a linha de uma série
// (o setLabel), todas de frontend/src/lib/history.js, que não muda. Aqui ficam duas regras do HexGym
// por cima delas:
//   - nenhum travessão (U+2014) nem meia-risca (U+2013) no texto que a pessoa vê: os dois viram o hífen
//     comum. A faixa da progressão dupla sai "8-12", e o lado ainda não feito de uma série com lados,
//     "D -" (o openGym não tem um texto para "não feito");
//   - nenhum "undefined" nem "NaN": um número do alvo que não é número sai do alvo antes do openGym ler.
//     Os que têm um padrão no openGym (as séries, os segundos, os minutos e a velocidade) ficam com o
//     padrão dele; o alvo sem repetições perde as repetições e o "8/lado" que sai delas, e diz só as
//     séries ("1 série · por lado").
// Só o texto que o motor escreve passa por aqui: o que a pessoa digitou (o nome de uma rotina, uma
// nota) chega às telas como está, para o editor gravar de volta o mesmo texto.
import { exLine, isPerSide, modeOf, setLabel, setsRepsOf } from '../../../../frontend/src/lib/history.js'
import { PYRAMID_MAX, isPyramid } from '../../../../frontend/src/lib/pyramid.js'
import { t, tn } from '../../../../frontend/src/lib/i18n-core.js'

const isMap = v => v !== null && typeof v === 'object' && !Array.isArray(v)

/** O texto com o travessão e a meia-risca trocados pelo hífen comum. */
export const plain = text => String(text ?? '').replace(/[\u2013\u2014]/g, '-')

// Os números de um alvo que o exLine e o setsRepsOf leem.
const NUMBERS = ['sets', 'setsMax', 'reps', 'repsMin', 'weight', 'sec', 'min', 'speed', 'incline']

// O alvo só com os números que são números, e a pirâmide só com os alvos que se leem (repetições de 1
// para cima e o "Max"); uma pirâmide sem nenhum sai, e o alvo volta a ser o de séries e repetições.
export function readableTarget(cfg) {
  const out = isMap(cfg) ? { ...cfg } : {}
  for (const k of NUMBERS) if (k in out && !(typeof out[k] === 'number' && Number.isFinite(out[k]))) delete out[k]
  if ('pyramid' in out) {
    const list = Array.isArray(out.pyramid) ? out.pyramid.filter(v => v === PYRAMID_MAX || (Number.isInteger(v) && v > 0)) : []
    if (list.length) out.pyramid = list
    else delete out.pyramid
  }
  return out
}

// Um alvo de repetições sem o número de repetições (o de um aparelho antigo, ou feito à mão).
const noReps = cfg => modeOf(cfg) === 'reps' && !isPyramid(cfg) && !(cfg.reps > 0)

// "1 série" ou "3-5 séries": as séries de um alvo sem repetições, com a faixa da progressão tripla.
function setsOnly(cfg) {
  const n = cfg.sets || 1
  return cfg.setsMax > n ? t('{0} sets', `${n}-${cfg.setsMax}`) : tn('{0} set', '{0} sets', n)
}

/**
 * O alvo de um exercício, como o exLine do openGym ("3 × 8-12 · 60 kg · 4-6/lado"). Sem repetições,
 * ficam as séries, a carga e o "por lado" ("1 série · por lado").
 */
export function targetText(cfg, unit, speedUnit) {
  const c = readableTarget(cfg)
  if (!noReps(c)) return plain(exLine(c, unit, speedUnit))
  // A carga é a do exLine: o mesmo alvo com uma repetição e sem os lados, menos o "1 × 1" do começo.
  const one = { ...c, reps: 1, side: false }
  delete one.repsMin
  const load = exLine(one, unit, speedUnit).slice(setsRepsOf(one).length)
  return plain(setsOnly(c) + load + (isPerSide(c) ? ' · ' + t('per side') : ''))
}

/** As séries e as repetições de um slot, como o setsRepsOf ("3 × 8-12"); sem repetições, as séries. */
export function setsRepsText(cfg) {
  const c = readableTarget(cfg)
  return plain(noReps(c) ? setsOnly(c) : setsRepsOf(c))
}

/** A linha de uma série, como o setLabel ("E 10×8 · D -"). Lança o que o setLabel lança. */
export const setText = (id, s, target, speedUnit) => plain(setLabel(id, s, target, speedUnit))
