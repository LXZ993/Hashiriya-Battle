# D1-Profi-Drift (2000er): Heck in Farbe 2 mit schraeger Kante, Tempo-Schraegstreifen (Farbe 3), Hauptsponsor gross
# in Farbe 3 auf der Tuer und der Haube, Sponsorblock in Farbe 1 auf dem Heck. Logos = BeamNG-Lore.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from cars import CAR, MODELS
from tribal import to_d, union
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RB = 'RobotoCondensed.ttf'
MAIN = ['driftgear', 'wangan', 'blastr', 'alder', 'driftgear', 'wangan', 'blastr', 'alder', 'driftgear']
main = MAIN[MODELS.index(D.model)]
STK = [s for s in ('okudai', 'nomi_2', 'gripall', 'wangan', 'rotopad') if s != main][:3]
S2, S3, W = 'Farbe_2_Heck_GRUEN', 'Farbe_3_Hauptsponsor_Streifen_BLAU', 'Farbe_1_Sponsorblock_ROT'
K = 0.55  # Neigung der Kante (dx/dy), nach hinten oben
def pg(p): return Polygon(p).buffer(0)
def slant(x, w, y0=-20, y1=240): return pg([(x, y1), (x + w, y1), (x + w + (y1 - y0) * K, y0), (x + (y1 - y0) * K, y0)])
D.side(S2, to_d(pg([(560, 240), (560 + 260 * K, -20), (L + 20, -20), (L + 20, 240)])), 2)
D.side(S3, to_d(union(slant(530, 9), slant(512, 5), slant(499, 2.5))), 3)
MY, MH = {'sbr': (128, 40)}.get(D.model, (150, 30))
D.side_logo(S3, main, 400, MY, MH, key=3)
D.side_logo(W, STK[0], 822, 132, 11, key=1)
D.side_text(W, ('TEAM ' + C['team']).upper(), RB, 6.5, 800, 112, 1, track=0.25)
D.top(S2, to_d(box(-20, 470, TW + 20, 920)), 2)
D.top(S3, to_d(union(box(-20, 440, TW + 20, 452), box(-20, 426, TW + 20, 432), box(-20, 418, TW + 20, 421))), 3)
D.top_logo(S3, main, TW / 2, 58, 30, key=3)
D.top_logo(W, STK[0], TW / 2, 820, 24, key=1)
D.write('bx_d1drift_a')
