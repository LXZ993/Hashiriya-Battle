"""Übernimmt den Export des Google-Formulars (Ordner "Hashiriya Battle – Community Import") in die Mod.

    python3 tools/community/import_wanderer.py <ordner oder zip>

Was passiert:
  - community_wanderer.json  -> neue/aktualisierte Wanderer in data/rivals.json (nach id; vorhandene werden ersetzt)
  - vehicles/<model>/*.pc    -> vehicles/<model>/ im Mod-Ordner (BeamNG findet die Configs dort)
  - credits.json             -> "community" in data/credits.json (nach id)
Kontaktdaten (_kontakt) kommen nicht in die Mod. Neue Wanderer zählen für tools/generator/protect.py als Handeintrag
und bleiben beim nächsten Generatorlauf erhalten.
Danach: Porträts neu erzeugen (tools/silhouette/build_data.py, dann tools/silhouette/vc/rivals_v2.py und tools/silhouette/vc/build_tool.py).
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


def main(src):
    tmp = None
    if zipfile.is_zipfile(src):
        tmp = tempfile.mkdtemp()
        zipfile.ZipFile(src).extractall(tmp)
        src = tmp
    try:
        wpath = find(src, 'community_wanderer.json')
        if not wpath:
            raise SystemExit('community_wanderer.json nicht gefunden')
        base = os.path.dirname(wpath)
        new = load(wpath)

        # Configs kopieren
        copied, missing = [], []
        for r in new:
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
        for r in new:
            r = {k: v for k, v in r.items() if k != '_kontakt'}
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
        cpath_new = find(src, 'credits.json')
        if cpath_new:
            have = {c.get('id'): i for i, c in enumerate(credits.get('community', []))}
            for c in load(cpath_new).get('community', []):
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
    main(sys.argv[1])
