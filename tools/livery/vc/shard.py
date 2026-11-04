"""Hilfen fuer gezackte Street-Drift-Splitter als SVG-Pfade (Koordinaten in Pixeln der Ansicht)."""
import math, random

def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

def bez(p, t):
    """kubische Bezier aus 4 Punkten"""
    u = 1 - t
    return (u**3*p[0][0] + 3*u*u*t*p[1][0] + 3*u*t*t*p[2][0] + t**3*p[3][0],
            u**3*p[0][1] + 3*u*u*t*p[1][1] + 3*u*t*t*p[2][1] + t**3*p[3][1])

def frame(p, t, e=1e-3):
    a = bez(p, max(0, t - e)); b = bez(p, min(1, t + e))
    dx, dy = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dy) or 1
    return (dx / l, dy / l), (-dy / l, dx / l)

def shard(spine, w0, w1, n=7, spike=1.0, lean=0.55, seed=1, tipcut=0.0, low=0.25, side=1):
    """Band entlang spine (Bezier), Breite w0->w1, Oberkante mit n schraegen Zacken (Richtung Ende),
    Unterkante leicht gezackt. Gibt Punktliste (Polygon) zurueck."""
    rnd = random.Random(seed)
    top, bot = [], []
    N = n * 3
    for i in range(N + 1):
        t = i / N
        c = bez(spine, t); tg, nm = frame(spine, t); nm = (nm[0] * side, nm[1] * side)
        w = w0 + (w1 - w0) * t
        k = i % 3
        if k == 1 and 0 < i < N:
            # Zackenspitze: nach aussen und nach hinten gezogen
            h = w * spike * (0.8 + 0.6 * rnd.random())
            top.append((c[0] + nm[0] * (w / 2 + h) + tg[0] * h * lean, c[1] + nm[1] * (w / 2 + h) + tg[1] * h * lean))
        elif k == 2:
            # Kerbe
            top.append((c[0] + nm[0] * w * 0.15, c[1] + nm[1] * w * 0.15))
        else:
            top.append((c[0] + nm[0] * w / 2, c[1] + nm[1] * w / 2))
        if i % 4 == 2 and 0 < i < N:
            h = w * low * (0.5 + rnd.random())
            bot.append((c[0] - nm[0] * (w / 2 + h) + tg[0] * h * 0.9, c[1] - nm[1] * (w / 2 + h) + tg[1] * h * 0.9))
        else:
            bot.append((c[0] - nm[0] * w / 2, c[1] - nm[1] * w / 2))
    tip = bez(spine, 1); tg, nm = frame(spine, 1)
    w = w1
    tip = (tip[0] + tg[0] * max(w * 2.5, 6), tip[1] + tg[1] * max(w * 2.5, 6))
    tail = bez(spine, 0); tg0, _ = frame(spine, 0)
    tail = (tail[0] - tg0[0] * w0 * 0.6, tail[1] - tg0[1] * w0 * 0.6)
    return [tail] + top + [tip] + bot[::-1]

def d(pts, dx=0, dy=0):
    return 'M' + ' L'.join(f'{x + dx:.1f} {y + dy:.1f}' for x, y in pts) + ' Z'

def flip_y(spine, H):
    return [(x, H - y) for x, y in spine]


def blade(base, ang, L, w, curl=0.35):
    """Geschwungene Klinge (Flammenzunge) ab base in Richtung ang (Grad, SVG-Koordinaten), Laenge L, Fussbreite w.
    curl > 0 biegt die Spitze nach links (gegen den Uhrzeiger)."""
    a = math.radians(ang); t = (math.cos(a), math.sin(a)); n = (-t[1], t[0])
    bl = (base[0] + n[0] * w / 2, base[1] + n[1] * w / 2)
    br = (base[0] - n[0] * w / 2, base[1] - n[1] * w / 2)
    a2 = a - curl; tip = (base[0] + math.cos(a2) * L, base[1] + math.sin(a2) * L)
    c1 = (base[0] + t[0] * L * 0.55 + n[0] * w * 0.35, base[1] + t[1] * L * 0.55 + n[1] * w * 0.35)
    c2 = (base[0] + t[0] * L * 0.62 - n[0] * w * 0.05, base[1] + t[1] * L * 0.62 - n[1] * w * 0.05)
    return f'M{bl[0]:.1f} {bl[1]:.1f} Q{c1[0]:.1f} {c1[1]:.1f} {tip[0]:.1f} {tip[1]:.1f} Q{c2[0]:.1f} {c2[1]:.1f} {br[0]:.1f} {br[1]:.1f} Z'


def claw(spine, w0, w1, n=6, Lmin=0.8, Lmax=2.2, ang=-35, curl=0.3, seed=1, side=1, under=0, ux=0.6):
    """Street-Drift-Splitter: spitz zulaufender Kern entlang spine plus n geschwungene Klingen, die zur Seite
    `side` (1 = links der Laufrichtung) schraeg nach hinten (ang Grad zur Laufrichtung) herausreissen.
    Laengen in Vielfachen der lokalen Breite. Liefert Liste von SVG-Pfaden."""
    rnd = random.Random(seed)
    out = []
    # Kern: spitz an beiden Enden, an der Wurzel breit
    N = 24; top, bot = [], []
    for i in range(N + 1):
        t = i / N; c = bez(spine, t); tg, nm = frame(spine, t)
        w = (w0 + (w1 - w0) * t) * math.sin(math.pi * min(1, t * 1.6 + 0.05)) ** 0.6 if t < 0.6 else (w0 + (w1 - w0) * t) * (1 - (t - 0.6) / 0.4 * 0.85)
        top.append((c[0] + nm[0] * w / 2, c[1] + nm[1] * w / 2)); bot.append((c[0] - nm[0] * w / 2, c[1] - nm[1] * w / 2))
    tip = bez(spine, 1); tg, _ = frame(spine, 1); tip = (tip[0] + tg[0] * w1 * 3, tip[1] + tg[1] * w1 * 3)
    out.append(d(top + [tip] + bot[::-1]))
    for k in range(n):
        t = 0.12 + (k + 0.5 + (rnd.random() - 0.5) * 0.5) / n * 0.8
        c = bez(spine, t); tg, nm = frame(spine, t)
        w = w0 + (w1 - w0) * t
        base = (c[0] + nm[0] * w * 0.38 * side, c[1] + nm[1] * w * 0.38 * side)
        dir_ = math.degrees(math.atan2(tg[1], tg[0]))
        a = dir_ + side * ang * (0.85 + 0.3 * rnd.random())  # in Laufrichtung, zur Seite geneigt
        L = w * (Lmin + (Lmax - Lmin) * rnd.random())
        out.append(blade(base, a, L, w * 0.62, curl * side * (0.4 + 0.8 * rnd.random())))
    for k in range(under):
        t = (k + 0.7) / (under + 0.5) * 0.85
        c = bez(spine, t); tg, nm = frame(spine, t); w = w0 + (w1 - w0) * t
        base = (c[0] - nm[0] * w * 0.3 * side, c[1] - nm[1] * w * 0.3 * side)
        dir_ = math.degrees(math.atan2(tg[1], tg[0]))
        a = dir_ - side * ang * 0.8
        out.append(blade(base, a, w * ux * (1 + rnd.random()), w * 0.5, curl * side * 0.6))
    return out


def spear(spine, wmax, hooks, ang=24, curl=0.45, peak=0.72, hw=0.85, N=48):
    """Ein zusammenhaengendes Tribal: spitzer Kern entlang spine (Anfang = vorne, Ende = hinten), Breite steigt bis
    `peak` und laeuft hinten spitz aus. hooks = [(t, laenge_in_wmax, seite)], alle Haken gleich geformt (Widerhaken
    nach hinten, Spitze zur Karosserie zurueckgebogen). seite 1 = rechts der Laufrichtung (SVG), -1 = links."""
    def wid(t):
        return wmax * (math.sin(math.pi / 2 * t / peak) ** 1.3 if t < peak else math.cos(math.pi / 2 * (t - peak) / (1 - peak)) ** 0.8)
    top, bot = [], []
    for i in range(N + 1):
        t = i / N; c = bez(spine, t); tg, nm = frame(spine, t); w = max(wid(t), 0.4)
        top.append((c[0] - nm[0] * w / 2, c[1] - nm[1] * w / 2)); bot.append((c[0] + nm[0] * w / 2, c[1] + nm[1] * w / 2))
    out = [d(top + bot[::-1])]
    for t, L, s in hooks:
        c = bez(spine, t); tg, nm = frame(spine, t); w = wid(t)
        base = (c[0] + nm[0] * w * 0.3 * s, c[1] + nm[1] * w * 0.3 * s)
        dr = math.degrees(math.atan2(tg[1], tg[0]))
        out.append(blade(base, dr + s * ang, L * wmax, w * hw, curl * s))
    return out
