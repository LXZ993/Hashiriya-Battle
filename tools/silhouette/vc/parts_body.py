"""Körperteile: Grundkörper, Oberteile, Halsteile, Aufnäher und Rangabzeichen.

Koordinaten im Körper-System bei voller Breite (Männer). Frauen-Oberteile werden beim Ablegen
in der Ebene um die Mitte auf k=0,86 verschmälert. Jedes Oberteil nennt feste Plätze (ANCHORS)
für Crew-Abzeichen und Rang, passend zum Kleidungsstück: Stoffaufnäher, Anstecknadel,
Aufdruck oder Stickerei. So landet nie ein Abzeichen auf Pelz, Schal oder Reißverschluss.
"""
import math
import random
from core import CX, HEAD_DY, f, ell, bean, mirror, shade_shell, cloth, stitch, line, bez

TONES = {
    "schwarz": ("#2c2f36", "#0c0d10"),
    "anthrazit": ("#474c56", "#1c1f25"),
    "marine": ("#2f3b5c", "#11172a"),
    "weinrot": ("#6a2230", "#2a0b12"),
    "oliv": ("#56603c", "#262b18"),
    "sand": ("#b7a17a", "#6e5c3e"),
    "weiss": ("#f2f3f5", "#b9bec7"),
    "grau": ("#8a9099", "#4a4f57"),
    "lila": ("#4a2a66", "#1c0e2a"),
    "royal": ("#2f55c8", "#13245c"),
    "rot": ("#c03030", "#5a1010"),
    "senf": ("#c89a2e", "#6b4c0c"),
    "petrol": ("#1f5f66", "#0b2a2e"),
    "denim": ("#4f6f9e", "#1f3150"),
    "creme": ("#efe6d6", "#b8a98e"),
    "rosa": ("#f0b8cf", "#a8667f"),
}


def bean_n(o=0, nw=30, dip=24, v=False):
    """Oberkörper-Hülle mit Halsausschnitt (rund oder V)."""
    L, R, t = CX - 182 - o, CX + 182 + o, 372 - o
    mid = f"L{CX},{f(t + dip)} L{f(CX + nw)},{f(t + 4)}" if v else f"Q{CX},{f(t + 2 * dip - 4)} {f(CX + nw)},{f(t + 4)}"
    return (f"M{f(L)},{f(t + 108)} C{f(L)},{f(t + 30)} {f(CX - 110)},{f(t + 2)} {f(CX - nw)},{f(t + 4)} {mid} "
            f"C{f(CX + 110)},{f(t + 2)} {f(R)},{f(t + 30)} {f(R)},{f(t + 108)} "
            f"C{f(R)},{f(t + 170)} {f(R - 6)},{f(t + 210)} {f(R - 12)},640 L{f(L + 12)},640 "
            f"C{f(L + 6)},{f(t + 210)} {f(L)},{f(t + 170)} {f(L)},{f(t + 108)} Z")


def body_shell(doc, A):
    neck = "M278,296 L322,296 L326,384 L274,384 Z"
    out = shade_shell(doc, neck, (274, 296, 326, 384), A)
    out += doc.soft(ell(300, 316 + HEAD_DY, 36, 14), "#3a3f47", 6, .6)
    out += shade_shell(doc, bean(1), (CX - 182, 372, CX + 182, 640), A)
    return out


def grad(doc, tone, a=0, b=1):
    return doc.lin([(a, tone[0], 1), (b, tone[1], 1)])


def zipper(x, y0, y1, col="#b9bec7"):
    out = line(f"M{x},{y0} L{x},{y1}", "#000", 3, .55)
    out += f'<path d="M{x},{y0} L{x},{y1}" stroke="{col}" stroke-width="3" stroke-dasharray="1.6 1.6" fill="none"/>'
    out += f'<rect x="{x - 4}" y="{y0 + 2}" width="8" height="14" rx="2" fill="{col}" stroke="#000" stroke-opacity=".5"/>'
    return out


def buttons(x, ys, col="#d9d2bd", r=4):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{col}" stroke="#000" stroke-opacity=".5"/>' for y in ys)


def rib_collar(doc, tone, A=None, stripe=None):
    d = "M252,368 C262,404 338,404 348,368 L336,364 C330,388 270,388 264,364 Z"
    out = f'<path d="{d}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    out += f'<g {doc.clip(d)}>' + "".join(line(f"M{x},360 L{x + (x - 300) * .12},404", "#000", 1.4, .25) for x in range(254, 348, 6))
    if stripe:
        out += line("M256,374 C268,400 332,400 344,374", stripe, 2.6, .9)
    out += "</g>"
    return out


def stand_collar(doc, tone, open_zip=False):
    d = "M262,380 L264,342 C282,350 318,350 336,342 L338,380 C320,388 280,388 262,380 Z"
    out = f'<path d="{d}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    out += line("M266,350 C284,356 316,356 334,350", "#ffffff", 1.2, .15)
    return out


def shirt_collar(doc, col="#f4f5f7", shade="#b9bec7"):
    out = ""
    for d in ("M276,360 L300,394 L256,404 L262,368 Z", mirror("M276,360 L300,394 L256,404 L262,368 Z")):
        out += f'<path d="{d}" fill="{doc.lin([(0, col, 1), (1, shade, 1)])}" stroke="#000" stroke-opacity=".35" stroke-width="1.2"/>'
    return out


def bust(doc):
    out = doc.soft(ell(254, 466, 40, 26), "#ffffff", 14, .07) + doc.soft(ell(346, 466, 40, 26), "#ffffff", 14, .07)
    cres = "M226,494 C240,510 272,512 290,498 C272,506 242,504 226,494 Z"
    out += doc.soft(cres, "#000", 5, .14) + doc.soft(mirror(cres), "#000", 5, .14)
    return out


def finish(doc, d, body, bust_on, female):
    """Brustschattierung (Frauen) auf den Stoff begrenzen."""
    if bust_on and female:
        body += f'<g {doc.clip(d)}>{bust(doc)}</g>'
    return body


# ---------------------------------------------------------------------------
# Oberteile
# ---------------------------------------------------------------------------

def g_hoodie(doc, A, tone, ctx):
    d = bean_n(10, 30, 20)
    hood = "M208,400 C196,350 236,318 300,318 C364,318 404,350 392,400 C370,380 338,372 300,372 C262,372 230,380 208,400 Z"
    out = f'<path d="{hood}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".45" stroke-width="1.5"/>'
    out += doc.soft("M230,392 C250,376 350,376 370,392 C350,386 250,386 230,392 Z", "#000", 4, .5)
    out += cloth(doc, d, tone, A, [ell(185, 560, 10, 70), ell(415, 560, 10, 70), ell(300, 470, 60, 6)])
    out += doc.soft("M226,404 C250,430 350,430 374,404 C350,416 250,416 226,404 Z", "#000", 5, .55)
    out += line("M228,402 C252,428 348,428 372,402", "#000", 4, .35)
    out += line("M282,416 C280,450 284,470 280,496", "#e6e8ec", 3.2) + line("M318,416 C320,450 316,470 320,496", "#e6e8ec", 3.2)
    out += f'<rect x="274" y="494" width="12" height="16" rx="3" fill="{A}"/><rect x="314" y="494" width="12" height="16" rx="3" fill="{A}"/>'
    out += line("M206,640 L222,548 C260,540 340,540 378,548 L394,640", "#000", 2.4, .45)
    out += stitch("M214,640 L228,556 C262,549 338,549 372,556 L386,640", "#fff", .2)
    return finish(doc, d, out, True, ctx["female"])


def g_pelz(doc, A, tone, ctx):
    d = bean_n(12, 34, 24)
    out = cloth(doc, d, tone, A, [ell(200, 560, 9, 80), ell(400, 560, 9, 80)], light=.45)
    out += line("M300,520 L300,640", "#000", 2.2, .5)
    out += buttons(316, (572,), "#e8cf8a", 6)
    rnd = random.Random(7)
    tufts = []
    for i in range(34):
        t = i / 33
        xi, yi = bez(t, (276, 358), (246, 384), (250, 456), (298, 512))
        xo, yo = bez(t, (236, 344), (128, 352), (150, 468), (290, 548))
        for j in range(4):
            u = (j + .5) / 4 + rnd.uniform(-.06, .06)
            x, y = xi + (xo - xi) * u, yi + (yo - yi) * u
            r = (19 - 7 * t) * rnd.uniform(.85, 1.15)
            for sx in (x, 2 * CX - x):
                tufts.append((sx + rnd.uniform(-2, 2), y + rnd.uniform(-2, 2), r))
    tufts.sort(key=lambda c: c[1])
    fur_col = ctx.get("fur", ("#fbf6ee", "#e2d6c4", "#a8977f"))
    furfill = doc.rad([(0, fur_col[0], 1), (.6, fur_col[1], 1), (1, fur_col[2], 1)], .38, .3, .75)
    stole = "M236,344 C128,352 150,468 290,548 L310,548 C450,468 472,352 364,344 C350,362 324,372 300,372 C276,372 250,362 236,344 Z"
    out += doc.soft(stole, "#000", 12, .5, 'transform="translate(0,10)"')
    out += f'<g fill="{furfill}">' + "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}"/>' for x, y, r in tufts) + "</g>"
    out += f'<g {doc.clip(stole)}>' + doc.soft("M150,470 C220,520 380,520 450,470 L450,560 L150,560 Z", "#5b4a36", 14, .45) + "</g>"
    for x, y, r in tufts[::2]:
        for _ in range(2):
            a = rnd.uniform(0, 2 * math.pi)
            sx, sy = x + math.cos(a) * r * .8, y + math.sin(a) * r * .8
            out += line(f"M{f(sx)},{f(sy)} l{f(math.cos(a) * 6)},{f(math.sin(a) * 6 + 2)}", fur_col[0], 1.4, .7)
    out += doc.soft("M200,372 C220,354 248,348 264,352 C240,362 222,374 210,392 Z", "#ffffff", 6, .6)
    return doc.shadowed(out, 0, 4, 6, 30)


def g_militaer(doc, A, tone, ctx):
    d = bean_n(8, 34, 40, v=True)
    out = cloth(doc, d, tone, A, [ell(190, 570, 9, 70), ell(410, 570, 9, 70), ell(300, 520, 4, 60)], light=.3)
    out += f'<path d="M300,404 L300,640" stroke="#000" stroke-opacity=".6" stroke-width="2.4"/>'
    col = "M266,366 L222,420 L290,412 Z"
    out += f'<path d="{col}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.4"/>'
    out += f'<path d="{mirror(col)}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.4"/>'
    for sd in (-1, 1):
        x = 300 + sd * 74
        out += doc.soft(f"M{x - 30},462 h60 v52 h-60 z", "#000", 3, .3)
        out += f'<rect x="{x - 30}" y="458" width="60" height="50" rx="3" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".6" stroke-width="1.3"/>'
        out += f'<path d="M{x - 33},454 h66 v18 h-66 z" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".6" stroke-width="1.3"/>'
        out += f'<circle cx="{x}" cy="466" r="3.5" fill="#000" fill-opacity=".5"/>'
        out += stitch(f"M{x - 27},462 h54 M{x - 27},504 h54", "#d8d2b8", .25)
        out += line(f"M{300 + sd * 120},402 L{300 + sd * 168},426", tone[1], 14)
    out += buttons(300, (436, 520, 590), "#2a2e1c", 4)
    out += '<rect x="336" y="428" width="70" height="14" rx="2" fill="#d8d2b8"/>'
    out += f'<text x="371" y="439" text-anchor="middle" font-size="11" font-weight="700" font-family="Arial, sans-serif" fill="#2a2e1c">{ctx.get("tape", "HASHIRIYA")[:9]}</text>'
    return finish(doc, d, out, False, ctx["female"])


def g_leder(doc, A, tone, ctx):
    d = bean_n(10, 40, 112, v=True)
    inner_col = ctx.get("inner", ("#f2f3f5", "#b9bec7"))
    tee = bean_n(2, 26, 18)
    out = f'<path d="{tee}" fill="{grad(doc, inner_col)}"/>'
    out += line("M274,370 Q300,404 326,370", "#000", 2.4, .3)
    out += cloth(doc, d, tone, A, [ell(186, 560, 9, 70), ell(414, 560, 9, 70)], light=.55)
    out += f'<g {doc.clip(d)}>' + doc.soft("M140,430 C170,410 200,410 220,430 L210,470 C190,450 160,450 140,470 Z", "#ffffff", 8, .16) + "</g>"
    lap = "M262,368 L190,410 L232,452 L294,484 Z"
    for p in (lap, mirror(lap)):
        out += f'<path d="{p}" fill="{doc.lin([(0, "#3b3f48", 1), (1, "#0c0d10", 1)])}" stroke="#000" stroke-opacity=".7" stroke-width="1.4"/>'
    out += buttons(206, (420,), "#c9ced6", 3.5) + buttons(394, (420,), "#c9ced6", 3.5)
    out += zipper(292, 484, 640) + zipper(308, 484, 640)
    out += line("M174,520 L230,500", "#000", 3, .6) + line("M370,560 L420,540", "#000", 3, .6)
    out += f'<rect x="226" y="496" width="5" height="10" rx="1" fill="#c9ced6"/><rect x="416" y="536" width="5" height="10" rx="1" fill="#c9ced6"/>'
    return out


def g_bomber(doc, A, tone, ctx):
    d = bean_n(14, 34, 22)
    out = cloth(doc, d, tone, A, [ell(190, 560, 12, 60), ell(410, 560, 12, 60), ell(300, 600, 120, 6)], light=.5)
    out += f'<g {doc.clip(d)}>' + doc.soft("M170,440 C200,420 240,420 260,440 L250,470 C230,452 200,452 172,470 Z", "#ffffff", 6, .25) + "</g>"
    out += rib_collar(doc, ("#1f2228", "#0b0c0f"))
    out += f'<path d="M296,398 L304,398 L304,640 L296,640 Z" fill="#e8742a" fill-opacity=".8"/>'
    out += zipper(300, 398, 640)
    out += line("M196,566 L226,520", "#000", 3, .5) + line("M404,566 L374,520", "#000", 3, .5)
    out += stitch("M200,570 L230,524 M400,570 L370,524", "#fff", .2)
    out += f'<path d="M160,600 C230,612 370,612 440,600" stroke="#000" stroke-opacity=".35" stroke-width="2" fill="none"/>'
    return finish(doc, d, out, True, ctx["female"])


def g_anzug(doc, A, tone, ctx, tie=True):
    d = bean_n(10, 36, 100, v=True)
    shirt_col = ctx.get("shirt", ("#f4f5f7", "#b9bec7"))
    out = f'<path d="{bean_n(2, 26, 14)}" fill="{grad(doc, shirt_col)}"/>'
    if tie:
        tc = ctx.get("tie", (ctxA(A), "#000"))
        out += f'<path d="M292,384 L308,384 L305,398 L295,398 Z" fill="{tc[0]}" stroke="#000" stroke-opacity=".5"/>'
        out += f'<path d="M295,398 L305,398 L314,470 L300,486 L286,470 Z" fill="{doc.lin([(0, tc[0], 1), (1, tc[1], 1)])}" stroke="#000" stroke-opacity=".5"/>'
        out += "".join(line(f"M{288 + i * 2},{410 + i * 14} l20,-6", "#ffffff", 1.4, .2) for i in range(4))
    else:
        out += line("M276,372 L300,420 L324,372", "#000", 1.6, .25)
    out += shirt_collar(doc, *shirt_col)
    out += cloth(doc, d, tone, A, [ell(190, 570, 9, 70), ell(410, 570, 9, 70)], light=.35)
    lap = "M264,366 L232,404 L246,410 L222,440 L300,472 Z"
    for p in (lap, mirror(lap)):
        out += f'<path d="{p}" fill="{doc.lin([(0, tone[0], 1), (1, tone[1], 1)])}" stroke="#000" stroke-opacity=".6" stroke-width="1.3"/>'
        out += doc.soft(p, "#ffffff", 4, .08)
    out += buttons(300, (500, 552), "#111", 4.5)
    out += f'<path d="M222,452 l8,-8 l6,6 l6,-7 l4,9 z" fill="#ffffff" fill-opacity=".9"/>' + line("M216,454 L250,450", "#000", 2.4, .5)  # Einstecktuch
    out += line("M352,530 L408,530", "#000", 2.4, .45) + line("M192,530 L248,530", "#000", 2.4, .45)
    return out


def ctxA(A):
    return A


def g_kostuem(doc, A, tone, ctx):
    return g_anzug(doc, A, tone, ctx, tie=False)


def g_tokkou(doc, A, tone, ctx):
    """Tokkou-fuku: langer Bosozoku-Mantel mit Stehkragen und Stickerei."""
    d = bean_n(14, 30, 18)
    out = cloth(doc, d, tone, A, [ell(196, 580, 10, 70), ell(404, 580, 10, 70), ell(300, 600, 6, 60)], light=.45)
    out += stand_collar(doc, tone)
    out += line("M300,450 L300,640", "#000", 2.2, .45)
    gold = ctx.get("thread", "#e8c35a")
    left = ctx.get("motto", "天上天下")
    right = (ctx.get("jp") or "走り屋連合")[:4]
    for x, txt in ((228, left), (372, right)):
        for i, ch in enumerate(txt[:4]):
            out += f'<text x="{x}" y="{448 + i * 34}" text-anchor="middle" font-size="30" font-weight="700" font-family="Yu Mincho, Hiragino Mincho ProN, Noto Serif JP, serif" fill="{gold}" stroke="#000" stroke-opacity=".35" stroke-width=".8">{ch}</text>'
    out += line("M210,416 L246,416 M354,416 L390,416", gold, 2, .7)
    return out


def g_trainings(doc, A, tone, ctx):
    d = bean_n(8, 30, 16)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60)], light=.45)
    out += stand_collar(doc, tone)
    s = ctx.get("stripe", "#ffffff")
    for sd in (-1, 1):
        for i in range(2):
            x = 300 + sd * (156 + i * 12)
            out += f'<path d="M{x - sd * 40},{404 - i * 4} C{x},430 {x + sd * 4},520 {x - sd * 2},640" stroke="{s}" stroke-width="6" fill="none" stroke-linecap="round"/>'
    out += zipper(300, 344, 640)
    return finish(doc, d, out, True, ctx["female"])


def g_rennanzug(doc, A, tone, ctx):
    d = bean_n(8, 30, 16)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60)], light=.5)
    out += f'<g {doc.clip(d)}><path d="M110,470 C170,420 200,520 196,640 L110,640 Z" fill="{A}" fill-opacity=".85"/><path d="{mirror("M110,470 C170,420 200,520 196,640 L110,640 Z")}" fill="{A}" fill-opacity=".85"/></g>'
    out += stand_collar(doc, tone)
    out += f'<rect x="306" y="350" width="24" height="12" rx="2" fill="{A}"/>'
    out += zipper(300, 344, 640)
    for x, y, w, txt in ((214, 520, 64, "KAZE OIL"), (322, 520, 64, "RYU GEAR"), (226, 548, 48, "TSUKI")):
        out += f'<rect x="{x}" y="{y}" width="{w}" height="18" rx="3" fill="#f2f3f5" stroke="#000" stroke-opacity=".4"/>'
        out += f'<text x="{x + w / 2}" y="{y + 13}" text-anchor="middle" font-size="10" font-weight="700" font-family="Arial, sans-serif" fill="#15171c">{txt}</text>'
    return finish(doc, d, out, True, ctx["female"])


def g_jeans(doc, A, tone, ctx):
    d = bean_n(10, 34, 70, v=True)
    out = f'<path d="{bean_n(2, 26, 18)}" fill="{grad(doc, ctx.get("inner", ("#2c2f36", "#0c0d10")))}"/>'
    out += cloth(doc, d, tone, A, [ell(190, 570, 9, 60), ell(410, 570, 9, 60)], light=.4)
    o = "#d98a3a"
    out += stitch("M300,442 L300,640", o, .7, 1.4) + line("M306,442 L306,640", "#000", 1.4, .35)
    out += buttons(312, (470, 520, 570), "#b87333", 4.2)
    for sd in (-1, 1):
        x = 300 + sd * 70
        out += f'<path d="M{x - 30},480 h60 v48 l-30,8 l-30,-8 z" fill="none" stroke="#000" stroke-opacity=".4" stroke-width="1.4"/>'
        out += f'<path d="M{x - 32},456 h64 v18 l-32,10 l-32,-10 z" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
        out += stitch(f"M{x - 28},460 h56", o, .7, 1.2)
        out += buttons(x, (476,), "#b87333", 3.2)
    sh = "M270,364 C236,368 204,388 194,424 L240,446 L296,440 Z"
    sher = doc.rad([(0, "#f6efe2", 1), (1, "#c8b89a", 1)], .4, .3, .8)
    for p in (sh, mirror(sh)):
        out += f'<path d="{p}" fill="{sher}" stroke="#8a7a60" stroke-opacity=".6" stroke-width="1.2"/>'
        out += f'<g {doc.clip(p)}>' + "".join(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#fff" fill-opacity=".5"/>' for x in range(196, 404, 7) for y in range(366, 446, 7)) + "</g>"
    return finish(doc, d, out, True, ctx["female"])


def g_tshirt(doc, A, tone, ctx):
    d = bean_n(4, 30, 22)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60), ell(300, 430, 40, 4)], light=.4)
    out += line("M270,370 Q300,416 330,370", "#000", 4, .3)
    out += line("M272,374 Q300,412 328,374", tone[0], 3, .8)
    return finish(doc, d, out, True, ctx["female"])


def g_rollkragen(doc, A, tone, ctx):
    d = bean_n(6, 30, 18)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60)], light=.35)
    out += f'<g {doc.clip(d)}>' + "".join(line(f"M{x},400 L{x + (x - 300) * .06},640", "#000", 2, .14) for x in range(130, 474, 9)) + "</g>"
    tube = "M268,336 C268,330 332,330 332,336 L338,384 C320,396 280,396 262,384 Z"
    out += f'<path d="{tube}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".45" stroke-width="1.3"/>'
    for y in (348, 360, 372):
        out += line(f"M266,{y} C284,{y + 8} 316,{y + 8} 334,{y}", "#000", 1.6, .25)
    return finish(doc, d, out, True, ctx["female"])


def g_overall(doc, A, tone, ctx):
    d = bean_n(8, 34, 64, v=True)
    out = cloth(doc, d, tone, A, [ell(190, 570, 9, 60), ell(410, 570, 9, 60)], light=.35)
    col = "M268,364 L238,420 L292,428 Z"
    for p in (col, mirror(col)):
        out += f'<path d="{p}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".55" stroke-width="1.3"/>'
    out += zipper(300, 436, 640)
    x = 228
    out += f'<rect x="{x - 26}" y="470" width="52" height="56" rx="3" fill="none" stroke="#000" stroke-opacity=".45" stroke-width="1.4"/>'
    out += stitch(f"M{x - 22},476 h44", "#fff", .3)
    for i, c in enumerate(("#d23a3a", "#2f55c8", "#111")):
        out += f'<rect x="{x - 14 + i * 9}" y="458" width="5" height="22" rx="2" fill="{c}"/>'
    out += f'<ellipse cx="372" cy="446" rx="34" ry="13" fill="#f2f3f5" stroke="{A}" stroke-width="2"/>'
    out += f'<text x="372" y="450" text-anchor="middle" font-size="11" font-style="italic" font-weight="700" font-family="Arial, sans-serif" fill="#15171c">{ctx.get("nick", "Hashiriya")[:9]}</text>'
    return finish(doc, d, out, True, ctx["female"])


def g_sukajan(doc, A, tone, ctx):
    d = bean_n(12, 34, 22)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60)], light=.7)
    out += f'<g {doc.clip(d)}>' + doc.soft("M150,450 C190,420 240,430 260,470 C230,460 190,460 160,490 Z", "#ffffff", 8, .45) + doc.soft(mirror("M150,450 C190,420 240,430 260,470 C230,460 190,460 160,490 Z"), "#ffffff", 8, .25) + "</g>"
    out += rib_collar(doc, ("#1a1c22", "#08090b"), stripe=ctx.get("stripe", A))
    out += zipper(300, 398, 640, "#e8c35a")
    out += f'<path d="M160,618 C230,630 370,630 440,618 L440,640 L160,640 Z" fill="#14161b"/>' + line("M160,624 C230,636 370,636 440,624", ctx.get("stripe", A), 2.4)
    return finish(doc, d, out, True, ctx["female"])


def g_parka(doc, A, tone, ctx):
    d = bean_n(14, 34, 22)
    out = cloth(doc, d, tone, A, [ell(190, 570, 12, 70), ell(410, 570, 12, 70)], light=.4)
    out += f'<path d="M290,394 h24 v246 h-24 z" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    out += buttons(302, (430, 490, 550, 610), "#2a2e1c", 4)
    for sd in (-1, 1):
        x = 300 + sd * 90
        out += f'<path d="M{x - 38},560 h76 v14 h-76 z" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".55" stroke-width="1.3"/>'
        out += line(f"M{x - 34},576 L{x - 34},640 M{x + 34},576 L{x + 34},640", "#000", 1.4, .35)
    rnd = random.Random(11)
    ruff = "M196,410 C200,346 256,326 300,326 C344,326 400,346 404,410 C380,388 346,374 300,374 C254,374 220,388 196,410 Z"
    out += doc.soft(ruff, "#000", 8, .5, 'transform="translate(0,6)"')
    out += f'<path d="{ruff}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    tufts = []
    for i in range(60):
        t = i / 59
        a = math.pi * (1.0 + t)
        for rr in (.98, 1.1, 1.22):
            x, y = 300 + math.cos(a) * 92 * rr, 392 + math.sin(a) * 48 * rr
            if abs(x - 300) < 30 and y > 360:
                continue
            tufts.append((x + rnd.uniform(-2, 2), y + rnd.uniform(-2, 2), rnd.uniform(9, 13)))
    furfill = doc.rad([(0, "#e6dccb", 1), (1, "#8a7c66", 1)], .4, .3, .8)
    out += f'<g fill="{furfill}">' + "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}"/>' for x, y, r in tufts) + "</g>"
    for x, y, r in tufts:
        a = math.atan2(y - 392, x - 300) + rnd.uniform(-.4, .4)
        out += line(f"M{f(x)},{f(y)} l{f(math.cos(a) * 8)},{f(math.sin(a) * 8)}", "#f1e9da", 1.2, .6)
    return out


def g_weste(doc, A, tone, ctx):
    shirt = bean_n(8, 28, 16)
    out = cloth(doc, shirt, ctx.get("shirt", ("#f4f5f7", "#b9bec7")), A, [ell(150, 560, 8, 60), ell(450, 560, 8, 60)], light=.2)
    out += shirt_collar(doc)
    vest = "M174,640 L176,476 C180,428 222,396 264,382 L300,492 L336,382 C378,396 420,428 424,476 L426,640 Z"
    out += f'<path d="{vest}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".55" stroke-width="1.5"/>'
    out += f'<g {doc.clip(vest)}>' + doc.soft("M190,470 C210,440 240,420 260,420 L250,450 C230,452 210,470 200,500 Z", "#ffffff", 6, .2) + "</g>"
    out += buttons(300, (514, 548, 582), "#d9d2bd", 4)
    out += line("M196,560 L240,556 M360,556 L404,560", "#000", 2.4, .45)
    bc = ctx.get("tie", (A, "#000"))
    out += f'<path d="M300,394 L278,382 L278,406 Z M300,394 L322,382 L322,406 Z" fill="{bc[0]}" stroke="#000" stroke-opacity=".5"/><rect x="294" y="388" width="12" height="12" rx="3" fill="{bc[1]}"/>'
    return finish(doc, vest, out, True, ctx["female"])


def g_bluse(doc, A, tone, ctx):
    d = bean_n(4, 30, 20)
    out = cloth(doc, d, tone, A, [ell(196, 570, 9, 60), ell(404, 570, 9, 60)], light=.55)
    out += f'<g {doc.clip(d)}>' + doc.soft("M180,440 C220,420 260,430 270,460 C240,450 210,452 186,470 Z", "#ffffff", 8, .35) + "</g>"
    out += line("M300,420 L300,640", "#000", 1.4, .25) + buttons(300, (540, 590), "#ffffff", 3.2)
    bc = ctx.get("tie", (A, "#000"))
    out += f'<path d="M300,384 C280,370 262,374 262,388 C262,402 282,402 300,392 C318,402 338,402 338,388 C338,374 320,370 300,384 Z" fill="{doc.lin([(0, bc[0], 1), (1, bc[1], 1)])}" stroke="#000" stroke-opacity=".4"/>'
    out += f'<path d="M294,392 C286,430 280,470 284,510 L294,506 C292,470 296,430 300,396 Z M306,392 C314,430 322,470 318,512 L308,508 C308,470 304,430 300,396 Z" fill="{doc.lin([(0, bc[0], 1), (1, bc[1], 1)])}" stroke="#000" stroke-opacity=".35"/>'
    out += f'<circle cx="300" cy="388" r="6" fill="{bc[1]}"/>'
    return finish(doc, d, out, True, ctx["female"])


# Plätze: patch/rank -> (x, y, Art). Art: patch = Stoffaufnäher, pin = Anstecknadel,
# print = Aufdruck, stick = Stickerei, None = kein Platz (z. B. Tokkou: Crew ist eingestickt)
# id: Name, Funktion, Halsausschnitt, Plätze, Gewicht m, Gewicht f, passende Farben
GARMENTS = {
    "hoodie": ("Hoodie", g_hoodie, "hood", {"patch": (372, 468, "patch"), "rank": (222, 468, "patch")}, 8, 5,
               ["schwarz", "anthrazit", "marine", "grau", "weinrot", "oliv", "rosa", "lila"]),
    "pelz": ("Mantel mit Pelzkragen", g_pelz, "fur", {"patch": (404, 566, "pin"), "rank": (196, 566, "pin")}, 1, 4,
             ["schwarz", "lila", "weinrot", "creme"]),
    "militaer": ("Feldjacke", g_militaer, "collar_open", {"patch": (374, 488, "patch"), "rank": (226, 488, "patch")}, 3, 1,
                 ["oliv", "sand", "anthrazit"]),
    "leder": ("Lederjacke", g_leder, "open", {"patch": (210, 548, "pin"), "rank": (394, 470, "pin")}, 7, 4,
              ["schwarz", "weinrot", "braun_leder"]),
    "bomber": ("Bomberjacke", g_bomber, "rib", {"patch": (368, 470, "patch"), "rank": (232, 470, "patch")}, 6, 3,
               ["oliv", "schwarz", "marine", "weinrot"]),
    "anzug": ("Anzug mit Krawatte", g_anzug, "tie", {"patch": (240, 424, "pin"), "rank": (360, 424, "pin")}, 5, 0,
              ["schwarz", "anthrazit", "marine", "weiss", "weinrot"]),
    "kostuem": ("Kostüm", g_kostuem, "v", {"patch": (240, 424, "pin"), "rank": (360, 424, "pin")}, 0, 5,
                ["schwarz", "weiss", "creme", "weinrot", "marine", "rosa"]),
    "tokkou": ("Tokkou-Mantel", g_tokkou, "stand", {"patch": None, "rank": (300, 424, "stick")}, 3, 2,
               ["weiss", "schwarz", "lila", "royal", "rot"]),
    "trainings": ("Trainingsjacke", g_trainings, "stand", {"patch": (370, 450, "patch"), "rank": (230, 450, "patch")}, 6, 5,
                  ["royal", "rot", "schwarz", "petrol", "lila", "weiss"]),
    "rennanzug": ("Rennanzug", g_rennanzug, "stand", {"patch": (372, 454, "patch"), "rank": (228, 454, "patch")}, 4, 3,
                  ["weiss", "schwarz", "royal", "rot", "senf"]),
    "jeans": ("Jeansjacke mit Fellkragen", g_jeans, "collar_open", {"patch": (370, 508, "patch"), "rank": (230, 508, "patch")}, 5, 4,
              ["denim"]),
    "tshirt": ("T-Shirt mit Aufdruck", g_tshirt, "open", {"patch": (300, 490, "print"), "rank": (230, 440, "print")}, 5, 4,
               ["weiss", "schwarz", "grau", "rot", "senf", "petrol", "rosa"]),
    "rollkragen": ("Rollkragenpullover", g_rollkragen, "high", {"patch": (364, 456, "pin"), "rank": (236, 456, "pin")}, 3, 5,
                   ["schwarz", "creme", "grau", "weinrot", "marine"]),
    "overall": ("Mechaniker-Overall", g_overall, "collar_open", {"patch": (372, 500, "patch"), "rank": (228, 440, "patch")}, 4, 2,
                ["grau", "marine", "oliv", "senf", "rot"]),
    "sukajan": ("Sukajan", g_sukajan, "rib", {"patch": (230, 480, "stick"), "rank": (372, 470, "stick")}, 4, 4,
                ["schwarz", "marine", "weinrot", "lila", "petrol"]),
    "parka": ("Parka mit Fellkapuze", g_parka, "fur", {"patch": (372, 470, "patch"), "rank": (228, 470, "patch")}, 3, 2,
              ["oliv", "marine", "schwarz"]),
    "weste": ("Weste mit Fliege", g_weste, "tie", {"patch": (364, 452, "pin"), "rank": (240, 452, "pin")}, 3, 1,
              ["schwarz", "anthrazit", "weinrot"]),
    "bluse": ("Bluse mit Schleife", g_bluse, "tie", {"patch": (364, 468, "pin"), "rank": (236, 468, "pin")}, 0, 5,
              ["creme", "weiss", "rosa", "schwarz"]),
}
TONES["braun_leder"] = ("#6b4128", "#22120a")

# ---------------------------------------------------------------------------
# Halsteile (Körper-System). Erlaubt nur bei passendem Halsausschnitt.
# ---------------------------------------------------------------------------


def n_kopfhoerer(doc, A):
    out = line("M244,352 C254,388 346,388 356,352", "#0d0f13", 9) + line("M244,352 C254,388 346,388 356,352", "#ffffff", 2, .15)
    for sd in (-1, 1):
        x = 300 + sd * 60
        out += f'<rect x="{x - 17}" y="338" width="34" height="46" rx="14" fill="{doc.lin([(0, "#2b313b", 1), (1, "#07080b", 1)])}" stroke="{A}" stroke-width="3"/>'
        out += f'<rect x="{x - 9}" y="346" width="18" height="30" rx="8" fill="{A}" fill-opacity=".25"/>'
    return doc.shadowed(out, 0, 6, 8, 45)


def n_hundemarken(doc, A):
    out = line("M276,364 C280,424 320,424 324,364", "#b8bfca", 2) + '<path d="M276,364 C280,424 320,424 324,364" fill="none" stroke="#5f6670" stroke-width="2" stroke-dasharray="2 2"/>'
    for dx, dy, r in ((-6, 0, -8), (6, 6, 10)):
        out += f'<rect x="{292 + dx}" y="{410 + dy}" width="18" height="28" rx="6" transform="rotate({r} {301 + dx} {424 + dy})" fill="{doc.lin([(0, "#eef1f5", 1), (1, "#8d949e", 1)], 0, 0, 1, 1)}" stroke="#555c66" stroke-width="1.2"/>'
    return doc.shadowed(out, 0, 3, 4, 45)


def n_kette(doc, A):
    out = line("M278,368 C282,420 318,420 322,368", "#8a6a1e", 5)
    out += '<path d="M278,368 C282,420 318,420 322,368" fill="none" stroke="#f3d77a" stroke-width="3" stroke-dasharray="3 2"/>'
    out += f'<circle cx="300" cy="412" r="6" fill="{doc.rad([(0, "#fff3c4", 1), (1, "#a37a2a", 1)], .35, .3, .7)}" stroke="#6b4c0c"/>'
    return doc.shadowed(out, 0, 3, 4, 40)


def n_schal(doc, A):
    tone = (A, "#15171c")
    wrap = "M258,344 C276,354 324,354 342,344 L350,384 C326,400 274,400 250,384 Z"
    end = "M318,384 C330,420 336,470 332,520 L360,522 C362,470 356,420 344,382 Z"
    out = f'<path d="{end}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    out += "".join(line(f"M{332 + i * 6},{512} L{332 + i * 6},{530}", A, 2) for i in range(5))
    out += f'<path d="{wrap}" fill="{grad(doc, tone)}" stroke="#000" stroke-opacity=".5" stroke-width="1.3"/>'
    out += f'<g {doc.clip(wrap)}>' + "".join(line(f"M{x},340 L{x + 4},400", "#000", 1.6, .2) for x in range(250, 352, 7)) + "</g>"
    return doc.shadowed(out, 0, 5, 6, 40)


def n_choker(doc, A):
    out = line("M278,356 C290,362 310,362 322,356", "#111", 6)
    out += f'<path d="M300,362 l5,8 l-5,8 l-5,-8 z" fill="{A}"/>'
    return doc.shadowed(out, 0, 2, 3, 40)


def n_handtuch(doc, A):
    col = doc.lin([(0, "#ffffff", 1), (1, "#c9ced6", 1)])
    out = ""
    for sd in (-1, 1):
        p = f"M{300 + sd * 20},350 C{300 + sd * 44},356 {300 + sd * 48},380 {300 + sd * 46},480 L{300 + sd * 20},484 C{300 + sd * 22},420 {300 + sd * 16},380 {300 + sd * 8},360 Z"
        out += f'<path d="{p}" fill="{col}" stroke="#000" stroke-opacity=".3" stroke-width="1.2"/>'
        out += line(f"M{300 + sd * 22},470 L{300 + sd * 45},468", A, 3)
    out += f'<path d="M278,346 C290,356 310,356 322,346 L324,360 C310,368 290,368 276,360 Z" fill="{col}" stroke="#000" stroke-opacity=".3"/>'
    return doc.shadowed(out, 0, 4, 5, 35)


# id: Name, Funktion, erlaubte Halsausschnitte, Gewicht m, Gewicht f
NECKS = {
    "kopfhoerer": ("Kopfhörer", n_kopfhoerer, {"hood", "rib", "open", "collar_open", "stand", "high"}, 4, 3),
    "hundemarken": ("Hundemarken", n_hundemarken, {"open", "collar_open"}, 3, 1),
    "kette": ("Goldkette", n_kette, {"open", "collar_open", "v"}, 3, 2),
    "schal": ("Schal", n_schal, {"open", "collar_open", "rib", "stand"}, 2, 3),
    "choker": ("Halsband", n_choker, {"open", "v", "collar_open"}, 0, 4),
    "handtuch": ("Handtuch", n_handtuch, {"open", "collar_open", "stand"}, 2, 1),
}

# ---------------------------------------------------------------------------
# Crew-Abzeichen und Rang
# ---------------------------------------------------------------------------
EMBLEMS = {
    "stern": "M0,-8 L2.4,-2.5 8,-2.5 3.5,1 5,7 0,3.5 -5,7 -3.5,1 -8,-2.5 -2.4,-2.5 Z",
    "blitz": "M2,-9 L-5,1 H-0.5 L-2,9 L5,-1 H0.5 Z",
    "flamme": "M0,-9 C4,-4 7,-1 6,3 C5,7 2,9 0,9 C-2,9 -5,7 -6,3 C-7,-1 -3,-3 -2,-6 C-1,-3 0,-2 1,-2 C2,-4 1,-6 0,-9 Z",
    "kreis": "M0,-8 A8,8 0 1 1 -0.01,-8 Z M0,-4 A4,4 0 1 0 0.01,-4 Z",
    "raute": "M0,-9 L7,0 L0,9 L-7,0 Z",
    "fluegel": "M-9,2 C-6,-6 -2,-6 0,-1 C2,-6 6,-6 9,2 C5,0 2,1 0,4 C-2,1 -5,0 -9,2 Z",
}


def mark(x, y, kind, A, emblem, k=1.0):
    """Crew-Abzeichen je nach Art des Platzes."""
    x = CX + (x - CX) * k
    e = EMBLEMS.get(emblem, EMBLEMS["stern"])
    if kind == "patch":
        return (f'<circle cx="{f(x)}" cy="{y}" r="22" fill="#0b0d11" stroke="{A}" stroke-width="3"/>'
                f'<path d="{e}" transform="translate({f(x)} {y}) scale(1.8)" fill="{A}" fill-rule="evenodd"/>'
                + stitch(f"M{f(x - 18)},{y} a18,18 0 1 1 36,0 a18,18 0 1 1 -36,0", A, .5, 1))
    if kind == "pin":
        return (f'<circle cx="{f(x)}" cy="{y}" r="10" fill="#e8c35a" stroke="#6b4c0c" stroke-width="1.2"/>'
                f'<circle cx="{f(x)}" cy="{y}" r="7.5" fill="{A}"/>'
                f'<path d="{e}" transform="translate({f(x)} {y}) scale(.7)" fill="#fff" fill-rule="evenodd"/>'
                f'<circle cx="{f(x - 3)}" cy="{y - 4}" r="2" fill="#fff" fill-opacity=".6"/>')
    if kind == "print":
        return (f'<circle cx="{f(x)}" cy="{y}" r="44" fill="none" stroke="{A}" stroke-width="4" stroke-opacity=".9"/>'
                f'<path d="{e}" transform="translate({f(x)} {y}) scale(4)" fill="{A}" fill-opacity=".92" fill-rule="evenodd"/>')
    if kind == "stick":
        return (f'<path d="{e}" transform="translate({f(x)} {y}) scale(3.4)" fill="{A}" stroke="#e8c35a" stroke-width=".5" fill-rule="evenodd"/>')
    return ""


def rank_mark(x, y, kind, A, k=1.0):
    x = CX + (x - CX) * k
    chev = f"M{f(x - 13)},{y + 2} l13,-9 l13,9 v6 l-13,-9 l-13,9 z M{f(x - 13)},{y + 12} l13,-9 l13,9 v6 l-13,-9 l-13,9 z"
    if kind == "patch":
        return (f'<rect x="{f(x - 20)}" y="{y - 16}" width="40" height="36" rx="5" fill="#0b0d11" stroke="{A}" stroke-width="2"/>'
                f'<path d="{chev}" transform="translate(0 -3)" fill="{A}"/>' + stitch(f"M{f(x - 17)},{y - 13} h34 v30 h-34 z", A, .45, 1))
    if kind == "pin":
        return (f'<path d="M{f(x - 9)},{y + 1} l9,-6 l9,6 v4 l-9,-6 l-9,6 z M{f(x - 9)},{y + 8} l9,-6 l9,6 v4 l-9,-6 l-9,6 z" fill="#e8c35a" stroke="#6b4c0c" stroke-width=".8"/>')
    if kind == "print":
        return f'<path d="{chev}" fill="{A}" fill-opacity=".9"/>'
    if kind == "stick":
        return f'<path d="{chev}" fill="#e8c35a" stroke="#000" stroke-opacity=".3" stroke-width=".6"/>'
    return ""
