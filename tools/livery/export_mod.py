"""Schreibt die Hashiriya-Liveries ins Mod: vehicles/<modell>/hashiriya_liveries.jbeam (+ .materials.json) und die Texturen
vehicles/<modell>/hashiriya_liveries/<skin>.color.png. Aufruf: python export_mod.py [filter]  (Arbeitsordner siehe README.md)."""
import os, sys, json
from designs import LIVERIES
HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.abspath(os.path.join(HERE, '..', '..'))

# Vorlage je Modell: Basis-Materialien mit Skin-Variante, Ebene 0 (Original-Karosserie) und die Lack-Parameter der Skin-Ebene.
REF = {
    'pessima': {'pessima': ('/vehicles/pessima/pessima_main', 'pessima_main_alt_c', 'pessima_main_n.normal', 'pessima_main_cc', 1, '/vehicles/pessima/pessima_main_m.data.png', '/vehicles/pessima/pessima_main_r.data.png'),
                'pessima_aftermarket': ('/vehicles/pessima/pessima_aftermarket', 'pessima_aftermarket_c', 'pessima_aftermarket_nm.normal', 'pessima_aftermarket_cc', 0.001, None, None)},
    'midsize': {'midsize_body': ('/vehicles/midsize/midsize_body', 'midsize_body_c', 'midsize_body_nm.normal', 'midsize_body_cc', 1, '/vehicles/midsize/midsize_body_m.data.png', '/vehicles/midsize/midsize_body_r.data.png')},
    'sunburst2': {'sunburst2_main': ('/vehicles/sunburst2/sunburst2_main', 'sunburst2_main_c', 'sunburst2_main_nm.normal', 'sunburst2_main_cc', 1, '/vehicles/sunburst2/sunburst2_main_m.data.png', '/vehicles/sunburst2/sunburst2_main_r.data.png')},
    'pickup': {'pickup': ('/vehicles/common/pickup/pickup_main', '/vehicles/pickup/pickup_skin_o', 'pickup_main_n.normal', 'pickup_main_cc', 1, '/vehicles/common/pickup/pickup_main_m.data.png', '/vehicles/common/pickup/pickup_main_r.data.png')},
    'van': {'van': ('/vehicles/van/van_main', 'van_main_c', 'van_main_nm.normal', 'van_main_cc', 1, '/vehicles/van/van_main_m.data.png', '/vehicles/van/van_main_r.data.png')},
}

def material(model, base, skin, tex):
    pre, opac, nrm, cc, metal, mmap, rmap = REF[model][base]
    folder = pre.rsplit('/', 1)[0]
    def p(x, kind='data'):
        return x + '.' + kind + '.png' if x.startswith('/') else folder + '/' + x + ('' if x.endswith('.normal') else '.' + kind) + '.png'
    l0 = {'ambientOcclusionMap': pre + '_ao.data.png', 'baseColorMap': pre + '_b.color.png', 'normalMap': folder + '/' + nrm + '.png', 'metallicFactor': metal}
    if mmap: l0['metallicMap'] = mmap
    if rmap: l0['roughnessMap'] = rmap
    else: l0['roughnessFactor'] = 0.5
    l1 = {'ambientOcclusionMap': pre + '_ao.data.png', 'baseColorMap': tex, 'diffuseMapUseUV': 1,
          'clearCoatFactor': 1, 'clearCoatMap': folder + '/' + cc + '.data.png', 'clearCoatRoughnessFactor': 0.08,
          'detailNormalMap': '/vehicles/common/orange_peel_n.normal.png', 'detailNormalMapStrength': 0.15, 'detailScale': [128, 64], 'normalDetailMapUseUV': 1,
          'metallicFactor': 0.4, 'roughnessFactor': 0.35, 'normalMap': folder + '/' + nrm + '.png',
          'opacityMap': p(opac) if opac.startswith('/') else folder + '/' + opac + '.data.png'}
    name = f'{base}.skin.{skin}'
    return name, {'name': name, 'mapTo': name, 'class': 'Material', 'Stages': [l0, l1, {}, {}], 'activeLayers': 2,
                  'dynamicCubemap': True, 'materialTag0': 'beamng', 'materialTag1': 'vehicle', 'version': 1.5}

def main(only):
    per = {}
    for sid, m, fn, de, en in LIVERIES:
        if only and not any(o in f'{m}_{sid}' for o in only): continue
        per.setdefault(m, []).append((sid, fn, de, en))
    for m, items in per.items():
        vdir = os.path.join(MOD, 'vehicles', m); tdir = os.path.join(vdir, 'hashiriya_liveries'); os.makedirs(tdir, exist_ok=True)
        jb = {}; mats = {}
        jpath = os.path.join(vdir, 'hashiriya_liveries.jbeam'); mpath = os.path.join(vdir, 'hashiriya_liveries.materials.json')
        if os.path.exists(jpath): jb = json.load(open(jpath, encoding='utf-8'))
        if os.path.exists(mpath): mats = json.load(open(mpath, encoding='utf-8'))
        for sid, fn, de, en in items:
            im = fn(m)
            png = os.path.join(tdir, sid + '.color.png'); im.save(png, optimize=True)
            tex = f'/vehicles/{m}/hashiriya_liveries/{sid}.color.png'
            for base in REF[m]:
                k, v = material(m, base, sid, tex); mats[k] = v
            jb[f'{m}_skin_{sid}'] = {'information': {'authors': 'JDMArsch (LXZ aka. LXZockt), Hashiriya Battle', 'name': 'Hashiriya: ' + en, 'value': 2500},
                                    'slotType': 'paint_design', 'globalSkin': sid}
            print('ok', m, sid, os.path.getsize(png) // 1024, 'KB')
        json.dump(jb, open(jpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
        json.dump(mats, open(mpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)

if __name__ == '__main__':
    main(sys.argv[1:])
