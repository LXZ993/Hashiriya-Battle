# Werks-Zweifarben (Variante 0 abgenommen), 3 Formvarianten, Ausstattungs-Schriftzug je Auto
from vcsvg import Doc
from cars import variant, CAR
D = Doc(); V = variant(D.model, 'twotone_a'); C = CAR[D.model]
RB = 'RobotoCondensed.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
X0, X1 = -20, D.lw + 20
def strip(y0, rise, a, b):   # Band zwischen Abstand a und b unter der Linie y0 (steigt nach hinten um rise)
    yl = lambda x, o: y0 + rise * (x - X0) / (X1 - X0) + o
    return P([(X0, yl(X0, a)), (X1, yl(X1, a)), (X1, yl(X1, b)), (X0, yl(X0, b))])
U, Z = 'Farbe_2_Unterteil_GRUEN', 'Farbe_3_Zierstreifen_BLAU'
if V == 0:
    D.side(U, strip(162, -4, 0, 70), 2)
    D.side(Z, strip(162, -4, -2, 2), 3)
elif V == 1:
    # Dach und Saeulen in Farbe 2, Zierlinie auf der Guertellinie
    U = 'Farbe_2_Dach_GRUEN'
    D.side(U, P([(290, -20), (775, -20), (775, 96), (290, 98)]), 2)
    D.top(U, P([(-20, 330), (D.tw + 20, 330), (D.tw + 20, 690), (-20, 690)]), 2)
    D.side(Z, strip(101, -6, 0, 3), 3)
else:
    # unten Farbe 2, darueber ein breites Zierband in Farbe 3 mit Abstand
    D.side(U, strip(172, -4, 0, 70), 2)
    D.side(Z, strip(172, -4, -18, -8), 3)
if V: D.side_text(Z.replace('Zierstreifen', 'Schrift'), C['script'].upper(), RB, 7, 820, 128 if V != 1 else 140, 3, track=0.3)
D.write('bx_twotone_a')
