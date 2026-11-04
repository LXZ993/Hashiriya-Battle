"""Gemeinsame SVG-Vorlage: Seite links (Front links) bei (0,0), Draufsicht (Front oben) bei (950,0), 200 px/m."""
import base64, re
KEYC = {1: '#ff0000', 2: '#00ff00', 3: '#0000ff', 'k': '#000000'}
class Doc:
    def __init__(self, model, W=1300, H=900, TX=950):
        self.model, self.W, self.H, self.TX = model, W, H, TX
        self.layers = []  # (id, [(d, fill, stroke, sw)])
        from PIL import Image
        self.tw = Image.open(f'{model}_T.png').size[0]
        self.lw = Image.open(f'{model}_L.png').size[0]
        self.RY = 260   # Seite rechts (Front rechts) bei (0, RY)
    def layer(self, lid):
        for l in self.layers:
            if l[0] == lid: return l[1]
        self.layers.append((lid, [])); return self.layers[-1][1]
    def mv(self, p, ox, oy, fx=False, w=None):
        tw = w or self.tw
        def f(m):
            x, y = float(m.group(1)), float(m.group(2))
            if fx: x = tw - x
            return f'{x + ox:.1f} {y + oy:.1f}'
        return re.sub(r'(-?\d+\.?\d*)[ ,](-?\d+\.?\d*)', f, p)
    def side(self, lid, d, key, stroke=None, sw=0):
        """Form links zeichnen und gespiegelt rechts."""
        self.layer(lid).append((d, KEYC[key], KEYC.get(stroke), sw))
        self.layer(lid).append((self.mv(d, 0, self.RY, fx=True, w=self.lw), KEYC[key], KEYC.get(stroke), sw))
    def side_text(self, lid, s, fname, size, x, y, key, rot=0, stroke=None, sw=0, xr=None, yr=None, **kw):
        """Schrift links und rechts lesbar (nicht gespiegelt), rechts an der gespiegelten Stelle."""
        from txt import text
        dl, *_ = text(s, fname, size, x, y, rot=rot, **kw)
        dr, *_ = text(s, fname, size, self.lw - x if xr is None else xr, (y if yr is None else yr) + self.RY, rot=-rot, **kw)
        for d in (dl, dr):
            if stroke: self.layer(lid).append((d, KEYC[stroke], KEYC[stroke], sw))
            self.layer(lid).append((d, KEYC[key], None, 0))
    def top(self, lid, d, key, stroke=None, sw=0, mirror=False):
        self.layer(lid).append((self.mv(d, self.TX, 0), KEYC[key], KEYC.get(stroke), sw))
        if mirror: self.layer(lid).append((self.mv(d, self.TX, 0, fx=True), KEYC[key], KEYC.get(stroke), sw))
    def svg(self, guide):
        b64 = lambda p: base64.b64encode(open(p, 'rb').read()).decode()
        from PIL import Image
        L = Image.open(f'{self.model}_L.png').size; T = Image.open(f'{self.model}_T.png').size
        vis = '' if guide else ' style="display:none"'
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.W}" height="{self.H}" viewBox="0 0 {self.W} {self.H}">',
               f'<g id="Hilfe_Auto_ausblenden"{vis}><image x="0" y="0" width="{L[0]}" height="{L[1]}" opacity="0.6" href="data:image/png;base64,{b64(self.model + "_L.png")}"/>'
               f'<image x="0" y="{self.RY}" width="{L[0]}" height="{L[1]}" opacity="0.6" href="data:image/png;base64,{b64(self.model + "_R.png")}"/>'
               f'<image x="{self.TX}" y="0" width="{T[0]}" height="{T[1]}" opacity="0.6" href="data:image/png;base64,{b64(self.model + "_T.png")}"/></g>']
        for lid, items in self.layers:
            out.append(f'<g id="{lid}">' + ''.join(
                f'<path fill="{f}"' + (f' stroke="{s}" stroke-width="{w}" stroke-linejoin="miter" stroke-miterlimit="3"' if s else '') + f' d="{d}"/>'
                for d, f, s, w in items) + '</g>')
        out.append('</svg>'); return '\n'.join(out)
    def write(self, name):
        open(name + '.svg', 'w').write(self.svg(False)); open(name + '_guide.svg', 'w').write(self.svg(True))
