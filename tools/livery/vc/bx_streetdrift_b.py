# Street Drift B: Team-Schriftzug + duennes Tribal + Sponsoren (Variante 0 abgenommen), Texte je Auto aus cars.py
from vcsvg import Doc
from flame import tongue
from txt import text
from cars import variant, CAR, sponsors
D = Doc(); V = variant(D.model, 'streetdrift_b'); C = CAR[D.model]; SP = sponsors(D.model)
KS, RC, RB = 'KaushanScript-Regular.ttf', 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
if V == 0:   # Tribal hinten, Schriftzug ueber dem hinteren Kotfluegel
    tri = [tongue([(430, 112), (520, 104), (640, 102), (760, 90), (840, 84), (866, 94), (854, 102)], 13, head=0.3, bulge=0.5),
           tongue([(470, 108), (540, 116), (640, 124), (720, 116), (760, 104), (774, 112)], 11, head=0.3),
           tongue([(500, 110), (560, 128), (640, 146), (700, 146), (730, 134), (726, 128)], 9, head=0.3),
           tongue([(520, 112), (580, 140), (630, 164), (670, 168), (692, 158)], 7, head=0.3)]
    sx, sy, rot, tx, ty, txr = 585, 126, 7, 482, 98, 210
    stk = [(SP[0], 14, 368, 116), (SP[1], 10, 368, 134), (SP[2], 12, 842, 150)]
elif V == 1:  # Tribal ab Vordertuer, Schriftzug auf der Tuer, Sponsoren hinten
    tri = [tongue([(230, 104), (330, 98), (450, 96), (560, 92), (630, 86), (652, 96), (640, 102)], 12, head=0.3, bulge=0.5),
           tongue([(260, 106), (330, 114), (420, 124), (500, 120), (540, 110), (552, 118)], 10, head=0.3),
           tongue([(280, 108), (340, 128), (410, 146), (460, 146), (486, 136)], 8, head=0.3)]
    sx, sy, rot, tx, ty, txr = 440, 140, 5, 340, 116, 520
    stk = [(SP[0], 14, 790, 120), (SP[1], 10, 790, 138), (SP[2], 11, 690, 172)]
else:         # kein Seitentribal, grosser Schriftzug flach, Tribal nur auf der Haube, Sponsoren-Stapel vorne
    tri = []
    sx, sy, rot, tx, ty, txr = 560, 134, 0, 470, 108, 300
    stk = [(SP[0], 14, 360, 114), (SP[1], 10, 360, 131), (SP[2], 10, 360, 146)]
for t in tri: D.side('Farbe_3_Tribal_BLAU', t, 3)
D.side_text('Farbe_2_Schriftzug_GRUEN', C['team'], KS, 42, sx, sy, 2, rot=rot, stroke=1, sw=7)
D.side_text('Schwarz_Sticker', 'Team', KS, 19, tx, ty, 'k', rot=rot, stroke=1, sw=4, xr=D.lw - 2 * sx + tx, yr=ty)
for s, h, x, y in stk: D.side_logo('Schwarz_Sticker', s, x, y, h)
cx = D.tw / 2
if V == 2:
    hood = [tongue([(30, 20), (40, 100), (54, 190), (72, 280)], 20, head=0.25, bulge=0.6),
            tongue([(54, 30), (64, 100), (76, 160), (88, 210)], 13, head=0.2),
            tongue([(76, 36), (86, 84), (96, 124)], 8, head=0.2)]
else:
    hood = [tongue([(40, 24), (48, 100), (58, 190), (72, 268)], 16, head=0.25, bulge=0.6),
            tongue([(60, 40), (70, 110), (82, 170), (92, 222)], 10, head=0.2)]
for t in hood: D.top('Farbe_3_Tribal_BLAU', t, 3, mirror=True)
d, *_ = text(C['team'].upper(), RC, 16, cx, 52, rot=180, track=0.08)
D.top('Schwarz_Sticker', d, 'k')
D.write('bx_streetdrift_b')
