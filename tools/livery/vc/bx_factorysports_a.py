from vcsvg import Doc
D = Doc('bx')
KS = 'KaushanScript-Regular.ttf'; RB = 'RobotoCondensed.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
# Werksstreifen unter der Fensterlinie: duenn ab Vordertuer, breiter nach hinten, mit Blitz-Unterbrechung
x0, x1 = 336, 884
def top(x): return 102 - (x - x0) * 0.022
def w(x): return 2.5 + (x - x0) / (x1 - x0) * 19
def seg(a, b, ca=0, cb=0):
    # Abschnitt a..b, Enden schraeg geschnitten (ca/cb = Versatz unten nach vorne)
    return P([(a, top(a)), (b, top(b)), (b - cb, top(b) + w(b)), (a - ca, top(a) + w(a))])
S2 = 'Farbe_2_Werksstreifen_GRUEN'
D.side(S2, seg(x0, 600, 0, 10), 2)
# Blitz: drei schraege Keile, die nach hinten breiter werden (wie der Werks-Blitz am Heck)
for a, b in ((612, 628), (642, 664), (680, 708)):
    D.side(S2, seg(a, b, 10, 10), 2)
D.side(S2, seg(722, x1, 10, 0), 2)
# Begleit-Nadelstreifen in Farbe 3 darunter, laeuft unter dem Blitz aus
S3 = 'Farbe_3_Nadelstreifen_BLAU'
def pin(a, b, off, th):
    return P([(a, top(a) + w(a) + off), (b, top(b) + w(b) + off), (b, top(b) + w(b) + off + th), (a + 30, top(a) + w(a) + off + th)])
D.side(S3, pin(420, 712, 5, 2.2), 3)
# Schriftzug am hinteren Kotfluegel ueber dem Streifen, Farbe 3
D.side_text(S3.replace('Nadelstreifen', 'Schrift'), 'Ibishu Tecnica', KS, 12, 812, 121, 3, rot=2)
D.side_text(S3.replace('Nadelstreifen', 'Schrift'), 'TWINCAM 16 VALVE', RB, 6.5, 392, 118, 3, track=0.25)
D.write('bx_factorysports_a')
