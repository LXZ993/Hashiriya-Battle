# Manga-Speed: Rasterpunkte (Farbe 2), die nach hinten groesser werden, Speedlines (Farbe 3) von hinten nach vorn,
# Soundwort in Katakana mit Explosions-Blase (feste Farben Gelb/Schwarz/Weiss wie im Manga).
import math, random
from shapely.geometry import Point, Polygon, box
from shapely import affinity
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
DELA = 'DelaGothicOne-Regular.ttf'
YEL, INK, PAPER = '#ffd21a', '#111111', '#fbfbf6'
S2, S3, F = 'Farbe_2_Rasterpunkte_GRUEN', 'Farbe_3_Speedlines_BLAU', 'Fest_Soundwort'
def halftone(region, x0, x1, step=9, rmax=4.6, axis=0):
    dots = []
    bx0, by0, bx1, by1 = region.bounds
    for j in range(int((by1 - by0) / step) + 3):
        for i in range(int((bx1 - bx0) / step) + 3):
            x = bx0 + i * step + (step / 2 if j % 2 else 0); y = by0 + j * step
            t = ((x if axis == 0 else y) - x0) / (x1 - x0)
            if t <= 0.03: continue
            r = rmax * min(1, t) ** 1.2
            dots.append(Point(x, y).buffer(r, 10))
    return union(*dots).intersection(region)
def speedlines(n, xa, xb, ya, yb, seed=1, wmax=3.2):
    rnd = random.Random(seed); out = []
    for k in range(n):
        y = ya + (yb - ya) * (k + rnd.random() * 0.6) / n
        x1 = xb + 20; x0 = xa + rnd.random() * (xb - xa) * 0.55
        w = wmax * (0.4 + rnd.random() * 0.6)
        out.append(pg([(x0, y), (x1, y - w / 2), (x1, y + w / 2)]))
    return union(*out)
def burst(cx, cy, r0, r1, n=14, seed=3):
    rnd = random.Random(seed); pts = []
    for i in range(n * 2):
        a = math.pi * i / n; r = (r1 if i % 2 == 0 else r0) * (0.85 + rnd.random() * 0.3)
        pts.append((cx + math.cos(a) * r * 1.45, cy + math.sin(a) * r))
    return pg(pts)
P = {'bx': dict(sfx='ドーン', ex='!!', bx=540, front=False, seed=1), 'sunburst2': dict(sfx='ズバァ', ex='!', bx=330, front=True, seed=5),
     'sbr': dict(sfx='ギャアア', ex='!!', bx=470, front=False, seed=9), 'midsize': dict(sfx='ブォン', ex='!?', bx=420, front=True, seed=13)}.get(M)
if P['front']:   # Raster vom Bug nach hinten auslaufend, Speedlines vorn
    body = box(-20, 104, 560, 214)
    D.side(S2, to_d(union(halftone(body, 560, 140, step=7.5, rmax=4.4), box(-20, 104, 100, 214))), 2)
else:
    body = box(330, 104, L + 20, 214)
    D.side(S2, to_d(union(halftone(body, 330, 760, step=7.5, rmax=4.4), box(800, 104, L + 20, 214))), 2)
D.side(S3, to_d(speedlines(26, 90, L, 106, 212, seed=P['seed'], wmax=6)), 3)
b = burst(P['bx'], 152, 40, 64, n=16, seed=P['seed'])
D.side(F, to_d(b.buffer(2.5)), INK); D.side(F, to_d(b), PAPER)
fs = 50 if len(P['sfx']) <= 3 else 40
D.side_text(F, P['sfx'], DELA, fs, P['bx'], 152, YEL, rot=-7, stroke=INK, sw=5)
D.side_text(F, P['ex'], DELA, 30, P['bx'] + 120, 128, YEL, rot=-7, stroke=INK, sw=4)
D.top(S2, to_d(halftone(box(-20, 600, TW + 20, 920), 600, 880, axis=1)), 2)
D.top(S3, to_d(union(*[pg([(TW * f - 2, 300), (TW * f + 2, 300), (TW * f, 20 + 60 * abs(f - 0.5))]) for f in (0.2, 0.3, 0.4, 0.6, 0.7, 0.8)])), 3)
D.write('bx_manga_a')
