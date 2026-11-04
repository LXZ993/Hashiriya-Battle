"""Baut den Wanderer-Builder: eine einzige HTML-Datei zum Verschicken.

    python3 tools/community/build_wanderer_builder.py

Liest:
  - tools/community/wanderer_builder_template.html   (Oberfläche, Texte DE/EN)
  - die Porträt-Teile aus tools/silhouette/vc/        (gleiche Teile wie das Silhouetten-Tool, Bärte inklusive)
  - data/rivals.json                                  (Crews, Leader, Mitglieder, Wanderer, Bosse für die Bedingungen)
Schreibt:
  - tools/community/Hashiriya-Wanderer-Builder.html   (alles drin, läuft offline per Doppelklick)

Die Leute füllen den Builder aus und schicken dir die Datei hashiriya_wanderer_<name>.json.
Die übernimmt tools/community/import_wanderer.py in die Mod.
REGEL (Alex 04.11.2026): Jede Änderung an Avatar-Teilen, Bedingungen (rivals.lua conditionsMet), Wanderer-Feldern
oder am Roster muss auch in den Builder (Vorlage: CG-Liste der Bedingungen, Felder) und die Datei neu gebaut werden.
"""
import datetime, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'silhouette', 'vc'))
import build_tool  # noqa: E402  (Teile + Regeln wie im Silhouetten-Tool)
import rivals_v2  # noqa: E402

RIVALS = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data', 'rivals.json')
C1 = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data', 'maps', 'c1.json')


def name_of(x):
    n = x.get('name', x.get('id'))
    return n.get('en') or n.get('de') if isinstance(n, dict) else n


def main():
    meta, frags = build_tool.bausteine()
    data = json.load(open(RIVALS, encoding='utf-8'))
    teams = [{'id': t['id'], 'name': name_of(t), 'jp': t.get('jp', ''), 'color': t.get('color')} for t in data['teams']]
    tname = {t['id']: t['name'] for t in teams}
    members, leaders, wanderers, bosses = [], [], [], []
    for r in data['rivals']:
        if r.get('community'):
            continue  # andere Einsendungen nicht verraten
        if r.get('boss'):
            bosses.append([r['id'], name_of(r)])
        elif r.get('wanderer'):
            wanderers.append([r['id'], name_of(r)])
        elif r.get('team'):
            (leaders if r.get('leader') else members).append([r['id'], name_of(r), tname.get(r['team'], r['team'])])
    roster = {'teams': teams, 'leaders': leaders, 'members': members, 'wanderers': wanderers, 'bosses': bosses,
              'wandererColors': rivals_v2.WANDERER_COLORS,
              'nicknames': [{'id': n['id'], 'name': n.get('name'), 'desc': n.get('desc')} for n in data.get('nicknames', [])],
              'ranks': [r.get('name') for r in data.get('ranks', [])],
              'pas': [p.get('name') for p in json.load(open(C1, encoding='utf-8')).get('napSpots', []) if p.get('name')]}
    payload = {'meta': meta, 'frags': frags, 'roster': roster}
    tpl = open(os.path.join(HERE, 'wanderer_builder_template.html'), encoding='utf-8').read()
    version = datetime.date.today().isoformat()
    html = tpl.replace('/*__DATA__*/null', json.dumps(payload, ensure_ascii=False, separators=(',', ':'))).replace('/*__VERSION__*/', version)
    out = os.path.join(HERE, 'Hashiriya-Wanderer-Builder.html')
    open(out, 'w', encoding='utf-8', newline='\n').write(html)
    print(f'{out}: {len(frags)} Bausteine, {len(teams)} Crews, {len(wanderers)} Wanderer, {len(html) // 1024} KB')


if __name__ == '__main__':
    main()
