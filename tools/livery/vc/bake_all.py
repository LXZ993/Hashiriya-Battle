"""bake_all.py [models...] : build/<m>_<style>.png -> Schluesselbild -> Mod-Texturen + jbeam/materials."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, '/home/user/hashiriya-battle/tools/livery')
from vc_bake import bake_key
from export_paint import write_maps, write_defs, BASES
STYLES = [  # (VectorCraft-Stil, Skin-ID, DE, EN)
    ('streetdrift_a', 'hb_streetdrift', 'Street-Drift Flammen', 'Street Drift Flames'),
    ('streetdrift_b', 'hb_streetdrift_team', 'Street-Drift Team', 'Street Drift Team'),
    ('factorysports_a', 'hb_factorysports', 'Werks-Sportstreifen', 'Factory Sports'),
    ('bosozoku_a', 'hb_bosozoku', 'Bosozoku', 'Bosozoku'),
    ('kaido_a', 'hb_kaido', 'Kaido-Racer', 'Kaido Racer'),
    ('twotone_a', 'hb_twotone', 'Werks-Zweifarben', 'Factory Two-Tone'),
    ('raceteam_a', 'hb_raceteam', 'Werks-Rennteam', 'Factory Race Team'),
]
for m in (sys.argv[1:] or list(BASES)):
    items = []
    for st, sid, de, en in STYLES:
        png = os.path.join(HERE, 'build', f'{m}_{st}.png')
        if not os.path.exists(png): print('fehlt', png); continue
        key = bake_key(m, png)
        write_maps(m, sid, key); items.append((sid, de, en)); print('ok', m, sid, flush=True)
    write_defs(m, items)
