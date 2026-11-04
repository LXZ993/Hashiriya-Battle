from vcsvg import Doc
from txt import text
from vcsvg import KEYC
D = Doc('bx')
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
def PL(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
# Geteilter Lack wie auf deinem pink/blau-Bild: vorne Farbe 2, hinten Farbe 1, Grenze = Zickzack-Pfeil nach vorne
Z = [(610, -5), (606, 84), (392, 95.8), (566, 107.7), (352, 119.5), (552, 131.3), (382, 143.2), (560, 155.0), (360, 166.8), (556, 178.7), (400, 190.5), (566, 202.3), (430, 214.2), (600, 226), (604, 240)]
D.side('Farbe_2_Vorderteil_GRUEN', P([(-5, -5)] + Z + [(-5, 225)]), 2)
# weisses Begleitband (Farbe 3): Linie entlang der ganzen Grenze, liegt UNTER Farbe 2, damit nur die hintere Haelfte
# sichtbar ist -> ueberall gleich breit, von der Dachkante bis unter den Schweller
B = 6
lid = 'Farbe_3_Zickzackband_BLAU'
D.layers.insert(0, (lid, []))
Zx = [(Z[0][0], -20)] + Z[1:-1] + [(Z[-1][0] + 2, 238)]
for dd in (PL(Zx), D.mv(PL(Zx), 0, D.RY, fx=True, w=D.lw)):
    D.layer(lid).append((dd, 'none', KEYC[3], 2 * B))
# Haube + vorderes Dach von oben in Farbe 2, Grenze quer mit Band
D.top('Farbe_2_Vorderteil_GRUEN', P([(-5, -5), (D.tw + 5, -5), (D.tw + 5, 606), (-5, 606)]), 2)
D.top('Farbe_3_Zickzackband_BLAU', P([(-5, 606), (D.tw + 5, 606), (D.tw + 5, 606 + B), (-5, 606 + B)]), 3)
D.write('bx_bosozoku_a')
