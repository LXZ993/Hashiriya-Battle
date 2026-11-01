"""Porträts v2 für alle Gegner und PA-Fahrer im Spiel.

Aufruf (im Repo-Ordner):  python tools/silhouette/vc/rivals_v2.py [--png]
  - liest tools/silhouette/rivals_data.js (aus build_data.py: Crew, Frau/Mann, Hinweise aus der Beschreibung)
  - liest tools/silhouette/silhouetten.json, falls vorhanden ("v2": {"<id>": {"hair": "tolle", ...}})
  - schreibt art/portraits/<id>.svg (Gegner) und art/portraits/npc/<sprecher>_<n>.svg (PA-Fahrer)
Die SVGs enthalten die Weichzeichner/Schatten als SVG-Filter, das Spiel (Browser-Oberfläche) zeigt sie direkt an.
Jede Figur ist fest aus der ID berechnet und einzigartig. Eigene Vorgaben je Gegner gehen über
"silhouette": {...} in rivals.json oder über silhouetten.json (gleiche Schlüssel wie SPEC_KEYS).
"""
import hashlib, json, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import parts_head as PH
import parts_body as PB
from make import compose, allowed_hats, allowed_glasses, allowed_necks, wpick

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SEED = "hashiriya-v2"
SPEC_KEYS = ("garment", "tone", "hair", "haircolor", "hat", "hattone", "glasses", "ear", "neck", "mask", "mouth", "eyes", "emblem", "crew")

# Crew-Stil: welche Teile die Mitglieder meistens tragen (passend zum Crew-Thema)
CREW = {
    "t_lantern":    dict(emblem="flamme", garment=["hoodie", "bomber", "tshirt", "sukajan"], hair=["stachelig", "kurz", "mittel", "pferdeschwanz", "zoepfe"], neck=["kopfhoerer", "kette"], hat=["cap_rueck"]),
    "t_zangyo":     dict(emblem="raute", garment=["anzug", "kostuem", "weste", "mantel"], glasses=["eckig", "rund"], hair=["scheitel", "kurz", "bob", "dutt", "zurueck"]),
    "t_showa":      dict(emblem="kreis", garment=["weste", "mantel", "rollkragen", "anzug", "kostuem"], hair=["scheitel", "tolle", "glatze", "dutt"], haircolor=["silber", "silber", "schwarz"]),
    "t_diana":      dict(emblem="fluegel", garment=["bluse", "kostuem", "sukajan", "pelz", "jeans"], ear=["creolen", "haenger"], neck=["choker", "kette"]),
    "t_yamagumi":   dict(emblem="raute", garment=["warnweste", "overall", "parka", "rollkragen"], hat=["muetze", "bandana", "stirnband", "cap"], neck=["handtuch"]),
    "t_bxboys":     dict(emblem="blitz", garment=["jeans", "bomber", "tshirt", "trainings"], hat=["cap", "cap_rueck"], hair=["kurz", "stachelig"]),
    "t_neon":       dict(emblem="stern", garment=["pelz", "anzug", "kostuem", "weste", "leder"], glasses=["sonnenbrille", "pilot"], neck=["kette"], ear=["creolen", "stecker"], mouth=["zigarette"]),
    "t_kombi":      dict(emblem="kreis", garment=["weste", "tshirt", "parka", "rollkragen"], glasses=["rund", "eckig"], hair=["kurz", "scheitel", "glatze"], hat=["cap"]),
    "t_kitsune":    dict(emblem="flamme", garment=["anzug", "mantel", "rollkragen", "kostuem"], glasses=["sonnenbrille", "pilot"], mask=True),
    "t_pocket":     dict(emblem="blitz", garment=["tshirt", "hoodie", "rennanzug", "sukajan"], hair=["stachelig", "zoepfe", "bob", "mittel"], hat=["cap_rueck"]),
    "t_hoshikuzu":  dict(emblem="stern", garment=["rennanzug", "trainings", "overall"], hat=["cap"], hair=["kurz"]),
    "t_sleeper":    dict(emblem="raute", garment=["jeans", "weste", "trainings", "tshirt"], hat=["cap"], hair=["kurz", "scheitel"]),
    "t_kasumi":     dict(emblem="fluegel", garment=["sukajan", "hoodie", "tokkou", "bomber"], mouth=["zigarette", "zahnstocher"], hair=["stachelig", "irokese", "mittel", "lang_wellig"], hat=["bandana"]),
    "t_etkklassik": dict(emblem="kreis", garment=["leder", "rollkragen", "mantel"], glasses=["rund", "eckig"]),
    "t_sbr":        dict(emblem="flamme", garment=["overall", "warnweste", "trainings"], hat=["cap"], hair=["kurz"]),
    "t_yokota":     dict(emblem="fluegel", garment=["militaer", "tshirt", "bomber"], neck=["hundemarken"], hair=["kurz", "glatze"], hat=["feldmuetze", "cap"]),
    "t_kurogane":   dict(emblem="raute", garment=["mantel", "anzug", "leder", "kostuem"], glasses=["sonnenbrille"], tone=["schwarz", "anthrazit"]),
    "t_muscle73":   dict(emblem="stern", garment=["leder", "jeans", "tshirt", "weste"], hair=["lang_m", "tolle", "lang_wellig", "zurueck"], glasses=["sonnenbrille", "pilot"]),
    "t_raijin":     dict(emblem="blitz", garment=["overall", "sukajan", "tshirt", "tokkou"], mouth=["zigarette"], hat=["bandana", "stirnband"], hair=["stachelig"]),
    "t_hotrod":     dict(emblem="flamme", garment=["leder", "jeans"], hair=["tolle", "zurueck", "hime", "pferdeschwanz"], mouth=["zigarette", "zahnstocher"]),
    "t_bolide":     dict(emblem="fluegel", garment=["rennanzug", "anzug", "kostuem", "rollkragen"], glasses=["sonnenbrille", "pilot"], neck=["schal"]),
    "t_vivace":     dict(emblem="kreis", garment=["rollkragen", "mantel", "trainings", "bluse"], neck=["schal"], hair=["scheitel", "bob"], hat=["cap_rueck"]),
    "t_akatsuki":   dict(emblem="flamme", garment=["rennanzug", "overall", "trainings"], ear=["headset"]),
    "t_etkmodern":  dict(emblem="blitz", garment=["anzug", "kostuem", "rollkragen", "mantel"], glasses=["eckig"]),
    "t_bastion":    dict(emblem="raute", garment=["leder", "jeans", "militaer", "weste"], neck=["hundemarken", "kette"]),
    "t_scintilla":  dict(emblem="stern", garment=["anzug", "kostuem", "pelz", "mantel"], glasses=["sonnenbrille"], neck=["kette"]),
}

# Feste Looks (Bosse und besondere Wanderer)
FIXED = {
    "b_shirotora": dict(garment="sukajan", tone="weiss", hair="kurz", haircolor="platin", eyes="cool", glasses="sonnenbrille", crew=False),
    "b_kokuryu":   dict(garment="tokkou", tone="schwarz", hair="zurueck", haircolor="schwarz", eyes="grimmig", mask=True, crew=False),
    "b_mugen":     dict(garment="mantel", tone="anthrazit", hair="zurueck", haircolor="silber", hat="hut", hattone="schwarz", eyes="muede", crew=False, figur="m"),
    # Slim Henry: Dutt, Zigarette, weinroter Hoodie, fröhlich (nach seinem bisherigen Porträt)
    "w_henry":     dict(garment="hoodie", tone="weinrot", hair="dutt", haircolor="dunkelbraun", eyes="laecheln", mouth="zigarette", crew=False, figur="m"),
    # Alex Zockt (LXZ): nach Alex' eigenem Porträt: Lantern-Farben, Hachimaki, Funk-Headset, dunkle Rennjacke, Goldkette
    "w_alex_zockt": dict(garment="rennanzug", tone="marine", hair="kurz", haircolor="dunkelbraun", hat="stirnband", eyes="cool",
                         ear="headset", neck="kette", crew=False, figur="m", A="#ffb347", jp="真夜中ランタン"),
}
BOSS_COLOR = {"b_shirotora": "#f5f5f5", "b_kokuryu": "#9c27ff", "b_mugen": "#ffd54f"}
WANDERER_COLORS = ["#9fb4c7", "#b5a58c", "#a7c4a0", "#c9a7c7", "#8fb8c9", "#c4b48a", "#a0a8c8"]

# alte Teilenamen (Version 1, z. B. aus rivals.json "silhouette", chat.json "look", Hinweisen) -> Version 2
V1 = {
    "jacke": {"hoodie": "hoodie", "bomber": "bomber", "tshirt": "tshirt", "sukajan": "sukajan", "windbreaker": "trainings", "anzug": "anzug",
              "kostuem": "kostuem", "weste": "weste", "mantel": "mantel", "strick": "rollkragen", "bluse": "bluse", "pelz": "pelz", "jeans": "jeans",
              "warnweste": "warnweste", "overall": "overall", "hawaii": "tshirt", "leder": "leder", "polo": "tshirt", "rollkragen": "rollkragen",
              "racing": "rennanzug", "militaer": "militaer", "tokko": "tokkou", "training": "trainings"},
    "haare": {"stachel": "stachelig", "kurz": "kurz", "bobcut": "bob", "zopf": "pferdeschwanz", "zoepfe": "zoepfe", "scheitel": "scheitel", "dutt": "dutt",
              "tolle": "tolle", "kahl": "glatze", "irokese": "irokese", "wellen": "lang_wellig", "lang": "lang_m", "hime": "hime",
              "capback": ("kurz", "cap_rueck"), "cap": ("kurz", "cap"), "muetze": ("kurz", "muetze"), "bandana": ("kurz", "bandana"), "stirnband": ("kurz", "stirnband")},
    "brille": {"sonne": "sonnenbrille", "rund": "rund", "halb": "eckig", "wrap": "sonnenbrille", "goggles": None, "keine": None},
    "hals": {"kopfhoerer": "kopfhoerer", "kette": "kette", "hundemarke": "hundemarken", "handtuch": "handtuch", "schal": "schal", "halstuch": "schal", "keins": None},
    "extra": {"zigarette": ("mouth", "zigarette"), "zahnstocher": ("mouth", "zahnstocher"), "maske": ("mask", True), "headset": ("ear", "headset"),
              "ohrring": ("ear", "creolen"), "keins": None},
}


def v1_to_v2(d, fem):
    """Übersetzt alte Teile ({jacke, haare, brille, hals, extra, haarfarbe}) in v2-Vorgaben."""
    out = {}
    for k, v in (d or {}).items():
        if k in SPEC_KEYS:
            out[k] = v
            continue
        m = V1.get(k, {})
        if k == "haarfarbe" and v in PH.HAIR_COLORS:
            out["haircolor"] = v
        elif k == "jacke" and v in m:
            g = m[v]
            out["garment"] = "kostuem" if g == "anzug" and fem else g
        elif k == "haare" and v in m:
            h = m[v]
            if isinstance(h, tuple):
                out["hair"], out["hat"] = ("pferdeschwanz" if fem else h[0]), h[1]
            else:
                out["hair"] = h
        elif k == "brille" and v in m:
            out["glasses"] = m[v]
        elif k == "hals" and v in m:
            out["neck"] = m[v]
        elif k == "extra" and m.get(v):
            out[m[v][0]] = m[v][1]
    return out


def rng(*parts):
    h = hashlib.sha1("|".join(map(str, parts)).encode()).hexdigest()
    return random.Random(int(h[:16], 16))


def auto_spec(r, team, salt):
    fem = r.get("figur") == "f"
    R = rng(SEED, r["id"], salt)
    st = CREW.get(r.get("team"), {})
    gi = 5 if fem else 4
    hi = 5 if fem else 4

    def pool(key, table, wi):
        lst = [x for x in st.get(key, []) if x in table and table[x][wi] > 0]
        return lst

    gp = pool("garment", PB.GARMENTS, gi)
    g = R.choice(gp) if gp and R.random() < .75 else wpick(R, [(k, v[gi]) for k, v in PB.GARMENTS.items()], gi)
    tones = st.get("tone") or PB.GARMENTS[g][6]
    spec = dict(female=fem, garment=g, tone=R.choice(tones), eyes=R.choice(list(PH.EYES)))
    hp = pool("hair", PH.HAIRS, hi)
    spec["hair"] = R.choice(hp) if hp and R.random() < .6 else wpick(R, [(k, v[hi]) for k, v in PH.HAIRS.items()], hi)
    hc = st.get("haircolor")
    spec["haircolor"] = R.choice(hc) if hc and R.random() < .6 else (R.choice(["schwarz", "schwarz", "dunkelbraun", "braun"]) if R.random() < .72 else R.choice(list(PH.HAIR_COLORS)))
    spec["hattone"] = R.choice(["schwarz", "marine", "weinrot", "oliv", "weiss", "grau", "rot", "royal"])
    return spec, R, st


def finish_spec(spec, R, st, fixed):
    """Zubehör nach den Regeln wählen; fest vorgegebene Teile (fixed) bleiben."""
    fem = spec["female"]
    spec.update({k: v for k, v in fixed.items() if k in ("garment", "tone", "hair", "haircolor", "eyes", "hattone")})
    if spec["garment"] == "anzug" and fem:
        spec["garment"] = "kostuem"
    if spec["garment"] not in PB.GARMENTS:
        spec["garment"] = "hoodie"
    if "tone" not in fixed and spec["tone"] not in (st.get("tone") or PB.GARMENTS[spec["garment"]][6]):
        spec["tone"] = R.choice(PB.GARMENTS[spec["garment"]][6])  # Farbe passend zum (vorgegebenen) Oberteil
    if spec["tone"] not in PB.TONES:
        spec["tone"] = PB.GARMENTS[spec["garment"]][6][0]
    # Hut
    if "hat" in fixed:
        spec["hat"] = fixed["hat"]
        if spec["hat"] and PH.HAIRS[spec["hair"]][2] not in PH.HATS[spec["hat"]][2]:
            spec["hair"] = "pferdeschwanz" if fem else "kurz"  # Frisur passend zum vorgegebenen Hut
    else:
        hats = allowed_hats(spec)
        pref = [h for h in st.get("hat", []) if h in hats]
        spec["hat"] = None
        if pref and R.random() < .45:
            spec["hat"] = R.choice(pref)
        elif hats and R.random() < .15:
            spec["hat"] = R.choice([h for h in hats if h != "feldmuetze"] or hats)
    # Brille
    gl = allowed_glasses(spec)
    if "glasses" in fixed:
        spec["glasses"] = fixed["glasses"] if (fixed["glasses"] in gl or fixed["glasses"] is None) else None
    else:
        pref = [x for x in st.get("glasses", []) if x in gl]
        spec["glasses"] = R.choice(pref) if pref and R.random() < .5 else (R.choice(gl) if gl and R.random() < .15 else None)
    # Hals (nur passender Ausschnitt)
    nk = allowed_necks(spec)
    ni = 4 if fem else 3
    if "neck" in fixed:
        spec["neck"] = fixed["neck"] if fixed["neck"] in nk else None
    else:
        pref = [x for x in st.get("neck", []) if x in nk and PB.NECKS[x][ni] > 0]
        spec["neck"] = R.choice(pref) if pref and R.random() < .5 else (wpick(R, [(k, PB.NECKS[k][ni]) for k in nk], ni) if nk and R.random() < .2 else None)
    # Ohren
    ei = 3 if fem else 2
    if "ear" in fixed:
        spec["ear"] = fixed["ear"]
    else:
        pref = [x for x in st.get("ear", []) if PH.EARS[x][ei] > 0 or x == "headset"]
        spec["ear"] = R.choice(pref) if pref and R.random() < .5 else (wpick(R, [(k, v[ei]) for k, v in PH.EARS.items()], ei) if R.random() < (.45 if fem else .12) else None)
    # Maske / Mund
    spec["mask"] = bool(fixed.get("mask", st.get("mask") and R.random() < .3 or R.random() < .03))
    if "mouth" in fixed:
        spec["mouth"] = fixed["mouth"]
    else:
        pref = st.get("mouth", [])
        spec["mouth"] = R.choice(pref) if pref and R.random() < .3 else (R.choice(list(PH.MOUTHS)) if not fem and R.random() < .05 else None)
    if spec["mask"]:
        spec["mouth"] = None
    return spec


def build_all(rivals, teams, overrides):
    specs, used = {}, set()
    for r in sorted(rivals, key=lambda x: x["id"]):
        fem = r.get("figur") == "f"
        fixed = dict(FIXED.get(r["id"], {}))
        if fixed.get("figur"):
            r = dict(r, figur=fixed["figur"])
            fem = fixed["figur"] == "f"
        fixed.update(v1_to_v2(r.get("hints"), fem))          # Hinweise aus der Beschreibung
        fixed.update(FIXED.get(r["id"], {}))                    # feste Looks gehen vor
        fixed.update(v1_to_v2(r.get("silhouette"), fem))       # "silhouette" in rivals.json
        fixed.update(v1_to_v2(overrides.get(r["id"]), fem))   # silhouetten.json
        team = teams.get(r.get("team"))
        for salt in range(60):
            spec, R, st = auto_spec(r, team, salt)
            spec = finish_spec(spec, R, st, fixed)
            sig = tuple(spec.get(k) for k in SPEC_KEYS if k not in ("emblem", "crew"))
            if sig not in used:
                break
        used.add(sig)
        if team:
            A, jp = team["color"], team["jp"]
            emblem = CREW.get(r["team"], {}).get("emblem", "stern")
            crew = bool(r.get("leader")) or R.random() < .7
        elif r.get("boss"):
            A, jp, emblem, crew = BOSS_COLOR.get(r["id"], "#ffd54f"), "首領", "stern", False
        else:
            A, jp, emblem, crew = WANDERER_COLORS[int(hashlib.md5(r["id"].encode()).hexdigest(), 16) % len(WANDERER_COLORS)], "放浪者", "stern", False
        A, jp = fixed.get("A", A), fixed.get("jp", jp)
        spec.update(A=A, jp=jp, emblem=emblem, crew=fixed.get("crew", crew), leader=bool(r.get("leader")),
                    nick=((r.get("nick") or {}).get("en") or r.get("name", ""))[:9],
                    tape=(r.get("name", "").split(" ")[-1] or "HASHIRIYA").upper()[:9])
        specs[r["id"]] = spec
    return specs


def npc_specs(chat):
    out = {}
    n = (chat.get("pa") or {}).get("portraitVariants", 3)
    for s in chat.get("speakers", []):
        fem = s.get("figur") == "f"
        c = s.get("color") or [.6, .6, .6]
        A = "#" + "".join(f"{round(max(0, min(1, v)) * 255):02x}" for v in c)
        looks = s.get("look") or [{}]
        for i in range(1, n + 1):
            fixed = v1_to_v2(looks[(i - 1) % len(looks)], fem)
            r = {"id": f"{s['id']}_{i}", "figur": "f" if fem else "m"}
            spec, R, st = auto_spec(r, None, 0)
            spec = finish_spec(spec, R, {}, fixed)
            spec.update(A=A, jp="パーキング", emblem="stern", crew=False, leader=False, nick="", tape="")
            out[r["id"]] = spec
    return out


def load_js(path):
    t = open(path, encoding="utf-8").read()
    return json.loads(t[t.index("{"):t.rindex("}") + 1])


if __name__ == "__main__":
    data = load_js(os.path.join(ROOT, "tools", "silhouette", "rivals_data.js"))
    teams = {t["id"]: t for t in data["teams"]}
    ov_path = os.path.join(ROOT, "tools", "silhouette", "silhouetten.json")
    overrides = {}
    if os.path.exists(ov_path):
        overrides = (json.load(open(ov_path, encoding="utf-8")).get("v2") or {})
    specs = build_all(data["rivals"], teams, overrides)
    outdir = os.path.join(ROOT, "art", "portraits")
    os.makedirs(os.path.join(outdir, "npc"), exist_ok=True)
    for f in os.listdir(outdir):
        if f.endswith(".svg"):
            os.remove(os.path.join(outdir, f))
    for rid, spec in specs.items():
        open(os.path.join(outdir, rid + ".svg"), "w", encoding="utf-8").write(compose(spec, True).svg())
    chat = json.load(open(os.path.join(ROOT, "lua", "ge", "extensions", "hashiriyaBattle", "data", "chat.json"), encoding="utf-8"))
    npcs = npc_specs(chat)
    for f in os.listdir(os.path.join(outdir, "npc")):
        if f.endswith(".svg"):
            os.remove(os.path.join(outdir, "npc", f))
    for nid, spec in npcs.items():
        open(os.path.join(outdir, "npc", nid + ".svg"), "w", encoding="utf-8").write(compose(spec, True).svg())
    json.dump({"rivals": specs, "npc": npcs}, open(os.path.join(HERE, "out", "portrait_specs.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"{len(specs)} Gegner-Porträts und {len(npcs)} PA-Porträts geschrieben")
