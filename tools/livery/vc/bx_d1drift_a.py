# D1-Profi-Drift (2000er). Eigenes Layout je Auto: 200BX Heckblock mit Schraegkante, Miramar Bug + Speedlines,
# Sunburst Saegezahn-Diagonale, SBR4 Splitter am Heck. Hauptsponsor je Auto aus BeamNG-Lore-Logos.
from shapely.geometry import Polygon, box
from shapely import affinity
from vcsvg import Doc
from cars import CAR
from tribal import to_d, union
from lore_common import pg, saw, band_f, sticker
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RB = 'RobotoCondensed.ttf'
main = {'bx': 'driftgear', 'miramar': 'burnside', 'sunburst2': 'wangan', 'sbr': 'folk'}.get(M, 'driftgear')
STK = [s for s in ('okudai', 'nomi_2', 'gripall', 'wangan', 'rotopad') if s != main][:3]
S2, S3, W = 'Farbe_2_Grafik_GRUEN', 'Farbe_3_Hauptsponsor_Streifen_BLAU', 'Farbe_1_Sponsorblock_ROT'
team = ('TEAM ' + C['team']).upper()
if M == 'miramar':   # Old-School: Bug in Farbe 2 mit Schnitt, drei Speedlines nach hinten
    D.side(S2, to_d(pg([(-20, -30), (300, -30), (330, 250), (-20, 250)])), 2)
    for i, (y, w) in enumerate(((118, 5), (128, 5), (138, 5))):
        D.side(S3, to_d(pg([(318, y), (760 - i * 70, y + w * 0.3), (760 - i * 70, y + w * 0.7), (318, y + w)])), 3)
    D.side_logo(S3, main, 520, 172, 28, key=3)
    sticker(D, 'Fest_Aufkleber', STK[0], 150, 120, 10)
    D.side_text(S3, team, RB, 6.5, 800, 112, 3, track=0.25)
    D.top(S2, to_d(box(-20, -20, TW + 20, 330)), 2)
    for i, x in enumerate((-60, 0, 60)):
        D.top(S3, to_d(box(TW / 2 + x - 4, 400, TW / 2 + x + 4, 900 - abs(x) * 2)), 3)
    sticker(D, 'Fest_Aufkleber', STK[0], TW / 2, 160, 28, view='top')
elif M == 'sunburst2':   # Diagonale von vorn unten nach hinten oben mit Saegezahn, Schatten in Farbe 3
    f = lambda x: 206 - 150 * (x + 20) / 933
    sh = affinity.translate(saw(f, -20, L + 20, 46, 18), 9, -7)
    main_g = saw(f, -20, L + 20, 46, 18)
    D.side(S3, to_d(sh.difference(main_g)), 3); D.side(S2, to_d(main_g), 2)
    D.side_logo(W, main, 610, 165, 28, key=1)
    sticker(D, 'Fest_Aufkleber', STK[0], 250, 110, 12)
    D.side_text(S3, team, RB, 6.5, 300, 128, 3, track=0.25)
    D.top(S2, to_d(pg([(-20, 520), (TW + 20, 380), (TW + 20, 920), (-20, 920)])), 2)
    D.top_logo(S3, main, TW / 2, 150, 30, key=3)
elif M == 'sbr':   # Splitter: spitze Scherben fliegen vom Heck nach vorn
    sh2 = [pg([(L + 20, 40), (L + 20, 230), (520, 150)]), pg([(L + 20, 60), (L + 20, 110), (360, 95)]),
           pg([(L + 20, 160), (L + 20, 215), (420, 205)])]
    sh3 = [pg([(510, 122), (500, 128), (380, 126)]), pg([(470, 184), (460, 190), (330, 189)]), pg([(560, 100), (550, 105), (450, 104)])]
    D.side(S2, to_d(union(*sh2)), 2); D.side(S3, to_d(union(*sh3)), 3)
    D.side_logo(S3, main, 330, 148, 34, key=3)
    sticker(D, 'Fest_Aufkleber', STK[0], 800, 150, 11)
    D.side_text(W, team, RB, 6.5, 800, 132, 1, track=0.25)
    D.top(S2, to_d(union(pg([(-20, 920), (TW + 20, 920), (TW + 20, 560), (TW / 2, 700), (-20, 560)]))), 2)
    D.top(S3, to_d(union(pg([(TW * 0.2, 520), (TW * 0.28, 520), (TW * 0.24, 420)]), pg([(TW * 0.72, 520), (TW * 0.8, 520), (TW * 0.76, 420)]))), 3)
    D.top_logo(S3, main, TW / 2, 150, 30, key=3)
else:   # 200BX (abgenommen): Heck in Farbe 2 mit schraeger Kante + Tempo-Schraegstreifen
    K = 0.55
    def slant(x, w, y0=-20, y1=240): return pg([(x, y1), (x + w, y1), (x + w + (y1 - y0) * K, y0), (x + (y1 - y0) * K, y0)])
    D.side(S2, to_d(pg([(560, 240), (560 + 260 * K, -20), (L + 20, -20), (L + 20, 240)])), 2)
    D.side(S3, to_d(union(slant(530, 9), slant(512, 5), slant(499, 2.5))), 3)
    D.side_logo(S3, main, 400, 150, 30, key=3)
    sticker(D, 'Fest_Aufkleber', STK[0], 822, 132, 11)
    D.side_text(W, team, RB, 6.5, 800, 112, 1, track=0.25)
    D.top(S2, to_d(box(-20, 470, TW + 20, 920)), 2)
    D.top(S3, to_d(union(box(-20, 440, TW + 20, 452), box(-20, 426, TW + 20, 432), box(-20, 418, TW + 20, 421))), 3)
    D.top_logo(S3, main, TW / 2, 58, 30, key=3)
    sticker(D, 'Fest_Aufkleber', STK[0], TW / 2, 820, 24, view='top')
D.write('bx_d1drift_a')
