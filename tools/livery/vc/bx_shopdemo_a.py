# Tuning-Shop-Demo-Car: dezenter Strassen-Look. Schwellerband in Farbe 2 mit Shop-Schriftzug (Farbe 1),
# Shop-Logo in Farbe 3 auf der Tuer, kleine Zubehoer-Aufkleber hinten, Logo auf dem Kofferraum.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from cars import CAR, MODELS
from tribal import to_d
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RB = 'RobotoCondensed.ttf'
SHOP = ['tuningstudio', 'grunt_1'][MODELS.index(D.model) % 2]
NAME = {'tuningstudio': 'TUNING STUDIO', 'grunt_1': 'GRUNT PERFORMANCE'}[SHOP]
STK = ['rotopad', 'clockwise', 'gripall'] if SHOP == 'grunt_1' else ['eshock', 'nodeoline', 'rotopad']
S2, S3, W = 'Farbe_2_Schwellerband_GRUEN', 'Farbe_3_Shoplogo_Aufkleber_BLAU', 'Farbe_1_Schrift_ROT'
D.side(S2, to_d(Polygon([(-20, 166), (L + 20, 158), (L + 20, 180), (-20, 188)])), 2)
D.side(S3, to_d(Polygon([(-20, 161), (L + 20, 153), (L + 20, 155.5), (-20, 163.5)])), 3)
D.side_text(W, NAME + '  ·  DEMO CAR', RB, 8, 445, 177, 1, track=0.3)
D.side_logo(S3, SHOP, 450, 128, 38 if SHOP == 'tuningstudio' else 22, key=3)
for i, s in enumerate(STK): D.side_logo(S3, s, 828, 124 + i * 14, 8, key=3)
D.top_logo(S3, SHOP, TW / 2, 840, 30 if SHOP == 'tuningstudio' else 20, key=3)
D.write('bx_shopdemo_a')
