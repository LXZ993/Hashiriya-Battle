# Gruppe C Retro (80er Langstrecke): Pfeil in Farbe 2 vom Bug bis zur Tuer, dreifache Zierlinien (Farbe 3 + festes Gold)
# laufen die Pfeilkante entlang und dann gerade bis zum Heck. Weisser Startnummern-Kreis, Sponsoren in festen Farben.
from shapely.geometry import Point, Polygon, box, LineString
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
GOLD, WHITE, RED, INK = '#c9a24b', '#f7f7f2', '#c8202a', '#111111'
P = {'bx': dict(tip=380, y=150, sp=('oilex', 'nodeoline', 'clockwise'), dbl=False),
     'pessima': dict(tip=300, y=170, sp=('okudai', 'rotopad', 'dreid'), dbl=True),
     'midsize': dict(tip=440, y=132, sp=('nodeoline', 'oilex', 'gripall'), dbl=False)}.get(M, dict(tip=380, y=150, sp=('oilex', 'nodeoline', 'clockwise')))
S2, S3, G, F = 'Farbe_2_Pfeil_GRUEN', 'Farbe_3_Zierlinie_BLAU', 'Fest_Gold_Linie', 'Fest_Nummernkreis_Sponsoren'
tip, yc = P['tip'], P['y']
arrow = pg([(-20, 70), (tip - 120, 70), (tip, yc), (tip - 120, 240), (-20, 240)])
D.side(S2, to_d(arrow), 2)
if P['dbl']:   # zweiter, schmaler Pfeil dahinter (Doppelpfeil)
    D.side(S2, to_d(pg([(tip - 70, 70), (tip - 40, 70), (tip + 80, yc), (tip - 40, 240), (tip - 70, 240), (tip + 50, yc)])), 2)
def chevline(off, w):
    pts = [(tip - 120 + off, 70), (tip + off, yc), (L + 20, yc)]
    return LineString(pts).buffer(w / 2, cap_style=2, join_style=2).intersection(box(-20, 96, L + 20, 240))
def chevline_low(off, w):
    pts = [(tip - 120 + off, 240), (tip + off, yc), (L + 20, yc)]
    return LineString(pts).buffer(w / 2, cap_style=2, join_style=2).intersection(box(-20, 96, L + 20, 240))
D.side(S3, to_d(union(chevline(10, 4), chevline_low(10, 4))), 3)
D.side(G, to_d(union(chevline(18, 2.4), chevline_low(18, 2.4))), GOLD)
D.side(S3, to_d(union(chevline(25, 1.6), chevline_low(25, 1.6))), 3)
# Nummernkreis auf der Tuer
nx = tip + 110; c = Point(nx, yc - 2).buffer(28)
D.side(F, to_d(c.buffer(1.8)), INK); D.side(F, to_d(c), WHITE)
D.side_text(F, C['rnum'], RS, 34, nx, yc - 1, INK)
D.side_logo(F, P['sp'][0], tip + 225, yc - 24, 18, key=RED)
D.side_logo(F, P['sp'][1], tip + 225, yc + 26, 10, key=INK)
D.side_logo(F, P['sp'][2], 180, 200, 9, key=WHITE)
D.side_text(F, C['maker'] + ' · GROUP C · 1000 KM', RB, 6, tip + 225, yc + 42, INK, track=0.3)
# Draufsicht: Pfeil auf der Haube nach vorn, Linien bis zum Heck, Nummernkreis auf dem Dach
cx = TW / 2
D.top(S2, to_d(pg([(-20, -20), (TW + 20, -20), (TW + 20, 180), (cx, 330), (-20, 180)])), 2)
for off, w, key, lid in ((12, 4, 3, S3), (20, 2.4, GOLD, G), (27, 1.6, 3, S3)):
    D.top(lid, to_d(LineString([(-20, 180 + off), (cx, 330 + off), (TW + 20, 180 + off)]).buffer(w / 2, cap_style=2, join_style=2)), key)
rc = Point(cx, 500).buffer(48); D.top(F, to_d(rc.buffer(2)), INK); D.top(F, to_d(rc), WHITE)
d, *_ = text(C['rnum'], RS, 58, cx, 500, rot=180); D.top(F, d, INK)
D.write('bx_groupc_a')
