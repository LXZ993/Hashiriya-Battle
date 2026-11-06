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

function onData(d) {
  if (d && typeof d.active === "boolean") {
    luaActive = d.active
    update()
  }
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
  events.on("HashiriyaPartStudio", onData)
  if (window.vueRouter && window.vueRouter.afterEach) removeRouteHook = window.vueRouter.afterEach(() => update())
  // nach einem UI-Neuladen (F5) den Zustand neu holen
  lua("if extensions.hashiriyaPartStudio then extensions.hashiriyaPartStudio.requestState() end")
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
  events.off("HashiriyaPartStudio", onData)
  if (removeRouteHook) { removeRouteHook(); removeRouteHook = null }
  unmountPanel()
}
