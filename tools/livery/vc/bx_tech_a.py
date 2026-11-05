# Werks-Tech: kantige Rennstreifen mit Schraegschnitten (moderner Werksteam-Look), Formen mit shapely
from shapely.geometry import Polygon, box
from shapely import affinity
from vcsvg import Doc
from cars import variant, CAR
from tribal import to_d, union
D = Doc(); V = variant(D.model, 'tech_a'); C = CAR[D.model]
L, TW = D.lw, D.tw
RB = 'RobotoCondensed.ttf'
S2, S3, K = 'Farbe_2_Hauptstreifen_GRUEN', 'Farbe_3_Akzent_BLAU', 'Schwarz_Details'
def pg(pts): return Polygon(pts).buffer(0)
def slant(x, w, k=0.62, y0=60, y1=240):
    # schraeger Streifen, neigt nach hinten oben (k = dx/dy)
    return pg([(x, y1), (x + w, y1), (x + w + (y1 - y0) * k, y0), (x + (y1 - y0) * k, y0)])
if V == 0:
    # duenne Linie auf Tuerhoehe, steigt schraeg in einen breiten Keil, der hinten spitz an der Fensterlinie ausläuft
    band = pg([(250, 151), (480, 150), (540, 106), (L + 20, 97), (L + 20, 102), (760, 122), (610, 142), (556, 158), (262, 158)])
    k = 60 / 44
    cuts = union(*[slant(548 + i * 15, 8, k, 100, 165) for i in range(5)])
    fr = union(*[slant(300 + i * 11, 5, k, 140, 170) for i in range(4)])
    allc = union(cuts, fr)
    D.side(S2, to_d(band.difference(allc.buffer(1.6))), 2)
    D.side(S3, to_d(allc.intersection(band.buffer(-2.4))), 3)
    pin = pg([(266, 163), (560, 163.5), (614, 147), (762, 127), (L + 20, 107), (L + 20, 109.5), (763, 129.6), (615, 149.6), (561, 166), (270, 165.5)])
    D.side(K, to_d(pin), 'k')
    D.side_text(K, C['maker'].upper() + '  RACING DEVELOPMENT', RB, 6.5, 420, 176, 'k', track=0.2)
    x = TW * 0.63
    D.top(S2, to_d(box(x, -20, x + 26, 920)), 2)
    D.top(S3, to_d(box(x + 31, -20, x + 34, 920)), 3)
elif V == 1:
    # Schicht-Balken: parallele Balken, hinten 45-Grad-Stufe nach oben, Unterbalken mit Segmenten, Kontur-Balken oben
    def stepbar(x0, y, th, xs=690, rise=26, x1=L + 20, cut=0.8):
        return pg([(x0 + th * cut, y), (xs, y), (xs + rise, y - rise), (x1, y - rise), (x1, y - rise + th), (xs + rise + th * 0.41, y - rise + th), (xs + th * 0.41, y + th), (x0, y + th)])
    main = stepbar(282, 144, 14, xs=566, rise=22)
    D.side(S2, to_d(main), 2)
    D.side(K, to_d(stepbar(264, 134, 4, xs=556, rise=22)), 'k')
    low = pg([(306, 164), (600, 164), (592, 172), (300, 172)])
    gaps = union(*[slant(318 + i * 20, 3, 0.8, 150, 190) for i in range(5)])
    D.side(S3, to_d(low.difference(gaps)), 3)
    ol = stepbar(430, 126, 9, xs=544, rise=22)
    D.side(S3, to_d(ol.difference(ol.buffer(-1.8))), 3)
    D.side_text(K, C['maker'].upper() + '  WORKS TEAM', RB, 6.5, 420, 184, 'k', track=0.2)
    x = TW * 0.3
    D.top(S2, to_d(box(x - 30, -20, x - 8, 920)), 2)
    D.top(K, to_d(box(x - 4, -20, x, 920)), 'k')
    D.top(S3, to_d(box(x + 4, -20, x + 6, 920)), 3)
elif V == 2:
    # Pfeilband: Band auf Tuerhoehe zwischen zwei Linien, hinten Pfeile nach vorn, vorn massiv und spitz auslaufend
    def yl(x, y0): return y0 - x * 0.008
    def hl(y0, th, a=-20, b=L + 20): return pg([(a, yl(a, y0)), (b, yl(b, y0)), (b, yl(b, y0) + th), (a, yl(a, y0) + th)])
    D.side(K, to_d(hl(141, 2.6, 96)), 'k')
    D.side(K, to_d(hl(171, 2.6, 96)), 'k')
    top, bot = 147, 166
    solid = pg([(262, yl(262, (top + bot) / 2)), (300, yl(300, top)), (440, yl(440, top)), (432, yl(432, bot)), (300, yl(300, bot))])
    D.side(S2, to_d(solid), 2)
    ch = []
    for i in range(9):
        x = 452 + i * 19; d, t = 8, 10
        yt, ym, yb = yl(x, top), yl(x, (top + bot) / 2), yl(x, bot)
        ch.append(pg([(x + d, yt), (x + d + t, yt), (x + t, ym), (x + d + t, yb), (x + d, yb), (x, ym)]))
    D.side(S2, to_d(union(*ch)), 2)
    D.side(S3, to_d(hl(177, 4.5, 300, 606).difference(union(*[slant(530 + i * 14, 4, 0.6, 160, 190) for i in range(5)]))), 3)
    D.side_text(K, C['maker'].upper() + '  RACING', RB, 7, 360, 134, 'k', track=0.25)
    x = TW * 0.5
    for sg in (-1, 1):
        D.top(S2, to_d(box(x + sg * 80, -20, x + sg * 94, 920)), 2)
        D.top(S3, to_d(box(x + sg * 74, -20, x + sg * 76.5, 920)), 3)
else:
    # Zielflagge: massives Band hinten, loest sich nach vorn in immer schmalere Karos auf
    def yl(x, y0): return y0 - x * 0.008
    top, th, xs = 140, 27, 530
    def quad(a, b, y0, y1): return pg([(a, yl(a, y0)), (b, yl(b, y0)), (b, yl(b, y1)), (a, yl(a, y1))])
    D.side(S2, to_d(quad(xs, L + 20, top, top + th)), 2)
    sq, x, c = [], xs, 0
    while c < 24:
        w = 9.5 * 0.95 ** c
        for r in range(3):
            if (c + r) % 2 == 1: sq.append(quad(x - w, x, top + r * th / 3, top + (r + 1) * th / 3))
        x -= w; c += 1
    D.side(S2, to_d(union(*sq)), 2)
    D.side(S3, to_d(quad(x, L + 20, top + th + 4, top + th + 7)), 3)
    D.side_text(K, C['maker'].upper() + '  MOTORSPORT', RB, 7, 470, yl(470, top) - 7, 'k', track=0.25)
    x0 = TW * 0.5 - 112
    D.top(S2, to_d(box(x0, 78, x0 + 30, 920)), 2)
    D.top(S2, to_d(union(*[box(x0 + i * 10, 18 + j * 10, x0 + i * 10 + 10, 28 + j * 10) for i in range(3) for j in range(6) if (i + j) % 2 == 0])), 2)
    D.top(S3, to_d(box(x0 + 34, 18, x0 + 37, 920)), 3)
D.write('bx_tech_a')
