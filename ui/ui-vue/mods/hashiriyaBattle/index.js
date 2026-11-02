// Hashiriya Battle: Eintrag im BeamNG-Hauptmenü (Seite "Mehr ...") mit eigenem Logo.
// Der Hauptmenü-Knopf nimmt ein eigenes Bild, wenn er im "Angular-Stil" angemeldet wird
// (translateid + icon), so macht es z. B. auch die Mod Actual Racing. targetState darf dabei
// eine Funktion sein (BeamNG reicht sie unverändert an runAction weiter).
import { useBridge } from "@/bridge"

const { events } = useBridge()

const ICON = "/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png"

export function startCareer() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end")
}

function addButton(add) {
  add({ translateid: "Hashiriya Battle", icon: ICON, targetState: startCareer })
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
  events.on("HashiriyaMusic", onMusic)
  events.on("HashiriyaMusicVolume", onMusicVolume)
  window.bngApi.engineLua("if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.playerReady() end")
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
  events.off("HashiriyaMusic", onMusic)
  events.off("HashiriyaMusicVolume", onMusicVolume)
  fadeOutAndStop(music.audio, 0.2)
  music.audio = null
  music.context = null
}

// Musik-Player ---------------------------------------------------------------------------------
// Läuft hier, weil diese Datei die ganze Zeit geladen bleibt (auch wenn das Layout wechselt).
// Lua (music.lua) schickt "HashiriyaMusic" mit Situation, Playlist und Lautstärke; hier wird nur
// abgespielt und übergeblendet. intro = einmal vorweg, danach tracks reihum (ein Stück = Schleife).
const music = { context: null, list: [], idx: 0, audio: null, volume: 0.6, fade: 2, timer: null }

function rampVolume(audio, from, to, seconds, done) {
  const steps = Math.max(1, Math.round(seconds * 20))
  let i = 0
  audio.volume = Math.max(0, Math.min(1, from))
  const id = setInterval(() => {
    i++
    audio.volume = Math.max(0, Math.min(1, from + (to - from) * (i / steps)))
    if (i >= steps) { clearInterval(id); if (done) done() }
  }, 50)
  return id
}

function fadeOutAndStop(audio, seconds) {
  if (!audio) return
  audio.onended = null
  audio.onerror = null
  rampVolume(audio, audio.volume, 0, seconds, () => { audio.pause(); audio.removeAttribute("src"); audio.load() })
}

function playFile(url, loop, fadeIn) {
  const a = new Audio(url)
  a.loop = !!loop
  a.volume = 0
  a.onended = () => { if (music.audio === a) nextTrack() }
  a.onerror = () => {
    window.bngApi.engineLua("log('W', 'hashiriya.music', " + JSON.stringify("Musik konnte nicht abgespielt werden: " + url) + ")")
    if (music.audio === a) setTimeout(nextTrack, 500)
  }
  const p = a.play()
  if (p && p.catch) p.catch(() => {})
  rampVolume(a, 0, music.volume, fadeIn)
  music.audio = a
}

function nextTrack() {
  if (!music.list.length) return
  const url = music.list[music.idx % music.list.length]
  music.idx++
  playFile(url, music.list.length === 1, 0.3)
}

function onMusic(data) {
  if (!data) return
  music.volume = typeof data.volume === "number" ? data.volume : music.volume
  music.fade = typeof data.fade === "number" ? data.fade : 2
  if (data.context === music.context && music.audio) { music.audio.volume = music.volume; return }
  music.context = data.context
  fadeOutAndStop(music.audio, music.fade)
  music.audio = null
  music.list = data.tracks || []
  music.idx = 0
  if (data.context === "off") return
  if (data.intro) playFile(data.intro, false, music.fade)
  else if (music.list.length) {
    music.idx = 1
    playFile(music.list[0], music.list.length === 1, music.fade)
  }
}

function onMusicVolume(data) {
  if (!data || typeof data.volume !== "number") return
  music.volume = data.volume
  if (music.audio) music.audio.volume = Math.max(0, Math.min(1, music.volume))
}

