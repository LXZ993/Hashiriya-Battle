from vcsvg import Doc
from txt import text
from vcsvg import KEYC
D = Doc('bx')
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
def PL(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
# Geteilter Lack wie auf deinem pink/blau-Bild: vorne Farbe 2, hinten Farbe 1, Grenze = Zickzack-Pfeil nach vorne
Z = [(610, -20), (440, 7.8), (590, 20.7), (420, 33.5), (580, 46.3), (392, 59.2), (566, 72.0), (352, 84.8), (552, 97.7), (382, 110.5), (560, 123.3), (360, 136.2), (556, 149.0), (400, 161.8), (566, 174.7), (430, 187.5), (585, 200.3), (445, 213.2), (600, 226), (604, 240)]
D.side('Farbe_2_Vorderteil_GRUEN', P([(-5, -5)] + Z + [(-5, 225)]), 2)
# weisses Begleitband (Farbe 3): Linie entlang der ganzen Grenze, liegt UNTER Farbe 2, damit nur die hintere Haelfte
# sichtbar ist -> ueberall gleich breit, von der Dachkante bis unter den Schweller
B = 6
lid = 'Farbe_3_Zickzackband_BLAU'
D.layers.insert(0, (lid, []))
Zx = Z
for dd in (PL(Zx), D.mv(PL(Zx), 0, D.RY, fx=True, w=D.lw)):
    D.layer(lid).append((dd, 'none', KEYC[3], 2 * B))
# Haube + vorderes Dach von oben in Farbe 2, Grenze quer ueber das Dach ebenfalls als Zickzack (Zacken nach vorne)
tw = D.tw; RZ = [(-20, 610)]
k = 7
for i in range(k):
    RZ.append(((i + 0.5) * tw / k, 515 + (i % 2) * 12))
    RZ.append(((i + 1) * tw / k if i < k - 1 else tw + 20, 610))
D.top('Farbe_2_Vorderteil_GRUEN', P([(-20, -5), (tw + 20, -5)] + RZ[::-1]), 2)
D.layer(lid).append((D.mv(PL(RZ), D.TX, 0), 'none', KEYC[3], 2 * B))
D.write('bx_bosozoku_a')
