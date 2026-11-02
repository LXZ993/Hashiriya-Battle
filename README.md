# Hashiriya Battle (走り屋バトル)

Ein Karriere-Mod für BeamNG.drive im Stil der Tokyo-Xtreme-Racer-Reihe: Rivalen im Verkehr per Lichthupe herausfordern, SP-Battles fahren, Geld (Yen) verdienen, Autos tunen.

**Stand: Prototyp 0.1.** Enthalten sind Start-Menü, Wahl eines Startautos, Rivalen, die im Verkehr auftauchen, Herausforderung per Lichthupe, SP-Battle mit Anzeige, Belohnung in Yen und Spielstand. Noch nicht enthalten: Parkplätze als Hauptquartier, Shops, Tuning, B.A.D.-System.

## Voraussetzungen

- BeamNG.drive (aktuelle Version)
- Map [Tokyo's Shuto Expressway (C1)](https://www.beamng.com/threads/tokyos-shuto-expressway-metropolitan-expressway.61259/)
- Empfohlen: [Agent's Simplified Realistic Traffic Mod](https://www.beamng.com/threads/agents-simplified-realistic-traffic-mod-eu-jp-released.102034/) mit der Japan-Gruppe

## Installieren (zum Testen)

1. Oben auf GitHub **Code → Download ZIP** klicken.
2. ZIP entpacken. Darin liegt ein Ordner wie `Hashiriya-Battle-main`.
3. Diesen Ordner kopieren nach
   `%LOCALAPPDATA%\BeamNG.drive\<Version>\mods\unpacked\`
   (bei älteren Versionen `Dokumente\BeamNG.drive\mods\unpacked\`). Den Ordner `unpacked` ggf. anlegen.
   Richtig ist es, wenn danach z. B. `mods\unpacked\Hashiriya-Battle-main\scripts\hashiriya_battle\modScript.lua` existiert.
4. BeamNG starten und im Mod-Manager prüfen, dass der Mod aktiv ist.

Bei einem Update einfach den Ordner ersetzen.

## Testen

1. Freeroam auf der C1-Map starten, Verkehr einschalten.
2. Beim Laden der Map schaltet der Mod auf das HUD-Layout **Hashiriya Battle**. Links erscheint das Menü → **Neues Spiel** → Startauto wählen. Mit der Taste **Pos1** blendest du das Menü ein und aus (änderbar unter Optionen → Steuerung → „Hashiriya Battle: Menü ein/aus“).
   Die Apps (Menü, SP-Anzeige, Status) findest du auch im App-Editor unter der Kategorie „Hashiriya Battle“ und kannst sie dort verschieben.
3. Auf den Highway fahren und mindestens 60 km/h fahren. Nach einer Weile erscheint „Rivale gesichtet“, das Auto taucht rund 160 m vor dir auf. Zum schnellen Testen gibt es den Knopf **Rivale rufen (Test)**.
4. Hinter den Rivalen fahren (unter 45 m, gleiche Spur) und kurz das **Fernlicht** einschalten (Lichthupe).
5. Der Rivale schaltet den Warnblinker ein, nach 3 Sekunden startet das Battle. Wer hinten liegt, verliert SP. Unfälle kosten zusätzlich SP. Bei 0 SP oder 250 m Abstand ist das Battle vorbei.

Falls die Taste nicht reagiert, geht es auch über die Konsole (Taste `^`, Modus „GE – Lua“):
`extensions.hashiriyaBattle_core.toggleMenu()`

### Bitte zurückmelden

- Startet der Mod, erscheint das Menü im HUD?
- Taucht der Rivale auf der richtigen Fahrbahn und in Fahrtrichtung auf?
- Wird die Lichthupe erkannt?
- Wie fährt die Gegner-KI im Battle (zu langsam, crasht, biegt ab)?
- Fehlermeldungen aus der Konsole (alles mit `hashiriya` oder rot markiert).

### Positionen sammeln

Im **Dev-Menü** (Umschalt+Ende), Reiter **Orte**, merkst du die aktuelle Position mit Name und Typ.
Gespeichert wird in `<BeamNG-Benutzerordner>\settings\hashiriya_battle\dev_places.json`; von dort kommen
Parkplätze, Shops, Tankstellen und Spawnpunkte in die Map-Datei. Die Liste zeigt alle Orte und teleportiert hin.

## Aufbau

| Pfad | Inhalt |
| --- | --- |
| `scripts/hashiriya_battle/modScript.lua` | Lädt den Mod beim Start |
| `lua/ge/extensions/hashiriyaBattle/core.lua` | Spielstand, Menüs, Belohnungen |
| `lua/ge/extensions/hashiriyaBattle/rivals.lua` | Rivalen auswählen, spawnen, im Verkehr fahren lassen |
| `lua/ge/extensions/hashiriyaBattle/battle.lua` | Lichthupe, Countdown, SP-Berechnung, Anzeige |
| `lua/ge/extensions/hashiriyaBattle/economy.lua` | Yen-Umrechnung und Preisformat |
| `lua/ge/extensions/hashiriyaBattle/data/` | Startautos, Rivalen, Map-Daten (JSON) |
| `ui/modules/apps/Hashiriya*` | UI-Apps: Menü, SP-Anzeige, Status |
| `settings/ui_apps/originalLayouts/default/hashiriyaBattle.uilayout.json` | HUD-Layout für den Modus |

Werte wie SP-Verlust, Abstände und Umrechnungskurs stehen oben in `battle.lua` bzw. `economy.lua` und lassen sich ohne weitere Programmierung anpassen.
