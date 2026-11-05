# Rallye Gruppe A (90er): breites Band in Farbe 2 rundum mit Kanten in Farbe 3, Hauptsponsor in Farbe 1 darauf,
# Tuernummernfeld, Rallye-Schild auf der Haube, grosse Dachnummer, Mittelband ueber Haube/Dach/Kofferraum.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from txt import text
from cars import CAR, MODELS
from tribal import to_d
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
MAIN = ['nomi_2', 'selecta', 'eshock', 'nomi_2', 'selecta', 'eshock', 'nomi_2', 'eshock', 'eshock'][MODELS.index(D.model)]
S2, S3, W, K = 'Farbe_2_Band_GRUEN', 'Farbe_3_Kanten_BLAU', 'Farbe_1_Sponsor_Schilder_ROT', 'Schwarz_Nummern'
def band(y0, y1, a=-20, b=L + 20, k=0.012): return Polygon([(a, y0 - a * k), (b, y0 - b * k), (b, y1 - b * k), (a, y1 - a * k)])
D.side(S2, to_d(band(126, 162)), 2)
D.side(S3, to_d(band(120, 123)), 3); D.side(S3, to_d(band(165, 168)), 3)
pl = box(286, 108, 372, 176).buffer(-5).buffer(5)
D.side(W, to_d(pl), 1); D.side(K, to_d(pl.buffer(1.6).difference(pl)), 'k')
D.side_text(K, 'SHUTO RALLY', RB, 6, 329, 118, 'k', track=0.2)
D.side_text(K, C['rnum'], RS, 34, 329, 150, 'k')
LX, LH = {'covet': (455, 19)}.get(D.model, (520, 24))
D.side_logo(W, MAIN, LX, 143, LH, key=1)
D.side_logo(K, 'gripall', 820, 120, 12)
D.side_text(K, C['maker'].upper() + ' RALLY TEAM', RB, 6.5, LX, 178, 'k', track=0.25)
cx = TW / 2
D.top(S2, to_d(box(cx - 46, -20, cx + 46, 920)), 2)
D.top(S3, to_d(box(cx - 52, -20, cx - 49, 920)), 3); D.top(S3, to_d(box(cx + 49, -20, cx + 52, 920)), 3)
hp = box(cx - 60, 30, cx + 60, 70).buffer(-4).buffer(4)
D.top(W, to_d(hp), 1); D.top(K, to_d(hp.buffer(1.6).difference(hp)), 'k')
d, *_ = text('SHUTO RALLY', RB, 14, cx, 50, rot=180, track=0.15); D.top(K, d, 'k')
rp = box(cx - 40, 440, cx + 40, 540).buffer(-6).buffer(6)
D.top(W, to_d(rp), 1); D.top(K, to_d(rp.buffer(2).difference(rp)), 'k')
d, *_ = text(C['rnum'], RS, 56, cx, 490, rot=180); D.top(K, d, 'k')
D.write('bx_rally_a')
