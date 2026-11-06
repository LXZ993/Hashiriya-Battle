"""bake_all.py [models...] : build/<m>_<style>.png -> Schluesselbild -> Mod-Texturen + jbeam/materials."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, '/home/user/hashiriya-battle/tools/livery')
from vc_bake import bake_key, bake_fix, fix_png
from export_paint import write_maps, write_defs, BASES, MOD
STYLES = [  # (VectorCraft-Stil, Skin-ID, DE, EN)
    ('streetdrift_a', 'hb_streetdrift', 'Street-Drift Flammen', 'Street Drift Flames'),
    ('streetdrift_b', 'hb_streetdrift_team', 'Street-Drift Team', 'Street Drift Team'),
    ('factorysports_a', 'hb_factorysports', 'Werks-Sportstreifen', 'Factory Sports'),
    ('bosozoku_a', 'hb_bosozoku', 'Bosozoku', 'Bosozoku'),
    ('kaido_a', 'hb_kaido', 'Kaido-Racer', 'Kaido Racer'),
    ('twotone_a', 'hb_twotone', 'Werks-Zweifarben', 'Factory Two-Tone'),
    ('raceteam_a', 'hb_raceteam', 'Werks-Rennteam', 'Factory Race Team'),
    ('tech_a', 'hb_tech_wedge', 'Werks-Tech Keil', 'Factory Tech Wedge'),
    ('tech_b', 'hb_tech_layers', 'Werks-Tech Schicht-Balken', 'Factory Tech Layers'),
    ('tech_c', 'hb_tech_chevron', 'Werks-Tech Pfeilband', 'Factory Tech Chevrons'),
    ('tech_d', 'hb_tech_checker', 'Werks-Tech Zielflagge', 'Factory Tech Checker'),
    ('sponsor_a', 'hb_sponsor_race', 'Sponsor-Rennwagen', 'Sponsor Race Car'),
    ('d1drift_a', 'hb_d1_drift', 'D1-Profi-Drift', 'Pro Drift'),
    ('shopdemo_a', 'hb_shop_demo', 'Tuning-Shop-Demo-Car', 'Tuning Shop Demo Car'),
    ('rally_a', 'hb_rally', 'Rallye Gruppe A', 'Group A Rally'),
    ('company_a', 'hb_company', 'Firmenwagen', 'Company Car'),
    ('wa_a', 'hb_wa', 'Wa-Muster', 'Wa Pattern'),
    ('manga_a', 'hb_manga', 'Manga-Speed', 'Manga Speed'),
    ('splinter_a', 'hb_splinter', 'Splitter-Tarn', 'Splinter Camo'),
    ('groupc_a', 'hb_groupc', 'Gruppe C Retro', 'Group C Retro'),
    ('jgtc_a', 'hb_jgtc', 'JGTC-Wellen', 'GT Waves'),
    ('kanjo_a', 'hb_kanjo', 'Kanjo-Zoku', 'Kanjo Loop'),
]
from cars import ALLOWED
for m in (sys.argv[1:] or list(BASES)):
    items = []
    for st, sid, de, en in STYLES:
        if st not in ALLOWED[m]: continue
        png = os.path.join(HERE, 'build', f'{m}_{st}.png')
        if not os.path.exists(png): print('fehlt', png); continue
        key = bake_key(m, png)
        fp = fix_png(png); write_maps(m, sid, key, bake_fix(m, fp) if fp else None); items.append((sid, de, en)); print('ok', m, sid, flush=True)
    write_defs(m, items)
    # Skins, die nicht (mehr) zu diesem Auto passen, aus jbeam/materials und Texturordner entfernen
    import json
    keep = {s[1] for s in STYLES if s[0] in ALLOWED[m]}
    drop = {s[1] for s in STYLES} - keep
    vdir = os.path.join(MOD, 'vehicles', m)
    for fn in ('hashiriya_paint.jbeam', 'hashiriya_paint.materials.json'):
        p = os.path.join(vdir, fn); d = json.load(open(p, encoding='utf-8'))
        d = {k: v for k, v in d.items() if k.split('_skin_')[-1].split('.skin.')[-1] not in drop}
        json.dump(d, open(p, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    for sid in drop:
        for suf in ('_p', '_b'):
            f = os.path.join(vdir, 'hashiriya_paint', sid + suf + '.color.png')
            if os.path.exists(f): os.remove(f); print('entfernt', m, sid)
