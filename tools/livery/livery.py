"""Livery-Backer: zeichnet Designs in Fahrzeug-Koordinaten (Meter) und backt sie aufs UV1-Skin-Layout.
Achsen BeamNG: vorne = -y, oben = +z, +x = linke Fahrzeugseite (Fahrersicht), -x = rechte Seite."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get('HB_LIVERY_WORK', os.path.join(HERE, 'work'))

FONTS = os.path.join(HERE, 'fonts') + os.sep
FONT = {
    'jp': FONTS + 'ZenKakuGothicNew-Black.ttf',
    'jpb': FONTS + 'ZenKakuGothicNew-Bold.ttf',
    'jpm': FONTS + 'MPLUS1p-Black.ttf',
    'dela': FONTS + 'DelaGothicOne-Regular.ttf',
    'mincho': FONTS + 'ShipporiMincho-ExtraBold.ttf',
    'latin': FONTS + 'RobotoCondensed.ttf',
}
_fc = {}
def font(name, px):
    k = (name, int(px))
    if k not in _fc:
        f = ImageFont.truetype(FONT[name], max(4, int(px)))
        if name == 'latin':
            try: f.set_variation_by_axes([800])
            except Exception: pass
        _fc[k] = f
    return _fc[k]

def hexc(c, a=255):
    if isinstance(c, tuple): return c if len(c) == 4 else c + (a,)
    c = c.lstrip('#'); return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


class Canvas:
    """Projektionsfläche in Metern. kind: 'L','R' (Seiten, s = Meter ab Fahrzeugfront, z), 'T' (Dach/Haube von oben),
    'F' (Front), 'B' (Heck); bei T/F/B ist die erste Koordinate q = Meter ab Mitte nach rechts im Bild."""
    def __init__(self, ctx, kind, ppm=300):
        self.ctx, self.kind, self.ppm = ctx, kind, ppm
        lo, hi = ctx.lo, ctx.hi
        if kind in 'LR':
            self.w = int((hi[1] - lo[1]) * ppm) + 1; self.h = int((hi[2] - lo[2]) * ppm) + 1
        elif kind == 'T':
            self.w = int((hi[0] - lo[0]) * ppm) + 1; self.h = int((hi[1] - lo[1]) * ppm) + 1
        else:
            self.w = int((hi[0] - lo[0]) * ppm) + 1; self.h = int((hi[2] - lo[2]) * ppm) + 1
        self.img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # Koordinaten -> Pixel
    def px(self, a, b):
        c, p = self.ctx, self.ppm
        if self.kind == 'L': return ((a) * p, (c.hi[2] - b) * p)
        if self.kind == 'R': return ((c.L - a) * p, (c.hi[2] - b) * p)
        if self.kind == 'T': return ((a + (c.hi[0] - c.lo[0]) / 2) * p, (b) * p)  # a = quer (rechts im Bild = Fahrzeug rechts), b = Meter ab Front
        return ((a + (c.hi[0] - c.lo[0]) / 2) * p, (c.hi[2] - b) * p)

    def rect(self, a0, a1, b0, b1, fill):
        p0 = self.px(a0, b0); p1 = self.px(a1, b1)
        self.d.rectangle([min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1])], fill=hexc(fill))

    def ellipse(self, a0, a1, b0, b1, fill):
        p0 = self.px(a0, b0); p1 = self.px(a1, b1)
        self.d.ellipse([min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1])], fill=hexc(fill))

    def poly(self, pts, fill):
        self.d.polygon([self.px(a, b) for a, b in pts], fill=hexc(fill))

    def text(self, a, b, s, fname, size_m, fill, anchor='mm', stroke=0, stroke_fill=None, spacing=0.0, vertical=False, maxw=None):
        """size_m = Schrifthöhe in Metern. spacing in em. vertical = japanisch senkrecht."""
        f = font(fname, size_m * self.ppm)
        x, y = self.px(a, b)
        sw = int(stroke * self.ppm)
        if vertical:
            chars = list(s); step = size_m * self.ppm * (1.0 + spacing)
            total = step * len(chars)
            y0 = y - total / 2 if anchor[1] == 'm' else y
            for i, ch in enumerate(chars):
                self.d.text((x, y0 + step * (i + 0.5)), ch, font=f, fill=hexc(fill), anchor='mm', stroke_width=sw, stroke_fill=hexc(stroke_fill or fill))
            return
        if spacing or maxw:
            # Zeichen einzeln setzen (Laufweite)
            widths = [f.getlength(ch) for ch in s]
            gap = spacing * size_m * self.ppm
            total = sum(widths) + gap * (len(s) - 1)
            scale = 1.0
            if maxw and total > maxw * self.ppm:
                return self.text(a, b, s, fname, size_m * maxw * self.ppm / total, fill, anchor, stroke, stroke_fill, spacing, vertical, None)
            if anchor[0] == 'm': x0 = x - total / 2
            elif anchor[0] == 'r': x0 = x - total
            else: x0 = x
            cx = x0
            for ch, w in zip(s, widths):
                self.d.text((cx, y), ch, font=f, fill=hexc(fill), anchor='l' + anchor[1], stroke_width=sw, stroke_fill=hexc(stroke_fill or fill))
                cx += w + gap
            return
        self.d.text((x, y), s, font=f, fill=hexc(fill), anchor=anchor, stroke_width=sw, stroke_fill=hexc(stroke_fill or fill))

    def paste(self, a, b, im, h_m, anchor='mm'):
        """Bild (RGBA) mit Höhe h_m Meter bei (a,b) einsetzen."""
        hp = max(1, int(h_m * self.ppm)); wp = max(1, int(im.width * hp / im.height))
        im2 = im.resize((wp, hp), Image.LANCZOS)
        x, y = self.px(a, b)
        if anchor[0] == 'm': x -= wp / 2
        elif anchor[0] == 'r': x -= wp
        if anchor[1] == 'm': y -= hp / 2
        elif anchor[1] == 'b': y -= hp
        self.img.alpha_composite(im2, (int(round(x)), int(round(y))))

    def sample(self, A, B):
        """Canvas an Fahrzeugkoordinaten abtasten -> RGBA float."""
        x, y = self.px(A, B)
        x = np.clip(np.round(x).astype(int), 0, self.w - 1); y = np.clip(np.round(y).astype(int), 0, self.h - 1)
        arr = np.asarray(self.img, dtype=np.float32) / 255.0
        return arr[y, x]


class Ctx:
    def __init__(self, model, gbdir=None):
        gbdir = gbdir or (WORK + os.sep)
        d = np.load(gbdir + model + '_gb.npz')
        self.model = model
        self.pos, self.nrm, self.mask = d['pos'], d['nrm'], d['mask']
        self.H, self.W = self.mask.shape
        P = self.pos[self.mask]
        self.lo = np.percentile(P, 0.1, 0); self.hi = np.percentile(P, 99.9, 0)
        self.L = self.hi[1] - self.lo[1]
        self.P = P; N = self.nrm[self.mask]
        ax, ay, az = np.abs(N[:, 0]) * 1.12, np.abs(N[:, 1]), np.abs(N[:, 2])
        side = (ax >= ay) & (ax >= az)
        top = (~side) & (az >= ay)
        fb = (~side) & (~top)
        self.cls = np.where(side, np.where(P[:, 0] > 0, 0, 1), np.where(top, 2, np.where(P[:, 1] < (self.lo[1] + self.hi[1]) / 2, 3, 4)))
        # 0 L, 1 R, 2 T, 3 F, 4 B
        self.canv = {}

    def c(self, kind):
        if kind not in self.canv: self.canv[kind] = Canvas(self, kind)
        return self.canv[kind]

    # Fahrzeugkoordinaten der Texel als Design-Größen
    @property
    def s(self): return self.P[:, 1] - self.lo[1]   # Meter ab Front
    @property
    def z(self): return self.P[:, 2]
    @property
    def x(self): return self.P[:, 0]

    def bake(self, base_rgb, out_png=None, bg='#1c1c1c', dilate=6):
        """base_rgb: (N,3) float 0..1 Grundfarbe je Texel. Canvases werden je Flächenklasse darübergelegt."""
        col = base_rgb.copy()
        P = self.P
        for k, (kind, A, B) in enumerate([('L', None, None), ('R', None, None), ('T', None, None), ('F', None, None), ('B', None, None)]):
            if kind not in self.canv: continue
            sel = self.cls == k
            if not sel.any(): continue
            cv = self.canv[kind]
            if kind in 'LR': a, b = P[sel, 1] - self.lo[1], P[sel, 2]
            elif kind == 'T': a, b = -P[sel, 0], P[sel, 1] - self.lo[1]
            elif kind == 'F': a, b = P[sel, 0], P[sel, 2]
            else: a, b = -P[sel, 0], P[sel, 2]
            rgba = cv.sample(a, b)
            al = rgba[:, 3:4]
            col[sel] = col[sel] * (1 - al) + rgba[:, :3] * al
        img = np.zeros((self.H, self.W, 3), np.float32) + np.array(hexc(bg)[:3]) / 255.0
        img[self.mask] = col
        # Ränder auffüllen (Dilatation), damit keine Nähte entstehen
        m = self.mask.copy()
        for _ in range(dilate):
            acc = np.zeros_like(img); cnt = np.zeros(m.shape, np.float32)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                sm = np.roll(m, (dy, dx), (0, 1)); si = np.roll(img, (dy, dx), (0, 1))
                acc += si * sm[..., None]; cnt += sm
            new = (~m) & (cnt > 0)
            img[new] = acc[new] / cnt[new][:, None]; m = m | new
        out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        if out_png: out.save(out_png)
        return out


def zbands(ctx, bands, default):
    """bands: Liste (z_von, z_bis, farbe). Spätere überschreiben frühere."""
    z = ctx.z
    col = np.tile(np.array(hexc(default)[:3], np.float32) / 255, (len(z), 1))
    for z0, z1, c in bands:
        sel = (z >= z0) & (z < z1)
        col[sel] = np.array(hexc(c)[:3], np.float32) / 255
    return col
