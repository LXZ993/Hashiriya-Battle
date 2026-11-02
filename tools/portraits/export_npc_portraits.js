// Erzeugt die Porträts der PA-Fahrer (art/portraits/npc/<sprecher>_<n>.svg) aus dem Silhouetten-Tool.
// Nutzung (im Repo-Ordner):
//   node tools/portraits/export_npc_portraits.js <silhouetten.html> [chat.json]
// Teile kommen aus chat.json: speakers[].look (eine Liste, ein Eintrag je Variante) und speakers[].figur.
// Fehlende Teile wählt das Tool selbst (fest aus der ID, also immer gleich).
'use strict'
const fs = require('fs')
const path = require('path')
const vm = require('vm')

const root = path.join(__dirname, '..', '..')
const [htmlPath, chatArg] = process.argv.slice(2)
if (!htmlPath) {
  console.error('Nutzung: node export_npc_portraits.js <silhouetten.html> [chat.json]')
  process.exit(1)
}
const chatPath = chatArg || path.join(root, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data', 'chat.json')
const chat = JSON.parse(fs.readFileSync(chatPath, 'utf8'))
const variants = (chat.pa && chat.pa.portraitVariants) || 3
const html = fs.readFileSync(htmlPath, 'utf8')
const start = html.indexOf('"use strict";', html.indexOf('<script>\n'))
const end = html.indexOf('const $ = id =>')
if (start < 0 || end < 0) throw new Error('Silhouetten-Tool hat ein unbekanntes Format')
const code = html.slice(start, end)

// PA-Fahrer als eigene "Crew" (Hintergrundzeichen パーキング = Parkplatz), Farbe je Sprecher
const npcs = []
for (const s of chat.speakers || []) {
  const looks = Array.isArray(s.look) ? s.look : []
  const c = s.color || [0.6, 0.6, 0.6]
  const hex = '#' + c.map(v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, '0')).join('')
  for (let i = 1; i <= variants; i++) {
    const look = Object.assign({ patch: 'keiner' }, looks[(i - 1) % Math.max(looks.length, 1)] || {})
    npcs.push({ id: s.id + '_' + i, name: s.id, team: 'npc_' + s.id, figur: s.figur || 'm', hints: look, color: hex })
  }
}

const sandbox = { window: {}, localStorage: { getItem: () => null, setItem: () => {} }, console }
vm.createContext(sandbox)
vm.runInContext(code + `
;(function () {
  DATA = { teams: NPCS.map(n => ({ id: n.team, name: n.name, jp: 'パーキング', color: n.color })), rivals: NPCS }
  TEAMS = Object.fromEntries(DATA.teams.map(t => [t.id, t]))
  computeAuto()
  OUT = DATA.rivals.map(r => ({ id: r.id, svg: renderSvg(r, Object.assign(partsOf(r), r.hints), { look: 'bob' }) }))
})()`, Object.assign(sandbox, { NPCS: npcs, OUT: null }))

const outDir = path.join(root, 'art', 'portraits', 'npc')
fs.mkdirSync(outDir, { recursive: true })
for (const f of fs.readdirSync(outDir)) if (f.endsWith('.svg')) fs.unlinkSync(path.join(outDir, f))
for (const p of sandbox.OUT) fs.writeFileSync(path.join(outDir, p.id + '.svg'), p.svg)
console.log(sandbox.OUT.length + ' PA-Porträts nach art/portraits/npc geschrieben')
