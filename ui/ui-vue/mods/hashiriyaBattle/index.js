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

// Hashiriya Battle: eigenes Ladebild, nur wenn die Karriere über "Mehr ..." > Hashiriya Battle startet.
// Lua (career.lua) schickt vor dem Laden das Event HashiriyaLoadingImage { src } mit einem zufälligen Bild
// aus art/loading/ und nach dem Laden { hide = true }. Andere Maps und Modi behalten die BeamNG-Bilder.
//
// Weg 1: Bilder im BeamNG-Ladebildschirm austauschen (alles, dessen Bildpfad "/loading/" enthält).
//        Dann bleiben Fortschrittsanzeige und Tipps von BeamNG sichtbar.
// Weg 2 (falls Weg 1 nach kurzer Zeit nichts gefunden hat): eigenes Vollbild mit kleiner Ladeanzeige darüber.

const OVERLAY_ID = "hashiriya-loading-overlay"
const FALLBACK_MS = 1500   // so lange auf das BeamNG-Ladebild warten, dann eigenes Vollbild
const MAX_MS = 180000      // spätestens nach 3 Minuten alles zurücksetzen (falls das Ende-Event fehlt)

let current = null   // { src, observer, swapped, fallbackTimer, maxTimer, originals }

function isLoadingUrl(s) {
  return typeof s === "string" && /\/loading\//i.test(s) && !/\/art\/loading\//i.test(s)
}

function swapAll() {
  if (!current) return
  const src = current.src
  document.querySelectorAll("img").forEach(img => {
    const s = img.getAttribute("src") || ""
    if (isLoadingUrl(s) || isLoadingUrl(img.currentSrc)) {
      current.originals.push({ el: img, kind: "src", value: s })
      img.setAttribute("src", src)
      if (img.srcset) img.srcset = ""
      current.swapped = true
    }
  })
  document.querySelectorAll("[style*='background']").forEach(el => {
    const bg = el.style.backgroundImage || ""
    if (isLoadingUrl(bg)) {
      current.originals.push({ el, kind: "bg", value: bg })
      el.style.backgroundImage = `url("${src}")`
      current.swapped = true
    }
  })
  if (current.swapped) removeOverlay()
}

function showOverlay() {
  if (!current || current.swapped || document.getElementById(OVERLAY_ID)) return
  const o = document.createElement("div")
  o.id = OVERLAY_ID
  o.style.cssText = [
    "position:fixed", "inset:0", "z-index:2147483000", "pointer-events:none",
    "background:#05060c center / cover no-repeat", `background-image:url("${current.src}")`,
    "opacity:0", "transition:opacity .4s ease",
  ].join(";")
  const bar = document.createElement("div")
  bar.style.cssText = "position:absolute;right:48px;bottom:40px;display:flex;align-items:center;gap:12px;" +
    "font:600 15px/1 sans-serif;letter-spacing:4px;color:#ffb347;text-shadow:0 1px 4px #000"
  bar.innerHTML = '<span>LOADING</span><span style="width:120px;height:3px;background:rgba(255,255,255,.15);overflow:hidden;position:relative">' +
    '<span style="position:absolute;top:0;bottom:0;width:40%;background:#ff6a00;animation:hbLoadBar 1.2s ease-in-out infinite"></span></span>'
  const st = document.createElement("style")
  st.textContent = "@keyframes hbLoadBar{0%{left:-40%}100%{left:100%}}"
  o.appendChild(st)
  o.appendChild(bar)
  document.body.appendChild(o)
  requestAnimationFrame(() => { o.style.opacity = "1" })
}

function removeOverlay(fade) {
  const o = document.getElementById(OVERLAY_ID)
  if (!o) return
  if (fade) {
    o.style.opacity = "0"
    setTimeout(() => o.remove(), 450)
  } else o.remove()
}

function hideLoadingImage() {
  if (!current) return
  const c = current
  current = null
  if (c.observer) c.observer.disconnect()
  clearTimeout(c.fallbackTimer)
  clearTimeout(c.maxTimer)
  // Ausgetauschte Bilder zurücksetzen, damit spätere Ladebildschirme (andere Maps) wieder die BeamNG-Bilder zeigen
  c.originals.forEach(o => {
    try {
      if (o.kind === "src") o.el.setAttribute("src", o.value)
      else o.el.style.backgroundImage = o.value
    } catch (e) { /* Element schon weg */ }
  })
  removeOverlay(true)
}

function showLoadingImage(src) {
  hideLoadingImage()
  if (!src) return
  current = { src, swapped: false, originals: [] }
  let queued = false
  current.observer = new MutationObserver(() => {
    if (queued) return
    queued = true
    requestAnimationFrame(() => { queued = false; swapAll() })
  })
  current.observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ["src", "style"] })
  swapAll()
  current.fallbackTimer = setTimeout(showOverlay, FALLBACK_MS)
  current.maxTimer = setTimeout(hideLoadingImage, MAX_MS)
}

function onLoadingImage(data) {
  if (!data || data.hide) hideLoadingImage()
  else showLoadingImage(data.src)
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
  // Eigenes Ladebild beim Start der Karriere (career.lua, Ordner art/loading/)
  events.on("HashiriyaLoadingImage", onLoadingImage)
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
  events.off("HashiriyaLoadingImage", onLoadingImage)
  hideLoadingImage()
}
