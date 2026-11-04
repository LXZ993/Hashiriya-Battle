from vcsvg import Doc
from flame import tongue
from txt import text
D = Doc('bx')
KS, RC, RB = 'KaushanScript-Regular.ttf', 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
# --- Seite: duennes Flammen-Tribal in Farbe 3 hinter dem Schriftzug, fliesst nach hinten ---
tri = [
    tongue([(430, 112), (520, 104), (640, 102), (760, 90), (840, 84), (866, 94), (854, 102)], 13, head=0.3, bulge=0.5),
    tongue([(470, 108), (540, 116), (640, 124), (720, 116), (760, 104), (774, 112)], 11, head=0.3),
    tongue([(500, 110), (560, 128), (640, 146), (700, 146), (730, 134), (726, 128)], 9, head=0.3),
    tongue([(520, 112), (580, 140), (630, 164), (670, 168), (692, 158)], 7, head=0.3),
]
for t in tri: D.side('Farbe_3_Tribal_BLAU', t, 3)
# --- Team-Schriftzug: Pinselschrift in Farbe 2 mit Farbe-1-Rand (frei gestellt), leicht ansteigend ---
D.side_text('Farbe_2_Schriftzug_GRUEN', 'Yokaze Sports', KS, 42, 585, 126, 2, rot=7, stroke=1, sw=7)
D.side_text('Schwarz_Sticker', 'Team', KS, 19, 482, 98, 'k', rot=7, stroke=1, sw=4, xr=210, yr=96)
# --- Sponsor-Sticker (schwarz, fest) ---
D.side_text('Schwarz_Sticker', 'KAZE WORKS', RC, 15, 368, 116, 'k', track=0.04)
D.side_text('Schwarz_Sticker', 'HAGANE BRAKES', RB, 9, 368, 129, 'k', track=0.06)
D.side_text('Schwarz_Sticker', 'MUGETSU WHEELS', RC, 11, 842, 150, 'k', track=0.03)
# --- Haube (Front oben): schlanke Flammen an den Kanten in Farbe 3, Teamname vorne, von vorne lesbar ---
cx = D.tw / 2
hood = [tongue([(40, 24), (48, 100), (58, 190), (72, 268)], 16, head=0.25, bulge=0.6),
        tongue([(60, 40), (70, 110), (82, 170), (92, 222)], 10, head=0.2)]
for t in hood: D.top('Farbe_3_Tribal_BLAU', t, 3, mirror=True)
d, *_ = text('YOKAZE SPORTS', RC, 16, cx, 52, rot=180, track=0.08)
D.top('Schwarz_Sticker', d, 'k')
D.write('bx_streetdrift_b')
