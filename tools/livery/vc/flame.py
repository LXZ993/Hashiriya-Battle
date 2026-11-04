"""Fliessende Flammen-/Fluessigkeits-Tribals: Zungen entlang glatter Catmull-Rom-Kurven, die weich aus einer
gemeinsamen Wurzel wachsen und spitz nach hinten auslaufen."""
import math

def catmull(pts, n=80):
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    segs = len(pts) - 1
    for i in range(segs):
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        for k in range(n // segs + 1):
            t = k / (n // segs + 1)
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                   (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(tuple(pts[-1]))
    return out

def tongue(pts, w, head=0.12, cap=True, start=0.0, bulge=1.0, n=120):
    """pts: Kurve von vorne (Wurzel) nach hinten (Spitze). w: max. Breite. head: Anteil bis zur max. Breite.
    start: Breite am Anfang (Anteil von w), cap: runde Kappe vorne."""
    C = catmull(pts, n)
    # Bogenlaenge
    L = [0.0]
    for a, b in zip(C, C[1:]): L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    tot = L[-1] or 1
    top, bot = [], []
    for i, c in enumerate(C):
        t = L[i] / tot
        a = C[max(0, i - 1)]; b = C[min(len(C) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        if t < head: ww = w * (start + (1 - start) * math.sin(math.pi / 2 * t / head))
        else:
            u = (t - head) / (1 - head)
            ww = w * max((1 - u) ** 0.85, 0) * (1 + 0.25 * bulge * math.sin(math.pi * u)) + (0.9 if u < 0.995 else 0)
        top.append((c[0] + nx * ww / 2, c[1] + ny * ww / 2)); bot.append((c[0] - nx * ww / 2, c[1] - ny * ww / 2))
    pts_ = top + bot[::-1]
    if cap and start > 0:
        c = C[0]; b = C[1]; ang = math.atan2(b[1] - c[1], b[0] - c[0]); r = w * start / 2
        arc = [(c[0] + r * math.cos(ang + math.pi / 2 + math.pi * k / 10), c[1] + r * math.sin(ang + math.pi / 2 + math.pi * k / 10)) for k in range(11)]
        pts_ = top + bot[::-1] + arc[1:-1]
    return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts_) + ' Z'
