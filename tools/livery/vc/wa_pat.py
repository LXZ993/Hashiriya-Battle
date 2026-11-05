"""Traditionelle japanische Muster als shapely-Geometrie: Seigaiha (Wellen), Asanoha (Hanfblatt), Kikko (Schildkroete)."""
import math
from shapely.geometry import Point, Polygon, LineString, box
from shapely.ops import unary_union
def seigaiha(region, r=14, rings=(1.0, 0.72, 0.46, 0.22), w=0.11):
    x0, y0, x1, y1 = region.bounds
    res = Polygon()
    rows = int((y1 - y0 + 2 * r) / (r / 2)) + 2
    for j in range(rows):
        cy = y0 - r + j * r / 2
        off = r if j % 2 else 0
        x = x0 - 2 * r + off
        while x < x1 + 2 * r:
            c = Point(x, cy)
            disk = c.buffer(r, 24)
            if disk.intersects(region):
                rg = unary_union([c.buffer(r * f, 24).difference(c.buffer(r * f - r * w * 1.6, 24)) for f in rings] + [c.buffer(r * 0.08, 8)])
                res = res.difference(disk).union(rg)
            x += 2 * r
    return res.intersection(region)
def asanoha(region, s=18, w=1.1):
    """Hanfblatt-Stern: Dreiecksgitter mit Linien zu den Dreiecksmitten."""
    x0, y0, x1, y1 = region.bounds
    h = s * math.sqrt(3) / 2; lines = []
    j = 0; y = y0 - h
    while y < y1 + h:
        off = s / 2 if j % 2 else 0; x = x0 - s + off
        while x < x1 + s:
            a, b, c = (x, y), (x + s, y), (x + s / 2, y + h)
            d, e = (x + s / 2, y + h), (x + 1.5 * s, y + h)
            for tri in ((a, b, c), (b, d, e)):
                m = (sum(p[0] for p in tri) / 3, sum(p[1] for p in tri) / 3)
                for p in tri: lines.append(LineString([p, m]))
                lines += [LineString([tri[0], tri[1]]), LineString([tri[1], tri[2]]), LineString([tri[2], tri[0]])]
            x += s
        y += h; j += 1
    return unary_union([l.buffer(w / 2, 4) for l in lines]).intersection(region)
def kikko(region, s=14, w=1.4):
    x0, y0, x1, y1 = region.bounds; hexes = []
    dx, dy = s * 1.5, s * math.sqrt(3)
    i = 0; x = x0 - s
    while x < x1 + s:
        y = y0 - s + (dy / 2 if i % 2 else 0)
        while y < y1 + s:
            hx = Polygon([(x + s * math.cos(math.pi / 3 * k), y + s * math.sin(math.pi / 3 * k)) for k in range(6)])
            hexes.append(hx.exterior.buffer(w / 2, 2)); hexes.append(hx.buffer(-s * 0.32).exterior.buffer(w / 3, 2))
            y += dy
        x += dx; i += 1
    return unary_union(hexes).intersection(region)
