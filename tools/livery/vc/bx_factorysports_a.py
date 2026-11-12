# Werks-Sportstreifen (Variante 0 abgenommen), Texte je Auto aus cars.py
from vcsvg import Doc
from cars import variant, CAR
D = Doc(); V = variant(D.model, 'factorysports_a'); C = CAR[D.model]
KS = 'KaushanScript-Regular.ttf'; RB = 'RobotoCondensed.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
S2, S3 = 'Farbe_2_Werksstreifen_GRUEN', 'Farbe_3_Nadelstreifen_BLAU'
ST = S3.replace('Nadelstreifen', 'Schrift')
if V == 0:
    # duenn ab Vordertuer, breiter nach hinten, Blitz-Unterbrechung
    x0, x1 = 336, 884
    def top(x): return 102 - (x - x0) * 0.022
    def w(x): return 2.5 + (x - x0) / (x1 - x0) * 19
    def seg(a, b, ca=0, cb=0): return P([(a, top(a)), (b, top(b)), (b - cb, top(b) + w(b)), (a - ca, top(a) + w(a))])
    D.side(S2, seg(x0, 600, 0, 10), 2)
    for a, b in ((612, 628), (642, 664), (680, 708)): D.side(S2, seg(a, b, 10, 10), 2)
    D.side(S2, seg(722, x1, 10, 0), 2)
    def pin(a, b, off, th): return P([(a, top(a) + w(a) + off), (b, top(b) + w(b) + off), (b, top(b) + w(b) + off + th), (a + 30, top(a) + w(a) + off + th)])
    D.side(S3, pin(420, 712, 5, 2.2), 3)
    D.side_text(ST, C['script'], KS, 12, 812, 121, 3, rot=2)
    D.side_text(ST, C['engine'], RB, 6.5, 392, 118, 3, track=0.25)
elif V == 1:
    # zwei lange Klebestreifen ueber die ganze Seite, laufen hinten in Strichen aus
    def y(x): return 108 - x * 0.012
    def strip(a, b, off, th): return P([(a, y(a) + off), (b, y(b) + off), (b, y(b) + off + th), (a, y(a) + off + th)])
    D.side(S2, strip(-20, 640, 0, 7), 2)
    for i, (a, l) in enumerate(((652, 40), (702, 30), (742, 22), (774, 15), (798, 9))): D.side(S2, strip(a, a + l, 0, 7), 2)
    D.side(S3, strip(-20, 640, 10, 2.5), 3)
    for a, l in ((652, 40), (702, 30), (742, 22), (774, 15), (798, 9)): D.side(S3, strip(a, a + l, 10, 2.5), 3)
    D.side_text(ST, C['script'], KS, 13, 470, 136, 3)
    D.side_text(ST, C['engine'], RB, 6.5, 470, 150, 3, track=0.25)
else:
    # Hockeyschlaeger: unten auf der Tuer nach hinten, am hinteren Kotfluegel hoch bis unter die Fensterlinie
    th = 9
    path = [(-20, 152), (540, 150), (584, 142), (610, 120), (630, 102), (660, 96), (D.lw + 20, 88)]
    from offset import band
    D.side(S2, P(band(path, th, (0, 1))), 2)
    D.side(S3, P(band([(p[0], p[1] + th + 3) for p in path], 2.5, (0, 1))), 3)
    D.side_text(ST, C['script'], KS, 13, 420, 138, 3)
    D.side_text(ST, C['engine'], RB, 6.5, 200, 120, 3, track=0.25)
D.write('bx_factorysports_a')
