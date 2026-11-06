import math
def offset_line(pts, d, toward):
    """Parallele zur Polylinie im Abstand d, auf der Seite, in die `toward` (Vektor) zeigt; Ecken echt spitz (Gehrung)."""
    segs = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0; l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        if nx * toward[0] + ny * toward[1] < 0: nx, ny = -nx, -ny
        segs.append(((x0 + nx * d, y0 + ny * d), (x1 + nx * d, y1 + ny * d)))
    out = [segs[0][0]]
    for (a0, a1), (b0, b1) in zip(segs, segs[1:]):
        # Schnittpunkt der beiden versetzten Geraden
        r = (a1[0] - a0[0], a1[1] - a0[1]); s = (b1[0] - b0[0], b1[1] - b0[1])
        den = r[0] * s[1] - r[1] * s[0]
        if abs(den) < 1e-9: out.append(a1); continue
        t = ((b0[0] - a0[0]) * s[1] - (b0[1] - a0[1]) * s[0]) / den
        out.append((a0[0] + r[0] * t, a0[1] + r[1] * t))
    out.append(segs[-1][1])
    return out
def band(pts, d, toward):
    return pts + offset_line(pts, d, toward)[::-1]
