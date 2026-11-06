"""Percheron Kofferwagen, Entwurf 2: Dekotora "夜桜丸" (Yozakura-maru, Nacht-Kirschblüte).
Wandbild auf dem Koffer: Nachthimmel, Strahlensonne, Brandungswellen + Seigaiha-Schuppen, Kirschblütenzweig,
großer Mincho-Schriftzug mit Gold/Rot/Schwarz-Kontur. Fahrerhaus: Regenbogen-Zierstreifen + Name.
Gleiches Raster wie pc_spedition_a.py (100 px/m, Seite L/R). Formen mit shapely, auf die Kofferwand geschnitten.
Aufruf: python pc_dekotora_a.py <ausgabe>  -> <ausgabe>_L.svg / _R.svg"""
import sys, math
import numpy as np
from shapely.geometry import Polygon, Point, box as sbox, LineString
from shapely.ops import unary_union
from shapely import affinity
from shapely.geometry.polygon import orient
from txt import text
from pc_spedition_a import PPM, BOX_Y0, BOX_Z0, BL, BH, W, H, vx, vy, box_pt, cab_pt, bez, Svg

SKY = ['#0b0726', '#140a3a', '#1f0d4d', '#2d0f5c', '#3f1266', '#55146b']
GOLD, ORANGE, RED, DRED, BLACK, WHITE = '#f6c21a', '#f08a12', '#d81e2c', '#7a0c16', '#0a0a0a', '#ffffff'
NAVY, BLUE, LBLUE = '#0b2a6b', '#1d5fbf', '#6fb6ff'
PINK, LPINK, SAKC, BARK = '#ff8fb8', '#ffd3e4', '#c2185b', '#3a1d14'
WALL = sbox(0, 0, BL, BH)


def pg(pts):
    return Polygon(pts).buffer(0)


def to_d(geom, side):
    """shapely (Koffer-Meter) -> SVG-Pfad in Bildpixeln der Seite."""
    out = []
    gs = getattr(geom, 'geoms', [geom])
    for g in gs:
        if g.is_empty or g.geom_type != 'Polygon':
            continue
        g = orient(g)  # Außenring und Löcher gegenläufig -> nonzero füllt richtig (auch für Schrift)
        for ring in [g.exterior] + list(g.interiors):
            pts = [box_pt(u, v, side) for u, v in ring.coords]
            out.append('M' + ' L'.join('%.1f %.1f' % p for p in pts) + ' Z')
    return ' '.join(out)


def crest(x, s, flip=1):
    """Brandungswelle mit Krone, die sich nach vorn (-u) einrollt. x = Fuß vorn, s = Größe."""
    pts = bez((0.95, 0), (0.75, 0.35), (0.55, 0.78), (0.12, 0.82), 20)
    pts += bez((0.12, 0.82), (-0.18, 0.84), (-0.32, 0.62), (-0.22, 0.48), 14)[1:]
    pts += bez((-0.22, 0.48), (-0.12, 0.40), (0.02, 0.50), (-0.04, 0.60), 10)[1:]
    pts += bez((-0.04, 0.60), (0.12, 0.58), (0.10, 0.36), (-0.05, 0.0), 14)[1:]
    p = pg(pts)
    return affinity.translate(affinity.scale(p, s, s, origin=(0, 0)), x, 0.40)


def star(cx, cy, r, k=0.42, n=4, rot=45):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = r if i % 2 == 0 else r * k
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pg(pts)


def blossom(cx, cy, r, rot=0):
    petals = []
    for i in range(5):
        a = math.radians(rot + 90 + i * 72)
        c = Point(cx + 0.55 * r * math.cos(a), cy + 0.55 * r * math.sin(a)).buffer(0.48 * r, 16)
        notch = Point(cx + 1.02 * r * math.cos(a), cy + 1.02 * r * math.sin(a)).buffer(0.13 * r, 8)
        petals.append(c.difference(notch))
    return unary_union(petals), Point(cx, cy).buffer(0.2 * r, 12)


def petal(cx, cy, r, rot):
    e = affinity.scale(Point(0, 0).buffer(1, 16), r, r * 0.55)
    e = e.difference(Point(r * 1.05, 0).buffer(r * 0.28, 8))
    return affinity.translate(affinity.rotate(e, rot, origin=(0, 0)), cx, cy)


def draw_box(svg, side):
    add = lambda lid, g, col: svg.add(lid, to_d(g.intersection(WALL), side), col)
    # 1 Nachthimmel in Stufen
    n = len(SKY)
    for i, c in enumerate(SKY):
        v1 = BH - i * (BH - 0.5) / n + (0.02 if i else 0.05)
        v0 = BH - (i + 1) * (BH - 0.5) / n if i < n - 1 else 0
        add('himmel', sbox(-0.05, v0, BL + 0.05, v1), c)
    # 2 Strahlensonne vorn
    sx, sy = 1.55, 1.70
    rays = []
    for i in range(20):
        a0 = math.radians(i * 18); a1 = a0 + math.radians(7)
        R = 9
        rays.append(pg([(sx, sy), (sx + R * math.cos(a0), sy + R * math.sin(a0)), (sx + R * math.cos(a1), sy + R * math.sin(a1))]))
    add('strahlen', unary_union(rays), ORANGE)
    inner = [pg([(sx, sy), (sx + 9 * math.cos(math.radians(i * 18 + 2)), sy + 9 * math.sin(math.radians(i * 18 + 2))),
                 (sx + 9 * math.cos(math.radians(i * 18 + 5)), sy + 9 * math.sin(math.radians(i * 18 + 5)))]) for i in range(20)]
    add('strahlen', unary_union(inner), GOLD)
    add('sonne', Point(sx, sy).buffer(0.66, 64), GOLD)
    add('sonne', Point(sx, sy).buffer(0.60, 64), RED)
    # Sterne im Himmel (nicht in der Sonne)
    rng = np.random.default_rng(7)
    sp = []
    for _ in range(40):
        u, v = rng.uniform(0.1, BL - 0.1), rng.uniform(1.3, BH - 0.1)
        if math.hypot(u - sx, v - sy) < 1.0:
            continue
        sp.append(star(u, v, rng.uniform(0.025, 0.07)))
    add('sterne', unary_union(sp), WHITE)
    # 3 Kirschblütenzweig von hinten oben
    br = bez((BL + 0.1, BH - 0.25), (BL - 0.9, BH - 0.1), (BL - 1.6, BH - 0.55), (BL - 2.6, BH - 0.45), 40)
    branch = LineString(br).buffer(0.07, cap_style=1)
    tw = [LineString(bez(br[i], (br[i][0] - 0.2, br[i][1] - 0.25), (br[i][0] - 0.35, br[i][1] - 0.35), (br[i][0] - 0.5, br[i][1] - 0.55), 12)).buffer(0.03) for i in (8, 20, 32)]
    tw.append(LineString(bez(br[14], (br[14][0] - 0.1, br[14][1] + 0.1), (br[14][0] - 0.3, br[14][1] + 0.15), (br[14][0] - 0.45, br[14][1] + 0.15), 10)).buffer(0.025))
    add('zweig', unary_union([branch] + tw), BARK)
    fl, ce = [], []
    for (u, v, r) in ((BL - 0.4, BH - 0.3, 0.17), (BL - 0.9, BH - 0.28, 0.2), (BL - 1.35, BH - 0.5, 0.16), (BL - 1.9, BH - 0.55, 0.19),
                      (BL - 2.5, BH - 0.48, 0.15), (BL - 1.0, BH - 0.72, 0.15), (BL - 1.55, BH - 0.95, 0.17), (BL - 2.25, BH - 0.85, 0.15),
                      (BL - 2.95, BH - 1.0, 0.16), (BL - 0.55, BH - 0.62, 0.13), (BL - 2.9, BH - 0.32, 0.12), (BL - 1.6, BH - 0.25, 0.12)):
        f, c = blossom(u, v, r, rot=u * 40)
        fl.append(f); ce.append(c)
    add('bluete', unary_union([f.buffer(0.018) for f in fl]), SAKC)
    add('bluete', unary_union(fl), LPINK)
    add('bluete', unary_union([f.buffer(-0.035) for f in fl]), PINK)
    add('bluete', unary_union(ce), SAKC)
    pts = [petal(rng.uniform(2.6, BL - 0.3), rng.uniform(0.9, 1.6), rng.uniform(0.04, 0.07), rng.uniform(0, 180)) for _ in range(14)]
    add('bluete', unary_union(pts), PINK)
    # 4 Brandung: Seigaiha-Schuppen unten, darüber Wellenkronen (rollen nach vorn)
    r = 0.24; band = sbox(-0.05, -0.05, BL + 0.05, 0.62)
    rows = [0.62 - k * r * 0.5 for k in range(6)]
    for k, cy in enumerate(rows):
        off = 0 if k % 2 == 0 else r
        for i in range(-1, int(BL / (2 * r)) + 2):
            cx = i * 2 * r + off
            for rr, col in ((r, WHITE), (r * 0.86, NAVY), (r * 0.66, WHITE), (r * 0.52, BLUE), (r * 0.32, WHITE), (r * 0.18, NAVY)):
                add('seigaiha', Point(cx, cy).buffer(rr, 32).intersection(band), col)
    crs = []
    x = -0.2; i = 0
    while x < BL:
        s = 0.62 + 0.28 * ((i * 37) % 5) / 4
        crs.append(crest(x, s)); x += 0.78 * s + 0.05; i += 1
    add('wellen', unary_union([c.buffer(0.045) for c in crs]), WHITE)
    add('wellen', unary_union(crs), BLUE)
    add('wellen', unary_union([affinity.scale(c, 0.72, 0.62, origin=(c.bounds[0] + 0.2, 0.4)) for c in crs]), NAVY)
    spray = [Point(rng.uniform(0, BL), rng.uniform(1.0, 1.35)).buffer(rng.uniform(0.012, 0.03), 8) for _ in range(60)]
    add('wellen', unary_union(spray), WHITE)
    # 5 Schriftzug (in Bildpixeln, damit er auf beiden Seiten lesbar ist)
    fx = lambda u: box_pt(u, 0, side)[0]; fy = lambda v: box_pt(0, v, side)[1]
    d, *_ = text('夜桜丸', 'ShipporiMincho-ExtraBold.ttf', 0.92 * PPM, fx(4.35), fy(1.62), anchor='mm', track=0.06)
    svg.add_s('schrift', d, BLACK, BLACK, 0.16 * PPM)
    svg.add_s('schrift', d, DRED, RED, 0.08 * PPM)
    svg.add('schrift', d, GOLD)
    d, *_ = text('全国夜間便', 'ShipporiMincho-ExtraBold.ttf', 0.2 * PPM, fx(3.55), fy(2.45), anchor='mm', track=0.35)
    svg.add_s('schrift', d, BLACK, BLACK, 0.05 * PPM)
    svg.add('schrift', d, WHITE)
    # Stempel "御免"
    sx2 = 6.05
    svg.add('stempel', to_d(sbox(sx2 - 0.17, 1.05, sx2 + 0.17, 1.55), side), RED)
    svg.add('stempel', to_d(sbox(sx2 - 0.17, 1.05, sx2 + 0.17, 1.55).difference(sbox(sx2 - 0.14, 1.08, sx2 + 0.14, 1.52)), side), WHITE)
    for k, ch in enumerate('御免'):
        d, *_ = text(ch, 'ShipporiMincho-ExtraBold.ttf', 0.17 * PPM, fx(sx2), fy(1.42 - k * 0.2), anchor='mm')
        svg.add('stempel', d, WHITE)


def draw_cab(svg, side):
    C = lambda g: to_cab_d(g, side)
    # Regenbogen-Zierstreifen schräg nach hinten ansteigend, unter der Tür
    cols = [RED, ORANGE, GOLD, '#2eb84a', BLUE, '#7b2fbf']
    for i, c in enumerate(cols):
        z0 = 1.44 + i * 0.045
        p = pg([(-3.37, z0), (-1.58, z0 + 0.10), (-1.58, z0 + 0.135), (-3.37, z0 + 0.035)])
        svg.add('fahrerhaus', C(p), c)
    f, ce = blossom(-2.96, 1.95, 0.13)
    svg.add('fahrerhaus', C(f.buffer(0.012)), SAKC)
    svg.add('fahrerhaus', C(f), PINK)
    svg.add('fahrerhaus', C(ce), SAKC)
    cx, cy = cab_pt(-2.42, 1.95, side)
    d, *_ = text('夜桜丸', 'ShipporiMincho-ExtraBold.ttf', 0.2 * PPM, cx, cy, anchor='mm', track=0.04)
    svg.add_s('fahrerhaus', d, BLACK, BLACK, 0.04 * PPM)
    svg.add_s('fahrerhaus', d, DRED, RED, 0.02 * PPM)
    svg.add('fahrerhaus', d, GOLD)


def to_cab_d(g, side):
    out = []
    for p in getattr(g, 'geoms', [g]):
        if p.is_empty:
            continue
        p = orient(p)
        for ring in [p.exterior] + list(p.interiors):
            pts = [cab_pt(Y, Z, side) for Y, Z in ring.coords]
            out.append('M' + ' L'.join('%.1f %.1f' % q for q in pts) + ' Z')
    return ' '.join(out)


class SvgS(Svg):
    def add(self, layer, d, fill):
        if d:
            self.layers.setdefault(layer, []).append((d, fill, None, 0))

    def add_s(self, layer, d, fill, stroke, sw):
        self.layers.setdefault(layer, []).append((d, fill, stroke, sw))

    def write(self, path):
        o = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H)]
        for lid, items in self.layers.items():
            o.append('<g id="%s">' % lid)
            for d, f, s, sw in items:
                st = ' stroke="%s" stroke-width="%.1f" stroke-linejoin="round"' % (s, sw) if s else ''
                o.append('<path d="%s" fill="%s"%s/>' % (d, f, st))
            o.append('</g>')
        o.append('</svg>')
        open(path, 'w', encoding='utf-8').write('\n'.join(o))


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_dekotora_a'
    for side in ('L', 'R'):
        s = SvgS(); draw_box(s, side); draw_cab(s, side); s.write('%s_%s.svg' % (out, side))
    print('ok', out)
