"""Schreibt rivals_data.js aus der rivals.json der Mod, damit silhouetten.html
ohne Webserver (file://) alle Gegner kennt. Aufruf: python build_data.py"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "lua", "ge", "extensions", "hashiriyaBattle", "data", "rivals.json")

data = json.load(open(SRC, encoding="utf-8"))
out = {
    "teams": [{k: t.get(k) for k in ("id", "name", "jp", "color")} for t in data["teams"]],
    "rivals": [],
}
for r in data["rivals"]:
    e = {k: r[k] for k in ("id", "name", "nick", "team", "lines", "silhouette") if k in r}
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
