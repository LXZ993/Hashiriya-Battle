"""Übersichtsbild aller Liveries (2 Ansichten je Livery) für Alex."""
import os, sys
from PIL import Image, ImageDraw
from livery import WORK, font
from designs import LIVERIES
out = sys.argv[1]
TW, TH = 760, 470; COLS = 4
items = [(f'{m}_{sid}', de, m) for sid, m, fn, de, en in LIVERIES]
MOD = {'pessima': 'Ibishu Pessima Mk1', 'midsize': 'Ibishu Pessima Mk2', 'sunburst2': 'Hirochi Sunburst', 'pickup': 'Gavril D-Series', 'van': 'Gavril H-Series'}
rows = (len(items) * 2 + COLS - 1) // COLS
S = Image.new('RGB', (TW * COLS, TH * rows + 90), (22, 24, 29)); d = ImageDraw.Draw(S)
d.text((30, 45), 'Hashiriya Battle – Liveries für PA-Arbeiter und Polizei (Entwurf 1)', font=font('jp', 44), fill=(240, 240, 240), anchor='lm')
for i, (key, de, m) in enumerate(items):
    for j, v in enumerate((0, 2)):
        k = i * 2 + j; r, c = divmod(k, COLS)
        im = Image.open(os.path.join(WORK, 'shots', f'{key}_{v}.png')).crop((140, 90, 1060, 660) if v == 0 else (60, 120, 1140, 790)).resize((TW, int(TW * 570 / 920)))
        S.paste(im.crop((0, 0, TW, TH)), (c * TW, 90 + r * TH))
        if v == 0:
            d.rectangle([c * TW, 90 + r * TH, c * TW + TW * 2, 90 + r * TH + 46], fill=(0, 0, 0))
            d.text((c * TW + 16, 90 + r * TH + 23), f'{de}  ·  {MOD[m]}', font=font('jp', 26), fill=(255, 255, 255), anchor='lm')
S.save(out, quality=88)
print(S.size)
