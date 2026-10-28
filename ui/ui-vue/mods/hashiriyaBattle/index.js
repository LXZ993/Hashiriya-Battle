// Hashiriya Battle: Eintrag im BeamNG-Hauptmenü (Seite "Mehr ...").
// (Ein eigenes Bild geht bei diesen Knöpfen nicht, nur ein eingebautes Symbol.)
import { useBridge } from "@/bridge"

const { events } = useBridge()

export function startCareer() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end")
}

function addButton(add) {
  add({ title: "Hashiriya Battle", iconId: "raceFlag", action: startCareer })
}

export function onLoad() {
  events.on("MainMenuButtons", addButton)
}

export function onUnload() {
  events.off("MainMenuButtons", addButton)
}
