"""Percheron Kofferwagen, Speditionen B und C (frei erfunden), jede mit eigenem Layout.
B: 青葉運輸 Aoba Logistics (Kühltransporte): grüner Stufenblock hinten mit Blatt-Logo, Name vorn, feine Dachlinie.
C: はやて引越センター Hayate Umzüge: orangefarbenes Dachband mit großer Freecall-Nummer, Schwalben-Maskottchen.
Aufruf: python pc_spedition_bc.py <ausgabe> -> <ausgabe>_b_L.svg ... _c_R.svg"""
import sys, math
from shapely.geometry import Point, LineString, box as sbox
from shapely.ops import unary_union
from shapely import affinity
from txt import text
from pc_spedition_a import PPM, BL, BH, box_pt, cab_pt, bez
from pc_dekotora_a import pg, to_d, to_cab_d, SvgS, WALL

WHITE = '#ffffff'


def fxy(side):
    return (lambda u: box_pt(u, 0, side)[0]), (lambda v: box_pt(0, v, side)[1])


# ---- B: Aoba --------------------------------------------------------------------------
G1, G2, G3, GT = '#0b5a2c', '#16884a', '#62c46d', '#0e6b35'


def leaf(cx, cy, s, rot=35):
    a = Point(-0.55, 0).buffer(0.8, 48); b = Point(0.55, 0).buffer(0.8, 48)
    l = a.intersection(b)                                      # Spitzoval, hoch 1.16, breit 0.5
    rib = LineString([(0, -0.5), (0, 0.48)]).buffer(0.025)
    veins = unary_union([LineString([(0, y), (0.16 * sgn, y + 0.14)]).buffer(0.018) for y in (-0.3, -0.08, 0.14) for sgn in (-1, 1)])
    stem = LineString([(0, -0.5), (0.05, -0.72)]).buffer(0.03)
    g = unary_union([l, stem]).difference(unary_union([rib, veins]))
    return affinity.translate(affinity.rotate(affinity.scale(g, s, s, origin=(0, 0)), rot, origin=(0, 0)), cx, cy)


def draw_b(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(WALL), side), c)
    fx, fy = fxy(side)
    k = 0.55  # Schräge der Stufen (m nach vorn je m Höhe)
    for x0, c in ((4.35, G3), (4.6, G2), (4.95, G1)):
        add('block', pg([(x0, 0), (BL + 0.1, 0), (BL + 0.1, BH), (x0 - k * BH, BH)]), c)
    add('logo', leaf(6.0, 1.45, 1.75), WHITE)
    # feine Dachlinie + Sockellinie vorn bis zum Block
    add('linien', pg([(0, BH - 0.17), (4.35 - k * (BH - 0.17), BH - 0.17), (4.35 - k * (BH - 0.12), BH - 0.12), (0, BH - 0.12)]), G2)
    add('linien', pg([(0, 0.16), (4.35 - k * 0.16, 0.16), (4.35 - k * 0.24, 0.24), (0, 0.24)]), G2)
    d, *_ = text('青葉運輸', 'ZenKakuGothicNew-Black.ttf', 0.62 * PPM, fx(1.95), fy(1.72), anchor='mm', track=0.05)
    svg.add('schrift', d, GT)
    d, *_ = text('AOBA LOGISTICS', 'RobotoCondensed.ttf', 0.2 * PPM, fx(1.95), fy(1.12), anchor='mm', track=0.3)
    svg.add('schrift', d, G2)
    d, *_ = text('冷蔵・冷凍  産地直送', 'ZenKakuGothicNew-Bold.ttf', 0.13 * PPM, fx(1.95), fy(0.62), anchor='mm', track=0.12)
    svg.add('schrift', d, GT)
    d, *_ = text('www.aoba-unyu.jp', 'RobotoCondensed.ttf', 0.11 * PPM, fx(1.95), fy(0.42), anchor='mm', track=0.08)
    svg.add('schrift', d, G2)
    # Fahrerhaus: untere Hälfte grün, Blatt auf der Tür
    C = lambda g: to_cab_d(g, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.70), (-3.4, 1.70)])), G2)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.73), (-1.56, 1.73), (-1.56, 1.76), (-3.4, 1.76)])), G3)
    svg.add('fahrerhaus', C(leaf(-2.95, 1.93, 0.26)), G2)
    cx, cy = cab_pt(-2.38, 1.93, side)
    d, *_ = text('青葉運輸', 'ZenKakuGothicNew-Black.ttf', 0.15 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, GT)


# ---- C: Hayate -----------------------------------------------------------------------
OR, ORD, BR = '#f26a1b', '#c94d0c', '#3a2416'


def swallow(cx, cy, s, back=1):
    """Stilisierte Schwalbe im Flug, Kopf nach vorn (-u). back=+1: Schwanz Richtung +u."""
    body = affinity.scale(Point(0, 0).buffer(1, 32), 0.42, 0.13)
    head = Point(-0.36, 0.03).buffer(0.12, 24)
    beak = pg([(-0.47, 0.06), (-0.58, 0.02), (-0.46, -0.01)])
    w1 = pg(bez((-0.1, 0.06), (0.05, 0.35), (0.35, 0.62), (0.75, 0.72), 14) + bez((0.75, 0.72), (0.45, 0.45), (0.25, 0.2), (0.15, 0.02), 14)[1:])
    w2 = pg(bez((-0.05, -0.05), (0.1, -0.28), (0.3, -0.42), (0.62, -0.5), 14) + bez((0.62, -0.5), (0.38, -0.3), (0.25, -0.12), (0.18, -0.04), 14)[1:])
    tail = pg([(0.3, 0.04), (0.85, 0.2), (0.48, 0.0), (0.88, -0.14), (0.3, -0.06)])
    g = unary_union([body, head, beak, w1, w2, tail])
    belly = affinity.scale(Point(-0.12, -0.05).buffer(1, 24), 0.22, 0.06)
    g = affinity.scale(g, s * back, s, origin=(0, 0)); belly = affinity.scale(belly, s * back, s, origin=(0, 0))
    return affinity.translate(g, cx, cy), affinity.translate(belly, cx, cy)


def draw_c(svg, side):
    add = lambda lid, g, c: svg.add(lid, to_d(g.intersection(WALL), side), c)
    fx, fy = fxy(side)
    # Dachband mit Welle an der Unterkante
    wave = [(u, 2.02 + 0.06 * math.sin(u * 1.6)) for u in [i * BL / 60 for i in range(61)]]
    add('band', pg([(-0.1, BH + 0.1)] + [(-0.1, wave[0][1])] + wave + [(BL + 0.1, wave[-1][1]), (BL + 0.1, BH + 0.1)]), OR)
    wave2 = [(u, v - 0.09) for u, v in wave]
    add('band', pg(wave2 + [(u, v - 0.035) for u, v in wave][::-1]), OR)
    add('band', sbox(-0.1, -0.1, BL + 0.1, 0.30), OR)
    add('band', sbox(-0.1, 0.34, BL + 0.1, 0.37), OR)
    d, *_ = text('0120-81-8181', 'RacingSansOne-Regular.ttf', 0.46 * PPM, fx(3.8), fy(2.4), anchor='mm', track=0.04)
    svg.add('schrift', d, WHITE)
    d, *_ = text('フリーダイヤル', 'ZenKakuGothicNew-Black.ttf', 0.15 * PPM, fx(1.35), fy(2.4), anchor='mm', track=0.05)
    svg.add('schrift', d, WHITE)
    d, *_ = text('はやて引越センター', 'MPLUS1p-Black.ttf', 0.44 * PPM, fx(4.75), fy(1.32), anchor='mm', track=0.02)
    svg.add_s('schrift', d, ORD, ORD, 0.06 * PPM)
    svg.add('schrift', d, OR)
    d, *_ = text('お引越しは、はやてにおまかせ！', 'ZenKakuGothicNew-Bold.ttf', 0.14 * PPM, fx(3.6), fy(0.15), anchor='mm', track=0.08)
    svg.add('schrift', d, WHITE)
    # Maskottchen vorn
    g, belly = swallow(1.0, 1.4, 0.95)
    add('maskottchen', g, BR)
    add('maskottchen', belly, WHITE)
    add('maskottchen', Point(0.69, 1.43).buffer(0.025, 12), WHITE)
    # Fahrerhaus: orangefarbener Sockel mit Schwalbe
    C = lambda gg: to_cab_d(gg, side)
    svg.add('fahrerhaus', C(pg([(-3.4, 1.38), (-1.56, 1.38), (-1.56, 1.66), (-3.4, 1.66)])), OR)
    g, belly = swallow(-2.95, 1.92, 0.3)
    svg.add('fahrerhaus', C(g), BR); svg.add('fahrerhaus', C(belly), WHITE)
    cx, cy = cab_pt(-2.4, 1.92, side)
    d, *_ = text('はやて', 'MPLUS1p-Black.ttf', 0.17 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, OR)
    cx, cy = cab_pt(-2.48, 1.52, side)
    d, *_ = text('0120-81-8181', 'RacingSansOne-Regular.ttf', 0.1 * PPM, cx, cy, anchor='mm')
    svg.add('fahrerhaus', d, WHITE)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pc_spedition'
    for key, fn in (('b', draw_b), ('c', draw_c)):
        for side in ('L', 'R'):
            s = SvgS(); fn(s, side); s.write('%s_%s_%s.svg' % (out, key, side))
    print('ok', out)
