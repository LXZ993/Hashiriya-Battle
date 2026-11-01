"""Hashiriya Battle Porträts v2 – Grundlagen: Dokument, Formen, Schattierung.

Erzeugt SVG-Dateien, die VectorCraft rendert (PNG) und als PSD mit einer Ebene je Teil speichert.
Weiche Schatten und Glanzlichter sind eigene Pfade mit einem Namens-Kürzel; vc_steps() macht daraus
die VectorCraft-Effekte (Weichzeichnen, Schlagschatten, Schein nach innen). Für die Vorschau im
Browser (preview=True) stehen dieselben Effekte als SVG-Filter drin.

Teile: parts.py, Bauen: make.py
"""
import json, math, os, sys

W = H = 600
CX = 300
HEAD_DY = 30
HEAD = dict(cx=300, cy=222, rx=88, ryt=100, ryb=92)


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


class Doc:
    """Sammelt Ebenen (oberste <g>), Verläufe und Effekt-Pfade."""

    def __init__(self, preview, pref=""):
        self.preview = preview
        self.pref = pref  # Präfix für IDs (Tool-Bausteine dürfen sich nicht in die Quere kommen)
        self.defs = []
        self.layers = []
        self.fx = []  # (name, effect, params)
        self.n = 0

    def uid(self, p="o"):
        self.n += 1
        return f"{p}{self.pref}{self.n:05d}"  # feste Länge: kein Name ist Teilstring eines anderen

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

    def shadowed(self, body, dx=0, dy=6, blur=8, opacity=40):
        """Gruppe mit Schlagschatten (VectorCraft stylize.dropShadow)."""
        name = self.uid("fxds")
        self.fx.append((name, "stylize.dropShadow", {"opacity": opacity, "x": dx, "y": dy, "blur": blur}))
        flt = ""
        if self.preview:
            fid = self.uid("ds")
            self.defs.append(f'<filter id="{fid}" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="{dx}" dy="{dy}" stdDeviation="{blur * .5}" flood-opacity="{opacity / 100}"/></filter>')
            flt = f' filter="url(#{fid})"'
        return f'<g id="{name}"{flt}>{body}</g>'

    def layer(self, name, body, head=False, k=1.0, hidden=False):
        """Oberste Gruppe = eine PSD-Ebene. head: Kopfteile sitzen HEAD_DY tiefer (kurzer Bob-Hals).
        k: Breite (Frauen schmaler), skaliert um die Mitte."""
        tf = []
        if head:
            tf.append(f"translate(0,{HEAD_DY})")
        if k != 1:
            tf.append(f"matrix({k} 0 0 1 {f(CX * (1 - k))} 0)")
        t = f' transform="{" ".join(tf)}"' if tf else ""
        hd = ' display="none"' if hidden else ""
        self.layers.append(f'<g id="{name}"{t}{hd}>{body}</g>')

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
        out += doc.soft(fd, "#000000", 9, .22)
    out += doc.soft("M470,420 C510,470 505,560 490,640 L520,640 L520,420 Z", rim, 10, .6)
    out += "</g>"
    out += f'<path d="{d}" fill="none" stroke="#000" stroke-opacity=".45" stroke-width="1.6"/>'
    return out


def stitch(d, col="#ffffff", op=.25, w=1.2):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-opacity="{op}" stroke-width="{w}" stroke-dasharray="4 3"/>'


def line(d, col, w=2, op=1, cap="round"):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round"/>'



def vc_steps(doc):
    steps = []
    for name, eff, params in doc.fx:
        steps.append({"command": "document.find", "params": {"name": name, "select": True}})
        steps.append({"command": "effect.apply", "params": {"effect": eff, "params": params}})
    return steps


def bez(t, p0, p1, p2, p3):
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3))
