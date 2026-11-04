# Street Drift A: fliessendes Flammen-Tribal (von Alex freigegeben 2026-11-04)
from vcsvg import Doc
from flame import tongue
import re
D = Doc()
def sh(p, dx, dy): return re.sub(r'(-?\d+\.?\d*) (-?\d+\.?\d*)', lambda m: f'{float(m.group(1)) + dx:.1f} {float(m.group(2)) + dy:.1f}', p)
F = [
    # Hauptstrang: ab Scheinwerfer ueber den Radlauf, ueber die Tuer bis in den hinteren Kotfluegel, Ende rollt sich ein
    tongue([(40, 120), (150, 102), (260, 104), (380, 99), (500, 96), (630, 96), (750, 86), (830, 80), (862, 92), (850, 100)], 21, head=0.4, bulge=0.5),
    # Zungen zweigen weich aus dem Hauptstrang ab und laufen nach hinten aus
    tongue([(240, 106), (300, 110), (390, 120), (490, 124), (580, 122), (660, 108), (700, 104), (716, 114)], 17, head=0.3),
    tongue([(255, 108), (320, 120), (400, 142), (470, 150), (540, 148), (590, 134), (606, 140)], 15, head=0.3),
    tongue([(270, 110), (330, 130), (390, 160), (440, 174), (482, 174), (506, 162), (500, 156)], 12, head=0.3),
]
for t in F: D.side('Farbe_3_Schatten_BLAU', sh(t, 3, 4), 3)
for t in F: D.side('Farbe_2_Flammen_GRUEN', t, 2)
# Haube von oben (Front oben): zwei schlanke Flammen an den Kanten, Spitzen nach hinten
hood = [tongue([(40, 24), (48, 100), (58, 190), (72, 268)], 22, head=0.25, start=0.0, bulge=0.6),
        tongue([(60, 40), (70, 110), (82, 170), (92, 222)], 14, head=0.2, start=0.0)]
for t in hood:
    D.top('Farbe_3_Schatten_BLAU', sh(t, 3, 4), 3); D.top('Farbe_3_Schatten_BLAU', sh(D._map(t, lambda x, y: (D.tw - x, y)), -3, 4), 3)
    D.top('Farbe_2_Flammen_GRUEN', t, 2, mirror=True)
D.write('bx_streetdrift_a')
