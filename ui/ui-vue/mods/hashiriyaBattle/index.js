// Hashiriya Battle: Eintrag im BeamNG-Hauptmenü (Seite "Mehr ...") mit eigenem Logo.
// Der Hauptmenü-Knopf nimmt ein eigenes Bild, wenn er im "Angular-Stil" angemeldet wird
// (translateid + icon), so macht es z. B. auch die Mod Actual Racing. targetState darf dabei
// eine Funktion sein (BeamNG reicht sie unverändert an runAction weiter).
// Dazu (nur Entwickler-Build): "Gegner-Garage (Dev)" startet die eigene Dev-Garage (garagetool.lua).
// Im Release fehlt garagetool.lua, dann wird der Eintrag nicht angezeigt.
import { useBridge } from "@/bridge"

const { events } = useBridge()

const ICON = "/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png"

export function startCareer() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end")
}

let devGarage = false

function checkDevGarage() {
  window.bngApi.engineLua(
    "extensions.hashiriyaBattle_garagetool ~= nil and extensions.hashiriyaBattle_garagetool.isAllowed() == true",
    v => { devGarage = v === true }
  )
}

export function startDevGarage() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.start() end")
}

function addButton(add) {
  add({ translateid: "Hashiriya Battle", icon: ICON, targetState: startCareer })
  if (devGarage) add({ translateid: "Gegner-Garage (Dev)", icon: ICON, targetState: startDevGarage })
  checkDevGarage()
}

export function onLoad() {
  checkDevGarage()
  setTimeout(checkDevGarage, 3000) // falls Lua beim UI-Start noch nicht fertig war
  events.on("MainMenuButtons", addButton)
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
}
