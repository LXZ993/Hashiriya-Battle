"""VectorCraft-PNG (Seite links bei SX,SY; Draufsicht bei TX,TY; ppm 200*scale) -> Schluesselbild -> Vorschau."""
import sys, os, subprocess, numpy as np
sys.path.insert(0, '/home/user/hashiriya-battle/tools/livery')
from PIL import Image
from livery import Ctx
from paint import preview_tex, PaintCtx
import preview
def bake_key(model, png, SX=0, SY=0, RY=300, TX=1000, TY=0, ppm0=200, scale=1.5, dilate=8):
    c = Ctx(model); P = c.P; lo, hi = c.lo, c.hi
    im = np.asarray(Image.open(png).convert('RGBA')).astype(np.float32) / 255
    Hh, Ww = im.shape[:2]; p = ppm0 * scale
    def samp(x, y):
        x = np.clip(np.round(x).astype(int), 0, Ww - 1); y = np.clip(np.round(y).astype(int), 0, Hh - 1)
        return im[y, x]
    rgba = np.zeros((len(P), 4), np.float32)
    # Front/Heck-Flaechen: Seitenansicht der jeweiligen Haelfte fortsetzen (Farbe laeuft um die Ecke)
    low = P[:, 2] < lo[2] + (hi[2] - lo[2]) * 0.45   # untere Flaechen (Schweller, Schuerzen) nie von oben
    fb = (c.cls == 3) | (c.cls == 4) | ((c.cls == 2) & low)
    side = (c.cls == 0) | (fb & (P[:, 0] > 0))
    rgba[side] = samp(SX * scale + (P[side, 1] - lo[1]) * p, SY * scale + (hi[2] - P[side, 2]) * p)
    rs = (c.cls == 1) | (fb & (P[:, 0] <= 0))   # rechte Seite: eigene Ansicht bei RY, Front rechts
    rgba[rs] = samp(SX * scale + (hi[1] - P[rs, 1]) * p, (SY + RY) * scale + (hi[2] - P[rs, 2]) * p)
    top = (c.cls == 2) & ~low
    rgba[top] = samp(TX * scale + (-P[top, 0] + (hi[0] - lo[0]) / 2) * p, TY * scale + (P[top, 1] - lo[1]) * p)
    a = rgba[:, 3:4]
    w = rgba[:, :3] * a + np.array([1, 0, 0], np.float32) * (1 - a)
    img = np.zeros((c.H, c.W, 3), np.float32); img[..., 0] = 1; img[c.mask] = w
    img = PaintCtx._dilate3(img, c.mask, dilate)
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
def bake_fix(model, png, dilate=8, **kw):
    """Feste Farben (nicht einfaerbbar): RGBA im UV-Raum, gleiche Abbildung wie bake_key."""
    c = Ctx(model)
    im = np.asarray(Image.open(png).convert('RGBA')).astype(np.float32) / 255
    pm = np.concatenate([im[..., :3] * im[..., 3:4], im[..., 3:4]], -1)   # vormultipliziert
    tmp = png + '.pm.png'
    Image.fromarray((pm[..., :3] * 255 + 0.5).astype(np.uint8), 'RGB').save(tmp)
    rgb = bake_key(model, tmp, dilate=dilate, **kw).astype(np.float32) / 255
    a_im = np.repeat(pm[..., 3:4], 3, -1)
    Image.fromarray((a_im * 255 + 0.5).astype(np.uint8), 'RGB').save(tmp)
    a = bake_key(model, tmp, dilate=dilate, **kw).astype(np.float32)[..., 1:2] / 255   # Gruen: Leerflaeche (1,0,0) -> 0
    os.remove(tmp)
    # bake_key fuellt Leerflaechen rot (1,0,0): ueberall wo die Alpha 0 ist, Farbe egal
    col = np.where(a > 1e-3, np.clip(rgb / np.maximum(a, 1e-3), 0, 1), 0)
    return np.concatenate([col, a], -1)
def fix_png(png):
    f = png[:-4] + '_fix.png'
    return f if os.path.exists(f) else None
if __name__ == '__main__':
    model, png, out = sys.argv[1:4]; cols = sys.argv[4].split(',') if len(sys.argv) > 4 else ['#c9c9cd', '#e0287a', '#151515']
    views = sys.argv[5].split(';') if len(sys.argv) > 5 else ['40,14', '90,3', '-40,14', '0,70']
    key = bake_key(model, png); np.save(out + '_key.npy', key)
    tp = out + '_tex.png'; tex = preview_tex(key, *cols)
    if fix_png(png):
        fx = bake_fix(model, fix_png(png)); a = fx[..., 3:4]
        t = np.asarray(tex).astype(np.float32) / 255 * (1 - a) + fx[..., :3] * a
        tex = Image.fromarray((t * 255 + 0.5).astype(np.uint8), 'RGB')
    tex.save(tp)
    glb = f'p_vc_{os.getpid()}.glb'; preview.make(model, tp, os.path.join(preview.HERE, 'web', glb))
    subprocess.run(['node', os.path.join(preview.HERE, 'web', 'shot.js'), glb, out, *views], check=True)
    os.remove(os.path.join(preview.HERE, 'web', glb))
