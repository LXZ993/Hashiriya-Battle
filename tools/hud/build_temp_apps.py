"""Erzeugt die Einzel-Apps HashiriyaWaterTemp und HashiriyaOilTemp aus HashiriyaTemps/app.js.

JDMArsch 08.11.2026: Wasser und Öl sollen einzelne Apps sein (einzeln verschiebbar im UI-Editor).
Die kombinierte App HashiriyaTemps bleibt als Vorlage und für alte Layouts erhalten.

Aufruf im Mod-Ordner:  python tools/hud/build_temp_apps.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APPS = os.path.join(ROOT, 'ui', 'modules', 'apps')

GW = "    { key: 'water', cx: 66,  field: 'watertemp', min: 40, max: 140, cold: 70, warm: 105, red: 120, labelKey: 'hud.water', label: 'Wasser' },\n"
GO = "    { key: 'oil',   cx: 194, field: 'oiltemp',   min: 40, max: 160, cold: 70, warm: 130, red: 150, labelKey: 'hud.oil',   label: 'Öl' }\n"

TARGETS = [
    # Ordner, Directive, Schlüssel, Name, Beschreibung, Platz rechts
    ('HashiriyaWaterTemp', 'hashiriyaWaterTemp', 'water', 'Hashiriya Battle: Wassertemperatur',
     'Kühlwassertemperatur als kleine Rundanzeige im Stil des Hashiriya-Drehzahlmessers. Blendet ohne Verbrennungsmotor aus.', '400px'),
    ('HashiriyaOilTemp', 'hashiriyaOilTemp', 'oil', 'Hashiriya Battle: Öltemperatur',
     'Öltemperatur als kleine Rundanzeige im Stil des Hashiriya-Drehzahlmessers. Blendet ohne Verbrennungsmotor aus.', '275px'),
]


def make(src, directive, key):
    s = src.replace(".directive('hashiriyaTemps', [function () {", ".directive('%s', [function () {" % directive)
    assert GW in s and GO in s, 'GAUGES in HashiriyaTemps/app.js geändert, Skript anpassen'
    s = s.replace(GW + GO, GW.rstrip(',\n') + '\n' if key == 'water' else GO.replace('cx: 194', 'cx: 66 '))
    s = s.replace('viewBox="0 0 260 130"', 'viewBox="0 0 132 130"')
    gid = 'hxwBg' + key.capitalize()
    s = s.replace('id="hxwBg"', 'id="%s"' % gid).replace('url(#hxwBg)', 'url(#%s)' % gid)
    has = "var has = el && (Number(el.oiltemp) > 0 || Number(el.watertemp) > 0)"
    assert has in s
    s = s.replace(has, "var has = el && Number(el.%s) > 0" % ('watertemp' if key == 'water' else 'oiltemp'))
    s = s.replace(
        "// Hashiriya Battle: Öl- und Wassertemperatur im Stil des eigenen Drehzahlmessers (HashiriyaTacho).",
        "// Hashiriya Battle: %s im Stil des eigenen Drehzahlmessers (HashiriyaTacho).\n"
        "// Eigene App seit 08.11.2026 (JDMArsch: Wasser und Öl einzeln verschiebbar). Erzeugt aus HashiriyaTemps/app.js\n"
        "// mit tools/hud/build_temp_apps.py, Änderungen bitte dort bzw. in HashiriyaTemps machen und neu erzeugen."
        % ('Wassertemperatur' if key == 'water' else 'Öltemperatur'))
    return s


def main():
    src = open(os.path.join(APPS, 'HashiriyaTemps', 'app.js'), encoding='utf-8').read()
    for folder, directive, key, name, desc, right in TARGETS:
        d = os.path.join(APPS, folder)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, 'app.js'), 'w', encoding='utf-8') as f:
            f.write(make(src, directive, key))
        dom = re.sub(r'([A-Z])', lambda m: '-' + m.group(1).lower(), directive)
        app = {
            'domElement': '<%s></%s>' % (dom, dom), 'name': name, 'types': ['ui.apps.categories.vehicle_info'],
            'description': desc,
            'css': {'right': right, 'bottom': '262px', 'width': '125px', 'height': '125px'},
            'preserveAspectRatio': True, 'author': 'Hashiriya Battle', 'version': '1.0',
            'directive': directive, 'appName': directive, 'category': 'Hashiriya Battle',
            'isAuxiliary': False, 'interactive': 'no',
        }
        with open(os.path.join(d, 'app.json'), 'w', encoding='utf-8') as f:
            f.write(json.dumps(app, ensure_ascii=False, indent=2) + '\n')
        print('geschrieben:', folder)


if __name__ == '__main__':
    main()
