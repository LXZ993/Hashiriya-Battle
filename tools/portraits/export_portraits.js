// Erzeugt die Gegner-Porträts fürs Spiel (art/portraits/<id>.svg) aus dem Silhouetten-Tool.
// Nutzung (im Repo-Ordner):
//   node tools/portraits/export_portraits.js <silhouetten.html> <rivals_data.js> [silhouetten.json]
// silhouetten.json = Export aus dem Tool ("seed" + "overrides"); ohne Datei gelten die Auto-Teile.
// Zeichnet mit genau demselben Code wie das Tool, daher sehen die Porträts im Spiel gleich aus.
'use strict'
const fs = require('fs')
const path = require('path')
const vm = require('vm')

const [htmlPath, dataPath, overridesPath] = process.argv.slice(2)
if (!htmlPath || !dataPath) {
  console.error('Nutzung: node export_portraits.js <silhouetten.html> <rivals_data.js> [silhouetten.json]')
  process.exit(1)
}
const html = fs.readFileSync(htmlPath, 'utf8')
// Nur der Zeichen-Teil des Tools (bis zur Oberfläche), ohne DOM-Code
const start = html.indexOf('"use strict";', html.indexOf('<script>\n'))
const end = html.indexOf('const $ = id =>')
if (start < 0 || end < 0) throw new Error('Silhouetten-Tool hat ein unbekanntes Format')
const code = html.slice(start, end)

const sandbox = { window: {}, localStorage: { getItem: () => null, setItem: () => {} }, console }
vm.createContext(sandbox)
vm.runInContext(fs.readFileSync(dataPath, 'utf8'), sandbox)
const ov = overridesPath && fs.existsSync(overridesPath) ? JSON.parse(fs.readFileSync(overridesPath, 'utf8')) : {}
vm.runInContext(code + `
;(function () {
  if (OV.seed) state.seed = OV.seed
  state.overrides = OV.overrides || {}
  TEAMS = Object.fromEntries(DATA.teams.map(t => [t.id, t]))
  computeAuto()
  OUT = DATA.rivals.map(r => ({ id: r.id, svg: renderSvg(r, partsOf(r), { look: 'bob' }) }))
})()`, Object.assign(sandbox, { OV: ov, OUT: null }))

const outDir = path.join(__dirname, '..', '..', 'art', 'portraits')
fs.mkdirSync(outDir, { recursive: true })
for (const f of fs.readdirSync(outDir)) if (f.endsWith('.svg')) fs.unlinkSync(path.join(outDir, f))
for (const p of sandbox.OUT) fs.writeFileSync(path.join(outDir, p.id + '.svg'), p.svg)
console.log(sandbox.OUT.length + ' Porträts nach art/portraits geschrieben' + (ov.overrides ? ' (mit ' + Object.keys(ov.overrides).length + ' Änderungen)' : ''))
