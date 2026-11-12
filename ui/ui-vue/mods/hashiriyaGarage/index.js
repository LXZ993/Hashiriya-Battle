// Hashiriya Battle: Gegner-Garage (Entwickler-Werkzeug, NICHT im Release: der ganze Ordner fehlt im Release-Zip).
//
// 1. Eintrag "Gegner-Garage (Dev)" im BeamNG-Hauptmenü unter More (neben Hashiriya Battle).
//    Er startet die ganz normale BeamNG-Garage (gameplay_garageMode.start(), wie More > Garage),
//    Lua-Seite: lua/ge/extensions/hashiriyaBattle/garagetool.lua.
// 2. Das Panel GaragePanel.vue liegt als eigene kleine Vue-App direkt unter <body>, über der Garage-Oberfläche.
//    So bleibt die Original-Garage unverändert (keine Datei ersetzt, kein Layout umgeschaltet), und das Panel
//    ist trotzdem klickbar. Es erscheint nur, solange Lua "HashiriyaGarageState" { active = true } meldet
//    (Garage über unseren Eintrag gestartet) und die Garage nicht gerade Vollbild-Menüs zeigt
//    (Fotomodus, Fahrzeugauswahl, Spiegel, Livery-Editor).
import { createApp } from "vue"
import { useBridge } from "@/bridge"

const { events } = useBridge()

const ICON = "/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png"
const PANEL = "/ui/ui-vue/mods/hashiriyaGarage/GaragePanel.vue"
// Garage-Ansichten, in denen das Panel Platz hat (Hauptansicht und die Seitenmenüs Teile/Tuning/Lack/Speichern)
const PANEL_ROUTES = ["garage", "garage.vehicle.parts", "garage.vehicle.tuning", "garage.vehicle.paint", "garage.vehicle.save"]

const lua = code => window.bngApi.engineLua(code)

function startDevGarage() {
  lua("if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.start() end")
}

function addButton(add) {
  add({ translateid: "Gegner-Garage (Dev)", icon: ICON, targetState: startDevGarage })
}

// --- Panel ein-/ausblenden --------------------------------------------------------------------------

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

function routeOk() {
  return PANEL_ROUTES.includes(routeName())
}

async function mountPanel() {
  if (app || mounting) return
  mounting = true
  try {
    const rt = window.__bngRuntime
    if (!rt || typeof rt.loadModule !== "function") throw new Error("window.__bngRuntime fehlt")
    const ns = await rt.loadModule(PANEL)
    const comp = ns && ns.default
    if (!comp) throw new Error("GaragePanel.vue ohne default export")
    if (!(luaActive && routeOk())) return // inzwischen wieder aus
    host = document.createElement("div")
    host.id = "hashiriya-garage-panel-host"
    document.body.appendChild(host)
    app = createApp(comp)
    app.mount(host)
  } catch (err) {
    console.error("[Hashiriya] Gegner-Garage-Panel:", err)
    lua("log('E', 'hashiriyaGarage', " + JSON.stringify("Panel nicht geladen: " + String(err && (err.stack || err.message) || err)) + ")")
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

function onState(d) {
  luaActive = !!(d && d.active)
  update()
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
  events.on("HashiriyaGarageState", onState)
  if (window.vueRouter && window.vueRouter.afterEach) removeRouteHook = window.vueRouter.afterEach(() => update())
  // nach einem UI-Neuladen (F5) den Zustand neu holen
  lua("if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.action('state') end")
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
  events.off("HashiriyaGarageState", onState)
  if (removeRouteHook) { removeRouteHook(); removeRouteHook = null }
  unmountPanel()
}
