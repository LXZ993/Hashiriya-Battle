"""Percheron-LKW-Skins ins Mod schreiben (Fahrerhaus + Koffer + Tank, Verkehrs-Configs).

Ablauf:
  1. Entwürfe als SVG:   python pc_spedition_a.py W/sped ; pc_spedition_bc.py W/sp ; pc_dekotora_a.py W/deko ; pc_dekotora_bc.py W/dk ; pc_tanker.py W/tk
  2. python pc_bake.py render        (SVG -> PNG 200 px/m, Playwright). .vectorcraft/PSD: vectorcraft-cli convert <svg> <ziel>.vectorcraft (bzw. .psd --hidden-objects layer)
  3. python pc_gbuf.py cab box tank  (Positionskarten UV1 -> 3D, einmalig)
  4. python pc_bake.py [ids...]      (Texturen, jbeam, Materialien, .pc-Configs; nur Configs: pc_bake.py configs)
  Kontrolle: python pc_preview.py <id> <box|tank> <ausgabe> [lackfarbe]  (3D-Bild, braucht web/node_modules/three)
Umgebung: HB_PC_WORK = Arbeitsordner (SVG/PNG/Positionskarten), HB_PC_SRC = entpacktes livery_src_percheron.zip,
          HB_PC_SRC2 = entpacktes livery_src_percheron2.zip (Vanilla-.pc-Configs).
Farben sind fest (Firmenlackierung). Bei Dekotora bleibt die Fahrerhaus-Fläche außerhalb des Motivs Lackfarbe 1."""
import os, sys, json, copy, glob, subprocess
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
from paint import PaintCtx

MOD = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
WORK = os.environ.get('HB_PC_WORK', os.path.join(HERE, 'work_pc'))
SRC = os.environ.get('HB_PC_SRC', os.path.join(WORK, 'src'))
SRC2 = os.environ.get('HB_PC_SRC2', os.path.join(WORK, 'src2'))
OUT = os.path.join(MOD, 'vehicles', 'percheron')
TEX = 'hashiriya_paint'
AUTHOR = 'JDMArsch (LXZ aka. LXZockt), Hashiriya Battle'
PPM = 200  # Pixel je Meter der gerenderten Seitenansichten (SVG 100 px/m, Faktor 2)

# id, Aufbau, SVG-Name, Art, Name EN, Name DE
DESIGNS = [
    ('hb_hoshizora', 'box', 'sped', 'firma', 'Hoshizora Express', 'Hoshizora Express'),
    ('hb_aoba', 'box', 'sp_b', 'firma', 'Aoba Logistics', 'Aoba Logistics'),
    ('hb_hayate', 'box', 'sp_c', 'firma', 'Hayate Moving', 'Hayate Umzüge'),
    ('hb_yozakura', 'box', 'deko', 'deko', 'Dekotora Yozakura-maru', 'Dekotora Yozakura-maru'),
    ('hb_fugaku', 'box', 'dk_b', 'deko', 'Dekotora Fugaku-maru', 'Dekotora Fugaku-maru'),
    ('hb_nishikigoi', 'box', 'dk_c', 'deko', 'Dekotora Nishikigoi-maru', 'Dekotora Nishikigoi-maru'),
    ('hb_hinode', 'tank', 'tk_a', 'firma', 'Hinode Oil', 'Hinode Oil'),
    ('hb_raijin', 'tank', 'tk_b', 'deko', 'Dekotora Raijin-maru', 'Dekotora Raijin-maru'),
    ('hb_hokkai', 'tank', 'tk_c', 'firma', 'Hokkai Milk', 'Hokkai Milk'),
    ('hb_toyogas', 'tank', 'tk_d', 'firma', 'Toyo Gas', 'Toyo Gas'),
    ('hb_momiji', 'tank', 'tk_e', 'deko', 'Dekotora Momiji-maru', 'Dekotora Momiji-maru'),
    ('hb_tora', 'tank', 'tk_f', 'deko', 'Dekotora Tora-maru', 'Dekotora Tora-maru'),
]
# Verkehrs-Configs: Vanilla-Config -> welche Skins
BOX_BASES = ['s310_4x2_box_A', 'l370_6x2_tag_box_M', 'xl500_6x4_box_M']
TANK_BASES = ['s410_6x4_tanker_M', 'l410_6x2_tag_tanker_M']
CAB_ONLY = {'s310_4x2_flatbed_M': ['hb_aoba', 'hb_hayate', 'hb_fugaku', 'hb_tora'],
            'l310_6x4_flatbed_M': ['hb_hoshizora', 'hb_toyogas', 'hb_yozakura', 'hb_momiji'],
            's370_6x4_mixer_M': ['hb_hinode', 'hb_aoba', 'hb_raijin', 'hb_nishikigoi'],
            's410_6x2_tag_tankerMilk_A': ['hb_hokkai']}


def side_img(name, side):
    return np.asarray(Image.open(os.path.join(WORK, f'{name}_{side}.png')).convert('RGBA')).astype(np.float32) / 255


def render():
    js = os.path.join(HERE, 'pc_render.js')
    for f in sorted(glob.glob(os.path.join(WORK, '*_[LR].svg'))):
        subprocess.run(['node', js, f, f[:-4] + '.png', '2'], check=True)
        print('png', os.path.basename(f)[:-4])


def sample(gb, name, sidecut=0.35):
    """Je Texel die Farbe aus der Seitenansicht (links +X, rechts -X). Gibt RGBA (H,W,4) und Maske zurück."""
    d = np.load(os.path.join(WORK, f'pc_{gb}_gb.npz')); pos, nrm, mask = d['pos'], d['nrm'], d['mask']
    H, W = mask.shape
    out = np.zeros((H, W, 4), np.float32)
    for side, sel in (('L', mask & (nrm[..., 0] > sidecut)), ('R', mask & (nrm[..., 0] < -sidecut))):
        im = side_img(name, side); h, w = im.shape[:2]
        Y, Z = pos[sel][:, 1], pos[sel][:, 2]
        x = ((Y + 3.7) if side == 'L' else (6.7 - Y)) * PPM
        y = (4.2 - Z) * PPM
        xi = np.clip(np.round(x).astype(int), 0, w - 1); yi = np.clip(np.round(y).astype(int), 0, h - 1)
        out[sel] = im[yi, xi]
    return out, mask


def comp_white(rgba):
    a = rgba[..., 3:4]
    return rgba[..., :3] * a + (1 - a)


def save(img, path, mode='RGB'):
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), mode).save(path, optimize=True)


def bake(did, kind, name, art):
    tdir = os.path.join(OUT, TEX); os.makedirs(tdir, exist_ok=True)
    # Fahrerhaus: Paletten-Map + Helligkeit/Farbe (UV1)
    rgba, m = sample('cab', name)
    a = rgba[..., 3:4]
    if art == 'firma':   # ganz fest: weißes Fahrerhaus + Motiv
        pal = np.zeros(rgba.shape[:2] + (3,), np.float32)
        base = comp_white(rgba)
    else:                # Dekotora: außerhalb des Motivs Lackfarbe 1
        pal = np.zeros(rgba.shape[:2] + (3,), np.float32); pal[..., 0] = 1
        pal = pal * (1 - a)
        base = comp_white(rgba)
    pal = PaintCtx._dilate3(pal, m.copy(), 6); base = PaintCtx._dilate3(base, m.copy(), 6)
    save(pal, os.path.join(tdir, f'{did}_cab_p.color.png')); save(base, os.path.join(tdir, f'{did}_cab_b.color.png'))
    if kind == 'box':
        rgba, m = sample('box', name, 0.5)
        base = PaintCtx._dilate3(comp_white(rgba), m.copy(), 6)
        save(base, os.path.join(tdir, f'{did}_box_b.color.png'))
    else:
        rgba, m = sample('tank', name, 0.3)
        base = PaintCtx._dilate3(comp_white(rgba), m.copy(), 6)
        save(base, os.path.join(tdir, f'{did}_tank_b.color.png'))
        save(np.zeros_like(base), os.path.join(tdir, f'{did}_tank_p.color.png'))
        o = PaintCtx._dilate3(m[..., None].astype(np.float32).repeat(3, -1), m.copy(), 4)
        save(o[..., 0], os.path.join(tdir, f'{did}_tank_o.data.png'), 'L')
    print('ok', did, flush=True)


def vanilla_mats():
    return json.load(open(os.path.join(SRC, 'vehicles', 'percheron', 'skins', 'skin.materials.json'), encoding='utf-8'))


def clone(tpl, name, repl):
    m = copy.deepcopy(tpl); m['name'] = m['mapTo'] = name; m.pop('persistentId', None)
    st = []
    for s in m['Stages']:
        s = {k: v for k, v in s.items() if v is not None}
        for k, v in list(s.items()):
            if isinstance(v, str):
                if not v.startswith('/') and '/' in v: v = '/' + v
                s[k] = repl.get(v, v)
        st.append(s)
    m['Stages'] = st
    return m


def write_defs(ids):
    vm = vanilla_mats()
    t = f'/vehicles/percheron/{TEX}/'
    jpath = os.path.join(OUT, 'hashiriya_paint.jbeam'); mpath = os.path.join(OUT, 'hashiriya_paint.materials.json')
    jb = json.load(open(jpath, encoding='utf-8')) if os.path.exists(jpath) else {}
    mats = json.load(open(mpath, encoding='utf-8')) if os.path.exists(mpath) else {}
    for did, kind, name, art, en, de in DESIGNS:
        if ids and did not in ids: continue
        mv = '/vehicles/percheron/skins/percheron_body_skin_montevalle_'
        r = {mv + 'p.color.png': t + f'{did}_cab_p.color.png', mv + 'b.color.png': t + f'{did}_cab_b.color.png'}
        mats[f'percheron_body.skin.{did}'] = clone(vm['percheron_body.skin.montevalle'], f'percheron_body.skin.{did}', r)
        mats[f'percheron_body_paint.skin.{did}'] = clone(vm['percheron_body_paint.skin.montevalle'], f'percheron_body_paint.skin.{did}', r)
        jb[f'percheron_skin_{did}'] = {'information': {'authors': AUTHOR, 'name': f'Hashiriya: {en}', 'value': 501},
                                       'slotType': 'paint_design', 'skinName': did}
        if kind == 'box':
            r = {'/vehicles/eu_trailers/skins/eu_trailer_skin_cola_M_b.color.png': t + f'{did}_box_b.color.png'}
            mats[f'percheron_flatbed.skin_boxTruck.{did}'] = clone(vm['percheron_flatbed.skin_boxTruck.colaTruck'], f'percheron_flatbed.skin_boxTruck.{did}', r)
            jb[f'skin_box_{did}'] = {'information': {'authors': AUTHOR, 'name': f'Hashiriya: {en}', 'value': 501},
                                     'slotType': 'skin_boxTruck', 'skinName': did}
        else:
            a = '/vehicles/common/eu_truck/eu_tanker/eu_tanker_skin_apex_'
            r = {a + 'p.color.png': t + f'{did}_tank_p.color.png', a + 'b.color.png': t + f'{did}_tank_b.color.png', a + 'o.data.png': t + f'{did}_tank_o.data.png'}
            mats[f'percheron_tanker.skin_tanker.{did}'] = clone(vm['percheron_tanker.skin_tanker.apex'], f'percheron_tanker.skin_tanker.{did}', r)
            jb[f'skin_tanker_{did}'] = {'information': {'authors': AUTHOR, 'name': f'Hashiriya: {en}', 'value': 501},
                                        'slotType': 'skin_tanker', 'skinName': did}
    json.dump(jb, open(jpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    json.dump(mats, open(mpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)


def pc_name(did, base):
    return f'hb_traffic_{did[3:]}_{base.split("_")[0]}'


def write_configs():
    """Eigene Verkehrs-Configs: Vanilla-Config + unsere Skins. Gibt die Liste für cars.json zurück."""
    out = []
    def make(base, did, kind):
        src = json.load(open(os.path.join(SRC2, 'vehicles', 'percheron', base + '.pc'), encoding='utf-8'))
        p = src['parts']
        p['paint_design'] = f'percheron_skin_{did}'
        if kind == 'box': p['skin_boxTruck'] = f'skin_box_{did}'
        if kind == 'tank': p['skin_tanker'] = f'skin_tanker_{did}'
        if 'skin_tanker_stainless' in p: p['skin_tanker_stainless'] = ''
        name = pc_name(did, base) + ('_' + base.split('_', 1)[1].lower() if kind == 'cab' else '')
        json.dump(src, open(os.path.join(OUT, name + '.pc'), 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
        en = next(d[4] for d in DESIGNS if d[0] == did)
        info = {'Configuration': f'Hashiriya {en} ({base.split("_")[0].upper()} {base.split("_")[-2]})', 'Config Type': 'Custom',
                'Description': 'Hashiriya Battle traffic truck', 'Author': AUTHOR}
        json.dump(info, open(os.path.join(OUT, f'info_{name}.json'), 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
        out.append({'model': 'percheron', 'config': name})
    for did, kind, *_ in DESIGNS:
        for base in (BOX_BASES if kind == 'box' else TANK_BASES):
            make(base, did, kind)
    for base, ids in CAB_ONLY.items():
        for did in ids: make(base, did, 'cab')
    return out


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['render']:
        render(); sys.exit()
    if args[:1] == ['configs']:
        cfgs = write_configs(); json.dump(cfgs, open(os.path.join(WORK, 'pc_traffic_configs.json'), 'w'), indent=1); print(len(cfgs)); sys.exit()
    ids = set(args)
    for did, kind, name, art, en, de in DESIGNS:
        if not ids or did in ids: bake(did, kind, name, art)
    write_defs(ids)
    cfgs = write_configs()
    json.dump(cfgs, open(os.path.join(WORK, 'pc_traffic_configs.json'), 'w'), indent=1)
    print(len(cfgs), 'Configs')
