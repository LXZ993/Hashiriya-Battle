"""Text als SVG-Pfade (keine Schriftarten im Spiel nötig).

Latein: Inter Display Black (SIL OFL), Japanisch: IPAGothic (IPA Font License).
Die Glyphen werden in Umrisse umgewandelt, das Logo braucht später keine Schrift mehr.
"""
import math
import os
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT_DIRS = ["/usr/share/fonts", os.path.expanduser("~/.fonts"), "C:/Windows/Fonts"]
FONTS = {
    "latin": ["InterDisplay-Black.otf", "InterDisplay-Black.ttf", "Inter-Black.otf", "Inter-Black.ttf", "DejaVuSans-Bold.ttf"],
    "latin_bold": ["InterDisplay-Bold.otf", "InterDisplay-Bold.ttf", "Inter-Bold.otf", "DejaVuSans-Bold.ttf"],
    "jp": ["ipag.ttf", "fonts-japanese-gothic.ttf"],
}
_cache = {}


def _find(names):
    for n in names:
        for d in FONT_DIRS:
            for root, _, files in os.walk(d):
                if n in files:
                    return os.path.join(root, n)
    raise FileNotFoundError(names)


def font(kind):
    if kind not in _cache:
        tt = TTFont(_find(FONTS[kind]))
        _cache[kind] = (tt, tt.getGlyphSet(), tt.getBestCmap(), tt["head"].unitsPerEm, tt["hmtx"])
    return _cache[kind]


def _kind_for(ch, kind):
    if kind == "jp":
        return "jp"
    return "jp" if ord(ch) > 0x2FF else kind


def glyph(ch, kind, size, x, y, rot=0.0, sx=1.0):
    """Ein Zeichen als Pfad; (x, y) = linker Grundlinienpunkt, rot in Grad um diesen Punkt."""
    k = _kind_for(ch, kind)
    tt, gs, cmap, upm, hmtx = font(k)
    name = cmap.get(ord(ch))
    if name is None:
        return "", 0
    s = size / upm
    adv = hmtx[name][0] * s * sx
    pen = SVGPathPen(gs)
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    # Font: y nach oben; SVG: y nach unten
    m = (s * sx * ca, s * sx * sa, s * sa, -s * ca, x, y)
    # Rotation: x' = ca*X - sa*Y ; mit Y gespiegelt
    m = (s * sx * ca, s * sx * sa, s * sa, -s * ca, x, y)
    gs[name].draw(TransformPen(pen, m))
    return pen.getCommands(), adv


def width(text, kind, size, track=0.0, sx=1.0):
    w = 0
    for ch in text:
        k = _kind_for(ch, kind)
        tt, gs, cmap, upm, hmtx = font(k)
        name = cmap.get(ord(ch))
        if name is None:
            continue
        w += hmtx[name][0] * size / upm * sx + track
    return w - track if text else 0


def cap_height(kind, size):
    tt = font(kind)[0]
    os2 = tt["OS/2"]
    ch = getattr(os2, "sCapHeight", 0) or tt["head"].unitsPerEm * 0.72
    return ch * size / tt["head"].unitsPerEm


def line(text, kind, size, cx, cy, track=0.0, sx=1.0, maxw=None):
    """Zentrierte Zeile; cy = optische Mitte der Großbuchstaben."""
    w = width(text, kind, size, track, sx)
    if maxw and w > maxw:
        f = maxw / w
        size *= f
        track *= f
        w = maxw
    x = cx - w / 2
    base = cy + cap_height(kind if kind != "jp" else "jp", size) / 2 if kind != "jp" else cy + size * 0.36
    out = []
    for ch in text:
        d, adv = glyph(ch, kind, size, x, base, 0, sx)
        out.append(d)
        x += adv + track
    return " ".join(out)


def arc(text, kind, size, cx, cy, r, center_deg=-90, track=0.0, bottom=False, maxdeg=None):
    """Text auf einem Kreisbogen. center_deg: Winkel der Textmitte (-90 = oben).
    bottom=True: Text unten, von links nach rechts lesbar (Buchstaben stehen aufrecht nach innen)."""
    w = width(text, kind, size, track)
    span = w / r
    if maxdeg and math.degrees(span) > maxdeg:
        f = math.radians(maxdeg) / span
        size *= f
        track *= f
        w = width(text, kind, size, track)
        span = w / r
    capc = cap_height(kind, size) / 2 if kind != "jp" else size * 0.36
    out = []
    if not bottom:
        a = math.radians(center_deg) - span / 2
        rr = r - capc  # Grundlinie innen, Großbuchstaben mittig auf r
        for ch in text:
            _, adv = glyph(ch, kind, size, 0, 0)
            mid = a + (adv / 2) / r
            px = cx + rr * math.cos(a)
            py = cy + rr * math.sin(a)
            d, _ = glyph(ch, kind, size, px, py, math.degrees(a) + 90 + math.degrees((adv / 2) / r) * 0)
            out.append(d)
            a += (adv + track) / r
    else:
        a = math.radians(center_deg) + span / 2
        rr = r + capc
        for ch in text:
            _, adv = glyph(ch, kind, size, 0, 0)
            px = cx + rr * math.cos(a)
            py = cy + rr * math.sin(a)
            d, _ = glyph(ch, kind, size, px, py, math.degrees(a) - 90)
            out.append(d)
            a -= (adv + track) / r
    return " ".join(out)
