# Hashiriya Battle – Audio

Eigene Sounds und Musik, komplett per Code erzeugt (Synthese, keine Samples, keine KI-Audio).

* `sfx.py` – Menü- und Spiel-Sounds im Stil japanischer Rennspiel-Menüs (FM-"Pi-kon", Funk-Pings, Stinger).
* `music.py` – Instrumental-Songs als Noten. Erzeugt `music/*.mid` (zum Bearbeiten in jeder DAW) und eine Vorschau in `out/music/*.ogg`.
  * `midnight_line` – Eurobeat, 155 BPM, A-Moll (Nacht/Autobahn)
  * `sunlit_grid` – Fusion-Rock, 118 BPM, D-Dur (Tag/Rennstrecke)

```
pip install numpy scipy mido   # + ffmpeg für .ogg
python tools/audio/sfx.py
python tools/audio/music.py --stems
```

Die Vorschau nutzt einen sehr einfachen eingebauten Synth. Für den finalen Klang die MIDI-Datei in FL Studio / LMMS / Reaper laden und eigene Instrumente (z. B. Supersaw-Synth, echtes Drumkit) auf die Spuren legen.
