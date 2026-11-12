"""20 Ränge statt 15 (Alex 2026-11-04).

Die 15 alten Ränge behalten ihren Ruf-Wert, dazwischen kommen 5 neue. Damit verschieben sich die Rang-Nummern
(Index ab 0). OLD_TO_NEW übersetzt einen alten Index in den neuen, damit alles beim gleichen Ruf frei wird wie vorher.
maxRank (bis einschließlich) wird auf den letzten Rang vor dem nächsten alten Rang gesetzt.

build.py benutzt das bei jedem Lauf (Crew-Stufen und Bedingungen schreibt der Generator mit alten Nummern).
Einmal von Hand: python3 tools/generator/ranks20.py migrate  (übersetzt die Daten-JSONs und base/rivals.json, nur einmal!)
"""
import json, os, re, sys

OLD_TO_NEW = [0, 1, 2, 3, 5, 6, 7, 8, 10, 11, 13, 14, 16, 18, 19]
# (Position im neuen Index, Ruf, de, en, jp)
NEW_RANKS = [
    (4, 2050, 'Spurwechsler', 'Lane Changer', '車線変更師'),
    (9, 5250, 'Mitternachtsklinge', 'Midnight Blade', '真夜中の刃'),
    (12, 7150, 'Ringbrecher', 'Loop Breaker', '環状破り'),
    (15, 9300, 'Sturmläufer', 'Storm Runner', '嵐走り'),
    (17, 10400, 'Phantom des Rings', 'Loop Phantom', '環状の幻'),
]


def new_min(k):
    k = int(k)
    return OLD_TO_NEW[min(max(k, 0), len(OLD_TO_NEW) - 1)]


def new_max(k):
    k = int(k)
    if k + 1 >= len(OLD_TO_NEW): return OLD_TO_NEW[-1]
    return OLD_TO_NEW[max(k + 1, 0)] - 1


def expand_ranks(ranks):
    """15 Ränge -> 20 (neue an ihren Platz). Schon erweiterte Listen bleiben."""
    if len(ranks) != len(OLD_TO_NEW): return ranks
    out = list(ranks)
    for pos, rep, de, en, jp in NEW_RANKS:
        out.insert(pos, {'rep': rep, 'name': {'de': de, 'en': en}, 'jp': jp})
    return out


def remap(obj):
    """minRank/maxRank überall in einer JSON-Struktur übersetzen."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == 'minRank' and isinstance(v, (int, float)) and not isinstance(v, bool): obj[k] = new_min(v)
            elif k == 'maxRank' and isinstance(v, (int, float)) and not isinstance(v, bool): obj[k] = new_max(v)
            else: remap(v)
    elif isinstance(obj, list):
        for v in obj: remap(v)
    return obj


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'migrate':
    here = os.path.dirname(os.path.abspath(__file__))
    data = os.path.join(here, '..', '..', 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data')
    files = [os.path.join(data, f) for f in ('rivals.json', 'dealer.json', 'tuning.json', 'board.json', 'crewbattle.json', 'music.json')]
    files.append(os.path.join(here, 'base', 'rivals.json'))
    for p in files:
        raw = open(p, encoding='utf-8').read()
        d = json.loads(raw)
        if 'ranks' in d:
            if len(d['ranks']) != len(OLD_TO_NEW): print('schon migriert?', p); continue
            d['ranks'] = expand_ranks(d['ranks'])
            remap(d)
            with open(p, 'w', encoding='utf-8') as f: f.write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
        else:
            # Formatierung der Datei behalten: nur die Zahlen ersetzen
            raw = re.sub(r'("minRank"\s*:\s*)(-?\d+)', lambda m: m.group(1) + str(new_min(m.group(2))), raw)
            raw = re.sub(r'("maxRank"\s*:\s*)(-?\d+)', lambda m: m.group(1) + str(new_max(m.group(2))), raw)
            json.loads(raw)
            with open(p, 'w', encoding='utf-8') as f: f.write(raw)
        print('migriert', os.path.relpath(p))
