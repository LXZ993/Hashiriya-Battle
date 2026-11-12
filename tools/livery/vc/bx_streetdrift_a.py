# Street Drift A: fliessendes Flammen-Tribal (Variante 0 von Alex freigegeben 2026-11-04), 3 Formvarianten je Auto
from vcsvg import Doc
from flame import tongue
from cars import variant
import re
D = Doc(); V = variant(D.model, 'streetdrift_a')
def sh(p, dx, dy): return re.sub(r'(-?\d+\.?\d*) (-?\d+\.?\d*)', lambda m: f'{float(m.group(1)) + dx:.1f} {float(m.group(2)) + dy:.1f}', p)
if V == 0:
    F = [
        tongue([(40, 120), (150, 102), (260, 104), (380, 99), (500, 96), (630, 96), (750, 86), (830, 80), (862, 92), (850, 100)], 21, head=0.4, bulge=0.5),
        tongue([(240, 106), (300, 110), (390, 120), (490, 124), (580, 122), (660, 108), (700, 104), (716, 114)], 17, head=0.3),
        tongue([(255, 108), (320, 120), (400, 142), (470, 150), (540, 148), (590, 134), (606, 140)], 15, head=0.3),
        tongue([(270, 110), (330, 130), (390, 160), (440, 174), (482, 174), (506, 162), (500, 156)], 12, head=0.3),
    ]
    hood = [tongue([(40, 24), (48, 100), (58, 190), (72, 268)], 22, head=0.25, start=0.0, bulge=0.6),
            tongue([(60, 40), (70, 110), (82, 170), (92, 222)], 14, head=0.2, start=0.0)]
elif V == 1:
    # lange schmale Flammen ab der Vordertuer, Hauptstrang auf der Guertellinie, zwei lange Zungen bis ins Heck
    F = [
        tongue([(300, 112), (420, 100), (560, 96), (690, 92), (800, 82), (868, 78), (884, 88), (872, 94)], 18, head=0.35, bulge=0.4),
        tongue([(360, 106), (450, 114), (560, 124), (670, 122), (760, 110), (800, 112), (806, 122)], 14, head=0.3),
        tongue([(390, 108), (470, 128), (560, 150), (640, 152), (700, 140), (712, 148)], 11, head=0.3),
    ]
    hood = [tongue([(70, 30), (76, 110), (82, 200), (86, 280)], 16, head=0.2, start=0.0, bulge=0.4)]
else:
    # kraeftiger Flammenkoerper ab dem vorderen Radlauf, fuenf kurze Zungen, enden vor dem hinteren Radlauf
    F = [
        tongue([(120, 128), (220, 112), (330, 108), (450, 104), (560, 102), (630, 98), (662, 108), (650, 114)], 24, head=0.45, bulge=0.6),
        tongue([(230, 114), (300, 122), (380, 132), (460, 136), (520, 130), (546, 138)], 15, head=0.3),
        tongue([(245, 116), (310, 134), (380, 152), (440, 160), (480, 154), (492, 160)], 13, head=0.3),
        tongue([(260, 118), (320, 146), (370, 170), (410, 178), (436, 170)], 10, head=0.3),
        tongue([(400, 108), (460, 98), (540, 90), (600, 86), (626, 92)], 9, head=0.3),
    ]
    hood = [tongue([(30, 20), (40, 90), (52, 160), (70, 230)], 26, head=0.3, start=0.0, bulge=0.7),
            tongue([(56, 30), (66, 90), (78, 140), (90, 180)], 15, head=0.2, start=0.0),
            tongue([(80, 36), (90, 80), (100, 116)], 9, head=0.2, start=0.0)]
for t in F: D.side('Farbe_3_Schatten_BLAU', sh(t, 3, 4), 3)
for t in F: D.side('Farbe_2_Flammen_GRUEN', t, 2)
for t in hood:
    D.top('Farbe_3_Schatten_BLAU', sh(t, 3, 4), 3); D.top('Farbe_3_Schatten_BLAU', sh(D._map(t, lambda x, y: (D.tw - x, y)), -3, 4), 3)
    D.top('Farbe_2_Flammen_GRUEN', t, 2, mirror=True)
D.write('bx_streetdrift_a')
