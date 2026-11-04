"""Lackierbare Liveries (Fahrzeugfarbe 1/2/3) – Ebenen-Backer.

Jede Ebene hat einen Schlüssel: 2 = Fahrzeugfarbe 2, 3 = Fahrzeugfarbe 3, 'k' = festes Schwarz (Umrandungen).
Alles, was keine Ebene bedeckt, bleibt Fahrzeugfarbe 1.

Ergebnis je Skin (wie die Vanilla-"Custom"-Skins von BeamNG):
  <skin>_p.color.png  Paletten-Map: Rot = Farbe 1, Grün = Farbe 2, Blau = Farbe 3
  <skin>_b.color.png  Helligkeit (weiß = Lack voll, schwarz = festes Schwarz)
Schlüsselbild (für PSD und Rückweg): Rot/Grün/Blau/Schwarz rein -> Pixel = (r, g, b), Summe = Helligkeit.
"""
import numpy as np
from PIL import Image
from livery import Ctx, Canvas

KEY = {1: (1, 0, 0), 2: (0, 1, 0), 3: (0, 0, 1), 'k': (0, 0, 0)}
KEYHEX = {1: '#ff0000', 2: '#00ff00', 3: '#0000ff', 'k': '#000000'}
LAYER_NAME = {1: 'Farbe 1', 2: 'Farbe 2', 3: 'Farbe 3', 'k': 'Schwarz (fest)'}


class HoodCanvas(Canvas):
    """Dach/Haube von oben: Schrift wird um 180° gedreht, damit sie von vorne lesbar ist."""
    def text(self, a, b, s, *args, **kw):
        from PIL import ImageDraw
        keep_img, keep_d = self.img, self.d
        tmp = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        self.img, self.d = tmp, ImageDraw.Draw(tmp)
        x, y = self.px(a, b)
        # gespiegelten Punkt suchen, damit nach der Drehung (x, y) herauskommt
        a2, b2 = self._inv(self.w - x, self.h - y)
        Canvas.text(self, a2, b2, s, *args, **kw)
        self.img, self.d = keep_img, keep_d
        self.img.alpha_composite(tmp.rotate(180))

    def _inv(self, x, y):
        c, p = self.ctx, self.ppm
        return (x / p - (c.hi[0] - c.lo[0]) / 2, y / p)


class Layer:
    """Ein Satz Projektionsflächen (L, R, T, F, B), der in einer Schlüsselfarbe gezeichnet wird."""
    def __init__(self, pc, key, name):
        self.pc, self.key, self.name = pc, key, name
        self.canv = {}

    def c(self, kind):
        if kind not in self.canv: self.canv[kind] = (HoodCanvas if kind == 'T' else Canvas)(self.pc.ctx, kind)
        return self.canv[kind]

    def sides(self):
        return [self.c('L'), self.c('R')]


class PaintCtx:
    def __init__(self, model):
        self.ctx = Ctx(model)
        self.layers = []

    def layer(self, key, name=None):
        ly = Layer(self, key, name or LAYER_NAME[key])
        self.layers.append(ly); return ly

    def _alpha(self, ly):
        c = self.ctx; P = c.P
        al = np.zeros(len(P), np.float32)
        for k, kind in enumerate('LRTFB'):
            if kind not in ly.canv: continue
            sel = c.cls == k
            if not sel.any(): continue
            if kind in 'LR': a, b = P[sel, 1] - c.lo[1], P[sel, 2]
            elif kind == 'T': a, b = -P[sel, 0], P[sel, 1] - c.lo[1]
            elif kind == 'F': a, b = P[sel, 0], P[sel, 2]
            else: a, b = -P[sel, 0], P[sel, 2]
            al[sel] = ly.canv[kind].sample(a, b)[:, 3]
        return al

    def bake(self, dilate=8):
        """-> dict mit 'key' (Schlüsselbild RGB uint8), 'masks' [(name, key, alpha HxW uint8)], 'palette', 'base' (PIL)."""
        c = self.ctx
        w = np.tile(np.array([1, 0, 0], np.float32), (len(c.P), 1))
        masks = []
        for ly in self.layers:
            a = self._alpha(ly)[:, None]
            w = w * (1 - a) + a * np.array(KEY[ly.key], np.float32)
            m = np.zeros((c.H, c.W), np.float32); m[c.mask] = a[:, 0]
            masks.append((ly.name, ly.key, self._dilate1(m, c.mask, dilate)))
        img = np.zeros((c.H, c.W, 3), np.float32); img[..., 0] = 1
        img[c.mask] = w
        img = self._dilate3(img, c.mask, dilate)
        key = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
        return dict(key=key, masks=masks, uvmask=c.mask)

    @staticmethod
    def _dilate3(img, mask, n):
        m = mask.copy()
        for _ in range(n):
            acc = np.zeros_like(img); cnt = np.zeros(m.shape, np.float32)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                sm = np.roll(m, (dy, dx), (0, 1)); si = np.roll(img, (dy, dx), (0, 1))
                acc += si * sm[..., None]; cnt += sm
            new = (~m) & (cnt > 0)
            img[new] = acc[new] / cnt[new][:, None]; m = m | new
        return img

    @classmethod
    def _dilate1(cls, a, mask, n):
        out = cls._dilate3(a[..., None].copy(), mask, n)[..., 0]
        return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def key_to_maps(key):
    """Schlüsselbild (HxWx3 uint8, rein R/G/B/Schwarz gemischt) -> (Paletten-PIL, Helligkeits-PIL)."""
    k = key.astype(np.float32) / 255.0
    s = k.sum(-1, keepdims=True)
    pal = np.where(s > 1e-3, k / np.maximum(s, 1e-3), np.array([1, 0, 0], np.float32))
    base = np.clip(s, 0, 1)
    pal_im = Image.fromarray((pal * 255 + 0.5).astype(np.uint8), 'RGB')
    base_im = Image.fromarray(np.repeat((base * 255 + 0.5).astype(np.uint8), 3, -1), 'RGB')
    return pal_im, base_im


def preview_tex(key, c1='#c8c8cc', c2='#d81b60', c3='#1e1e1e', bg='#1c1c1c', uvmask=None):
    """Schlüsselbild mit Beispiel-Lackfarben einfärben (nur Vorschau)."""
    k = key.astype(np.float32) / 255.0
    C = np.stack([np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255 for h in (c1, c2, c3)])
    out = k @ C
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB')


def save_psd(path, res, guide=None):
    """Ebenen-PSD: Grund (Farbe 1 = Rot), je Ebene eine Füllfarbe mit Maske, oben ein ausgeblendetes UV-Hilfsbild."""
    from psd_tools import PSDImage
    from psd_tools.api.layers import PixelLayer
    from psd_tools.constants import Compression
    RLE = Compression.RLE
    H, W = res['key'].shape[:2]
    psd = PSDImage.new('RGB', (W, H), color=(255, 0, 0))
    base = Image.new('RGBA', (W, H), (255, 0, 0, 255))
    psd.append(PixelLayer.frompil(base, psd, 'Farbe 1 (Grundlack) = ROT', compression=RLE))
    for name, key, alpha in res['masks']:
        col = tuple(int(v * 255) for v in KEY[key])
        im = Image.new('RGBA', (W, H), col + (0,)); im.putalpha(Image.fromarray(alpha))
        lab = {1: 'ROT', 2: 'GRÜN', 3: 'BLAU', 'k': 'SCHWARZ'}[key]
        psd.append(PixelLayer.frompil(im, psd, f'{name} = {lab}', compression=RLE))
    if guide is not None:
        g = guide.convert('RGBA').resize((W, H)); arr = np.array(g); arr[..., 3] = 255
        ly = PixelLayer.frompil(Image.fromarray(arr), psd, 'UV-Hilfe (nur Ansicht, ausblenden)', compression=RLE)
        ly.visible = False
        psd.append(ly)
    # zusammengesetztes Vorschaubild (für Explorer/Viewer) RLE-komprimiert ablegen
    from psd_tools.psd.image_data import ImageData
    comp = Image.fromarray(res['key'], 'RGB')
    idata = ImageData(compression=RLE)
    idata.set_data([ch.tobytes() for ch in comp.split()], psd._record.header)
    psd._record.image_data = idata
    psd.save(path)
