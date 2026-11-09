// Hashiriya Part Studio (eigenständige Mod): Eintrag "Teile-Studio" im BeamNG-Hauptmenü unter "Mehr ..."
// und das Studio-Fenster (StudioPanel.vue) als eigene kleine Vue-App direkt unter <body>.
// Das Fenster erscheint, solange Lua "HashiriyaPartStudio" { active = true } meldet, und nicht in Vollbild-Menüs.
// Lua-Seite: lua/ge/extensions/hashiriyaPartStudio.lua
import { createApp } from "vue"
import { useBridge } from "@/bridge"

const { events } = useBridge()

const ICON = "/ui/ui-vue/mods/hashiriyaPartStudio/icon.png"
const PANEL = "/ui/ui-vue/mods/hashiriyaPartStudio/StudioPanel.vue"

const lua = code => window.bngApi.engineLua(code)

function openStudio() {
  lua("if extensions.hashiriyaPartStudio then extensions.hashiriyaPartStudio.open() end")
}

function addButton(add) {
  add({ translateid: "Teile-Studio", icon: ICON, targetState: openStudio })
}

let luaActive = false
let host = null
let app = null
let mounting = false
let removeRouteHook = null

function routeName() {
  const r = window.vueRouter && window.vueRouter.currentRoute
  const v = r && (r.value || r)
  return (v && v.name) || ""
}

// Im Hauptmenü, in den Optionen, im Fahrzeug-Auswahlmenü usw. ausblenden; im Spiel und in der Garage zeigen
function routeOk() {
  const n = String(routeName())
  if (!n) return true
  return !/menu|loading|photo|mainmenu|vehicleSelect|vehicle-select|options|mirrors|livery/i.test(n)
}

async function mountPanel() {
  if (app || mounting) return
  mounting = true
  try {
    const rt = window.__bngRuntime
    if (!rt || typeof rt.loadModule !== "function") throw new Error("window.__bngRuntime fehlt")
    const ns = await rt.loadModule(PANEL)
    const comp = ns && ns.default
    if (!comp) throw new Error("StudioPanel.vue ohne default export")
    if (!(luaActive && routeOk())) return
    host = document.createElement("div")
    host.id = "hashiriya-part-studio-host"
    document.body.appendChild(host)
    app = createApp(comp)
    app.mount(host)
  } catch (err) {
    console.error("[Teile-Studio] Panel:", err)
    lua("log('E', 'partStudio', " + JSON.stringify("Panel nicht geladen: " + String((err && (err.stack || err.message)) || err)) + ")")
  } finally {
    mounting = false
  }
}

function unmountPanel() {
  if (app) {
    try { app.unmount() } catch (e) {}
    app = null
  }
  if (host) {
    if (host.parentNode) host.parentNode.removeChild(host)
    host = null
  }
}

function update() {
  if (luaActive && routeOk()) mountPanel()
  else unmountPanel()
}

// --- Bilder in der BeamNG-Teileauswahl (Fahrzeugkonfigurator) ----------------------------------------
// Die Teile-Liste ist ein BngDropdown: jede Zeile ist ein div.dropdown-option mit dem Anzeigenamen des Teils.
// Lua (requestPartMap) schickt, welche Teile des eigenen Autos ein Bild haben und welcher Anzeigename zu
// welchem Teil gehört. Hier bekommt jede passende Zeile ein kleines Bild, und beim Drüberfahren erscheint
// das Bild groß neben der Liste. Am Konfigurator selbst wird nichts verändert.
let partMap = { enabled: false, labels: {}, images: {} }
let observer = null
let preview = null
let styleEl = null

const CSS = `
.dropdown-option .hps-cfg-thumb { flex: none; width: 48px; height: 30px; object-fit: cover; border-radius: 2px;
  background: #18191c; margin: -2px 0; }
#hps-cfg-preview { position: fixed; z-index: 100000; pointer-events: none; width: 320px;
  background: rgba(14, 14, 16, 0.96); border: 1px solid rgba(255, 102, 0, 0.6); border-radius: 4px;
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.5); overflow: hidden; display: none; }
#hps-cfg-preview img { display: block; width: 320px; height: 200px; object-fit: cover; }
#hps-cfg-preview div { padding: 5px 8px; font-size: 12px; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
`

function partOf(el) {
  const key = el.__vnode && el.__vnode.key
  if (typeof key === "string" && partMap.images[key]) return key
  const lab = el.querySelector(".dropdown-option-label")
  const text = String((lab ? lab.textContent : el.textContent) || "").trim().replace(/^\[!\]\s*/, "")
  if (partMap.images[text]) return text
  return partMap.labels[text] || null
}

function showPreview(el, part) {
  if (!preview) {
    preview = document.createElement("div")
    preview.id = "hps-cfg-preview"
    preview.innerHTML = "<img><div></div>"
    document.body.appendChild(preview)
  }
  preview.querySelector("img").src = partMap.images[part]
  const lab = el.querySelector(".dropdown-option-label")
  preview.querySelector("div").textContent = String((lab ? lab.textContent : el.textContent) || "").trim()
  // neben die aufgeklappte Liste, links wenn dort Platz ist, sonst rechts
  const box = (el.closest("[class*='popover'], .bng-popover") || el).getBoundingClientRect()
  const r = el.getBoundingClientRect()
  const w = 322, h = 230
  let x = box.left - w - 8
  if (x < 4) x = Math.min(window.innerWidth - w - 4, box.right + 8)
  let y = Math.max(4, Math.min(window.innerHeight - h - 4, r.top + r.height / 2 - h / 2))
  preview.style.left = x + "px"
  preview.style.top = y + "px"
  preview.style.display = "block"
}

function hidePreview() {
  if (preview) preview.style.display = "none"
}

function decorate(el) {
  if (el.dataset.hpsPart) return
  const part = partOf(el)
  if (!part) return
  el.dataset.hpsPart = part
  const img = document.createElement("img")
  img.className = "hps-cfg-thumb"
  img.src = partMap.images[part]
  img.onerror = () => img.remove()
  el.insertBefore(img, el.firstChild)
  el.addEventListener("mouseenter", () => showPreview(el, part))
  el.addEventListener("focusin", () => showPreview(el, part))
  el.addEventListener("mouseleave", hidePreview)
  el.addEventListener("focusout", hidePreview)
}

function undecorateAll() {
  hidePreview()
  document.querySelectorAll(".dropdown-option .hps-cfg-thumb").forEach(n => n.remove())
  document.querySelectorAll(".dropdown-option[data-hps-part]").forEach(n => { delete n.dataset.hpsPart })
}

function decorateAll() {
  if (!partMap.enabled) return
  document.querySelectorAll(".dropdown-option").forEach(decorate)
}

function onMap(d) {
  if (!d) return
  partMap = { enabled: d.enabled !== false, labels: d.labels || {}, images: d.images || {} }
  undecorateAll()
  decorateAll()
}

function startConfigThumbs() {
  if (!styleEl) {
    styleEl = document.createElement("style")
    styleEl.id = "hps-cfg-style"
    styleEl.textContent = CSS
    document.head.appendChild(styleEl)
  }
  if (!observer) {
    let queued = false
    observer = new MutationObserver(() => {
      if (queued) return
      queued = true
      requestAnimationFrame(() => {
        queued = false
        decorateAll()
        if (!document.querySelector(".dropdown-option")) hidePreview()
      })
    })
    observer.observe(document.body, { childList: true, subtree: true })
  }
}

function stopConfigThumbs() {
  if (observer) { observer.disconnect(); observer = null }
  undecorateAll()
  if (preview && preview.parentNode) preview.parentNode.removeChild(preview)
  preview = null
  if (styleEl && styleEl.parentNode) styleEl.parentNode.removeChild(styleEl)
  styleEl = null
}

function onData(d) {
  if (d && typeof d.active === "boolean") {
    luaActive = d.active
    update()
  }
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
  events.on("HashiriyaPartStudio", onData)
  events.on("HashiriyaPartStudioMap", onMap)
  startConfigThumbs()
  if (window.vueRouter && window.vueRouter.afterEach) removeRouteHook = window.vueRouter.afterEach(() => update())
  // nach einem UI-Neuladen (F5) den Zustand neu holen
  lua("if extensions.hashiriyaPartStudio then extensions.hashiriyaPartStudio.requestState(); extensions.hashiriyaPartStudio.requestPartMap() end")
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
  events.off("HashiriyaPartStudio", onData)
  events.off("HashiriyaPartStudioMap", onMap)
  stopConfigThumbs()
  if (removeRouteHook) { removeRouteHook(); removeRouteHook = null }
  unmountPanel()
}
