from vcsvg import Doc
from txt import text
D = Doc('bx')
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
def PL(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
# Geteilter Lack wie auf deinem pink/blau-Bild: vorne Farbe 2, hinten Farbe 1, Grenze = Zickzack-Pfeil nach vorne
Z = [(610, -5), (606, 84), (372, 112), (540, 128), (398, 168), (600, 182), (612, 225)]
D.side('Farbe_2_Vorderteil_GRUEN', P([(-5, -5)] + Z + [(-5, 225)]), 2)
# weisses Begleitband (Farbe 3) entlang der Grenze, auf der hinteren Seite
band = [(x + 16, y) for x, y in Z[1:-1]]
from vcsvg import KEYC
lid = 'Farbe_3_Zickzackband_BLAU'
for dd in (PL(band),):
    D.layer(lid).append((dd, 'none', KEYC[3], 9))
    D.layer(lid).append((D.mv(dd, 0, D.RY, fx=True, w=D.lw), 'none', KEYC[3], 9))
# Haube + vorderes Dach von oben in Farbe 2, Grenze quer mit Band
D.top('Farbe_2_Vorderteil_GRUEN', P([(-5, -5), (D.tw + 5, -5), (D.tw + 5, 606), (-5, 606)]), 2)
D.layer(lid).append((D.mv(PL([(-5, 622), (D.tw + 5, 622)]), D.TX, 0), 'none', KEYC[3], 9))
D.write('bx_bosozoku_a')
