import json, sys, hashlib, os
sys.path.insert(0, os.path.dirname(__file__))
from crews_a import CREWS_A
from crews_b import CREWS_B
from crews_c import CREWS_C
from wanderers import WANDERERS
from fixes import FIXES
from lines_1 import LINES_1
from lines_2 import LINES_2
from lines_3 import LINES_3
from lines_4 import LINES_4

from protect import DATA, write_protected
REPO = os.path.join(DATA, 'rivals.json')
MARKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cfg', 'marks.json')  # Buchstaben aus der Config-Liste
old = json.load(open(REPO, encoding='utf-8'))
marks = {f"{x['model']}/{x['key']}": x for x in json.load(open(MARKS, encoding='utf-8'))}

PAINTS = {
 'orange': ([1.0, 0.45, 0.05], 0.3, 0.35), 'pink': ([1.0, 0.35, 0.65], 0.4, 0.3), 'mint': ([0.55, 0.9, 0.75], 0.2, 0.4),
 'pearl': ([0.93, 0.92, 0.88], 0.6, 0.25), 'wine': ([0.35, 0.03, 0.1], 0.6, 0.3), 'champagne': ([0.85, 0.75, 0.55], 0.8, 0.25),
 'burgundy': ([0.4, 0.05, 0.08], 0.5, 0.3), 'violet': ([0.45, 0.15, 0.75], 0.7, 0.25), 'white': ([0.95, 0.95, 0.95], 0.0, 0.35),
 'forest': ([0.08, 0.3, 0.12], 0.4, 0.4), 'cream': ([0.95, 0.9, 0.75], 0.0, 0.45), 'fox': ([0.9, 0.4, 0.1], 0.5, 0.3),
 'grey': ([0.45, 0.46, 0.48], 0.3, 0.45), 'beige': ([0.78, 0.7, 0.55], 0.2, 0.45), 'red': ([0.8, 0.03, 0.03], 0.2, 0.3),
 'yellow': ([1.0, 0.82, 0.05], 0.2, 0.3), 'black': ([0.015, 0.015, 0.018], 0.7, 0.2), 'navy': ([0.04, 0.08, 0.25], 0.6, 0.3),
 'silver': ([0.7, 0.72, 0.74], 0.9, 0.3), 'teal': ([0.05, 0.5, 0.5], 0.4, 0.35), 'sky': ([0.5, 0.75, 0.95], 0.2, 0.4),
 'italred': ([0.75, 0.0, 0.0], 0.1, 0.25), 'rose': ([0.8, 0.3, 0.45], 0.6, 0.25), 'peach': ([1.0, 0.7, 0.55], 0.2, 0.4),
 'lilac': ([0.75, 0.6, 0.9], 0.4, 0.35), 'dark': ([0.1, 0.1, 0.13], 0.6, 0.3), 'coral': ([1.0, 0.45, 0.4], 0.3, 0.35),
 'ice': ([0.8, 0.9, 1.0], 0.7, 0.25), 'green': ([0.1, 0.55, 0.2], 0.4, 0.35), 'lime': ([0.6, 0.9, 0.1], 0.3, 0.3),
 'blue': ([0.05, 0.2, 0.7], 0.5, 0.3), 'midnight': ([0.03, 0.04, 0.12], 0.8, 0.2), 'electric': ([0.1, 0.6, 1.0], 0.7, 0.2),
 'olive': ([0.3, 0.33, 0.18], 0.1, 0.6), 'sand': ([0.76, 0.66, 0.46], 0.1, 0.6), 'gold': ([0.85, 0.65, 0.15], 0.9, 0.2),
 'brown': ([0.35, 0.2, 0.1], 0.4, 0.4), 'italyellow': ([1.0, 0.78, 0.0], 0.1, 0.25), 'frenchblue': ([0.0, 0.2, 0.6], 0.5, 0.25),
 'gunmetal': ([0.2, 0.22, 0.25], 0.8, 0.25), 'skyblue': ([0.4, 0.7, 1.0], 0.6, 0.25),
}

def paint(name):
    if not name: return None
    c, met, rough = PAINTS[name]
    return {'name': name, 'color': c, 'metallic': met, 'roughness': rough}

def h(s):
    return int(hashlib.md5(s.encode()).hexdigest(), 16)

VANITY = [1, 8, 88, 777, 1111, 2000, 3333, 5555, 7777, 8888, 9999, 1234, 4649, 2525, 3776, 1188, 5963, 3104, 8008, 6969, 4126, 1919, 2929, 1000, 5000, 7000]
def serial(n):
    s = f'{n:04d}'
    if n >= 1000: return s[:2] + '-' + s[2:]
    s = list(s); i = 0
    while i < 3 and s[i] == '0': s[i] = '.'; i += 1
    return ''.join(s[:2]) + ' ' + ''.join(s[2:])

COMMERCIAL = {'miramar/base_ute_M', 'miramar/base_ute_facelift_M', 'miramar/base_ute_plucky_M', 'van/offroad_alt', 'van/street_tuned',
              'nine/nine_pickup_hotrod', 'nine/nine_dragvan', 'pickup/d15_longbed_drag_A', 'wendover/super'}
REGIONS = ['shinagawa', 'shinagawa', 'shinagawa', 'sapporo', 'toyota', 'shizuoka', 'himeji', 'kochi', 'kumamoto', 'kagoshima']
vanityIdx = [0]
def plate(rid, cfg, region, special=False, design=None):
    x = h(rid)
    if design is None:
        if region == 'okinawa_airforce': design = 'am5jp_okinawa_airforce'
        else:
            kind = 'commercial' if cfg in COMMERCIAL else 'standard'
            design = f'am5jp_{region}_{kind}'
    cls = (100 + x % 100) if 'commercial' in design else ([300, 330, 500, 300, 301, 330, 503, 331][x % 8] + (x >> 8) % 10 * (0 if x % 3 else 1))
    if special:
        num = VANITY[vanityIdx[0] % len(VANITY)]; vanityIdx[0] += 1
    else:
        num = 1 + (x >> 16) % 9999
    top = f'{cls}/' if cls >= 100 else f'{cls:02d}//'
    return {'text': top + serial(num), 'design': design}

def stats(tier, i, role):
    if role == 'member':
        return dict(aggression=round(min(0.92, 0.45 + 0.03 * tier + 0.012 * i), 2), cruiseKmh=95 + 2 * tier,
                    maxSp=850 + 50 * tier + 12 * i, rewardUsd=int(round((1200 + 350 * tier) / 100) * 100), rep=40 + 5 * tier)
    return dict(aggression=round(min(0.97, 0.6 + 0.03 * tier), 2), cruiseKmh=103 + 2 * tier,
                maxSp=1050 + 50 * tier, rewardUsd=int(round((1200 + 350 * tier) * 2.5 / 100) * 100), rep=int((40 + 5 * tier) * 2.4))

oldById = {r['id']: r for r in old['rivals']}
crews = CREWS_A + CREWS_B + CREWS_C
teams, rivals, used = [], [], []
for ci, c in enumerate(sorted(crews, key=lambda c: c['tier'])):
    teams.append({'id': c['id'], 'name': c['name'], 'jp': c['jp'], 'color': c['color'], 'minRank': c['tier'],
                  'desc': {'de': c['desc'][0], 'en': c['desc'][1]}})
    for i, p in enumerate(c['members'] + [c['leader']]):
        leader = i == len(c['members'])
        cfg, name, nde, nen, dde, den = p[:6]
        pt = p[6] if len(p) > 6 else None
        model, key = cfg.split('/')
        rid = f"{c['id']}_leader" if leader else f"{c['id']}_{i + 1}"
        r = {'id': rid, 'name': name, 'nick': {'de': nde, 'en': nen}, 'team': c['id']}
        if leader:
            r['leader'] = True
            r['appear'] = (oldById.get(rid) or {}).get('appear') or ('sameNight' if ci % 2 == 0 else 'nextNight')
        r['model'] = model; r['config'] = f'vehicles/{model}/{key}.pc'
        r.update(stats(c['tier'], i, 'leader' if leader else 'member'))
        r['plate'] = plate(rid, cfg, c['region'], special=leader,
                           design='am5jp_shinagawa_olympic' if c['id'] == 't_scintilla' and (leader or i % 3 == 0) else None)
        if pt: r['paint'] = paint(pt)
        r['desc'] = {'de': dde, 'en': den}
        rivals.append(r); used.append(cfg)

for w in WANDERERS:
    cfg, wid, name, nde, nen, dde, den, hde, hen, cond = w[:10]
    pt = w[10] if len(w) > 10 else None
    model, key = cfg.split('/')
    rk = cond.get('minRank', 1)
    r = {'id': wid, 'name': name, 'nick': {'de': nde, 'en': nen}, 'wanderer': True, 'model': model,
         'config': f'vehicles/{model}/{key}.pc', 'aggression': round(min(0.97, 0.7 + 0.02 * rk), 2), 'cruiseKmh': 110 + 2 * rk,
         'maxSp': 1250 + 30 * rk, 'rewardUsd': int(round((1200 + 350 * rk) * 3 / 100) * 100), 'rep': (40 + 5 * rk) * 2,
         'conditions': cond}
    design = None
    if 'powerglow' in key: design = 'am5jp_shinagawa_glow'
    if wid == 'w_fukurou': design = 'am5jp_shinagawa_temporary'
    region = REGIONS[h(wid) % len(REGIONS)]
    if wid in ('w_rodeo', 'w_slider', 'w_bigblock', 'w_doc', 'w_marshal', 'w_tractor'): region = 'okinawa_airforce'
    r['plate'] = plate(wid, cfg, region, special=True, design=design)
    if pt: r['paint'] = paint(pt)
    r['desc'] = {'de': dde, 'en': den}; r['hint'] = {'de': hde, 'en': hen}
    rivals.append(r); used.append(cfg)

# End-Bosse: Platzhalter, bis Alex eigene Configs liefert
bossCond = {
 'b_shirotora': {'minRank': 6, 'minDay': 6, 'beatenTeams': ['t_lantern', 't_neon', 't_yamagumi', 't_kitsune']},
 'b_kokuryu': {'minRank': 12, 'minDay': 12, 'beatenTeams': ['t_kasumi', 't_akatsuki', 't_raijin', 't_kurogane']},
 'b_mugen': {'minRank': 13, 'minDay': 15, 'beatenRivals': ['b_shirotora', 'b_kokuryu'], 'hours': [2, 4]},
}
bossSp = {'b_shirotora': 1600, 'b_kokuryu': 1800, 'b_mugen': 2000}
for bid in ('b_shirotora', 'b_kokuryu', 'b_mugen'):
    b = dict(oldById[bid]); b['conditions'] = bossCond[bid]; b['maxSp'] = bossSp[bid]
    b['plate'] = plate(bid, '', 'shinagawa', special=True)
    b['_platzhalter'] = 'Config kommt später von Alex'
    rivals.append(b)

# Korrekturen (Marken, gemischte Namen)
seen = set()
for r in rivals:
    f = FIXES.get(r['name'])
    if not f: continue
    seen.add(r['name'])
    r['name'] = f.get('name', r['name'])
    if 'nde' in f: r['nick']['de'] = f['nde']
    if 'nen' in f: r['nick']['en'] = f['nen']
    if 'dde' in f: r['desc']['de'] = f['dde']
    if 'den' in f: r['desc']['en'] = f['den']
assert seen == set(FIXES), set(FIXES) - seen

# Sprueche (aus Sicht des Rivalen): challenge, win (Rivale gewinnt), lose (Rivale verliert)
LINES = {**LINES_1, **LINES_2, **LINES_3, **LINES_4}
assert len(LINES) == len(LINES_1) + len(LINES_2) + len(LINES_3) + len(LINES_4)
for r in rivals:
    L = LINES[r['id']]
    r['lines'] = {'challenge': {'de': L[0], 'en': L[1]}, 'win': {'de': L[2], 'en': L[3]}, 'lose': {'de': L[4], 'en': L[5]}}
    if 'desc' in r: r['desc'] = r.pop('desc')  # desc/hint ans Ende fuer Lesbarkeit
    if 'hint' in r: r['hint'] = r.pop('hint')
assert set(LINES) == {r['id'] for r in rivals}, set(LINES) ^ {r['id'] for r in rivals}

# Pruefen: jede R- und W-Config genau einmal
need = sorted(k for k, x in marks.items() if any(ch in (x['mark'] or '') for ch in 'RW'))
from collections import Counter
cnt = Counter(used)
dup = [k for k, v in cnt.items() if v > 1]
missing = [k for k in need if k not in cnt]
extra = [k for k in cnt if k not in need]
names = Counter(r['name'] for r in rivals)
assert not dup and not missing and not extra, (dup, missing, extra)
assert all(v == 1 for v in names.values()), [n for n, v in names.items() if v > 1]
ids = Counter(r['id'] for r in rivals); assert all(v == 1 for v in ids.values())
for c in crews: assert 4 <= len(c['members']) <= 12, (c['id'], len(c['members']))
for r in rivals:
    for rid in (r.get('conditions') or {}).get('beatenRivals', []): assert rid in ids, rid
    for t in [(r.get('conditions') or {}).get('beatenTeam')] + (r.get('conditions') or {}).get('beatenTeams', []):
        assert t is None or any(x['id'] == t for x in teams), t
    assert len(r['plate']['text']) == 9, r['plate']

# Raenge: Schwelle = vorige + 55 % des Rufs, den die Crews der vorigen Stufe bringen
RANKNAMES = [
 ('Neuling', 'Rookie', '初心者'), ('Nachtgast', 'Night Guest', '夜の客'), ('Straßenläufer', 'Street Runner', '走り屋'),
 ('Ampelstarter', 'Light Launcher', '信号ダッシュ'), ('Ringjäger', 'Loop Hunter', '環状ハンター'), ('Kurvenkünstler', 'Corner Artist', 'コーナー職人'),
 ('Tunnelgeist', 'Tunnel Ghost', 'トンネルの亡霊'), ('Schattenläufer', 'Shadow Runner', '影走り'), ('Nachtfalke', 'Night Hawk', '夜鷹'),
 ('Turbowolf', 'Turbo Wolf', 'ターボ狼'), ('Bahnbrecher', 'Trailblazer', '開拓者'), ('Asphaltdrache', 'Asphalt Dragon', 'アスファルトの竜'),
 ('Legende des Rings', 'Loop Legend', '環状伝説'), ('Mythos der Stadt', 'City Myth', '都市伝説'), ('Herr der Nacht', 'Lord of the Night', '夜の覇者'),
]
tierRep = Counter()
teamTier = {t['id']: t['minRank'] for t in teams}
for r in rivals:
    if r.get('team'): tierRep[teamTier[r['team']]] += r['rep']
ranks, rep = [], 0
for i, (de, en, jp) in enumerate(RANKNAMES):
    e = {'rep': int(round(rep / 50) * 50), 'name': {'de': de, 'en': en}, 'jp': jp}
    if i == len(RANKNAMES) - 1: e['requiresFinal'] = True
    ranks.append(e)
    rep += 0.55 * tierRep.get(i, tierRep[12])

EXTRA_HINT = (' plate = Kennzeichen aus Agent\'s Japanese Plates Pack (text: 4 Zeichen oben inkl. /, 5 unten; design = Teil im Slot licenseplate_design_2_1). paint = fester Lack (color RGB 0..1, metallic, roughness), nur wenn die Config keine Livery hat. _platzhalter = Boss wartet auf eigene Config. lines = Sprüche des Rivalen im SP-HUD: challenge beim Start, win wenn der Rivale gewinnt, lose wenn er verliert.')
hint = old['_hinweis'].replace('Rivalen fuer C1 (50 Gegner).', f'Rivalen fuer C1 ({len(rivals)} Gegner: {len(teams)} Crews, Wanderer, Bosse).')
if ' plate = Kennzeichen' in hint: hint = hint[:hint.index(' plate = Kennzeichen')]  # nicht bei jedem Lauf erneut anhaengen
out = {'_hinweis': hint + EXTRA_HINT,
       'settings': old['settings'], 'ranks': ranks, 'nicknames': old['nicknames'], 'teams': teams, 'rivals': rivals}
write_protected('rivals.json', out)  # Handänderungen in rivals.json bleiben erhalten
print(len(teams), 'crews', len(rivals), 'rivals', sum(1 for r in rivals if r.get('wanderer')), 'wanderer',
      sum(1 for r in rivals if r.get('paint')), 'paints')
print([(r['rep'], r['name']['de']) for r in ranks])
