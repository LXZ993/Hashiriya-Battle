<!-- Hashiriya Battle: Banner auf der ersten Seite des BeamNG-Hauptmenüs (über dem Logo). Klick startet den Karrieremodus. -->
<template>
  <div class="hb-banner" :style="{ backgroundImage: `url(${bannerUrl})` }" tabindex="0"
    @click="start" @keydown.enter="start">
    <img class="hb-badge" :src="iconUrl" alt="" />
  </div>
</template>

<script>
const modInfo = {
  uiSlots: ["mainmenu.top"],
}
</script>

<script setup>
import bannerUrl from "./assets/banner.jpg"
import iconUrl from "./assets/icon.png"

function start() {
  window.bngApi.engineLua("if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end")
}
</script>

<style scoped lang="scss">
.hb-banner {
  position: relative;
  width: 26em;
  max-width: 90vw;
  aspect-ratio: 1200 / 375;
  margin: 0 auto 0.75em;
  border-radius: 0.5em;
  background-size: cover;
  background-position: center;
  box-shadow: 0 0.25em 1em rgba(0, 0, 0, 0.5);
  outline: 2px solid transparent;
  cursor: pointer;
  filter: brightness(0.85);
  transition: filter 0.15s, outline-color 0.15s, transform 0.15s;

  &:hover,
  &:focus {
    filter: brightness(1);
    outline-color: #ff6600;
    transform: scale(1.02);
  }
}

.hb-badge {
  position: absolute;
  right: 0.5em;
  bottom: 0.5em;
  width: 2.25em;
  height: 2.25em;
}
</style>
