"""Kopfteile: Augen, Frisuren, Kopfbedeckungen, Brillen, Ohren, Maske.

Alle Koordinaten im Kopf-System (vor der Verschiebung um HEAD_DY): Kopfmitte (300,222),
Breite ±88, oben y=122, Kinn y=314. Visier 222..378 x 164..252.
Jede Frisur liefert (hinten, vorn): "hinten" liegt hinter dem Körper (lange Haare), "vorn" über dem Kopf.
"""
import math
from core import CX, HEAD, f, egg, ell, mirror, line, stitch, shade_shell

# ---------------------------------------------------------------------------
# Kopf + Visier + Augen
# ---------------------------------------------------------------------------
VISOR = "M222,208 C222,176 258,164 300,164 C342,164 378,176 378,208 C378,240 342,252 300,252 C258,252 222,240 222,208 Z"


def head_shell(doc, A):
    h = HEAD
    d = egg(h["cx"], h["cy"], h["rx"], h["ryt"], h["ryb"])
    out = shade_shell(doc, d, (h["cx"] - h["rx"], h["cy"] - h["ryt"], h["cx"] + h["rx"], h["cy"] + h["ryb"]), A)
    return doc.shadowed(out, 0, 8, 10, 35)


def visor_glass(doc):
    v = f'<path d="{VISOR}" fill="{doc.lin([(0, "#30394a", 1), (.55, "#0b0e14", 1), (1, "#05070a", 1)])}" stroke="#20252d" stroke-width="3"/>'
    off = []
    for gx, gy, x, y in _grid():
        off.append(f'<rect x="{f(x - 2.6)}" y="{f(y - 2.6)}" width="5.2" height="5.2" rx="1.2"/>')
    v += f'<g fill="#ffffff" fill-opacity=".06">{"".join(off)}</g>'
    return v


def visor_shine(doc):
    cp = doc.clip(VISOR)
    return f'<g {cp}><path d="M230,196 C236,176 266,170 300,170 C334,170 364,176 370,196 C350,186 326,183 300,183 C274,183 250,186 230,196 Z" fill="#ffffff" fill-opacity=".22"/></g>'


def _grid():
    for gy in range(-5, 6):
        for gx in range(-9, 10):
            x, y = 300 + gx * 8, 208 + gy * 8
            if abs((x - 300) / 70) ** 2.6 + abs((y - 208) / 38) ** 2.6 < 1:
                yield gx, gy, x, y


def eyes_svg(doc, fn, lashes=False, col="#eef7ff"):
    on = [f'<rect x="{f(x - 2.6)}" y="{f(y - 2.6)}" width="5.2" height="5.2" rx="1.2"/>'
          for gx, gy, x, y in _grid() if fn(gx, gy) or (lashes and _lash(fn, gx, gy))]
    glow = doc.uid("fxglowled")
    doc.fx.append((glow, "stylize.outerGlow", {"color": "#bfe0ff", "opacity": 85, "blur": 6, "mode": "screen"}))
    gflt = ""
    if doc.preview:
        doc.defs.append(f'<filter id="{glow}f" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
        gflt = f' filter="url(#{glow}f)"'
    return f'<g id="{glow}" fill="{col}"{gflt}>{"".join(on)}</g>'


def _lash(fn, gx, gy):
    for sd in (-1, 1):
        ex = 4 * sd
        tops = [dy for dy in range(-5, 5) for dx in range(-2, 3) if fn(ex + dx, dy)]
        if not tops:
            continue
        t = min(tops)
        dx = gx - ex
        if (dx * sd == 2 and gy == t - 1) or (dx * sd == 3 and gy == t - 2):
            return True
    return False


def _e_normal(gx, gy):
    return any(abs(gx - e) <= 1 and -2 <= gy <= 1 for e in (-4, 4))


def _e_grim(gx, gy):
    for e, sd in ((-4, -1), (4, 1)):
        dx = gx - e
        if abs(dx) <= 1 and -1 <= gy <= 1 and not (gy == -1 and dx * sd < 0):
            return True
        if gy == -2 and dx * sd == 1:
            return True
    return False


def _e_smile(gx, gy):
    for e in (-4, 4):
        dx = gx - e
        if (gy == -1 and dx == 0) or (gy == 0 and abs(dx) == 1) or (gy == 1 and abs(dx) == 2):
            return True
    return False


def _e_sleepy(gx, gy):
    return any(abs(gx - e) <= 2 and gy == 0 for e in (-4, 4)) or any(abs(gx - e) <= 1 and gy == 1 for e in (-4, 4))


def _e_wink(gx, gy):
    left = abs(gx + 4) <= 1 and -2 <= gy <= 1
    right = (gy == 0 and abs(gx - 4) <= 2) or (gy == -1 and abs(gx - 4) == 2)
    return left or right


def _e_angry(gx, gy):
    for e, sd in ((-4, 1), (4, -1)):
        dx = gx - e
        if abs(dx) <= 1 and 0 <= gy <= 1:
            return True
        if gy == -1 and dx * sd >= 0 and abs(dx) <= 1:
            return True
        if gy == -2 and dx * sd == 1:
            return True
    return False


def _e_round(gx, gy):
    for e in (-4, 4):
        dx = gx - e
        if abs(dx) <= 2 and abs(gy) <= 2 and not (abs(dx) == 2 and abs(gy) == 2) and not (dx == 0 and gy == 0):
            return True
    return False


def _e_cool(gx, gy):
    return any(abs(gx - e) <= 2 and gy == -1 for e in (-4, 4)) or any(abs(gx - e) <= 1 and gy == 0 for e in (-4, 4))


EYES = {
    "normal": ("Normal", _e_normal),
    "grimmig": ("Grimmig", _e_grim),
    "laecheln": ("Lächeln", _e_smile),
    "muede": ("Müde", _e_sleepy),
    "zwinkern": ("Zwinkern", _e_wink),
    "wuetend": ("Wütend", _e_angry),
    "rund": ("Große Augen", _e_round),
    "cool": ("Cool", _e_cool),
}

# ---------------------------------------------------------------------------
# Frisuren
# ---------------------------------------------------------------------------
HAIR_COLORS = {
    "schwarz": ("#2b2b33", "#0a0a0d"),
    "dunkelbraun": ("#3b2a1e", "#120c07"),
    "braun": ("#6b4a2e", "#2a1a0e"),
    "blond": ("#e8cf8a", "#9c7a34"),
    "platin": ("#f1efe8", "#a9a69c"),
    "rot": ("#b0432a", "#4a160b"),
    "pink": ("#ff8fd0", "#a3346f"),
    "blau": ("#5c8dff", "#1d2f80"),
    "lila": ("#8e5cd6", "#341a5c"),
    "gruen": ("#4fc48a", "#14553a"),
    "silber": ("#c9ccd2", "#6c7078"),
    "pflaume": ("#3b2030", "#120810"),
}


def paint(doc, d, base, A, sheen=None, rim=True, stroke=.5):
    """Haarfläche: Verlauf, Glanzband, Randlicht in Crewfarbe, Kontur."""
    out = f'<path d="{d}" fill="{doc.lin([(0, base[0], 1), (1, base[1], 1)], 0, 0, .3, 1)}"/>'
    inner = ""
    if sheen:
        inner += doc.soft(sheen, "#ffffff", 5, .3)
    if rim:
        inner += doc.soft("M376,110 C404,160 408,220 400,270 L430,270 L430,100 Z", A, 8, .22)
    if inner:
        out += f"<g {doc.clip(d)}>{inner}</g>"
    out += f'<path d="{d}" fill="none" stroke="#000" stroke-opacity="{stroke}" stroke-width="1.4"/>'
    return out


def strands(pts_list, col="#ffffff", op=.16, w=1.8):
    return "".join(line(p, col, w, op) for p in pts_list)


SHEEN_TOP = "M222,150 C252,124 330,116 370,142 L372,154 C330,132 258,138 226,164 Z"


def h_kurz(doc, A, c):
    d = ("M212,196 C206,130 248,110 300,110 C352,110 394,130 388,196 C380,178 372,166 360,160 "
         "C340,170 320,166 300,170 C280,166 260,170 240,160 C228,166 220,178 212,196 Z")
    out = paint(doc, d, c, A, SHEEN_TOP)
    out += strands(["M250,124 l-6,22", "M280,116 l-4,24", "M318,116 l4,24", "M350,124 l6,22"], "#000", .25, 1.4)
    return "", doc.shadowed(out, 0, 4, 6, 40)


def h_stachelig(doc, A, c):
    h = HEAD
    pts = []
    n = 11
    for i in range(n + 1):
        a = math.pi * (1.06 + .88 * i / n)
        for j, (rr, da) in enumerate(((1.02, -.06), (1.34 + (.1 if i % 2 else 0), 0), (1.02, .06))):
            if j == 1 and (i == 0 or i == n):
                continue
            pts.append((h["cx"] + math.cos(a + da) * h["rx"] * rr, h["cy"] - 18 + math.sin(a + da) * h["ryt"] * rr * .95))
    fr = [(392, 196), (372, 168), (356, 186), (336, 160), (318, 182), (300, 156), (282, 182), (264, 160), (246, 186), (228, 168), (208, 196)]
    d = "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts + fr) + " Z"
    out = paint(doc, d, c, A, SHEEN_TOP)
    for i in range(1, n, 2):
        a = math.pi * (1.06 + .88 * i / n)
        x1, y1 = h["cx"] + math.cos(a) * h["rx"] * .9, h["cy"] - 18 + math.sin(a) * h["ryt"] * .85
        x2, y2 = h["cx"] + math.cos(a) * h["rx"] * 1.25, h["cy"] - 18 + math.sin(a) * h["ryt"] * 1.2
        out += line(f"M{f(x1)},{f(y1)} L{f(x2)},{f(y2)}", "#ffffff", 2, .18)
    return "", doc.shadowed(out, 0, 5, 7, 45)


def h_zurueck(doc, A, c):
    """Nach hinten gegelt (Yakuza/Host)."""
    d = ("M214,190 C206,124 248,104 300,104 C352,104 394,124 386,190 C376,170 366,156 352,150 "
         "C334,144 318,146 300,146 C282,146 266,144 248,150 C234,156 224,170 214,190 Z")
    out = paint(doc, d, c, A, "M236,136 C262,114 338,112 364,134 L360,142 C334,124 266,124 240,146 Z")
    for x in (240, 262, 284, 316, 338, 360):
        out += line(f"M{x},{150 - abs(300 - x) * .05} C{x + (x - 300) * .1},126 {x + (x - 300) * .2},112 {x + (x - 300) * .25},106", "#ffffff", 1.4, .2)
    return "", doc.shadowed(out, 0, 4, 6, 45)


def h_tolle(doc, A, c):
    """Bosozoku-Tolle (Regent): breite, nach vorn gerollte Haarrolle über der Stirn."""
    base = ("M212,198 C206,140 236,120 262,116 L338,116 C364,120 394,140 388,198 C378,180 366,168 352,164 "
            "C334,160 318,162 300,164 C282,162 266,160 248,164 C234,168 222,180 212,198 Z")
    out = paint(doc, base, c, A, None)
    roll = ("M214,138 C206,96 240,64 300,62 C360,64 396,96 386,138 C380,152 362,160 340,156 "
            "C320,152 280,152 260,156 C238,160 220,152 214,138 Z")
    out += paint(doc, roll, c, A, "M240,90 C262,72 338,70 362,88 L358,98 C334,82 266,84 244,100 Z")
    out += f'<g {doc.clip(roll)}>' + doc.soft("M214,128 C250,150 350,150 386,128 L386,160 L214,160 Z", "#000", 7, .5) + "</g>"
    out += strands(["M232,130 C236,100 262,78 300,72", "M256,140 C262,108 292,86 336,80", "M282,146 C292,116 326,96 370,100",
                    "M318,148 C330,124 356,110 382,118"])
    return "", doc.shadowed(out, 0, 6, 8, 45)


def h_mittel(doc, A, c):
    """Mittellang, zerzaust, Pony bis an das Visier."""
    d = ("M210,236 C196,150 238,108 300,108 C362,108 404,150 390,236 C384,214 380,196 372,184 "
         "L360,200 L350,176 L334,196 L322,170 L306,194 L292,168 L278,194 L262,172 L250,198 L238,180 C226,196 216,214 210,236 Z")
    out = paint(doc, d, c, A, SHEEN_TOP)
    out += strands(["M300,114 C292,140 286,158 292,168", "M330,118 C330,142 326,160 322,170", "M264,124 C262,146 262,160 262,172"], "#000", .25, 1.4)
    return "", doc.shadowed(out, 0, 5, 7, 45)


def h_scheitel(doc, A, c):
    """Undercut mit Seitenscheitel: Seiten kurz, oben zur Seite gekämmt."""
    side = ("M212,200 C208,160 220,136 236,126 L364,126 C380,136 392,160 388,200 C380,186 372,176 360,172 L240,172 C228,176 220,186 212,200 Z")
    out = f'<path d="{side}" fill="{c[1]}" fill-opacity=".85"/>'
    out += f'<g {doc.clip(side)}>' + "".join(f'<circle cx="{x}" cy="{y}" r="1" fill="#000" fill-opacity=".25"/>' for x in range(214, 388, 6) for y in range(130, 200, 6)) + "</g>"
    top = ("M226,150 C226,108 270,96 312,98 C360,100 394,118 396,154 C388,170 372,178 356,180 "
           "C330,176 300,170 280,160 C262,152 244,150 226,150 Z")
    out += paint(doc, top, c, A, "M250,118 C280,102 340,102 372,120 L366,128 C336,112 282,112 256,126 Z")
    out += line("M262,104 C254,116 248,132 246,150", "#000", 2, .4)
    out += strands(["M270,104 C310,108 350,124 380,150", "M268,120 C306,124 344,140 372,166", "M264,136 C296,142 326,156 350,174"])
    return "", doc.shadowed(out, 0, 5, 7, 45)


def h_irokese(doc, A, c):
    pts = [(272, 186)]
    for i in range(9):
        y = 176 - i * 9
        x = 270 + i * .8
        pts += [(x - 2, y), (x - 14 + i * .6, y - 18)]
    tip = [(300, 60)]
    right = [(2 * CX - x, y) for x, y in reversed(pts)]
    d = "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts + tip + right) + " Z"
    shaved = "M214,196 C206,140 246,114 300,114 C354,114 394,140 386,196 C370,176 340,168 300,168 C260,168 230,176 214,196 Z"
    out = f'<path d="{shaved}" fill="{c[1]}" fill-opacity=".22"/>'
    out += paint(doc, d, c, A, None)
    out += line("M300,180 L300,70", "#ffffff", 2, .18)
    return "", doc.shadowed(out, 0, 5, 7, 45)


def h_afro(doc, A, c):
    import random
    rnd = random.Random(3)
    cx, cy, rx, ry = 300, 156, 136, 112
    pts = []
    for i in range(36):
        a = 2 * math.pi * i / 36
        r = 1 + rnd.uniform(-.03, .05)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    d = "M" + " ".join(
        f"Q{f(cx + math.cos(2 * math.pi * (i + .5) / 36) * rx * 1.08)},{f(cy + math.sin(2 * math.pi * (i + .5) / 36) * ry * 1.08)} {f(x)},{f(y)}"
        if i else f"{f(x)},{f(y)}" for i, (x, y) in enumerate(pts)) + " Z"
    back = paint(doc, d, c, A, None)
    back += "".join(f'<circle cx="{f(cx + rnd.uniform(-1, 1) * rx * .8)}" cy="{f(cy + rnd.uniform(-1, .6) * ry * .8)}" r="{f(rnd.uniform(5, 9))}" fill="none" stroke="#fff" stroke-opacity=".08" stroke-width="2"/>' for _ in range(40))
    front = "M214,190 C214,160 236,150 252,150 C270,138 330,138 348,150 C364,150 386,160 386,190 C370,176 340,172 300,172 C260,172 230,176 214,190 Z"
    fr = paint(doc, front, c, A, None, rim=False, stroke=.3)
    return doc.shadowed(back, 0, 6, 10, 40), fr


def h_lang_wellig(doc, A, c):
    back = ("M206,170 C196,110 250,100 300,100 C350,100 404,110 394,170 C410,230 424,300 432,350 "
            "C438,392 420,420 404,440 C392,420 382,428 368,446 C356,420 344,430 330,440 L270,440 "
            "C256,430 244,420 232,446 C218,428 208,420 196,440 C180,420 162,392 168,350 C176,300 190,230 206,170 Z")
    b = paint(doc, back, c, A, None)
    for x in (214, 236, 364, 386):
        sd = 1 if x > 300 else -1
        b += line(f"M{x},230 C{x + sd * 14},300 {x - sd * 10},360 {x + sd * 8},430", "#ffffff", 2.2, .14)
    front = ("M210,232 C196,150 238,112 300,110 C366,108 408,150 394,236 C388,206 378,176 352,160 "
             "C330,190 280,206 236,200 C226,212 218,224 210,232 Z")
    fr = paint(doc, front, c, A, SHEEN_TOP)
    fr += line("M352,160 C344,184 320,198 290,204", "#ffffff", 2, .2)
    fr += line("M330,150 C318,178 286,194 250,198", "#ffffff", 1.6, .16)
    return b, doc.shadowed(fr, 0, 6, 8, 45)


def h_hime(doc, A, c):
    """Lang und glatt, gerader Pony, Seitensträhnen (Hime-Schnitt)."""
    back = ("M204,170 C196,108 250,98 300,98 C350,98 404,108 396,170 L404,470 L196,470 Z")
    b = paint(doc, back, c, A, None)
    b += strands([f"M{x},200 L{x + (x - 300) * .04},460" for x in (214, 232, 368, 386)], "#ffffff", .12, 2)
    front = ("M206,250 C196,140 240,108 300,108 C360,108 404,140 394,250 L394,330 L370,330 L370,180 "
             "L230,180 L230,330 L206,330 Z")
    fr = paint(doc, front, c, A, SHEEN_TOP)
    fr += line("M232,180 L368,180", "#000", 1.6, .4)
    fr += strands(["M260,130 L258,178", "M300,120 L300,178", "M340,130 L342,178"], "#000", .2, 1.2)
    return b, doc.shadowed(fr, 0, 5, 7, 45)


def h_bob(doc, A, c):
    back = "M200,180 C196,110 250,100 300,100 C350,100 404,110 400,180 C408,240 410,290 398,318 L202,318 C190,290 192,240 200,180 Z"
    b = paint(doc, back, c, A, None)
    front = ("M204,300 C190,170 230,110 300,110 C370,110 410,170 396,300 C390,310 380,316 372,318 "
             "C382,270 384,220 376,186 C340,176 300,190 252,180 C226,180 222,190 222,186 C216,220 218,270 228,318 C220,316 210,310 204,300 Z")
    fr = paint(doc, front, c, A, SHEEN_TOP)
    fr += line("M252,180 C300,190 340,176 376,186", "#000", 1.6, .35)
    return b, doc.shadowed(fr, 0, 5, 7, 45)


def h_pferdeschwanz(doc, A, c):
    tail = "M352,150 C410,150 432,220 426,300 C422,360 404,420 380,460 C386,400 390,330 382,270 C376,220 364,190 346,176 Z"
    b = paint(doc, tail, c, A, None)
    b += strands(["M372,190 C400,240 404,330 392,430", "M362,200 C384,260 386,330 380,400"], "#ffffff", .14, 2)
    top = ("M212,206 C204,134 250,108 300,108 C352,108 398,134 388,206 C378,186 366,170 352,164 "
           "C330,170 300,160 270,170 C250,164 230,180 212,206 Z")
    fr = paint(doc, top, c, A, SHEEN_TOP)
    fr += f'<path d="M344,150 C352,140 368,140 372,152 C368,164 352,166 344,160 Z" fill="#14161b"/>'  # Haargummi
    fr += f'<path d="M346,152 C356,146 364,146 368,152" stroke="{A}" stroke-width="2.4" fill="none"/>'
    return b, doc.shadowed(fr, 0, 5, 7, 45)


def h_dutt(doc, A, c):
    top = ("M212,206 C204,134 250,108 300,108 C352,108 398,134 388,206 C378,184 366,170 350,164 "
           "C330,158 300,156 270,162 C248,166 228,182 212,206 Z")
    fr = paint(doc, ell(300, 84, 40, 32), c, A, "M276,70 C290,58 312,58 324,70 L320,76 C308,66 292,66 280,76 Z")
    fr += line("M266,90 C286,100 314,100 334,90", "#000", 1.6, .35)
    fr += paint(doc, top, c, A, SHEEN_TOP)
    fr += line("M262,72 L338,96", "#c9a54a", 3)  # Haarstab
    fr += f'<circle cx="338" cy="96" r="4" fill="{A}"/>'
    return "", doc.shadowed(fr, 0, 5, 7, 45)


def h_zoepfe(doc, A, c):
    b = ""
    for sd in (-1, 1):
        x = 300 + sd * 104
        tail = (f"M{x - 18 * sd},170 C{x + 30 * sd},190 {x + 34 * sd},270 {x + 20 * sd},340 "
                f"C{x + 10 * sd},380 {x + 4 * sd},410 {x - 6 * sd},430 C{x - 2 * sd},380 {x - 6 * sd},300 {x - 20 * sd},220 Z")
        b += paint(doc, tail, c, A, None)
    top = ("M212,214 C204,134 250,108 300,108 C352,108 398,134 388,214 C380,190 368,174 350,168 "
           "L330,184 L318,164 L300,180 L282,164 L270,184 L250,168 C232,174 220,190 212,214 Z")
    fr = paint(doc, top, c, A, SHEEN_TOP)
    for sd in (-1, 1):
        fr += f'<circle cx="{300 + sd * 98}" cy="176" r="8" fill="{A}" stroke="#000" stroke-opacity=".4"/>'
    return b, doc.shadowed(fr, 0, 5, 7, 45)


def h_lang_m(doc, A, c):
    """Schulterlang, Mittelscheitel (Männer)."""
    back = "M204,170 C196,108 250,98 300,98 C350,98 404,108 396,170 C404,230 410,300 404,360 L196,360 C190,300 196,230 204,170 Z"
    b = paint(doc, back, c, A, None)
    front = ("M208,260 C194,150 238,106 300,106 C362,106 406,150 392,260 C384,220 376,190 356,166 "
             "C338,150 318,140 300,124 C282,140 262,150 244,166 C224,190 216,220 208,260 Z")
    fr = paint(doc, front, c, A, SHEEN_TOP)
    fr += line("M300,108 L300,124", "#000", 1.6, .4)
    fr += strands(["M296,128 C270,146 244,180 230,240", "M304,128 C330,146 356,180 370,240"])
    return b, doc.shadowed(fr, 0, 5, 7, 45)


def h_glatze(doc, A, c):
    return "", ""


# id: (Name, Funktion, Volumen flat|mid|tall, lang?, Gewicht m, Gewicht f)
HAIRS = {
    "kurz": ("Kurzhaar", h_kurz, "flat", False, 10, 1),
    "stachelig": ("Stachelig", h_stachelig, "tall", False, 6, 1),
    "zurueck": ("Zurückgegelt", h_zurueck, "flat", False, 6, 1),
    "tolle": ("Tolle (Regent)", h_tolle, "tall", False, 4, 0),
    "mittel": ("Zerzaust", h_mittel, "mid", False, 8, 2),
    "scheitel": ("Undercut", h_scheitel, "mid", False, 6, 1),
    "irokese": ("Irokese", h_irokese, "tall", False, 2, 1),
    "afro": ("Afro", h_afro, "tall", False, 2, 1),
    "glatze": ("Glatze", h_glatze, "none", False, 3, 0),
    "lang_m": ("Schulterlang", h_lang_m, "mid", True, 3, 2),
    "lang_wellig": ("Lang gewellt", h_lang_wellig, "mid", True, 0, 8),
    "hime": ("Lang glatt mit Pony", h_hime, "mid", True, 0, 6),
    "bob": ("Bob", h_bob, "mid", True, 0, 6),
    "pferdeschwanz": ("Pferdeschwanz", h_pferdeschwanz, "flat", True, 1, 6),
    "dutt": ("Dutt", h_dutt, "bun", False, 0, 4),
    "zoepfe": ("Zöpfe", h_zoepfe, "flat", True, 0, 3),
}

# ---------------------------------------------------------------------------
# Kopfbedeckungen (über den Haaren)
# ---------------------------------------------------------------------------


def hat_cap(doc, A, tone):
    crown = "M206,180 C202,112 250,90 300,90 C350,90 398,112 394,180 C360,170 334,166 300,166 C266,166 240,170 206,180 Z"
    out = f'<path d="{crown}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    out += f'<g {doc.clip(crown)}>' + doc.soft(ell(262, 118, 46, 18), "#ffffff", 8, .22) + "</g>"
    out += line("M300,92 L300,166", "#000", 1.2, .3) + line("M250,100 C246,130 244,150 246,170", "#000", 1.2, .2) + line("M350,100 C354,130 356,150 354,170", "#000", 1.2, .2)
    out += f'<circle cx="300" cy="92" r="5" fill="{tone[0]}" stroke="#000" stroke-opacity=".5"/>'
    brim = "M198,182 C240,166 360,166 402,182 C394,204 356,212 300,212 C244,212 206,204 198,182 Z"
    out += f'<path d="{brim}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.4"/>'
    out += doc.soft("M210,190 C250,200 350,200 390,190 C356,208 244,208 210,190 Z", "#000", 3, .4)
    out += stitch("M212,186 C250,176 350,176 388,186", "#ffffff", .25)
    out += f'<path d="M276,128 h48 v22 h-48 z" fill="{A}" fill-opacity=".9" rx="3"/><text x="300" y="145" text-anchor="middle" font-size="15" font-weight="700" font-family="Arial, sans-serif" fill="#0b0d11">走</text>'
    return doc.shadowed(out, 0, 6, 8, 45)


def hat_cap_rueck(doc, A, tone):
    crown = "M208,190 C200,118 250,92 300,92 C350,92 400,118 392,190 C360,182 334,178 300,178 C266,178 240,182 208,190 Z"
    out = f'<path d="{crown}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    out += f'<g {doc.clip(crown)}>' + doc.soft(ell(262, 118, 46, 18), "#ffffff", 8, .22) + "</g>"
    out += line("M300,94 L300,140", "#000", 1.2, .3)
    out += f'<path d="M270,190 C270,156 330,156 330,190 Z" fill="#14161b"/>'  # Öffnung hinten = vorn sichtbar
    out += f'<path d="M262,176 h76 v8 h-76 z" fill="{tone[1]}" stroke="#000" stroke-opacity=".5"/>'
    out += f'<rect x="292" y="174" width="16" height="12" rx="2" fill="#9aa1ab"/>'
    out += f'<path d="M280,98 C290,92 310,92 320,98 L318,104 C308,100 292,100 282,104 Z" fill="{tone[0]}" stroke="#000" stroke-opacity=".5"/>'  # Schirm hinten oben
    return doc.shadowed(out, 0, 6, 8, 45)


def hat_beanie(doc, A, tone):
    d = "M210,196 C200,120 248,82 300,82 C352,82 400,120 390,196 Z"
    out = f'<path d="{d}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    cp = doc.clip(d)
    rib = "".join(line(f"M{x},90 C{x + (x - 300) * .05},140 {x + (x - 300) * .08},170 {x + (x - 300) * .1},200", "#000", 1.6, .18) for x in range(224, 380, 10))
    out += f'<g {cp}>{rib}' + doc.soft(ell(266, 112, 40, 20), "#ffffff", 8, .2) + "</g>"
    band = "M204,164 C240,150 360,150 396,164 L398,204 C360,194 240,194 202,204 Z"
    out += f'<path d="{band}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    out += f'<g {doc.clip(band)}>' + "".join(line(f"M{x},150 L{x},206", "#000", 2, .2) for x in range(206, 398, 8)) + "</g>"
    out += f'<rect x="282" y="168" width="36" height="20" rx="2" fill="{A}"/>'
    return doc.shadowed(out, 0, 6, 8, 45)


def hat_feld(doc, A, tone):
    crown = "M206,176 C204,112 250,92 300,92 C350,92 396,112 394,176 C360,166 334,162 300,162 C266,162 240,166 206,176 Z"
    out = f'<path d="{crown}" fill="{doc.lin([(0, "#56603c", 1), (1, "#2a2f1a", 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    out += f'<g {doc.clip(crown)}>' + doc.soft(ell(262, 118, 46, 18), "#ffffff", 8, .25) + "</g>"
    brim = "M200,178 C240,164 360,164 400,178 C392,196 356,204 300,204 C244,204 208,196 200,178 Z"
    out += f'<path d="{brim}" fill="{doc.lin([(0, "#2c3220", 1), (1, "#161a10", 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.4"/>'
    out += stitch("M214,182 C250,172 350,172 386,182", "#d8d2b8", .35)
    out += '<rect x="286" y="122" width="28" height="22" rx="3" fill="#3a4128" stroke="#1a1d12" stroke-width="1.2"/>'
    out += line("M292,133 L300,127 L308,133 M292,140 L300,134 L308,140", "#c9b26a", 2)
    return doc.shadowed(out, 0, 7, 8, 50)


def hat_stirnband(doc, A, tone):
    """Hachimaki: weißes Stirnband mit rotem Kreis, Knoten seitlich."""
    band = "M212,168 C250,150 350,150 388,168 L386,188 C350,172 250,172 214,188 Z"
    out = f'<path d="{band}" fill="{doc.lin([(0, "#ffffff", 1), (1, "#cfd3da", 1)])}" stroke="#000" stroke-opacity=".35" stroke-width="1.2"/>'
    out += '<circle cx="300" cy="168" r="8" fill="#d8262e"/>'
    out += '<path d="M386,170 l22,-6 l-6,14 z M388,180 l20,16 l-14,4 z" fill="#e9ecf0" stroke="#000" stroke-opacity=".3"/>'
    return doc.shadowed(out, 0, 3, 4, 35)


def hat_bandana(doc, A, tone):
    d = "M208,190 C200,124 248,96 300,96 C352,96 400,124 392,190 C360,178 334,174 300,174 C266,174 240,178 208,190 Z"
    out = f'<path d="{d}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    cp = doc.clip(d)
    dots = "".join(f'<path d="M{x},{y} c4,-6 10,-2 6,4 c-2,4 -8,4 -6,-4 z" fill="#ffffff" fill-opacity=".55"/>' for x in range(222, 384, 22) for y in range(110, 190, 20))
    out += f'<g {cp}>{dots}' + doc.soft(ell(262, 118, 46, 18), "#ffffff", 8, .2) + "</g>"
    out += line("M210,184 C250,170 350,170 390,184", "#ffffff", 2, .5)
    out += f'<path d="M388,178 l26,4 l-10,14 z M392,186 l14,24 l-14,0 z" fill="{tone[0]}" stroke="#000" stroke-opacity=".4"/>'
    return doc.shadowed(out, 0, 5, 7, 45)


def hat_hut(doc, A, tone):
    """Trilby/Fedora mit Hutband."""
    crown = "M226,170 C222,110 250,82 300,80 C350,82 378,110 374,170 Z"
    out = f'<path d="{crown}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/>'
    out += f'<g {doc.clip(crown)}>' + doc.soft(ell(270, 110, 30, 22), "#ffffff", 8, .2) + "</g>"
    out += line("M280,84 C292,96 308,96 320,84", "#000", 2, .35)
    out += f'<path d="M226,150 C260,140 340,140 374,150 L374,170 L226,170 Z" fill="{A}" fill-opacity=".85"/>'
    brim = "M176,176 C220,158 380,158 424,176 C410,190 380,194 300,194 C220,194 190,190 176,176 Z"
    out += f'<path d="{brim}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".55" stroke-width="1.4"/>'
    return doc.shadowed(out, 0, 7, 9, 50)


# id: (Name, Funktion, erlaubtes Haarvolumen)
HATS = {
    "cap": ("Cap", hat_cap, {"none", "flat", "mid"}),
    "cap_rueck": ("Cap rückwärts", hat_cap_rueck, {"none", "flat", "mid"}),
    "muetze": ("Strickmütze", hat_beanie, {"none", "flat", "mid"}),
    "feldmuetze": ("Feldmütze", hat_feld, {"none", "flat"}),
    "stirnband": ("Stirnband (Hachimaki)", hat_stirnband, {"none", "flat", "mid", "tall", "bun"}),
    "bandana": ("Bandana", hat_bandana, {"none", "flat", "mid"}),
    "hut": ("Hut (Trilby)", hat_hut, {"none", "flat"}),
}

# ---------------------------------------------------------------------------
# Brillen (auf dem Visier)
# ---------------------------------------------------------------------------


def gl_sonne(doc, A):
    d = "M216,196 C216,180 250,176 300,178 C350,176 384,180 384,196 C384,222 358,230 330,228 C314,226 306,214 300,214 C294,214 286,226 270,228 C242,230 216,222 216,196 Z"
    out = f'<path d="{d}" fill="{doc.lin([(0, "#2a2e38", .92), (1, "#050608", .96)])}" stroke="#0a0b0e" stroke-width="3"/>'
    out += f'<g {doc.clip(d)}><path d="M222,186 C260,180 340,180 378,186 L376,196 C340,190 260,190 224,196 Z" fill="#fff" fill-opacity=".25"/>' + doc.soft("M340,190 L380,190 L380,226 L340,226 Z", A, 6, .35) + "</g>"
    out += line("M216,196 L204,198 M384,196 L396,198", "#0a0b0e", 4)
    return doc.shadowed(out, 0, 3, 4, 45)


def gl_pilot(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 40
        d = f"M{x - 34},192 C{x - 34},180 {x + 34},178 {x + 34},192 C{x + 34},218 {x + 14},232 {x},232 C{x - 18},232 {x - 34},216 {x - 34},192 Z"
        out += f'<path d="{d}" fill="{doc.lin([(0, "#6a4a2a", .75), (1, "#120a05", .9)])}" stroke="{doc.lin([(0, "#fff3c4", 1), (1, "#a37a2a", 1)])}" stroke-width="2.6"/>'
        out += line(f"M{x - 22},200 l18,-14", "#ffffff", 2.6, .3)
    out += line("M286,186 C294,182 306,182 314,186", "#c9a54a", 2.6)
    out += line("M266,182 L334,182", "#c9a54a", 1.8, .9)
    out += line("M266,192 L210,196 M334,192 L390,196", "#c9a54a", 2.4)
    return doc.shadowed(out, 0, 3, 4, 40)


def gl_rund(doc, A):
    out = ""
    for sd in (-1, 1):
        out += f'<circle cx="{300 + sd * 36}" cy="208" r="26" fill="#ffffff" fill-opacity=".06" stroke="#1a1a1e" stroke-width="3"/>'
        out += line(f"M{300 + sd * 36 - 14},196 l10,-8", "#ffffff", 2, .3)
    out += line("M290,204 C296,198 304,198 310,204", "#1a1a1e", 3)
    out += line("M262,206 L210,200 M338,206 L390,200", "#1a1a1e", 2.6)
    return doc.shadowed(out, 0, 2, 3, 35)


def gl_eckig(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 40
        out += f'<rect x="{x - 32}" y="188" width="64" height="38" rx="6" fill="#ffffff" fill-opacity=".05" stroke="#111216" stroke-width="4"/>'
        out += line(f"M{x - 20},198 l12,-6", "#ffffff", 2, .3)
    out += line("M292,200 L308,200", "#111216", 4)
    out += line("M260,198 L210,196 M340,198 L390,196", "#111216", 3)
    return doc.shadowed(out, 0, 2, 3, 35)


def gl_oben(doc, A):
    """Sonnenbrille ins Haar geschoben."""
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 40
        out += f'<path d="M{x - 30},132 C{x - 30},120 {x + 30},118 {x + 30},132 C{x + 28},150 {x - 26},152 {x - 30},132 Z" fill="{doc.lin([(0, "#3a2440", 1), (1, "#07050a", 1)])}" stroke="#c9b26a" stroke-width="2"/>'
        out += line(f"M{x - 18},140 l14,-14", "#ffffff", 2.4, .35)
    out += line("M330,128 C320,122 280,122 270,128", "#c9b26a", 2.4)
    return doc.shadowed(out, 0, 4, 5, 45)


# id: (Name, Funktion, braucht Haar oben ohne Hut)
GLASSES = {
    "sonnenbrille": ("Sonnenbrille", gl_sonne, False),
    "pilot": ("Pilotenbrille", gl_pilot, False),
    "rund": ("Runde Brille", gl_rund, False),
    "eckig": ("Eckige Brille", gl_eckig, False),
    "oben": ("Sonnenbrille im Haar", gl_oben, True),
}

# ---------------------------------------------------------------------------
# Ohren
# ---------------------------------------------------------------------------


def ear_creolen(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 86
        out += f'<circle cx="{x}" cy="268" r="11" fill="none" stroke="{doc.lin([(0, "#fff3c4", 1), (1, "#b88a2a", 1)])}" stroke-width="3.5"/>'
    return doc.shadowed(out, 0, 3, 4, 40)


def ear_stecker(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 87
        out += f'<circle cx="{x}" cy="258" r="4.5" fill="{doc.rad([(0, "#ffffff", 1), (1, "#9aa6b8", 1)], .35, .3, .7)}" stroke="#4a515c" stroke-width="1"/>'
    return doc.shadowed(out, 0, 2, 3, 40)


def ear_headset(doc, A):
    out = f'<path d="M384,214 h14 a6,6 0 0 1 6,6 v28 a6,6 0 0 1 -6,6 h-14 z" fill="#16181d" stroke="{A}" stroke-width="2"/>'
    out += line("M392,250 C392,290 360,304 326,300", "#16181d", 4)
    out += '<circle cx="324" cy="300" r="6" fill="#16181d"/>'
    out += f'<circle cx="398" cy="226" r="2.5" fill="{A}"/>'
    return doc.shadowed(out, 0, 3, 4, 40)


def ear_haenger(doc, A):
    out = ""
    for sd in (-1, 1):
        x = 300 + sd * 86
        out += line(f"M{x},258 L{x},286", "#d9dde4", 1.6)
        out += f'<path d="M{x},284 l7,10 l-7,10 l-7,-10 z" fill="{A}" stroke="#fff" stroke-opacity=".6"/>'
    return doc.shadowed(out, 0, 3, 4, 40)


EARS = {
    "creolen": ("Creolen", ear_creolen, 1, 6),
    "stecker": ("Ohrstecker", ear_stecker, 3, 3),
    "haenger": ("Ohrhänger", ear_haenger, 0, 4),
    "headset": ("Funk-Headset", ear_headset, 1, 1),
}


def mask(doc, A, tone=("#1b1d22", "#08090b")):
    d = "M232,248 C262,262 338,262 368,248 C374,270 366,296 344,306 C320,316 280,316 256,306 C234,296 226,270 232,248 Z"
    out = f'<path d="{d}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".5" stroke-width="1.2"/>'
    out += line("M244,272 C270,282 330,282 356,272", "#ffffff", 1.4, .12) + line("M246,288 C272,298 328,298 354,288", "#ffffff", 1.4, .12)
    out += line("M232,250 C222,244 214,240 212,232 M368,250 C378,244 386,240 388,232", tone[0], 2.4)
    return doc.shadowed(out, 0, 3, 4, 35)
