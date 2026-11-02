"""Schützt Handänderungen an erzeugten Dateien (rivals.json, chat.json).

base/<datei> ist der Stand, den der Generator zuletzt geschrieben hat. Alles, was in der
echten Datei davon abweicht, ist eine Handänderung (z. B. von Alex). Vor dem Schreiben einer
neuen Version werden diese Änderungen auf die neue Version übertragen:
  - geänderte Felder bleiben geändert (auch wenn der Generator dort etwas Neues hat; das wird gemeldet)
  - von Hand hinzugefügte Rivalen/Crews/Einträge bleiben erhalten
  - von Hand gelöschte bleiben gelöscht
Listen mit "id" (rivals, teams, talk, nicknames ...) werden pro Eintrag verglichen, andere Listen als Ganzes.

Nutzung im Generator:   write_protected(path, new_data)
Von Hand prüfen:        python3 tools/generator/protect.py check
"""
import json, os, sys, copy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data')
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'base')
FILES = ['rivals.json', 'chat.json']


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def dump(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def is_id_list(v):
    return isinstance(v, list) and v and all(isinstance(x, dict) and 'id' in x for x in v)


def diff(base, cur, path=()):
    """Liste von (pfad, art, wert, davor_id). art: set | del | add"""
    out = []
    if isinstance(base, dict) and isinstance(cur, dict):
        for k in cur:
            if k not in base:
                out.append((path + (k,), 'set', cur[k], None))
            else:
                out += diff(base[k], cur[k], path + (k,))
        for k in base:
            if k not in cur:
                out.append((path + (k,), 'del', None, None))
    elif is_id_list(base) and is_id_list(cur):
        bmap = {x['id']: x for x in base}
        cmap = {x['id']: x for x in cur}
        prev = None
        for x in cur:
            if x['id'] not in bmap:
                out.append((path + (('id', x['id']),), 'add', x, prev))
            else:
                out += diff(bmap[x['id']], x, path + (('id', x['id']),))
            prev = x['id']
        for x in base:
            if x['id'] not in cmap:
                out.append((path + (('id', x['id']),), 'del', None, None))
    elif base != cur:
        out.append((path, 'set', cur, None))
    return out


def _step(obj, key):
    if isinstance(key, tuple):
        for i, x in enumerate(obj):
            if isinstance(x, dict) and x.get('id') == key[1]:
                return x, i
        return None, None
    if isinstance(obj, dict) and key in obj:
        return obj[key], key
    return None, None


def get(obj, path):
    for k in path:
        if obj is None:
            return None
        obj, _ = _step(obj, k)
    return obj


def show(path):
    return '/'.join(k[1] if isinstance(k, tuple) else str(k) for k in path)


def apply(new, changes, base):
    """Überträgt Handänderungen auf new. Gibt Meldungen zurück."""
    notes = []
    for path, kind, value, after in changes:
        parent = get(new, path[:-1]) if len(path) > 1 else new
        if parent is None:
            notes.append(f'NICHT übernommen (gibt es im Generator nicht mehr): {show(path)}')
            continue
        key = path[-1]
        if kind == 'add':
            if any(isinstance(x, dict) and x.get('id') == key[1] for x in parent):
                notes.append(f'Hand-Eintrag {key[1]} gibt es jetzt auch im Generator, Hand-Version bleibt')
                _, i = _step(parent, key)
                parent[i] = copy.deepcopy(value)
                continue
            pos = len(parent)
            if after is not None:
                _, i = _step(parent, ('id', after))
                if i is not None:
                    pos = i + 1
            parent.insert(pos, copy.deepcopy(value))
            notes.append(f'Hand-Eintrag behalten: {show(path)}')
        elif kind == 'del':
            cur, i = _step(parent, key)
            if i is not None:
                del parent[i]
                notes.append(f'Hand-Löschung behalten: {show(path)}')
        else:
            gen = get(new, path)
            if gen is not None and gen != get(base, path) and gen != value:
                notes.append(f'KONFLIKT {show(path)}: Generator neu {json.dumps(gen, ensure_ascii=False)[:80]}, Hand {json.dumps(value, ensure_ascii=False)[:80]} -> Hand bleibt')
            if isinstance(key, tuple):
                _, i = _step(parent, key)
                if i is not None:
                    parent[i] = copy.deepcopy(value)
            else:
                parent[key] = copy.deepcopy(value)
    return notes


def manual_changes(name):
    base_path, cur_path = os.path.join(BASE, name), os.path.join(DATA, name)
    if not os.path.exists(base_path) or not os.path.exists(cur_path):
        return None, []
    base = load(base_path)
    return base, diff(base, load(cur_path))


def write_protected(name, new):
    """Neue Generator-Version schreiben, Handänderungen behalten, Basis aktualisieren."""
    base, changes = manual_changes(name)
    gen = copy.deepcopy(new)
    notes = apply(new, changes, base) if changes else []
    dump(os.path.join(DATA, name), new)
    dump(os.path.join(BASE, name), gen)
    print(f'{name}: {len(changes)} Handänderung(en) übernommen')
    for n in notes:
        print('  ' + n)
    return notes


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'check':
        for name in FILES:
            _, ch = manual_changes(name)
            print(f'{name}: {len(ch)} Handänderung(en)')
            for path, kind, value, _ in ch[:200]:
                print(f'  {kind:3} {show(path)}' + ('' if kind == 'del' else ' = ' + json.dumps(value, ensure_ascii=False)[:100]))
    elif len(sys.argv) > 1 and sys.argv[1] == 'init':
        os.makedirs(BASE, exist_ok=True)
        for name in FILES:
            dump(os.path.join(BASE, name), load(os.path.join(DATA, name)))
        print('Basis = aktuelle Dateien')
    else:
        print(__doc__)
