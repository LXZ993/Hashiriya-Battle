"""Percheron Tankwagen (Einkammer-Tank, skin_tanker), Entwürfe Spedition und Dekotora.
Tank lokal: u (m ab Tankfront, 0..5.98), v (m ab Tankunterkante z=1.34, 0..1.6). Gleiche Seitenansicht wie der Koffer.
A/C/D Spedition: 日の出石油 Hinode Oil, 北海ミルク Hokkai Milk (Milchtank), 東洋ガス Toyo Gas.
B/E/F Dekotora: 雷神丸 Raijin-maru, 紅葉丸 Momiji-maru, 虎丸 Tora-maru.
A: 日の出石油 Hinode Oil (Tankstellenkette, erfunden): roter Gürtel mit Goldlinie, Sonnenaufgang-Logo, 火気厳禁.
B: 雷神丸 Raijin-maru (Dekotora): Gewitternacht mit Blitzen und Wolkenschnecken, Goldname.
Aufruf: python pc_tanker.py <ausgabe> -> <ausgabe>_a_L.svg ... _b_R.svg"""
import sys, math
import numpy as np
from shapely.geometry import Point, LineString, box as sbox
from shapely.ops import unary_union
from shapely.geometry.polygon import orient
from shapely import affinity
from txt import text
from pc_spedition_a import PPM, vx, vy, cab_pt, bez
from pc_dekotora_a import pg, to_cab_d, SvgS, GOLD, RED, DRED, BLACK, WHITE

TY0, TZ0, TL, TH = -1.07, 1.34, 5.98, 1.6
TANK = sbox(0.12, 0.0, TL - 0.12, TH)
MINCHO = 'ShipporiMincho-ExtraBold.ttf'


def tpt(u, v, side):
    return vx(TY0 + u, side), vy(TZ0 + v)


def to_d(geom, side):
    out = []
    for g in getattr(geom, 'geoms', [geom]):
        if g.is_empty or g.geom_type != 'Polygon':
            continue
        g = orient(g)
        for ring in [g.exterior] + list(g.interiors):
            out.append('M' + ' L'.join('%.1f %.1f' % tpt(u, v, side) for u, v in ring.coords) + ' Z')
    return ' '.join(out)


def fxy(side):
    return (lambda u: tpt(u, 0, side)[0]), (lambda v: tpt(0, v, side)[1])


# ---- A: Hinode Oil -------------------------------------------------------------------
HR, HG = '#d3121f', '#e9b10c'


def sunrise(cx, cy, r):
    disc = Point(cx, cy).buffer(r, 48).intersection(sbox(cx - r, cy, cx + r, cy + r))
    rays = []
    for i in range(7):
        a = math.radians(15 + i * 25)
        rays.append(pg([(cx + 1.15 * r * math.cos(a - 0.07), cy + 1.15 * r * math.sin(a - 0.07)), (cx + 1.8 * r * math.cos(a - 0.05), cy + 1.8 * r * math.sin(a - 0.05)),
                        (cx + 1.8 * r * math.cos(a + 0.05), cy + 1.8 * r * math.sin(a + 0.05)), (cx + 1.15 * r * math.cos(a + 0.07), cy + 1.15 * r * math.sin(a + 0.07))]))
    return disc, unary_union(rays)


def draw_a(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    add('guertel', sbox(-0.1, 0.38, TL + 0.1, 0.70), HR)
    add('guertel', sbox(-0.1, 0.73, TL + 0.1, 0.76), HG)
    add('guertel', sbox(-0.1, 0.32, TL + 0.1, 0.345), HG)
    disc, rays = sunrise(1.0, 0.80, 0.3)
    add('logo', rays, HR); add('logo', disc, HR)
    d, *_ = text('日の出石油', 'ZenKakuGothicNew-Black.ttf', 0.4 * PPM, fx(3.05), fy(1.12), anchor='mm', track=0.06)
    svg.add('schrift', d, HR)
    d, *_ = text('HINODE OIL', 'RobotoCondensed.ttf', 0.13 * PPM, fx(4.95), fy(1.12), anchor='mm', track=0.2)
    svg.add('schrift', d, HR)
    d, *_ = text('火気厳禁', 'ZenKakuGothicNew-Black.ttf', 0.18 * PPM, fx(3.0), fy(0.54), anchor='mm', track=0.3)
    svg.add('schrift', d, WHITE)
    d, *_ = text('石油類 第4類', 'ZenKakuGothicNew-Bold.ttf', 0.1 * PPM, fx(4.85), fy(0.54), anchor='mm', track=0.1)
    svg.add('schrift', d, WHITE)
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.5), (-1.56, 1.5), (-1.56, 1.66), (-3.4, 1.66)])), HR)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.69), (-1.56, 1.69), (-1.56, 1.71), (-3.4, 1.71)])), HG)
    disc, rays = sunrise(-2.98, 1.84, 0.09)
    svg.add('fahrerhaus', C(unary_union([disc, rays])), HR)
    cx, cy = cab_pt(-2.38, 1.9, side)
    d, *_ = text('日の出石油', 'ZenKakuGothicNew-Black.ttf', 0.13 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, HR)


# ---- B: Raijin ----------------------------------------------------------------------
STORM = ['#0c0a1f', '#16113a', '#211853', '#2d1f66']


def bolt(x0, y0, x1, y1, w, seed, n=6):
    rng = np.random.default_rng(seed)
    pts = [(x0, y0)]
    for k in range(1, n):
        t = k / n
        pts.append((x0 + (x1 - x0) * t + rng.uniform(-0.14, 0.14), y0 + (y1 - y0) * t))
    pts.append((x1, y1))
    left = [(x - w * (1 - i / n), y) for i, (x, y) in enumerate(pts)]
    right = [(x + w * (1 - i / n) + 0.05 * (1 - i / n), y + 0.03) for i, (x, y) in enumerate(pts)]
    return pg(left + right[::-1])


def cloud(cx, cy, s):
    """Wolkenschnecke (kumo): Kreise mit eingerollten Enden."""
    parts = [Point(cx + dx * s, cy + dy * s).buffer(r * s, 32) for dx, dy, r in ((0, 0, 0.22), (0.28, 0.05, 0.18), (-0.27, 0.02, 0.17), (0.5, -0.04, 0.12), (-0.48, -0.04, 0.11))]
    base = unary_union(parts).union(sbox(cx - 0.55 * s, cy - 0.15 * s, cx + 0.6 * s, cy - 0.04 * s))
    def curl(x, y, r):
        ring = Point(x, y).buffer(r, 24).difference(Point(x, y).buffer(r * 0.55, 24))
        return ring.difference(sbox(x - r, y - r, x + r * 0.1, y))   # eingerolltes Ende (3/4-Bogen)
    curls = unary_union([curl(cx + dx * s, cy + dy * s, 0.09 * s) for dx, dy in ((0.02, 0.0), (0.3, 0.04), (-0.27, 0.01))])
    return base, curls


def draw_b(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    for i, c in enumerate(STORM):
        add('himmel', sbox(-0.1, TH - (i + 1) * TH / 4 - 0.01, TL + 0.1, TH - i * TH / 4 + 0.05), c)
    for (x0, x1, w, sd) in ((0.9, 1.15, 0.11, 1), (4.95, 5.15, 0.1, 2), (1.75, 1.6, 0.06, 3), (4.2, 4.4, 0.06, 4)):
        b = bolt(x0, TH + 0.05, x1, 0.0, w, sd)
        add('blitze', b.buffer(0.035), WHITE)
        add('blitze', b, GOLD)
    for (u, v, s) in ((0.6, 1.35, 1.0), (2.2, 1.45, 0.8), (3.9, 1.38, 0.95), (5.4, 1.42, 0.85), (1.3, 0.22, 0.75), (4.7, 0.2, 0.8), (2.9, 0.15, 0.6)):
        base, curls = cloud(u, v, s)
        add('wolken', base.buffer(0.03), GOLD)
        add('wolken', base, '#e9e4ff')
        add('wolken', curls, '#7d6bd6')
    for (u, v) in ((0.35, 0.8), (5.65, 0.8)):
        drum = Point(u, v).buffer(0.17, 32)
        add('trommeln', drum.buffer(0.03), GOLD); add('trommeln', drum, RED)
        tomoe = unary_union([affinity.rotate(Point(u + 0.06, v).buffer(0.05, 16), a, origin=(u, v)) for a in (0, 120, 240)])
        add('trommeln', tomoe, GOLD)
    d, *_ = text('雷神丸', MINCHO, 0.62 * PPM, fx(TL / 2), fy(0.82), anchor='mm', track=0.25)
    svg.add_s('schrift', d, BLACK, BLACK, 0.12 * PPM)
    svg.add_s('schrift', d, DRED, RED, 0.06 * PPM)
    svg.add('schrift', d, GOLD)
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.66), (-3.4, 1.66)])), STORM[1])
    zig = pg([(-3.4, 1.66), (-3.0, 1.74), (-2.9, 1.69), (-2.4, 1.78), (-2.3, 1.72), (-1.56, 1.82), (-1.56, 1.76), (-2.3, 1.67), (-2.42, 1.72), (-2.92, 1.63), (-3.02, 1.68), (-3.4, 1.62)])
    svg.add('fahrerhaus', C(zig), GOLD)
    cx, cy = cab_pt(-2.42, 1.97, side)
    d, *_ = text('雷神丸', MINCHO, 0.18 * PPM, cx, cy, anchor='mm', track=0.1)
    svg.add_s('fahrerhaus', d, DRED, RED, 0.03 * PPM)
    svg.add('fahrerhaus', d, GOLD)



# ---- C: Hokkai Milk (Spedition) ------------------------------------------------------
MB, MBL = '#1f5fae', '#8cc4f2'


def drop(cx, cy, r):
    return pg(bez((cx, cy + 2.0 * r), (cx + 0.2 * r, cy + 1.2 * r), (cx + 1.0 * r, cy + 0.6 * r), (cx + r, cy), 12)
              + [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in np.linspace(0, -math.pi, 20)][1:]
              + bez((cx - r, cy), (cx - 1.0 * r, cy + 0.6 * r), (cx - 0.2 * r, cy + 1.2 * r), (cx, cy + 2.0 * r), 12)[1:])


def draw_c(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    edge = [(u, 0.62 + 0.07 * math.sin(u * 3.1) + 0.04 * math.sin(u * 7.3)) for u in np.linspace(-0.1, TL + 0.1, 120)]
    add('welle', pg([(-0.1, -0.1)] + edge + [(TL + 0.1, -0.1)]), MB)
    add('welle', pg([(u, v + 0.06) for u, v in edge] + [(u, v + 0.1) for u, v in edge][::-1]), MBL)
    add('logo', drop(0.9, 0.85, 0.2), MB)
    add('logo', drop(0.9, 0.85, 0.13), WHITE)
    d, *_ = text('北海ミルク', 'MPLUS1p-Black.ttf', 0.42 * PPM, fx(2.9), fy(1.08), anchor='mm', track=0.05)
    svg.add('schrift', d, MB)
    d, *_ = text('HOKKAI MILK', 'RobotoCondensed.ttf', 0.13 * PPM, fx(4.9), fy(1.08), anchor='mm', track=0.25)
    svg.add('schrift', d, MB)
    d, *_ = text('生乳輸送', 'ZenKakuGothicNew-Black.ttf', 0.17 * PPM, fx(2.9), fy(0.36), anchor='mm', track=0.4)
    svg.add('schrift', d, WHITE)
    d, *_ = text('毎朝、牧場から。', 'ZenKakuGothicNew-Bold.ttf', 0.11 * PPM, fx(4.8), fy(0.36), anchor='mm', track=0.1)
    svg.add('schrift', d, WHITE)
    C = lambda g: to_cab_d(g, side)
    cab_edge = [(Y, 1.62 + 0.03 * math.sin(Y * 9)) for Y in np.linspace(-3.4, -1.56, 40)]
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38)] + cab_edge + [(-1.56, 1.38)])), MB)
    svg.add('fahrerhaus', C(drop(-2.98, 1.82, 0.07)), MB)
    cx, cy = cab_pt(-2.38, 1.9, side)
    d, *_ = text('北海ミルク', 'MPLUS1p-Black.ttf', 0.13 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, MB)


# ---- D: Toyo Gas (Spedition) ---------------------------------------------------------
GN, GT, GO = '#103a6b', '#14a3a8', '#f07a12'


def flame(cx, cy, s):
    outer = pg(bez((cx, cy), (cx + 0.32 * s, cy), (cx + 0.36 * s, cy + 0.38 * s), (cx + 0.05 * s, cy + 0.8 * s), 14)
               + bez((cx + 0.05 * s, cy + 0.8 * s), (cx + 0.05 * s, cy + 0.5 * s), (cx - 0.12 * s, cy + 0.5 * s), (cx - 0.16 * s, cy + 0.42 * s), 8)[1:]
               + bez((cx - 0.16 * s, cy + 0.42 * s), (cx - 0.36 * s, cy + 0.25 * s), (cx - 0.3 * s, cy), (cx, cy), 12)[1:])
    inner = affinity.scale(outer, 0.5, 0.5, origin=(cx, cy))
    return outer, inner


def draw_d(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    for k, (c, w) in enumerate(((GN, 0.34), (GT, 0.16), (GN, 0.08))):
        x = 0.25 + k * 0.48
        add('streifen', pg([(x, -0.1), (x + w, -0.1), (x + w + 0.9, TH + 0.1), (x + 0.9, TH + 0.1)]), c)
    for k, (c, w) in enumerate(((GN, 0.08), (GT, 0.16), (GN, 0.34))):
        x = TL - 2.15 + k * 0.48
        add('streifen', pg([(x, -0.1), (x + w, -0.1), (x + w + 0.9, TH + 0.1), (x + 0.9, TH + 0.1)]), c)
    add('linie', sbox(1.6, 0.2, TL - 2.0, 0.25), GN)
    o, i = flame(2.05, 0.6, 0.75)
    add('logo', o, GO); add('logo', i, '#ffc21a')
    d, *_ = text('東洋ガス', 'ZenKakuGothicNew-Black.ttf', 0.44 * PPM, fx(3.25), fy(0.95), anchor='mm', track=0.06)
    svg.add('schrift', d, GN)
    d, *_ = text('TOYO GAS  LPG', 'RobotoCondensed.ttf', 0.12 * PPM, fx(3.25), fy(0.5), anchor='mm', track=0.3)
    svg.add('schrift', d, GT)
    d, *_ = text('高圧ガス', 'ZenKakuGothicNew-Black.ttf', 0.15 * PPM, fx(3.25), fy(1.38), anchor='mm', track=0.35)
    svg.add('schrift', d, '#c8102e')
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.42), (-2.7, 1.42), (-2.45, 1.75), (-3.15, 1.75)])), GN)
    svg.add('fahrerhaus', C(pg([(-2.62, 1.42), (-2.47, 1.42), (-2.22, 1.75), (-2.37, 1.75)])), GT)
    o, i = flame(-1.95, 1.5, 0.3)
    svg.add('fahrerhaus', C(o), GO); svg.add('fahrerhaus', C(i), '#ffc21a')
    cx, cy = cab_pt(-2.55, 1.93, side)
    d, *_ = text('東洋ガス', 'ZenKakuGothicNew-Black.ttf', 0.13 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, GN)


# ---- E: Momiji-maru (Dekotora) -------------------------------------------------------
def maple(cx, cy, r, rot):
    pts = []
    lobes = [(90, 1.0), (140, 0.78), (190, 0.55), (350, 0.55), (40, 0.78)]
    for i in range(72):
        a = i * 5
        best = max(math.cos(math.radians(a - la)) ** 12 * lr for la, lr in lobes)
        rr = r * (0.28 + 0.72 * best) * (1 + 0.06 * (i % 2))
        pts.append((rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a))))
    leaf = pg(pts).union(LineString([(0, 0), (0.12 * r, -0.55 * r)]).buffer(0.05 * r))
    return affinity.translate(affinity.rotate(leaf, rot, origin=(0, 0)), cx, cy)


def draw_e(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    cols = ['#5c0b0b', '#8a1410', '#b82512', '#d9480f', '#ee7b16']
    for i, c in enumerate(cols):
        add('himmel', sbox(-0.1, TH - (i + 1) * TH / len(cols) - 0.01, TL + 0.1, TH - i * TH / len(cols) + 0.05), c)
    # Wasserlauf mit Wellen unten
    add('fluss', sbox(-0.1, -0.1, TL + 0.1, 0.3), '#123a63')
    add('fluss', unary_union([LineString([(u, 0.18 + 0.03 * math.sin(u * 8 + k)) for u in np.linspace(-0.1, TL + 0.1, 120)]).buffer(0.015) for k in range(2)]), '#7fb5e8')
    rng = np.random.default_rng(5)
    cs = ['#ffd23f', '#ff9f1c', '#e4572e', '#c1121f', '#ffe066']
    leaves = []
    for k in range(34):
        u, v = rng.uniform(0, TL), rng.uniform(0.3, TH)
        if 1.9 < u < 4.1 and 0.45 < v < 1.25:
            continue
        leaves.append((maple(u, v, rng.uniform(0.09, 0.2), rng.uniform(0, 360)), cs[k % len(cs)]))
    for g, c in leaves:
        add('blaetter', g.buffer(0.012), '#3a0a05')
        add('blaetter', g, c)
    add('tafel', sbox(1.85, 0.42, 4.13, 1.28), GOLD)
    add('tafel', sbox(1.9, 0.47, 4.08, 1.23), BLACK)
    d, *_ = text('紅葉丸', MINCHO, 0.56 * PPM, fx(TL / 2), fy(0.85), anchor='mm', track=0.2)
    svg.add_s('schrift', d, RED, RED, 0.04 * PPM)
    svg.add('schrift', d, GOLD)
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.64), (-3.4, 1.64)])), '#8a1410')
    for (Y, Z, r, rot, c) in ((-3.05, 1.92, 0.12, 20, '#ff9f1c'), (-2.86, 1.84, 0.08, 300, '#c1121f'), (-1.8, 1.53, 0.08, 160, '#ffd23f')):
        g = maple(Y, Z, r, rot)
        svg.add('fahrerhaus', C(g.buffer(0.008)), '#3a0a05'); svg.add('fahrerhaus', C(g), c)
    cx, cy = cab_pt(-2.38, 1.92, side)
    d, *_ = text('紅葉丸', MINCHO, 0.17 * PPM, cx, cy, anchor='mm', track=0.1)
    svg.add_s('fahrerhaus', d, DRED, RED, 0.025 * PPM)
    svg.add('fahrerhaus', d, GOLD)


# ---- F: Tora-maru (Dekotora) ---------------------------------------------------------
def tstripe(u, v0, v1, w, bend, fork):
    left = bez((u - w / 2, v0), (u - w / 2 + bend, (v0 + v1) / 2), (u + bend, v1 - 0.1), (u + bend * 1.2, v1), 14)
    right = bez((u + bend * 1.2, v1), (u + bend + w * 0.25, v1 - 0.2), (u + w / 2 + bend, (v0 + v1) / 2), (u + w / 2, v0), 14)
    g = pg(left + right[1:])
    if fork:
        g = g.difference(pg([(u - w * 0.15, v0 - 0.01), (u + w * 0.15, v0 - 0.01), (u + bend * 0.3, v0 + (v1 - v0) * 0.35)]))
    return g


def draw_f(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(TANK), side), c)
    fx, fy = fxy(side)
    add('fell', sbox(-0.1, -0.1, TL + 0.1, TH + 0.1), '#f29e1f')
    rng = np.random.default_rng(11)
    st = []
    u = 0.1
    while u < TL:
        w = rng.uniform(0.14, 0.26)
        st.append(tstripe(u, TH + 0.05, rng.uniform(0.3, 0.85), w, rng.uniform(-0.32, 0.32), rng.random() < 0.6))
        st.append(tstripe(u + rng.uniform(0.15, 0.3), -0.05, rng.uniform(0.55, 1.05), w * 0.85, rng.uniform(-0.28, 0.28), rng.random() < 0.4))
        u += rng.uniform(0.38, 0.55)
    stripes = unary_union(st).difference(sbox(1.55, 0.38, 4.43, 1.22).buffer(0.08))
    add('streifen', stripes, BLACK)
    add('tafel', sbox(1.55, 0.38, 4.43, 1.22), BLACK)
    add('tafel', sbox(1.55, 0.38, 4.43, 1.22).difference(sbox(1.6, 0.43, 4.38, 1.17)), WHITE)
    d, *_ = text('虎丸', MINCHO, 0.62 * PPM, fx(TL / 2 - 0.25), fy(0.8), anchor='mm', track=0.3)
    svg.add_s('schrift', d, RED, RED, 0.05 * PPM)
    svg.add('schrift', d, WHITE)
    d, *_ = text('一番星', MINCHO, 0.14 * PPM, fx(TL / 2 + 1.0), fy(0.8), anchor='mm', track=0.1)
    svg.add('schrift', d, GOLD)
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.66), (-3.4, 1.66)])), '#f29e1f')
    for k in range(5):
        Y = -3.3 + k * 0.38
        svg.add('fahrerhaus', C(pg([(Y, 1.38), (Y + 0.1, 1.38), (Y + 0.14, 1.66), (Y + 0.09, 1.66)])), BLACK)
    cx, cy = cab_pt(-2.42, 1.92, side)
    d, *_ = text('虎丸', MINCHO, 0.2 * PPM, cx, cy, anchor='mm', track=0.2)
    svg.add_s('fahrerhaus', d, BLACK, BLACK, 0.03 * PPM)
    svg.add('fahrerhaus', d, '#f29e1f')

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_tanker'
    for key, fn in (('a', draw_a), ('b', draw_b), ('c', draw_c), ('d', draw_d), ('e', draw_e), ('f', draw_f)):
        for side in ('L', 'R'):
            s = SvgS(); fn(s, side); s.write('%s_%s_%s.svg' % (out, key, side))
    print('ok', out)
