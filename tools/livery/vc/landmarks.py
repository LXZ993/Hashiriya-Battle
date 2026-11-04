"""Orientierungspunkte je Modell (Pixel bei 200 px/m in den Ansichten): Radlaeufe, Fensterlinie, Schweller."""
import numpy as np, sys
from PIL import Image
sys.path.insert(0, '/home/user/hashiriya-battle/tools/livery')
GEO = {'pessima': (0.84, 0.30), 'midsize': (0.92, 0.27), 'bx': (0.82, 0.30), 'covet': (0.86, 0.28), 'hopper': (1.10, 0.47),
       'miramar': (0.88, 0.32), 'pigeon': (0.95, 0.36), 'sunburst2': (0.88, 0.26), 'sbr': (0.80, 0.26)}
MANUAL = {'pigeon': [(60, 170), (440, 555)], 'hopper': [(95, 192)]}   # vorderer Radlauf, wo die Erkennung nicht greift
_c = {}
def lm(m, d='.'):
    if m in _c: return _c[m]
    im = Image.open(f'{d}/{m}_L.png'); a = np.array(im)[..., 3] > 0; H, W = a.shape
    bot = np.array([np.nonzero(a[:, x])[0].max() if a[:, x].any() else -1 for x in range(W)])
    arch = bot < H * 0.80; runs = []; s = None
    for x in range(W):
        if arch[x] and s is None: s = x
        if not arch[x] and s is not None: runs.append((s, x)); s = None
    runs = [r for r in runs if r[1] - r[0] > 40 and r[0] > 10 and r[1] < W - 10]
    if m in MANUAL: runs = MANUAL[m] + ([] if len(MANUAL[m]) > 1 else [r for r in runs if r[0] > W / 2])
    f, r = runs[0], runs[-1]
    # Hoehe: hi_z aus der Groesse ableiten -> hi_z = lo_z + H/200; belt/sill in Pixel
    from livery import Ctx
    import os
    c = Ctx(m); hz = c.hi[2]
    belt, sill = GEO[m]
    T = Image.open(f'{d}/{m}_T.png').size
    out = dict(W=W, H=H, X=[0, f[0], f[1], r[0], r[1], W], Y=[0, float((hz - belt) * 200), float((hz - sill) * 200), H], TW=T[0], TH=T[1])
    _c[m] = out; return out
