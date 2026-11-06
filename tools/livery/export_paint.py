"""Lackierbare Japan-Liveries ins Mod schreiben.

Aufruf:  python export_paint.py [filter ...]          (z. B. "pessima" oder "hb_kaido" oder "bx_hb_twotone")
Schreibt je Modell:
  vehicles/<modell>/hashiriya_paint.jbeam              (Teile <modell>_skin_<id>, Slot paint_design)
  vehicles/<modell>/hashiriya_paint.materials.json     (Material je Karosserie-Grundmaterial)
  vehicles/<modell>/hashiriya_paint/<id>_p.color.png   (Paletten-Map: Rot/Grün/Blau = Farbe 1/2/3)
  vehicles/<modell>/hashiriya_paint/<id>_b.color.png   (Helligkeit)
und, wenn HB_LIVERY_PSD gesetzt ist, dort <modell>_<id>.psd zum Nachbearbeiten (Rückweg: psd_zu_skin.py).
Braucht die Vanilla-Dateien wie export_mod.py (HB_LIVERY_SRC) und die Positionskarten aus gbuf.py (HB_LIVERY_WORK).
"""
import os, sys, json, re, copy
from PIL import Image
from styles import STYLES, GEO
from paint import key_to_maps, save_psd

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(HERE, '..', '..'))
WORK = os.environ.get('HB_LIVERY_WORK', os.path.join(HERE, 'work'))
SRC = os.environ.get('HB_LIVERY_SRC', os.path.join(WORK, 'src'))
PSD = os.environ.get('HB_LIVERY_PSD')

# Grundmaterialien je Modell, die das Skin-Layout (UV1) der Karosserie teilen. Die erste ist die Hauptkarosserie.
BASES = {
    'pessima': ['pessima', 'pessima_aftermarket'],
    'midsize': ['midsize_body'],
    'bx': ['bx_main', 'bx_aftermarket'],
    'covet': ['covet'],
    'hopper': ['hopper'],
    'miramar': ['miramar'],
    'pigeon': ['pigeon'],
    'sunburst2': ['sunburst2_main'],
    'sbr': ['sbr', 'sbr_aftermarket', 'sbr_efacelift', 'sbr_widebody'],
}
AUTHOR = 'JDMArsch (LXZ aka. LXZockt), Hashiriya Battle'


def vanilla_skins(model):
    p = os.path.join(SRC, model, 'vehicles', model, 'skin.materials.json')
    t = re.sub(r'(?m)^\s*//.*$', '', open(p, encoding='utf-8').read())
    return json.loads(t)


def template(skins, base):
    """Vanilla-Skin-Material dieser Grundkarosserie mit Paletten-Map auf UV1 und Karosserie-Maske als Vorlage."""
    best = None
    for k, v in skins.items():
        if not k.startswith(base + '.skin.'): continue
        st = v.get('Stages', [{}, {}])
        if len(st) < 2 or st[1].get('colorPaletteMapUseUV') != 1: continue
        op = st[1].get('opacityMap') or ''
        score = (0 if 'skin' in op.lower() else 2) + (1 if 'custom' in k else 0)
        if best is None or score > best[0]: best = (score, k, v)
    if not best: raise SystemExit(f'Keine Vorlage für {base} gefunden')
    return best[2]


def abspath(p):
    return p if not isinstance(p, str) or p.startswith('/') or '/' not in p else '/' + p


def material(tpl, base, sid, model):
    m = copy.deepcopy(tpl)
    name = f'{base}.skin.{sid}'
    m['name'] = m['mapTo'] = name
    stages = []
    for i, st in enumerate(m['Stages']):
        st = {k: abspath(v) for k, v in st.items() if v is not None}
        if i == 1:
            for k in list(st):
                if isinstance(st[k], str) and '_skin_' in st[k].lower() and k != 'opacityMap': del st[k]
            st['baseColorMap'] = f'/vehicles/{model}/hashiriya_paint/{sid}_b.color.png'
            st['colorPaletteMap'] = f'/vehicles/{model}/hashiriya_paint/{sid}_p.color.png'
            st['colorPaletteMapUseUV'] = 1; st['diffuseMapUseUV'] = 1; st['instanceDiffuse'] = True
            st.setdefault('metallicFactor', 1)
        stages.append(st)
    m['Stages'] = stages
    m.pop('persistentId', None)
    return name, m


def write_maps(model, sid, key, fix=None):
    """fix: optional HxWx4 float (RGB + Alpha) fuer feste, nicht einfaerbbare Farben (Logos, Muster).
    Dort ist die Paletten-Karte schwarz, damit die Farbe der baseColorMap unveraendert erscheint."""
    tdir = os.path.join(MOD, 'vehicles', model, 'hashiriya_paint'); os.makedirs(tdir, exist_ok=True)
    pal, base = key_to_maps(key)
    if fix is None:
        pal.save(os.path.join(tdir, f'{sid}_p.color.png'), optimize=True)
        base.convert('L').convert('RGB').save(os.path.join(tdir, f'{sid}_b.color.png'), optimize=True)
        return
    import numpy as np
    from PIL import Image
    a = fix[..., 3:4]
    p = np.asarray(pal).astype(np.float32) / 255 * (1 - a)
    bb = np.asarray(base.convert('L').convert('RGB')).astype(np.float32) / 255 * (1 - a) + fix[..., :3] * a
    Image.fromarray((p * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(tdir, f'{sid}_p.color.png'), optimize=True)
    Image.fromarray((np.clip(bb, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(tdir, f'{sid}_b.color.png'), optimize=True)


def write_defs(model, items):
    vdir = os.path.join(MOD, 'vehicles', model)
    jpath = os.path.join(vdir, 'hashiriya_paint.jbeam'); mpath = os.path.join(vdir, 'hashiriya_paint.materials.json')
    jb = json.load(open(jpath, encoding='utf-8')) if os.path.exists(jpath) else {}
    mats = json.load(open(mpath, encoding='utf-8')) if os.path.exists(mpath) else {}
    skins = vanilla_skins(model)
    for sid, de, en in items:
        for base in BASES[model]:
            try: tpl = template(skins, base)
            except SystemExit as e: print('  übersprungen:', e); continue
            k, v = material(tpl, base, sid, model); mats[k] = v
        jb[f'{model}_skin_{sid}'] = {'information': {'authors': AUTHOR, 'name': f'Hashiriya: {en} (Colorable)', 'value': 3000},
                                     'slotType': 'paint_design', 'skinName': sid}
    json.dump(jb, open(jpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    json.dump(mats, open(mpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)


def main(only):
    for model in GEO:
        items = []
        for sid, fn, de, en in STYLES:
            key = f'{model}_{sid}'
            if only and not any(o == model or o == sid or o == key for o in only): continue
            pc = fn(model); res = pc.bake()
            write_maps(model, sid, res['key'])
            if PSD:
                os.makedirs(PSD, exist_ok=True)
                guide = Image.open(os.path.join(WORK, model + '_gb.png')) if os.path.exists(os.path.join(WORK, model + '_gb.png')) else None
                save_psd(os.path.join(PSD, f'{model}_{sid}.psd'), res, guide)
            items.append((sid, de, en)); print('ok', key, flush=True)
        if items: write_defs(model, items)


if __name__ == '__main__':
    main(sys.argv[1:])
