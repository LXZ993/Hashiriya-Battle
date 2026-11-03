"""Grundformen (Aufkleber-Umrisse) und Motive für die Logos. Alles im 512er Raster, Mitte 256/256."""
import math

C = 256


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def poly(pts, close=True):
    d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts)
    return d + (" Z" if close else "")


def circle(cx, cy, r):
    return (f"M{f(cx - r)} {f(cy)} A{f(r)} {f(r)} 0 1 0 {f(cx + r)} {f(cy)} "
            f"A{f(r)} {f(r)} 0 1 0 {f(cx - r)} {f(cy)} Z")


def ring(cx, cy, r1, r2):
    """Kreisring (evenodd)."""
    return circle(cx, cy, r1) + " " + circle(cx, cy, r2)


def ellipse(cx, cy, rx, ry):
    return (f"M{f(cx - rx)} {f(cy)} A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)} "
            f"A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)} Z")


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    return (f"M{f(x + r)} {f(y)} H{f(x + w - r)} A{f(r)} {f(r)} 0 0 1 {f(x + w)} {f(y + r)} "
            f"V{f(y + h - r)} A{f(r)} {f(r)} 0 0 1 {f(x + w - r)} {f(y + h)} H{f(x + r)} "
            f"A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y + h - r)} V{f(y + r)} A{f(r)} {f(r)} 0 0 1 {f(x + r)} {f(y)} Z")


def ngon(cx, cy, r, n, rot=-90):
    return poly([(cx + r * math.cos(math.radians(rot + i * 360 / n)),
                  cy + r * math.sin(math.radians(rot + i * 360 / n))) for i in range(n)])


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def shield(cx, cy, w, h):
    x0, x1, y0 = cx - w / 2, cx + w / 2, cy - h / 2
    return (f"M{f(x0)} {f(y0 + h * .08)} Q{f(cx)} {f(y0 - h * .04)} {f(x1)} {f(y0 + h * .08)} "
            f"L{f(x1)} {f(y0 + h * .5)} C{f(x1)} {f(y0 + h * .78)} {f(cx + w * .18)} {f(y0 + h * .92)} {f(cx)} {f(y0 + h)} "
            f"C{f(cx - w * .18)} {f(y0 + h * .92)} {f(x0)} {f(y0 + h * .78)} {f(x0)} {f(y0 + h * .5)} Z")


def drop(cx, cy, r):
    top = cy - r * 1.75
    return (f"M{f(cx)} {f(top)} C{f(cx + r * .35)} {f(cy - r * 1.1)} {f(cx + r)} {f(cy - r * .55)} {f(cx + r)} {f(cy)} "
            f"A{f(r)} {f(r)} 0 1 1 {f(cx - r)} {f(cy)} C{f(cx - r)} {f(cy - r * .55)} {f(cx - r * .35)} {f(cy - r * 1.1)} {f(cx)} {f(top)} Z")


def heart(cx, cy, s):
    return (f"M{f(cx)} {f(cy + s * .9)} C{f(cx - s * 1.3)} {f(cy + s * .1)} {f(cx - s * 1.1)} {f(cy - s * .95)} {f(cx)} {f(cy - s * .45)} "
            f"C{f(cx + s * 1.1)} {f(cy - s * .95)} {f(cx + s * 1.3)} {f(cy + s * .1)} {f(cx)} {f(cy + s * .9)} Z")


def banner(cx, cy, w, h, notch=0.12):
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    n = w * notch
    return poly([(x0, y0), (x1, y0), (x1 - n, cy), (x1, y1), (x0, y1), (x0 + n, cy)])


def bolt(cx, cy, s):
    p = [(.18, -1), (-.42, .08), (-.02, .08), (-.22, 1), (.46, -.18), (.04, -.18), (.3, -1)]
    return poly([(cx + x * s, cy + y * s) for x, y in p])


def sparkle(cx, cy, r, k=.22):
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * k
        a = math.radians(-90 + i * 45)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = f"M{f(pts[0][0])} {f(pts[0][1])}"
    for i in range(1, 9):
        p = pts[i % 8]
        q = (cx, cy)
        d += f" Q{f((pts[i - 1][0] + p[0]) / 2 * .55 + q[0] * .45)} {f((pts[i - 1][1] + p[1]) / 2 * .55 + q[1] * .45)} {f(p[0])} {f(p[1])}"
    return d + " Z"


def wing(cx, cy, s, side=1):
    """Stilisierter Flügel aus drei Federn, side=1 rechts, -1 links."""
    out = []
    for i, (ln, dy) in enumerate([(1.0, 0), (.82, .2), (.62, .4)]):
        x0 = cx
        y0 = cy + dy * s
        x1 = cx + side * ln * s
        out.append(poly([(x0, y0 - .07 * s), (x1, y0 - .16 * s), (x1 - side * .1 * s, y0 + .02 * s), (x0, y0 + .1 * s)]))
    return " ".join(out)


def rays(cx, cy, r1, r2, n, a0, a1, w):
    out = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / max(n - 1, 1))
        da = w / 2 / r2
        out.append(poly([(cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
                         (cx + r2 * math.cos(a - da), cy + r2 * math.sin(a - da)),
                         (cx + r2 * math.cos(a + da), cy + r2 * math.sin(a + da))]))
    return " ".join(out)
