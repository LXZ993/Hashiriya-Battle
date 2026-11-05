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
# ---- feste Farben (nicht einfaerbbar): Markenfarben der Lore-Logos und Aufkleber auf weissem Grund
WHITE, INK = '#f7f7f2', '#111111'
BRAND = {'oilex': '#d4202a', 'okudai': '#1f5fbf', 'wangan': '#e8262c', 'eshock': '#1d63c9', 'gripall': '#e85d04', 'driftgear': '#0095d9',
         'rotopad': '#333333', 'nomi_2': '#e02020', 'selecta': '#0a8f3d', 'tims': '#1d4fa0', 'clockwise': '#222222', 'dreid': '#b00020',
         'nodeoline': '#0d3b66', 'tuningstudio': '#111111', 'grunt_1': '#c1121f', 'grunt_2': '#c1121f', 'burnside': '#7a3b12',
         'folk': '#f28c28', 'blastr': '#111111', 'alder': '#111111', 'apex_2': '#1a8fd0', 'arnida': '#1e40af', 'civetta': '#111111'}
def sticker(D, lid, name, x, y, h, view='side', pad=0.35):
    """Aufkleber: weisser, abgerundeter Grund mit schwarzem Haarrand und Logo in Markenfarbe (alles fest)."""
    import os
    from PIL import Image
    m = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logos', name + '.png'))
    w = h * m.size[0] / m.size[1]
    p = h * pad
    if view == 'side':
        b = rbox(x - w / 2 - p, y - h / 2 - p, x + w / 2 + p, y + h / 2 + p, min(3, h * 0.3))
        D.side(lid, to_d(b.buffer(0.7)), INK); D.side(lid, to_d(b), WHITE)
        D.side_logo(lid, name, x, y, h, key=BRAND.get(name, INK))
    else:   # Draufsicht (um 180 Grad gedreht wie top_logo)
        b = rbox(x - w / 2 - p, y - h / 2 - p, x + w / 2 + p, y + h / 2 + p, min(3, h * 0.3))
        D.top(lid, to_d(b.buffer(0.7)), INK); D.top(lid, to_d(b), WHITE)
        D.top_logo(lid, name, x, y, h, key=BRAND.get(name, INK))
