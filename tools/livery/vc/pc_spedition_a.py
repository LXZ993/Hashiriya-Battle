"""Percheron Kofferwagen, Entwurf 1: erfundene japanische Spedition "Hoshizora Kyuubin" (星空急便).
Zeichnet die Seitenansicht links/rechts (100 px/m) als SVG mit Ebenen fuer VectorCraft.
Koordinaten: Koffer lokal u (m ab Stirnwand, 0..7.08) / v (m ab Kofferboden, 0..2.77),
Fahrerhaus in Fahrzeug-Metern Y (vorn negativ) / Z (oben).
Aufruf: python pc_spedition_a.py <ausgabe.svg>"""
import sys
import numpy as np
from txt import text

PPM = 100
BOX_Y0, BOX_Z0, BL, BH = -0.88, 1.18, 7.08, 2.77
NAVY, SKY, STAR, WHITE, RED = '#17295a', '#2b8fd6', '#f4c20d', '#ffffff', '#d7262e'
W, H = 1040, 420


def vx(Y, side):
    return (Y + 3.7) * PPM if side == 'L' else (6.7 - Y) * PPM


def vy(Z):
    return (4.2 - Z) * PPM


def box_pt(u, v, side):
    return vx(BOX_Y0 + u, side), vy(BOX_Z0 + v)


def cab_pt(Y, Z, side):
    return vx(Y, side), vy(Z)


def bez(p0, p1, p2, p3, n=24):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = map(np.array, (p0, p1, p2, p3))
    return list(map(tuple, (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3))


def poly(pts, f, side):
    q = [f(u, v, side) for u, v in pts]
    return 'M' + ' L'.join('%.1f %.1f' % p for p in q) + ' Z'


# ---- Formen im Koffer-System -------------------------------------------------------
def swoosh_top(off=0.0):
    """Oberkante des Bands: flach vorn, schwingt hinten hoch."""
    return [(0, 0.42 + off), (3.6, 0.42 + off)] + bez((3.6, 0.42 + off), (5.2, 0.42 + off), (6.0, 1.0 + off), (BL, 1.95 + off))[1:]


def band():
    top = swoosh_top()
    return [(0, 0)] + top + [(BL, 0)]


def stripe(off, th):
    a = swoosh_top(off); b = swoosh_top(off + th)
    return a + b[::-1]


def star(cx, cy, r, rot=0.0, k=0.45):
    pts = []
    for i in range(10):
        a = np.radians(90 + rot + i * 36)
        rr = r if i % 2 == 0 else r * k
        pts.append((cx + rr * np.cos(a), cy + rr * np.sin(a)))
    return pts


def tail(x0, y0, x1, y1, w0, w1):
    """Spitz zulaufender Schweif von (x0,y0) (breit w0) nach (x1,y1) (Spitze w1)."""
    d = np.array([x1 - x0, y1 - y0]); n = np.array([-d[1], d[0]]) / np.linalg.norm(d)
    a = np.array([x0, y0]); b = np.array([x1, y1])
    return [tuple(a + n * w0 / 2), tuple(b + n * w1 / 2), tuple(b - n * w1 / 2), tuple(a - n * w0 / 2)]


def logo_shapes(cx, cy, s, back):
    """Stern mit drei Schweifen. back = Richtung nach hinten (+1 im Koffer-System = Richtung Heck)."""
    out = []
    for i, (dy, ln, w) in enumerate(((0.16, 1.25, 0.12), (0.0, 1.6, 0.14), (-0.16, 1.05, 0.10))):
        x0 = cx + back * 0.12 * s; y0 = cy + dy * s
        out.append(('tail%d' % i, tail(x0, y0, x0 + back * ln * s, y0 + (0.25 - abs(dy)) * 0.2 * s, w * s, 0.01), SKY if i != 1 else NAVY))
    out.append(('star', star(cx, cy, 0.34 * s, rot=-8 * back), STAR))
    return out


# ---- SVG --------------------------------------------------------------------------
class Svg:
    def __init__(self):
        self.layers = {}

    def add(self, layer, d, fill):
        self.layers.setdefault(layer, []).append((d, fill))

    def write(self, path):
        o = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H)]
        for lid, items in self.layers.items():
            o.append('<g id="%s">' % lid)
            for d, f in items:
                o.append('<path d="%s" fill="%s"/>' % (d, f))
            o.append('</g>')
        o.append('</svg>')
        open(path, 'w', encoding='utf-8').write('\n'.join(o))


def draw(svg, side):
    back = 1  # im Koffer-System zeigt +u immer nach hinten
    B = lambda pts: poly(pts, box_pt, side)
    # Band + Begleitstreifen
    svg.add('band', B(band()), NAVY)
    svg.add('band', B(stripe(0.07, 0.06)), SKY)
    svg.add('band', B(stripe(0.17, 0.025)), SKY)
    # Logo vorn
    for _, pts, col in logo_shapes(0.85, 1.85, 1.0, back):
        svg.add('logo', B(pts), col)
    # Schrift: Kanji gross, darunter Romaji, auf dem Band die Freecall-Nummer
    fx = lambda u: box_pt(u, 0, side)[0]
    fy = lambda v: box_pt(0, v, side)[1]
    d, *_ = text('星空急便', 'DelaGothicOne-Regular.ttf', 0.74 * PPM, fx(3.55), fy(1.82), anchor='mm', track=0.02)
    svg.add('schrift', d, NAVY)
    d, *_ = text('HOSHIZORA EXPRESS', 'RobotoCondensed.ttf', 0.2 * PPM, fx(3.55), fy(1.13), anchor='mm', track=0.18, skew=0.18)
    svg.add('schrift', d, NAVY)
    d, *_ = text('フリーダイヤル 0120-48-2470', 'ZenKakuGothicNew-Bold.ttf', 0.13 * PPM, fx(1.9), fy(0.2), anchor='mm', track=0.04)
    svg.add('schrift', d, WHITE)
    d, *_ = text('夜も走る、あなたの荷物。', 'ZenKakuGothicNew-Bold.ttf', 0.13 * PPM, fx(4.5), fy(0.2), anchor='mm', track=0.04)
    svg.add('schrift', d, WHITE)
    # Fahrerhaus: Gurtlinie in Navy/Blau ueber Tuer und Seitenteil, kleines Logo + Name auf der Tuer
    C = lambda pts: poly(pts, cab_pt, side)
    svg.add('fahrerhaus', C([(-3.37, 1.50), (-1.58, 1.50), (-1.58, 1.62), (-3.37, 1.62)]), NAVY)
    svg.add('fahrerhaus', C([(-3.37, 1.655), (-1.58, 1.655), (-1.58, 1.695), (-3.37, 1.695)]), SKY)
    # auf der Tuer nur der Stern (Schweife waeren zu klein), Name dahinter
    svg.add('fahrerhaus', C(star(-2.93, 1.90, 0.13, rot=-8)), STAR)
    cx, cy = cab_pt(-2.40, 1.90, side)
    d, *_ = text('星空急便', 'DelaGothicOne-Regular.ttf', 0.17 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, NAVY)
    cx, cy = cab_pt(-2.30, 1.39, side)
    d, *_ = text('安全運転', 'ZenKakuGothicNew-Bold.ttf', 0.06 * PPM, cx, cy, anchor='mm', track=0.05)
    svg.add('fahrerhaus', d, RED)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_spedition_a'
    for side in ('L', 'R'):
        s = Svg(); draw(s, side); s.write('%s_%s.svg' % (out, side))
    print('ok', out)
