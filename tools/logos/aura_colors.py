"""Schreibt die Aura-Farben der Wanderer und Bosse in data/aura.json (Schlüssel "colors").

    python3 tools/logos/aura_colors.py

Crews nehmen ihre Farbe aus rivals.json (teams[].color), Wanderer und Bosse die Farbe ihres Siegels/Emblems
(WANDERERS / BOSSES in build_logos.py). Alles andere in aura.json (Stärken, Lichtgrößen) bleibt unverändert.
Von Hand eingetragene Farben in "colors" bleiben stehen; neue Wanderer bekommen eine Farbe dazu.
"""
import ast, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))


def dicts():
    """WANDERERS und BOSSES aus build_logos.py lesen, ohne es zu importieren (braucht sonst Schriften/fonttools)."""
    tree = ast.parse(open(os.path.join(HERE, 'build_logos.py'), encoding='utf-8').read())
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and getattr(node.targets[0], 'id', '') in ('WANDERERS', 'BOSSES'):
            out[node.targets[0].id] = ast.literal_eval(node.value)
    return out['WANDERERS'], out['BOSSES']

DATA = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data')
AURA = os.path.join(DATA, 'aura.json')


def main():
    aura = json.load(open(AURA, encoding='utf-8'))
    colors = aura.setdefault('colors', {})
    rivals = json.load(open(os.path.join(DATA, 'rivals.json'), encoding='utf-8'))['rivals']
    wanderers, bosses = dicts()
    added = 0
    for r in rivals:
        if not (r.get('wanderer') or r.get('boss')) or r['id'] in colors:
            continue
        col = None
        if r['id'] in bosses:
            col = bosses[r['id']][2]
        elif r['id'] in wanderers:
            col = wanderers[r['id']][1]
        elif isinstance(r.get('seal'), dict) and r['seal'].get('color'):
            col = r['seal']['color']  # Community-Wanderer aus dem Wanderer-Builder: Farbe des Siegels
        if col:
            colors[r['id']] = col
            added += 1
    aura['colors'] = dict(sorted(colors.items()))
    with open(AURA, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(aura, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{AURA}: {added} neue Farben, {len(colors)} insgesamt')


if __name__ == '__main__':
    main()
