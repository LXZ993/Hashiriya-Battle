# Kaido-Racer (Variante 0 abgenommen), Nummer und Katakana je Auto aus cars.py
from vcsvg import Doc
from txt import text
from cars import variant, CAR
import math
D = Doc(); V = variant(D.model, 'kaido_a'); C = CAR[D.model]
SM, ZK = 'ShipporiMincho-ExtraBold.ttf', 'ZenKakuGothicNew-Black.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
def ring(cx, cy, r, w, n=48):
    o = [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    i_ = [(cx + (r - w) * math.cos(-2 * math.pi * i / n), cy + (r - w) * math.sin(-2 * math.pi * i / n)) for i in range(n)]
    return P(o) + ' ' + P(i_)
N, K = 'Farbe_2_Nummer_Schrift_GRUEN', 'Farbe_3_Seitenstreifen_BLAU'
L = D.lw
if V == 0:
    y, th = 160, 5
    D.side(K, P([(-20, y), (L + 20, y - 4), (L + 20, y - 4 + th), (-20, y + th)]), 3)
    D.side_text(N, C['num'], SM, 52, 482, 128, 2, track=0.02)
    D.side_text(N, C['kata'], ZK, 13, 778, 112, 2, track=0.02)
    d, *_ = text(C['num'], SM, 56, D.tw * 0.25, 120, rot=-90); D.top(N, d, 2)
elif V == 1:
    # doppelte Zierlinie auf der Guertellinie, Nummer im Kreis auf der Vordertuer, Katakana auf der Hintertuer
    for yy, th in ((116, 3), (122, 1.6)):
        D.side(K, P([(-20, yy), (L + 20, yy - 6), (L + 20, yy - 6 + th), (-20, yy + th)]), 3)
    D.side(K.replace('Seitenstreifen', 'Kreis'), ring(400, 150, 33, 4), 3)
    D.side_text(N, C['num'], SM, 40, 400, 150, 2, track=0.02)
    D.side_text(N, C['kata'], ZK, 12, 560, 132, 2, track=0.02)
    D.top(K.replace('Seitenstreifen', 'Kreis'), ring(D.tw / 2, 130, 40, 5), 3)
    d, *_ = text(C['num'], SM, 46, D.tw / 2, 132, rot=180); D.top(N, d, 2)
else:
    # Nase in Farbe 3 bis hinter den vorderen Radlauf (schraeg), tiefe Linie, Nummer hinten, Katakana vorne
    D.side(K.replace('Seitenstreifen', 'Front'), P([(-20, -20), (280, -20), (250, 104), (300, 240), (-20, 240)]), 3)
    y, th = 182, 4
    D.side(K, P([(280, y), (L + 20, y - 2), (L + 20, y - 2 + th), (283, y + th)]), 3)
    D.side_text(N, C['num'], SM, 50, 560, 140, 2, track=0.02)
    D.side_text(N, C['kata'], ZK, 12, 420, 118, 2, track=0.02)
    D.top(K.replace('Seitenstreifen', 'Front'), P([(-20, -20), (D.tw + 20, -20), (D.tw + 20, 250), (-20, 250)]), 3)
    d, *_ = text(C['num'], SM, 44, D.tw / 2, 120, rot=180); D.top(N, d, 1)
D.write('bx_kaido_a')
