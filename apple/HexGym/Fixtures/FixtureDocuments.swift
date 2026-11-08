// Os sete documentos preparados (os cinco da Task 6 do plano da fase 3 e os dois do Início da Task 7),
// como texto JSON, no formato do documento do openGym, com a chave _fixtureNow, o instante em que cada
// um "está" (o FixtureLoader leva tudo para hoje e tira a chave). Foram montados pelo próprio motor (o runtime.js e o
// controlador do treino: começar, mudar a carga, marcar, terminar) num relógio de São Paulo, com o
// _fixtureNow na segunda, 9 de novembro de 2026, 12 h em UTC, e por isso abrem como o app abriria:
//   semana-ppl           as três rotinas do PPL na semana (Push na segunda, Pull na quarta e Legs na
//                        sexta), 12 treinos em quatro semanas, com a carga subindo, e o Push no
//                        dayPlan de hoje. O treino mais antigo não tem id, como os do openGym de antes
//                        do id (a chave dele muda a cada dia: os prints abrem os outros);
//   treino-em-andamento  o histórico do semana-ppl e o Push de hoje com 5 séries feitas (o supino
//                        inteiro, com carga de recorde, e a primeira volta do superset), sem descanso;
//   descanso             o mesmo, com 75 s de descanso pela frente;
//   vazio                o documento novo, o do primeiro uso;
//   veio-do-opengym      um treino do openGym, sem rest e sem progress, em lista, com aquecimento,
//                        drop set, rest-pause, lados, cardio, série com tempo, pirâmide, noProg e um
//                        exercício que não existe neste aparelho (Foco da revisão 4);
//   dia-de-descanso      o semana-ppl com o hoje marcado como descanso no dayPlan: "Dia de descanso" e a
//                        próxima sessão da semana, qualquer que seja o dia do print (Task 7, rodada 2 do
//                        PR #157);
//   nada-marcado         o semana-ppl sem a semana e sem o dayPlan: as rotinas e o histórico, e nada
//                        marcado para hoje nem para os próximos dias (Task 7, rodada 2 do PR #157).
// Os dois últimos saem do texto do semana-ppl, trocando só o plano, para o histórico ser o mesmo.
//
// Inteiro dentro do #if DEBUG, como o FixtureLoader: nada daqui entra no build Release.

#if DEBUG
enum FixtureDocuments {
  static let names = ["semana-ppl", "treino-em-andamento", "descanso", "vazio", "veio-do-opengym", "dia-de-descanso",
                       "nada-marcado"]

  static func text(named name: String) -> String? {
    switch name {
    case "semana-ppl": semanaPPL
    case "treino-em-andamento": treinoEmAndamento
    case "descanso": descanso
    case "vazio": vazio
    case "veio-do-opengym": veioDoOpenGym
    case "dia-de-descanso": diaDeDescanso
    case "nada-marcado": nadaMarcado
    default: nil
    }
  }

  // O plano do semana-ppl, que os dois documentos do Início trocam.
  private static let pplWeek = #""week": {"1":["r-push"],"3":["r-pull"],"5":["r-legs"]},"#
  private static let pplDayPlan = #""dayPlan": {"2026-11-09":"r-push"},"#

  static var diaDeDescanso: String {
    semanaPPL.replacing(pplDayPlan, with: #""dayPlan": {"2026-11-09":"rest"},"#)
  }

  static var nadaMarcado: String {
    semanaPPL.replacing(pplWeek, with: #""week": {},"#).replacing(pplDayPlan, with: #""dayPlan": {},"#)
  }

  static let semanaPPL = #"""
    {
      "_fixtureNow": 1794225600000,
      "unit": "kg",
      "restSec": 90,
      "restPauseSec": 15,
      "sound": true,
      "soundOnSilent": false,
      "vibrateOnSilent": false,
      "timerFlash": false,
      "timedSetOvertime": false,
      "keepAwake": true,
      "theme": "dark",
      "accent": "lime",
      "body": "male",
      "targetW": null,
      "rateGoal": null,
      "bodyweight": [
        {"d":"2026-10-12","w":82.1},
        {"d":"2026-10-19","w":81.8},
        {"d":"2026-10-26","w":81.5},
        {"d":"2026-11-02","w":81.2},
        {"d":"2026-11-09","w":80.9}
      ],
      "routines": [
        {"id":"r-push","name":"Push","emoji":"barbell","ex":[{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"}]},
        {"id":"r-pull","name":"Pull","emoji":"pullup","ex":[{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"}]},
        {"id":"r-legs","name":"Legs","emoji":"figureStrength","ex":[{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"}]}
      ],
      "week": {"1":["r-push"],"3":["r-pull"],"5":["r-legs"]},
      "dayPlan": {"2026-11-09":"r-push"},
      "dayNotes": {},
      "measurements": [],
      "measurementEnabled": null,
      "customMeasurements": [],
      "queue": null,
      "rotation": null,
      "scheduleMode": null,
      "exWeights": {"1162":{"w":47.5,"d":"2026-11-02"},"0025":{"w":67.5,"d":"2026-11-02"},"0294":{"w":15,"d":"2026-11-02"},"0047":{"w":47.5,"d":"2026-11-02"},"0201":{"w":28,"d":"2026-11-02"},"0027":{"w":67.5,"d":"2026-11-04"},"0150":{"w":57.5,"d":"2026-11-04"},"0032":{"w":115,"d":"2026-11-04"},"0043":{"w":115,"d":"2026-11-06"},"0739":{"w":165,"d":"2026-11-06"},"0085":{"w":77.5,"d":"2026-11-06"}},
      "workouts": [
        {"d":"2026-10-12","start":1791840600000,"end":1791842670000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":82.1,"entries":[{"id":"0025","sets":[{"w":60,"r":8,"done":true,"at":1791840720000},{"w":60,"r":8,"done":true,"at":1791840870000},{"w":60,"r":8,"done":true,"at":1791841020000}],"topW":60,"target":{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":12,"r":10,"done":true,"at":1791841170000},{"w":12,"r":10,"done":true,"at":1791841470000}],"topW":12,"target":{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":40,"r":10,"done":true,"at":1791841320000},{"w":40,"r":10,"done":true,"at":1791841620000}],"topW":40,"target":{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":40,"r":8,"done":true,"at":1791841770000},{"w":40,"r":8,"done":true,"at":1791841920000},{"w":40,"r":8,"done":true,"at":1791842070000}],"topW":40,"target":{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":25,"r":12,"done":true,"at":1791842220000},{"w":25,"r":12,"done":true,"at":1791842370000},{"w":25,"r":12,"done":true,"at":1791842520000}],"topW":25,"target":{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4340},
        {"id":"w-2026-10-14-pull","d":"2026-10-14","start":1792013400000,"end":1792014870000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":82.1,"entries":[{"id":"0027","sets":[{"w":60,"r":8,"done":true,"at":1792013520000},{"w":60,"r":8,"done":true,"at":1792013670000},{"w":60,"r":8,"done":true,"at":1792013820000}],"topW":60,"target":{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":50,"r":10,"done":true,"at":1792013970000},{"w":50,"r":10,"done":true,"at":1792014120000},{"w":50,"r":10,"done":true,"at":1792014270000}],"topW":50,"target":{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":100,"r":5,"done":true,"at":1792014420000},{"w":100,"r":5,"done":true,"at":1792014570000},{"w":100,"r":5,"done":true,"at":1792014720000}],"topW":100,"target":{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4440},
        {"id":"w-2026-10-16-legs","d":"2026-10-16","start":1792184400000,"end":1792185870000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":82.1,"entries":[{"id":"0043","sets":[{"w":100,"r":5,"done":true,"at":1792184520000},{"w":100,"r":5,"done":true,"at":1792184670000},{"w":100,"r":5,"done":true,"at":1792184820000}],"topW":100,"target":{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":150,"r":10,"done":true,"at":1792184970000},{"w":150,"r":10,"done":true,"at":1792185120000},{"w":150,"r":10,"done":true,"at":1792185270000}],"topW":150,"target":{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":70,"r":8,"done":true,"at":1792185420000},{"w":70,"r":8,"done":true,"at":1792185570000},{"w":70,"r":8,"done":true,"at":1792185720000}],"topW":70,"target":{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7680},
        {"id":"w-2026-10-19-push","d":"2026-10-19","start":1792445400000,"end":1792447470000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.8,"entries":[{"id":"0025","sets":[{"w":62.5,"r":8,"done":true,"at":1792445520000},{"w":62.5,"r":8,"done":true,"at":1792445670000},{"w":62.5,"r":8,"done":true,"at":1792445820000}],"topW":62.5,"target":{"id":"0025","sets":3,"reps":8,"weight":62.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":13,"r":10,"done":true,"at":1792445970000},{"w":13,"r":10,"done":true,"at":1792446270000}],"topW":13,"target":{"id":"0294","sets":2,"reps":10,"weight":14.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":42.5,"r":10,"done":true,"at":1792446120000},{"w":42.5,"r":10,"done":true,"at":1792446420000}],"topW":42.5,"target":{"id":"0047","sets":2,"reps":10,"weight":42.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":42.5,"r":8,"done":true,"at":1792446570000},{"w":42.5,"r":8,"done":true,"at":1792446720000},{"w":42.5,"r":8,"done":true,"at":1792446870000}],"topW":42.5,"target":{"id":"1162","sets":3,"reps":8,"weight":42.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":26,"r":12,"done":true,"at":1792447020000},{"w":26,"r":12,"done":true,"at":1792447170000},{"w":26,"r":12,"done":true,"at":1792447320000}],"topW":26,"target":{"id":"0201","sets":3,"reps":12,"weight":27.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4566},
        {"id":"w-2026-10-21-pull","d":"2026-10-21","start":1792618200000,"end":1792619670000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.8,"entries":[{"id":"0027","sets":[{"w":62.5,"r":8,"done":true,"at":1792618320000},{"w":62.5,"r":8,"done":true,"at":1792618470000},{"w":62.5,"r":8,"done":true,"at":1792618620000}],"topW":62.5,"target":{"id":"0027","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":52.5,"r":10,"done":true,"at":1792618770000},{"w":52.5,"r":10,"done":true,"at":1792618920000},{"w":52.5,"r":10,"done":true,"at":1792619070000}],"topW":52.5,"target":{"id":"0150","sets":3,"reps":10,"weight":55,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":105,"r":5,"done":true,"at":1792619220000},{"w":105,"r":5,"done":true,"at":1792619370000},{"w":105,"r":5,"done":true,"at":1792619520000}],"topW":105,"target":{"id":"0032","sets":3,"reps":5,"weight":102.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4650},
        {"id":"w-2026-10-23-legs","d":"2026-10-23","start":1792789200000,"end":1792790670000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.8,"entries":[{"id":"0043","sets":[{"w":105,"r":5,"done":true,"at":1792789320000},{"w":105,"r":5,"done":true,"at":1792789470000},{"w":105,"r":5,"done":true,"at":1792789620000}],"topW":105,"target":{"id":"0043","sets":3,"reps":5,"weight":105,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":155,"r":10,"done":true,"at":1792789770000},{"w":155,"r":10,"done":true,"at":1792789920000},{"w":155,"r":10,"done":true,"at":1792790070000}],"topW":155,"target":{"id":"0739","sets":3,"reps":10,"weight":155,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":72.5,"r":8,"done":true,"at":1792790220000},{"w":72.5,"r":8,"done":true,"at":1792790370000},{"w":72.5,"r":8,"done":true,"at":1792790520000}],"topW":72.5,"target":{"id":"0085","sets":3,"reps":8,"weight":75,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7965},
        {"id":"w-2026-10-26-push","d":"2026-10-26","start":1793050200000,"end":1793052270000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.5,"entries":[{"id":"0025","sets":[{"w":65,"r":8,"done":true,"at":1793050320000},{"w":65,"r":8,"done":true,"at":1793050470000},{"w":65,"r":8,"done":true,"at":1793050620000}],"topW":65,"target":{"id":"0025","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":14,"r":10,"done":true,"at":1793050770000},{"w":14,"r":10,"done":true,"at":1793051070000}],"topW":14,"target":{"id":"0294","sets":2,"reps":10,"weight":15.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":45,"r":10,"done":true,"at":1793050920000},{"w":45,"r":10,"done":true,"at":1793051220000}],"topW":45,"target":{"id":"0047","sets":2,"reps":10,"weight":45,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":45,"r":8,"done":true,"at":1793051370000},{"w":45,"r":8,"done":true,"at":1793051520000},{"w":45,"r":8,"done":true,"at":1793051670000}],"topW":45,"target":{"id":"1162","sets":3,"reps":8,"weight":45,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":27,"r":12,"done":true,"at":1793051820000},{"w":27,"r":12,"done":true,"at":1793051970000},{"w":27,"r":12,"done":true,"at":1793052120000}],"topW":27,"target":{"id":"0201","sets":3,"reps":12,"weight":28.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4792},
        {"id":"w-2026-10-28-pull","d":"2026-10-28","start":1793223000000,"end":1793224470000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.5,"entries":[{"id":"0027","sets":[{"w":65,"r":8,"done":true,"at":1793223120000},{"w":65,"r":8,"done":true,"at":1793223270000},{"w":65,"r":8,"done":true,"at":1793223420000}],"topW":65,"target":{"id":"0027","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":55,"r":10,"done":true,"at":1793223570000},{"w":55,"r":10,"done":true,"at":1793223720000},{"w":55,"r":10,"done":true,"at":1793223870000}],"topW":55,"target":{"id":"0150","sets":3,"reps":10,"weight":57.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":110,"r":5,"done":true,"at":1793224020000},{"w":110,"r":5,"done":true,"at":1793224170000},{"w":110,"r":5,"done":true,"at":1793224320000}],"topW":110,"target":{"id":"0032","sets":3,"reps":5,"weight":107.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4860},
        {"id":"w-2026-10-30-legs","d":"2026-10-30","start":1793394000000,"end":1793395470000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.5,"entries":[{"id":"0043","sets":[{"w":110,"r":5,"done":true,"at":1793394120000},{"w":110,"r":5,"done":true,"at":1793394270000},{"w":110,"r":5,"done":true,"at":1793394420000}],"topW":110,"target":{"id":"0043","sets":3,"reps":5,"weight":110,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":160,"r":10,"done":true,"at":1793394570000},{"w":160,"r":10,"done":true,"at":1793394720000},{"w":160,"r":10,"done":true,"at":1793394870000}],"topW":160,"target":{"id":"0739","sets":3,"reps":10,"weight":160,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":75,"r":8,"done":true,"at":1793395020000},{"w":75,"r":8,"done":true,"at":1793395170000},{"w":75,"r":8,"done":true,"at":1793395320000}],"topW":75,"target":{"id":"0085","sets":3,"reps":8,"weight":77.5,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8250},
        {"id":"w-2026-11-02-push","d":"2026-11-02","start":1793655000000,"end":1793657070000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.2,"entries":[{"id":"0025","sets":[{"w":67.5,"r":8,"done":true,"at":1793655120000},{"w":67.5,"r":8,"done":true,"at":1793655270000},{"w":67.5,"r":8,"done":true,"at":1793655420000}],"topW":67.5,"target":{"id":"0025","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":15,"r":10,"done":true,"at":1793655570000},{"w":15,"r":10,"done":true,"at":1793655870000}],"topW":15,"target":{"id":"0294","sets":2,"reps":10,"weight":16.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":47.5,"r":10,"done":true,"at":1793655720000},{"w":47.5,"r":10,"done":true,"at":1793656020000}],"topW":47.5,"target":{"id":"0047","sets":2,"reps":10,"weight":47.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":47.5,"r":8,"done":true,"at":1793656170000},{"w":47.5,"r":8,"done":true,"at":1793656320000},{"w":47.5,"r":8,"done":true,"at":1793656470000}],"topW":47.5,"target":{"id":"1162","sets":3,"reps":8,"weight":47.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":28,"r":12,"done":true,"at":1793656620000},{"w":28,"r":12,"done":true,"at":1793656770000},{"w":28,"r":12,"done":true,"at":1793656920000}],"topW":28,"target":{"id":"0201","sets":3,"reps":12,"weight":29.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":5018},
        {"id":"w-2026-11-04-pull","d":"2026-11-04","start":1793827800000,"end":1793829270000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.2,"entries":[{"id":"0027","sets":[{"w":67.5,"r":8,"done":true,"at":1793827920000},{"w":67.5,"r":8,"done":true,"at":1793828070000},{"w":67.5,"r":8,"done":true,"at":1793828220000}],"topW":67.5,"target":{"id":"0027","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":57.5,"r":10,"done":true,"at":1793828370000},{"w":57.5,"r":10,"done":true,"at":1793828520000},{"w":57.5,"r":10,"done":true,"at":1793828670000}],"topW":57.5,"target":{"id":"0150","sets":3,"reps":10,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":115,"r":5,"done":true,"at":1793828820000},{"w":115,"r":5,"done":true,"at":1793828970000},{"w":115,"r":5,"done":true,"at":1793829120000}],"topW":115,"target":{"id":"0032","sets":3,"reps":5,"weight":112.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":5070},
        {"id":"w-2026-11-06-legs","d":"2026-11-06","start":1793998800000,"end":1794000270000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.2,"entries":[{"id":"0043","sets":[{"w":115,"r":5,"done":true,"at":1793998920000},{"w":115,"r":5,"done":true,"at":1793999070000},{"w":115,"r":5,"done":true,"at":1793999220000}],"topW":115,"target":{"id":"0043","sets":3,"reps":5,"weight":115,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":165,"r":10,"done":true,"at":1793999370000},{"w":165,"r":10,"done":true,"at":1793999520000},{"w":165,"r":10,"done":true,"at":1793999670000}],"topW":165,"target":{"id":"0739","sets":3,"reps":10,"weight":165,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":77.5,"r":8,"done":true,"at":1793999820000},{"w":77.5,"r":8,"done":true,"at":1793999970000},{"w":77.5,"r":8,"done":true,"at":1794000120000}],"topW":77.5,"target":{"id":"0085","sets":3,"reps":8,"weight":80,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8535}
      ],
      "active": null,
      "customEx": [],
      "gifSize": "mini",
      "heatmapMetric": "time",
      "volumeWarmups": false,
      "workoutView": "cards",
      "collapseCompleted": false,
      "exerciseView": "list",
      "wc": {"steppers":true,"setShortcuts":false,"pairButtons":false,"exerciseButtons":false,"exerciseChips":true,"muscleMap":true,"swipeSets":true},
      "hints": {},
      "reminder": {"on":false,"time":"08:00","tz":null,"nudge":false,"tone":"friendly"},
      "effort": null,
      "autoBackup": false,
      "equipProfiles": [],
      "activeEquipId": null,
      "equipFilterOn": false,
      "exNotes": {},
      "exAliases": {},
      "favEx": [],
      "weekStart": 1,
      "wdec": 1,
      "speedUnit": null,
      "barWeights": {},
      "plates": {},
      "loadKind": {},
      "dbLoad": {},
      "dumbbells": {},
      "stackWeights": {},
      "gymCards": [],
      "lastGymCardId": null,
      "checkIn": true,
      "showWeightCard": true,
      "weighIn": false,
      "connStatus": true,
      "shareMap": true,
      "connLocal": true,
      "startFrom": "plan",
      "lastFrom": "routine",
      "enParens": {},
      "enOnly": {},
      "logRef": "last",
      "balanceTemplate": "poliquin",
      "balanceOverrides": {},
      "langAuto": true,
      "_ts": 1794000270000
    }
    """#

  static let descanso = #"""
    {
      "_fixtureNow": 1794225135000,
      "unit": "kg",
      "restSec": 90,
      "restPauseSec": 15,
      "sound": true,
      "soundOnSilent": false,
      "vibrateOnSilent": false,
      "timerFlash": false,
      "timedSetOvertime": false,
      "keepAwake": true,
      "theme": "dark",
      "accent": "lime",
      "body": "male",
      "targetW": null,
      "rateGoal": null,
      "bodyweight": [
        {"d":"2026-10-12","w":82.1},
        {"d":"2026-10-19","w":81.8},
        {"d":"2026-10-26","w":81.5},
        {"d":"2026-11-02","w":81.2},
        {"d":"2026-11-09","w":80.9}
      ],
      "routines": [
        {"id":"r-push","name":"Push","emoji":"barbell","ex":[{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"}]},
        {"id":"r-pull","name":"Pull","emoji":"pullup","ex":[{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"}]},
        {"id":"r-legs","name":"Legs","emoji":"figureStrength","ex":[{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"}]}
      ],
      "week": {"1":["r-push"],"3":["r-pull"],"5":["r-legs"]},
      "dayPlan": {"2026-11-09":"r-push"},
      "dayNotes": {},
      "measurements": [],
      "measurementEnabled": null,
      "customMeasurements": [],
      "queue": null,
      "rotation": null,
      "scheduleMode": null,
      "exWeights": {"1162":{"w":47.5,"d":"2026-11-02"},"0025":{"w":67.5,"d":"2026-11-02"},"0294":{"w":15,"d":"2026-11-02"},"0047":{"w":47.5,"d":"2026-11-02"},"0201":{"w":28,"d":"2026-11-02"},"0027":{"w":67.5,"d":"2026-11-04"},"0150":{"w":57.5,"d":"2026-11-04"},"0032":{"w":115,"d":"2026-11-04"},"0043":{"w":115,"d":"2026-11-06"},"0739":{"w":165,"d":"2026-11-06"},"0085":{"w":77.5,"d":"2026-11-06"}},
      "workouts": [
        {"d":"2026-10-12","start":1791840600000,"end":1791842670000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":82.1,"entries":[{"id":"0025","sets":[{"w":60,"r":8,"done":true,"at":1791840720000},{"w":60,"r":8,"done":true,"at":1791840870000},{"w":60,"r":8,"done":true,"at":1791841020000}],"topW":60,"target":{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":12,"r":10,"done":true,"at":1791841170000},{"w":12,"r":10,"done":true,"at":1791841470000}],"topW":12,"target":{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":40,"r":10,"done":true,"at":1791841320000},{"w":40,"r":10,"done":true,"at":1791841620000}],"topW":40,"target":{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":40,"r":8,"done":true,"at":1791841770000},{"w":40,"r":8,"done":true,"at":1791841920000},{"w":40,"r":8,"done":true,"at":1791842070000}],"topW":40,"target":{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":25,"r":12,"done":true,"at":1791842220000},{"w":25,"r":12,"done":true,"at":1791842370000},{"w":25,"r":12,"done":true,"at":1791842520000}],"topW":25,"target":{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4340},
        {"id":"w-2026-10-14-pull","d":"2026-10-14","start":1792013400000,"end":1792014870000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":82.1,"entries":[{"id":"0027","sets":[{"w":60,"r":8,"done":true,"at":1792013520000},{"w":60,"r":8,"done":true,"at":1792013670000},{"w":60,"r":8,"done":true,"at":1792013820000}],"topW":60,"target":{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":50,"r":10,"done":true,"at":1792013970000},{"w":50,"r":10,"done":true,"at":1792014120000},{"w":50,"r":10,"done":true,"at":1792014270000}],"topW":50,"target":{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":100,"r":5,"done":true,"at":1792014420000},{"w":100,"r":5,"done":true,"at":1792014570000},{"w":100,"r":5,"done":true,"at":1792014720000}],"topW":100,"target":{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4440},
        {"id":"w-2026-10-16-legs","d":"2026-10-16","start":1792184400000,"end":1792185870000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":82.1,"entries":[{"id":"0043","sets":[{"w":100,"r":5,"done":true,"at":1792184520000},{"w":100,"r":5,"done":true,"at":1792184670000},{"w":100,"r":5,"done":true,"at":1792184820000}],"topW":100,"target":{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":150,"r":10,"done":true,"at":1792184970000},{"w":150,"r":10,"done":true,"at":1792185120000},{"w":150,"r":10,"done":true,"at":1792185270000}],"topW":150,"target":{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":70,"r":8,"done":true,"at":1792185420000},{"w":70,"r":8,"done":true,"at":1792185570000},{"w":70,"r":8,"done":true,"at":1792185720000}],"topW":70,"target":{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7680},
        {"id":"w-2026-10-19-push","d":"2026-10-19","start":1792445400000,"end":1792447470000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.8,"entries":[{"id":"0025","sets":[{"w":62.5,"r":8,"done":true,"at":1792445520000},{"w":62.5,"r":8,"done":true,"at":1792445670000},{"w":62.5,"r":8,"done":true,"at":1792445820000}],"topW":62.5,"target":{"id":"0025","sets":3,"reps":8,"weight":62.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":13,"r":10,"done":true,"at":1792445970000},{"w":13,"r":10,"done":true,"at":1792446270000}],"topW":13,"target":{"id":"0294","sets":2,"reps":10,"weight":14.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":42.5,"r":10,"done":true,"at":1792446120000},{"w":42.5,"r":10,"done":true,"at":1792446420000}],"topW":42.5,"target":{"id":"0047","sets":2,"reps":10,"weight":42.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":42.5,"r":8,"done":true,"at":1792446570000},{"w":42.5,"r":8,"done":true,"at":1792446720000},{"w":42.5,"r":8,"done":true,"at":1792446870000}],"topW":42.5,"target":{"id":"1162","sets":3,"reps":8,"weight":42.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":26,"r":12,"done":true,"at":1792447020000},{"w":26,"r":12,"done":true,"at":1792447170000},{"w":26,"r":12,"done":true,"at":1792447320000}],"topW":26,"target":{"id":"0201","sets":3,"reps":12,"weight":27.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4566},
        {"id":"w-2026-10-21-pull","d":"2026-10-21","start":1792618200000,"end":1792619670000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.8,"entries":[{"id":"0027","sets":[{"w":62.5,"r":8,"done":true,"at":1792618320000},{"w":62.5,"r":8,"done":true,"at":1792618470000},{"w":62.5,"r":8,"done":true,"at":1792618620000}],"topW":62.5,"target":{"id":"0027","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":52.5,"r":10,"done":true,"at":1792618770000},{"w":52.5,"r":10,"done":true,"at":1792618920000},{"w":52.5,"r":10,"done":true,"at":1792619070000}],"topW":52.5,"target":{"id":"0150","sets":3,"reps":10,"weight":55,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":105,"r":5,"done":true,"at":1792619220000},{"w":105,"r":5,"done":true,"at":1792619370000},{"w":105,"r":5,"done":true,"at":1792619520000}],"topW":105,"target":{"id":"0032","sets":3,"reps":5,"weight":102.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4650},
        {"id":"w-2026-10-23-legs","d":"2026-10-23","start":1792789200000,"end":1792790670000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.8,"entries":[{"id":"0043","sets":[{"w":105,"r":5,"done":true,"at":1792789320000},{"w":105,"r":5,"done":true,"at":1792789470000},{"w":105,"r":5,"done":true,"at":1792789620000}],"topW":105,"target":{"id":"0043","sets":3,"reps":5,"weight":105,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":155,"r":10,"done":true,"at":1792789770000},{"w":155,"r":10,"done":true,"at":1792789920000},{"w":155,"r":10,"done":true,"at":1792790070000}],"topW":155,"target":{"id":"0739","sets":3,"reps":10,"weight":155,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":72.5,"r":8,"done":true,"at":1792790220000},{"w":72.5,"r":8,"done":true,"at":1792790370000},{"w":72.5,"r":8,"done":true,"at":1792790520000}],"topW":72.5,"target":{"id":"0085","sets":3,"reps":8,"weight":75,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7965},
        {"id":"w-2026-10-26-push","d":"2026-10-26","start":1793050200000,"end":1793052270000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.5,"entries":[{"id":"0025","sets":[{"w":65,"r":8,"done":true,"at":1793050320000},{"w":65,"r":8,"done":true,"at":1793050470000},{"w":65,"r":8,"done":true,"at":1793050620000}],"topW":65,"target":{"id":"0025","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":14,"r":10,"done":true,"at":1793050770000},{"w":14,"r":10,"done":true,"at":1793051070000}],"topW":14,"target":{"id":"0294","sets":2,"reps":10,"weight":15.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":45,"r":10,"done":true,"at":1793050920000},{"w":45,"r":10,"done":true,"at":1793051220000}],"topW":45,"target":{"id":"0047","sets":2,"reps":10,"weight":45,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":45,"r":8,"done":true,"at":1793051370000},{"w":45,"r":8,"done":true,"at":1793051520000},{"w":45,"r":8,"done":true,"at":1793051670000}],"topW":45,"target":{"id":"1162","sets":3,"reps":8,"weight":45,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":27,"r":12,"done":true,"at":1793051820000},{"w":27,"r":12,"done":true,"at":1793051970000},{"w":27,"r":12,"done":true,"at":1793052120000}],"topW":27,"target":{"id":"0201","sets":3,"reps":12,"weight":28.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4792},
        {"id":"w-2026-10-28-pull","d":"2026-10-28","start":1793223000000,"end":1793224470000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.5,"entries":[{"id":"0027","sets":[{"w":65,"r":8,"done":true,"at":1793223120000},{"w":65,"r":8,"done":true,"at":1793223270000},{"w":65,"r":8,"done":true,"at":1793223420000}],"topW":65,"target":{"id":"0027","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":55,"r":10,"done":true,"at":1793223570000},{"w":55,"r":10,"done":true,"at":1793223720000},{"w":55,"r":10,"done":true,"at":1793223870000}],"topW":55,"target":{"id":"0150","sets":3,"reps":10,"weight":57.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":110,"r":5,"done":true,"at":1793224020000},{"w":110,"r":5,"done":true,"at":1793224170000},{"w":110,"r":5,"done":true,"at":1793224320000}],"topW":110,"target":{"id":"0032","sets":3,"reps":5,"weight":107.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4860},
        {"id":"w-2026-10-30-legs","d":"2026-10-30","start":1793394000000,"end":1793395470000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.5,"entries":[{"id":"0043","sets":[{"w":110,"r":5,"done":true,"at":1793394120000},{"w":110,"r":5,"done":true,"at":1793394270000},{"w":110,"r":5,"done":true,"at":1793394420000}],"topW":110,"target":{"id":"0043","sets":3,"reps":5,"weight":110,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":160,"r":10,"done":true,"at":1793394570000},{"w":160,"r":10,"done":true,"at":1793394720000},{"w":160,"r":10,"done":true,"at":1793394870000}],"topW":160,"target":{"id":"0739","sets":3,"reps":10,"weight":160,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":75,"r":8,"done":true,"at":1793395020000},{"w":75,"r":8,"done":true,"at":1793395170000},{"w":75,"r":8,"done":true,"at":1793395320000}],"topW":75,"target":{"id":"0085","sets":3,"reps":8,"weight":77.5,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8250},
        {"id":"w-2026-11-02-push","d":"2026-11-02","start":1793655000000,"end":1793657070000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.2,"entries":[{"id":"0025","sets":[{"w":67.5,"r":8,"done":true,"at":1793655120000},{"w":67.5,"r":8,"done":true,"at":1793655270000},{"w":67.5,"r":8,"done":true,"at":1793655420000}],"topW":67.5,"target":{"id":"0025","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":15,"r":10,"done":true,"at":1793655570000},{"w":15,"r":10,"done":true,"at":1793655870000}],"topW":15,"target":{"id":"0294","sets":2,"reps":10,"weight":16.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":47.5,"r":10,"done":true,"at":1793655720000},{"w":47.5,"r":10,"done":true,"at":1793656020000}],"topW":47.5,"target":{"id":"0047","sets":2,"reps":10,"weight":47.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":47.5,"r":8,"done":true,"at":1793656170000},{"w":47.5,"r":8,"done":true,"at":1793656320000},{"w":47.5,"r":8,"done":true,"at":1793656470000}],"topW":47.5,"target":{"id":"1162","sets":3,"reps":8,"weight":47.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":28,"r":12,"done":true,"at":1793656620000},{"w":28,"r":12,"done":true,"at":1793656770000},{"w":28,"r":12,"done":true,"at":1793656920000}],"topW":28,"target":{"id":"0201","sets":3,"reps":12,"weight":29.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":5018},
        {"id":"w-2026-11-04-pull","d":"2026-11-04","start":1793827800000,"end":1793829270000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.2,"entries":[{"id":"0027","sets":[{"w":67.5,"r":8,"done":true,"at":1793827920000},{"w":67.5,"r":8,"done":true,"at":1793828070000},{"w":67.5,"r":8,"done":true,"at":1793828220000}],"topW":67.5,"target":{"id":"0027","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":57.5,"r":10,"done":true,"at":1793828370000},{"w":57.5,"r":10,"done":true,"at":1793828520000},{"w":57.5,"r":10,"done":true,"at":1793828670000}],"topW":57.5,"target":{"id":"0150","sets":3,"reps":10,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":115,"r":5,"done":true,"at":1793828820000},{"w":115,"r":5,"done":true,"at":1793828970000},{"w":115,"r":5,"done":true,"at":1793829120000}],"topW":115,"target":{"id":"0032","sets":3,"reps":5,"weight":112.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":5070},
        {"id":"w-2026-11-06-legs","d":"2026-11-06","start":1793998800000,"end":1794000270000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.2,"entries":[{"id":"0043","sets":[{"w":115,"r":5,"done":true,"at":1793998920000},{"w":115,"r":5,"done":true,"at":1793999070000},{"w":115,"r":5,"done":true,"at":1793999220000}],"topW":115,"target":{"id":"0043","sets":3,"reps":5,"weight":115,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":165,"r":10,"done":true,"at":1793999370000},{"w":165,"r":10,"done":true,"at":1793999520000},{"w":165,"r":10,"done":true,"at":1793999670000}],"topW":165,"target":{"id":"0739","sets":3,"reps":10,"weight":165,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":77.5,"r":8,"done":true,"at":1793999820000},{"w":77.5,"r":8,"done":true,"at":1793999970000},{"w":77.5,"r":8,"done":true,"at":1794000120000}],"topW":77.5,"target":{"id":"0085","sets":3,"reps":8,"weight":80,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8535}
      ],
      "active": {
        "id": "w-2026-11-09-push",
        "d": "2026-11-09",
        "start": 1794224040000,
        "routineIds": ["r-push"],
        "name": "Push",
        "bw": 80.9,
        "cur": 1,
        "entries": [
          {"id":"0025","target":{"id":"0025","sets":3,"reps":8,"weight":70,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":70,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224160000},{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224400000},{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224640000}],"planned":{"sets":3,"reps":8,"weight":60},"rid":"r-push","topW":70},
          {"id":"0294","sg":"g1","target":{"id":"0294","sets":2,"reps":10,"weight":17.5,"mode":"reps","sg":"g1"},"plan":{"policy":"linear","kind":"up","weight":17.5,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":16,"r":10,"done":true,"weightOrigin":"manual","at":1794224880000},{"w":16,"r":10,"done":false,"weightOrigin":"manual"}],"planned":{"sets":2,"reps":10,"weight":12},"rid":"r-push"},
          {"id":"0047","sg":"g1","target":{"id":"0047","sets":2,"reps":10,"weight":50,"mode":"reps","sg":"g1"},"plan":{"policy":"linear","kind":"up","weight":50,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":50,"r":10,"done":true,"weightOrigin":"manual","at":1794225120000},{"w":50,"r":10,"done":false,"weightOrigin":"manual"}],"planned":{"sets":2,"reps":10,"weight":40},"rid":"r-push"},
          {"id":"1162","target":{"id":"1162","sets":3,"reps":8,"weight":50,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":50,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":50,"r":8,"done":false,"weightOrigin":"manual"},{"w":50,"r":8,"done":false,"weightOrigin":"manual"},{"w":50,"r":8,"done":false,"weightOrigin":"manual"}],"planned":{"sets":3,"reps":8,"weight":40},"rid":"r-push"},
          {"id":"0201","target":{"id":"0201","sets":3,"reps":12,"weight":30.5,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":30.5,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"},{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"},{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"}],"planned":{"sets":3,"reps":12,"weight":25},"rid":"r-push"}
        ],
        "workoutView": "cards",
        "rest": {"endsAt":1794225210000,"total":90,"forIdx":2,"forSet":0,"kind":"rest"},
        "progress": [3,1,1,0,0]
      },
      "customEx": [],
      "gifSize": "mini",
      "heatmapMetric": "time",
      "volumeWarmups": false,
      "workoutView": "cards",
      "collapseCompleted": false,
      "exerciseView": "list",
      "wc": {"steppers":true,"setShortcuts":false,"pairButtons":false,"exerciseButtons":false,"exerciseChips":true,"muscleMap":true,"swipeSets":true},
      "hints": {},
      "reminder": {"on":false,"time":"08:00","tz":null,"nudge":false,"tone":"friendly"},
      "effort": null,
      "autoBackup": false,
      "equipProfiles": [],
      "activeEquipId": null,
      "equipFilterOn": false,
      "exNotes": {},
      "exAliases": {},
      "favEx": [],
      "weekStart": 1,
      "wdec": 1,
      "speedUnit": null,
      "barWeights": {},
      "plates": {},
      "loadKind": {},
      "dbLoad": {},
      "dumbbells": {},
      "stackWeights": {},
      "gymCards": [],
      "lastGymCardId": null,
      "checkIn": true,
      "showWeightCard": true,
      "weighIn": false,
      "connStatus": true,
      "shareMap": true,
      "connLocal": true,
      "startFrom": "plan",
      "lastFrom": "routine",
      "enParens": {},
      "enOnly": {},
      "logRef": "last",
      "balanceTemplate": "poliquin",
      "balanceOverrides": {},
      "langAuto": true,
      "_ts": 1794225120000
    }
    """#

  static let treinoEmAndamento = #"""
    {
      "_fixtureNow": 1794225600000,
      "unit": "kg",
      "restSec": 90,
      "restPauseSec": 15,
      "sound": true,
      "soundOnSilent": false,
      "vibrateOnSilent": false,
      "timerFlash": false,
      "timedSetOvertime": false,
      "keepAwake": true,
      "theme": "dark",
      "accent": "lime",
      "body": "male",
      "targetW": null,
      "rateGoal": null,
      "bodyweight": [
        {"d":"2026-10-12","w":82.1},
        {"d":"2026-10-19","w":81.8},
        {"d":"2026-10-26","w":81.5},
        {"d":"2026-11-02","w":81.2},
        {"d":"2026-11-09","w":80.9}
      ],
      "routines": [
        {"id":"r-push","name":"Push","emoji":"barbell","ex":[{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"}]},
        {"id":"r-pull","name":"Pull","emoji":"pullup","ex":[{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"}]},
        {"id":"r-legs","name":"Legs","emoji":"figureStrength","ex":[{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"}]}
      ],
      "week": {"1":["r-push"],"3":["r-pull"],"5":["r-legs"]},
      "dayPlan": {"2026-11-09":"r-push"},
      "dayNotes": {},
      "measurements": [],
      "measurementEnabled": null,
      "customMeasurements": [],
      "queue": null,
      "rotation": null,
      "scheduleMode": null,
      "exWeights": {"1162":{"w":47.5,"d":"2026-11-02"},"0025":{"w":67.5,"d":"2026-11-02"},"0294":{"w":15,"d":"2026-11-02"},"0047":{"w":47.5,"d":"2026-11-02"},"0201":{"w":28,"d":"2026-11-02"},"0027":{"w":67.5,"d":"2026-11-04"},"0150":{"w":57.5,"d":"2026-11-04"},"0032":{"w":115,"d":"2026-11-04"},"0043":{"w":115,"d":"2026-11-06"},"0739":{"w":165,"d":"2026-11-06"},"0085":{"w":77.5,"d":"2026-11-06"}},
      "workouts": [
        {"d":"2026-10-12","start":1791840600000,"end":1791842670000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":82.1,"entries":[{"id":"0025","sets":[{"w":60,"r":8,"done":true,"at":1791840720000},{"w":60,"r":8,"done":true,"at":1791840870000},{"w":60,"r":8,"done":true,"at":1791841020000}],"topW":60,"target":{"id":"0025","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":12,"r":10,"done":true,"at":1791841170000},{"w":12,"r":10,"done":true,"at":1791841470000}],"topW":12,"target":{"id":"0294","sets":2,"reps":10,"weight":12,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":40,"r":10,"done":true,"at":1791841320000},{"w":40,"r":10,"done":true,"at":1791841620000}],"topW":40,"target":{"id":"0047","sets":2,"reps":10,"weight":40,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":40,"r":8,"done":true,"at":1791841770000},{"w":40,"r":8,"done":true,"at":1791841920000},{"w":40,"r":8,"done":true,"at":1791842070000}],"topW":40,"target":{"id":"1162","sets":3,"reps":8,"weight":40,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":25,"r":12,"done":true,"at":1791842220000},{"w":25,"r":12,"done":true,"at":1791842370000},{"w":25,"r":12,"done":true,"at":1791842520000}],"topW":25,"target":{"id":"0201","sets":3,"reps":12,"weight":25,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4340},
        {"id":"w-2026-10-14-pull","d":"2026-10-14","start":1792013400000,"end":1792014870000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":82.1,"entries":[{"id":"0027","sets":[{"w":60,"r":8,"done":true,"at":1792013520000},{"w":60,"r":8,"done":true,"at":1792013670000},{"w":60,"r":8,"done":true,"at":1792013820000}],"topW":60,"target":{"id":"0027","sets":3,"reps":8,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":50,"r":10,"done":true,"at":1792013970000},{"w":50,"r":10,"done":true,"at":1792014120000},{"w":50,"r":10,"done":true,"at":1792014270000}],"topW":50,"target":{"id":"0150","sets":3,"reps":10,"weight":50,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":100,"r":5,"done":true,"at":1792014420000},{"w":100,"r":5,"done":true,"at":1792014570000},{"w":100,"r":5,"done":true,"at":1792014720000}],"topW":100,"target":{"id":"0032","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4440},
        {"id":"w-2026-10-16-legs","d":"2026-10-16","start":1792184400000,"end":1792185870000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":82.1,"entries":[{"id":"0043","sets":[{"w":100,"r":5,"done":true,"at":1792184520000},{"w":100,"r":5,"done":true,"at":1792184670000},{"w":100,"r":5,"done":true,"at":1792184820000}],"topW":100,"target":{"id":"0043","sets":3,"reps":5,"weight":100,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":150,"r":10,"done":true,"at":1792184970000},{"w":150,"r":10,"done":true,"at":1792185120000},{"w":150,"r":10,"done":true,"at":1792185270000}],"topW":150,"target":{"id":"0739","sets":3,"reps":10,"weight":150,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":70,"r":8,"done":true,"at":1792185420000},{"w":70,"r":8,"done":true,"at":1792185570000},{"w":70,"r":8,"done":true,"at":1792185720000}],"topW":70,"target":{"id":"0085","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7680},
        {"id":"w-2026-10-19-push","d":"2026-10-19","start":1792445400000,"end":1792447470000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.8,"entries":[{"id":"0025","sets":[{"w":62.5,"r":8,"done":true,"at":1792445520000},{"w":62.5,"r":8,"done":true,"at":1792445670000},{"w":62.5,"r":8,"done":true,"at":1792445820000}],"topW":62.5,"target":{"id":"0025","sets":3,"reps":8,"weight":62.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":13,"r":10,"done":true,"at":1792445970000},{"w":13,"r":10,"done":true,"at":1792446270000}],"topW":13,"target":{"id":"0294","sets":2,"reps":10,"weight":14.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":42.5,"r":10,"done":true,"at":1792446120000},{"w":42.5,"r":10,"done":true,"at":1792446420000}],"topW":42.5,"target":{"id":"0047","sets":2,"reps":10,"weight":42.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":42.5,"r":8,"done":true,"at":1792446570000},{"w":42.5,"r":8,"done":true,"at":1792446720000},{"w":42.5,"r":8,"done":true,"at":1792446870000}],"topW":42.5,"target":{"id":"1162","sets":3,"reps":8,"weight":42.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":26,"r":12,"done":true,"at":1792447020000},{"w":26,"r":12,"done":true,"at":1792447170000},{"w":26,"r":12,"done":true,"at":1792447320000}],"topW":26,"target":{"id":"0201","sets":3,"reps":12,"weight":27.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4566},
        {"id":"w-2026-10-21-pull","d":"2026-10-21","start":1792618200000,"end":1792619670000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.8,"entries":[{"id":"0027","sets":[{"w":62.5,"r":8,"done":true,"at":1792618320000},{"w":62.5,"r":8,"done":true,"at":1792618470000},{"w":62.5,"r":8,"done":true,"at":1792618620000}],"topW":62.5,"target":{"id":"0027","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":52.5,"r":10,"done":true,"at":1792618770000},{"w":52.5,"r":10,"done":true,"at":1792618920000},{"w":52.5,"r":10,"done":true,"at":1792619070000}],"topW":52.5,"target":{"id":"0150","sets":3,"reps":10,"weight":55,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":105,"r":5,"done":true,"at":1792619220000},{"w":105,"r":5,"done":true,"at":1792619370000},{"w":105,"r":5,"done":true,"at":1792619520000}],"topW":105,"target":{"id":"0032","sets":3,"reps":5,"weight":102.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4650},
        {"id":"w-2026-10-23-legs","d":"2026-10-23","start":1792789200000,"end":1792790670000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.8,"entries":[{"id":"0043","sets":[{"w":105,"r":5,"done":true,"at":1792789320000},{"w":105,"r":5,"done":true,"at":1792789470000},{"w":105,"r":5,"done":true,"at":1792789620000}],"topW":105,"target":{"id":"0043","sets":3,"reps":5,"weight":105,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":155,"r":10,"done":true,"at":1792789770000},{"w":155,"r":10,"done":true,"at":1792789920000},{"w":155,"r":10,"done":true,"at":1792790070000}],"topW":155,"target":{"id":"0739","sets":3,"reps":10,"weight":155,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":72.5,"r":8,"done":true,"at":1792790220000},{"w":72.5,"r":8,"done":true,"at":1792790370000},{"w":72.5,"r":8,"done":true,"at":1792790520000}],"topW":72.5,"target":{"id":"0085","sets":3,"reps":8,"weight":75,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":7965},
        {"id":"w-2026-10-26-push","d":"2026-10-26","start":1793050200000,"end":1793052270000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.5,"entries":[{"id":"0025","sets":[{"w":65,"r":8,"done":true,"at":1793050320000},{"w":65,"r":8,"done":true,"at":1793050470000},{"w":65,"r":8,"done":true,"at":1793050620000}],"topW":65,"target":{"id":"0025","sets":3,"reps":8,"weight":65,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":14,"r":10,"done":true,"at":1793050770000},{"w":14,"r":10,"done":true,"at":1793051070000}],"topW":14,"target":{"id":"0294","sets":2,"reps":10,"weight":15.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":45,"r":10,"done":true,"at":1793050920000},{"w":45,"r":10,"done":true,"at":1793051220000}],"topW":45,"target":{"id":"0047","sets":2,"reps":10,"weight":45,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":45,"r":8,"done":true,"at":1793051370000},{"w":45,"r":8,"done":true,"at":1793051520000},{"w":45,"r":8,"done":true,"at":1793051670000}],"topW":45,"target":{"id":"1162","sets":3,"reps":8,"weight":45,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":27,"r":12,"done":true,"at":1793051820000},{"w":27,"r":12,"done":true,"at":1793051970000},{"w":27,"r":12,"done":true,"at":1793052120000}],"topW":27,"target":{"id":"0201","sets":3,"reps":12,"weight":28.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":4792},
        {"id":"w-2026-10-28-pull","d":"2026-10-28","start":1793223000000,"end":1793224470000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.5,"entries":[{"id":"0027","sets":[{"w":65,"r":8,"done":true,"at":1793223120000},{"w":65,"r":8,"done":true,"at":1793223270000},{"w":65,"r":8,"done":true,"at":1793223420000}],"topW":65,"target":{"id":"0027","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":55,"r":10,"done":true,"at":1793223570000},{"w":55,"r":10,"done":true,"at":1793223720000},{"w":55,"r":10,"done":true,"at":1793223870000}],"topW":55,"target":{"id":"0150","sets":3,"reps":10,"weight":57.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":110,"r":5,"done":true,"at":1793224020000},{"w":110,"r":5,"done":true,"at":1793224170000},{"w":110,"r":5,"done":true,"at":1793224320000}],"topW":110,"target":{"id":"0032","sets":3,"reps":5,"weight":107.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":4860},
        {"id":"w-2026-10-30-legs","d":"2026-10-30","start":1793394000000,"end":1793395470000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.5,"entries":[{"id":"0043","sets":[{"w":110,"r":5,"done":true,"at":1793394120000},{"w":110,"r":5,"done":true,"at":1793394270000},{"w":110,"r":5,"done":true,"at":1793394420000}],"topW":110,"target":{"id":"0043","sets":3,"reps":5,"weight":110,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":160,"r":10,"done":true,"at":1793394570000},{"w":160,"r":10,"done":true,"at":1793394720000},{"w":160,"r":10,"done":true,"at":1793394870000}],"topW":160,"target":{"id":"0739","sets":3,"reps":10,"weight":160,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":75,"r":8,"done":true,"at":1793395020000},{"w":75,"r":8,"done":true,"at":1793395170000},{"w":75,"r":8,"done":true,"at":1793395320000}],"topW":75,"target":{"id":"0085","sets":3,"reps":8,"weight":77.5,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8250},
        {"id":"w-2026-11-02-push","d":"2026-11-02","start":1793655000000,"end":1793657070000,"routineIds":["r-push"],"routineId":"r-push","name":"Push","bw":81.2,"entries":[{"id":"0025","sets":[{"w":67.5,"r":8,"done":true,"at":1793655120000},{"w":67.5,"r":8,"done":true,"at":1793655270000},{"w":67.5,"r":8,"done":true,"at":1793655420000}],"topW":67.5,"target":{"id":"0025","sets":3,"reps":8,"weight":67.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0294","sets":[{"w":15,"r":10,"done":true,"at":1793655570000},{"w":15,"r":10,"done":true,"at":1793655870000}],"topW":15,"target":{"id":"0294","sets":2,"reps":10,"weight":16.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":12},"sg":"g1"},{"id":"0047","sets":[{"w":47.5,"r":10,"done":true,"at":1793655720000},{"w":47.5,"r":10,"done":true,"at":1793656020000}],"topW":47.5,"target":{"id":"0047","sets":2,"reps":10,"weight":47.5,"mode":"reps","sg":"g1"},"rid":"r-push","planned":{"sets":2,"reps":10,"weight":40},"sg":"g1"},{"id":"1162","sets":[{"w":47.5,"r":8,"done":true,"at":1793656170000},{"w":47.5,"r":8,"done":true,"at":1793656320000},{"w":47.5,"r":8,"done":true,"at":1793656470000}],"topW":47.5,"target":{"id":"1162","sets":3,"reps":8,"weight":47.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":8,"weight":40}},{"id":"0201","sets":[{"w":28,"r":12,"done":true,"at":1793656620000},{"w":28,"r":12,"done":true,"at":1793656770000},{"w":28,"r":12,"done":true,"at":1793656920000}],"topW":28,"target":{"id":"0201","sets":3,"reps":12,"weight":29.5,"mode":"reps"},"rid":"r-push","planned":{"sets":3,"reps":12,"weight":25}}],"prs":["0025","0294","0047","1162","0201"],"vol":5018},
        {"id":"w-2026-11-04-pull","d":"2026-11-04","start":1793827800000,"end":1793829270000,"routineIds":["r-pull"],"routineId":"r-pull","name":"Pull","bw":81.2,"entries":[{"id":"0027","sets":[{"w":67.5,"r":8,"done":true,"at":1793827920000},{"w":67.5,"r":8,"done":true,"at":1793828070000},{"w":67.5,"r":8,"done":true,"at":1793828220000}],"topW":67.5,"target":{"id":"0027","sets":3,"reps":8,"weight":70,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":8,"weight":60}},{"id":"0150","sets":[{"w":57.5,"r":10,"done":true,"at":1793828370000},{"w":57.5,"r":10,"done":true,"at":1793828520000},{"w":57.5,"r":10,"done":true,"at":1793828670000}],"topW":57.5,"target":{"id":"0150","sets":3,"reps":10,"weight":60,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":10,"weight":50}},{"id":"0032","sets":[{"w":115,"r":5,"done":true,"at":1793828820000},{"w":115,"r":5,"done":true,"at":1793828970000},{"w":115,"r":5,"done":true,"at":1793829120000}],"topW":115,"target":{"id":"0032","sets":3,"reps":5,"weight":112.5,"mode":"reps"},"rid":"r-pull","planned":{"sets":3,"reps":5,"weight":100}}],"prs":["0027","0150","0032"],"vol":5070},
        {"id":"w-2026-11-06-legs","d":"2026-11-06","start":1793998800000,"end":1794000270000,"routineIds":["r-legs"],"routineId":"r-legs","name":"Legs","bw":81.2,"entries":[{"id":"0043","sets":[{"w":115,"r":5,"done":true,"at":1793998920000},{"w":115,"r":5,"done":true,"at":1793999070000},{"w":115,"r":5,"done":true,"at":1793999220000}],"topW":115,"target":{"id":"0043","sets":3,"reps":5,"weight":115,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":5,"weight":100}},{"id":"0739","sets":[{"w":165,"r":10,"done":true,"at":1793999370000},{"w":165,"r":10,"done":true,"at":1793999520000},{"w":165,"r":10,"done":true,"at":1793999670000}],"topW":165,"target":{"id":"0739","sets":3,"reps":10,"weight":165,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":10,"weight":150}},{"id":"0085","sets":[{"w":77.5,"r":8,"done":true,"at":1793999820000},{"w":77.5,"r":8,"done":true,"at":1793999970000},{"w":77.5,"r":8,"done":true,"at":1794000120000}],"topW":77.5,"target":{"id":"0085","sets":3,"reps":8,"weight":80,"mode":"reps"},"rid":"r-legs","planned":{"sets":3,"reps":8,"weight":70}}],"prs":["0043","0739","0085"],"vol":8535}
      ],
      "active": {
        "id": "w-2026-11-09-push",
        "d": "2026-11-09",
        "start": 1794224040000,
        "routineIds": ["r-push"],
        "name": "Push",
        "bw": 80.9,
        "cur": 1,
        "entries": [
          {"id":"0025","target":{"id":"0025","sets":3,"reps":8,"weight":70,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":70,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224160000},{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224400000},{"w":70,"r":8,"done":true,"weightOrigin":"manual","at":1794224640000}],"planned":{"sets":3,"reps":8,"weight":60},"rid":"r-push","topW":70},
          {"id":"0294","sg":"g1","target":{"id":"0294","sets":2,"reps":10,"weight":17.5,"mode":"reps","sg":"g1"},"plan":{"policy":"linear","kind":"up","weight":17.5,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":16,"r":10,"done":true,"weightOrigin":"manual","at":1794224880000},{"w":16,"r":10,"done":false,"weightOrigin":"manual"}],"planned":{"sets":2,"reps":10,"weight":12},"rid":"r-push"},
          {"id":"0047","sg":"g1","target":{"id":"0047","sets":2,"reps":10,"weight":50,"mode":"reps","sg":"g1"},"plan":{"policy":"linear","kind":"up","weight":50,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":50,"r":10,"done":true,"weightOrigin":"manual","at":1794225120000},{"w":50,"r":10,"done":false,"weightOrigin":"manual"}],"planned":{"sets":2,"reps":10,"weight":40},"rid":"r-push"},
          {"id":"1162","target":{"id":"1162","sets":3,"reps":8,"weight":50,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":50,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":50,"r":8,"done":false,"weightOrigin":"manual"},{"w":50,"r":8,"done":false,"weightOrigin":"manual"},{"w":50,"r":8,"done":false,"weightOrigin":"manual"}],"planned":{"sets":3,"reps":8,"weight":40},"rid":"r-push"},
          {"id":"0201","target":{"id":"0201","sets":3,"reps":12,"weight":30.5,"mode":"reps"},"plan":{"policy":"linear","kind":"up","weight":30.5,"why":["Every rep last time. {0} {1} more.",2.5,"kg"]},"sets":[{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"},{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"},{"w":32.5,"r":12,"done":false,"weightOrigin":"manual"}],"planned":{"sets":3,"reps":12,"weight":25},"rid":"r-push"}
        ],
        "workoutView": "cards",
        "rest": null,
        "progress": [3,1,1,0,0]
      },
      "customEx": [],
      "gifSize": "mini",
      "heatmapMetric": "time",
      "volumeWarmups": false,
      "workoutView": "cards",
      "collapseCompleted": false,
      "exerciseView": "list",
      "wc": {"steppers":true,"setShortcuts":false,"pairButtons":false,"exerciseButtons":false,"exerciseChips":true,"muscleMap":true,"swipeSets":true},
      "hints": {},
      "reminder": {"on":false,"time":"08:00","tz":null,"nudge":false,"tone":"friendly"},
      "effort": null,
      "autoBackup": false,
      "equipProfiles": [],
      "activeEquipId": null,
      "equipFilterOn": false,
      "exNotes": {},
      "exAliases": {},
      "favEx": [],
      "weekStart": 1,
      "wdec": 1,
      "speedUnit": null,
      "barWeights": {},
      "plates": {},
      "loadKind": {},
      "dbLoad": {},
      "dumbbells": {},
      "stackWeights": {},
      "gymCards": [],
      "lastGymCardId": null,
      "checkIn": true,
      "showWeightCard": true,
      "weighIn": false,
      "connStatus": true,
      "shareMap": true,
      "connLocal": true,
      "startFrom": "plan",
      "lastFrom": "routine",
      "enParens": {},
      "enOnly": {},
      "logRef": "last",
      "balanceTemplate": "poliquin",
      "balanceOverrides": {},
      "langAuto": true,
      "_ts": 1794225125000
    }
    """#

  static let vazio = #"""
    {
      "_fixtureNow": 1794225600000,
      "unit": "kg",
      "restSec": 90,
      "restPauseSec": 15,
      "sound": true,
      "soundOnSilent": false,
      "vibrateOnSilent": false,
      "timerFlash": false,
      "timedSetOvertime": false,
      "keepAwake": true,
      "theme": "dark",
      "accent": "lime",
      "body": "male",
      "targetW": null,
      "rateGoal": null,
      "bodyweight": [],
      "routines": [],
      "week": {},
      "dayPlan": {},
      "dayNotes": {},
      "measurements": [],
      "measurementEnabled": null,
      "customMeasurements": [],
      "queue": null,
      "rotation": null,
      "scheduleMode": null,
      "exWeights": {},
      "workouts": [],
      "active": null,
      "customEx": [],
      "gifSize": "mini",
      "heatmapMetric": "time",
      "volumeWarmups": false,
      "workoutView": "cards",
      "collapseCompleted": false,
      "exerciseView": "list",
      "wc": {"steppers":true,"setShortcuts":false,"pairButtons":false,"exerciseButtons":false,"exerciseChips":true,"muscleMap":true,"swipeSets":true},
      "hints": {},
      "reminder": {"on":false,"time":"08:00","tz":null,"nudge":false,"tone":"friendly"},
      "effort": null,
      "autoBackup": false,
      "equipProfiles": [],
      "activeEquipId": null,
      "equipFilterOn": false,
      "exNotes": {},
      "exAliases": {},
      "favEx": [],
      "weekStart": 1,
      "wdec": 1,
      "speedUnit": null,
      "barWeights": {},
      "plates": {},
      "loadKind": {},
      "dbLoad": {},
      "dumbbells": {},
      "stackWeights": {},
      "gymCards": [],
      "lastGymCardId": null,
      "checkIn": true,
      "showWeightCard": true,
      "weighIn": false,
      "connStatus": true,
      "shareMap": true,
      "connLocal": true,
      "startFrom": "plan",
      "lastFrom": "routine",
      "enParens": {},
      "enOnly": {},
      "logRef": "last",
      "balanceTemplate": "poliquin",
      "balanceOverrides": {},
      "langAuto": true
    }
    """#

  static let veioDoOpenGym = #"""
    {
      "_fixtureNow": 1794225600000,
      "unit": "kg",
      "restSec": 90,
      "restPauseSec": 15,
      "sound": true,
      "soundOnSilent": false,
      "vibrateOnSilent": false,
      "timerFlash": false,
      "timedSetOvertime": false,
      "keepAwake": true,
      "theme": "dark",
      "accent": "lime",
      "body": "male",
      "targetW": null,
      "rateGoal": null,
      "bodyweight": [],
      "routines": [
        {"id":"ra","name":"Treino A","emoji":"barbell","ex":[{"id":"0043","sets":3,"reps":8,"weight":60,"mode":"reps","pyramid":[8,6,4],"pyramidRest":[60,90,120]},{"id":"0025","sets":1,"reps":8,"weight":60,"mode":"reps"}]}
      ],
      "week": {"1":["ra"]},
      "dayPlan": {},
      "dayNotes": {},
      "measurements": [],
      "measurementEnabled": null,
      "customMeasurements": [],
      "queue": null,
      "rotation": null,
      "scheduleMode": null,
      "exWeights": {},
      "workouts": [],
      "active": {
        "id": "og-2026-11-09",
        "d": "2026-11-09",
        "start": 1794224400000,
        "routineIds": ["ra"],
        "name": "Treino A",
        "bw": 80,
        "cur": 0,
        "entries": [
          {"id":"0043","rid":"ra","noProg":true,"target":{"id":"0043","mode":"reps","sets":3,"reps":8,"pyramid":[8,6,4],"pyramidRest":[60,90,120]},"plan":{"kind":"off"},"sets":[{"w":40,"r":5,"done":true,"at":1794224400000,"phase":"warmup"},{"w":60,"r":8,"done":true,"at":1794224460000},{"w":70,"r":6,"done":false,"rir":2},{"w":80,"r":4,"done":false,"type":"dropset","drops":[{"w":60,"r":4}]}]},
          {"id":"0025","rid":"ra","target":{"id":"0025","mode":"reps","sets":1,"reps":8},"sets":[{"w":60,"r":8,"done":false,"type":"restpause","clusters":[{"r":3,"restSec":15}]}]},
          {"id":"0294","target":{"id":"0294","mode":"reps","side":true},"sets":[{"w":10,"r":16,"sides":{"L":{"w":10,"r":8,"done":true},"R":{"w":10,"r":8,"done":false}},"done":false},{"w":10,"r":16,"sides":{"L":{"w":10,"r":8,"done":false},"R":{"w":10,"r":8,"done":false}},"done":false}]},
          {"id":"0685","target":{"id":"0685","mode":"cardio","min":20,"speed":9},"sets":[{"min":20,"speed":9,"done":false,"incline":2}]},
          {"id":"0464","target":{"id":"0464","mode":"time","sec":45},"sets":[{"sec":45,"w":0,"done":false,"planSec":30}]},
          {"id":"exercicio-de-outro-aparelho","target":{"mode":"reps","sets":1,"reps":5,"weight":20},"sets":[{"w":20,"r":5,"done":false}]}
        ],
        "workoutView": "list",
        "collapseCompleted": true
      },
      "customEx": [],
      "gifSize": "mini",
      "heatmapMetric": "time",
      "volumeWarmups": false,
      "workoutView": "cards",
      "collapseCompleted": false,
      "exerciseView": "list",
      "wc": {"steppers":true,"setShortcuts":false,"pairButtons":false,"exerciseButtons":false,"exerciseChips":true,"muscleMap":true,"swipeSets":true},
      "hints": {},
      "reminder": {"on":false,"time":"08:00","tz":null,"nudge":false,"tone":"friendly"},
      "effort": null,
      "autoBackup": false,
      "equipProfiles": [],
      "activeEquipId": null,
      "equipFilterOn": false,
      "exNotes": {},
      "exAliases": {},
      "favEx": [],
      "weekStart": 1,
      "wdec": 1,
      "speedUnit": null,
      "barWeights": {},
      "plates": {},
      "loadKind": {},
      "dbLoad": {},
      "dumbbells": {},
      "stackWeights": {},
      "gymCards": [],
      "lastGymCardId": null,
      "checkIn": true,
      "showWeightCard": true,
      "weighIn": false,
      "connStatus": true,
      "shareMap": true,
      "connLocal": true,
      "startFrom": "plan",
      "lastFrom": "routine",
      "enParens": {},
      "enOnly": {},
      "logRef": "last",
      "balanceTemplate": "poliquin",
      "balanceOverrides": {},
      "langAuto": true
    }
    """#
}
#endif
