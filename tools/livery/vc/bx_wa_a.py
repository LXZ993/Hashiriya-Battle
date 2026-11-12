# Wa-Muster (Kimono/Obi-Stil): Pinselstrich-Band, das vorn spitz beginnt und nach hinten breit wird.
# Darin Seigaiha-Wellen (Farbe 2) auf Farbe 3, Goldkante und roter Hanko-Stempel als feste Farben, Kanji in Tusche.
import math
from shapely.geometry import Polygon, LineString, box, Point
from vcsvg import Doc
from cars import CAR
from tribal import to_d, union
from lore_common import pg
from wa_pat import seigaiha, asanoha, kikko
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
MIN = 'ShipporiMincho-ExtraBold.ttf'
GOLD, RED, INK = '#c9a24b', '#b3232b', '#111111'
S3, S2, G, R, K = 'Farbe_3_Bandgrund_BLAU', 'Farbe_2_Seigaiha_GRUEN', 'Fest_Gold_Kante', 'Fest_Rot_Stempel', 'Tusche_Kanji'
def bez(p0, p1, p2, p3, n=80):
    return [((1-t)**3*p0[0]+3*(1-t)**2*t*p1[0]+3*(1-t)*t*t*p2[0]+t**3*p3[0], (1-t)**3*p0[1]+3*(1-t)**2*t*p1[1]+3*(1-t)*t*t*p2[1]+t**3*p3[1]) for t in [i/n for i in range(n+1)]]
def stroke(pts, w0, w1, wob=0.0):
    """Pinselstrich entlang pts, Breite von w0 nach w1 (Potenzkurve), leicht gewellte Kanten."""
    up, dn = [], []
    for i, (x, y) in enumerate(pts):
        j = min(i + 1, len(pts) - 1); k = max(i - 1, 0)
        dx, dy = pts[j][0] - pts[k][0], pts[j][1] - pts[k][1]; ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln; t = i / (len(pts) - 1)
        w = (w0 + (w1 - w0) * t ** 0.7) / 2
        e1 = w * (1 + wob * math.sin(t * 19)); e2 = w * (1 + wob * math.sin(t * 23 + 1.3))
        up.append((x + nx * e1, y + ny * e1)); dn.append((x - nx * e2, y - ny * e2))
    return pg(up + dn[::-1])
P = {'bx':        dict(pat='seigaiha', p=((60, 206), (300, 200), (560, 150), (L + 30, 118)), w=(2, 82), kan='疾風', seal='走', kx=342),
     'miramar':   dict(pat='kikko', p=((L - 60, 210), (600, 205), (330, 150), (-30, 122)), w=(2, 76), kan='月光', seal='夜', kx=700),
     'pessima':   dict(pat='asanoha', p=((-30, 200), (250, 120), (560, 214), (L + 30, 140)), w=(60, 40), kan='雷電', seal='雷', kx=420),
     'midsize':   dict(pat='seigaiha', p=((-30, 128), (300, 128), (560, 200), (L + 30, 200)), w=(30, 70), kan='桜花', seal='桜', kx=470),
     'covet':     dict(pat='asanoha', p=((120, 214), (320, 214), (520, 120), (L + 30, 110)), w=(4, 90), kan='若葉', seal='若', kx=300),
     'sunburst2': dict(pat='kikko', p=((40, 140), (300, 210), (600, 210), (L + 30, 130)), w=(4, 70), kan='蒼天', seal='天', kx=430),
     'sbr':       dict(pat='seigaiha', p=((L - 40, 214), (560, 210), (300, 150), (-30, 110)), w=(90, 2), kan='龍神', seal='龍', kx=690)}.get(M)
PAT = {'seigaiha': lambda g: seigaiha(g, r=15, w=0.07), 'asanoha': lambda g: asanoha(g, s=20, w=1.4), 'kikko': lambda g: kikko(g, s=13, w=1.6)}[P['pat']]
path = bez(*P['p'])
band = stroke(path, *P['w'], wob=0.05)
D.side(S3, to_d(band), 3)
D.side(S2, to_d(PAT(band.buffer(-3))), 2)
D.side(G, to_d(band.buffer(2.2).difference(band)), GOLD)
# zweiter, duenner Strich darueber (Gold) als Echo
echo = bez(*[(x, y - 40 if y > 150 else y + 40) for x, y in P['p']])
D.side(G, to_d(stroke(echo, 1, 7).intersection(box(-20, 96, L + 20, 240))), GOLD)
# Hanko-Stempel mit ausgespartem Kanji
kx = P['kx']; seal = box(kx - 46, 112, kx - 18, 140).buffer(2)
from txt import text
D.side(R, to_d(seal), RED)
D.side_text('Fest_Stempel_Kanji', P['seal'], MIN, 20, kx - 32, 127, '#f4efe4')
for i, ch in enumerate(P['kan']): D.side_text(K, ch, MIN, 18, kx, 120 + i * 21, INK)
# Draufsicht: Strich diagonal ueber den Kofferraum und das Dach
tpath = bez((-20, 900), (TW * 0.3, 820), (TW * 0.6, 640), (TW + 20, 480))
tb = stroke(tpath, 70, 6, wob=0.05)
D.top(S3, to_d(tb), 3); D.top(S2, to_d(PAT(tb.buffer(-3))), 2); D.top(G, to_d(tb.buffer(2.2).difference(tb)), GOLD)
D.write('bx_wa_a')
