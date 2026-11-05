# Sponsor-Rennwagen (90er JGTC / Super Taikyu): Hauptsponsor in Farbe 1 auf Farbflaeche (Farbe 2), Nummernfeld,
# Zubehoer-Aufkleber am Schweller. Hauptsponsor je Auto aus BeamNG-Lore-Logos.
from shapely.geometry import Polygon, box
from vcsvg import Doc
from txt import text
from cars import CAR, MODELS
from tribal import to_d
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
MAIN = ['oilex', 'okudai', 'wangan', 'gripall', 'eshock', 'oilex', 'okudai', 'wangan', 'tims']
main = MAIN[MODELS.index(D.model)]
SMALL = [s for s in ('gripall', 'rotopad', 'clockwise', 'eshock', 'dreid', 'nodeoline') if s != main][:4]
S2, S3, W, K = 'Farbe_2_Sponsorflaeche_GRUEN', 'Farbe_3_Zierlinie_BLAU', 'Farbe_1_Sponsor_Nummernfeld_ROT', 'Schwarz_Nummer'
def pg(p): return Polygon(p).buffer(0)
split = [(-20, 124), (560, 124), (L + 20, 110)]
D.side(S2, to_d(pg(split + [(L + 20, 240), (-20, 240)])), 2)
D.side(S3, to_d(pg([(x, y - 7) for x, y in split] + [(x, y - 4) for x, y in split[::-1]])), 3)
D.side(W, to_d(box(298, 132, 374, 178).buffer(-6).buffer(6)), 1)
D.side_text(K, C['rnum'], RS, 34, 336, 155, 'k')
D.side_logo(W, main, 505, 155, 30, key=1)
for i, s in enumerate(SMALL[:3]): D.side_logo(W, s, 330 + i * 76, 194, 11, key=1)
D.side_text(K, C['maker'].upper() + '  ×  ' + main.upper() + ' RACING', RB, 6, 760, 104, 'k', track=0.2)
D.top(S2, to_d(box(-20, -20, TW + 20, 300)), 2)
D.top(S2, to_d(box(-20, 760, TW + 20, 920)), 2)
D.top_logo(W, main, TW / 2, 160, 40, key=1)
d, *_ = text(C['rnum'], RS, 70, TW / 2, 500, rot=180); D.top(K, d, 'k')
D.write('bx_sponsor_a')
