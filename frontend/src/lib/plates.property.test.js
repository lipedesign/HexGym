/* What any plate answer must satisfy, for any weight and any inventory (fast-check). plates.test.js
 * has the worked examples (the rack, the home gym with one pair of each); these are the rules a
 * lifter relies on without checking: the plates add up to what the app says is on the bar, it
 * never hands out plates you do not own, it never loads more than asked, the load is the heaviest
 * these plates can make without going over, and owning more plates never makes the answer worse.
 * Which plates make that load is plateStack's rule: heaviest first when that lands exactly, the
 * way a bar is loaded, even when another stack would need fewer plates; the fewest plates only
 * when heaviest first misses.
 */
import { describe, expect, it } from 'vitest'
import fc from 'fast-check'
import { plateStack, plateDelta, rowLoad, PLATE_SIZES } from './plates.js'

const RUNS = { numRuns: Number(process.env.PROPERTY_RUNS) || 300 }
const sum = a => a.reduce((s, x) => s + x, 0)
const Q = 4 // quarter-units, as plates.js counts
const close = (a, b) => Math.abs(a - b) < 1e-9

// An inventory: some of the real sizes, a few pairs of each, heaviest first like inventoryFor's.
const inventory = (unit = 'kg', maxSizes = 6, maxPairs = 4) =>
  fc.subarray(PLATE_SIZES[unit], { minLength: 0, maxLength: maxSizes })
    .chain(sizes => fc.tuple(...sizes.map(() => fc.integer({ min: 1, max: maxPairs }))).map(ns => sizes.map((w, i) => ({ w, n: ns[i] }))))
    .map(inv => inv.sort((a, b) => b.w - a.w))
// Weights as typed: mostly on the quarter grid, sometimes any decimal.
const weight = fc.oneof(fc.integer({ min: 0, max: 1200 }).map(x => x / 4), fc.double({ min: 0, max: 400, noNaN: true }))
// A small inventory and a weight: half the time as typed, half the time some of those very plates
// added up, so the weight can always be loaded. A typed weight seldom lands exactly heaviest first
// while another stack has fewer plates; a loadable one does now and then (about one case in a
// thousand). What holds those cases in every run are the fixed `examples` below.
const small = inventory('kg', 4, 3)
const loadable = small.chain(inv => fc.tuple(...inv.map(p => fc.integer({ min: 0, max: p.n })))
  .map(ks => [ks.reduce((s, k, i) => s + k * inv[i].w, 0), inv]))
const weightAndSmall = fc.oneof(fc.tuple(weight, small), loadable)

// Every load these plates can make (in quarter-units) with the fewest plates for each: a brute
// force over small inventories to hold the clever answer against.
function reachable(inv) {
  let best = new Map([[0, 0]])
  for (const { w, n } of inv) {
    const next = new Map(best)
    for (const [s, c] of best) for (let k = 1; k <= n; k++) {
      const t = s + k * Math.round(w * Q)
      if (!next.has(t) || next.get(t) > c + k) next.set(t, c + k)
    }
    best = next
  }
  return best
}

// Heaviest first, as a lifter loads a bar: as many of each size as still fit, biggest size first.
// Written again here, not taken from plates.js, so the test does not lean on the code it checks.
// `exact` says whether it lands on the weight (in quarter-units, like the rest).
function heaviestFirst(w, inv) {
  let left = Math.floor(Math.max(0, w) * Q)
  const plates = []
  for (const { w: size, n } of [...inv].sort((a, b) => b.w - a.w)) {
    const unit = Math.round(size * Q)
    for (let k = Math.min(n, Math.floor(left / unit)); k > 0; k--) { plates.push(size); left -= unit }
  }
  return { plates, exact: left === 0 }
}

// When heaviest first misses, the stack plateStack promises for `load` (quarter-units): the fewest
// plates, and among stacks with that many, the heaviest plate in each place, in order. A brute
// force over every count of every size, fine for small inventories.
function fewestHeaviest(inv, load) {
  const sizes = [...inv].sort((a, b) => b.w - a.w)
  // Fewer plates wins; with as many, the heavier plate at the first place they differ.
  const better = (a, b) => {
    if (a.length !== b.length) return a.length < b.length
    const j = a.findIndex((x, i) => x !== b[i])
    return j >= 0 && a[j] > b[j]
  }
  let best = null
  const walk = (i, left, stack) => {
    if (left === 0) { if (!best || better(stack, best)) best = [...stack]; return }
    if (i === sizes.length) return
    const unit = Math.round(sizes[i].w * Q)
    for (let k = 0; k <= sizes[i].n && k * unit <= left; k++) walk(i + 1, left - k * unit, [...stack, ...Array(k).fill(sizes[i].w)])
  }
  walk(0, load, [])
  return best
}

describe('plates for a weight', () => {
  it('add up to what is on the bar: plates + missing = the weight asked for', () => {
    fc.assert(fc.property(weight, inventory(), (w, inv) => {
      const { plates, missing } = plateStack(w, inv)
      expect(missing).toBeGreaterThanOrEqual(-1e-9)
      expect(close(sum(plates) + missing, Math.max(0, w))).toBe(true)
    }), RUNS)
  })

  it('never use a plate you do not own, nor more of a size than you have', () => {
    fc.assert(fc.property(weight, inventory(), (w, inv) => {
      const { plates } = plateStack(w, inv)
      for (const p of new Set(plates)) {
        const own = inv.find(x => x.w === p)
        expect(own, `${p} is not in the inventory`).toBeDefined()
        expect(plates.filter(x => x === p).length).toBeLessThanOrEqual(own.n)
      }
    }), RUNS)
  })

  it('come heaviest first, the order they go on the bar', () => {
    fc.assert(fc.property(weight, inventory(), (w, inv) => {
      const { plates } = plateStack(w, inv)
      expect(plates).toEqual([...plates].sort((a, b) => b - a))
    }), RUNS)
  })

  it('are the heaviest load you can make without going over', () => {
    fc.assert(fc.property(weightAndSmall, ([w, inv]) => {
      const { plates } = plateStack(w, inv)
      const target = Math.floor(Math.max(0, w) * Q)
      const bestSum = Math.max(...[...reachable(inv).keys()].filter(s => s <= target))
      expect(Math.round(sum(plates) * Q)).toBe(bestSum)
    }), RUNS)
  })

  it('are the heaviest-first stack when it lands exactly, and the fewest plates only when it misses, heavier on ties', () => {
    fc.assert(fc.property(weightAndSmall, ([w, inv]) => {
      const { plates } = plateStack(w, inv)
      const greedy = heaviestFirst(w, inv)
      // Landing exactly, heaviest first wins even with more plates (55 from 25, 25, 2.5, 2.5
      // and not 25, 15, 15: plates.test.js).
      if (greedy.exact) { expect(plates).toEqual(greedy.plates); return }
      const target = Math.floor(Math.max(0, w) * Q)
      const options = reachable(inv)
      const bestSum = Math.max(...[...options.keys()].filter(s => s <= target))
      expect(Math.round(sum(plates) * Q)).toBe(bestSum)
      expect(plates.length).toBe(options.get(bestSum))
      // Among stacks with that many plates, the heaviest plate in each place.
      expect(plates).toEqual(fewestHeaviest(inv, bestSum))
    }), {
      ...RUNS,
      examples: [
        [[55, [{ w: 25, n: 2 }, { w: 15, n: 2 }, { w: 2.5, n: 2 }]]], // heaviest first lands, with more plates
        [[40, [{ w: 25, n: 2 }, { w: 20, n: 2 }, { w: 10, n: 2 }]]], // heaviest first misses: 20 + 20, not 20 + 10 + 10
        [[55, [{ w: 25, n: 2 }, { w: 20, n: 2 }, { w: 15, n: 2 }]]], // a tie of three plates: 25 + 15 + 15, not 20 + 20 + 15
      ],
    })
  })

  it('never get worse when you own more plates', () => {
    fc.assert(fc.property(weight, inventory(), fc.constantFrom(...PLATE_SIZES.kg), (w, inv, extra) => {
      const more = inv.some(x => x.w === extra) ? inv.map(x => (x.w === extra ? { ...x, n: x.n + 1 } : x)) : [...inv, { w: extra, n: 1 }].sort((a, b) => b.w - a.w)
      expect(plateStack(w, more).missing).toBeLessThanOrEqual(plateStack(w, inv).missing + 1e-9)
    }), RUNS)
  })

  it('in lb as in kg', () => {
    fc.assert(fc.property(weight, inventory('lb'), (w, inv) => {
      const { plates, missing } = plateStack(w, inv)
      expect(close(sum(plates) + missing, Math.max(0, w))).toBe(true)
    }), RUNS)
  })
})

describe('the load line of a set row', () => {
  it('on a bar: base + both sides + what is missing on both sides = the logged weight', () => {
    fc.assert(fc.property(fc.integer({ min: 1, max: 1200 }).map(x => x / 4), fc.constantFrom(0, 10, 15, 20), inventory(), (w, bar, inv) => {
      const r = rowLoad('pairs', w, bar, inv)
      if (w <= bar) { expect(r.barOnly).toBe(true); return }
      expect(r.barOnly).toBe(false)
      expect(Math.abs(bar + 2 * (sum(r.plates) + r.missing) - w)).toBeLessThan(0.02 + 1e-9)
    }), RUNS)
  })

  it('a single stack may use both plates of a pair, a bar side only one', () => {
    fc.assert(fc.property(fc.integer({ min: 1, max: 800 }).map(x => x / 4), inventory(), (w, inv) => {
      const single = rowLoad('single', w, 0, inv)
      for (const p of new Set(single.plates)) expect(single.plates.filter(x => x === p).length).toBeLessThanOrEqual(2 * inv.find(x => x.w === p).n)
      // Twice the plates to choose from never leaves more missing than one side of a bar would.
      expect(single.missing).toBeLessThanOrEqual(plateStack(w, inv).missing + 1e-9)
    }), RUNS)
  })

  it('has nothing to load for dumbbells, cables or an empty weight', () => {
    fc.assert(fc.property(weight, inventory(), (w, inv) => {
      expect(rowLoad('none', w, 0, inv)).toBeNull()
      expect(rowLoad('pairs', 0, 20, inv)).toBeNull()
    }), { numRuns: 50 })
  })
})

describe('changing plates between sets', () => {
  it('taking off what comes off and putting on what goes on turns one stack into the next', () => {
    const stack = fc.array(fc.constantFrom(...PLATE_SIZES.kg), { maxLength: 10 })
    fc.assert(fc.property(stack, stack, (prev, next) => {
      const { strip, add } = plateDelta(prev, next)
      const after = [...prev]
      for (const p of strip) after.splice(after.indexOf(p), 1)
      after.push(...add)
      expect(after.sort((a, b) => a - b)).toEqual([...next].sort((a, b) => a - b))
      // and nothing is taken off only to go straight back on
      expect(strip.filter(p => add.includes(p))).toEqual([])
    }), RUNS)
  })
})
