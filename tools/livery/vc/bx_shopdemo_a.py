# Tuning-Shop-Demo-Car: dezenter Strassen-Look, jedes Auto mit eigenem Layout (Tuning Studio oder Grunt Performance).
# 200BX Schwellerband, Miramar Doppel-Zierlinie, Pessima Mk1 Band mit Bloecken, Pessima Mk2 Grosslogo,
# Covet Heckkeil, Sunburst Haube/Dach, SBR4 Schulterkeil.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RB, ZK = 'RobotoCondensed.ttf', 'ZenKakuGothicNew-Bold.ttf'
SHOP = {'bx': 'tuningstudio', 'miramar': 'grunt_1', 'pessima': 'tuningstudio', 'midsize': 'grunt_1',
        'covet': 'tuningstudio', 'sunburst2': 'grunt_1', 'sbr': 'tuningstudio'}.get(M, 'tuningstudio')
NAME = {'tuningstudio': 'TUNING STUDIO', 'grunt_1': 'GRUNT PERFORMANCE'}[SHOP]
KATA = {'tuningstudio': 'チューニング・スタジオ', 'grunt_1': 'グラント・パフォーマンス'}[SHOP]
GH = 1.0 if SHOP == 'tuningstudio' else 0.6   # Grunt-Logo ist breiter
STK = ['rotopad', 'clockwise', 'gripall'] if SHOP == 'grunt_1' else ['eshock', 'nodeoline', 'rotopad']
S2, S3, W = 'Farbe_2_Band_Flaeche_GRUEN', 'Farbe_3_Shoplogo_Linien_BLAU', 'Farbe_1_Schrift_ROT'
model = C['script'].upper()
if M == 'miramar':   # Doppel-Zierlinie an der Guertellinie mit Haken vorn, Logo hinten
    D.side(S3, to_d(union(pg([(60, 103), (L - 10, 103), (L - 10, 106), (60, 106)]), pg([(80, 110), (L - 10, 110), (L - 10, 112), (80, 112)]),
                          pg([(60, 103), (63, 103), (88, 126), (85, 126)]))), 3)
    D.side_logo(S2, SHOP, 690, 132, 34 * GH, key=2)
    D.side_text(S3, KATA, ZK, 7, 450, 124, 3)
    D.side_text(S3, model + '  ·  DEMO CAR', RB, 6, 690, 152, 3, track=0.3)
    D.top(S3, to_d(union(box(TW / 2 - 70, 20, TW / 2 - 66, 900), box(TW / 2 + 66, 20, TW / 2 + 70, 900))), 3)
    D.top_logo(S2, SHOP, TW / 2, 840, 26 * GH, key=2)
elif M == 'pessima':   # Band auf Tuermitte, laeuft hinten in drei kleiner werdenden Bloecken aus
    D.side(S2, to_d(union(box(150, 140, 590, 158), box(605, 142, 640, 156), box(652, 144, 676, 154), box(686, 146, 700, 152))), 2)
    D.side(S3, to_d(box(150, 161, 590, 163)), 3)
    D.side_logo(S3, SHOP, 380, 120, 26 * GH, key=3)
    D.side_text(W, NAME + '  ·  DEMO CAR', RB, 6.5, 370, 149, 1, track=0.3)
    for i, s in enumerate(STK): D.side_logo(S3, s, 800, 120 + i * 13, 7, key=3)
    D.top(S2, to_d(box(TW / 2 - 16, 0, TW / 2 + 16, 300)), 2)
    D.top_logo(S3, SHOP, TW / 2, 840, 24 * GH, key=3)
elif M == 'midsize':   # grosses Shop-Logo hinten in Farbe 2, Schriftzeile unter dem Fenster, Keil vorn unten
    D.side_logo(S2, SHOP, 560, 140, 46 * GH, key=2)
    D.side_text(S3, NAME + '  ·  ' + model + ' DEMO', RB, 6.5, 420, 110, 3, track=0.35)
    D.side(S3, to_d(pg([(280, 192), (L - 40, 188), (L - 40, 190.5), (280, 194.5)])), 3)
    for i, s in enumerate(STK[:2]): D.side_logo(S3, s, 160 + i * 0, 118 + i * 14, 8, key=3)
    D.top_logo(S2, SHOP, TW / 2, 520, 40 * GH, key=2)
    D.top_logo(S3, SHOP, TW / 2, 840, 22 * GH, key=3)
elif M == 'covet':   # Hot-Hatch: Heckkeil unten in Farbe 2, Logo darin in Farbe 1
    D.side(S2, to_d(pg([(180, 216), (420, 140), (L + 20, 140), (L + 20, 250), (180, 250)])), 2)
    D.side(S3, to_d(pg([(166, 216), (414, 134), (L + 20, 134), (L + 20, 137), (417, 137), (172, 216)])), 3)
    D.side_logo(W, SHOP, 435, 182, 30 * GH, key=1)
    D.side_text(S3, model + ' DEMO', RB, 6.5, 300, 120, 3, track=0.3)
    D.side_logo(S3, STK[0], 170, 120, 9, key=3)
    D.top(S2, to_d(box(-20, 760, TW + 20, 920)), 2)
    D.top_logo(W, SHOP, TW / 2, 840, 24 * GH, key=1)
elif M == 'sunburst2':   # Haube + Dach in Farbe 2 (Carbon-Look), feine Schulterlinie, dezentes Seitenlogo
    D.top(S2, to_d(box(-20, -20, TW + 20, 300)), 2); D.top(S2, to_d(box(-20, 380, TW + 20, 620)), 2)
    D.side(S3, to_d(pg([(40, 98), (L - 40, 92), (L - 40, 95), (40, 101)])), 3)
    D.side_logo(S3, SHOP, 450, 178, 18 * GH * 1.3, key=3)
    D.side_text(S3, NAME + '  ·  DEMO CAR', RB, 6, 450, 196, 3, track=0.3)
    D.top_logo(W, SHOP, TW / 2, 500, 34 * GH, key=1)
    D.top_logo(S3, SHOP, TW / 2, 840, 22 * GH, key=3)
elif M == 'sbr':   # Schulterkeil von der Lampe bis zum Heck, grosses Logo auf der Tuer
    D.side(S2, to_d(pg([(30, 110), (L + 20, 100), (L + 20, 126), (300, 118)])), 2)
    D.side(S3, to_d(pg([(300, 122), (L + 20, 130), (L + 20, 133), (300, 124.5)])), 3)
    D.side_logo(S3, SHOP, 440, 160, 32 * GH, key=3)
    D.side_text(W, model + '  ·  DEMO CAR', RB, 6, 700, 112, 1, track=0.3)
    D.top(S2, to_d(union(pg([(TW * 0.12, 0), (TW * 0.18, 0), (TW * 0.16, 900), (TW * 0.10, 900)]),
                         pg([(TW * 0.82, 0), (TW * 0.88, 0), (TW * 0.90, 900), (TW * 0.84, 900)]))), 2)
    D.top_logo(S3, SHOP, TW / 2, 840, 26 * GH, key=3)
else:   # 200BX (abgenommen): Schwellerband in Farbe 2, Logo auf der Tuer
    D.side(S2, to_d(Polygon([(-20, 166), (L + 20, 158), (L + 20, 180), (-20, 188)])), 2)
    D.side(S3, to_d(Polygon([(-20, 161), (L + 20, 153), (L + 20, 155.5), (-20, 163.5)])), 3)
    D.side_text(W, NAME + '  ·  DEMO CAR', RB, 8, 445, 177, 1, track=0.3)
    D.side_logo(S3, SHOP, 450, 128, 38 if SHOP == 'tuningstudio' else 22, key=3)
    for i, s in enumerate(STK): D.side_logo(S3, s, 828, 124 + i * 14, 8, key=3)
    D.top_logo(S3, SHOP, TW / 2, 840, 30 if SHOP == 'tuningstudio' else 20, key=3)
D.write('bx_shopdemo_a')
