"""Hashiriya Battle: Team-Logos, Wanderer-Siegel und Boss-Embleme als SVG.

Aufruf:  python tools/logos/build_logos.py            -> art/logos/*.svg
         python tools/logos/build_logos.py --png      -> zusätzlich PNG-Vorschau (braucht cairosvg)
         python tools/logos/build_logos.py --sheet    -> Übersichtsbild tools/logos/uebersicht.png

Jedes Logo hat oberste Gruppen (= Ebenen in VectorCraft): schnitt, grund, rahmen, motiv, schrift.
Text ist bereits in Pfade umgewandelt, im Spiel wird keine Schrift gebraucht.
Eigene Entwürfe, im Stil von Vinyl-Aufklebern; keine Logos aus anderen Spielen nachgebaut.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import textpath as tp  # noqa: E402
from shapes import (f, poly, circle, ring, rrect, ngon, star, shield, drop, heart, banner)  # noqa: E402
from motifs import MOTIFS  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RIVALS = os.path.join(ROOT, "lua", "ge", "extensions", "hashiriyaBattle", "data", "rivals.json")
OUT = os.path.join(ROOT, "art", "logos")

DARK = "#15181d"
DARK2 = "#0b0d10"
WHITE = "#f1f3f5"
GOLD = "#ffcc4d"
CUT = "#f4f5f7"   # weißer Aufkleber-Rand

# ---------------------------------------------------------------------------------------------
# Crews: Form, Motiv, Kurzname auf dem Logo (Großbuchstaben)
TEAMS = {
    "t_lantern":    ("seal",    "lantern",       "MAYONAKA LANTERNS"),
    "t_zangyo":     ("ticket",  "necktie",       "ZANGYO EXPRESS"),
    "t_showa":      ("oval",    "chrome_wings",  "SHOWA RETRO CLUB"),
    "t_diana":      ("seal",    "six_petals",    "DIANA SISTERS"),
    "t_yamagumi":   ("shield",  "mountain",      "YAMA-GUMI"),
    "t_bxboys":     ("plate",   "two_hundred",   "NIHYAKU BOYS"),
    "t_neon":       ("ticket",  "neon_sign",     "GINZA NEON CLUB"),
    "t_kombi":      ("seal",    "wagon",         "KOMBI PAPAS"),
    "t_kitsune":    ("diamond", "fox",           "KOSOKU KITSUNE"),
    "t_pocket":     ("seal",    "rocket",        "POCKET ROCKETS"),
    "t_hoshikuzu":  ("shield",  "shooting_star", "HOSHIKUZU RALLY"),
    "t_sleeper":    ("plate",   "closed_eye",    "SLEEPER AGENTS"),
    "t_kasumi":     ("seal",    "mist",          "KASUMI DRIFT UNION"),
    "t_etkklassik": ("hex",     "wind_hex",      "BAYERN KAZE"),
    "t_sbr":        ("shield",  "blood_drop",    "HIROCHI BLOOD"),
    "t_yokota":     ("plate",   "patrol_star",   "NIGHT PATROL"),
    "t_kurogane":   ("oct",     "iron",          "KUROGANE-KAI"),
    "t_muscle73":   ("shield",  "forty_eight",   "SHOWA 48 MUSCLE"),
    "t_raijin":     ("seal",    "thunder",       "RAIJIN GARAGE"),
    "t_hotrod":     ("banner",  "pistons",       "KOENJI GREASERS"),
    "t_bolide":     ("shield",  "eighty_one",    "ROSSO 81"),
    "t_vivace":     ("seal",    "ring_road",     "PERIPH TOKYO"),
    "t_akatsuki":   ("hex",     "dawn",          "AKATSUKI RACING"),
    "t_etkmodern":  ("seal",    "woodpecker",    "RENNSPECHT KAI"),
    "t_bastion":    ("shield",  "fortress",      "BASTION"),
    "t_scintilla":  ("diamond", "spark",         "SCINTILLA"),
}

# Wanderer: Siegel mit eigenem Zeichen (Kanji, selten lateinisch) und eigener Farbe
WANDERERS = {
    "w_ojisan": ("叔父", "#d9a066"), "w_rodeo": ("牛", "#c8813c"), "w_kemuri": ("煙", "#b0bec5"),
    "w_rentner": ("船", "#4f9fd9"), "w_shinkiro": ("蜃", "#80deea"), "w_rallye": ("鼠", "#5c8cf0"),
    "w_dtm": ("豪", "#e0c060"), "w_noir": ("猫", "#9e9e9e"), "w_tetsujin": ("鉄人", "#ff8a50"),
    "w_slider": ("滑", "#ff6f91"), "w_hotaru": ("蛍", "#c6ff60"), "w_kazekiri": ("風切", "#7fe0c8"),
    "w_pastor": ("祈", "#f0d890"), "w_oval": ("左", "#ff5a4f"), "w_marshal": ("保安", "#d4b25c"),
    "w_fink": ("広告", "#ff9f40"), "w_tsukiyomi": ("月", "#cfd8ff"), "w_nurburg": ("緑", "#54c46a"),
    "w_yurei": ("霊", "#a7f3ff"), "w_erbstueck": ("宝", "#e8c25a"), "w_noodle": ("麺", "#ffcf70"),
    "w_gruppe5": ("影", "#ef6c50"), "w_hakone": ("峠", "#8cc070"), "w_tasti": ("糖", "#ff5f7a"),
    "w_mont": ("頂", "#ffffff"), "w_kemuri2": ("霧", "#9fb6c8"), "w_fukurou": ("梟", "#8d7cff"),
    "w_corsa": ("疾", "#ff4040"), "w_benikaze": ("紅風", "#ff3030"), "w_tractor": ("農", "#a3c94f"),
    "w_viper": ("蛇", "#9ccc3d"), "w_wheelie": ("跳", "#ff8fd8"), "w_bigblock": ("轟", "#ff7a30"),
    "w_familie": ("家", "#c0c8d0"), "w_kofun": ("墳", "#c6a46c"), "w_doc": ("歯", "#e0f4ff"),
    "w_hellcat": ("嵐", "#b070ff"), "w_dragvan": ("便", "#ffd040"), "w_bakuon": ("爆音", "#ff5a28"),
    "w_nitro": ("炎", "#ff6a1a"), "w_afterburner": ("噴", "#6fb8ff"), "w_kaminari": ("閃", "#fff27a"),
    "w_henry": ("粋", "#ff9ad5"), "w_alex_zockt": ("LXZ", "#ffcc4d"),
}

# Bosse: eigene, größere Embleme
BOSSES = {
    "b_shirotora": ("白虎", "SHIROTORA", "#e9f2ff", "#6ec3ff", "claws"),
    "b_kokuryu":   ("黒龍", "KOKURYU",   "#ff3b4e", "#2a2d33", "scales"),
    "b_mugen":     ("無限", "MUGEN",     "#ffcc4d", "#a07a20", "infinity"),
}


def fit_doc(svg, box=476):
    """Inhalt automatisch mittig einpassen (nur Symbole): misst die sichtbare Fläche per cairosvg."""
    try:
        import cairosvg, io
        from PIL import Image
    except ImportError:
        return svg
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=512, output_height=512)))
    bb = im.getchannel("A").getbbox()
    if not bb:
        return svg
    x0, y0, x1, y1 = bb
    k = min(box / (x1 - x0), box / (y1 - y0))
    tx = 256 - k * (x0 + x1) / 2
    ty = 256 - k * (y0 + y1) / 2
    head, rest = svg.split("</defs>", 1)
    body, tail = rest.rsplit("</svg>", 1)
    return f'{head}</defs><g transform="translate({f(tx)} {f(ty)}) scale({k:.4f})">{body}</g></svg>{tail}'


def doc(layers, defs=""):
    body = "".join(f'<g id="{n}">{c}</g>' for n, c in layers if c)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">'
            f'<defs>{defs}</defs>{body}</svg>\n')


def p(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}"{extra}/>' if d else ""


def stroked(d, color, w, fill="none"):
    return f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{f(w)}" stroke-linejoin="round"/>'


def shape_path(kind):
    c = 256
    if kind == "seal":
        return circle(c, c, 236)
    if kind == "shield":
        return shield(c, c + 6, 420, 470)
    if kind == "diamond":
        return poly([(c, 14), (498, c), (c, 498), (14, c)])
    if kind == "hex":
        return ngon(c, c, 246, 6, -90)
    if kind == "oct":
        return ngon(c, c, 246, 8, -67.5)
    if kind == "plate":
        return rrect(22, 92, 468, 328, 34)
    if kind == "ticket":
        return rrect(16, 112, 480, 288, 144)
    if kind == "oval":
        return f"M20 256 A236 168 0 1 0 492 256 A236 168 0 1 0 20 256 Z"
    if kind == "banner":
        return banner(c, c, 490, 330, .1)
    raise KeyError(kind)


def scaled(d_fn_kind, k):
    """Form verkleinert um die Mitte (für den Innenrahmen)."""
    return f'<g transform="translate(256 256) scale({k}) translate(-256 -256)">'


def layout(kind):
    """Motiv-Mitte, Motivgröße, Namensband (y, Breite, Höhe), Kanji-Zeile y oder None."""
    return {
        "seal":    dict(m=(256, 250, 92)),
        "shield":  dict(m=(256, 186, 100), band=(338, 400, 60), jp=398, jps=24, jpw=230),
        "diamond": dict(m=(256, 196, 92), band=(322, 330, 52), jp=376, jps=20, jpw=150),
        "hex":     dict(m=(256, 192, 100), band=(332, 430, 60), jp=398, jps=26),
        "oct":     dict(m=(256, 200, 100), band=(346, 420, 60), jp=418),
        "plate":   dict(m=(256, 222, 92), band=(366, 420, 50), jp=None, jp_top=134),
        "ticket":  dict(m=(256, 240, 66), band=(346, 360, 46), jp=None, jp_top=160),
        "oval":    dict(m=(256, 236, 100), band=(346, 300, 44), jp=None, jp_top=146),
        "banner":  dict(m=(256, 222, 92), band=(346, 340, 50), jp=None, jp_top=132),
    }[kind]


def render_motif(name, cx, cy, s, color):
    parts = MOTIFS[name](cx, cy, s)
    out = []
    for d, role in parts:
        if role == "glow":
            out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="10" stroke-linejoin="round" opacity=".55"/>')
        elif role == "stroke":
            out.append(f'<path d="{d}" fill="none" stroke="{DARK2}" stroke-width="14" stroke-linejoin="round"/>')
        else:
            out.append(p(d, {"c": color, "w": WHITE, "d": DARK, "k": color}[role], ' fill-rule="evenodd"' if role == "c" else ""))
    return "".join(out)


def motif_paths(name, cx, cy, s, color):
    """Motivteile als (pfad, füllung, zusatz) für den freigestellten Stil."""
    out = []
    for d, role in MOTIFS[name](cx, cy, s):
        if role == "glow":
            out.append((d, None, f' fill="none" stroke="{color}" stroke-width="10" stroke-linejoin="round" opacity=".55"'))
        elif role == "stroke":
            out.append((d, None, f' fill="none" stroke="{DARK2}" stroke-width="12" stroke-linejoin="round"'))
        else:
            out.append((d, {"c": color, "w": WHITE, "d": DARK, "k": color}[role], ' fill-rule="evenodd"' if role == "c" else ""))
    return out


def team_logo(team, leader=False, icon=False):
    """Freigestellt (Alex 2026-11-03): keine Grundform, nur das Objekt und der Schriftzug,
    mit Aufkleber-Schnittkante (weiß, Leader gold) und dunkler Kontur, damit es auf jedem Hintergrund steht."""
    kind, motif, short = TEAMS[team["id"]]
    col = team["color"]
    cutc = GOLD if leader else CUT
    if icon:
        # Symbol ohne Schrift für kleine Anzeigen (HUD, Sprechblase): Motiv groß, dickere Schnittkante
        parts = motif_paths(motif, 256, 262, 196, col)
        shapes_all = [(d, 34, 16) for d, fill, _ in parts if fill is not None]
        name = jp = ""
    else:
        parts = motif_paths(motif, 256, 196, 138, col)
        name = tp.line(short, "latin", 48, 256, 404, track=4, maxw=470)
        jp = tp.line(team["jp"], "jp", 30, 256, 458, track=4, maxw=330)
        shapes_all = [(d, 26, 12) for d, fill, _ in parts if fill is not None] + [(name, 15, 7), (jp, 11, 5)]
    if leader:
        shapes_all.append((star(456, 48, 22, 9), 20, 9))
    cut = "".join(stroked(d, cutc, w1, cutc) for d, w1, w2 in shapes_all)
    edge = "".join(stroked(d, DARK2, w2, DARK2) for d, w1, w2 in shapes_all)
    layers = [("schnitt", cut), ("grund", edge)]
    layers.append(("motiv", "".join(f'<path d="{d}"' + (f' fill="{fill}"' if fill else "") + f'{x}/>' for d, fill, x in parts)))
    txt = (p(name, WHITE) + p(jp, col)) if name else ""
    if leader:
        txt += p(star(456, 48, 22, 9), GOLD)
    layers.append(("schrift", txt))
    return fit_doc(doc(layers)) if icon else doc(layers)


def wanderer_logo(r):
    sign, col = WANDERERS[r["id"]]
    layers = []
    outer = circle(256, 256, 232)
    layers.append(("schnitt", stroked(outer, DARK2, 30, DARK2) + stroked(outer, CUT, 18, CUT)))
    layers.append(("grund", p(outer, DARK) + p(ring(256, 256, 232, 220), col, ' fill-rule="evenodd"')))
    # Innenring mit gestrichelter Linie (Wanderer = keine Crew, eigener Stempel)
    layers.append(("rahmen", stroked(circle(256, 256, 166), col, 4) +
                   f'<path d="{circle(256, 256, 152)}" fill="none" stroke="{col}" stroke-width="2" stroke-dasharray="4 7" opacity=".7"/>'))
    # Mitte: Zeichen im Stempel-Stil (Quadrat leicht gedreht)
    seal = rrect(256 - 104, 256 - 104, 208, 208, 14)
    mot = f'<g transform="rotate(-4 256 256)">{p(seal, col)}'
    if all(ord(ch) < 0x300 for ch in sign):
        mot += p(tp.line(sign, "latin", 92, 256, 256, track=-2, maxw=180), DARK2)
    elif len(sign) == 1:
        mot += p(tp.line(sign, "jp", 168, 256, 250), DARK2)
    else:
        # zwei Zeichen untereinander, wie auf einem Hanko
        mot += p(tp.line(sign[0], "jp", 92, 256, 206), DARK2) + p(tp.line(sign[1], "jp", 92, 256, 304), DARK2)
    mot += "</g>"
    layers.append(("motiv", mot))
    name = r["name"].upper().replace("Ō", "O").replace("Ū", "U").replace("Ä", "AE").replace("Ü", "UE").replace("Ö", "OE")
    txt = p(tp.arc("WANDERER", "latin", 26, 256, 256, 193, -90, track=6), col)
    txt += p(tp.arc(name, "latin", 28, 256, 256, 193, 90, track=2, bottom=True, maxdeg=150), WHITE)
    for a in (-35, -145, 0, 180):
        rr = math.radians(a if a in (0, 180) else a)
    for a in (0, 180):
        rr = math.radians(a)
        txt += p(star(256 + 193 * math.cos(rr), 256 + 193 * math.sin(rr), 8, 3, 4), col)
    layers.append(("schrift", txt))
    return doc(layers)


def boss_logo(r):
    sign, short, col, col2, kind = BOSSES[r["id"]]
    layers = []
    # 12-zackiger Stern als Außenform, darin Kreis
    outer = star(256, 256, 248, 214, 12)
    defs = (f'<radialGradient id="bg_{r["id"]}" cx=".5" cy=".42" r=".6"><stop offset="0" stop-color="{col2}"/>'
            f'<stop offset="1" stop-color="{DARK2}"/></radialGradient>')
    layers.append(("schnitt", stroked(outer, DARK2, 28, DARK2) + stroked(outer, col, 14, col)))
    layers.append(("grund", p(outer, DARK2) + p(circle(256, 256, 200), f"url(#bg_{r['id']})")))
    fr = stroked(circle(256, 256, 200), col, 6) + stroked(circle(256, 256, 186), col, 2)
    fr += stroked(star(256, 256, 248, 214, 12), col, 3)
    layers.append(("rahmen", fr))
    mot = ""
    if kind == "claws":
        for i in range(3):
            x = 300 + i * 34
            mot += p(f"M{x} 112 Q{x + 22} 250 {x - 10} 400 L{x - 22} 396 Q{x + 6} 250 {x - 14} 116 Z", col2, ' opacity=".55"')
    elif kind == "scales":
        for row in range(4):
            for colm in range(6):
                cx = 140 + colm * 46 + (23 if row % 2 else 0)
                cy = 150 + row * 56
                if (cx - 256) ** 2 + (cy - 256) ** 2 < 170 ** 2:
                    mot += f'<path d="M{cx - 22} {cy} A22 22 0 0 0 {cx + 22} {cy}" fill="none" stroke="{col}" stroke-width="3" opacity=".35"/>'
    elif kind == "infinity":
        mot += (f'<path d="M256 256 C300 196 380 196 380 256 C380 316 300 316 256 256 C212 196 132 196 132 256 C132 316 212 316 256 256 Z" '
                f'fill="none" stroke="{col}" stroke-width="16" opacity=".35"/>')
    mot += p(tp.line(sign[0], "jp", 104, 256, 200), WHITE) + p(tp.line(sign[1], "jp", 104, 256, 312), col if kind != "claws" else WHITE)
    layers.append(("motiv", mot))
    by = 420
    txt = p(banner(256, by, 330, 56, .1), col)
    txt += p(tp.line(short, "latin", 30, 256, by, track=5, maxw=260), DARK2)
    txt += p(star(256, 66, 18, 7), col)
    layers.append(("schrift", txt))
    return doc(layers, defs)


def main():
    data = json.load(open(RIVALS, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    written = []
    for t in data["teams"]:
        if t["id"] not in TEAMS:
            print("WARNUNG: kein Logo-Eintrag für Crew", t["id"])
            continue
        for leader in (False, True):
            for icon in (False, True):
                name = t["id"] + ("_leader" if leader else "") + ("_icon" if icon else "") + ".svg"
                open(os.path.join(OUT, name), "w", encoding="utf-8").write(team_logo(t, leader, icon))
                written.append(name)
    for r in data["rivals"]:
        if r.get("wanderer"):
            if r["id"] not in WANDERERS:
                print("WARNUNG: kein Siegel für Wanderer", r["id"])
                continue
            open(os.path.join(OUT, r["id"] + ".svg"), "w", encoding="utf-8").write(wanderer_logo(r))
            written.append(r["id"] + ".svg")
        elif r.get("boss") and r["id"] in BOSSES:
            open(os.path.join(OUT, r["id"] + ".svg"), "w", encoding="utf-8").write(boss_logo(r))
            written.append(r["id"] + ".svg")
    print(len(written), "Logos nach", OUT)
    if "--png" in sys.argv or "--sheet" in sys.argv:
        import cairosvg
        pngdir = os.path.join(HERE, "out")
        os.makedirs(pngdir, exist_ok=True)
        for n in written:
            cairosvg.svg2png(url=os.path.join(OUT, n), write_to=os.path.join(pngdir, n[:-4] + ".png"), output_width=256, output_height=256)
        if "--sheet" in sys.argv:
            sheet(written, pngdir, data)


def sheet(written, pngdir, data):
    from PIL import Image, ImageDraw, ImageFont
    cols = 10
    cell = 200
    rows = math.ceil(len(written) / cols)
    img = Image.new("RGB", (cols * cell, rows * (cell + 26)), (28, 31, 36))
    dr = ImageDraw.Draw(img)
    try:
        fnt = ImageFont.truetype(tp._find(["Inter-Bold.otf", "DejaVuSans-Bold.ttf", "InterDisplay-Bold.otf"]), 13)
    except Exception:
        fnt = None
    for i, n in enumerate(written):
        im = Image.open(os.path.join(pngdir, n[:-4] + ".png")).convert("RGBA").resize((176, 176))
        x, y = (i % cols) * cell + 12, (i // cols) * (cell + 26) + 8
        img.paste(im, (x, y), im)
        dr.text((x, y + 180), n[:-4], fill=(200, 205, 212), font=fnt)
    img.save(os.path.join(HERE, "uebersicht.png"))
    print("Übersicht:", os.path.join(HERE, "uebersicht.png"))


if __name__ == "__main__":
    main()
