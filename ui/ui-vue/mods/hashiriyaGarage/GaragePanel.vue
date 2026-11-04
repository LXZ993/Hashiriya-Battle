<template>
  <div
    class="hbg"
    :class="{ 'is-min': ui.min }"
    :style="{ left: win.x + 'px', top: win.y + 'px', maxHeight: maxH + 'px' }"
    @wheel.stop
    @mousedown.stop
  >
    <div class="hbg-head" @mousedown="dragStart">
      <div class="hbg-title">GEGNER<span>GARAGE</span><small>DEV</small></div>
      <div class="hbg-sub" v-if="!ui.min">{{ d.rivals.length }} Gegner · in der Garage: <b>{{ loadedName }}</b></div>
      <div class="hbg-sub" v-else-if="sel">{{ sel.name }} · {{ sel.modelName }}</div>
      <div class="hbg-x" @mousedown.stop @click="toggleMin" :title="ui.min ? 'Aufklappen' : 'Einklappen'">{{ ui.min ? "▾" : "–" }}</div>
    </div>

    <template v-if="!ui.min">
      <div class="hbg-tabs">
        <span v-for="t in tabs" :key="t.id" class="hbg-tab" :class="{ 'is-on': ui.tab === t.id }" @click="setTab(t.id)">{{ t.name }}</span>
      </div>
      <div class="hbg-status" :class="{ 'is-bad': status && !status.ok, 'is-empty': !status }">{{ status ? status.time + " · " + status.text : "Bereit" }}</div>

      <div class="hbg-body">
        <div class="hbg-note" v-if="!d.full">Lade Gegnerliste …</div>

        <!-- Gegner-Auswahl (für alle Reiter) -->
        <div class="hbg-pick" v-if="d.full">
          <input
            class="hbg-search" type="text" v-model="q.text"
            placeholder="Suchen: Name, Spitzname, ID, Crew, Auto, Config …"
            @focus="typing(true)" @blur="typing(false)" @keydown.stop @keyup.stop
          />
          <div class="hbg-chips">
            <span v-for="f in filters" :key="f.id" class="hbg-chip" :class="{ 'is-on': q.role === f.id }" @click="setRole(f.id)">
              {{ f.name }} <em>{{ roleCount[f.id] }}</em>
            </span>
          </div>
          <div class="hbg-chips" v-if="q.role === 'crew' || q.role === 'leader' || q.team">
            <span v-for="t in d.teams" :key="t.id" class="hbg-chip hbg-team" :class="{ 'is-on': q.team === t.id }" @click="q.team = q.team === t.id ? null : t.id">
              <i class="hbg-dot" :style="{ background: t.color }"></i>{{ t.name }}
            </span>
          </div>
          <div class="hbg-sub2">{{ matches.length }} Treffer<span v-if="matches.length > 150"> (die ersten 150)</span></div>
          <div class="hbg-list">
            <div
              v-for="r in matches.slice(0, 150)" :key="r.id" class="hbg-li"
              :class="{ 'is-sel': sel && sel.id === r.id, 'is-bad': !r.configOk }"
              :style="{ borderLeftColor: r.color || roleColor(r.role) }"
              @click="select(r)"
            >
              <div class="hbg-li-main">
                <b>{{ r.name }}<i v-if="d.loadedId === r.id"> ● in der Garage</i></b>
                <span>{{ roleName(r) }} · {{ r.modelName }} · {{ r.configName }}</span>
              </div>
              <span class="hbg-tag" v-if="r.own">eigene</span>
              <span class="hbg-tag hbg-tag-bad" v-if="!r.configOk">fehlt</span>
            </div>
          </div>
        </div>

        <!-- Reiter Gegner -->
        <div class="hbg-detail" v-if="sel && ui.tab === 'rival'">
          <div class="hbg-name" :style="{ borderLeftColor: sel.color || roleColor(sel.role) }">
            <b>{{ sel.name }}</b><span class="hbg-role" :style="{ background: roleColor(sel.role) }">{{ roleLabel[sel.role] }}</span>
            <em>„{{ sel.nick }}“ · {{ sel.id }}</em>
          </div>
          <div class="hbg-warn" v-if="sel.placeholder">Platzhalter: {{ sel.placeholder }}</div>

          <div class="hbg-sec">Auto</div>
          <div class="hbg-kv"><span>Modell</span><b>{{ sel.modelName }} <i>({{ sel.model }})</i></b></div>
          <div class="hbg-kv"><span>Config</span><b>{{ sel.configName }}</b></div>
          <div class="hbg-path" :class="{ 'is-bad': !sel.configOk }">{{ sel.config }}{{ sel.configOk ? "" : "  — Datei fehlt!" }}</div>
          <div class="hbg-kv" v-if="sel.power || sel.value">
            <span>Werte</span>
            <b><i v-if="sel.power">{{ num(sel.power) }} PS</i><i v-if="sel.weight"> · {{ num(sel.weight) }} kg</i><i v-if="sel.value"> · Wert ${{ num(sel.value) }}</i></b>
          </div>
          <div class="hbg-kv" v-if="sel.plate"><span>Kennzeichen</span><b>{{ sel.plate.text }} <i>{{ sel.plate.design }}</i></b></div>
          <div class="hbg-kv" v-if="sel.paint"><span>Fester Lack</span><b><i class="hbg-sw" :style="{ background: paintCss(sel.paint) }"></i>{{ sel.paint.name || "eigene Farbe" }}</b></div>
          <div class="hbg-note" v-if="sel.paint">Im Spiel überdeckt dieser Lack aus rivals.json (paint) den Lack der Config, außer die Config hat eine Livery. Lackänderungen in der Garage wirken dann nicht.</div>
          <div class="hbg-note" v-if="sel.shared.length">
            Diese Config fahren auch:
            <template v-for="(id, i) in sel.shared" :key="id"><span class="hbg-link" @click="selectId(id)">{{ nameOf(id) }}</span>{{ i !== sel.shared.length - 1 ? ", " : "" }}</template>
          </div>
          <div class="hbg-btns">
            <span class="hbg-btn hbg-main" @click="act('load', { id: sel.id, mode: 'game' })" title="Mit Kennzeichen-Design und festem Lack aus rivals.json, so wie er auf der Strecke auftaucht">Laden (wie im Spiel)</span>
            <span class="hbg-btn" @click="act('load', { id: sel.id, mode: 'pure' })" title="Nur die .pc-Datei, ohne Kennzeichen-Design und Lack aus rivals.json">Nur Config laden</span>
          </div>

          <div class="hbg-sec">Charakter</div>
          <div class="hbg-text">{{ sel.desc }}</div>
          <div class="hbg-kv" v-if="sel.hint"><span>Hinweis</span><b>{{ sel.hint }}</b></div>
          <div class="hbg-kv" v-for="(c, i) in condList" :key="'c' + i"><span>{{ i === 0 ? "Bedingungen" : "" }}</span><b>{{ c }}</b></div>
          <div class="hbg-kv" v-if="sel.appear"><span>Auftauchen</span><b>{{ appearText(sel.appear) }}</b></div>
          <div class="hbg-kv"><span>Fahrstil</span><b>Aggression {{ sel.aggression }} · Reise {{ sel.cruiseKmh }} km/h · SP {{ sel.maxSp }}</b></div>
          <div class="hbg-kv"><span>Belohnung</span><b>{{ sel.rewardYen ? "¥" + sel.rewardYen : "$" + sel.rewardUsd }} · Ruf {{ sel.rep }}</b></div>
          <div class="hbg-line" v-for="(l, i) in lineList" :key="'l' + i"><span>{{ l.k }}</span>„{{ l.t }}“</div>

          <template v-if="selTeam">
            <div class="hbg-sec">Crew</div>
            <div class="hbg-crew" :style="{ borderColor: selTeam.color }">
              <b>{{ selTeam.name }}</b> <i>{{ selTeam.jp }}</i>
              <div class="hbg-text">{{ selTeam.desc }}</div>
              <div v-for="m in mates" :key="m.id" class="hbg-mate" :class="{ 'is-sel': m.id === sel.id }" @click="select(m)">
                <span>{{ m.role === "leader" ? "★ " : "" }}{{ m.name }}</span><em>{{ m.modelName }} · {{ m.configName }}</em>
              </div>
            </div>
          </template>

          <div class="hbg-sec">Speichern</div>
          <div class="hbg-warn" v-if="d.loadedId !== sel.id">In der Garage steht gerade {{ loadedName }}, nicht {{ sel.name }}. Erst laden, dann anpassen.</div>
          <div class="hbg-note" v-if="sel.own">Eigene Mod-Config: wird überschrieben (Sicherung in settings/hashiriya_battle/builder_backups/).</div>
          <div class="hbg-note" v-else>BeamNG-/fremde Config: bleibt unverändert. Es entsteht vehicles/{{ (d.player && d.player.model) || sel.model }}/hashiriya_r_{{ sel.id }}.pc im Mod-Ordner, rivals.json bekommt den neuen Pfad.</div>
          <div class="hbg-note" v-if="d.player && d.player.model !== sel.model">Achtung: Das Auto in der Garage ist ein {{ d.player.modelName }}, der Gegner fährt {{ sel.modelName }}. Beim Speichern wechselt auch sein Modell.</div>
          <span class="hbg-check" v-if="sel.own && sel.shared.length" :class="{ 'is-on': ui.ownFile }" @click="ui.ownFile = !ui.ownFile"><i></i>Eigene Datei nur für {{ sel.name }} (die anderen behalten die alte)</span>
          <div class="hbg-btns">
            <span class="hbg-btn hbg-main hbg-wide" :class="{ 'hbg-off': d.loadedId !== sel.id && armedKey !== 'save' }" @click="armedClick('save', save)">
              {{ armedKey === "save" ? "Sicher? Nochmal klicken" : "Auf " + sel.name + " speichern" }}
            </span>
          </div>
        </div>

        <!-- Reiter Aura -->
        <div class="hbg-detail" v-if="sel && ui.tab === 'aura'">
          <div class="hbg-name" :style="{ borderLeftColor: sel.auraColor || sel.color || roleColor(sel.role) }">
            <b>{{ sel.name }}</b><span class="hbg-role" :style="{ background: roleColor(sel.role) }">{{ roleLabel[sel.role] }}</span>
            <em>
              <template v-if="sel.auraOn">Hat eine Aura <i class="hbg-sw" :style="{ background: sel.auraColor || '#ff6600' }"></i>{{ sel.auraColor || "Standard" }}<template v-if="sel.leader"> · goldener Saum (Leader)</template></template>
              <template v-else>Hat im Spiel keine Aura</template>
            </em>
          </div>

          <div class="hbg-sec">Aura dieses Gegners</div>
          <div class="hbg-kv"><span>Hat Aura</span>
            <b class="hbg-chips hbg-inline">
              <span class="hbg-chip" :class="{ 'is-on': ed.on === null }" @click="edSet({ on: null })">Standard <em>{{ sel.auraDefaultOn ? "an" : "aus" }}</em></span>
              <span class="hbg-chip" :class="{ 'is-on': ed.on === true }" @click="edSet({ on: true })">An</span>
              <span class="hbg-chip" :class="{ 'is-on': ed.on === false }" @click="edSet({ on: false })">Aus</span>
            </b>
          </div>
          <div class="hbg-kv"><span>Farbe</span>
            <b class="hbg-color">
              <i class="hbg-sw hbg-sw-big" :style="{ background: edColor }"></i>
              <input class="hbg-search hbg-hex" type="text" v-model="hexText" maxlength="7"
                @focus="typing(true)" @blur="typing(false); hexDone()" @keydown.stop="e => e.key === 'Enter' && hexDone()" @keyup.stop />
              <span class="hbg-chip" :class="{ 'is-on': !ed.color }" @click="edSet({ color: null })" :title="'Standardfarbe ' + (sel.auraDefault || '')">Standard</span>
            </b>
          </div>
          <div class="hbg-rgb" v-for="(c, i) in ['R', 'G', 'B']" :key="c">
            <span>{{ c }}</span>
            <input type="range" min="0" max="255" step="1" :value="edRgb[i]" @input="e => rgbSet(i, e.target.value)" />
            <em>{{ edRgb[i] }}</em>
          </div>
          <div class="hbg-kv"><span>Stärke</span>
            <b class="hbg-chips hbg-inline">
              <span class="hbg-chip" :class="{ 'is-on': !ed.level }" @click="edSet({ level: null })">Standard <em>{{ ["schwach", "mittel", "stark"][(gcNum("rivalLevel", 2) || 2) - 1] }}</em></span>
              <span v-for="lv in [1, 2, 3]" :key="lv" class="hbg-chip" :class="{ 'is-on': ed.level === lv }" @click="edSet({ level: lv })">{{ ["schwach", "mittel", "stark"][lv - 1] }}</span>
            </b>
          </div>
          <div class="hbg-btns">
            <span class="hbg-btn hbg-main hbg-wide" :class="{ 'hbg-off': !edDirty }" @click="edSave">
              {{ edDirty ? "Aura auf " + sel.name + " speichern" : "Gespeichert" }}
            </span>
            <span class="hbg-btn" v-if="edDirty" @click="edReset">Verwerfen</span>
          </div>
          <div class="hbg-sec">Aura am Auto in der Garage</div>
          <div class="hbg-chips">
            <span v-for="m in auraModes" :key="m.id" class="hbg-chip" :class="{ 'is-on': auraOn && aura.mode === m.id }" @click="setAura({ mode: m.id })">{{ m.name }}</span>
            <span class="hbg-chip" :class="{ 'is-on': !auraOn }" @click="auraOff">Aus</span>
          </div>
          <div class="hbg-kv"><span>SP im Battle</span>
            <b class="hbg-chips hbg-inline">
              <span v-for="sp in [1, 0.6, 0.3, 0.1]" :key="sp" class="hbg-chip" :class="{ 'is-on': aura.sp === sp }" @click="setAura({ sp })">{{ Math.round(sp * 100) }} %</span>
            </b>
          </div>
          <div class="hbg-kv"><span>Vorschau heller</span>
            <b class="hbg-chips hbg-inline">
              <span v-for="b in [1, 3, 10]" :key="b" class="hbg-chip" :class="{ 'is-on': aura.boost === b }" @click="setAura({ boost: b })">{{ b === 1 ? "wie im Spiel" : b + "×" }}</span>
            </b>
          </div>
          <div class="hbg-note" v-if="auraOn && d.aura && d.aura.id !== sel.id">Gerade an: Aura von {{ nameOf(d.aura.id) }}. Ein Klick auf eine Art zeigt die Aura von {{ sel.name }}.</div>
          <div class="hbg-note">Die Aura folgt dem Auto, das gerade in der Garage steht. Am besten mit ausgeschaltetem Hallenlicht ansehen (rechts: Garage-Funktionen, die drei Lichter). „Vorschau heller“ gilt nur hier, nicht im Spiel. Farbe und Stärke oben siehst du sofort in der Vorschau, gespeichert wird erst mit dem Knopf.</div>

          <div class="hbg-sec">Allgemein für alle (aura.json)</div>
          <div class="hbg-kv"><span>Automatisch eine Aura</span>
            <b class="hbg-chips hbg-inline">
              <span v-for="w in whoList" :key="w.id" class="hbg-chip" :class="{ 'is-on': gcGet('who.' + w.id) === true }" @click="gcSet('who.' + w.id, gcGet('who.' + w.id) !== true)">{{ w.name }}</span>
            </b>
          </div>
          <div class="hbg-note">Aura-Träger im Moment: {{ auraCount }} von {{ d.rivals.length }}. Einzelne Gegner stellst du oben bei „Hat Aura“ an oder aus, das gilt vor dieser Regel.</div>
          <div class="hbg-kv"><span>Nebel</span>
            <b class="hbg-chips hbg-inline">
              <span class="hbg-chip" :class="{ 'is-on': gcGet('haze.ground') !== false }" @click="gcSet('haze.ground', gcGet('haze.ground') === false)">auch ohne Battle</span>
            </b>
          </div>
          <div class="hbg-rgb hbg-slider" v-for="sl in sliders" :key="sl.path" :title="sl.path">
            <span>{{ sl.name }}</span>
            <input type="range" :min="sl.min" :max="sl.max" :step="sl.step" :value="gcNum(sl.path, sl.min)" @input="e => gcSet(sl.path, Number(e.target.value))" />
            <em>{{ fmt(gcNum(sl.path, sl.min), sl.step) }}</em>
          </div>
          <div class="hbg-btns">
            <span class="hbg-btn hbg-main" :class="{ 'hbg-off': !gcDirty }" @click="gcSave" title="Regler und Regel in aura.json schreiben (mit Sicherung)">aura.json speichern</span>
            <span class="hbg-btn" @click="gcReload" title="aura.json neu einlesen, ungespeicherte Regler verwerfen">aura.json neu laden</span>
          </div>
        </div>

        <div class="hbg-foot">
          <span class="hbg-btn" @click="act('refresh')">Liste neu laden</span>
          <span class="hbg-hint">Garage verlassen: Knopf unten links in der Garage</span>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted, onUnmounted } from "vue"
import { useBridge } from "@/bridge"

const { api, events } = useBridge()

const tabs = [
  { id: "rival", name: "Gegner" },
  { id: "aura", name: "Aura" },
]
const filters = [
  { id: "all", name: "Alle" }, { id: "crew", name: "Crews" }, { id: "leader", name: "Leader" },
  { id: "wanderer", name: "Wanderer" }, { id: "boss", name: "Bosse" }, { id: "own", name: "Eigene Configs" }, { id: "missing", name: "Config fehlt" },
]
const roleLabel = { crew: "Crew", leader: "Leader", wanderer: "Wanderer", boss: "Boss", final: "Endboss", other: "Sonstige" }
const roleColors = { crew: "#ff9a3c", leader: "#ffd400", wanderer: "#b07bff", boss: "#ff3b3b", final: "#ff3b3b", other: "#a0a0a0" }
const roleColor = role => roleColors[role] || "#a0a0a0"
const auraModes = [
  { id: "ground", name: "Boden (Nacht)" },
  { id: "battle", name: "Battle (pulsiert)" },
  { id: "both", name: "Beides" },
]

const arr = v => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v) : [])
const num = v => Math.round(Number(v) || 0).toLocaleString("de-DE")

const d = ref({ full: false, rivals: [], teams: [], ranks: [] })
const q = reactive({ text: "", role: "all", team: null })
const status = ref(null)
const selId = ref(null)

// --- Fenster: Position, Einklappen, Reiter (Browser-Speicher) ---------------------------------------
const STORE = "hashiriyaGaragePanel"
const ui = reactive({ min: false, tab: "rival", ownFile: false })
const win = reactive({ x: 0, y: 0 })
const maxH = ref(600)
function load() {
  try {
    const s = JSON.parse(window.localStorage.getItem(STORE) || "null")
    if (s) {
      win.x = s.x; win.y = s.y; ui.min = !!s.min
      if (tabs.some(t => t.id === s.tab)) ui.tab = s.tab
      if (s.sel) selId.value = s.sel
    }
  } catch (e) {}
}
function remember() {
  try { window.localStorage.setItem(STORE, JSON.stringify({ x: win.x, y: win.y, min: ui.min, tab: ui.tab, sel: selId.value })) } catch (e) {}
}
function clampWin() {
  const w = window.innerWidth || 1920, h = window.innerHeight || 1080
  // Standard: rechts unten, unter den Garage-Funktionen am rechten Rand
  if (!win.x && !win.y) { win.x = Math.max(10, w - 470); win.y = Math.round(h * 0.4) }
  win.x = Math.min(Math.max(0, win.x), w - 140)
  win.y = Math.min(Math.max(0, win.y), h - 50)
  maxH.value = Math.max(160, h - win.y - 70)
}
function toggleMin() { ui.min = !ui.min; remember() }
function setTab(id) { ui.tab = id; remember() }

let drag = null
function dragStart(e) {
  if (e.button !== 0) return
  drag = { mx: e.clientX, my: e.clientY, x: win.x, y: win.y }
  e.preventDefault()
}
function onMove(e) {
  if (!drag) return
  win.x = drag.x + e.clientX - drag.mx
  win.y = drag.y + e.clientY - drag.my
  clampWin()
}
function onUp() { if (drag) { drag = null; remember() } }
function onResize() { clampWin() }

// Tippen ins Suchfeld: Tasten gehen an die Oberfläche statt ans Spiel
let typingOn = false
function typing(on) {
  if (typingOn === on) return
  typingOn = on
  api.engineLua("setCEFTyping(" + (on ? "true" : "false") + ")")
}

// --- Lua ---------------------------------------------------------------------------------------
function act(name, arg) {
  const a = arg === undefined ? "nil" : JSON.stringify(JSON.stringify(arg))
  api.engineLua('if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.action("' + name + '", ' + a + ") end")
}
const armedKey = ref(null)
let armTimer = null
function armedClick(key, fn) {
  if (armedKey.value === key) { armedKey.value = null; clearTimeout(armTimer); fn(); return }
  armedKey.value = key
  clearTimeout(armTimer)
  armTimer = setTimeout(() => { armedKey.value = null }, 4000)
}

// --- Liste --------------------------------------------------------------------------------------
function roleMatch(r, role) {
  if (role === "all") return true
  if (role === "crew") return r.role === "crew" || r.role === "leader"
  if (role === "boss") return r.role === "boss" || r.role === "final"
  if (role === "own") return r.own
  if (role === "missing") return !r.configOk
  return r.role === role
}
const roleCount = computed(() => {
  const out = {}
  for (const f of filters) out[f.id] = d.value.rivals.filter(r => roleMatch(r, f.id)).length
  return out
})
function setRole(id) { q.role = id; q.team = null }
const matches = computed(() => {
  const text = (q.text || "").toLowerCase()
  return d.value.rivals.filter(r => {
    if (!roleMatch(r, q.role)) return false
    if (q.team && r.team !== q.team) return false
    if (!text) return true
    return [r.id, r.name, r.nick, r.teamName, r.modelName, r.model, r.configName, r.config]
      .some(s => s && String(s).toLowerCase().includes(text))
  })
})
const byId = id => d.value.rivals.find(r => r.id === id) || null
const sel = computed(() => (selId.value ? byId(selId.value) : null))
function select(r) {
  if (!r) return
  selId.value = r.id
  ui.ownFile = false
  remember()
}
function selectId(id) { if (byId(id)) select(byId(id)) }
const nameOf = id => (byId(id) ? byId(id).name : id)
const loadedName = computed(() => {
  const r = d.value.loadedId && byId(d.value.loadedId)
  if (r) return r.name
  return d.value.player ? d.value.player.modelName + " (kein Gegner)" : "—"
})
function roleName(r) {
  if ((r.role === "crew" || r.role === "leader") && r.teamName) return (r.role === "leader" ? "Leader " : "") + r.teamName
  return roleLabel[r.role] || r.role
}

// --- Details ------------------------------------------------------------------------------------
const teamOf = id => (id ? d.value.teams.find(t => t.id === id) || null : null)
const selTeam = computed(() => (sel.value ? teamOf(sel.value.team) : null))
const mates = computed(() => (sel.value && sel.value.team ? d.value.rivals.filter(m => m.team === sel.value.team) : []))
function paintCss(p) {
  const c = arr(p && p.color)
  const v = c.length >= 3 ? c : [0.5, 0.5, 0.5]
  return "rgb(" + Math.round(v[0] * 255) + "," + Math.round(v[1] * 255) + "," + Math.round(v[2] * 255) + ")"
}
const lineNames = { challenge: "Herausfordern", win: "Er gewinnt", lose: "Er verliert" }
const lineList = computed(() => {
  const r = sel.value
  if (!r || !r.lines || typeof r.lines !== "object") return []
  const out = []
  for (const k of ["challenge", "win", "lose"]) if (r.lines[k]) out.push({ k: lineNames[k], t: r.lines[k] })
  for (const k of Object.keys(r.lines)) if (!lineNames[k]) out.push({ k, t: r.lines[k] })
  return out
})
const teamName = id => (teamOf(id) ? teamOf(id).name : id)
const list = v => (Array.isArray(v) ? v : [v])
const condList = computed(() => {
  const r = sel.value
  const c = (r && r.conditions && typeof r.conditions === "object") ? r.conditions : {}
  const ranks = arr(d.value.ranks)
  const out = []
  for (const k of Object.keys(c)) {
    const v = c[k]
    switch (k) {
      case "minRank": out.push("ab Rang " + (v + 1) + (ranks[v] ? " (" + ranks[v] + ")" : "")); break
      case "minWins": out.push("mindestens " + v + " Siege"); break
      case "minDay": out.push("ab Spieltag " + v); break
      case "hours": case "timeWindow": out.push("nur " + list(v)[0] + ":00 bis " + list(v)[1] + ":00 Uhr"); break
      case "playerModel": out.push("nur gegen Spieler im " + v); break
      case "playerPart": out.push("Spielerauto braucht Teil mit „" + v + "“"); break
      case "noPart": out.push("Spielerauto ohne Teil „" + v + "“"); break
      case "speedTraps": out.push(v === "all" ? "alle Blitzer ausgelöst" : v + " Blitzer ausgelöst"); break
      case "beatenTeam": out.push("Crew " + teamName(v) + " geschlagen"); break
      case "beatenTeams": out.push("Crews geschlagen: " + list(v).map(teamName).join(", ")); break
      case "beatenRivals": case "requires": out.push("Gegner geschlagen: " + list(v).map(nameOf).join(", ")); break
      case "naOnly": out.push("nur Sauger"); break
      case "forcedInduction": out.push("nur Turbo/Kompressor"); break
      case "manual": out.push("nur Schaltgetriebe"); break
      case "drive": out.push("Antrieb " + list(v).join("/")); break
      case "minPower": out.push("ab " + v + " PS"); break
      case "maxPower": out.push("bis " + v + " PS"); break
      case "paintColor": out.push("Lackfarbe " + list(v).join("/")); break
      default: out.push(k + ": " + (typeof v === "object" ? JSON.stringify(v) : v))
    }
  }
  return out
})
function appearText(a) {
  const m = { sameNight: "in derselben Nacht", nextNight: "ab der nächsten Nacht" }
  return list(a).map(x => m[x] || x).join(", ")
}
function save() { if (sel.value) act("save", { id: sel.value.id, ownFile: ui.ownFile }) }

// --- Aura ---------------------------------------------------------------------------------------
const aura = reactive({ mode: "ground", level: 2, sp: 1, boost: 1 })
const auraOn = computed(() => !!(d.value.aura && d.value.aura.id))
function setAura(p) {
  Object.assign(aura, p)
  if (!sel.value) return
  if (!p.mode && !auraOn.value) return // Stufe/SP nur merken, solange keine Aura an ist
  // Stufe/SP ändern, während eine Aura an ist: die laufende Aura bleibt beim gleichen Gegner
  const id = p.mode || !auraOn.value ? sel.value.id : d.value.aura.id
  const own = id === sel.value.id && ed.id === id // Werte aus dem Editor in die Vorschau
  act("aura", {
    id, mode: aura.mode, sp: aura.sp, boost: aura.boost,
    level: own ? ed.level || gcNum("rivalLevel", 2) : undefined, color: own ? edColor.value : undefined,
  })
}
function auraOff() { act("aura", { mode: "off" }) }

// --- Aura-Editor: pro Gegner (rivals.json) ------------------------------------------------------
const HEX = /^#[0-9a-fA-F]{6}$/
const ed = reactive({ id: null, on: null, color: null, level: null })
const hexText = ref("")
function edFrom(r) {
  ed.id = r ? r.id : null
  ed.on = r && (r.auraOwn === true || r.auraOwn === false) ? r.auraOwn : null
  ed.color = r && r.auraOwnColor ? r.auraOwnColor.toLowerCase() : null
  ed.level = r && r.auraLevel ? Number(r.auraLevel) : null
  hexText.value = edColor.value
}
const edColor = computed(() => ed.color || (sel.value && (sel.value.auraDefault || sel.value.auraColor)) || "#ff6600")
const edRgb = computed(() => [1, 3, 5].map(i => parseInt(edColor.value.substr(i, 2), 16) || 0))
const edDirty = computed(() => {
  const r = sel.value
  if (!r || ed.id !== r.id) return false
  const on = r.auraOwn === true || r.auraOwn === false ? r.auraOwn : null
  const color = r.auraOwnColor ? r.auraOwnColor.toLowerCase() : null
  const level = r.auraLevel ? Number(r.auraLevel) : null
  return on !== ed.on || color !== ed.color || level !== ed.level
})
watch(() => sel.value && sel.value.id, () => edFrom(sel.value), { immediate: true })
let edTimer = null
function edPreview() {
  // nur nachführen, wenn gerade die Aura dieses Gegners gezeigt wird
  if (!auraOn.value || !sel.value || d.value.aura.id !== sel.value.id) return
  clearTimeout(edTimer)
  edTimer = setTimeout(() => setAura({ mode: aura.mode }), 90)
}
function edSet(p) {
  Object.assign(ed, p)
  if ("color" in p) hexText.value = edColor.value
  edPreview()
}
function hexDone() {
  let v = (hexText.value || "").trim()
  if (v && v[0] !== "#") v = "#" + v
  if (HEX.test(v)) edSet({ color: v.toLowerCase() })
  else hexText.value = edColor.value
}
function rgbSet(i, v) {
  const c = edRgb.value.slice()
  c[i] = Math.max(0, Math.min(255, Math.round(Number(v) || 0)))
  edSet({ color: "#" + c.map(x => x.toString(16).padStart(2, "0")).join("") })
}
function edSave() {
  if (!sel.value || !edDirty.value) return
  act("auraSaveRival", { id: sel.value.id, on: ed.on, color: ed.color, level: ed.level })
}
function edReset() { edFrom(sel.value); edPreview() }

// --- Aura-Editor: allgemein (aura.json) ---------------------------------------------------------
const whoList = [
  { id: "boss", name: "Bosse" }, { id: "wanderer", name: "Wanderer" },
  { id: "leader", name: "Leader" }, { id: "member", name: "Crew-Mitglieder" },
]
const sliders = [
  { path: "rivalLevel", name: "Standard-Stärke", min: 1, max: 3, step: 1 },
  { path: "shell.ground", name: "Hülle ohne Battle", min: 0, max: 1.5, step: 0.05 },
  { path: "shell.battle", name: "Hülle im Battle", min: 0, max: 2, step: 0.05 },
  { path: "shell.height", name: "Hülle Höhe", min: 0.3, max: 3, step: 0.05 },
  { path: "shell.battleHeight", name: "Hülle Höhe Battle", min: 0.3, max: 3.5, step: 0.05 },
  { path: "shell.widthPad", name: "Hülle Abstand", min: 0.5, max: 2.5, step: 0.05 },
  { path: "shell.pulseDepth", name: "Pulsieren", min: 0, max: 1, step: 0.05 },
  { path: "shell.flicker", name: "Flackern", min: 0, max: 0.6, step: 0.02 },
  { path: "haze.amount", name: "Nebel Menge", min: 0, max: 3, step: 0.05 },
  { path: "haze.groundAmount", name: "Nebel ohne Battle", min: 0, max: 1.5, step: 0.05 },
  { path: "haze.alpha", name: "Nebel Dichte", min: 0.05, max: 1, step: 0.05 },
  { path: "haze.size", name: "Nebel Größe", min: 0.3, max: 3, step: 0.05 },
  { path: "haze.rise", name: "Nebel steigt", min: 0, max: 3, step: 0.05 },
  { path: "ground.intensity", name: "Bodenlicht", min: 0, max: 4000, step: 50 },
  { path: "battle.intensity", name: "Licht im Battle", min: 0, max: 6000, step: 50 },
]
const gc = ref({})
const gcDirty = ref(false)
function gcGet(path) {
  let t = gc.value
  for (const k of path.split(".")) { if (!t || typeof t !== "object") return undefined; t = t[k] }
  return t
}
const gcNum = (path, dflt) => { const v = Number(gcGet(path)); return isFinite(v) ? v : dflt }
const fmt = (v, step) => (step >= 1 ? String(Math.round(v)) : Number(v).toFixed(2))
const gcTimers = {}
function gcSet(path, value) {
  const keys = path.split(".")
  let t = gc.value
  for (const k of keys.slice(0, -1)) { if (!t[k] || typeof t[k] !== "object") t[k] = {}; t = t[k] }
  t[keys[keys.length - 1]] = value
  gc.value = { ...gc.value }
  gcDirty.value = true
  clearTimeout(gcTimers[path])
  gcTimers[path] = setTimeout(() => act("auraSet", { path, value }), 120)
}
function gcSave() { if (gcDirty.value) { act("auraSaveCfg"); gcDirty.value = false } }
function gcReload() { gcDirty.value = false; act("auraReload") }
const auraCount = computed(() => d.value.rivals.filter(r => r.auraOn).length)

// --- Daten von Lua ------------------------------------------------------------------------------
function onData(msg) {
  if (!msg) return
  if (msg.status) { status.value = msg.status; return }
  if (!msg.full) return
  msg.rivals = arr(msg.rivals)
  msg.teams = arr(msg.teams)
  msg.ranks = arr(msg.ranks)
  for (const r of msg.rivals) r.shared = arr(r.shared)
  if (msg.aura && msg.aura.id) {
    aura.mode = msg.aura.mode || aura.mode
    if (msg.aura.level) aura.level = msg.aura.level
    if (msg.aura.sp !== undefined && msg.aura.sp !== null) aura.sp = msg.aura.sp
    if (msg.aura.boost) aura.boost = msg.aura.boost
  }
  d.value = msg
  if (msg.auraCfg && !gcDirty.value) gc.value = JSON.parse(JSON.stringify(msg.auraCfg))
  if (!edDirty.value && sel.value) edFrom(sel.value)
}

onMounted(() => {
  load()
  clampWin()
  window.addEventListener("mousemove", onMove)
  window.addEventListener("mouseup", onUp)
  window.addEventListener("resize", onResize)
  events.on("HashiriyaGarage", onData)
  api.engineLua("if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.refresh() end")
})
onUnmounted(() => {
  window.removeEventListener("mousemove", onMove)
  window.removeEventListener("mouseup", onUp)
  window.removeEventListener("resize", onResize)
  events.off("HashiriyaGarage", onData)
  typing(false)
})
</script>

<style scoped>
.hbg {
  --o: #ff6600; --o2: #ff9a3c; --w: #f4f4f4; --dim: rgba(244, 244, 244, 0.58);
  position: fixed; z-index: 12500; width: 440px; box-sizing: border-box;
  display: flex; flex-direction: column; pointer-events: auto; user-select: none;
  font-family: "Overpass", "Noto Sans", "Segoe UI", sans-serif; color: var(--w); font-size: 12px; line-height: 1.3;
  background: linear-gradient(160deg, rgba(26, 26, 29, 0.96), rgba(14, 14, 16, 0.94));
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.55); border-left: 4px solid var(--o);
}
.hbg * { box-sizing: border-box; }
.hbg.is-min { width: 300px; }
.hbg-head { position: relative; padding: 9px 40px 7px 14px; cursor: move; flex: none;
  background: linear-gradient(100deg, rgba(255, 102, 0, 0.22), rgba(255, 102, 0, 0) 70%); border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
.hbg-title { font-size: 17px; font-weight: 900; font-style: italic; letter-spacing: 2px; line-height: 1; }
.hbg-title span { color: var(--o); margin-left: 6px; }
.hbg-title small { font-size: 9px; font-style: normal; letter-spacing: 1px; margin-left: 8px; padding: 1px 4px; background: rgba(255, 255, 255, 0.12); vertical-align: 3px; }
.hbg-sub { font-size: 11px; color: var(--dim); margin-top: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hbg-sub b { color: var(--w); font-weight: 700; }
.hbg-x { position: absolute; right: 8px; top: 8px; width: 24px; height: 24px; line-height: 24px; text-align: center; cursor: pointer; color: var(--dim); font-size: 14px; }
.hbg-x:hover { color: var(--w); background: rgba(255, 102, 0, 0.3); }
.hbg-tabs { display: flex; flex: none; border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
.hbg-tab { flex: 1; text-align: center; padding: 6px 0; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: var(--dim); cursor: pointer; border-bottom: 2px solid transparent; }
.hbg-tab:hover { color: var(--w); background: rgba(255, 102, 0, 0.12); }
.hbg-tab.is-on { color: var(--w); border-bottom-color: var(--o); }
.hbg-status { flex: none; font-size: 11px; padding: 4px 14px; height: 22px; line-height: 14px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; background: rgba(61, 220, 132, 0.15); color: #bff5d5; }
.hbg-status.is-empty { background: rgba(255, 255, 255, 0.04); color: var(--dim); }
.hbg-status.is-bad { background: rgba(220, 40, 40, 0.25); color: #ffc9c9; }
.hbg-body { flex: 1 1 auto; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 4px 12px 10px; }
.hbg-body::-webkit-scrollbar, .hbg-list::-webkit-scrollbar { width: 4px; }
.hbg-body::-webkit-scrollbar-thumb, .hbg-list::-webkit-scrollbar-thumb { background: var(--o); }
.hbg-sec { font-size: 10px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--o2); padding: 10px 0 4px; }
.hbg-note { font-size: 11px; color: var(--dim); padding: 3px 0; line-height: 1.4; }
.hbg-warn { font-size: 11px; padding: 5px 8px; margin: 4px 0; background: rgba(255, 180, 0, 0.14); border-left: 2px solid #ffb400; line-height: 1.35; }
.hbg-search { display: block; width: 100%; margin: 6px 0 3px; background: rgba(0, 0, 0, 0.4); border: 1px solid rgba(255, 255, 255, 0.12); color: var(--w); padding: 5px 7px; font-size: 12px; font-family: inherit; outline: none; user-select: text; }
.hbg-search:focus { border-color: var(--o); }
.hbg-chips { display: flex; flex-wrap: wrap; gap: 3px; padding: 3px 0; }
.hbg-inline { padding: 0; }
.hbg-chip { padding: 3px 7px; font-size: 10px; font-weight: 700; background: rgba(255, 255, 255, 0.06); cursor: pointer; white-space: nowrap; }
.hbg-chip em { font-style: normal; color: var(--dim); margin-left: 2px; }
.hbg-chip:hover { background: rgba(255, 102, 0, 0.25); }
.hbg-chip.is-on { background: rgba(255, 102, 0, 0.6); }
.hbg-chip.is-on em { color: var(--w); }
.hbg-team { font-weight: 600; }
.hbg-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 5px; box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.5); }
.hbg-sub2 { font-size: 10px; color: var(--dim); padding: 2px 0 3px; }
.hbg-list { display: flex; flex-direction: column; gap: 2px; max-height: 28vh; overflow-y: auto; }
.hbg-li { display: flex; align-items: center; gap: 4px; padding: 4px 6px; background: rgba(255, 255, 255, 0.04); border-left: 3px solid transparent; cursor: pointer; }
.hbg-li:hover { background: rgba(255, 102, 0, 0.14); }
.hbg-li.is-sel { background: rgba(255, 102, 0, 0.32); }
.hbg-li.is-bad .hbg-li-main span { color: #ff9d9d; }
.hbg-li-main { flex: 1; min-width: 0; }
.hbg-li-main b { display: block; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hbg-li-main b i { font-style: normal; font-size: 10px; color: #3ddc84; font-weight: 600; }
.hbg-li-main span { display: block; font-size: 10px; color: var(--dim); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hbg-tag { font-size: 9px; font-weight: 800; letter-spacing: 0.5px; padding: 1px 5px; background: rgba(255, 255, 255, 0.1); text-transform: uppercase; }
.hbg-tag-bad { background: rgba(220, 40, 40, 0.6); }
.hbg-detail { margin-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.08); padding-top: 6px; }
.hbg-name { border-left: 4px solid var(--o); padding: 2px 0 2px 8px; }
.hbg-name b { font-size: 16px; font-weight: 800; }
.hbg-name em { display: block; font-style: normal; font-size: 11px; color: var(--dim); margin-top: 2px; }
.hbg-role { display: inline-block; margin-left: 8px; font-size: 9px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; padding: 2px 6px; color: #111; vertical-align: 3px; }
.hbg-kv { display: flex; gap: 8px; font-size: 12px; padding: 2px 0; line-height: 1.35; }
.hbg-kv > span { flex: 0 0 86px; color: var(--dim); font-size: 11px; }
.hbg-kv > b { flex: 1; font-weight: 600; min-width: 0; }
.hbg-kv > b i { font-style: normal; color: var(--dim); font-weight: 500; }
.hbg-path { font-family: monospace; font-size: 10px; color: var(--dim); padding: 1px 0 3px 94px; word-break: break-all; }
.hbg-path.is-bad { color: #ff8a8a; }
.hbg-sw { display: inline-block; width: 12px; height: 12px; margin: 0 6px 0 4px; vertical-align: -2px; box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.4); }
.hbg-link { color: var(--o2); cursor: pointer; }
.hbg-link:hover { text-decoration: underline; }
.hbg-text { font-size: 12px; line-height: 1.45; padding: 2px 0 4px; }
.hbg-line { font-size: 11px; font-style: italic; color: rgba(244, 244, 244, 0.82); padding: 2px 0; line-height: 1.35; }
.hbg-line span { display: inline-block; width: 86px; font-style: normal; color: var(--dim); margin-right: 8px; }
.hbg-crew { border-left: 3px solid var(--o); background: rgba(255, 255, 255, 0.03); padding: 5px 8px; }
.hbg-crew > b { font-size: 13px; }
.hbg-crew > i { font-style: normal; color: var(--dim); font-size: 11px; }
.hbg-mate { display: flex; justify-content: space-between; gap: 8px; font-size: 11px; padding: 3px 4px; cursor: pointer; }
.hbg-mate:hover { background: rgba(255, 102, 0, 0.15); }
.hbg-mate.is-sel { background: rgba(255, 102, 0, 0.3); }
.hbg-mate em { font-style: normal; color: var(--dim); text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hbg-color { display: flex; align-items: center; gap: 5px; }
.hbg-sw-big { width: 18px; height: 18px; }
.hbg-hex { width: 82px; margin: 0; padding: 3px 5px; font-size: 11px; }
.hbg-rgb { display: flex; align-items: center; gap: 6px; padding: 1px 0; font-size: 10px; }
.hbg-rgb span { width: 14px; color: var(--dim); font-weight: 700; }
.hbg-rgb.hbg-slider span { width: 118px; }
.hbg-rgb input { flex: 1; min-width: 0; accent-color: var(--o); }
.hbg-rgb em { width: 38px; text-align: right; font-style: normal; color: var(--dim); }
.hbg-btns { display: flex; gap: 4px; padding: 6px 0 2px; }
.hbg-btn { display: inline-block; padding: 5px 9px; font-size: 11px; font-weight: 700; letter-spacing: 0.3px; background: rgba(255, 255, 255, 0.08); cursor: pointer; white-space: nowrap; text-align: center; }
.hbg-btn:hover { background: rgba(255, 102, 0, 0.35); }
.hbg-main { background: rgba(255, 102, 0, 0.55); }
.hbg-main:hover { background: var(--o); }
.hbg-off { opacity: 0.5; }
.hbg-wide { flex: 1; }
.hbg-check { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--dim); cursor: pointer; padding: 4px 0; }
.hbg-check i { width: 12px; height: 12px; border: 1px solid rgba(255, 255, 255, 0.4); flex: none; }
.hbg-check.is-on { color: var(--w); }
.hbg-check.is-on i { background: var(--o); border-color: var(--o); }
.hbg-foot { display: flex; align-items: center; gap: 8px; margin-top: 10px; padding-top: 6px; border-top: 1px solid rgba(255, 255, 255, 0.08); }
.hbg-hint { font-size: 10px; color: var(--dim); margin-left: auto; text-align: right; }
</style>
