"""Hashiriya Battle Porträts v2: Figuren zusammensetzen, Musterbogen und Teile-Katalog (eine PSD).

Aufruf: python make.py OUTDIR
  OUTDIR/muster_NN.svg (+ _steps.json, _preview.svg)  12 zufällige Figuren nach den Regeln
  OUTDIR/katalog.svg  (+ _steps.json, _preview.svg)   alle Teile als eigene Ebenen auf einer Leinwand
VectorCraft: vectorcraft-cli run --in X.svg --commands X_steps.json --export X.png --export X.psd --scale 2
"""
import json, os, random, sys
from core import Doc, W, H, vc_steps
import parts_head as PH
import parts_body as PB

CREW_COLORS = ["#ffb347", "#ff4fd8", "#7cb342", "#4fc3f7", "#ff5252", "#b388ff", "#ffd740", "#64ffda", "#ff8a65", "#e0e0e0"]
FEMALE_K = .86


def background(doc, A, jp):
    out = f'<rect width="{W}" height="{H}" fill="{doc.lin([(0, "#151821", 1), (1, "#07080b", 1)])}"/>'
    out += f'<rect width="{W}" height="{H}" fill="{doc.rad([(0, A, .45), (.5, A, .08), (1, A, 0)], cx=.15, cy=1, r=.95)}"/>'
    for i in range(14):
        x = -200 + i * 70
        out += f'<path d="M{x},600 L{x + 340},0" stroke="#ffffff" stroke-opacity=".025" stroke-width="18"/>'
    for i, ch in enumerate(jp[:8]):
        out += f'<text x="548" y="{70 + i * 62}" text-anchor="middle" font-size="54" font-weight="700" font-family="Yu Gothic, Meiryo, Noto Sans JP, sans-serif" fill="{A}" fill-opacity=".14">{ch}</text>'
    out += f'<rect y="592" width="{W}" height="8" fill="{A}"/>'
    return out


def wpick(rnd, items, wkey):
    items = [(k, w) for k, w in items if w > 0]
    tot = sum(w for _, w in items)
    r = rnd.uniform(0, tot)
    for k, w in items:
        r -= w
        if r <= 0:
            return k
    return items[-1][0]


# ---------------------------------------------------------------------------
# Regeln: was passt zusammen?
# ---------------------------------------------------------------------------
FORMAL = {"anzug", "kostuem", "weste", "pelz", "rollkragen", "bluse"}


def allowed_hats(spec):
    vol = PH.HAIRS[spec["hair"]][2]
    out = []
    for hid, (_, _, vols) in PH.HATS.items():
        if vol not in vols:
            continue
        if hid == "feldmuetze" and spec["garment"] != "militaer":
            continue  # Feldmütze nur zur Feldjacke
        if hid == "hut" and spec["garment"] not in FORMAL:
            continue  # Hut nur zu eleganter Kleidung
        if hid in ("cap", "cap_rueck", "bandana") and spec["garment"] in FORMAL:
            continue  # keine Cap zum Anzug
        out.append(hid)
    return out


def allowed_glasses(spec):
    vol = PH.HAIRS[spec["hair"]][2]
    return [g for g, (_, _, top) in PH.GLASSES.items() if not top or (spec["hat"] is None and vol not in ("none",))]


def allowed_necks(spec):
    neck = PB.GARMENTS[spec["garment"]][2]
    return [n for n, v in PB.NECKS.items() if neck in v[2]]


def auto(seed):
    rnd = random.Random(seed)
    fem = rnd.random() < .35
    gi = 5 if fem else 4
    g = wpick(rnd, [(k, v[gi]) for k, v in PB.GARMENTS.items()], gi)
    spec = dict(female=fem, A=rnd.choice(CREW_COLORS), jp=rnd.choice(["真夜中ランタン", "銀座ネオン倶楽部", "ナイトパトロール", "首都高連合", "湾岸ゴースト", "赤城レーサーズ"]),
                emblem=rnd.choice(list(PB.EMBLEMS)), garment=g, tone=rnd.choice(PB.GARMENTS[g][6]),
                eyes=rnd.choice(list(PH.EYES)), crew=rnd.random() < .85, leader=rnd.random() < .25,
                nick=rnd.choice(["Kenta", "Reika", "Shin", "Yuki", "Ghost", "Mika", "Daiki", "Aya"]),
                tape=rnd.choice(["BROOKS", "MORI", "TANAKA", "SATO", "MILLER"]))
    hi = 5 if fem else 4
    spec["hair"] = wpick(rnd, [(k, v[hi]) for k, v in PH.HAIRS.items()], hi)
    natural = ["schwarz", "dunkelbraun", "braun", "schwarz"]
    spec["haircolor"] = rnd.choice(natural) if rnd.random() < .7 else rnd.choice(list(PH.HAIR_COLORS))
    hats = allowed_hats(spec)
    spec["hat"] = None
    if spec["garment"] == "militaer" and "feldmuetze" in hats and rnd.random() < .6:
        spec["hat"] = "feldmuetze"
    elif hats and rnd.random() < .3:
        spec["hat"] = rnd.choice([h for h in hats if h != "feldmuetze"] or hats)
    spec["hattone"] = rnd.choice(["schwarz", "marine", "weinrot", "oliv", "weiss", "grau", "rot", "royal"])
    gl = allowed_glasses(spec)
    spec["glasses"] = rnd.choice(gl) if gl and rnd.random() < .3 else None
    ei = 3 if fem else 2
    spec["ear"] = wpick(rnd, [(k, v[ei]) for k, v in PH.EARS.items()], ei) if rnd.random() < (.6 if fem else .2) else None
    nk = allowed_necks(spec)
    ni = 4 if fem else 3
    spec["neck"] = wpick(rnd, [(k, PB.NECKS[k][ni]) for k in nk], ni) if nk and rnd.random() < .4 else None
    spec["mask"] = rnd.random() < .07
    return spec


# ---------------------------------------------------------------------------
# Zusammensetzen
# ---------------------------------------------------------------------------

def compose(spec, preview):
    doc = Doc(preview)
    A = spec["A"]
    k = FEMALE_K if spec["female"] else 1.0
    from html import escape
    ctx = dict(female=spec["female"], leader=bool(spec.get("leader")), jp=spec["jp"], nick=escape(spec.get("nick", "")), tape=escape(spec.get("tape", "").upper()))
    doc.layer("Hintergrund", background(doc, A, spec["jp"]))
    c = PH.HAIR_COLORS[spec["haircolor"]]
    back, front = PH.HAIRS[spec["hair"]][1](doc, A, c)
    if back:
        doc.layer("Haare_hinten", back, head=True)
    doc.layer("Koerper", PB.body_shell(doc, A), k=k)
    gname, gfn, neck, anchors = PB.GARMENTS[spec["garment"]][:4]
    doc.layer("Oberteil", gfn(doc, A, PB.TONES[spec["tone"]], ctx), k=k)
    if spec.get("crew") and anchors.get("patch"):
        x, y, kind = anchors["patch"]
        doc.layer("Abzeichen", doc.shadowed(PB.mark(x, y, kind, A, spec["emblem"], k, gold=bool(spec.get("leader"))), 0, 2, 3, 40))
    if spec.get("neck"):
        doc.layer("Hals", PB.NECKS[spec["neck"]][1](doc, A), k=k)
    doc.layer("Kopf", PH.head_shell(doc, A), head=True)
    doc.layer("Visier", PH.visor_glass(doc), head=True)
    doc.layer("Augen", PH.eyes_svg(doc, PH.EYES[spec["eyes"]][1], lashes=spec["female"]) + PH.visor_shine(doc), head=True)
    if spec.get("mask"):
        doc.layer("Maske", PH.mask(doc, A), head=True)
    elif spec.get("mouth"):
        doc.layer("Mund", PH.MOUTHS[spec["mouth"]][1](doc, A), head=True)
    if front:
        doc.layer("Haare", front, head=True)
    if spec.get("ear"):
        doc.layer("Ohren", PH.EARS[spec["ear"]][1](doc, A), head=True)
    if spec.get("hat"):
        doc.layer("Kopfbedeckung", PH.HATS[spec["hat"]][1](doc, A, PB.TONES[spec["hattone"]]), head=True)
    if spec.get("glasses"):
        doc.layer("Brille", PH.GLASSES[spec["glasses"]][1](doc, A), head=True)
    return doc


def catalog(preview, hide=True):
    """Alle Teile auf einer Leinwand, jede Ebene ein Teil. Sichtbar ist nur eine Grundfigur."""
    doc = Doc(preview)
    A = "#ffb347"
    c = PH.HAIR_COLORS["braun"]
    ctx = dict(female=False, jp="首都高連合", nick="Kenta", tape="MORI")
    doc.layer("Hintergrund", background(doc, A, "首都高連合"))
    show = {"Koerper_M", "Oberteil_M_hoodie", "Kopf", "Visier", "Augen_normal", "Haare_kurz", "Abzeichen_Stoff"}

    def L(name, body, **kw):
        doc.layer(name, body, hidden=hide and name not in show, **kw)

    hairs = {hid: h[1](doc, A, c) for hid, h in PH.HAIRS.items()}  # einmal zeichnen (Effekt-Namen bleiben gültig)
    for hid, (b, fr) in hairs.items():
        if b:
            L(f"Haare_hinten_{hid}", b, head=True)
    L("Koerper_M", PB.body_shell(doc, A))
    L("Koerper_W", PB.body_shell(doc, A), k=FEMALE_K)
    for gid, g in PB.GARMENTS.items():
        tone = PB.TONES[g[6][0]]
        if g[4] > 0:
            L(f"Oberteil_M_{gid}", g[1](doc, A, tone, dict(ctx)))
        if g[5] > 0:
            L(f"Oberteil_W_{gid}", g[1](doc, A, tone, dict(ctx, female=True)), k=FEMALE_K)
    for kind, nm in (("patch", "Stoff"), ("pin", "Nadel"), ("print", "Aufdruck"), ("stick", "Stickerei")):
        for gold in (False, True):
            x, y = {"patch": (372, 468), "pin": (344, 422), "print": (300, 490), "stick": (370, 480)}[kind]
            L(f"Abzeichen_{nm}{'_Leader' if gold else ''}", doc.shadowed(PB.mark(x, y, kind, A, "stern", gold=gold), 0, 2, 3, 40))
    for nid, n in PB.NECKS.items():
        L(f"Hals_{nid}", n[1](doc, A))
    L("Kopf", PH.head_shell(doc, A), head=True)
    L("Visier", PH.visor_glass(doc) + PH.visor_shine(doc), head=True)
    for eid, (nm, fn) in PH.EYES.items():
        L(f"Augen_{eid}", PH.eyes_svg(doc, fn), head=True)
    L("Augen_Wimpern_normal", PH.eyes_svg(doc, PH.EYES["normal"][1], lashes=True), head=True)
    L("Maske", PH.mask(doc, A), head=True)
    for mid, (nm, fn, *_r) in PH.MOUTHS.items():
        L(f"Mund_{mid}", fn(doc, A), head=True)
    for hid, (b, fr) in hairs.items():
        if fr:
            L(f"Haare_{hid}", fr, head=True)
    for eid, (nm, fn, *_r) in PH.EARS.items():
        L(f"Ohren_{eid}", fn(doc, A), head=True)
    for hid, (nm, fn, _v) in PH.HATS.items():
        L(f"Kopfbedeckung_{hid}", fn(doc, A, PB.TONES["schwarz"]), head=True)
    for gid, (nm, fn, _t) in PH.GLASSES.items():
        L(f"Brille_{gid}", fn(doc, A), head=True)
    return doc


def overview_specs():
    """Eine Figur je Teil (für die Übersicht): alle Oberteile M/W, alle Frisuren, Hüte, Brillen, Hals, Ohren."""
    base = dict(female=False, A="#ffb347", jp="首都高連合", emblem="stern", garment="hoodie", tone="schwarz", eyes="normal",
                crew=True, leader=True, nick="Kenta", tape="MORI", hair="kurz", haircolor="dunkelbraun", hat=None,
                hattone="schwarz", glasses=None, ear=None, neck=None, mask=False)
    out = []
    for i, (gid, g) in enumerate(PB.GARMENTS.items()):
        for fem in (False, True):
            if g[5 if fem else 4] > 0:
                out.append((f"o_{gid}_{'w' if fem else 'm'}", dict(base, garment=gid, tone=g[6][i % len(g[6])], female=fem,
                            hair="lang_wellig" if fem else "kurz", A=CREW_COLORS[i % len(CREW_COLORS)])))
    for i, (hid, h) in enumerate(PH.HAIRS.items()):
        fem = h[5] > h[4]
        out.append((f"h_{hid}", dict(base, hair=hid, female=fem, garment="tshirt", tone="grau", haircolor=list(PH.HAIR_COLORS)[i % 12])))
    for i, hid in enumerate(PH.HATS):
        out.append((f"k_{hid}", dict(base, hat=hid, garment="militaer" if hid == "feldmuetze" else ("anzug" if hid == "hut" else "bomber"),
                                     tone="oliv" if hid == "feldmuetze" else "marine", hattone=["rot", "schwarz", "weinrot", "oliv", "weiss", "royal", "anthrazit"][i])))
    for gid in PH.GLASSES:
        out.append((f"b_{gid}", dict(base, glasses=gid, hair="mittel", garment="leder")))
    for nid, n in PB.NECKS.items():
        g = {"hood": "hoodie", "open": "tshirt", "collar_open": "jeans", "v": "kostuem"}
        gar = "tshirt" if "open" in n[2] else "kostuem"
        out.append((f"n_{nid}", dict(base, neck=nid, garment=gar, tone="weiss", female=nid == "choker", hair="bob" if nid == "choker" else "kurz")))
    for eid in PH.EARS:
        out.append((f"e_{eid}", dict(base, ear=eid, female=True, hair="dutt", garment="bluse", tone="creme")))
    for eid in PH.EYES:
        out.append((f"a_{eid}", dict(base, eyes=eid, hair="scheitel", garment="trainings", tone="royal")))
    out.append(("m_maske", dict(base, mask=True, hair="tolle", garment="tokkou", tone="weiss")))
    return out


def write(out, name, mk):
    d = mk(False)
    open(os.path.join(out, f"{name}.svg"), "w", encoding="utf-8").write(d.svg())
    json.dump(vc_steps(d), open(os.path.join(out, f"{name}_steps.json"), "w"), indent=0)
    open(os.path.join(out, f"{name}_preview.svg"), "w", encoding="utf-8").write(mk(True).svg())


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    specs = []
    for i in range(12):
        s = auto(f"hashiriya-muster-{i}")
        specs.append(s)
        write(out, f"muster_{i:02d}", lambda p, s=s: compose(s, p))
    json.dump(specs, open(os.path.join(out, "muster_specs.json"), "w"), indent=1, ensure_ascii=False)
    if "--uebersicht" in sys.argv:
        ov = overview_specs()
        for n, s in ov:
            write(out, n, lambda p, s=s: compose(s, p))
        open(os.path.join(out, "uebersicht.txt"), "w").write(",".join(n for n, _ in ov))
    # VectorCraft verwirft ausgeblendete Ebenen beim PSD-Export, daher alle sichtbar
    write(out, "katalog", lambda p: catalog(p, False))
    print("ok")
