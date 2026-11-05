# Rallye Gruppe A. Eigenes Layout je Auto: Sunburst Schraegband rundum, Pessima Mk1 80er-Stufenstreifen,
# Pessima Mk2 grosser Schwung, Covet Bug mit Zielflaggen-Kante, Hopper Raid mit Bergkante. Sponsor je Auto.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg, band_f, below, rbox, outline, checker
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
MAIN = {'sunburst2': 'eshock', 'pessima': 'selecta', 'midsize': 'nomi_2', 'covet': 'nomi_2', 'hopper': 'eshock'}.get(M, 'eshock')
SUB = {'covet': 'gripall', 'midsize': 'oilex', 'pessima': 'gripall', 'hopper': 'rotopad'}.get(M, 'gripall')
S2, S3, W, K = 'Farbe_2_Grafik_GRUEN', 'Farbe_3_Kanten_BLAU', 'Farbe_1_Sponsor_Schilder_ROT', 'Schwarz_Nummern'
cx = TW / 2
def plate(x0, y0, x1, y1):
    pl = rbox(x0, y0, x1, y1, 5); D.side(W, to_d(pl), 1); D.side(K, to_d(outline(pl)), 'k')
    xm = (x0 + x1) / 2; D.side_text(K, 'SHUTO RALLY', RB, 6, xm, y0 + 10, 'k', track=0.2)
    D.side_text(K, C['rnum'], RS, min(34, (y1 - y0) * 0.55), xm, (y0 + y1) / 2 + 7, 'k')
def hood_plate(y=50):
    hp = rbox(cx - 60, y - 20, cx + 60, y + 20, 4); D.top(W, to_d(hp), 1); D.top(K, to_d(outline(hp)), 'k')
    d, *_ = text('SHUTO RALLY', RB, 14, cx, y, rot=180, track=0.15); D.top(K, d, 'k')
def roof_plate(y=490, key_bg=1):
    rp = rbox(cx - 40, y - 50, cx + 40, y + 50, 6); D.top(W, to_d(rp), 1); D.top(K, to_d(outline(rp, 2)), 'k')
    d, *_ = text(C['rnum'], RS, 56, cx, y, rot=180); D.top(K, d, 'k')
if M == 'pessima':   # 80er Gruppe A: Unterteil Farbe 2, drei Linien, die hinten nach oben steigen
    def step(y): return lambda x: y - (0 if x < 560 else min(1, (x - 560) / 80) * 22)
    D.side(S2, to_d(below(step(166))), 2)
    for y, w in ((148, 3), (155, 3), (161, 2.5)):
        D.side(S3, to_d(band_f(step(y), lambda x, y=y, w=w: step(y)(x) + w)), 3)
    plate(286, 92, 372, 140)
    D.side_logo(W, MAIN, 470, 190, 20, key=1)
    D.side_logo(K, SUB, 120, 120, 10)
    D.side_text(K, C['maker'] + ' RALLY TEAM', RB, 6.5, 470, 130, 'k', track=0.25)
    D.top(S2, to_d(union(box(cx - 90, -20, cx - 60, 920), box(cx + 60, -20, cx + 90, 920))), 2)
    hood_plate(); roof_plate()
elif M == 'midsize':   # grosser Schwung vom Vorderrad nach hinten oben
    bot = lambda x: 222 - 150 * ((x + 20) / 933) ** 1.3
    top = lambda x: bot(x) - 50
    D.side(S2, to_d(band_f(top, bot)), 2)
    D.side(S3, to_d(band_f(lambda x: top(x) - 7, lambda x: top(x) - 3)), 3)
    plate(286, 96, 368, 140)
    D.side_logo(W, MAIN, 600, top(600) + 25, 22, key=1)
    D.side_logo(K, SUB, 800, 190, 11)
    D.side_text(K, C['maker'] + ' WORLD RALLY TEAM', RB, 6.5, 330, 196, 'k', track=0.25)
    D.top(S2, to_d(pg([(-20, 300), (TW + 20, 200), (TW + 20, 520), (-20, 620)])), 2)
    hood_plate(); roof_plate(700)
elif M == 'covet':   # Bug Farbe 2 bis zur B-Saeule, Zielflaggen-Kante, Schild auf der hinteren Tuer
    D.side(S2, to_d(pg([(-20, -30), (420, -30), (400, 250), (-20, 250)])), 2)
    D.side(S3, to_d(checker(405, 90, 4, 12, 10)), 3)
    plate(286, 104, 372, 166)
    D.side_logo(W, MAIN, 190, 126, 16, key=1)
    D.side_logo(K, SUB, 700, 118, 10)
    D.side_text(W, C['maker'] + ' RALLY TEAM', RB, 6, 329, 180, 1, track=0.25)
    D.top(S2, to_d(box(-20, -20, TW + 20, 360)), 2)
    D.top(S3, to_d(checker(-10, 360, 37, 3, 10)), 3)
    hood_plate(); roof_plate()
elif M == 'hopper':   # Raid: Unterteil Farbe 2 mit Bergkante, Dachstreifen
    import math
    f = lambda x: 160 - 18 * abs(((x + 20) / 90) % 2 - 1) - 8 * math.sin(x / 47)
    D.side(S2, to_d(below(f)), 2)
    D.side(S3, to_d(band_f(lambda x: f(x) - 6, lambda x: f(x) - 3)), 3)
    plate(286, 92, 372, 138)
    D.side_logo(W, MAIN, 520, 192, 20, key=1)
    D.side_logo(K, SUB, 800, 116, 11)
    D.side_text(K, C['maker'] + ' RAID TEAM', RB, 6.5, 520, 122, 'k', track=0.25)
    D.top(S2, to_d(box(-20, 380, TW + 20, 440)), 2); D.top(S2, to_d(box(-20, 560, TW + 20, 620)), 2)
    hood_plate(); roof_plate(500)
else:   # Sunburst: breites Schraegband rundum mit Kanten, Mittelband ueber Haube/Dach
    def band(y0, y1, a=-20, b=L + 20, k=0.012): return Polygon([(a, y0 - a * k), (b, y0 - b * k), (b, y1 - b * k), (a, y1 - a * k)])
    D.side(S2, to_d(band(126, 162)), 2)
    D.side(S3, to_d(band(120, 123)), 3); D.side(S3, to_d(band(165, 168)), 3)
    pl = box(286, 108, 372, 176).buffer(-5).buffer(5)
    D.side(W, to_d(pl), 1); D.side(K, to_d(outline(pl)), 'k')
    D.side_text(K, 'SHUTO RALLY', RB, 6, 329, 118, 'k', track=0.2)
    D.side_text(K, C['rnum'], RS, 34, 329, 150, 'k')
    D.side_logo(W, MAIN, 520, 143, 24, key=1)
    D.side_logo(K, 'gripall', 820, 120, 12)
    D.side_text(K, C['maker'].upper() + ' RALLY TEAM', RB, 6.5, 520, 178, 'k', track=0.25)
    D.top(S2, to_d(box(cx - 46, -20, cx + 46, 920)), 2)
    D.top(S3, to_d(box(cx - 52, -20, cx - 49, 920)), 3); D.top(S3, to_d(box(cx + 49, -20, cx + 52, 920)), 3)
    hood_plate(); roof_plate()
D.write('bx_rally_a')
