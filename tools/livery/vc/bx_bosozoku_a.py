# Bosozoku: geteilter Lack mit spitzem Zickzack (Variante 0 abgenommen), 3 Formvarianten
from vcsvg import Doc
from offset import band
from cars import variant
D = Doc(); V = variant(D.model, 'bosozoku_a')
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
F2, F3, B = 'Farbe_2_Vorderteil_GRUEN', 'Farbe_3_Zickzackband_BLAU', 6
tw, L = D.tw, D.lw
if V == 0:
    # vorne Farbe 2, Grenze = Zickzack mit Spitzen nach vorne, quer ueber Saeule und Dach
    Z = [(610, -20), (450, 14.2), (575, 33.5), (430, 52.8), (565, 72.0), (410, 91.2), (560, 110.5), (420, 129.8), (565, 149.0), (440, 168.2), (575, 187.5), (455, 206.8), (600, 226), (604, 240)]
    D.side(F2, P([(-5, -5)] + Z + [(-5, 225)]), 2)
    D.side(F3, P(band(Z, B, (1, 0))), 3)
    RZ = [(-20, 610)]; k = 6
    for i in range(k):
        RZ.append(((i + 0.5) * tw / k, 520)); RZ.append(((i + 1) * tw / k if i < k - 1 else tw + 20, 610))
    D.top(F2, P([(-20, -5), (tw + 20, -5)] + RZ[::-1]), 2)
    D.top(F3, P(band(RZ, B, (0, 1))), 3)
elif V == 1:
    # hinten Farbe 2, Zickzack mit Spitzen nach hinten (8 feinere Zaehne), quer ueber das Dach
    n, y0, y1 = 8, -5, 226
    Z = [(372, -20)]
    for i in range(n):
        ya = y0 + (y1 - y0) * (i + 0.5) / n; yb = y0 + (y1 - y0) * (i + 1) / n
        Z += [(470 - 12 * abs(i - 3.5), ya), (360 + 6 * abs(i - 3.5), yb)]
    Z += [(356, 240)]
    D.side(F2.replace('Vorderteil', 'Heckteil'), P(Z + [(L + 20, 240), (L + 20, -20)]), 2)
    D.side(F3, P(band(Z, B, (-1, 0))), 3)
    RZ = [(-20, 360)]; k = 7
    for i in range(k):
        RZ.append(((i + 0.5) * tw / k, 450)); RZ.append(((i + 1) * tw / k if i < k - 1 else tw + 20, 360))
    D.top(F2.replace('Vorderteil', 'Heckteil'), P(RZ + [(tw + 20, 980), (-20, 980)]), 2)
    D.top(F3, P(band(RZ, B, (0, -1))), 3)
else:
    # Unterteil Farbe 2, waagrechter Zickzack mit Spitzen nach oben, rundum von Stossstange zu Stossstange
    n = 16; ya, yb = 118, 160
    Z = [(-20, yb)]
    for i in range(n):
        Z += [((i + 0.5) * (L + 40) / n - 20, ya + (i % 2) * 8), ((i + 1) * (L + 40) / n - 20, yb)]
    D.side(F2.replace('Vorderteil', 'Unterteil'), P(Z + [(L + 20, 240), (-20, 240)]), 2)
    D.side(F3, P(band(Z, B, (0, -1))), 3)
D.write('bx_bosozoku_a')
