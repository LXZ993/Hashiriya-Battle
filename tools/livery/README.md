# Livery-Werkzeug (Hashiriya Battle)

Backt Designs, die in Fahrzeug-Metern beschrieben sind (`designs.py`), über die 3D-Form der Karosserie auf das UV1-Skin-Layout der BeamNG-Fahrzeuge.
Nicht Teil des Spiels.

## Ablauf
1. Quell-Dateien aus dem Spiel holen (nur lesen): aus `content\vehicles\<modell>.zip` die `.dae`/`.DAE` und `*materials.json`
   nach `work\src\<modell>\vehicles\<modell>\` entpacken (Arbeitsordner änderbar mit `HB_LIVERY_WORK` / `HB_LIVERY_SRC`).
2. `pip install numpy pillow lxml trimesh` und `python fetch_fonts.py` (freie Schriften, SIL OFL).
3. Einmal je Modell die Positionskarte rechnen, z. B. `python gbuf.py work/src/van/vehicles/van/van.DAE van van 2048 2048`
   (Pessima: `pessima,pessima_aftermarket` 4096 2048; Pessima Mk2: `midsize_body`; Sunburst: `sunburst2_main`; D-Series: `pickup`).
4. `python export_mod.py [filter]` schreibt jbeam, Materialien und Texturen nach `vehicles\<modell>\`.
5. Vorschau (optional, braucht Node + Playwright, `npm i three@0.160.0` in `web\`):
   `python preview.py van ../../vehicles/van/hashiriya_liveries/hb_courier.color.png van_hb_courier`, Übersicht mit `overview.py <bild.jpg>`.

`sideview.py <modell>` zeigt eine Seitenansicht mit Maßlinien, um Positionen in `GEO` (designs.py) abzulesen.

## Lackierbare Japan-Liveries (Farbe 1/2/3)
**Aktuell (VectorCraft, 04.11.2026):** die Entwürfe liegen in `vc/`. `vc/bx_<stil>.py` zeichnet auf dem 200BX (Seite links/rechts + Draufsicht, 200 px/m) über `vcsvg.Doc`;
`vc/landmarks.py` liefert Radlauf/Gürtel/Schweller je Modell für die Übertragung. `vc/build_all.sh <modell>` macht PNG/PSD/.vectorcraft
(VectorCraft-CLI 0.19, `--hidden-objects layer`), `vc/bake_all.py [modell...]` projiziert das PNG (`vc_bake.bake_key`) und schreibt per
`export_paint.write_maps/write_defs` Texturen, jbeam und Materialien. Braucht `HB_LIVERY_WORK` (Positionskarten) und `HB_LIVERY_SRC` (Vanilla-Skins).
Der Python-Weg unten (`styles.py`) ist der ältere Stand.

Älterer Weg seit 04.11.2026, für Liveries, die man im Spiel selbst einfärbt (wie der Vanilla-Skin "Custom").
- `styles.py`: 6 Stile mit je 3 Varianten, Formen in Fahrzeug-Einheiten (u = Vorderrad 0 … Hinterrad 1, v = Schweller 0 … Fensterlinie 1),
  Maße je Modell in `GEO`, Teams/Sponsoren/Fahrer/Gangs als Listen. Welche Variante ein Modell bekommt: `variant()`.
- `paint.py`: Ebenen-Backer. Jede Ebene hat einen Schlüssel (1/2/3 = Lackfarbe, 'k' = festes Schwarz) und wird in das Schlüsselbild
  (rein Rot/Grün/Blau/Schwarz) gemischt. Daraus entstehen `<id>_p.color.png` (Paletten-Map) und `<id>_b.color.png` (Helligkeit), und die PSD.
- Positionskarten: `gbuf.py` je Modell mit 4096 2048, Grundmaterialien wie in `export_paint.BASES` (z. B. `bx_main,bx_aftermarket`,
  `sbr,sbr_aftermarket,sbr_efacelift,sbr_widebody`). Vanilla-Dateien liegen auf Alex' PC in `F:\BeamNG\current\hashiriya_tools\livery_src\<modell>\`.
- `python export_paint.py [modell|stil|modell_stil]` schreibt jbeam, Materialien (Vorlage = ein Vanilla-Skin mit UV1-Paletten-Map) und Texturen
  nach `vehicles\<modell>\hashiriya_paint*`; mit `HB_LIVERY_PSD=<ordner>` zusätzlich die PSDs.
- Rückweg: `python psd_zu_skin.py <modell>_<id>.psd` oder Drag-and-drop auf `PSD-zu-Skin.bat` (braucht `pip install numpy pillow psd-tools`).
  Feste Liveries (hashiriya_liveries) werden als fertiges Bild übernommen; deren PSDs macht `psd_alt.py <ordner>`.
- Vorschau: `preview.make(modell, textur, glb)` mit einer per `paint.preview_tex()` eingefärbten Textur; `SHOT_PORT` für parallele Läufe.
