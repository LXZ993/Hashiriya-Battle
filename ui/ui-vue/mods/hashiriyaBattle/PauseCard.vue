<template>
  <div class="hb-pause">
    <div class="hb-head">
      <img class="hb-logo" src="/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png" alt="" />
      <div>
        <div class="hb-name">Hashiriya Battle</div>
        <div class="hb-title">{{ tab === 'keys' ? tx('keys.pauseTitle', 'Tasten') : tx('pause.title') }}</div>
      </div>
    </div>
    <div class="hb-tabs">
      <button :class="{ 'is-sel': tab === 'keys' }" @click="setTab('keys')">{{ tx('pause.tab.keys', 'Tasten') }}</button>
      <button :class="{ 'is-sel': tab === 'music' }" @click="setTab('music')">{{ tx('pause.tab.music', 'Musik') }}</button>
    </div>

    <template v-if="tab === 'keys'">
      <p class="hb-sub">{{ tx('keys.pauseSub') }}</p>
      <div v-if="!keys" class="hb-sub">…</div>
      <template v-else>
        <template v-for="g in keyGroups" :key="g">
          <div class="hb-label">{{ tx('keys.group.' + g) }}</div>
          <div class="hb-list">
            <div v-for="k in keysOf(g)" :key="k.id" class="hb-key"
              :class="{ 'is-missing': !k.keys && k.need, 'is-free': !k.keys && !k.need }">
              <span class="hb-key-main">
                <span class="hb-song-title">{{ tx('keys.' + k.id) }}</span>
                <small>{{ tx('keys.' + k.id + '.d') }}</small>
              </span>
              <span class="hb-kbd" :title="k.keys">{{ k.keys || tx('keys.unbound') }}</span>
              <button class="hb-btn hb-ghost" @click="bind(k)">{{ tx('keys.bind') }}</button>
            </div>
          </div>
        </template>
        <p class="hb-note hb-warn" v-if="keys.missing > 0">{{ tx('keys.missing') }}</p>
        <p class="hb-note" v-else>{{ tx('keys.allOk') }}</p>
        <p class="hb-note">{{ tx('keys.pauseHint') }}</p>
        <div class="hb-foot">
          <button class="hb-btn" @click="bind(null)">{{ tx('keys.open') }}</button>
        </div>
      </template>
    </template>

    <template v-if="tab === 'music'">
    <p class="hb-sub">{{ tx('pause.sub') }}</p>
    <div v-if="!data" class="hb-sub">…</div>
    <template v-else>
      <div class="hb-now" v-if="data.now">
        <span class="hb-label">{{ tx('pause.now') }}</span>
        <span class="hb-now-title">{{ data.now.title }}<small v-if="data.now.artist"> – {{ data.now.artist }}</small></span>
        <button class="hb-btn" @click="call('skipAndSend()')">{{ tx('pause.skip') }} ▸</button>
      </div>

      <div class="hb-label">{{ tx('pause.situation') }}</div>
      <div class="hb-sits">
        <button v-for="s in data.sits" :key="s.id" class="hb-chip"
          :class="{ 'is-sel': s.id === sel, 'is-now': s.id === data.current, 'is-off': s.mode === 'off' }"
          @click="sel = s.id">
          {{ s.name }}<span class="hb-count">{{ countFor(s.id) }}</span>
          <span v-if="s.id === data.current" class="hb-dot" :title="tx('pause.current')"></span>
        </button>
      </div>

      <div class="hb-bar" v-if="selSit">
        <span class="hb-label">{{ tx('pause.source') }}</span>
        <div class="hb-seg">
          <button v-for="m in modes" :key="m" :class="{ 'is-sel': selSit.mode === m }"
            @click="call('setSource(' + q(selSit.id) + ',' + q(m) + ')')">{{ tx('music.mode.' + m) }}</button>
        </div>
        <span class="hb-spacer"></span>
        <button class="hb-btn hb-ghost" @click="call('setAllFor(' + q(sel) + ',true)')">{{ tx('pause.all') }}</button>
        <button class="hb-btn hb-ghost" @click="call('setAllFor(' + q(sel) + ',false)')">{{ tx('pause.none') }}</button>
      </div>
      <div class="hb-bar" v-if="selSit">
        <span class="hb-label">{{ tx('pause.order') }}</span>
        <div class="hb-seg">
          <button :class="{ 'is-sel': selSit.order === 'shuffle' }" @click="call('setOrder(' + q(sel) + ',' + q('shuffle') + ')')">{{ tx('pause.shuffle') }}</button>
          <button :class="{ 'is-sel': selSit.order === 'list' }" @click="call('setOrder(' + q(sel) + ',' + q('list') + ')')">{{ tx('pause.list') }}</button>
        </div>
      </div>
      <p class="hb-note" v-if="selSit && selSit.order === 'list'">{{ tx('pause.listHint') }}</p>
      <p class="hb-note" v-if="selSit && selSit.fallback && countFor(sel) === 0">
        {{ selSit.fallback === 'daynight' ? tx('pause.fallbackDayNight') : tx('pause.fallbackBattle') }}
      </p>

      <div class="hb-list">
        <div v-for="song in shownSongs" :key="song.id" class="hb-song"
          :class="{ 'is-on': isOn(song, sel), 'is-playing': song.playing, 'is-bad': song.bad }"
          @click="toggle(song)">
          <span class="hb-check">{{ isOn(song, sel) ? '✓' : '' }}</span>
          <span class="hb-pos" v-if="isList && isOn(song, sel)">{{ posOf(song) }}</span>
          <span class="hb-song-main">
            <span class="hb-song-title">
              {{ song.title }}
              <em v-if="song.own" class="hb-tag hb-own">{{ tx('pause.own') }}</em>
              <em v-if="song.ai" class="hb-tag hb-ai">{{ tx('pause.ai') }}</em>
              <em v-if="song.custom" class="hb-tag">{{ tx('pause.custom') }}</em>
              <em v-if="song.playing" class="hb-tag hb-play">♪</em>
            </span>
            <small v-if="song.artist || others(song).length">
              <template v-if="song.artist">{{ song.artist }}</template>
              <template v-if="song.artist && others(song).length"> · </template>
              <template v-if="others(song).length">{{ tx('pause.alsoIn') }}: {{ others(song).join(', ') }}</template>
            </small>
          </span>
          <span class="hb-move" v-if="isList && isOn(song, sel)">
            <button :disabled="posOf(song) === 1" @click.stop="move(song, -1)">▲</button>
            <button :disabled="posOf(song) === selSit.sorted.length" @click.stop="move(song, 1)">▼</button>
          </span>
        </div>
        <p class="hb-note" v-if="!data.songs.length">{{ tx('pause.empty') }}</p>
      </div>

      <p class="hb-note">{{ tx('pause.hint') }}</p>
      <p class="hb-note hb-path">{{ tx('music.folder') }}: {{ data.folder }}</p>
      <div class="hb-foot">
        <button class="hb-btn" @click="call('openFolder()')">{{ tx('music.openFolder') }}</button>
        <button class="hb-btn" @click="call('rescan()')">{{ tx('music.rescan') }}</button>
        <span class="hb-spacer"></span>
        <button class="hb-btn hb-ghost" @click="call('resetAssign()')">{{ tx('pause.reset') }}</button>
      </div>
    </template>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue"
import { useBridge } from "@/bridge"

const { api, events } = useBridge()
const data = ref(null)
const sel = ref(null)
const modes = ["both", "mod", "own", "off"]

const q = v => JSON.stringify(String(v))
const keys = ref(null)
const tx = (k, fb) => (keys.value && keys.value.t && keys.value.t[k]) || (data.value && data.value.t && data.value.t[k]) || fb || k

// Reiter Tasten / Musik, der zuletzt offene bleibt gemerkt
const TAB_KEY = "hashiriyaPauseTab"
function readTab() {
  try { const v = window.localStorage.getItem(TAB_KEY); if (v === "keys" || v === "music") return v } catch (e) {}
  return "keys"
}
const tab = ref(readTab())
function setTab(t) {
  tab.value = t
  try { window.localStorage.setItem(TAB_KEY, t) } catch (e) {}
  if (t === "keys") askKeys()
}

function askKeys() {
  api.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.sendKeys() end")
}
const keyGroups = computed(() => {
  if (!keys.value) return []
  return arr(keys.value.groups).filter(g => keysOf(g).length > 0)
})
function keysOf(g) { return keys.value ? keys.value.keys.filter(k => k.group === g) : [] }
// öffnet den BeamNG-Dialog "Taste belegen" für diese Aktion (ohne Aktion: die ganze Steuerung)
function bind(k) {
  const arg = k ? JSON.stringify(String(k.id)) : "nil"
  api.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.openControls(" + arg + ") end")
}
function onKeys(d) {
  if (!d) return
  d.keys = arr(d.keys)
  keys.value = d
}
let keyTimer = null

function call(fn) {
  api.engineLua("if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music." + fn + " end")
}

const selSit = computed(() => data.value && data.value.sits.find(s => s.id === sel.value))
const sitName = computed(() => {
  const m = {}
  if (data.value) data.value.sits.forEach(s => { m[s.id] = s.name })
  return m
})

const isList = computed(() => !!(selSit.value && selSit.value.order === "list"))
function posOf(song) { return selSit.value ? selSit.value.sorted.indexOf(song.id) + 1 : 0 }
// feste Reihenfolge: angeschaltete Songs in ihrer Reihenfolge oben, der Rest darunter
const shownSongs = computed(() => {
  if (!data.value) return []
  if (!isList.value) return data.value.songs
  const pos = {}
  selSit.value.sorted.forEach((id, i) => { pos[id] = i })
  const on = data.value.songs.filter(s => pos[s.id] !== undefined).sort((a, b) => pos[a.id] - pos[b.id])
  const off = data.value.songs.filter(s => pos[s.id] === undefined)
  return on.concat(off)
})
function move(song, dir) {
  const list = selSit.value.sorted
  const i = list.indexOf(song.id), j = i + dir
  if (i < 0 || j < 0 || j >= list.length) return
  list[i] = list[j]; list[j] = song.id // sofort anzeigen
  call("moveSong(" + q(sel.value) + "," + q(song.id) + "," + dir + ")")
}

function isOn(song, id) { return song.on.indexOf(id) >= 0 }
function countFor(id) { return data.value ? data.value.songs.filter(s => isOn(s, id)).length : 0 }
function others(song) { return song.on.filter(id => id !== sel.value).map(id => sitName.value[id] || id) }

function toggle(song) {
  const on = !isOn(song, sel.value)
  // sofort anzeigen, Lua schickt danach den echten Stand
  if (on) song.on.push(sel.value)
  else song.on = song.on.filter(id => id !== sel.value)
  call("setAssign(" + q(song.id) + "," + q(sel.value) + "," + (on ? "true" : "false") + ")")
}

// leere Lua-Tabellen kommen als {} statt [] an
const arr = v => (Array.isArray(v) ? v : (v && typeof v === "object" ? Object.values(v) : []))

function onMatrix(d) {
  if (!d) return
  d.sits = arr(d.sits).map(s => Object.assign(s, { sorted: arr(s.sorted) }))
  d.songs = arr(d.songs).map(s => Object.assign(s, { on: arr(s.on) }))
  data.value = d
  if (!sel.value || !d.sits.find(s => s.id === sel.value)) {
    sel.value = d.sits.find(s => s.id === d.current) ? d.current : (d.sits[0] && d.sits[0].id)
  }
}

onMounted(() => {
  events.on("HashiriyaMusicMatrix", onMatrix)
  events.on("HashiriyaKeys", onKeys)
  call("sendMatrix()")
  askKeys()
  // Belegung neu holen, solange der Reiter offen ist (z. B. nach Rückkehr aus der Steuerung)
  keyTimer = setInterval(() => { if (tab.value === "keys") askKeys() }, 2000)
})
onUnmounted(() => {
  events.off("HashiriyaMusicMatrix", onMatrix)
  events.off("HashiriyaKeys", onKeys)
  if (keyTimer) clearInterval(keyTimer)
})
</script>

<style lang="scss" scoped>
.hb-pause {
  padding: 1.25rem 1.5rem;
  color: #f0f0f0;
  max-height: 70vh;
  overflow-y: auto;
  font-size: 0.95rem;
}
.hb-head { display: flex; align-items: center; gap: 0.75rem; }
.hb-logo { width: 3rem; height: 3rem; object-fit: contain; }
.hb-name { font-size: 0.75rem; letter-spacing: 0.12em; text-transform: uppercase; color: #ff6600; font-weight: 700; }
.hb-title { font-size: 1.35rem; font-weight: 700; }
.hb-sub { color: #b9b9b9; margin: 0.5rem 0 0.9rem; }
.hb-label { display: block; font-size: 0.7rem; letter-spacing: 0.1em; text-transform: uppercase; color: #9a9a9a; margin: 0.6rem 0 0.35rem; }
.hb-now {
  display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem 0.75rem;
  background: rgba(255, 102, 0, 0.1); border-left: 3px solid #ff6600;
  .hb-label { margin: 0; }
  .hb-now-title { flex: 1; font-weight: 600; small { color: #b9b9b9; font-weight: 400; } }
}
.hb-sits { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.hb-chip {
  position: relative; border: 1px solid rgba(255, 255, 255, 0.12); background: rgba(255, 255, 255, 0.04);
  color: #e6e6e6; padding: 0.35rem 0.65rem; border-radius: 0.2rem; cursor: pointer; font-size: 0.85rem;
  &:hover { background: rgba(255, 255, 255, 0.09); }
  &.is-sel { border-color: #ff6600; background: rgba(255, 102, 0, 0.18); color: #fff; }
  &.is-off { opacity: 0.55; }
  .hb-count { margin-left: 0.4rem; color: #ff8a3d; font-weight: 700; }
  .hb-dot { position: absolute; top: 3px; right: 3px; width: 6px; height: 6px; border-radius: 50%; background: #ff6600; }
}
.hb-bar { display: flex; align-items: center; gap: 0.5rem; margin-top: 0.8rem; flex-wrap: wrap; .hb-label { margin: 0; } }
.hb-seg {
  display: flex; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 0.2rem; overflow: hidden;
  button {
    border: 0; background: transparent; color: #cfcfcf; padding: 0.3rem 0.65rem; cursor: pointer; font-size: 0.85rem;
    &:hover { background: rgba(255, 255, 255, 0.08); }
    &.is-sel { background: #ff6600; color: #fff; font-weight: 700; }
  }
}
.hb-spacer { flex: 1; }
.hb-btn {
  border: 0; background: #ff6600; color: #fff; padding: 0.35rem 0.8rem; border-radius: 0.2rem;
  cursor: pointer; font-weight: 700; font-size: 0.85rem;
  &:hover { background: #ff7a1f; }
  &.hb-ghost { background: rgba(255, 255, 255, 0.07); color: #e6e6e6; font-weight: 600; &:hover { background: rgba(255, 255, 255, 0.14); } }
}
.hb-note { color: #9a9a9a; font-size: 0.8rem; margin: 0.5rem 0; }
.hb-warn { color: #ff9a3c; }
.hb-tabs {
  display: flex; gap: 0; margin: 0.9rem 0 0.2rem; border-bottom: 1px solid rgba(255, 255, 255, 0.12);
  button {
    border: 0; background: transparent; color: #b9b9b9; padding: 0.45rem 1rem; cursor: pointer; font-size: 0.85rem;
    font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; border-bottom: 2px solid transparent; margin-bottom: -1px;
    &:hover { color: #fff; }
    &.is-sel { color: #fff; border-bottom-color: #ff6600; }
  }
}
.hb-key {
  display: flex; align-items: center; gap: 0.75rem; padding: 0.4rem 0.6rem;
  background: rgba(255, 255, 255, 0.03); border-left: 3px solid #3fbf6f;
  &.is-missing { border-left-color: #e23b3b; background: rgba(226, 59, 59, 0.1); }
  &.is-free { border-left-color: rgba(255, 255, 255, 0.22); }
  .hb-key-main { display: flex; flex-direction: column; min-width: 0; flex: 1; }
  .hb-song-title { font-weight: 600; }
  small { color: #a8a8a8; font-size: 0.75rem; }
}
.hb-kbd {
  flex: none; min-width: 6.5rem; max-width: 10rem; text-align: center; padding: 0.2rem 0.6rem; font-weight: 800; font-size: 0.85rem;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #3fbf6f;
  border: 1px solid rgba(63, 191, 111, 0.45); border-bottom-width: 3px; border-radius: 0.25rem; background: rgba(0, 0, 0, 0.25);
  .is-missing & { color: #ff6b6b; border-color: rgba(255, 107, 107, 0.45); font-size: 0.75rem; }
  .is-free & { color: #9a9a9a; border-color: rgba(255, 255, 255, 0.18); font-size: 0.75rem; }
}
.hb-path { word-break: break-all; }
.hb-list { margin-top: 0.6rem; display: flex; flex-direction: column; gap: 2px; }
.hb-song {
  display: flex; align-items: center; gap: 0.6rem; padding: 0.4rem 0.6rem; cursor: pointer;
  background: rgba(255, 255, 255, 0.03); border-left: 3px solid transparent;
  &:hover { background: rgba(255, 255, 255, 0.08); }
  &.is-on { border-left-color: #ff6600; background: rgba(255, 102, 0, 0.08); }
  &.is-bad { opacity: 0.45; }
  .hb-check {
    width: 1.1rem; height: 1.1rem; flex: none; border: 1px solid rgba(255, 255, 255, 0.35); border-radius: 0.15rem;
    display: flex; align-items: center; justify-content: center; font-size: 0.8rem; color: #fff;
  }
  &.is-on .hb-check { background: #ff6600; border-color: #ff6600; }
  .hb-song-main { display: flex; flex-direction: column; min-width: 0; }
  .hb-song-title { font-weight: 600; }
  small { color: #a8a8a8; font-size: 0.75rem; }
}
.hb-tag {
  font-style: normal; font-size: 0.65rem; padding: 0.05rem 0.35rem; margin-left: 0.3rem; border-radius: 0.15rem;
  background: rgba(255, 255, 255, 0.1); color: #cfcfcf; vertical-align: middle; font-weight: 600;
  &.hb-own { background: rgba(80, 160, 255, 0.2); color: #9cc8ff; }
  &.hb-ai { background: rgba(190, 120, 255, 0.2); color: #d6b3ff; }
  &.hb-play { background: rgba(255, 102, 0, 0.25); color: #ffb380; }
}
.hb-pos { width: 1.4rem; flex: none; text-align: right; color: #ff8a3d; font-weight: 700; font-size: 0.8rem; }
.hb-move {
  margin-left: auto; display: flex; gap: 2px;
  button {
    border: 0; background: rgba(255, 255, 255, 0.07); color: #e6e6e6; width: 1.6rem; height: 1.4rem; cursor: pointer; font-size: 0.7rem;
    &:hover { background: #ff6600; color: #fff; }
    &:disabled { opacity: 0.25; cursor: default; background: rgba(255, 255, 255, 0.07); }
  }
}
.hb-foot { display: flex; gap: 0.5rem; align-items: center; margin-top: 0.4rem; flex-wrap: wrap; }
</style>
