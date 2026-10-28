// Hashiriya Battle: Eintrag im BeamNG-Hauptmenü (Seite "Mehr ...").
// Der große Banner auf der ersten Seite kommt aus MainMenuBanner.vue (Slot mainmenu.top).
import { useBridge } from "@/bridge"

const { events } = useBridge()

export function startCareer() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end")
}

function addButton(add) {
  add({ title: "Hashiriya Battle", iconId: "flag", action: startCareer })
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
}
