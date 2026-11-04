import base64, re
from shard import spear, d
from flame import tongue
W, H = 1300, 900
SX, SY = 0, 0        # Seitenansicht links (893x217, Front links)
TX, TY = 950, 0      # Draufsicht (343x893, Front oben)
def b64(p): return base64.b64encode(open(p, 'rb').read()).decode()
pink, shad = [], []
def mv(p, ox, oy, fx=False):
    def f(m):
        x, y = float(m.group(1)), float(m.group(2))
        if fx: x = 343 - x
        return f'{x + ox:.1f} {y + oy:.1f}'
    return re.sub(r'(-?\d+\.?\d*) (-?\d+\.?\d*)', f, p)
def add(paths, ox, oy, sh=(3, 4), fx=False):
    for p in paths:
        pink.append(mv(p, ox, oy, fx)); shad.append(mv(p, ox + sh[0], oy + sh[1], fx))
cut = []
def addcut(p, ox, oy, fx=False): cut.append(mv(p, ox, oy, fx))
# --- Seite (ppm 200, Front links): Flammen wachsen hinter dem vorderen Radlauf und laufen nach hinten aus ---
F = [
    # Hauptstrang: ab Scheinwerfer ueber den Radlauf, ueber die Tuer bis in den hinteren Kotfluegel, Ende rollt sich ein
    tongue([(40, 120), (150, 102), (260, 104), (380, 99), (500, 96), (630, 96), (750, 86), (830, 80), (862, 92), (850, 100)], 21, head=0.4, bulge=0.5),
    # Zungen zweigen weich aus dem Hauptstrang ab und laufen nach hinten aus
    tongue([(240, 106), (300, 110), (390, 120), (490, 124), (580, 122), (660, 108), (700, 104), (716, 114)], 17, head=0.3),
    tongue([(255, 108), (320, 120), (400, 142), (470, 150), (540, 148), (590, 134), (606, 140)], 15, head=0.3),
    tongue([(270, 110), (330, 130), (390, 160), (440, 174), (482, 174), (506, 162), (500, 156)], 12, head=0.3),
]
add(F, SX, SY)
# Aussparungen in Farbe 1: duenne fliessende Schlitze in den breiten Zungen

# --- Haube von oben (Front oben): zwei schlanke Flammen an den Kanten, Spitzen nach hinten ---
hood = [tongue([(40, 24), (48, 100), (58, 190), (72, 268)], 22, head=0.25, start=0.0, bulge=0.6),
        tongue([(60, 40), (70, 110), (82, 170), (92, 222)], 14, head=0.2, start=0.0)]
add(hood, TX, TY); add(hood, TX, TY, sh=(-3, 4), fx=True)

def svg(show_guide):
    vis = '' if show_guide else ' style="display:none"'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<g id="Hilfe_Auto_ausblenden"{vis}>
<image x="{SX}" y="{SY}" width="893" height="217" opacity="0.6" href="data:image/png;base64,{b64('bx_L.png')}"/>
<image x="{TX}" y="{TY}" width="343" height="893" opacity="0.6" href="data:image/png;base64,{b64('bx_T.png')}"/>
</g>
<g id="Farbe_3_Kontur_BLAU">{''.join(f'<path fill="#0000ff" d="{p}"/>' for p in shad)}</g>
<g id="Farbe_2_Tribal_GRUEN">{''.join(f'<path fill="#00ff00" d="{p}"/>' for p in pink)}</g>
<g id="Farbe_1_Aussparung_ROT">{''.join(f'<path fill="#ff0000" d="{p}"/>' for p in cut)}</g>
</svg>'''
open('bx_streetdrift_a.svg', 'w').write(svg(False))
open('bx_streetdrift_a_guide.svg', 'w').write(svg(True))
