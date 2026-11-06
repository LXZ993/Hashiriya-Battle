"""Text -> SVG-Pfad (fontTools), damit VectorCraft keine Schriften braucht."""
import math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
FD = '/home/user/hashiriya-battle/tools/livery/fonts/'
_c = {}
class LPen(SVGPathPen):
    def _lineTo(self, pt):
        self._commands.append('L' + ' '.join(self._svgNum(v) for v in pt) if hasattr(self, '_svgNum') else 'L%s %s' % (pt[0], pt[1]))
        self._lastCommand = 'L'; self._lastX, self._lastY = pt

def font(n):
    if n not in _c: _c[n] = TTFont(FD + n)
    return _c[n]
def text(s, fname, size, x, y, rot=0, anchor='mm', track=0.0, skew=0.0):
    """size = Versalhoehe-ungefaehr in px (unitsPerEm skaliert), rot in Grad (gegen Uhrzeiger positiv = nach oben)."""
    f = font(fname); gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    hm = f['hmtx']; sc = size / upm
    # Breite + Bounds messen
    xs, glyphs = 0, []
    for ch in s:
        g = cmap.get(ord(ch));
        if g is None: continue
        glyphs.append((g, xs)); xs += hm[g][0] + track * upm
    bp = BoundsPen(gs)
    for g, ox in glyphs: gs[g].draw(TransformPen(bp, (1, 0, 0, 1, ox, 0)))
    x0, y0, x1, y1 = bp.bounds
    cx = {'l': x0, 'm': (x0 + x1) / 2, 'r': x1}[anchor[0]]; cy = {'t': y1, 'm': (y0 + y1) / 2, 'b': y0}[anchor[1]]
    a = math.radians(rot); ca, sa = math.cos(a), math.sin(a)
    pen = LPen(gs)
    for g, ox in glyphs:
        # Glyphe: (u,v) Font -> lokal (u-cx, -(v-cy))*sc mit Schraegung, dann drehen und verschieben
        # lokal: X = (u - cx + skew*(v-cy)) * sc, Y = -(v - cy) * sc ; Welt: x + X*ca + Y*sa, y - X*sa + Y*ca
        A = sc * ca; B = -sc * sa; C = sc * (skew * ca - sa); D = sc * (-skew * sa - ca)
        E = x + ((ox - cx) - skew * cy) * sc * ca - (-(0 - cy)) * 0 + (cy * sc) * sa
        F = y - ((ox - cx) - skew * cy) * sc * sa + cy * sc * ca
        gs[g].draw(TransformPen(pen, (A, B, C, D, E, F)))
    return pen.getCommands(), (x1 - x0) * sc, (y1 - y0) * sc
