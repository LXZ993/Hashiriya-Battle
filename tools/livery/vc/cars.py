"""Pro-Auto-Daten fuer die VectorCraft-Liveries: Formvariante je Stil und Texte (Marke, Modell, Teams, Nummern).
200BX bleibt immer Variante 0 (so wie von Alex abgenommen)."""
MODELS = ['bx', 'pessima', 'midsize', 'covet', 'miramar', 'sunburst2', 'sbr', 'hopper', 'pigeon']
SHIFT = {'streetdrift_a': 0, 'streetdrift_b': 1, 'factorysports_a': 2, 'bosozoku_a': 0, 'kaido_a': 1, 'twotone_a': 2, 'raceteam_a': 0}
# Welche Stile zu welchem Auto passen (Baujahr + Antrieb, Alex 2026-11-05): kein Drift auf Fronttrieblern,
# kein Bosozoku/Kaido/Zweifarben auf modernen Autos, Tech nur auf neueren Modellen.
ALLOWED = {
    'bx': ['streetdrift_a', 'streetdrift_b', 'kaido_a', 'bosozoku_a', 'factorysports_a', 'sponsor_a', 'd1drift_a', 'shopdemo_a', 'wa_a', 'manga_a', 'splinter_a', 'groupc_a', 'jgtc_a', 'kanjo_a'],
    'miramar': ['bosozoku_a', 'kaido_a', 'twotone_a', 'streetdrift_a', 'd1drift_a', 'shopdemo_a', 'wa_a', 'splinter_a'],
    'pessima': ['bosozoku_a', 'kaido_a', 'twotone_a', 'factorysports_a', 'shopdemo_a', 'rally_a', 'wa_a', 'groupc_a', 'kanjo_a'],
    'midsize': ['twotone_a', 'factorysports_a', 'raceteam_a', 'tech_a', 'tech_b', 'tech_c', 'tech_d', 'sponsor_a', 'shopdemo_a', 'rally_a', 'wa_a', 'manga_a', 'groupc_a', 'jgtc_a', 'kanjo_a'],
    'covet': ['factorysports_a', 'raceteam_a', 'tech_a', 'tech_b', 'tech_c', 'tech_d', 'sponsor_a', 'shopdemo_a', 'rally_a', 'wa_a', 'jgtc_a', 'kanjo_a'],
    'sunburst2': ['raceteam_a', 'factorysports_a', 'streetdrift_a', 'streetdrift_b', 'tech_a', 'tech_b', 'tech_c', 'tech_d', 'sponsor_a', 'd1drift_a', 'shopdemo_a', 'rally_a', 'wa_a', 'manga_a', 'splinter_a', 'jgtc_a'],
    'sbr': ['tech_a', 'tech_b', 'tech_c', 'tech_d', 'raceteam_a', 'streetdrift_a', 'streetdrift_b', 'sponsor_a', 'd1drift_a', 'shopdemo_a', 'wa_a', 'manga_a', 'splinter_a', 'jgtc_a'],
    'hopper': ['twotone_a', 'factorysports_a', 'rally_a', 'company_a', 'splinter_a'],
    'pigeon': ['twotone_a', 'company_a'],
}
def variant(model, style):
    import os
    if os.environ.get('HB_V'): return int(os.environ['HB_V'])
    if model == 'bx': return 0
    i = MODELS.index(model)
    return (i + SHIFT.get(style, 0)) % 3
# Texte je Auto (werden durch Alex' lorefreundliche Marken ersetzt)
CAR = {
    'bx':        dict(brand='Ibishu',  maker='IBISHU',  script='Ibishu Tecnica', engine='TWINCAM 16 VALVE', team='Yokaze Sports', num='43', rnum='46', kata='カイドー・レーサー'),
    'pessima':   dict(brand='Ibishu',  maker='IBISHU',  script='Pessima GT',     engine='DOHC 16 VALVE',   team='Kuroshio Racing', num='7',  rnum='12', kata='チーム・ハヤテ'),
    'midsize':   dict(brand='Ibishu',  maker='IBISHU',  script='Pessima Sports', engine='TWINCAM 24 VALVE', team='Shiden Works',  num='18', rnum='23', kata='イナズマ・レーシング'),
    'covet':     dict(brand='Ibishu',  maker='IBISHU',  script='Covet Sprint',   engine='1600 DOHC',       team='Akatsuki Drift', num='21', rnum='5',  kata='チーム・シデン'),
    'miramar':   dict(brand='Ibishu',  maker='IBISHU',  script='Miramar Royal',  engine='SOHC 1600',       team='Hayate Garage',  num='33', rnum='2',  kata='カゼキリ・クラブ'),
    'sunburst2': dict(brand='Hirochi', maker='HIROCHI', script='Sunburst RS',    engine='TURBO 4WD',       team='Tsuki Motors',   num='55', rnum='39', kata='チーム・ヨザクラ'),
    'sbr':       dict(brand='Hirochi', maker='HIROCHI', script='SBR4 Type-S',    engine='TWIN TURBO',      team='Inazuma Speed',  num='61', rnum='51', kata='ライデン・レーサー'),
    'hopper':    dict(brand='Ibishu',  maker='IBISHU',  script='Hopper Trail',   engine='4WD TURBO',       team='Kagerou Factory', num='77', rnum='68', kata='ホクト・オフロード'),
    'pigeon':    dict(brand='Ibishu',  maker='IBISHU',  script='Pigeon Deluxe',  engine='550 SUPER',       team='Hokuto Sports',  num='88', rnum='15', kata='アカツキ・クラブ'),
}
# BeamNG-Lore-Logos (aus art/dynamicDecals/textures, als Alphamaske in logos/), passend fuer JP-Tuning
SPONSORS = ['driftgear', 'okudai', 'wangan', 'gripall', 'grunt_2', 'eshock', 'oilex', 'rotopad', 'selecta', 'tims', 'nomi_2', 'dreid', 'clockwise', 'nodeoline', 'folk']
EMBLEM = {'Ibishu': 'ibishu', 'Hirochi': 'hirochi_1'}
def sponsors(model, n=3):
    i = MODELS.index(model) * 3
    return [SPONSORS[(i + k) % len(SPONSORS)] for k in range(n)]
