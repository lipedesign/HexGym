// The printable plan (Save as PDF): the week's routines, or one routine on its own page, laid out
// so a single exercise never splits across a page break; each exercise, and each routine that
// fits, stays in one place. Kept apart from lib/plan-share.js, the plan file a friend imports, so
// that file loads without the print code (lib/print-doc.js, and through it lib/mobile.js).

import { EXIDX } from './exercises.js'
import { modeOf, exLine } from './history.js'
import { deriveSessionName } from './session-merge.js'
import { todayISO, DAYN, weekOrder, weekStartOf, exCount, routineCount } from './format.js'
import { t, exerciseNameFor, exerciseNameClass } from './i18n-core.js'
import { fmtSpeed, speedUnitOf } from './speed.js'
import { esc, printShell, printDocument, probeMarks } from './print-doc.js'
import { cleanIntensifier } from './plan-share.js'

// One exercise's scheme, e.g. "3 × 8–12 · 60 kg · drop-set 1× −20%", "3 × 0:45" or
// "2 × 20 min @ 8 km/h" — the speed in the profile's unit (lib/speed.js), like the weight. The
// reps half is exLine's, so a double-progression range prints as the range it is ("8–12", not
// the top alone) and a per-side split reads "8/side" exactly as the routine editor shows it.
// As parts: the sets line, then what comes on top of it, each printed on a line of its own so the
// sets line never wraps in the middle of "4 × 12 · 35 kg".
function schemeParts(e, unit, speedUnit) {
  const sets = e.sets || 1
  const mode = modeOf(e)
  if (mode === 'cardio') {
    const body = `${e.min || 20} min @ ${fmtSpeed(e.speed || 8, speedUnit)}`
    return [sets > 1 ? `${sets} × ${body}` : body]
  }
  const line = exLine({ ...e, reps: e.reps ?? 10 }, unit, speedUnit)
  const extras = [intensifierLine(e.intensifier), e.lastToFailure === true ? t('Last set to failure') : ''].filter(Boolean)
  return [line, ...extras]
}
// The extra lines keep their " · " in the text (hidden on paper), so copied text reads as one line.
const schemeHTML = parts => parts.map((p, i) => i === 0
  ? `<span class="s-main">${esc(p)}</span>`
  : `<span class="s-x"><span class="sep"> · </span>${esc(p)}</span>`).join('')

// A drop-set or rest-pause is how the exercise is prescribed, so the printout names it — the
// sheet at the rack otherwise reads as plain straight sets.
function intensifierLine(x) {
  const intens = cleanIntensifier(x)
  if (!intens) return ''
  return intens.type === 'dropset'
    ? `${t('Drop-set')} ${intens.count}× −${intens.pct}%`
    : `${t('Rest-pause')} ${intens.totalReps} ${t('reps')}`
}

// Group consecutive exercises sharing a superset id into rendered units.
function units(ex) {
  const out = []
  ex.forEach((e, i) => {
    const prev = ex[i - 1]
    if (i > 0 && e.sg && prev?.sg === e.sg) out[out.length - 1].push(e)
    else out.push([e])
  })
  return out
}

/**
 * An exercise's printed name: the display name, and on a line of its own the English title the
 * app adds in parentheses to a translated one ("Bankdrücken mit Langhantel (barbell bench press)"),
 * so a long German name wraps once instead of three times. Shared with the workout printouts.
 */
export function printedName(ex, fallback) {
  if (!ex) return { name: fallback || t('Unknown exercise'), en: '', cls: '' }
  const full = exerciseNameFor(ex)
  const suffix = ` (${ex.n})`
  const split = ex.n && full !== ex.n && full.endsWith(suffix)
  return { name: split ? full.slice(0, -suffix.length) : full, en: split ? ex.n : '', cls: exerciseNameClass(ex) }
}

// One exercise row. `n` is its number in the routine; `ticks` draws a box per set to tick off at
// the gym (the single-routine sheet, which is the one you take with you).
function exerciseHTML(e, n, unit, { speedUnit, ticks }) {
  const ex = EXIDX[e.id]
  const { name, en, cls } = printedName(ex)
  // Translated, and set apart by a real space: glued to the name, "capitalize" read the two as
  // one word and printed "Curlupper Legs".
  const part = ex && ex.bp && ex.bp !== 'cardio' ? ` <span class="part">${esc(t(ex.bp))}</span>` : ''
  const boxes = ticks ? `<div class="ticks">${'<i></i>'.repeat(Math.min(12, Math.max(1, e.sets || 1)))}</div>` : ''
  return `<div class="ex"><div class="ex-num">${n}</div><div class="ex-main">`
    + `<div class="ex-n ${ex ? cls : ''}">${esc(name)}${part}</div>`
    + (en ? `<div class="ex-en">${esc(en)}</div>` : '')
    + (e.note ? `<div class="ex-note">${esc(e.note)}</div>` : '')
    + `</div><div class="ex-s">${schemeHTML(schemeParts(e, unit, speedUnit))}${boxes}</div></div>`
}

// A routine as a run of blocks that each stay whole on a page: one per exercise, one per superset.
// The routine's heading (and, for the first routine, the section heading above it) travels inside
// the first block, so it can never be stranded at the bottom of a page with its exercises overleaf.
// The routine itself may run over a page: holding all of it together left whole pages blank.
function routineHTML(r, unit, { bare = false, speedUnit, ticks = false, lead = '', m, key }) {
  let n = 0
  const list = units(r.ex)
  const blocks = list.map((u, bi) => {
    const items = u.map(e => exerciseHTML(e, ++n, unit, { speedUnit, ticks })).join('')
    const body = u.length > 1
      ? `<div class="ss"><div class="ss-tag">${esc(t('Superset'))}</div>${items}</div>`
      : items
    const id = `${key}-${bi}`
    const head = bi === 0
      ? lead + (bare ? '' : `${m.h(id)}<div class="r-head"><h2>${esc(r.name)}</h2><span class="r-count">${esc(exCount(r.ex.length))}</span></div>`)
      : ''
    return `<div class="keep">${m.s(id)}${head}${body}${m.e(id)}</div>`
  })
  if (!blocks.length) blocks.push(`<div class="keep">${lead}${bare ? '' : `<div class="r-head"><h2>${esc(r.name)}</h2></div>`}<div class="none">${esc(t('No exercises yet.'))}</div></div>`)
  return `<section class="routine">${blocks.join('')}</section>`
}

function weekHTML(S, m) {
  // The printout is read by whoever exported it, so the week runs in their order.
  const rows = weekOrder(weekStartOf(S)).map(d => {
    const names = [].concat(S.week?.[d] || [])
      .map(id => S.routines.find(x => x.id === id)?.name)
      .filter(Boolean)
    const val = names.length ? esc(deriveSessionName(names)) : `<span class="rest">${esc(t('Rest'))}</span>`
    return `<tr><th scope="row">${esc(t(DAYN[d]))}</th><td>${val}</td></tr>`
  }).join('')
  return `<div class="keep">${m.s('week')}${m.h('week')}<h3 class="sec-h first">${esc(t('Week schedule'))}</h3><table class="week">${rows}</table>${m.e('week')}</div>`
}

const PLAN_CSS = `
  .routine { margin-bottom: 8pt; }
  .r-head { display: flex; align-items: baseline; justify-content: space-between; gap: 10pt; margin: 14pt 0 2pt; padding-bottom: 4pt; border-bottom: 1.5px solid var(--ink); }
  .r-head h2 { font-size: 13pt; letter-spacing: -.01em; margin: 0; overflow-wrap: anywhere; }
  .r-count { font-size: 8pt; color: var(--muted); white-space: nowrap; }

  .ex { display: flex; align-items: flex-start; gap: 8pt; padding: 6pt 0; border-bottom: 1px solid var(--rule-soft); }
  .ex-num { flex: none; width: 14pt; height: 14pt; margin-top: 1pt; border-radius: 50%; background: var(--tint); color: var(--muted);
    font-size: 7pt; font-weight: 700; line-height: 14pt; text-align: center; }
  .ex-main { flex: 1 1 auto; min-width: 0; }
  .ex-n { font-weight: 600; overflow-wrap: anywhere; }
  .ex-n.capitalize { text-transform: capitalize; }
  .ex-n .part { display: inline-block; text-transform: none; color: var(--faint); font-weight: 400; font-size: 8pt; margin-inline-start: 3pt; }
  .ex-n .part::first-letter { text-transform: uppercase; }
  .ex-en { color: var(--faint); font-size: 8pt; text-transform: capitalize; overflow-wrap: anywhere; }
  .ex-note { color: var(--ink-2); font-size: 8.5pt; margin-top: 2pt; font-style: italic; }
  .ex-s { flex: none; max-width: 46%; text-align: end; color: var(--ink-2); font-weight: 500; }
  .ex-s .s-main { display: block; white-space: nowrap; }
  .ex-s .s-x { display: block; font-size: 8pt; font-weight: 400; color: var(--muted); }
  .ex-s .sep { display: none; }
  .ticks { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 3pt; margin-top: 4pt; }
  .ticks i { display: block; width: 9pt; height: 9pt; border: 1px solid #c4c9d2; border-radius: 2pt; }

  .ss { border-inline-start: 2.5pt solid var(--lime); padding-inline-start: 8pt; margin: 4pt 0; }
  .ss-tag { font-size: 7pt; letter-spacing: .1em; text-transform: uppercase; color: var(--lime-ink); font-weight: 700; padding-top: 5pt; }
  .ss .ex:last-child { border-bottom: 0; }

  table.week th { width: 32%; text-transform: none; letter-spacing: 0; font-size: 9pt; color: var(--ink); font-weight: 600; padding: 4pt 8pt 4pt 0; border-bottom: 1px solid var(--rule-soft); }
  table.week td { padding: 4pt 0; }
  table.week tr:last-child th, table.week tr:last-child td { border-bottom: 0; }
  .rest { color: var(--faint); }
`

/**
 * Full self-contained HTML for the print/PDF view. With `routineId` it is that one routine on
 * its own page (#282) — the session you take to the gym, not the week around it — so the week
 * schedule is left out and the routine's name is the page title. `probe` is for the layout check
 * (lib/print-doc.js probeMarks), never set in the app.
 */
export function planPrintHTML(S, owner, { routineId, probe = false } = {}) {
  const m = probeMarks(probe)
  const unit = S.unit || 'kg'
  const speedUnit = speedUnitOf(S)
  const single = routineId ? (S.routines || []).find(r => r.id === routineId) || null : null
  const routines = routineId ? [single].filter(Boolean) : (S.routines || []).filter(r => r.ex && r.ex.length)
  const lead = routineId ? '' : `<h3 class="sec-h">${esc(t('Routines'))}</h3>`
  const body = routines.length
    ? routines.map((r, i) => routineHTML(r, unit, { bare: !!single, speedUnit, ticks: !!single, lead: i === 0 ? lead : '', m, key: 'r' + i })).join('')
    : `<p class="none">${esc(t('No routines yet.'))}</p>`
  const title = single ? single.name : t('Weekly Training Plan')
  const facts = single ? [exCount(single.ex.length)] : [routineCount(routines.length)]
  return printShell({
    title, kicker: single ? t('Routine') : t('Training plan'), facts, owner, date: todayISO(),
    body: (routineId ? '' : weekHTML(S, m)) + body,
    css: PLAN_CSS,
  })
}

/**
 * Print the plan: the browser's print dialog (→ Save as PDF) on the web.
 * `opts` is planPrintHTML's: `{ routineId }` prints a single routine.
 */
export function printPlan(S, owner, opts) {
  return printDocument(planPrintHTML(S, owner, opts), opts?.routineId ? (S.routines || []).find(r => r.id === opts.routineId)?.name : t('Weekly Training Plan'))
}
