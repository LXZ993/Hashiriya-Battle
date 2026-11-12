"""Percheron Kofferwagen, Dekotora B und C, jede mit eigenem Layout.
B: 富嶽丸 Fugaku-maru: goldgerahmte Namenstafel oben, darunter Fuji vor Abendrot-Streifen, Wasserlinien unten, Kiku-Wappen.
C: 錦鯉丸 Nishikigoi-maru: Teich mit Ringwellen und Seerosenblättern, zwei große Koi, Name senkrecht (tategaki) hinten.
Aufruf: python pc_dekotora_bc.py <ausgabe> -> <ausgabe>_b_L.svg ... _c_R.svg"""
import sys, math
import numpy as np
from shapely.geometry import Point, LineString, box as sbox
from shapely.ops import unary_union
from shapely import affinity
from txt import text
from pc_spedition_a import PPM, BL, BH, box_pt, cab_pt, bez
from pc_dekotora_a import pg, to_d, to_cab_d, SvgS, WALL, GOLD, ORANGE, RED, DRED, BLACK, WHITE, NAVY, BLUE

MINCHO = 'ShipporiMincho-ExtraBold.ttf'


def fxy(side):
    return (lambda u: box_pt(u, 0, side)[0]), (lambda v: box_pt(0, v, side)[1])


def kiku(cx, cy, r, n=16):
    """Chrysanthemen-Wappen: Mittelscheibe + n runde Blütenblätter."""
    petals = []
    for i in range(n):
        a = 2 * math.pi * i / n
        p = LineString([(cx + 0.35 * r * math.cos(a), cy + 0.35 * r * math.sin(a)), (cx + 0.82 * r * math.cos(a), cy + 0.82 * r * math.sin(a))])
        petals.append(p.buffer(r * math.pi / n * 0.95, cap_style=1))
    ring = Point(cx, cy).buffer(0.30 * r, 32)
    return unary_union(petals), ring


# ---- B: Fugaku ----------------------------------------------------------------------
def draw_b(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(WALL), side), c)
    fx, fy = fxy(side)
    # Abendrot-Streifen
    cols = ['#5a0a1e', '#8c0f24', RED, '#e8471c', ORANGE, GOLD]
    v0, v1 = 0.5, 2.05
    for i, c in enumerate(cols):
        a = v1 - (v1 - v0) * i / len(cols)
        add('himmel', sbox(-0.1, v0 - 0.05, BL + 0.1, a + 0.01), c)
    add('sonne', Point(5.3, 1.35).buffer(0.55, 64), WHITE)
    add('sonne', Point(5.3, 1.35).buffer(0.5, 64), '#ffe27a')
    # Fuji
    mt = pg([(0.9, 0.45)] + bez((0.9, 0.45), (2.2, 0.75), (3.0, 1.25), (3.38, 1.86), 16) + [(3.55, 1.84), (3.7, 1.88), (3.85, 1.85)]
            + bez((3.85, 1.85), (4.25, 1.25), (5.0, 0.75), (6.4, 0.45), 16)[1:])
    add('fuji', mt, '#1b3a78')
    add('fuji', mt.intersection(sbox(0, 0.45, 3.62, 2.0)), '#23498f')
    jag = [(2.7, 1.2)]
    for k in range(13):
        u = 2.85 + k * 0.12
        jag.append((u, 1.42 + (0.1 if k % 2 else -0.04) + 0.03 * math.sin(k * 1.7)))
    jag += [(4.5, 1.2), (4.5, 2.1), (2.7, 2.1)]
    add('fuji', mt.intersection(pg(jag)), WHITE)
    # Wasser
    add('wasser', sbox(-0.1, -0.1, BL + 0.1, 0.5), NAVY)
    wl = []
    for row, v in enumerate((0.38, 0.24, 0.1)):
        pts = [(u, v + 0.04 * math.sin(u * 5 + row)) for u in np.linspace(-0.1, BL + 0.1, 160)]
        wl.append(LineString(pts).buffer(0.022))
    add('wasser', unary_union(wl), '#8fc7ff')
    # Namenstafel oben
    add('tafel', sbox(-0.1, 2.0, BL + 0.1, BH + 0.1), GOLD)
    add('tafel', sbox(0.08, 2.08, BL - 0.08, BH - 0.06), BLACK)
    add('tafel', sbox(0.08, 2.08, BL - 0.08, BH - 0.06).difference(sbox(0.12, 2.12, BL - 0.12, BH - 0.1)), GOLD)
    for u in (0.55, BL - 0.55):
        p, c = kiku(u, 2.39, 0.27)
        add('tafel', p, GOLD); add('tafel', c, RED)
    d, *_ = text('富嶽丸', MINCHO, 0.5 * PPM, fx(BL / 2), fy(2.38), anchor='mm', track=0.6)
    svg.add_s('schrift', d, RED, RED, 0.05 * PPM)
    svg.add('schrift', d, GOLD)
    d, *_ = text('日本一周', MINCHO, 0.17 * PPM, fx(1.55), fy(1.85), anchor='mm', track=0.25)
    svg.add_s('schrift', d, BLACK, BLACK, 0.04 * PPM)
    svg.add('schrift', d, WHITE)
    # Fahrerhaus: schwarzer Sockel mit Goldkante, Kiku + Name
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.7), (-3.4, 1.7)])), GOLD)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.67), (-3.4, 1.67)])), BLACK)
    p, c = kiku(-2.95, 1.52, 0.11)
    svg.add('fahrerhaus', C(p), GOLD); svg.add('fahrerhaus', C(c), RED)
    cx, cy = cab_pt(-2.4, 1.52, side)
    d, *_ = text('富嶽丸', MINCHO, 0.15 * PPM, cx, cy, anchor='mm', track=0.2)
    svg.add('fahrerhaus', d, GOLD)


# ---- C: Nishikigoi -------------------------------------------------------------------
TEAL = ['#04222e', '#063041', '#083f52', '#0a4f63']


def koi(cx, cy, L, ang, seed):
    """Koi in Draufsicht, Kopf in Richtung ang (Grad). Gibt (Körper, Flossen, rote Flecken, Augen) zurück."""
    half = bez((0, 0), (0.06, 0.13), (0.3, 0.17), (0.6, 0.11), 14) + bez((0.6, 0.11), (0.78, 0.07), (0.9, 0.04), (0.95, 0.02), 8)[1:]
    outline = half + [(0.95, -0.02)] + [(x, -y) for x, y in half[::-1]]
    body = pg(outline)
    tail = pg(bez((0.92, 0), (1.05, 0.12), (1.2, 0.2), (1.3, 0.16), 10) + bez((1.3, 0.16), (1.2, 0.05), (1.2, -0.05), (1.3, -0.16), 8)[1:]
              + bez((1.3, -0.16), (1.2, -0.2), (1.05, -0.12), (0.92, 0), 10)[1:])
    fins = unary_union([pg([(0.25, 0.11), (0.36, 0.23), (0.43, 0.21), (0.36, 0.09)]), pg([(0.25, -0.11), (0.36, -0.23), (0.43, -0.21), (0.36, -0.09)]), tail])
    rng = np.random.default_rng(seed)
    spots = unary_union([affinity.scale(Point(rng.uniform(0.1, 0.75), rng.uniform(-0.08, 0.08)).buffer(1, 24), rng.uniform(0.08, 0.16), rng.uniform(0.06, 0.12)) for _ in range(5)]).intersection(body.buffer(-0.01))
    eyes = unary_union([Point(0.07, 0.06).buffer(0.018, 10), Point(0.07, -0.06).buffer(0.018, 10)])
    T = lambda g: affinity.translate(affinity.rotate(affinity.scale(g, L, L, origin=(0, 0)), ang + 180, origin=(0, 0)), cx, cy)
    return T(body), T(fins), T(spots), T(eyes)


def lotus(cx, cy, r, rot):
    g = Point(cx, cy).buffer(r, 40)
    notch = pg([(cx, cy), (cx + 1.2 * r * math.cos(math.radians(rot - 12)), cy + 1.2 * r * math.sin(math.radians(rot - 12))),
                (cx + 1.2 * r * math.cos(math.radians(rot + 12)), cy + 1.2 * r * math.sin(math.radians(rot + 12)))])
    return g.difference(notch)


def draw_c(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(WALL), side), c)
    fx, fy = fxy(side)
    n = len(TEAL)
    for i, c in enumerate(TEAL):
        add('teich', sbox(-0.1, BH - (i + 1) * BH / n - 0.01, BL + 0.1, BH - i * BH / n + 0.1), c)
    rings = []
    for (u, v, r0) in ((1.2, 0.6, 0.15), (3.3, 2.2, 0.1), (4.6, 0.7, 0.12), (2.3, 1.2, 0.08), (0.5, 2.1, 0.1)):
        for k in range(4):
            rr = r0 + k * 0.13
            rings.append(Point(u, v).buffer(rr + 0.012, 48).difference(Point(u, v).buffer(rr - 0.012, 48)))
    add('ringe', unary_union(rings), '#2a8fa3')
    for (u, v, r, rot) in ((0.55, 0.45, 0.32, 30), (2.9, 2.35, 0.26, 200), (5.2, 0.35, 0.3, 120), (1.6, 2.3, 0.18, 300)):
        add('seerosen', lotus(u, v, r, rot), '#2e8b3e')
        add('seerosen', lotus(u, v, r * 0.72, rot), '#3fae4f')
    flower = unary_union([affinity.rotate(affinity.scale(Point(0, 0.08).buffer(1, 16), 0.05, 0.1), a, origin=(0, 0)) for a in range(0, 360, 45)])
    add('seerosen', affinity.translate(flower, 2.9, 2.35), '#ff9cc2')
    # zwei Koi, schwimmen nach vorn oben / vorn unten
    for (u, v, L, ang, seed, base) in ((1.0, 1.85, 1.85, 172, 3, WHITE), (2.6, 0.62, 1.55, 190, 9, '#f6c21a'), (4.05, 1.95, 1.05, 168, 21, WHITE)):
        body, fins, spots, eyes = koi(u, v, L, ang, seed)
        add('koi', unary_union([body, fins]).buffer(0.03), BLACK)
        add('koi', fins, '#ffd9c7' if base == WHITE else '#ffe9a0')
        add('koi', body, base)
        add('koi', spots, RED)
        add('koi', eyes, BLACK)
    # Name senkrecht hinten, eingerahmt
    u0 = 6.25
    add('tafel', sbox(u0 - 0.5, 0.12, u0 + 0.5, BH - 0.12), RED)
    add('tafel', sbox(u0 - 0.45, 0.17, u0 + 0.45, BH - 0.17), BLACK)
    for k, ch in enumerate('錦鯉丸'):
        d, *_ = text(ch, MINCHO, 0.68 * PPM, fx(u0), fy(2.2 - k * 0.8), anchor='mm')
        svg.add_s('schrift', d, RED, RED, 0.06 * PPM)
        svg.add('schrift', d, WHITE)
    # Fahrerhaus: türkiser Sockel, kleiner Koi + Name
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.66), (-3.4, 1.66)])), TEAL[2])
    svg.add('fahrerhaus', C(pg([(-3.4, 1.68), (-1.56, 1.68), (-1.56, 1.71), (-3.4, 1.71)])), RED)
    body, fins, spots, eyes = koi(-3.0, 1.95, 0.42, 180, 3)
    svg.add('fahrerhaus', C(unary_union([body, fins]).buffer(0.008)), BLACK)
    svg.add('fahrerhaus', C(body), WHITE); svg.add('fahrerhaus', C(spots), RED)
    cx, cy = cab_pt(-2.3, 1.95, side)
    d, *_ = text('錦鯉丸', MINCHO, 0.16 * PPM, cx, cy, anchor='mm', track=0.1)
    svg.add_s('fahrerhaus', d, RED, RED, 0.02 * PPM)
    svg.add('fahrerhaus', d, WHITE)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_dekotora'
    for key, fn in (('b', draw_b), ('c', draw_c)):
        for side in ('L', 'R'):
            s = SvgS(); fn(s, side); s.write('%s_%s_%s.svg' % (out, key, side))
    print('ok', out)
