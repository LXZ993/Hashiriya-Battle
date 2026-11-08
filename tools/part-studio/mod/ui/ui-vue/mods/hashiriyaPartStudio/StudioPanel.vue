<template>
  <div
    class="hps"
    :class="{ 'is-min': ui.min }"
    :style="{ left: win.x + 'px', top: win.y + 'px', maxHeight: maxH + 'px' }"
    @wheel.stop
    @mousedown.stop
  >
    <div class="hps-head" @mousedown="dragStart">
      <div class="hps-title">TEILE<span>STUDIO</span></div>
      <div class="hps-sub" v-if="g.vehicle">{{ g.modelName }} · {{ g.withImg }} von {{ g.total }} Teilen mit Bild</div>
      <div class="hps-sub" v-else>Kein Auto</div>
      <div class="hps-x hps-x2" @mousedown.stop @click="toggleMin" :title="ui.min ? 'Aufklappen' : 'Einklappen'">{{ ui.min ? "▾" : "–" }}</div>
      <div class="hps-x" @mousedown.stop @click="close" title="Schließen (Strg+Umschalt+P)">✕</div>
    </div>

    <template v-if="!ui.min">
      <div class="hps-tabs">
        <span v-for="t in tabs" :key="t.id" class="hps-tab" :class="{ 'is-on': ui.tab === t.id }" @click="setTab(t.id)">
          {{ t.name }}<i v-if="t.id === 'make' && running" class="hps-live"></i>
        </span>
      </div>
      <div class="hps-status" :class="{ 'is-bad': status && !status.ok, 'is-empty': !status }">{{ status ? status.text : statusIdle }}</div>

      <!-- ===================== Galerie ===================== -->
      <div class="hps-body" v-if="ui.tab === 'gallery'">
        <div class="hps-note" v-if="!g.vehicle">Steig in ein Auto (oder spawne eins), dann zeigt die Galerie seine Teile.</div>
        <template v-else>
          <div class="hps-big">
            <img v-if="shown && shown.img" :src="imgUrl(shown.img)" />
            <div v-else class="hps-big-empty">{{ shown ? (shown.visual ? "Noch kein Bild" : "Teil ohne sichtbares Mesh") : "Fahr mit der Maus über ein Teil, Klick wählt es aus" }}</div>
            <div class="hps-big-cap" v-if="shown"><b>{{ shown.name }}</b><span>{{ shown.part }}</span></div>
          </div>
          <div class="hps-view" v-if="pinOpt" :class="{ 'is-busy': running }">
            <span class="hps-view-l" :title="pinOpt.name">Ansicht</span>
            <span class="hps-btn hps-ib" title="nach links drehen" @click="view({ dyaw: -20 })">⟲</span>
            <span class="hps-btn hps-ib" title="nach rechts drehen" @click="view({ dyaw: 20 })">⟳</span>
            <span class="hps-btn hps-ib" title="von weiter oben" @click="view({ dpitch: 15 })">▲</span>
            <span class="hps-btn hps-ib" title="von weiter unten" @click="view({ dpitch: -15 })">▼</span>
            <span class="hps-btn hps-ib" title="näher" @click="view({ dzoom: 1.2 })">+</span>
            <span class="hps-btn hps-ib" title="weiter weg" @click="view({ dzoom: 1 / 1.2 })">−</span>
            <span class="hps-btn" title="automatischen Blickwinkel nehmen" @click="view({ reset: true })">Auto</span>
            <span class="hps-btn hps-btn-o" title="neu fotografieren" @click="reshoot">Neu aufnehmen</span>
            <span class="hps-view-scope">
              <span class="hps-chip" :class="{ 'is-on': ui.viewScope !== 'part' }" @click="setScope('slot')" title="Korrektur gilt für alle Teile in diesem Slot">ganzer Slot ({{ pinParts.length }})</span>
              <span class="hps-chip" :class="{ 'is-on': ui.viewScope === 'part' }" @click="setScope('part')">nur dieses Teil</span>
            </span>
            <em class="hps-view-v">{{ pinOpt.name }}<template v-if="pinOpt.view"> · {{ viewText(pinOpt.view) }}</template></em>
          </div>
          <input class="hps-search" type="text" v-model="q.text" placeholder="Suchen: Slot, Teilname …"
            @focus="typing(true)" @blur="typing(false)" @keydown.stop @keyup.stop />
          <div class="hps-chips">
            <span class="hps-chip" :class="{ 'is-on': q.onlyImg }" @click="q.onlyImg = !q.onlyImg">nur mit Bild</span>
            <span class="hps-chip" :class="{ 'is-on': q.onlyVisual }" @click="q.onlyVisual = !q.onlyVisual">nur sichtbare Teile</span>
            <span class="hps-chip hps-chip-act" @click="makeCurrent">Bilder für dieses Auto erstellen</span>
          </div>
          <div class="hps-sub2">{{ rows.length }} Slots</div>
          <div v-for="r in rows" :key="r.key" class="hps-slot" :class="{ 'is-open': openKey === r.key }">
            <div class="hps-slot-h" @click="toggleSlot(r.key)">
              <span class="hps-thumb">
                <img v-if="r.cur && r.cur.img" :src="imgUrl(r.cur.img)" />
              </span>
              <span class="hps-slot-t">
                <b>{{ r.name }}</b>
                <em>{{ r.chosenName }}<template v-if="r.parent"> · an {{ r.parent }}</template></em>
              </span>
              <span class="hps-count">{{ r.opts.length }}</span>
            </div>
            <div class="hps-tiles" v-if="openKey === r.key || q.text" @mouseleave="hover = null">
              <div v-for="o in r.opts" :key="o.part" class="hps-tile"
                :class="{ 'is-on': o.on, 'is-noimg': !o.img, 'is-armed': armed === r.key + '|' + o.part, 'is-pin': pin && pin.key === r.key && pin.part === o.part }"
                @mouseenter="hover = o" @click="pick(r, o)">
                <div class="hps-tile-img">
                  <img v-if="o.img" :src="imgUrl(o.img)" loading="lazy" />
                  <span v-else>{{ o.visual ? "kein Bild" : "unsichtbar" }}</span>
                </div>
                <div class="hps-tile-n">{{ o.name }}</div>
                <div class="hps-tile-tag" v-if="o.on">verbaut</div>
                <div class="hps-tile-tag hps-tag-arm" v-else-if="armed === r.key + '|' + o.part">nochmal klicken</div>
              </div>
              <div class="hps-tile hps-tile-empty" @click="pick(r, { part: '', name: 'Ausbauen' })" v-if="r.chosen">
                <div class="hps-tile-img"><span>leer</span></div>
                <div class="hps-tile-n">Ausbauen</div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- ===================== Bilder erstellen ===================== -->
      <div class="hps-body" v-if="ui.tab === 'make'">
        <template v-if="job && (job.running || job.finished)">
          <div class="hps-sec">{{ job.running ? "Läuft" : job.text }}</div>
          <div class="hps-prog">
            <div class="hps-prog-bar"><i :style="{ width: progress + '%' }"></i></div>
            <div class="hps-kv"><span>Fahrzeug</span><b>{{ job.model || "–" }} <i>({{ job.modelIndex }} von {{ job.modelCount }})</i></b></div>
            <div class="hps-kv" v-if="job.rounds"><span>Durchgang</span><b>{{ job.round }} von {{ job.rounds }}</b></div>
            <div class="hps-kv"><span>Neue Bilder</span><b>{{ job.done }}<i> · {{ job.skipped }} schon da · {{ job.failed }} fehlgeschlagen · {{ job.noMesh }} ohne Mesh</i></b></div>
            <div class="hps-kv"><span>Zeit</span><b>{{ fmtTime(job.elapsed) }}</b></div>
            <div class="hps-note" v-if="job.text">{{ job.text }}</div>
          </div>
          <div class="hps-big" v-if="job.last">
            <img :src="imgUrl(job.last)" />
            <div class="hps-big-cap"><b>Zuletzt</b><span>{{ job.lastName }}</span></div>
          </div>
          <div class="hps-btns">
            <span class="hps-btn hps-wide" v-if="job.running" @click="stop">{{ job.stopping ? "Wird abgebrochen …" : "Abbrechen" }}</span>
            <span class="hps-btn hps-wide" v-else @click="clearJob">Neue Auswahl</span>
            <span class="hps-btn" @click="openFolder">Ordner öffnen</span>
          </div>
        </template>
        <template v-else>
          <div class="hps-note hps-warn" v-if="!inGarage">
            Fotografiert wird in der BeamNG-Garage. Beim Start wechselt das Studio mit deinem Auto dorthin
            und legt danach los.
            <span class="hps-btn hps-btn-o" @click="call('goGarage')">Jetzt in die Garage</span>
          </div>
          <div class="hps-note">
            Wähle die Fahrzeuge. Das Studio baut jedes sichtbare Teil einzeln an ein unsichtbares Studio-Auto
            und fotografiert es. Ein Auto dauert je nach Teilezahl ein paar Minuten, alle Fahrzeuge deutlich länger.
            Schon vorhandene Bilder werden übersprungen.
          </div>
          <input class="hps-search" type="text" v-model="m.text" placeholder="Fahrzeug suchen …"
            @focus="typing(true)" @blur="typing(false)" @keydown.stop @keyup.stop />
          <div class="hps-chips">
            <span class="hps-chip" @click="selectSet('current')">aktuelles Auto</span>
            <span class="hps-chip" @click="selectSet('official')">alle Original</span>
            <span class="hps-chip" @click="selectSet('mod')">alle Mods</span>
            <span class="hps-chip" @click="selectSet('none')">keine</span>
          </div>
          <div class="hps-sub2">{{ selCount }} von {{ models.length }} ausgewählt</div>
          <div class="hps-list">
            <div v-for="x in modelMatches" :key="x.key" class="hps-li" :class="{ 'is-sel': m.sel[x.key] }" @click="m.sel[x.key] = !m.sel[x.key]">
              <i class="hps-box"></i>
              <span class="hps-li-main"><b>{{ x.name }}</b><span>{{ x.key }} · {{ x.official ? "Original" : (x.source || "Mod") }}</span></span>
            </div>
          </div>
          <div class="hps-btns">
            <span class="hps-btn hps-main hps-wide" :class="{ 'hps-off': !selCount }" @click="start">Bilder erstellen ({{ selCount }})</span>
            <span class="hps-btn" @click="openFolder">Ordner öffnen</span>
          </div>
        </template>
      </div>

      <!-- ===================== Einstellungen ===================== -->
      <div class="hps-body" v-if="ui.tab === 'settings'">
        <div class="hps-sec">Bild</div>
        <div class="hps-row"><span>Größe</span>
          <select v-model.number="setW" @change="setSize">
            <option :value="256">256 × 160</option><option :value="320">320 × 200</option>
            <option :value="400">400 × 250</option><option :value="512">512 × 320</option>
          </select>
        </div>
        <div class="hps-check" :class="{ 'is-on': s.studioPaint }" @click="set('studioPaint', !s.studioPaint)"><i></i>Einheitlicher Studio-Lack (silbergrau)</div>
        <div class="hps-check" :class="{ 'is-on': s.skipExisting }" @click="set('skipExisting', !s.skipExisting)"><i></i>Vorhandene Bilder überspringen (aus: die eigenen Teile der gewählten Autos neu machen; gemeinsame Teile wie Felgen, Reifen und Radkappen bleiben, wenn sie schon da sind)</div>
        <div class="hps-check" :class="{ 'is-on': s.singlePair }" @click="set('singlePair', !s.singlePair)"><i></i>Paare nur einmal zeigen (Felgen, Reifen, Bremsen …)</div>
        <div class="hps-check" :class="{ 'is-on': s.autoView }" @click="set('autoView', !s.autoView)"><i></i>Besten Blickwinkel automatisch suchen (5 Ansichten je Teil, es gewinnt die, auf der man am meisten vom Teil sieht)</div>
        <div class="hps-sec">Licht</div>
        <div class="hps-note">Fotografiert wird in der BeamNG-Garage mit ihrem eigenen Licht, so wie du dein Auto dort siehst. Das Studio ändert am Licht und an der Belichtung nichts, es übernimmt die Belichtung der Spielkamera.</div>
        <div class="hps-note">Neue Einstellungen gelten für neue Bilder. Alte Bilder neu machen: „Vorhandene Bilder überspringen“ ausschalten oder in der Galerie „Neu aufnehmen“.</div>
        <div class="hps-sec">Kamera</div>
        <div class="hps-rgb hps-slider"><span>Abstand ums Teil</span>
          <input type="range" min="1" max="1.6" step="0.02" :value="s.padding" @change="set('padding', Number($event.target.value))" /><em>{{ Number(s.padding).toFixed(2) }}</em></div>
        <div class="hps-rgb hps-slider"><span>Blickwinkel</span>
          <input type="range" min="15" max="50" step="1" :value="s.fov" @change="set('fov', Number($event.target.value))" /><em>{{ s.fov }}°</em></div>
        <div class="hps-rgb hps-slider"><span>Wartezeit je Bild</span>
          <input type="range" min="1" max="2.5" step="0.1" :value="s.settleDelay" @change="set('settleDelay', Number($event.target.value))" /><em>{{ Number(s.settleDelay).toFixed(1) }} s</em></div>
        <div class="hps-note">Die Bilder liegen im BeamNG-Benutzerordner unter art/partPreviews_garage/ (ein Bild je Teilname).</div>
        <div class="hps-btns">
          <span class="hps-btn" @click="openFolder">Ordner öffnen</span>
          <span class="hps-btn" @click="resetSettings">Standard</span>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from "vue"
import { useBridge } from "@/bridge"

const { api, events } = useBridge()

const tabs = [
  { id: "gallery", name: "Galerie" },
  { id: "make", name: "Bilder erstellen" },
  { id: "settings", name: "Einstellungen" },
]
const arr = v => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v) : [])
const norm = s => String(s || "").toLowerCase()

const g = ref({ vehicle: false, rows: [], withImg: 0, total: 0 })
const job = ref(null)
const s = ref({})
const models = ref([])
const inGarage = ref(true)
const status = ref(null)
const hover = ref(null)
const openKey = ref(null)
const armed = ref(null)
const imgVer = ref(0)
const q = reactive({ text: "", onlyImg: false, onlyVisual: true })
const m = reactive({ text: "", sel: {} })
const setW = ref(320)

// --- Fenster (Position, Einklappen, Reiter im Browser-Speicher) ----------------------------------
const STORE = "hashiriyaPartStudioPanel"
const ui = reactive({ min: false, tab: "gallery", viewScope: "slot" })
const win = reactive({ x: 0, y: 0 })
const maxH = ref(700)
function load() {
  try {
    const st = JSON.parse(window.localStorage.getItem(STORE) || "null")
    if (st) {
      win.x = st.x; win.y = st.y; ui.min = !!st.min
      if (tabs.some(t => t.id === st.tab)) ui.tab = st.tab
      if (st.viewScope === "part") ui.viewScope = "part"
    }
  } catch (e) {}
}
function remember() {
  try { window.localStorage.setItem(STORE, JSON.stringify({ x: win.x, y: win.y, min: ui.min, tab: ui.tab, viewScope: ui.viewScope })) } catch (e) {}
}
function clampWin() {
  const w = window.innerWidth || 1920, h = window.innerHeight || 1080
  if (!win.x && !win.y) { win.x = Math.max(10, w - 560); win.y = 70 }
  win.x = Math.min(Math.max(0, win.x), w - 140)
  win.y = Math.min(Math.max(0, win.y), h - 50)
  maxH.value = Math.max(200, h - win.y - 20)
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

let typingOn = false
function typing(on) {
  if (typingOn === on) return
  typingOn = on
  api.engineLua("setCEFTyping(" + (on ? "true" : "false") + ")")
}

// --- Lua ---------------------------------------------------------------------------------------
function call(fn, arg) {
  const a = arg === undefined ? "" : JSON.stringify(typeof arg === "string" ? arg : JSON.stringify(arg))
  api.engineLua("if extensions.hashiriyaPartStudio then extensions.hashiriyaPartStudio." + fn + "(" + a + ") end")
}
function close() { call("close") }
function openFolder() { call("openFolder") }
function stop() { call("stop") }
function clearJob() { job.value = null }
function set(key, value) {
  api.engineLua("if extensions.hashiriyaPartStudio then extensions.hashiriyaPartStudio.setSetting(" +
    JSON.stringify(key) + ", " + (typeof value === "string" ? JSON.stringify(value) : JSON.stringify(JSON.stringify(value))) + ") end")
}
function setSize() {
  const w = Number(setW.value) || 320
  set("width", w)
  set("height", Math.round(w * 0.625))
}
function resetSettings() { call("resetSettings") }

function imgUrl(p) { return p + "?v=" + imgVer.value }
function fmtTime(sec) {
  sec = Math.max(0, Math.round(Number(sec) || 0))
  const h = Math.floor(sec / 3600), mi = Math.floor((sec % 3600) / 60), se = sec % 60
  return (h ? h + " h " : "") + (h || mi ? mi + " min " : "") + se + " s"
}

// --- Galerie ------------------------------------------------------------------------------------
const rows = computed(() => {
  const t = norm(q.text)
  const out = []
  for (const r of arr(g.value.rows)) {
    let opts = arr(r.options)
    if (q.onlyVisual) opts = opts.filter(o => o.visual || o.img)
    if (q.onlyImg) opts = opts.filter(o => o.img)
    const slotHit = !t || norm(r.name + " " + r.id + " " + r.parent).includes(t)
    if (!slotHit) opts = opts.filter(o => norm(o.name + " " + o.part).includes(t))
    if (!opts.length) continue
    const cur = arr(r.options).find(o => o.on)
    out.push({ ...r, opts, cur })
  }
  return out
})
function toggleSlot(key) { openKey.value = openKey.value === key ? null : key }

// Ausgewähltes Teil (Klick): bleibt in der großen Vorschau, dort lässt sich der Blickwinkel korrigieren
const pin = ref(null)
const pinOpt = computed(() => {
  const p = pin.value
  if (!p) return null
  const r = arr(g.value.rows).find(x => x.key === p.key)
  return (r && arr(r.options).find(o => o.part === p.part)) || null
})
const shown = computed(() => hover.value || pinOpt.value)
// alle sichtbaren Teile im Slot des ausgewählten Teils (für „ganzer Slot“)
const pinParts = computed(() => {
  const p = pin.value
  if (!p) return []
  const r = arr(g.value.rows).find(x => x.key === p.key)
  return r ? arr(r.options).filter(o => o.visual || o.img).map(o => o.part) : []
})
function setScope(v) { ui.viewScope = v; remember() }
function target() {
  const p = pin.value
  const slot = ui.viewScope !== "part"
  return { ...p, scope: slot ? "slot" : "part", parts: slot ? pinParts.value : [p.part] }
}
function view(change) {
  if (!pin.value || running.value) return
  call("setView", { ...target(), ...change })
}
function reshoot() {
  if (!pin.value || running.value) return
  call("reshoot", target())
}
function viewText(v) {
  const t = []
  if (Number(v.yaw)) t.push("gedreht " + Math.round(v.yaw) + "°")
  if (Number(v.pitch)) t.push("gekippt " + Math.round(v.pitch) + "°")
  if (Number(v.zoom) && Math.abs(v.zoom - 1) > 0.01) t.push("Zoom " + Number(v.zoom).toFixed(2) + "×")
  return t.join(" · ")
}

let armTimer = null
function pick(r, o) {
  if (o.part) pin.value = { key: r.key, path: r.path, slotId: r.id, part: o.part, name: o.name }
  if (o.on) return
  const key = r.key + "|" + o.part
  if (armed.value !== key) {
    armed.value = key
    clearTimeout(armTimer)
    armTimer = setTimeout(() => { armed.value = null }, 3000)
    return
  }
  armed.value = null
  call("install", { key: r.key, part: o.part, name: o.name })
}
function makeCurrent() {
  ui.tab = "make"; remember()
  call("start", { models: "current" })
}

// --- Bilder erstellen ---------------------------------------------------------------------------
const running = computed(() => !!(job.value && job.value.running))
const progress = computed(() => {
  const j = job.value
  if (!j || !j.planned) return j && j.finished ? 100 : 0
  return Math.min(100, Math.round(((j.done + j.failed + j.noMesh) / j.planned) * 100))
})
const modelMatches = computed(() => {
  const t = norm(m.text)
  return models.value.filter(x => !t || norm(x.name + " " + x.key + " " + x.source).includes(t))
})
const selCount = computed(() => models.value.filter(x => m.sel[x.key]).length)
function selectSet(kind) {
  if (kind === "current") {
    for (const x of models.value) m.sel[x.key] = x.key === g.value.model
    return
  }
  for (const x of modelMatches.value) {
    if (kind === "none") m.sel[x.key] = false
    else if (kind === "official" && x.official) m.sel[x.key] = true
    else if (kind === "mod" && !x.official) m.sel[x.key] = true
  }
}
function start() {
  const keys = models.value.filter(x => m.sel[x.key]).map(x => x.key)
  if (!keys.length) return
  call("start", { models: keys })
}

const statusIdle = computed(() => (running.value ? "Bilderstellung läuft …" : "Bereit"))

// --- Daten von Lua ------------------------------------------------------------------------------
let statusTimer = null
function onData(d) {
  if (!d) return
  if (d.status) {
    status.value = d.status
    clearTimeout(statusTimer)
    statusTimer = setTimeout(() => { status.value = null }, 5000)
  }
  if (d.settings) {
    s.value = d.settings
    setW.value = Number(d.settings.width) || 320
  }
  if (d.models) models.value = arr(d.models)
  if (d.inGarage !== undefined) inGarage.value = !!d.inGarage
  if (d.gallery) {
    const gal = d.gallery
    gal.rows = arr(gal.rows)
    for (const r of gal.rows) r.options = arr(r.options)
    g.value = gal
    imgVer.value++
    if (hover.value) {
      const p = hover.value.part
      hover.value = null
      for (const r of gal.rows) { const o = r.options.find(x => x.part === p); if (o) { hover.value = o; break } }
    }
  }
  if (d.job !== undefined) {
    const was = job.value && job.value.last
    job.value = d.job || null
    if (job.value && job.value.last !== was) imgVer.value++
  }
}

onMounted(() => {
  load()
  clampWin()
  window.addEventListener("mousemove", onMove)
  window.addEventListener("mouseup", onUp)
  window.addEventListener("resize", onResize)
  events.on("HashiriyaPartStudio", onData)
  call("requestState")
  call("requestGallery")
})
onUnmounted(() => {
  window.removeEventListener("mousemove", onMove)
  window.removeEventListener("mouseup", onUp)
  window.removeEventListener("resize", onResize)
  events.off("HashiriyaPartStudio", onData)
  typing(false)
})
</script>

<style scoped>
.hps {
  --o: #ff6600; --o2: #ff9a3c; --w: #f4f4f4; --dim: rgba(244, 244, 244, 0.58);
  position: fixed; z-index: 12500; width: 540px; box-sizing: border-box;
  display: flex; flex-direction: column; pointer-events: auto; user-select: none;
  font-family: "Overpass", "Noto Sans", "Segoe UI", sans-serif; color: var(--w); font-size: 12px; line-height: 1.3;
  background: linear-gradient(160deg, rgba(26, 26, 29, 0.96), rgba(14, 14, 16, 0.94));
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.55); border-left: 4px solid var(--o);
}
.hps * { box-sizing: border-box; }
.hps.is-min { width: 320px; }
.hps-head { position: relative; padding: 9px 70px 7px 14px; cursor: move; flex: none;
  background: linear-gradient(100deg, rgba(255, 102, 0, 0.22), rgba(255, 102, 0, 0) 70%); border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
.hps-title { font-size: 17px; font-weight: 900; font-style: italic; letter-spacing: 2px; line-height: 1; }
.hps-title span { color: var(--o); margin-left: 6px; }
.hps-sub { font-size: 11px; color: var(--dim); margin-top: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hps-x { position: absolute; right: 8px; top: 8px; width: 24px; height: 24px; line-height: 24px; text-align: center; cursor: pointer; color: var(--dim); font-size: 13px; }
.hps-x2 { right: 36px; }
.hps-x:hover { color: var(--w); background: rgba(255, 102, 0, 0.3); }
.hps-tabs { display: flex; flex: none; border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
.hps-tab { flex: 1; text-align: center; padding: 6px 0; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: var(--dim); cursor: pointer; border-bottom: 2px solid transparent; }
.hps-tab:hover { color: var(--w); background: rgba(255, 102, 0, 0.12); }
.hps-tab.is-on { color: var(--w); border-bottom-color: var(--o); }
.hps-live { display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #3ddc84; margin-left: 6px; vertical-align: 1px; animation: hps-blink 1s infinite; }
@keyframes hps-blink { 50% { opacity: 0.25; } }
.hps-status { flex: none; font-size: 11px; padding: 4px 14px; height: 22px; line-height: 14px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; background: rgba(61, 220, 132, 0.15); color: #bff5d5; }
.hps-status.is-empty { background: rgba(255, 255, 255, 0.04); color: var(--dim); }
.hps-status.is-bad { background: rgba(220, 40, 40, 0.25); color: #ffc9c9; }
.hps-body { flex: 1 1 auto; min-height: 0; overflow-y: auto; overflow-x: hidden; padding: 6px 12px 10px; }
.hps-body::-webkit-scrollbar, .hps-list::-webkit-scrollbar { width: 4px; }
.hps-body::-webkit-scrollbar-thumb, .hps-list::-webkit-scrollbar-thumb { background: var(--o); }
.hps-sec { font-size: 10px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--o2); padding: 10px 0 4px; }
.hps-note { font-size: 11px; color: var(--dim); padding: 3px 0 6px; line-height: 1.45; }
.hps-sub2 { font-size: 10px; color: var(--dim); padding: 2px 0 4px; }
.hps-search { display: block; width: 100%; margin: 6px 0 3px; background: rgba(0, 0, 0, 0.4); border: 1px solid rgba(255, 255, 255, 0.12); color: var(--w); padding: 5px 7px; font-size: 12px; font-family: inherit; outline: none; user-select: text; }
.hps-search:focus { border-color: var(--o); }
.hps-chips { display: flex; flex-wrap: wrap; gap: 3px; padding: 3px 0; }
.hps-chip { padding: 3px 8px; font-size: 10px; font-weight: 700; background: rgba(255, 255, 255, 0.06); cursor: pointer; white-space: nowrap; }
.hps-chip:hover { background: rgba(255, 102, 0, 0.25); }
.hps-chip.is-on { background: rgba(255, 102, 0, 0.6); }
.hps-chip-act { margin-left: auto; background: rgba(255, 102, 0, 0.3); }

/* große Vorschau */
.hps-big { position: relative; width: 100%; height: 220px; background: #18191c; border: 1px solid rgba(255, 255, 255, 0.08); margin: 2px 0 6px; overflow: hidden; }
.hps-view { display: flex; flex-wrap: wrap; align-items: center; gap: 3px; margin: -2px 0 6px; }
.hps-view .hps-btn { padding: 4px 8px; }
.hps-ib { min-width: 26px; font-size: 13px; line-height: 13px; }
.hps-btn-o { background: rgba(255, 102, 0, 0.35); }
.hps-warn { border-left: 3px solid var(--o); padding-left: 8px; }
.hps-warn .hps-btn { display: inline-block; margin-top: 6px; }
.hps-view-l { font-size: 10px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: var(--dim); margin-right: 3px; }
.hps-view-scope { display: inline-flex; gap: 3px; margin-left: 4px; }
.hps-view-v { flex-basis: 100%; font-size: 10px; color: var(--dim); font-style: normal; }
.hps-view.is-busy { opacity: 0.45; }
.hps-tile.is-pin { outline: 1px solid rgba(255, 255, 255, 0.55); }
.hps-big img { width: 100%; height: 100%; object-fit: contain; display: block; }
.hps-big-empty { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: var(--dim); font-size: 12px; }
.hps-big-cap { position: absolute; left: 0; right: 0; bottom: 0; padding: 5px 8px; background: linear-gradient(0deg, rgba(0, 0, 0, 0.75), rgba(0, 0, 0, 0)); }
.hps-big-cap b { display: block; font-size: 13px; }
.hps-big-cap span { font-size: 10px; color: var(--dim); font-family: monospace; }

/* Slots */
.hps-slot { border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
.hps-slot-h { display: flex; align-items: center; gap: 8px; padding: 4px 2px; cursor: pointer; }
.hps-slot-h:hover { background: rgba(255, 102, 0, 0.12); }
.hps-slot.is-open > .hps-slot-h { background: rgba(255, 102, 0, 0.2); }
.hps-thumb { flex: none; width: 56px; height: 35px; background: #18191c; overflow: hidden; }
.hps-thumb img { width: 100%; height: 100%; object-fit: contain; display: block; }
.hps-slot-t { flex: 1; min-width: 0; }
.hps-slot-t b { display: block; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hps-slot-t em { display: block; font-style: normal; font-size: 10px; color: var(--dim); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hps-count { flex: none; font-size: 10px; font-weight: 800; padding: 1px 6px; background: rgba(255, 255, 255, 0.1); }

/* Kacheln */
.hps-tiles { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; padding: 6px 0 10px; }
.hps-tile { position: relative; background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.07); cursor: pointer; }
.hps-tile:hover { border-color: var(--o2); background: rgba(255, 102, 0, 0.1); }
.hps-tile.is-on { border-color: #3ddc84; cursor: default; }
.hps-tile.is-armed { border-color: var(--o); background: rgba(255, 102, 0, 0.25); }
.hps-tile-img { width: 100%; aspect-ratio: 16 / 10; background: #18191c; display: flex; align-items: center; justify-content: center; overflow: hidden; }
.hps-tile-img img { width: 100%; height: 100%; object-fit: contain; display: block; }
.hps-tile-img span { font-size: 10px; color: var(--dim); }
.hps-tile.is-noimg .hps-tile-img { background: repeating-linear-gradient(135deg, #18191c 0 8px, #1d1e22 8px 16px); }
.hps-tile-n { font-size: 10px; padding: 3px 5px 4px; line-height: 1.25; height: 30px; overflow: hidden; }
.hps-tile-tag { position: absolute; top: 3px; left: 3px; font-size: 9px; font-weight: 800; padding: 1px 5px; background: #2f8f57; text-transform: uppercase; }
.hps-tag-arm { background: var(--o); }

/* Fortschritt + Modell-Liste */
.hps-prog-bar { height: 6px; background: rgba(255, 255, 255, 0.08); margin: 2px 0 8px; }
.hps-prog-bar i { display: block; height: 100%; background: var(--o); transition: width 0.3s; }
.hps-kv { display: flex; gap: 8px; font-size: 12px; padding: 2px 0; }
.hps-kv > span { flex: 0 0 96px; color: var(--dim); font-size: 11px; }
.hps-kv > b { flex: 1; font-weight: 600; min-width: 0; }
.hps-kv > b i { font-style: normal; color: var(--dim); font-weight: 500; }
.hps-list { display: flex; flex-direction: column; gap: 2px; max-height: 38vh; overflow-y: auto; }
.hps-li { display: flex; align-items: center; gap: 8px; padding: 4px 6px; background: rgba(255, 255, 255, 0.04); cursor: pointer; }
.hps-li:hover { background: rgba(255, 102, 0, 0.14); }
.hps-li.is-sel { background: rgba(255, 102, 0, 0.3); }
.hps-box { width: 12px; height: 12px; border: 1px solid rgba(255, 255, 255, 0.4); flex: none; }
.hps-li.is-sel .hps-box { background: var(--o); border-color: var(--o); }
.hps-li-main { flex: 1; min-width: 0; }
.hps-li-main b { display: block; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hps-li-main span { display: block; font-size: 10px; color: var(--dim); }

/* Knöpfe, Einstellungen */
.hps-btns { display: flex; gap: 4px; padding: 8px 0 2px; }
.hps-btn { display: inline-block; padding: 6px 10px; font-size: 11px; font-weight: 700; background: rgba(255, 255, 255, 0.08); cursor: pointer; white-space: nowrap; text-align: center; }
.hps-btn:hover { background: rgba(255, 102, 0, 0.35); }
.hps-main { background: rgba(255, 102, 0, 0.55); }
.hps-main:hover { background: var(--o); }
.hps-off { opacity: 0.45; pointer-events: none; }
.hps-wide { flex: 1; }
.hps-row { display: flex; align-items: center; gap: 6px; padding: 3px 0; }
.hps-row > span:first-child { flex: 0 0 110px; color: var(--dim); font-size: 11px; }
.hps-row select { background: rgba(0, 0, 0, 0.4); color: var(--w); border: 1px solid rgba(255, 255, 255, 0.15); font-size: 11px; padding: 3px 5px; }
.hps-check { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--dim); cursor: pointer; padding: 4px 0; }
.hps-check i { width: 12px; height: 12px; border: 1px solid rgba(255, 255, 255, 0.4); flex: none; }
.hps-check.is-on { color: var(--w); }
.hps-check.is-on i { background: var(--o); border-color: var(--o); }
.hps-rgb { display: flex; align-items: center; gap: 6px; padding: 2px 0; font-size: 11px; }
.hps-rgb span { width: 118px; color: var(--dim); }
.hps-rgb input { flex: 1; min-width: 0; accent-color: var(--o); }
.hps-rgb em { width: 44px; text-align: right; font-style: normal; color: var(--dim); }
</style>
