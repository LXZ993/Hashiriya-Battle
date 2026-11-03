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
