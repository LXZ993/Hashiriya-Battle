"""Rückweg: nachbearbeitete PSD (oder als PNG exportiertes Bild) wieder ins Spiel bringen.

Aufruf:  python psd_zu_skin.py <datei.psd|datei.png> [modell] [skin-id]
Ohne modell/skin-id wird beides aus dem Dateinamen gelesen (<modell>_<skin-id>.psd, z. B. pessima_hb_kaido.psd).
Regeln für das Bild: ROT = Fahrzeugfarbe 1, GRÜN = Farbe 2, BLAU = Farbe 3, SCHWARZ = festes Schwarz.
Weiche Kanten/Mischungen sind erlaubt. Die Ebene "UV-Hilfe" muss ausgeblendet sein.
Schreibt vehicles/<modell>/hashiriya_paint/<skin-id>_p.color.png und _b.color.png neu (jbeam/Materialien bleiben).
Feste Liveries (Taxi, Polizei, Arbeiter in hashiriya_liveries/) werden als fertiges Bild übernommen.
Für eine NEUE Skin-ID zuerst mit export_paint.py anlegen oder Eintrag in styles.STYLES ergänzen.
"""
import os, sys
import numpy as np
from PIL import Image
from paint import key_to_maps

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(HERE, '..', '..'))
MODELS = ['pessima', 'midsize', 'bx', 'covet', 'hopper', 'miramar', 'pigeon', 'sunburst2', 'sbr', 'pickup', 'van']


def load(path):
    if path.lower().endswith('.psd'):
        from psd_tools import PSDImage
        psd = PSDImage.open(path)
        for ly in psd:
            if ly.name.startswith('UV-Hilfe'): ly.visible = False
        return psd.composite(force=True).convert('RGB')
    return Image.open(path).convert('RGB')


def main():
    if len(sys.argv) < 2: print(__doc__); sys.exit(1)
    path = sys.argv[1]
    if len(sys.argv) >= 4: model, sid = sys.argv[2], sys.argv[3]
    else:
        stem = os.path.splitext(os.path.basename(path))[0]
        model = next((m for m in sorted(MODELS, key=len, reverse=True) if stem.startswith(m + '_')), None)
        if not model: sys.exit('Modell nicht erkannt, bitte angeben: psd_zu_skin.py <datei> <modell> <skin-id>')
        sid = stem[len(model) + 1:]
    old = os.path.join(MOD, 'vehicles', model, 'hashiriya_liveries', f'{sid}.color.png')
    if os.path.exists(old):   # feste Liveries (Taxi, Polizei, Arbeiter): Bild direkt als Textur übernehmen
        load(path).save(old, optimize=True)
        print(f'fertig: {model} / {sid} -> {old}  (BeamNG neu starten oder Fahrzeug neu laden)'); return
    tdir = os.path.join(MOD, 'vehicles', model, 'hashiriya_paint')
    if not os.path.isdir(tdir): sys.exit(f'{tdir} fehlt – stimmt das Modell?')
    key = np.array(load(path))
    pal, base = key_to_maps(key)
    pal.save(os.path.join(tdir, f'{sid}_p.color.png'), optimize=True)
    base.convert('L').convert('RGB').save(os.path.join(tdir, f'{sid}_b.color.png'), optimize=True)
    print(f'fertig: {model} / {sid} -> {tdir}  (BeamNG neu starten oder Fahrzeug neu laden)')


if __name__ == '__main__':
    main()
