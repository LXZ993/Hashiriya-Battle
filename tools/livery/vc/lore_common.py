"""Hilfen fuer die Lore-Logo-Stile (Sponsor, D1, Shop-Demo, Rallye, Firmenwagen): jedes Auto hat ein eigenes Layout."""
from shapely.geometry import Polygon, box, Point
from shapely.ops import unary_union
from tribal import to_d
def pg(p): return Polygon(p).buffer(0)
def curve(f, a, b, n=60): return [(a + (b - a) * i / n, f(a + (b - a) * i / n)) for i in range(n + 1)]
def band_f(top, bot, a=-20, b=913):
    """Band zwischen zwei Funktionen y=top(x) und y=bot(x)."""
    return pg(curve(top, a, b) + curve(bot, b, a))
def below(f, a=-20, b=913, yb=250): return pg(curve(f, a, b) + [(b, yb), (a, yb)])
def above(f, a=-20, b=913, yt=-30): return pg(curve(f, a, b) + [(b, yt), (a, yt)])
def saw(f, a, b, tooth, h):
    """Saegezahn-Kante entlang y=f(x): Zaehne nach oben, gerade Unterkante 250."""
    pts, x = [], a
    while x < b:
        pts += [(x, f(x)), (min(x + tooth * 0.75, b), f(min(x + tooth * 0.75, b)) - h)]; x += tooth
    pts += [(b, f(b)), (b, 250), (a, 250)]
    return pg(pts)
def rbox(x0, y0, x1, y1, r=5): return box(x0, y0, x1, y1).buffer(-r).buffer(r)
def outline(g, w=1.6): return g.buffer(w).difference(g)
def checker(x0, y0, cols, rows, s):
    return unary_union([box(x0 + c * s, y0 + r * s, x0 + (c + 1) * s, y0 + (r + 1) * s) for c in range(cols) for r in range(rows) if (c + r) % 2 == 0])
