from vcsvg import Doc
from txt import text
from vcsvg import KEYC
D = Doc()
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
def PL(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
# Geteilter Lack wie auf deinem pink/blau-Bild: vorne Farbe 2, hinten Farbe 1, Grenze = Zickzack-Pfeil nach vorne
Z = [(610, -20), (450, 14.2), (575, 33.5), (430, 52.8), (565, 72.0), (410, 91.2), (560, 110.5), (420, 129.8), (565, 149.0), (440, 168.2), (575, 187.5), (455, 206.8), (600, 226), (604, 240)]
D.side('Farbe_2_Vorderteil_GRUEN', P([(-5, -5)] + Z + [(-5, 225)]), 2)
# weisses Begleitband (Farbe 3): eigene Flaeche mit gleicher Breite und echten Spitzen (Gehrung) an jeder Ecke
from offset import band
B = 6
lid = 'Farbe_3_Zickzackband_BLAU'
D.side(lid, P(band(Z, B, (1, 0))), 3)
# Haube + vorderes Dach von oben in Farbe 2, Grenze quer ueber das Dach ebenfalls als Zickzack (Zacken nach vorne)
tw = D.tw; RZ = [(-20, 610)]
k = 6
for i in range(k):
    RZ.append(((i + 0.5) * tw / k, 520))
    RZ.append(((i + 1) * tw / k if i < k - 1 else tw + 20, 610))
D.top('Farbe_2_Vorderteil_GRUEN', P([(-20, -5), (tw + 20, -5)] + RZ[::-1]), 2)
D.top(lid, P(band(RZ, B, (0, 1))), 3)
D.write('bx_bosozoku_a')
