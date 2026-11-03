// O que o JavaScriptCore não tem e o motor usa, vindo do Swift (seção 8.2 do design doc): o console,
// que vai para o log do sistema, e o setTimeout e o clearTimeout, com o tempo contado no Swift. O
// structuredClone vem no próprio script do motor (apple/Packages/HexEngine/JS/polyfills.js).
//
// O HexEngine.swift avalia este arquivo antes do script do motor, depois de pôr no global as duas
// pontes do Swift, que este arquivo guarda e tira do global:
//   __hexgymLog(nível, texto)   escreve no Logger(subsystem: "app.hexgym", category: "motor"), no
//                               nível do método: log, info, debug, warn ou error;
//   __hexgymSchedule(id, ms)    dorme ms num Task do Swift e, de volta ao ator, chama __hexgymFire(id).
// Cada timer fica no Map daqui até disparar ou ser cancelado. O clearTimeout só o tira do Map, e o
// __hexgymFire de um timer que não está mais lá não faz nada. Uma exceção dentro de um timer volta
// ao Swift, que a escreve no log como erro.
(function () {
  const log = globalThis.__hexgymLog
  const schedule = globalThis.__hexgymSchedule
  delete globalThis.__hexgymLog
  delete globalThis.__hexgymSchedule

  // Um argumento do console como texto: um Error com a pilha, um objeto em JSON (ou o tipo dele,
  // quando o JSON não sai) e o resto como o String daria.
  const show = v => {
    if (typeof v === 'string') return v
    if (v instanceof Error) return v.stack ? `${v}\n${v.stack}` : String(v)
    if (v !== null && typeof v === 'object') {
      try {
        return JSON.stringify(v) ?? Object.prototype.toString.call(v)
      } catch {
        return Object.prototype.toString.call(v)
      }
    }
    return String(v)
  }
  const writer = level => (...args) => log(level, args.map(show).join(' '))
  globalThis.console = { log: writer('log'), info: writer('info'), debug: writer('debug'), warn: writer('warn'), error: writer('error') }

  // O maior atraso que um navegador conta (2^31 - 1 ms); um atraso que não é número, ou negativo, é 0.
  const MAX_DELAY = 2147483647
  const timers = new Map()
  let last = 0
  globalThis.setTimeout = (fn, ms, ...args) => {
    if (typeof fn !== 'function') throw new TypeError('setTimeout: o motor só aceita uma função')
    const id = ++last
    const delay = Number(ms)
    timers.set(id, () => fn(...args))
    schedule(id, Number.isFinite(delay) && delay > 0 ? Math.min(delay, MAX_DELAY) : 0)
    return id
  }
  globalThis.clearTimeout = id => {
    timers.delete(id)
  }
  Object.defineProperty(globalThis, '__hexgymFire', {
    value: id => {
      const run = timers.get(id)
      if (!run) return
      timers.delete(id)
      run()
    },
  })
})()
