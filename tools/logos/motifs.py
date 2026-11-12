"""Motive der 26 Crews. Jede Funktion bekommt Mitte (cx, cy) und Größe s (~ halbe Motivbreite in px)
und gibt eine Liste (pfad, rolle) zurück. Rollen: c = Teamfarbe, w = Weiß, d = Grundfarbe (dunkel),
k = Kanji/Textfarbe (Teamfarbe). Alles eigene Formen, keine Vorlagen aus anderen Spielen."""
import math
from shapes import (f, poly, circle, ring, ellipse, rrect, ngon, star, shield, drop, heart, banner, bolt,
                    sparkle, wing, rays)
import textpath as tp


def P(cx, cy, s, pts):
    return poly([(cx + x * s, cy + y * s) for x, y in pts])


def lantern(cx, cy, s):
    o = [(rrect(cx - .42 * s, cy - .98 * s, .84 * s, .16 * s, .04 * s), "c"),
         (rrect(cx - .42 * s, cy + .82 * s, .84 * s, .16 * s, .04 * s), "c"),
         (ellipse(cx, cy, .72 * s, .86 * s), "c")]
    for i in range(-3, 4):
        y = cy + i * .22 * s
        hw = .72 * s * math.sqrt(max(0, 1 - (i * .22 / .86) ** 2))
        o.append((rrect(cx - hw + 4, y - 2.5, 2 * hw - 8, 5, 2.5), "d"))
    o.append((tp.line("灯", "jp", .62 * s, cx, cy), "w"))
    o.append((rrect(cx - .06 * s, cy - 1.2 * s, .12 * s, .24 * s, 3), "c"))
    return o


def necktie(cx, cy, s):
    o = []
    for i, w in enumerate([.9, .7, .5]):
        y = cy - .35 * s + i * .35 * s
        o.append((rrect(cx - 1.25 * s, y - 5, w * s, 10, 5), "w"))
    tie = P(cx + .25 * s, cy, s, [(-.14, -.95), (.14, -.95), (.2, -.78), (.07, -.62), (.32, .55), (0, .95),
                                     (-.32, .55), (-.07, -.62), (-.2, -.78)])
    o.append((tie, "c"))
    o.append((P(cx + .25 * s, cy, s, [(-.07, -.62), (.07, -.62), (.22, .1), (-.13, -.28)]), "d"))
    return o


def chrome_wings(cx, cy, s):
    o = [(wing(cx + .3 * s, cy - .08 * s, .95 * s, 1), "c"), (wing(cx - .3 * s, cy - .08 * s, .95 * s, -1), "c"),
         (circle(cx, cy, .42 * s), "w"), (circle(cx, cy, .34 * s), "d"),
         (tp.line("昭", "jp", .48 * s, cx, cy), "c")]
    return o


def six_petals(cx, cy, s):
    o = []
    for i in range(6):
        a = math.radians(-90 + i * 60)
        px, py = cx + math.cos(a) * .52 * s, cy + math.sin(a) * .52 * s
        rot = i * 60
        o.append((f'M{f(px)} {f(py - .42 * s)} ' if False else ellipse_rot(px, py, .22 * s, .44 * s, rot), "c"))
    o.append((circle(cx, cy, .26 * s), "w"))
    o.append((heart(cx, cy - .02 * s, .17 * s), "c"))
    return o


def ellipse_rot(cx, cy, rx, ry, rot):
    pts = []
    for i in range(36):
        t = 2 * math.pi * i / 36
        x, y = rx * math.cos(t), ry * math.sin(t)
        a = math.radians(rot)
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return poly(pts)


def mountain(cx, cy, s):
    o = [(P(cx, cy, s, [(-1.05, .7), (-.35, -.55), (-.05, -.08), (.3, -.85), (1.05, .7)]), "c"),
         (P(cx, cy, s, [(.3, -.85), (.47, -.55), (.36, -.46), (.28, -.6), (.17, -.44), (.08, -.6)]), "w"),
         (P(cx, cy, s, [(-.35, -.55), (-.22, -.33), (-.31, -.27), (-.38, -.38), (-.47, -.32)]), "w"),
         (tp.line("山", "jp", .6 * s, cx, cy + .3 * s), "d")]
    return o


def two_hundred(cx, cy, s):
    o = [(rrect(cx - 1.0 * s, cy - .78 * s, .62 * s, .2 * s, 4), "c"),
         (rrect(cx + .38 * s, cy - .78 * s, .62 * s, .2 * s, 4), "c"),
         (tp.line("200", "latin", 1.0 * s, cx, cy + .12 * s, track=-.02 * s, sx=.92, maxw=2.0 * s), "w"),
         (rrect(cx - 1.0 * s, cy + .62 * s, 2.0 * s, .1 * s, 4), "c")]
    return o


def neon_sign(cx, cy, s):
    t = tp.line("NEON", "latin", .62 * s, cx, cy + .02 * s, track=.04 * s, maxw=1.9 * s)
    return [(t, "glow"), (t, "w"),
            (star(cx + .82 * s, cy - .62 * s, .2 * s, .08 * s), "c"),
            (star(cx - .86 * s, cy + .62 * s, .13 * s, .05 * s), "c"),
            (rrect(cx - 1.0 * s, cy - .5 * s, 2.0 * s, 1.0 * s, .2 * s) + " " + rrect(cx - .93 * s, cy - .43 * s, 1.86 * s, .86 * s, .15 * s), "c")]


def wagon(cx, cy, s):
    body = P(cx, cy, s, [(-1.05, .28), (-1.05, -.05), (-.9, -.12), (-.62, -.52), (.55, -.52), (.62, -.12),
                          (1.02, -.04), (1.05, .28)])
    o = [(body, "c"),
         (P(cx, cy, s, [(-.55, -.14), (-.38, -.42), (-.04, -.42), (-.04, -.14)]), "d"),
         (P(cx, cy, s, [(.04, -.14), (.04, -.42), (.47, -.42), (.5, -.14)]), "d"),
         (circle(cx - .58 * s, cy + .3 * s, .23 * s), "d"), (circle(cx - .58 * s, cy + .3 * s, .15 * s), "w"),
         (circle(cx + .6 * s, cy + .3 * s, .23 * s), "d"), (circle(cx + .6 * s, cy + .3 * s, .15 * s), "w"),
         (rrect(cx - .62 * s, cy - .7 * s, 1.1 * s, .08 * s, 3), "w"),
         (heart(cx + .02 * s, cy + .78 * s, .16 * s), "w")]
    return o


def fox(cx, cy, s):
    o = [(P(cx, cy, s, [(-.95, -.85), (-.35, -.42), (.35, -.42), (.95, -.85), (.78, .02), (0, .92), (-.78, .02)]), "c"),
         (P(cx, cy, s, [(-.78, -.62), (-.45, -.38), (-.62, -.2)]), "d"),
         (P(cx, cy, s, [(.78, -.62), (.45, -.38), (.62, -.2)]), "d"),
         (P(cx, cy, s, [(-.78, .02), (-.2, .12), (0, .92)]), "w"),
         (P(cx, cy, s, [(.78, .02), (.2, .12), (0, .92)]), "w"),
         (P(cx, cy, s, [(-.52, -.12), (-.2, -.04), (-.46, .02)]), "d"),
         (P(cx, cy, s, [(.52, -.12), (.2, -.04), (.46, .02)]), "d"),
         (P(cx, cy, s, [(-.1, .7), (.1, .7), (0, .86)]), "d")]
    return o


def rocket(cx, cy, s):
    a = -35
    def R(pts):
        out = []
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        for x, y in pts:
            out.append((cx + (x * ca - y * sa) * s, cy + (x * sa + y * ca) * s))
        return poly(out)
    body = [(0, -1.0), (.2, -.72), (.26, -.3), (.26, .45), (-.26, .45), (-.26, -.3), (-.2, -.72)]
    return [(R([(.26, .05), (.5, .4), (.5, .62), (.26, .45)]), "c"), (R([(-.26, .05), (-.5, .4), (-.5, .62), (-.26, .45)]), "c"),
            (R([(-.17, .48), (.17, .48), (0, 1.0)]), "c"),
            (R([(-.1, .48), (.1, .48), (0, .78)]), "w"),
            (R(body), "w"),
            (R([(0, -1.0), (.2, -.72), (-.2, -.72)]), "c"),
            (circle(cx + (0 * math.cos(math.radians(a)) - (-.28) * math.sin(math.radians(a))) * s,
                    cy + (0 * math.sin(math.radians(a)) + (-.28) * math.cos(math.radians(a))) * s, .12 * s), "c")]


def shooting_star(cx, cy, s):
    o = []
    for i, (w, l) in enumerate([(.12, 1.25), (.08, 1.0), (.05, .75)]):
        dy = (i - 1) * .2
        o.append((P(cx, cy, s, [(.25, -.35 + dy - w), (-1.0 + (1.25 - l), .55 + dy), (.35, -.25 + dy + w)]), "c"))
    o.append((star(cx + .35 * s, cy - .35 * s, .55 * s, .22 * s), "w"))
    for x, y, r in [(-.8, -.6, .06), (-.45, -.85, .04), (.85, .45, .05), (.6, .8, .035), (-.2, .85, .03)]:
        o.append((star(cx + x * s, cy + y * s, r * 2 * s, r * .8 * s, 4), "w"))
    return o


def closed_eye(cx, cy, s):
    lid = (f"M{f(cx - 1.0 * s)} {f(cy - .05 * s)} Q{f(cx)} {f(cy + .62 * s)} {f(cx + 1.0 * s)} {f(cy - .05 * s)} "
           f"Q{f(cx)} {f(cy + .42 * s)} {f(cx - 1.0 * s)} {f(cy - .05 * s)} Z")
    o = [(lid, "w")]
    for i in range(5):
        t = (i + 1) / 6
        x = cx + (-1 + 2 * t) * s
        y = cy - .05 * s + (1 - (2 * t - 1) ** 2) * .27 * s + .14 * s
        ang = (t - .5) * 50
        dx, dy = math.sin(math.radians(ang)) * .3 * s, math.cos(math.radians(ang)) * .3 * s
        o.append((P(0, 0, 1, [(x - 4, y), (x + 4, y), (x + dx + 2, y + dy), (x + dx - 2, y + dy)]), "w"))
    o.append((tp.line("Zz", "latin", .42 * s, cx + .55 * s, cy - .6 * s, track=.02 * s), "c"))
    o.append((rrect(cx - 1.0 * s, cy - .38 * s, .7 * s, .1 * s, 4), "c"))
    return o


def mist(cx, cy, s):
    """Drei Nebelwellen (Sinus), mittlere weiß, dazu 霞."""
    o = []
    for i, (y, x0, x1, ph) in enumerate([(-.55, -1.0, .75, 0), (-.05, -.8, 1.0, 1.4), (.45, -1.0, .6, 2.6)]):
        top, bot = [], []
        n = 40
        for k in range(n + 1):
            t = k / n
            x = x0 + (x1 - x0) * t
            yy = y + math.sin(t * 2 * math.pi * 1.2 + ph) * .09
            w = .075 * (1 - abs(2 * t - 1) ** 3) + .01
            top.append((cx + x * s, cy + (yy - w) * s))
            bot.append((cx + x * s, cy + (yy + w) * s))
        o.append((poly(top + bot[::-1]), "w" if i == 1 else "c"))
    return o


def wind_hex(cx, cy, s):
    o = [(tp.line("風", "jp", 1.15 * s, cx, cy + .02 * s), "w")]
    for i, (y, l) in enumerate([(-.62, .9), (.62, .9)]):
        o.append((rrect(cx - l * s, cy + y * s - 4, 2 * l * s, 8, 4), "c"))
    return o


def blood_drop(cx, cy, s):
    return [(drop(cx, cy + .25 * s, .62 * s), "c"),
            (ellipse_rot(cx - .25 * s, cy + .1 * s, .09 * s, .2 * s, 25), "w"),
            (tp.line("H", "latin", .72 * s, cx + .03 * s, cy + .36 * s), "d")]


def patrol_star(cx, cy, s):
    return [(ring(cx, cy, .98 * s, .84 * s), "c"),
            (star(cx, cy - .02 * s, .78 * s, .32 * s), "w"),
            (tp.line("16", "latin", .5 * s, cx, cy + .05 * s, track=-.01 * s), "d")]


def iron(cx, cy, s):
    return [(tp.line("鉄", "jp", 1.55 * s, cx, cy + .03 * s), "w"),
            (rrect(cx - 1.0 * s, cy + .9 * s, 2.0 * s, 6, 3), "c")]


def forty_eight(cx, cy, s):
    o = [(P(cx, cy, s, [(-1.05, -.15), (1.05, -.55), (1.05, -.35), (-1.05, .05)]), "c"),
         (P(cx, cy, s, [(-1.05, .2), (1.05, -.2), (1.05, 0), (-1.05, .4)]), "c"),
         (tp.line("48", "latin", 1.25 * s, cx, cy + .02 * s, track=-.04 * s, sx=1.0), "stroke"),
         (tp.line("48", "latin", 1.25 * s, cx, cy + .02 * s, track=-.04 * s, sx=1.0), "w")]
    return o


def thunder(cx, cy, s):
    o = [(ring(cx, cy, .98 * s, .8 * s), "c")]
    for i in range(12):
        a = math.radians(i * 30)
        o.append((circle(cx + math.cos(a) * .89 * s, cy + math.sin(a) * .89 * s, .055 * s), "d"))
    o.append((bolt(cx, cy, .68 * s), "w"))
    return o


def pistons(cx, cy, s):
    def piston(a):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        def R(pts):
            return poly([(cx + (x * ca - y * sa) * s, cy + (x * sa + y * ca) * s) for x, y in pts])
        rod = R([(-.07, -.4), (.07, -.4), (.07, .8), (-.07, .8)])
        head = R([(-.3, -1.0), (.3, -1.0), (.3, -.4), (-.3, -.4)])
        grooves = R([(-.3, -.88), (.3, -.88), (.3, -.83), (-.3, -.83)]) + " " + R([(-.3, -.76), (.3, -.76), (.3, -.71), (-.3, -.71)])
        eye = R([(-.16, .72), (.16, .72), (.16, .98), (-.16, .98)])
        return [(rod, "w"), (head, "w"), (grooves, "d"), (eye, "w")]
    return piston(-32) + piston(32) + [(circle(cx, cy + .05 * s, .16 * s), "c")]


def eighty_one(cx, cy, s):
    o = []
    for i, col in enumerate(["w", "c", "w"]):
        x = cx + (-.42 + i * .28) * s
        o.append((P(0, 0, 1, [(x, cy - 1.0 * s), (x + .22 * s, cy - 1.0 * s), (x + .22 * s - .5 * s, cy + 1.0 * s), (x - .5 * s, cy + 1.0 * s)]), col))
    o.append((tp.line("81", "latin", 1.05 * s, cx + .1 * s, cy + .02 * s, track=-.03 * s), "stroke"))
    o.append((tp.line("81", "latin", 1.05 * s, cx + .1 * s, cy + .02 * s, track=-.03 * s), "w"))
    return o


def ring_road(cx, cy, s):
    o = [(ring(cx, cy, .95 * s, .7 * s), "c")]
    # Pfeil auf dem Ring (Uhrzeigersinn)
    a = math.radians(-20)
    px, py = cx + math.cos(a) * .825 * s, cy + math.sin(a) * .825 * s
    tx, ty = -math.sin(a), math.cos(a)
    nx, ny = math.cos(a), math.sin(a)
    o.append((poly([(px + nx * .26 * s, py + ny * .26 * s), (px - nx * .26 * s, py - ny * .26 * s), (px + tx * .34 * s, py + ty * .34 * s)]), "w"))
    o.append((P(cx, cy, s, [(-.72, .02), (.72, .02), (.72, .06), (-.72, .06)]), "d"))
    o.append((tp.line("PT", "latin", .7 * s, cx, cy, track=.02 * s), "w"))
    return o


def dawn(cx, cy, s):
    sun = (f"M{f(cx - .62 * s)} {f(cy + .2 * s)} A{f(.62 * s)} {f(.62 * s)} 0 0 1 {f(cx + .62 * s)} {f(cy + .2 * s)} Z")
    o = [(sun, "c")]
    for i, (y, w) in enumerate([(.34, 1.0), (.52, .78), (.7, .56)]):
        o.append((rrect(cx - w * s, cy + y * s - 5, 2 * w * s, 10, 5), "w"))
    o.append((rrect(cx - 1.0 * s, cy + .18 * s, 2.0 * s, 8, 4), "w"))
    return o


def woodpecker(cx, cy, s):
    head = (f"M{f(cx - .55 * s)} {f(cy + .9 * s)} C{f(cx - .75 * s)} {f(cy + .2 * s)} {f(cx - .6 * s)} {f(cy - .6 * s)} {f(cx - .05 * s)} {f(cy - .75 * s)} "
            f"C{f(cx + .3 * s)} {f(cy - .82 * s)} {f(cx + .45 * s)} {f(cy - .55 * s)} {f(cx + .42 * s)} {f(cy - .3 * s)} "
            f"L{f(cx + 1.05 * s)} {f(cy - .12 * s)} L{f(cx + .38 * s)} {f(cy + .02 * s)} "
            f"C{f(cx + .2 * s)} {f(cy + .3 * s)} {f(cx + .1 * s)} {f(cy + .6 * s)} {f(cx + .15 * s)} {f(cy + .9 * s)} Z")
    crest = (f"M{f(cx - .5 * s)} {f(cy - .45 * s)} C{f(cx - .45 * s)} {f(cy - .95 * s)} {f(cx - .05 * s)} {f(cy - 1.05 * s)} {f(cx + .25 * s)} {f(cy - .78 * s)} "
             f"C{f(cx)} {f(cy - .72 * s)} {f(cx - .3 * s)} {f(cy - .6 * s)} {f(cx - .5 * s)} {f(cy - .45 * s)} Z")
    return [(head, "w"), (crest, "c"), (circle(cx + .1 * s, cy - .4 * s, .1 * s), "d"),
            (P(cx, cy, s, [(-.62, .1), (.12, .25), (.08, .4), (-.6, .3)]), "c")]


def fortress(cx, cy, s):
    pts = [(-.9, .85), (-.9, -.45), (-.9, -.7), (-.62, -.7), (-.62, -.5), (-.42, -.5), (-.42, -.7), (-.14, -.7), (-.14, -.5),
           (.14, -.5), (.14, -.7), (.42, -.7), (.42, -.5), (.62, -.5), (.62, -.7), (.9, -.7), (.9, .85)]
    gate = (f"M{f(cx - .26 * s)} {f(cy + .85 * s)} V{f(cy + .2 * s)} A{f(.26 * s)} {f(.26 * s)} 0 0 1 {f(cx + .26 * s)} {f(cy + .2 * s)} V{f(cy + .85 * s)} Z")
    o = [(P(cx, cy, s, pts), "c"), (gate, "d")]
    for x in (-.55, 0, .55):
        o.append((star(cx + x * s, cy - .18 * s, .14 * s, .06 * s), "w"))
    return o


def spark(cx, cy, s):
    return [(sparkle(cx, cy, 1.0 * s, .18), "c"), (sparkle(cx, cy, .55 * s, .2), "w"),
            (sparkle(cx + .72 * s, cy - .62 * s, .26 * s, .2), "w"), (sparkle(cx - .7 * s, cy + .66 * s, .18 * s, .2), "c")]


MOTIFS = {
    "lantern": lantern, "necktie": necktie, "chrome_wings": chrome_wings, "six_petals": six_petals,
    "mountain": mountain, "two_hundred": two_hundred, "neon_sign": neon_sign, "wagon": wagon, "fox": fox,
    "rocket": rocket, "shooting_star": shooting_star, "closed_eye": closed_eye, "mist": mist, "wind_hex": wind_hex,
    "blood_drop": blood_drop, "patrol_star": patrol_star, "iron": iron, "forty_eight": forty_eight,
    "thunder": thunder, "pistons": pistons, "eighty_one": eighty_one, "ring_road": ring_road, "dawn": dawn,
    "woodpecker": woodpecker, "fortress": fortress, "spark": spark,
}
