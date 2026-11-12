"""Schreibt rivals_data.js aus der rivals.json der Mod, damit silhouetten.html
ohne Webserver (file://) alle Gegner kennt. Aufruf: python build_data.py"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "lua", "ge", "extensions", "hashiriyaBattle", "data", "rivals.json")

# Figur (Frau/Mann) fuer das Portraet. Steht in rivals.json ein Feld "figur" ("f"/"m"),
# gilt das. Sonst: Vorname aus der Liste unten, danach Pronomen in der deutschen Beschreibung.
FEMALE_NAMES = set("""Ai Aiko Akane Akari Aoi Asami Asuka Atsuko Ayame Ayano Ayumi Brenda Camille Chiharu
Chiyo Emi Erika Erina Fumiko Giulia Greta Hana Hanae Haruko Hinata Ingrid Junko Kaede Kana Kanna Kazue
Kiko Kimiko Kumiko Kyoko Linda Mai Maki Mamiko Mariko Mathilde Mayu Mayumi Mei Michiko Midori Mika Mio
Mirai Momo Nana Nanami Natsumi Noa Noriko Rei Reika Reiko Rie Rin Rina Rumi Ruriko Ryōko Sachi Sachiko
Sakura Saya Sayaka Sayuri Setsuko Shiho Shiori Shizuka Sumire Tamaki Tomoe Ume Valentina Yoko Yoshie
Yui Yuka Yumi Yuri Élodie Signora""".split())
FIGUR_FIX = {"t_vivace_6": "m", "b_mugen": "m"}

def figur(r):
    if r.get("figur") in ("f", "m"):
        return r["figur"]
    if r["id"] in FIGUR_FIX:
        return FIGUR_FIX[r["id"]]
    if r["name"].split()[0] in FEMALE_NAMES:
        return "f"
    t = (r.get("desc") or {}).get("de", "")
    if re.match(r"\s*(Eine|Die)\b", t):
        return "f"
    fem = len(re.findall(r"(?:^|[.!?]\s+)Sie\b|\b(?:ihr|ihre|ihren|ihrem|ihrer)\b", t))
    mal = len(re.findall(r"(?:^|[.!?]\s+)Er\b|\b(?:sein|seine|seinen|seinem|seiner)\b", t))
    return "f" if fem > mal else "m"

# Teile, die zur Beschreibung passen (deutscher Text + Spitzname). Erste passende Regel je Slot gilt.
HINTS = [
    (r"sonnenbrille", "brille", "sonne"),
    (r"lehrer|nachhilfe|mathe|buchhalt|clubkasse", "brille", "rund"),
    (r"overall|mechaniker|schraubt|werkstatt|schweißt", "jacke", "overall"),
    (r"pelz", "jacke", "pelz"),
    (r"lederjacke|rocker", "jacke", "leder"),
    (r"soldat|stützpunkt|army|marine|dient seit", "jacke", "militaer"),
    (r"surf|hawaii|kalifornien", "jacke", "hawaii"),
    (r"büro|aktentasche|bank|firmenwagen|unternehmer", "jacke", "anzug"),
    (r"student|studier", "jacke", "hoodie"),
    (r"haarspray", "haare", "wellen"),
    (r"\btolle\b", "haare", "tolle"),
    (r"ramen|koch|bude", "haare", "stirnband"),
    (r"raucht|zigarette", "extra", "zigarette"),
    (r"zahnstocher", "extra", "zahnstocher"),
    (r"zahnarzt|\barzt|krankenschwester", "extra", "maske"),
    (r"\bfunk", "extra", "headset"),
    (r"kopfhörer|eurobeat|kassette|tape|walkman", "hals", "kopfhoerer"),
    (r"onsen|handtuch", "hals", "handtuch"),
    (r"\bopa\b|\boma\b|großvater|großmutter|rentner|enkel|älterer herr", "haarfarbe", "silber"),
]

def hints(r, fig):
    t = ((r.get("desc") or {}).get("de", "") + " " + (r.get("nick") or {}).get("de", "")).lower()
    out = {}
    for pat, slot, val in HINTS:
        if slot not in out and re.search(pat, t):
            if slot == "jacke" and val == "anzug" and fig == "f":
                val = "kostuem"
            out[slot] = val
    return out

data = json.load(open(SRC, encoding="utf-8"))
out = {
    "teams": [{k: t.get(k) for k in ("id", "name", "jp", "color")} for t in data["teams"]],
    "rivals": [],
}
for r in data["rivals"]:
    e = {k: r[k] for k in ("id", "name", "nick", "team", "lines", "silhouette") if k in r}
    e["figur"] = figur(r)
    h = hints(r, e["figur"])
    if h:
        e["hints"] = h
    for flag in ("leader", "wanderer", "boss", "final"):
        if r.get(flag):
            e[flag] = True
    out["rivals"].append(e)

with open(os.path.join(HERE, "rivals_data.js"), "w", encoding="utf-8") as f:
    f.write("// Automatisch erzeugt von build_data.py aus rivals.json. Nicht von Hand bearbeiten.\n")
    f.write("window.HB_RIVALS = ")
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    f.write(";\n")
print(len(out["rivals"]), "Rivalen ->", os.path.join(HERE, "rivals_data.js"))
