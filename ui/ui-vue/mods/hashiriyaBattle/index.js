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
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
}
