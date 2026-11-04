"""Übernimmt Community-Wanderer in die Mod: aus dem Wanderer-Builder oder aus dem alten Google-Formular.

    python3 tools/community/import_wanderer.py <datei.json ...>          Dateien aus dem Wanderer-Builder
    python3 tools/community/import_wanderer.py <ordner oder zip>         Ordner/ZIP mit Builder-Dateien
                                                                          oder Export des Google-Formulars

Wanderer-Builder (tools/community/Hashiriya-Wanderer-Builder.html): jede Datei hashiriya_wanderer_<name>.json
enthält den fertigen rivals.json-Eintrag (mit Avatar "silhouette", Siegel "seal", Kennzeichen, Credits) und die .pc-Config.
Was passiert:
  - community_wanderer.json  -> neue/aktualisierte Wanderer in data/rivals.json (nach id; vorhandene werden ersetzt)
  - vehicles/<model>/*.pc    -> vehicles/<model>/ im Mod-Ordner (BeamNG findet die Configs dort)
  - credits.json             -> "community" in data/credits.json (nach id)
Kontaktdaten (_kontakt) kommen nicht in die Mod. Neue Wanderer zählen für tools/generator/protect.py als Handeintrag
und bleiben beim nächsten Generatorlauf erhalten.
Danach: Porträts neu erzeugen (tools/silhouette/build_data.py, dann tools/silhouette/vc/rivals_v2.py und tools/silhouette/vc/build_tool.py)
und die Siegel (tools/logos/build_logos.py, liest "seal" aus rivals.json).
"""
import json, os, re, shutil, sys, tempfile, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data')
PLATE = re.compile(r'^([0-9]{3}/|[0-9]{2}//)([0-9]{2}-[0-9]{2}|[0-9.]{2} [0-9.]{2})$')


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def find(root, name):
    for d, _, files in os.walk(root):
        if name in files:
            return os.path.join(d, name)
    return None


def builder_files(paths):
    """Alle Dateien aus dem Wanderer-Builder (format == hashiriya-wanderer) in Dateien/Ordnern."""
    out = []
    for p in paths:
        files = [p] if os.path.isfile(p) else [os.path.join(d, f) for d, _, fs in os.walk(p) for f in fs if f.lower().endswith('.json')]
        for f in sorted(files):
            try:
                j = load(f)
            except (ValueError, UnicodeDecodeError):
                continue
            if isinstance(j, dict) and j.get('format') == 'hashiriya-wanderer' and isinstance(j.get('rival'), dict):
                out.append((f, j))
    return out


HOURS = lambda h: f'{h:02d}:00'


def make_hint(r, names):
    """Tipp-Text (für Tipps/Lexikon) aus den Bedingungen, wenn der Eintrag keinen hat."""
    c = r.get('conditions') or {}
    de, en = [], []
    if c.get('beatenTeam'):
        n = names.get(c['beatenTeam'], c['beatenTeam'])
        de.append(f'Erst nach dem Sieg über {n}'); en.append(f'Only after beating {n}')
    for rid in c.get('beatenRivals') or []:
        n = names.get(rid, rid)
        de.append(f'Erst nach dem Sieg gegen {n}'); en.append(f'Only after beating {n}')
    if c.get('playerModel'):
        de.append(f'nur wenn du einen {c["playerModel"]} fährst'); en.append(f'only if you drive a {c["playerModel"]}')
    if c.get('playerPart'):
        de.append(f'nur mit „{c["playerPart"]}“ verbaut'); en.append(f'only with "{c["playerPart"]}" installed')
    if c.get('naOnly'):
        de.append('nur gegen Saugmotoren'); en.append('only against naturally aspirated cars')
    if c.get('forcedInduction'):
        de.append('nur gegen Turbo oder Kompressor'); en.append('only against turbo or supercharged cars')
    if c.get('manual'):
        de.append('nur gegen Schaltwagen'); en.append('only against manual gearboxes')
    if c.get('paintColor'):
        pc = c['paintColor'] if isinstance(c['paintColor'], list) else [c['paintColor']]
        FDE = {'red': 'rot', 'yellow': 'gelb', 'green': 'grün', 'blue': 'blau', 'purple': 'lila', 'white': 'weiß', 'silver': 'silber', 'grey': 'grau', 'black': 'schwarz'}
        de.append('nur gegen Autos in ' + '/'.join(FDE.get(x, x) for x in pc)); en.append('only against ' + '/'.join(pc) + ' cars')
    if c.get('maxPower'):
        de.append(f'nur gegen Autos bis {c["maxPower"]} PS'); en.append(f'only against cars up to {c["maxPower"]} hp')
    if c.get('minPower'):
        de.append(f'nur gegen Autos ab {c["minPower"]} PS'); en.append(f'only against cars from {c["minPower"]} hp')
    if c.get('minStreak'):
        de.append(f'nach {c["minStreak"]} Siegen in Folge'); en.append(f'after {c["minStreak"]} wins in a row')
    if c.get('weekday'):
        wd = c['weekday'] if isinstance(c['weekday'], list) else [c['weekday']]
        D = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']; E = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        de.append('nur ' + '/'.join(D[int(d) - 1] for d in wd)); en.append('only on ' + '/'.join(E[int(d) - 1] for d in wd))
    if c.get('visitedPa'):
        v = c['visitedPa'] if isinstance(c['visitedPa'], list) else [c['visitedPa']]
        de.append('nach einem Besuch in ' + ', '.join(v)); en.append('after a visit to ' + ', '.join(v))
    if c.get('minDay'):
        de.append(f'ab Nacht {c["minDay"]}'); en.append(f'from night {c["minDay"]} on')
    if c.get('hours'):
        a, b = c['hours']
        de.append(f'zwischen {HOURS(a)} und {HOURS(b)} Uhr'); en.append(f'between {HOURS(a)} and {HOURS(b)}')
    if not de:
        return {'de': 'Fährt nachts allein auf der C1.', 'en': 'Drives the C1 alone at night.'}
    cap = lambda xs: (xs[0][0].upper() + xs[0][1:] + (', ' + ', '.join(xs[1:]) if xs[1:] else '') + '.')
    return {'de': cap(de), 'en': cap(en)}


def main(src, *more):
    tmp = None
    if zipfile.is_zipfile(src):
        tmp = tempfile.mkdtemp()
        zipfile.ZipFile(src).extractall(tmp)
        src = tmp
    try:
        pcs = {}  # id -> .pc-Inhalt (Builder)
        built = builder_files([src, *more])
        if built:
            base = None
            new = []
            for f, j in built:
                r = dict(j['rival'])
                if not re.match(r'^w_[a-z0-9_]+$', r.get('id', '')):
                    print(f'  ÜBERSPRUNGEN {os.path.basename(f)}: ungültige id {r.get("id")}')
                    continue
                if isinstance(j.get('pc'), dict):
                    pcs[r['id']] = j['pc']
                new.append(r)
            print(f'{len(new)} Datei(en) aus dem Wanderer-Builder')
        else:
            wpath = find(src, 'community_wanderer.json')
            if not wpath:
                raise SystemExit('Weder Wanderer-Builder-Dateien noch community_wanderer.json gefunden')
            base = os.path.dirname(wpath)
            new = load(wpath)

        # Configs kopieren / schreiben
        copied, missing = [], []
        for r in new:
            if r['id'] in pcs:
                rel = r['config'].replace('\\', '/')
                dst = os.path.join(ROOT, *rel.split('/'))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with open(dst, 'w', encoding='utf-8') as f:
                    json.dump(pcs[r['id']], f, ensure_ascii=False, indent=2)
                    f.write('\n')
                copied.append(rel)
                continue
            cfg = r.get('config')
            if not cfg:
                missing.append(r['id'] + ' (kein config-Pfad)')
                continue
            rel = cfg.replace('\\', '/')
            srcpc = os.path.join(base, *rel.split('/'))
            if not os.path.exists(srcpc):
                missing.append(f"{r['id']} ({rel})")
                continue
            pc = load(srcpc)
            if not isinstance(pc.get('parts'), dict):
                missing.append(f"{r['id']} ({rel}: keine parts)")
                continue
            dst = os.path.join(ROOT, *rel.split('/'))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(srcpc, dst)
            copied.append(rel)

        # rivals.json: nach id einfügen/ersetzen, vor den Bossen
        rpath = os.path.join(DATA, 'rivals.json')
        rivals = load(rpath)
        lst = rivals['rivals']
        ids = {x['id']: i for i, x in enumerate(lst)}
        added, replaced, warn = 0, 0, []
        names = {t['id']: (t['name'] if isinstance(t['name'], str) else t['name'].get('en')) for t in rivals['teams']}
        names.update({x['id']: x.get('name') for x in lst})
        credits_new = []
        for r in new:
            r = {k: v for k, v in r.items() if k != '_kontakt'}
            if not r.get('hint'):
                r['hint'] = make_hint(r, names)
            if r.get('credit'):
                credits_new.append({'name': r['credit'].get('name', ''), 'role': r['credit'].get('role', ''), 'wanderer': r.get('name'), 'id': r['id']})
            if not PLATE.match(r.get('plate', {}).get('text', '')):
                warn.append(f"{r['id']}: Kennzeichen {r.get('plate')} prüfen")
            if r['id'] in ids and not lst[ids[r['id']]].get('community'):
                warn.append(f"{r['id']}: ID gehört schon einem normalen Rivalen, übersprungen")
                continue
            if r['id'] in ids:
                lst[ids[r['id']]] = r
                replaced += 1
            else:
                pos = next((i for i, x in enumerate(lst) if x.get('boss')), len(lst))
                lst.insert(pos, r)
                ids = {x['id']: i for i, x in enumerate(lst)}
                added += 1
        with open(rpath, 'w', encoding='utf-8') as f:
            json.dump(rivals, f, ensure_ascii=False, indent=2)
            f.write('\n')

        # credits.json
        cpath = os.path.join(DATA, 'credits.json')
        credits = load(cpath)
        cpath_new = None if built else find(src, 'credits.json')
        incoming = load(cpath_new).get('community', []) if cpath_new else (credits_new if built else [])
        if incoming:
            have = {c.get('id'): i for i, c in enumerate(credits.get('community', []))}
            for c in incoming:
                if c.get('id') in have:
                    credits['community'][have[c['id']]] = c
                else:
                    credits.setdefault('community', []).append(c)
            with open(cpath, 'w', encoding='utf-8') as f:
                json.dump(credits, f, ensure_ascii=False, indent=2)
                f.write('\n')

        print(f'Wanderer: {added} neu, {replaced} aktualisiert. Configs kopiert: {len(copied)}')
        for c in copied:
            print('  ' + c)
        for m in missing:
            print('  FEHLT Config: ' + m)
        for w in warn:
            print('  ACHTUNG ' + w)
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(*sys.argv[1:])
