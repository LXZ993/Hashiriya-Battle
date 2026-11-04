"""Gemeinsame SVG-Vorlage. Entworfen wird immer in 200BX-Pixeln (200 px/m):
Seite links (Front links) bei (0,0), Seite rechts (Front rechts) bei (0,260), Draufsicht (Front oben) bei (950,0).
Beim Schreiben fuer ein anderes Modell wird jede Ansicht stueckweise linear an dessen Radlaeufe, Fensterlinie,
Schweller und Breite angepasst. Ausgabe-Layout fuer alle Modelle: rechts bei (0,300), Draufsicht bei (1000,0)."""
import base64, re
import numpy as np
from landmarks import lm
KEYC = {1: '#ff0000', 2: '#00ff00', 3: '#0000ff', 'k': '#000000'}
SRC = 'bx'; RY_SRC, TX_SRC = 260, 950
RY, TX, W, H = 300, 1000, 1400, 1000
class Doc:
    def __init__(self, model=None):
        import sys
        model = model or (sys.argv[1] if len(sys.argv) > 1 else 'bx')
        self.model = model
        s = lm(SRC); self.lw, self.tw, self.RY, self.TX = s['W'], s['TW'], RY_SRC, TX_SRC
        self.layers = []   # (id, [(d, fill, stroke, sw, view)])
    def layer(self, lid):
        for l in self.layers:
            if l[0] == lid: return l[1]
        self.layers.append((lid, [])); return self.layers[-1][1]
    @staticmethod
    def _map(p, f):
        return re.sub(r'(-?\d+\.?\d*(?:e-?\d+)?)[ ,](-?\d+\.?\d*(?:e-?\d+)?)', lambda m: '%.1f %.1f' % f(float(m.group(1)), float(m.group(2))), p)
    def _add(self, lid, d, key, stroke, sw, view):
        self.layer(lid).append((d, KEYC[key] if key in KEYC else key, KEYC.get(stroke), sw, view))
    def side(self, lid, d, key, stroke=None, sw=0):
        """Form links zeichnen und gespiegelt rechts."""
        self._add(lid, d, key, stroke, sw, 'L')
        self._add(lid, self._map(d, lambda x, y: (self.lw - x, y)), key, stroke, sw, 'R')
    def side_text(self, lid, s, fname, size, x, y, key, rot=0, stroke=None, sw=0, xr=None, yr=None, **kw):
        """Schrift links und rechts lesbar (nicht gespiegelt), rechts an der gespiegelten Stelle."""
        from txt import text
        dl, *_ = text(s, fname, size, x, y, rot=rot, **kw)
        dr, *_ = text(s, fname, size, self.lw - x if xr is None else xr, (y if yr is None else yr), rot=-rot, **kw)
        for d, v in ((dl, 'L'), (dr, 'R')):
            if stroke: self._add(lid, d, stroke, stroke, sw, v)
            self._add(lid, d, key, None, 0, v)
    def _logo(self, lid, name, key, x, y, h, view, rot=0):
        self.layer(lid).append(('IMG', name, KEYC[key], (x, y, h, rot), view))
    def side_logo(self, lid, name, x, y, h, key='k', xr=None):
        """Lore-Logo (tools/livery/vc/logos/<name>.png, Alphamaske) mittig bei x,y mit Hoehe h, beide Seiten lesbar."""
        self._logo(lid, name, key, x, y, h, 'L'); self._logo(lid, name, key, self.lw - x if xr is None else xr, y, h, 'R')
    def top_logo(self, lid, name, x, y, h, key='k', rot=180):
        self._logo(lid, name, key, x, y, h, 'T', rot)
    def top(self, lid, d, key, stroke=None, sw=0, mirror=False):
        self._add(lid, d, key, stroke, sw, 'T')
        if mirror: self._add(lid, self._map(d, lambda x, y: (self.tw - x, y)), key, stroke, sw, 'T')
    # ---- Anpassung an das Zielmodell
    def _warpers(self):
        s, t = lm(SRC), lm(self.model)
        def pl(v, a, b):
            return float(np.interp(v, a, b, left=None, right=None)) if a[0] <= v <= a[-1] else \
                (b[0] + (v - a[0]) * (b[1] - b[0]) / (a[1] - a[0]) if v < a[0] else b[-1] + (v - a[-1]) * (b[-1] - b[-2]) / (a[-1] - a[-2]))
        XS, XT = s['X'], t['X']
        XSr = [s['W'] - v for v in XS[::-1]]; XTr = [t['W'] - v for v in XT[::-1]]
        YS, YT = s['Y'], t['Y']
        sc = t['TW'] / s['TW']
        fL = lambda x, y: (pl(x, XS, XT), pl(y, YS, YT))
        fR = lambda x, y: (pl(x, XSr, XTr), pl(y, YS, YT) + RY)
        fT = lambda x, y: (TX + t['TW'] / 2 + (x - s['TW'] / 2) * sc, pl(y, XS, XT))
        return {'L': fL, 'R': fR, 'T': fT}
    def svg(self, guide):
        b64 = lambda p: base64.b64encode(open(p, 'rb').read()).decode()
        t = lm(self.model); m = self.model
        vis = '' if guide else ' style="display:none"'
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
               f'<g id="Hilfe_Auto_ausblenden"{vis}>'
               f'<image x="0" y="0" width="{t["W"]}" height="{t["H"]}" opacity="0.6" href="data:image/png;base64,{b64(m + "_L.png")}"/>'
               f'<image x="0" y="{RY}" width="{t["W"]}" height="{t["H"]}" opacity="0.6" href="data:image/png;base64,{b64(m + "_R.png")}"/>'
               f'<image x="{TX}" y="0" width="{t["TW"]}" height="{t["TH"]}" opacity="0.6" href="data:image/png;base64,{b64(m + "_T.png")}"/></g>']
        wp = self._warpers()
        for lid, items in self.layers:
            out.append(f'<g id="{lid}">')
            for d, f, s, w, v in items:
                if d == 'IMG':
                    out.append(self._img(f, s, w, v, wp)); continue
                dd = self._map(d, lambda x, y, v=v: wp[v](x, y))
                out.append(f'<path fill="{f}"' + (f' stroke="{s}" stroke-width="{w}" stroke-linejoin="miter" stroke-miterlimit="3"' if s else '') + f' d="{dd}"/>')
            out.append('</g>')
        out.append('</svg>'); return '\n'.join(out)
    def _img(self, name, color, box, view, wp):
        import io, os
        from PIL import Image
        x, y, h, rot = box
        m = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logos', name + '.png')).convert('L')
        c = tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))
        im = Image.new('RGBA', m.size, c + (0,)); im.putalpha(m)
        buf = io.BytesIO(); im.save(buf, 'PNG'); b = base64.b64encode(buf.getvalue()).decode()
        w = h * m.size[0] / m.size[1]
        # Anker + Massstab aus der Verformung des Zielmodells (Logo selbst bleibt unverzerrt)
        cx, cy = wp[view](x, y); ax, _ = wp[view](x - w / 2, y); bx_, _ = wp[view](x + w / 2, y)
        k = abs(bx_ - ax) / w if w else 1; k = min(max(k, 0.6), 1.4)
        W2, H2 = w * k, h * k
        tr = f' transform="rotate({rot} {cx:.1f} {cy:.1f})"' if rot else ''
        return f'<image x="{cx - W2 / 2:.1f}" y="{cy - H2 / 2:.1f}" width="{W2:.1f}" height="{H2:.1f}"{tr} href="data:image/png;base64,{b}"/>'
    def write(self, name):
        if name.startswith('bx_'): name = self.model + name[2:]
        self.out = name
        open(name + '.svg', 'w').write(self.svg(False)); open(name + '_guide.svg', 'w').write(self.svg(True))
