"""Tribal-Bausteine mit echten Booleschen Formen (shapely): Klingen, Haken, Tropfen-Aussparungen, Schatten."""
import math
from shapely.geometry import Polygon, MultiPolygon
from shapely.geometry.polygon import orient
from shapely import affinity
from shapely.ops import unary_union
from flame import catmull

def blade(pts, w, head=0.25, start=0.0, power=1.0, n=160):
    """Spitz auslaufende Klinge entlang einer glatten Kurve (Wurzel -> Spitze)."""
    C = catmull(pts, n); L = [0.0]
    for a, b in zip(C, C[1:]): L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    T = L[-1] or 1; top, bot = [], []
    for i, c in enumerate(C):
        t = L[i] / T
        a = C[max(0, i - 1)]; b = C[min(len(C) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dy) or 1; nx, ny = -dy / l, dx / l
        if t < head: ww = w * (start + (1 - start) * math.sin(math.pi / 2 * t / head))
        else: ww = w * (1 - (t - head) / (1 - head)) ** power
        top.append((c[0] + nx * ww / 2, c[1] + ny * ww / 2)); bot.append((c[0] - nx * ww / 2, c[1] - ny * ww / 2))
    return Polygon(top + bot[::-1]).buffer(0)

def drop(cx, cy, r, length, ang=0.0):
    """Tropfen (rund vorne, spitz hinten), fuer Aussparungen."""
    pts = []
    for k in range(40):
        a = math.pi / 2 + math.pi * k / 39
        pts.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    pts.append((cx + length, cy))
    p = Polygon(pts[::-1] + [(cx, cy - r)]).buffer(0)
    return affinity.rotate(p, ang, origin=(cx, cy))

def union(*g): return unary_union(list(g))

def to_d(g):
    """shapely -> SVG-Pfad (Aussenkontur gegen, Loecher im Uhrzeigersinn: nonzero fuellt korrekt)."""
    polys = [g] if isinstance(g, Polygon) else list(getattr(g, 'geoms', []))
    out = []
    for p in polys:
        if not isinstance(p, Polygon) or p.is_empty: continue
        p = orient(p, 1.0)
        for ring in [p.exterior] + list(p.interiors):
            c = list(ring.coords)
            out.append('M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in c) + ' Z')
    return ' '.join(out)

def shadow(g, dx, dy):
    return affinity.translate(g, dx, dy).difference(g)

def mirror_x(g, w): return affinity.scale(g, -1, 1, origin=(w / 2, 0))

def ellipse(cx, cy, rx, ry, ang=0.0, n=60):
    p = Polygon([(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)])
    return affinity.rotate(p, ang, origin=(cx, cy))

def poly(pts): return Polygon(pts).buffer(0)

def tongue_poly(pts, w, **kw):
    from flame import tongue
    import re
    d = tongue(pts, w, **kw)
    nums = [float(v) for v in re.findall(r'-?\d+\.?\d*', d)]
    return Polygon(list(zip(nums[0::2], nums[1::2]))).buffer(0)
