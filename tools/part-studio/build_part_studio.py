"""Baut die eigenständige Mod "Hashiriya Part Studio" als Zip (für den BeamNG-Ordner mods/).

Aufruf: python tools/part-studio/build_part_studio.py [Zielordner]
Ohne Zielordner landet hashiriya_part_studio.zip in tools/part-studio/dist/.
"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'mod')


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'dist')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, 'hashiriya_part_studio.zip')
    count = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(SRC):
            for f in sorted(files):
                if f in ('Thumbs.db', '.DS_Store'):
                    continue
                full = os.path.join(root, f)
                rel = os.path.relpath(full, SRC).replace(os.sep, '/')
                z.write(full, rel)
                count += 1
    print(f'{count} Dateien -> {out}')


if __name__ == '__main__':
    main()
