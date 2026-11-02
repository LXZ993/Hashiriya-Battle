"""Baut das Silhouetten-Tool (tools/silhouette/silhouetten.html) aus den Teilen des Porträt-Generators.

Jedes Teil wird einmal mit Platzhaltern für Farben und Texte gezeichnet (@A@ Crewfarbe, @T0@/@T1@ Stoff,
@H0@/@H1@ Haare, @K0@/@K1@ Kopfbedeckung, @E@ Crewzeichen, @J0@..@J7@ Crewname, @NICK@, @TAPE@).
Das Tool setzt die Teile im Browser genauso zusammen wie make.compose() und tauscht die Platzhalter aus.
So sieht man im Tool exakt das Bild, das im Spiel landet.

Aufruf (im Repo-Ordner): python tools/silhouette/vc/build_tool.py   (vorher rivals_v2.py laufen lassen)
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from core import Doc, HEAD_DY, CX, W, H
import parts_head as PH
import parts_body as PB
import make as MK
import rivals_v2 as RV

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
A = "@A@"
T = ("@T0@", "@T1@")
HC = ("@H0@", "@H1@")
KT = ("@K0@", "@K1@")
JP = [f"@J{i}@" for i in range(8)]
PB.EMBLEMS["@E@"] = "@E@"

frags = {}
n = 0


def frag(key, fn):
    global n
    n += 1
    doc = Doc(True, pref=f"q{n}x")
    out = fn(doc)
    frags[key] = {"defs": "".join(doc.defs), "body": out}


frag("bg", lambda d: MK.background(d, A, JP))
frag("body", lambda d: PB.body_shell(d, A))
frag("head", lambda d: PH.head_shell(d, A))
frag("visor", lambda d: PH.visor_glass(d))
frag("shine", lambda d: PH.visor_shine(d))
frag("mask", lambda d: PH.mask(d, A))
for eid, (_, fn) in PH.EYES.items():
    for lash in (0, 1):
        frag(f"eyes:{eid}:{lash}", lambda d, fn=fn, lash=lash: PH.eyes_svg(d, fn, lashes=bool(lash)))
for hid, h in PH.HAIRS.items():
    res = {}

    def hb(d, h=h, res=res):
        b, fr = h[1](d, A, HC)
        res["f"] = fr
        return b
    frag(f"hairb:{hid}", hb)
    frags[f"hairf:{hid}"] = {"defs": "", "body": res["f"]}  # gleiche Defs wie hairb
for gid, g in PB.GARMENTS.items():
    for fem in (0, 1):
        for lead in (0, 1):
            ctx = dict(female=bool(fem), leader=bool(lead), jp=JP[:4], nick="@NICK@", tape="@TAPE@")
            frag(f"g:{gid}:{fem}:{lead}", lambda d, g=g, ctx=ctx: g[1](d, A, T, ctx))
            if g[3].get("patch"):
                x, y, kind = g[3]["patch"]
                frag(f"mark:{gid}:{fem}:{lead}", lambda d, x=x, y=y, kind=kind, fem=fem, lead=lead:
                     d.shadowed(PB.mark(x, y, kind, A, "@E@", MK.FEMALE_K if fem else 1.0, gold=bool(lead)), 0, 2, 3, 40))
for nid, nk in PB.NECKS.items():
    frag(f"neck:{nid}", lambda d, nk=nk: nk[1](d, A))
for eid, e in PH.EARS.items():
    frag(f"ear:{eid}", lambda d, e=e: e[1](d, A))
for mid, m in PH.MOUTHS.items():
    frag(f"mouth:{mid}", lambda d, m=m: m[1](d, A))
for hid, h in PH.HATS.items():
    frag(f"hat:{hid}", lambda d, h=h: h[1](d, A, KT))
for gid, g in PH.GLASSES.items():
    frag(f"gl:{gid}", lambda d, g=g: g[1](d, A))

meta = {
    "W": W, "H": H, "CX": CX, "HEAD_DY": HEAD_DY, "FEMALE_K": MK.FEMALE_K,
    "garments": {k: {"name": v[0], "neck": v[2], "patch": v[3].get("patch"), "wm": v[4], "wf": v[5], "tones": v[6]} for k, v in PB.GARMENTS.items()},
    "tones": PB.TONES,
    "hairs": {k: {"name": v[0], "vol": v[2], "long": v[3], "wm": v[4], "wf": v[5]} for k, v in PH.HAIRS.items()},
    "haircolors": PH.HAIR_COLORS,
    "hats": {k: {"name": v[0], "vols": sorted(v[2])} for k, v in PH.HATS.items()},
    "glasses": {k: {"name": v[0], "top": v[2]} for k, v in PH.GLASSES.items()},
    "ears": {k: {"name": v[0]} for k, v in PH.EARS.items()},
    "necks": {k: {"name": v[0], "ok": sorted(v[2])} for k, v in PB.NECKS.items()},
    "mouths": {k: {"name": v[0]} for k, v in PH.MOUTHS.items()},
    "eyes": {k: v[0] for k, v in PH.EYES.items()},
    "emblems": PB.EMBLEMS_PUBLIC if hasattr(PB, "EMBLEMS_PUBLIC") else {k: v for k, v in PB.EMBLEMS.items() if k != "@E@"},
    "formal": sorted(MK.FORMAL),
}

specs = json.load(open(os.path.join(HERE, "out", "portrait_specs.json"), encoding="utf-8"))
data = RV.load_js(os.path.join(ROOT, "tools", "silhouette", "rivals_data.js"))
rivals = [{"id": r["id"], "name": r.get("name", ""), "team": r.get("team"), "leader": bool(r.get("leader")), "wanderer": bool(r.get("wanderer")),
           "boss": bool(r.get("boss")), "nick": r.get("nick"), "lines": r.get("lines")} for r in data["rivals"]]
payload = {"meta": meta, "frags": frags, "specs": specs["rivals"], "rivals": rivals, "teams": data["teams"]}

tpl = open(os.path.join(HERE, "tool_template.html"), encoding="utf-8").read()
html = tpl.replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
out = os.path.join(ROOT, "tools", "silhouette", "silhouetten.html")
open(out, "w", encoding="utf-8").write(html)
print(f"{out}: {len(frags)} Bausteine, {len(rivals)} Gegner, {len(html) // 1024} KB")
