"""Hashiriya Battle Porträts v2: Bob-Figuren als geschichtete Vektor-Illustration.

Erzeugt SVG-Dateien, die VectorCraft rendert (PNG) und als PSD mit einer Ebene je Teil speichert.
Weiche Schatten und Glanzlichter sind eigene Pfade mit einem Namens-Kürzel; vc_steps() macht daraus
die VectorCraft-Effekte (Weichzeichnen, Schlagschatten, Schein nach innen). Für die Vorschau im
Browser (preview=True) stehen dieselben Effekte als SVG-Filter drin.

Aufruf: python portrait.py OUTDIR   -> OUTDIR/<name>.svg (+ _preview.svg, _steps.json)
"""
import json, math, os, sys

W = H = 600
CX = 300


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


class Doc:
    """Sammelt Ebenen (oberste <g>), Verläufe und Effekt-Pfade."""

    def __init__(self, preview):
        self.preview = preview
        self.defs = []
        self.layers = []
        self.fx = []  # (name, effect, params)
        self.n = 0

    def uid(self, p="o"):
        self.n += 1
        return f"{p}{self.n:03d}"  # feste Länge: kein Name ist Teilstring eines anderen

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self.uid("lg")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{i})"

    def rad(self, stops, cx=.5, cy=.5, r=.5, fx=None, fy=None):
        i = self.uid("rg")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        fxy = f' fx="{fx}" fy="{fy}"' if fx is not None else ""
        self.defs.append(f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}"{fxy}>{st}</radialGradient>')
        return f"url(#{i})"

    def clip(self, d):
        i = self.uid("cp")
        self.defs.append(f'<clipPath id="{i}"><path d="{d}"/></clipPath>')
        return f'clip-path="url(#{i})"'

    def soft(self, d, fill, blur, opacity=1, extra=""):
        """Weicher Pfad (Schatten/Licht): in VectorCraft per blur.gaussian."""
        name = self.uid("fxblur")
        self.fx.append((name, "blur.gaussian", {"radius": blur}))
        flt = f' filter="url(#b{blur})"' if self.preview else ""
        if self.preview and f'id="b{blur}"' not in "".join(self.defs):
            self.defs.append(f'<filter id="b{blur}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{blur * .6}"/></filter>')
        return f'<path id="{name}" d="{d}" fill="{fill}" opacity="{opacity}"{flt} {extra}/>'

    def shadowed(self, name, body, dx=0, dy=6, blur=8, opacity=40):
        """Gruppe mit Schlagschatten (VectorCraft stylize.dropShadow)."""
        self.fx.append((name, "stylize.dropShadow", {"opacity": opacity, "x": dx, "y": dy, "blur": blur}))
        flt = ""
        if self.preview:
            fid = self.uid("ds")
            self.defs.append(f'<filter id="{fid}" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="{dx}" dy="{dy}" stdDeviation="{blur * .5}" flood-opacity="{opacity / 100}"/></filter>')
            flt = f' filter="url(#{fid})"'
        return f'<g id="{name}"{flt}>{body}</g>'

    def layer(self, name, body):
        # Kopf-Ebenen sitzen tiefer (kurzer Bob-Hals); verschoben per Transform
        tf = f' transform="translate(0,{HEAD_DY})"' if name in HEAD_LAYERS else ""
        self.layers.append(f'<g id="{name}"{tf}>{body}</g>')

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.layers)}</svg>')


# ---------------------------------------------------------------------------
# Formen
# ---------------------------------------------------------------------------
def egg(cx, cy, rx, ryt, ryb):
    k = .5523
    return (f"M{f(cx)},{f(cy - ryt)} C{f(cx + rx * k)},{f(cy - ryt)} {f(cx + rx)},{f(cy - ryt * k)} {f(cx + rx)},{f(cy)} "
            f"C{f(cx + rx)},{f(cy + ryb * k)} {f(cx + rx * k)},{f(cy + ryb)} {f(cx)},{f(cy + ryb)} "
            f"C{f(cx - rx * k)},{f(cy + ryb)} {f(cx - rx)},{f(cy + ryb * k)} {f(cx - rx)},{f(cy)} "
            f"C{f(cx - rx)},{f(cy - ryt * k)} {f(cx - rx * k)},{f(cy - ryt)} {f(cx)},{f(cy - ryt)} Z")


def ell(cx, cy, rx, ry):
    return egg(cx, cy, rx, ry, ry)


def bean(k=1.0, o=0):
    """Bob-Oberkörper. k = Schulterbreite, o = Aufmaß für Kleidung."""
    L, R = CX - 182 * k - o, CX + 182 * k + o
    t = 372 - o
    return (f"M{f(L)},{f(t + 108)} C{f(L)},{f(t + 30)} {f(CX - 95 * k)},{f(t)} {CX},{f(t)} "
            f"C{f(CX + 95 * k)},{f(t)} {f(R)},{f(t + 30)} {f(R)},{f(t + 108)} "
            f"C{f(R)},{f(t + 170)} {f(R - 6)},{f(t + 210)} {f(R - 12)},640 L{f(L + 12)},640 "
            f"C{f(L + 6)},{f(t + 210)} {f(L)},{f(t + 170)} {f(L)},{f(t + 108)} Z")


def mirror(d):
    import re
    return re.sub(r"(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)", lambda m: f"{f(2 * CX - float(m.group(1)))},{m.group(2)}", d)


def shade_shell(doc, d, bbox, rim, base=("#f6f7f9", "#cdd2d9", "#8a919b")):
    """Glatte Kunststoff-Hülle wie bei Bob: Grundverlauf, Kernschatten, Glanzlicht, Randlicht."""
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    cp = doc.clip(d)
    out = f'<path d="{d}" fill="{doc.rad([(0, base[0], 1), (.55, base[1], 1), (1, base[2], 1)], cx=.38, cy=.3, r=.85)}"/>'
    out += f"<g {cp}>"
    # Kernschatten rechts unten
    out += doc.soft(ell(x1 - w * .05, y1 - h * .05, w * .45, h * .42), "#5b626d", max(6, w / 14), .55)
    # Glanzlicht oben links + kleiner Spiegelpunkt
    out += doc.soft(ell(x0 + w * .34, y0 + h * .26, w * .2, h * .13), "#ffffff", max(4, w / 18), .9)
    out += doc.soft(ell(x0 + w * .3, y0 + h * .2, w * .06, h * .04), "#ffffff", 2, 1)
    # Randlicht in Crewfarbe rechts
    out += doc.soft(ell(x1 + w * .08, y0 + h * .45, w * .14, h * .5), rim, max(4, w / 20), .55)
    out += "</g>"
    out += f'<path d="{d}" fill="none" stroke="#3a3f47" stroke-opacity=".35" stroke-width="1.5"/>'
    return out


def cloth(doc, d, tone, rim, folds=(), light=.35):
    """Stoff: Verlauf, weiche Falten, Licht auf den Schultern, Randlicht."""
    cp = doc.clip(d)
    out = f'<path d="{d}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)], 0, 0, .35, 1)}"/>'
    out += f"<g {cp}>"
    out += doc.soft("M110,470 C150,410 230,392 300,392 C370,392 450,410 490,470 L490,440 C450,380 370,366 300,366 C230,366 150,380 110,440 Z", "#ffffff", 10, light * .5)
    for fd in folds:
        out += doc.soft(fd, "#000000", 5, .35)
    out += doc.soft("M470,420 C510,470 505,560 490,640 L520,640 L520,420 Z", rim, 10, .6)
    out += "</g>"
    out += f'<path d="{d}" fill="none" stroke="#000" stroke-opacity=".45" stroke-width="1.6"/>'
    return out


def stitch(d, col="#ffffff", op=.25, w=1.2):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-opacity="{op}" stroke-width="{w}" stroke-dasharray="4 3"/>'


def line(d, col, w=2, op=1, cap="round"):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round"/>'


# ---------------------------------------------------------------------------
# Figur
# ---------------------------------------------------------------------------
HEAD_DY = 30
HEAD_LAYERS = {"Haare_hinten", "Kopf", "Visier", "Haare", "Brille", "Extra_Kopf"}
HEAD = dict(cx=300, cy=222, rx=88, ryt=100, ryb=92)


def background(doc, A, jp):
    out = f'<rect width="{W}" height="{H}" fill="{doc.lin([(0, "#151821", 1), (1, "#07080b", 1)])}"/>'
    out += f'<rect width="{W}" height="{H}" fill="{doc.rad([(0, A, .45), (.5, A, .08), (1, A, 0)], cx=.15, cy=1, r=.95)}"/>'
    for i in range(14):
        x = -200 + i * 70
        out += f'<path d="M{x},600 L{x + 340},0" stroke="#ffffff" stroke-opacity=".025" stroke-width="18"/>'
    for i, ch in enumerate(jp[:8]):
        out += f'<text x="548" y="{70 + i * 62}" text-anchor="middle" font-size="54" font-weight="700" font-family="Yu Gothic, Meiryo, Noto Sans JP, sans-serif" fill="{A}" fill-opacity=".14">{ch}</text>'
    out += f'<rect y="592" width="{W}" height="8" fill="{A}"/>'
    doc.layer("Hintergrund", out)


def body(doc, A, k):
    d = bean(k)
    neck = "M278,296 L322,296 L326,384 L274,384 Z"
    out = shade_shell(doc, neck, (274, 296, 326, 384), A)
    out += doc.soft(ell(300, 316 + HEAD_DY, 36, 14), "#3a3f47", 6, .6)  # Schatten unter dem Kinn
    out += shade_shell(doc, d, (CX - 182 * k, 372, CX + 182 * k, 640), A)
    doc.layer("Koerper", out)


def head(doc, A, eyes, lashes=False):
    h = HEAD
    d = egg(h["cx"], h["cy"], h["rx"], h["ryt"], h["ryb"])
    out = shade_shell(doc, d, (h["cx"] - h["rx"], h["cy"] - h["ryt"], h["cx"] + h["rx"], h["cy"] + h["ryb"]), A)
    doc.layer("Kopf", doc.shadowed("fxds_Kopf", out, 0, 8, 10, 35))
    # Visier
    vd = "M222,208 C222,176 258,164 300,164 C342,164 378,176 378,208 C378,240 342,252 300,252 C258,252 222,240 222,208 Z"
    v = f'<path d="{vd}" fill="{doc.lin([(0, "#30394a", 1), (.55, "#0b0e14", 1), (1, "#05070a", 1)])}" stroke="#20252d" stroke-width="3"/>'
    cp = doc.clip(vd)
    dots_on, dots_off = [], []
    for gy in range(-5, 6):
        for gx in range(-9, 10):
            x, y = 300 + gx * 8, 208 + gy * 8
            if abs((x - 300) / 70) ** 2.6 + abs((y - 208) / 38) ** 2.6 >= 1:
                continue
            (dots_on if eyes(gx, gy) or (lashes and lash(eyes, gx, gy)) else dots_off).append(
                f'<rect x="{x - 2.6}" y="{y - 2.6}" width="5.2" height="5.2" rx="1.2"/>')
    v += f'<g fill="#ffffff" fill-opacity=".06">{"".join(dots_off)}</g>'
    glow = doc.uid("fxglowled")
    doc.fx.append((glow, "stylize.outerGlow", {"color": "#bfe0ff", "opacity": 85, "blur": 6, "mode": "screen"}))
    gflt = ""
    if doc.preview:
        doc.defs.append(f'<filter id="{glow}f" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
        gflt = f' filter="url(#{glow}f)"'
    v += f'<g id="{glow}" fill="#eef7ff"{gflt}>{"".join(dots_on)}</g>'
    # Spiegelung oben
    v += f'<g {cp}><path d="M230,196 C236,176 266,170 300,170 C334,170 364,176 370,196 C350,186 326,183 300,183 C274,183 250,186 230,196 Z" fill="#ffffff" fill-opacity=".22"/></g>'
    v += doc.soft("M244,240 C270,248 330,248 356,240", "none", 2, .0)
    doc.layer("Visier", v)


def lash(eyes, gx, gy):
    for sd in (-1, 1):
        ex = 4 * sd
        tops = [dy for dy in range(-5, 5) for dx in range(-2, 3) if eyes(ex + dx, dy)]
        if not tops:
            continue
        t = min(tops)
        dx = gx - ex
        if (dx * sd == 2 and gy == t - 1) or (dx * sd == 3 and gy == t - 2):
            return True
    return False


def eyes_normal(gx, gy):
    return any(abs(gx - e) <= 1 and -2 <= gy <= 1 for e in (-4, 4))


def eyes_grim(gx, gy):
    for e, sd in ((-4, -1), (4, 1)):
        dx = gx - e
        if abs(dx) <= 1 and -1 <= gy <= 1 and not (gy == -1 and dx * sd < 0):
            return True
        if gy == -2 and dx * sd == 1:
            return True
    return False


def eyes_smile(gx, gy):
    for e in (-4, 4):
        dx = gx - e
        if (gy == -1 and dx == 0) or (gy == 0 and abs(dx) == 1) or (gy == 1 and abs(dx) == 2):
            return True
    return False


# ---------------------------------------------------------------------------
# Haare
# ---------------------------------------------------------------------------
def hair_paint(doc, d, base, A, sheen=True):
    cp = doc.clip(d)
    out = f'<path d="{d}" fill="{doc.lin([(0, base[0], 1), (1, base[1], 1)], 0, 0, .3, 1)}"/>'
    out += f"<g {cp}>"
    if sheen:
        out += doc.soft("M215,150 C250,120 330,112 370,140 L372,152 C330,128 255,134 218,164 Z", "#ffffff", 5, .35)
    out += doc.soft("M372,120 C400,160 404,220 396,260 L420,260 L420,110 Z", A, 8, .5)
    out += "</g>"
    out += f'<path d="{d}" fill="none" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    return out


def hair_spiky(doc, A, base):
    h = HEAD
    pts = []
    n = 11
    for i in range(n + 1):
        a = math.pi * (1.06 + .88 * i / n)
        r_in = 1.02
        r_out = 1.34 + (.1 if i % 2 else 0)
        for j, (rr, da) in enumerate(((r_in, -.06), (r_out, 0), (r_in, .06))):
            if j == 1 and (i == 0 or i == n):
                continue
            pts.append((h["cx"] + math.cos(a + da) * h["rx"] * rr, h["cy"] - 18 + math.sin(a + da) * h["ryt"] * rr * .95))
    # Pony vorn gezackt
    fr = [(392, 196), (372, 168), (356, 186), (336, 160), (318, 182), (300, 156), (282, 182), (264, 160), (246, 186), (228, 168), (208, 196)]
    d = "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts + fr) + " Z"
    out = hair_paint(doc, d, base, A)
    for i in range(1, n, 2):
        a = math.pi * (1.06 + .88 * i / n)
        x1, y1 = h["cx"] + math.cos(a) * h["rx"] * .9, h["cy"] - 18 + math.sin(a) * h["ryt"] * .85
        x2, y2 = h["cx"] + math.cos(a) * h["rx"] * 1.28, h["cy"] - 18 + math.sin(a) * h["ryt"] * 1.25
        out += line(f"M{f(x1)},{f(y1)} L{f(x2)},{f(y2)}", "#ffffff", 2, .18)
    doc.layer("Haare", doc.shadowed("fxds_Haare", out, 0, 5, 7, 45))


def hair_long_wavy(doc, A, base):
    back = ("M206,170 C196,110 250,100 300,100 C350,100 404,110 394,170 C410,230 424,300 432,350 "
            "C438,392 420,420 404,440 C392,420 382,428 368,446 C356,420 344,430 330,440 L270,440 "
            "C256,430 244,420 232,446 C218,428 208,420 196,440 C180,420 162,392 168,350 C176,300 190,230 206,170 Z")
    out_b = hair_paint(doc, back, base, A, sheen=False)
    for x in (214, 236, 364, 386):
        sd = 1 if x > 300 else -1
        out_b += line(f"M{x},230 C{x + sd * 14},300 {x - sd * 10},360 {x + sd * 8},430", "#ffffff", 2.2, .14)
    doc.layer("Haare_hinten", out_b)
    front = ("M210,232 C196,150 238,112 300,110 C366,108 408,150 394,236 C388,206 378,176 352,160 "
             "C330,190 280,206 236,200 C226,212 218,224 210,232 Z")
    out = hair_paint(doc, front, base, A)
    out += line("M352,160 C344,184 320,198 290,204", "#ffffff", 2, .2)
    out += line("M330,150 C318,178 286,194 250,198", "#ffffff", 1.6, .16)
    doc.layer("Haare", doc.shadowed("fxds_Haare", out, 0, 6, 8, 45))


def hair_buzz_cap(doc, A, tone):
    """Kurze Haare unter einer Feldmütze."""
    h = HEAD
    crown = "M206,176 C204,112 250,92 300,92 C350,92 396,112 394,176 C360,166 334,162 300,162 C266,162 240,166 206,176 Z"
    out = f'<path d="{crown}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    cp = doc.clip(crown)
    out += f'<g {cp}>' + doc.soft(ell(262, 118, 46, 18), "#ffffff", 8, .25) + doc.soft(ell(390, 150, 30, 40), A, 8, .45) + "</g>"
    brim = "M200,178 C240,164 360,164 400,178 C392,196 356,204 300,204 C244,204 208,196 200,178 Z"
    out += f'<path d="{brim}" fill="{doc.lin([(0, "#2c3220", 1), (1, "#161a10", 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.4"/>'
    out += stitch("M214,182 C250,172 350,172 386,182", "#d8d2b8", .35)
    out += f'<rect x="286" y="122" width="28" height="22" rx="3" fill="#3a4128" stroke="#1a1d12" stroke-width="1.2"/>'
    out += line("M292,133 L300,127 L308,133 M292,140 L300,134 L308,140", "#c9b26a", 2)
    doc.layer("Haare", doc.shadowed("fxds_Haare", out, 0, 7, 8, 50))


# ---------------------------------------------------------------------------
# Kleidung
# ---------------------------------------------------------------------------
def hoodie(doc, A, tone, k):
    d = bean(k, 10)
    hood = "M208,400 C196,350 236,318 300,318 C364,318 404,350 392,400 C370,380 338,372 300,372 C262,372 230,380 208,400 Z"
    out = f'<path d="{hood}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".45" stroke-width="1.5"/>'
    out += doc.soft("M230,392 C250,376 350,376 370,392 C350,386 250,386 230,392 Z", "#000", 4, .5)
    folds = ["M170,520 C200,560 210,600 205,640", "M430,520 C400,560 390,600 395,640", "M250,430 C262,470 258,500 250,520"]
    folds = [ell(185, 560, 10, 70), ell(415, 560, 10, 70), ell(300, 470, 60, 6)]
    out += cloth(doc, d, tone, A, folds)
    out += doc.soft("M226,404 C250,430 350,430 374,404 C350,416 250,416 226,404 Z", "#000", 5, .55)
    out += line("M228,402 C252,428 348,428 372,402", "#000", 4, .35)
    out += line("M282,416 C280,450 284,470 280,496", "#e6e8ec", 3.2)
    out += line("M318,416 C320,450 316,470 320,496", "#e6e8ec", 3.2)
    out += f'<rect x="274" y="494" width="12" height="16" rx="3" fill="{A}"/><rect x="314" y="494" width="12" height="16" rx="3" fill="{A}"/>'
    pocket = "M206,640 L222,548 C260,540 340,540 378,548 L394,640"
    out += line(pocket, "#000", 2.4, .45) + stitch("M214,640 L228,556 C262,549 338,549 372,556 L386,640", "#fff", .2)
    out += f'<path d="M332,454 l7,-12 l7,12 l-7,5 z" fill="{A}"/>'
    doc.layer("Jacke", out)


def fur_coat(doc, A, tone, k):
    d = bean(k, 12)
    folds = [ell(200, 560, 9, 80), ell(400, 560, 9, 80)]
    out = cloth(doc, d, tone, A, folds, light=.45)
    out += line("M300,420 L300,640", "#000", 2.2, .5)
    for y in (470, 530, 590):
        out += f'<circle cx="320" cy="{y}" r="6" fill="{doc.rad([(0, "#fff2c0", 1), (1, "#b08a3c", 1)], .35, .3, .7)}" stroke="#5a4518" stroke-width="1"/>'
    # Pelzkragen: symmetrischer Schalkragen aus überlappenden Büscheln, V bis zur Brust
    import random
    rnd = random.Random(7)

    def bez(t, p0, p1, p2, p3):
        u = 1 - t
        return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3))

    tufts = []
    for i in range(34):
        t = i / 33
        xi, yi = bez(t, (276, 358), (246, 384), (250, 456), (298, 512))   # Innenkante (V)
        xo, yo = bez(t, (236, 344), (128, 352), (150, 468), (290, 548))   # Außenkante (Schulter)
        for j in range(4):
            u = (j + .5) / 4 + rnd.uniform(-.06, .06)
            x, y = xi + (xo - xi) * u, yi + (yo - yi) * u
            r = (19 - 7 * t) * rnd.uniform(.85, 1.15)
            for sx in (x, 2 * CX - x):
                tufts.append((sx + rnd.uniform(-2, 2), y + rnd.uniform(-2, 2), r, t))
    tufts.sort(key=lambda c: c[1])
    furfill = doc.rad([(0, "#fbf6ee", 1), (.6, "#e2d6c4", 1), (1, "#a8977f", 1)], .38, .3, .75)
    fur = "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}"/>' for x, y, r, t in tufts)
    stole = "M236,344 C128,352 150,468 290,548 L310,548 C450,468 472,352 364,344 C350,362 324,372 300,372 C276,372 250,362 236,344 Z"
    out += doc.soft(stole, "#000", 12, .5, 'transform="translate(0,10)"')
    out += f'<g fill="{furfill}">{fur}</g>'
    out += f'<g {doc.clip(stole)}>' + doc.soft("M150,470 C220,520 380,520 450,470 L450,560 L150,560 Z", "#5b4a36", 14, .45) + "</g>"
    for x, y, r, t in tufts[::2]:
        for _ in range(2):
            a = rnd.uniform(0, 2 * math.pi)
            sx, sy = x + math.cos(a) * r * .8, y + math.sin(a) * r * .8
            out += line(f"M{f(sx)},{f(sy)} l{f(math.cos(a) * 6)},{f(math.sin(a) * 6 + 2)}", "#fbf6ee", 1.4, .7)
    out += doc.soft("M200,372 C220,354 248,348 264,352 C240,362 222,374 210,392 Z", "#ffffff", 6, .6)
    out += doc.soft(mirror("M172,404 C176,380 196,366 214,362 C196,380 186,400 184,430 Z"), A, 8, .3)
    doc.layer("Jacke", doc.shadowed("fxds_Jacke", out, 0, 4, 6, 30))


def military(doc, A, k):
    tone = ("#56603c", "#262b18")
    d = bean(k, 8)
    folds = [ell(190, 570, 9, 70), ell(410, 570, 9, 70), ell(300, 520, 4, 60)]
    out = cloth(doc, d, tone, A, folds, light=.3)
    out += line("M300,404 L300,640", "#1a1d12", 2.4)
    col = "M262,384 L222,420 L282,414 Z"
    out += f'<path d="{col}" fill="{doc.lin([(0, "#646f46", 1), (1, "#3a4128", 1)])}" stroke="#1a1d12" stroke-width="1.4"/>'
    out += f'<path d="{mirror(col)}" fill="{doc.lin([(0, "#646f46", 1), (1, "#3a4128", 1)])}" stroke="#1a1d12" stroke-width="1.4"/>'
    for sd in (-1, 1):
        x = 300 + sd * 74
        out += doc.soft(f"M{x - 30},{462} h60 v52 h-60 z", "#000", 3, .3)
        out += f'<rect x="{x - 30}" y="458" width="60" height="50" rx="3" fill="{doc.lin([(0, "#5d6840", 1), (1, "#3a4128", 1)])}" stroke="#1a1d12" stroke-width="1.3"/>'
        out += f'<path d="M{x - 33},454 h66 v18 h-66 z" fill="{doc.lin([(0, "#69744a", 1), (1, "#454d30", 1)])}" stroke="#1a1d12" stroke-width="1.3"/>'
        out += f'<circle cx="{x}" cy="466" r="3.5" fill="#2a2e1c"/>'
        out += stitch(f"M{x - 27},462 h54 M{x - 27},504 h54", "#d8d2b8", .25)
        out += line(f"M{300 + sd * 120},{402} L{300 + sd * 168},{426}", "#3a4128", 14)
        out += line(f"M{300 + sd * 120},{402} L{300 + sd * 168},{426}", "#000", 14, .25)
    out += f'<rect x="336" y="428" width="70" height="14" rx="2" fill="#d8d2b8"/>'
    out += f'<text x="371" y="439" text-anchor="middle" font-size="11" font-weight="800" font-family="Arial, sans-serif" fill="#2a2e1c">BROOKS</text>'
    out += f'<path d="M150,474 h40 v28 h-40 z" fill="#3a4128" stroke="#1a1d12"/><path d="M158,488 l12,-8 l12,8 m-24,8 l12,-8 l12,8" stroke="{A}" stroke-width="2.4" fill="none"/>'
    doc.layer("Jacke", out)


# ---------------------------------------------------------------------------
# Extras
# ---------------------------------------------------------------------------
def headphones_neck(doc, A):
    out = line("M244,352 C254,388 346,388 356,352", "#0d0f13", 9)
    out += line("M244,352 C254,388 346,388 356,352", "#ffffff", 2, .15)
    for sd in (-1, 1):
        x = 300 + sd * 60
        out += f'<rect x="{x - 17}" y="338" width="34" height="46" rx="14" fill="{doc.lin([(0, "#2b313b", 1), (1, "#07080b", 1)])}" stroke="{A}" stroke-width="3"/>'
        out += f'<rect x="{x - 9}" y="346" width="18" height="30" rx="8" fill="{A}" fill-opacity=".25"/>'
    doc.layer("Extra_Hals", doc.shadowed("fxds_Extra_Hals", out, 0, 6, 8, 45))


def earrings(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 86
        out += f'<circle cx="{x}" cy="262" r="11" fill="none" stroke="{doc.lin([(0, "#fff3c4", 1), (1, "#b88a2a", 1)])}" stroke-width="3.5"/>'
        out += f'<circle cx="{x}" cy="276" r="4" fill="{A}"/>'
    doc.layer("Extra_Kopf", doc.shadowed("fxds_Extra_Kopf", out, 0, 3, 4, 40))


def dogtags(doc, A):
    out = line("M262,382 C268,430 332,430 338,382", "#b8bfca", 2, 1)
    out += '<path d="M262,382 C268,430 332,430 338,382" fill="none" stroke="#5f6670" stroke-width="2" stroke-dasharray="2 2"/>'
    for dx, dy, r in ((-6, 0, -8), (6, 6, 10)):
        out += f'<rect x="{292 + dx}" y="{414 + dy}" width="18" height="28" rx="6" transform="rotate({r} {301 + dx} {428 + dy})" fill="{doc.lin([(0, "#eef1f5", 1), (1, "#8d949e", 1)], 0, 0, 1, 1)}" stroke="#555c66" stroke-width="1.2"/>'
    doc.layer("Extra_Hals", doc.shadowed("fxds_Extra_Hals", out, 0, 3, 4, 45))


def sunglasses_top(doc, A):
    """Sonnenbrille ins Haar geschoben."""
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 40
        out += f'<path d="M{x - 30},132 C{x - 30},120 {x + 30},118 {x + 30},132 C{x + 28},150 {x - 26},152 {x - 30},132 Z" fill="{doc.lin([(0, "#3a2440", 1), (1, "#07050a", 1)])}" stroke="#c9b26a" stroke-width="2"/>'
        out += line(f"M{x - 18},140 l14,-14", "#ffffff", 2.4, .35)
    out += line("M330,128 C320,122 280,122 270,128", "#c9b26a", 2.4)
    doc.layer("Brille", doc.shadowed("fxds_Brille", out, 0, 4, 5, 45))


def crew_patch(doc, A, emblem):
    x, y = 372, 470
    out = f'<circle cx="{x}" cy="{y}" r="24" fill="#0b0d11" stroke="{A}" stroke-width="3"/>'
    out += f'<path d="{emblem}" transform="translate({x} {y}) scale(2)" fill="{A}" fill-rule="evenodd"/>'
    out += stitch(f"M{x - 20},{y} a20,20 0 1 1 40,0 a20,20 0 1 1 -40,0", A, .5, 1)
    doc.layer("Aufnaeher", doc.shadowed("fxds_Aufnaeher", out, 0, 2, 3, 40))


def leader_badge(doc, A):
    out = f'<path d="M190,452 l16,-10 l16,10 v14 l-16,-10 l-16,10 z" fill="{A}"/><path d="M190,474 l16,-10 l16,10 v10 l-16,-10 l-16,10 z" fill="{A}" fill-opacity=".6"/>'
    doc.layer("Rang", out)


# ---------------------------------------------------------------------------
FIGS = {
    "kenta": dict(name="Kenta Mori", A="#ffb347", jp="真夜中ランタン", k=1.0, build=lambda d, A: (
        hoodie(d, A, ("#3a4256", "#161a24"), 1.0), headphones_neck(d, A), None)),
    "reika": dict(name="Reika Hoshino", A="#ff4fd8", jp="銀座ネオン倶楽部", k=.86),
    "brooks": dict(name="Tyler Brooks", A="#7cb342", jp="ナイトパトロール", k=1.0),
}
STAR = "M0,-8 L2.4,-2.5 8,-2.5 3.5,1 5,7 0,3.5 -5,7 -3.5,1 -8,-2.5 -2.4,-2.5 Z"
BOLT = "M2,-9 L-5,1 H-0.5 L-2,9 L5,-1 H0.5 Z"


def build(fig, preview):
    doc = Doc(preview)
    if fig == "kenta":
        A = "#ffb347"
        background(doc, A, "真夜中ランタン")
        body(doc, A, 1.0)
        hoodie(doc, A, ("#3a4256", "#161a24"), 1.0)
        crew_patch(doc, A, STAR)
        headphones_neck(doc, A)
        head(doc, A, eyes_grim)
        hair_spiky(doc, A, ("#2a1d14", "#0b0806"))
    elif fig == "reika":
        A = "#ff4fd8"
        background(doc, A, "銀座ネオン倶楽部")
        hair_long_wavy_back = None
        doc_layers_before = len(doc.layers)
        hair_long_wavy(doc, A, ("#3b2030", "#120810"))
        back = doc.layers.pop(doc_layers_before)  # Haare_hinten
        front = doc.layers.pop()  # Haare (vorn)
        doc.layers.append(back)
        body(doc, A, .86)
        fur_coat(doc, A, ("#2a1630", "#0e0712"), .86)
        leader_badge(doc, A)
        head(doc, A, eyes_smile, lashes=True)
        doc.layers.append(front)
        earrings(doc, A)
        sunglasses_top(doc, A)
    else:
        A = "#7cb342"
        background(doc, A, "ナイトパトロール")
        body(doc, A, 1.0)
        military(doc, A, 1.0)
        dogtags(doc, A)
        head(doc, A, eyes_normal)
        hair_buzz_cap(doc, A, ("#56603c", "#2a2f1a"))
    return doc


def vc_steps(doc):
    steps = []
    for name, eff, params in doc.fx:
        kind = "Group" if eff in ("stylize.dropShadow",) or name.startswith("fxglowled") else "Path"
        steps.append({"command": "document.find", "params": {"name": name, "select": True}})
        steps.append({"command": "effect.apply", "params": {"effect": eff, "params": params}})
    return steps


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for fig in ("kenta", "reika", "brooks"):
        d = build(fig, False)
        open(os.path.join(out, f"{fig}.svg"), "w", encoding="utf-8").write(d.svg())
        json.dump(vc_steps(d), open(os.path.join(out, f"{fig}_steps.json"), "w"), indent=0)
        open(os.path.join(out, f"{fig}_preview.svg"), "w", encoding="utf-8").write(build(fig, True).svg())
    print("ok")
