"""Release-Build der Mod als ZIP zum Verschicken.

Aufruf (im Mod-Ordner):  python tools/build_release.py "Alpha 0.3"
Ergebnis:                 dist/hashiriya_battle_alpha_0.3.zip

Im ZIP:
- data/build.json mit release = true und modVersion = die angegebene Version
  (Dev- und Cheat-Werkzeuge aus, Release-Sperren an)
- Tastenbelegung ohne Shift+Pos1 (Titelbild-Kamera merken, nur für Entwicklung)
- CHANGELOG_DE.md (aus CHANGELOG.md) und CHANGELOG_EN.md
- ohne tools/, docs/, README.md und andere Entwicklerdateien
Der Mod-Ordner selbst bleibt unverändert (release bleibt dort false).
"""
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INCLUDE = ['lua', 'scripts', 'settings', 'ui', 'art']
EXCLUDE_NAMES = {'logo-source.html', 'LIESMICH.txt', '.DS_Store', 'Thumbs.db'}
BUILD_JSON = 'lua/ge/extensions/hashiriyaBattle/data/build.json'
INPUTMAP = 'settings/inputmaps/keyboard_hashiriya.json'


def release_build_json(text, version):
    data = json.loads(text)
    data['release'] = True
    data['modVersion'] = version
    return json.dumps(data, ensure_ascii=False, indent=2) + '\n'


def release_inputmap(text):
    data = json.loads(text)
    data['bindings'] = [b for b in data.get('bindings', []) if b.get('action') != 'hashiriyaCaptureCamera']
    return json.dumps(data, ensure_ascii=False, indent=2) + '\n'


def main():
    if len(sys.argv) < 2:
        sys.exit('Version fehlt, z. B.: python tools/build_release.py "Alpha 0.3"')
    version = sys.argv[1].strip()
    slug = re.sub(r'[^a-z0-9.]+', '_', version.lower()).strip('_')
    out = ROOT / 'dist' / f'hashiriya_battle_{slug}.zip'
    out.parent.mkdir(exist_ok=True)

    files = []
    for top in INCLUDE:
        for p in sorted((ROOT / top).rglob('*')):
            if p.is_file() and p.name not in EXCLUDE_NAMES:
                files.append(p)

    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in files:
            rel = p.relative_to(ROOT).as_posix()
            if rel == BUILD_JSON:
                z.writestr(rel, release_build_json(p.read_text(encoding='utf-8'), version))
            elif rel == INPUTMAP:
                z.writestr(rel, release_inputmap(p.read_text(encoding='utf-8')))
            else:
                z.write(p, rel)
        z.write(ROOT / 'CHANGELOG.md', 'CHANGELOG_DE.md')
        z.write(ROOT / 'CHANGELOG_EN.md', 'CHANGELOG_EN.md')

    print(f'{out} ({len(files) + 2} Dateien, {out.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
