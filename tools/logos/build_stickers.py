"""Rendert alle Logos aus art/logos/*.svg als PNG-Aufkleber nach art/stickers/<name>.png (512 px, transparent).

    python3 tools/logos/build_stickers.py

Die Aufkleber nutzt stickers.lua (Sticker-Modus in der Garage) und das Back-Werkzeug für die Rivalen-Autos.
BeamNG kann keine SVG als Decal-Textur laden, darum PNG. Neu ausführen, wenn sich Logos ändern (nach build_logos.py).
Braucht: pip install cairosvg pillow
"""
import glob, io, os
import cairosvg
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'art', 'logos')
OUT = os.path.join(ROOT, 'art', 'stickers')
SIZE = 512


def main():
    os.makedirs(OUT, exist_ok=True)
    n, total = 0, 0
    for svg in sorted(glob.glob(os.path.join(SRC, '*.svg'))):
        name = os.path.splitext(os.path.basename(svg))[0]
        png = cairosvg.svg2png(url=svg, output_width=SIZE, output_height=SIZE)
        im = Image.open(io.BytesIO(png)).convert('RGBA')
        # an den Inhalt anpassen (quadratisch, kleiner Rand), damit Größe auf dem Auto gleich wirkt
        bb = im.getchannel('A').getbbox()
        if bb:
            w, h = bb[2] - bb[0], bb[3] - bb[1]
            side = int(max(w, h) * 1.06)
            canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
            canvas.paste(im.crop(bb), ((side - w) // 2, (side - h) // 2))
            im = canvas.resize((SIZE, SIZE), Image.LANCZOS)
        path = os.path.join(OUT, name + '.png')
        # Palette (256 Farben mit Transparenz) statt RGBA: etwa ein Fünftel der Größe, bei Logos kein sichtbarer Unterschied
        im.quantize(colors=256, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)
        n += 1
        total += os.path.getsize(path)
    print(f'{OUT}: {n} Aufkleber, {total // 1024} KB')


if __name__ == '__main__':
    main()
