# Kanjo-Zoku (Osaka-Loop, 90er): fast schlichter Lack, Warnstreifen (fest Gelb/Schwarz) an der Frontecke,
# Team-Schriftzug in Weiss mit schwarzem Rand, kleine Aufkleber-Wolke hinten, Wakaba-Marke, Schwellerlinie Farbe 2.
from shapely.geometry import box, Polygon
from shapely import affinity
from vcsvg import Doc
from cars import CAR
from tribal import to_d, union
from lore_common import pg
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
ZK, DELA, RB, RS = 'ZenKakuGothicNew-Black.ttf', 'DelaGothicOne-Regular.ttf', 'RobotoCondensed.ttf', 'RacingSansOne-Regular.ttf'
YEL, INK, WHITE, GRN = '#f4c20d', '#111111', '#f7f7f2', '#2e9e48'
P = {'covet': dict(team='環状 夜行会', sub='KANJO NIGHT CLUB', n='07'), 'pessima': dict(team='環状 鬼走連', sub='LOOP DEVILS', n='11'),
     'midsize': dict(team='阪神 疾風会', sub='HANSHIN HAYATE', n='24'), 'bx': dict(team='環状 狼団', sub='OSAKA WOLVES', n='03')}.get(M, dict(team='環状 夜行会', sub='KANJO NIGHT CLUB', n='07'))
S2, F = 'Farbe_2_Schwellerlinie_GRUEN', 'Fest_Aufkleber'
REAR = M in ('pessima', 'bx')   # Warnstreifen hinten, Schriftzug vorn
D.side(S2, to_d(box(-20, 196, L + 20, 203)), 2)
# Warnstreifen an der vorderen Stossstangenecke
hz = box(L - 110, 172, L + 20, 214) if REAR else box(-20, 172, 110, 214)
stripes = union(*[pg([(x, 214), (x + 10, 214), (x + 52, 172), (x + 42, 172)]) for x in range(-80, int(L) + 40, 20)])
D.side(F, to_d(hz.buffer(1.2)), INK); D.side(F, to_d(hz), YEL); D.side(F, to_d(stripes.intersection(hz)), INK)
# Team-Schriftzug ueber dem hinteren Radlauf
TX = {'bx': 330}.get(M, 200) if REAR else 690
D.side_text(F, P['team'], DELA, 22, TX, 126, WHITE, stroke=INK, sw=4)
D.side_text(F, P['sub'], RB, 7, TX, 146, INK, track=0.4)
# Nummer an der Tuer, schlicht
D.side_text(F, P['n'], RS, 30, 470 if REAR else 450, 150 if not REAR else 128, WHITE, stroke=INK, sw=3)
# Aufkleber-Wolke (Lore-Logos, feste Farben)
for (lg, x, y, h, col) in (('rotopad', 800, 120, 8, INK), ('gripall', 820, 134, 8, INK), ('nomi_2', 790, 148, 8, '#d0262e'),
                           ('dreid', 830, 160, 7, INK), ('eshock', 800, 172, 7, '#1d63c9')):
    D.side_logo(F, lg, (x - 640 if REAR else x), y, h, key=col)
# Wakaba (Anfaenger-Marke) als Gag
wk = union(pg([(560, 168), (572, 176), (572, 194), (560, 186)]), pg([(584, 168), (572, 176), (572, 194), (584, 186)]))
D.side(F, to_d(wk.buffer(1)), INK)
D.side(F, to_d(pg([(560, 168), (572, 176), (572, 194), (560, 186)])), YEL); D.side(F, to_d(pg([(584, 168), (572, 176), (572, 194), (584, 186)])), GRN)
cx = TW / 2
D.top(F, to_d(box(cx - 60, 0, cx + 60, 26)), INK)
from txt import text
d, *_ = text(P['sub'], RB, 14, cx, 13, rot=180, track=0.2); D.top(F, d, WHITE)
D.write('bx_kanjo_a')
