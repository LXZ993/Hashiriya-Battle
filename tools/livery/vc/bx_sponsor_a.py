# Sponsor-Rennwagen (90er JGTC / Super Taikyu / JTCC). Jedes Auto hat ein eigenes Layout und einen eigenen
# Hauptsponsor (BeamNG-Lore-Logos): 200BX Unterteil, Pessima Mk2 Diagonale, Covet Bug, Sunburst Schwung, SBR4 GT-Band.
from shapely.geometry import box, Point
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg, band_f, below, rbox, outline
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
MAIN = {'bx': 'oilex', 'midsize': 'wangan', 'covet': 'gripall', 'sunburst2': 'eshock', 'sbr': 'okudai'}.get(M, 'oilex')
SMALL = [s for s in ('gripall', 'rotopad', 'clockwise', 'eshock', 'dreid', 'nodeoline', 'tims') if s != MAIN]
S2, S3, W, K = 'Farbe_2_Sponsorflaeche_GRUEN', 'Farbe_3_Zierlinie_BLAU', 'Farbe_1_Sponsor_Nummernfeld_ROT', 'Schwarz_Nummer'
cx = TW / 2
def num_box(x, y, w=76, h=46):
    b = rbox(x - w / 2, y - h / 2, x + w / 2, y + h / 2, 6); D.side(W, to_d(b), 1); D.side_text(K, C['rnum'], RS, 34, x, y, 'k')
def meatball(x, y, r=24):
    c = Point(x, y).buffer(r); D.side(W, to_d(c), 1); D.side(K, to_d(outline(c, 1.8)), 'k'); D.side_text(K, C['rnum'], RS, 30, x, y + 1, 'k')
def roofnum(y=500, s=70, key='k', lid=K):
    d, *_ = text(C['rnum'], RS, s, cx, y, rot=180); D.top(lid, d, key)
if M == 'midsize':   # JTCC: Diagonale, hinten unten Farbe 2
    f = lambda x: 196 - 92 * (x + 20) / 933
    D.side(S2, to_d(below(f)), 2); D.side(S3, to_d(band_f(lambda x: f(x) - 8, lambda x: f(x) - 4)), 3)
    meatball(318, 140)
    D.side_logo(W, MAIN, 600, 168, 26, key=1)
    for i, s in enumerate(SMALL[:2]): D.side_logo(K, s, 180 + i * 0, 128 + i * 14, 9)
    D.side_text(K, C['maker'] + ' TOURING CAR TEAM', RB, 6, 600, 196, 'k', track=0.2)
    D.top(S2, to_d(pg([(-20, 430), (TW + 20, 330), (TW + 20, 920), (-20, 920)])), 2)
    D.top(S3, to_d(pg([(-20, 420), (TW + 20, 320), (TW + 20, 326), (-20, 426)])), 3)
    D.top_logo(S2, MAIN, cx, 150, 34, key=2); roofnum(560, 64, 1, W)
elif M == 'covet':   # Bug in Farbe 2 mit schraegem Schnitt an der B-Saeule, Sponsor hinten auf Grundlack
    D.side(S2, to_d(pg([(-20, -30), (395, -30), (335, 250), (-20, 250)])), 2)
    D.side(S3, to_d(pg([(403, -30), (411, -30), (351, 250), (343, 250)])), 3)
    D.side_logo(S2, MAIN, 425, 142, 26, key=2)
    D.side_text(S2, C['maker'] + ' × ' + MAIN.upper(), RB, 6, 425, 166, 2, track=0.25)
    num_box(700, 120, 58, 36)
    for i, s in enumerate(SMALL[:3]): D.side_logo(W, s, 90 + i * 70, 196, 9, key=1)
    D.top(S2, to_d(box(-20, -20, TW + 20, 330)), 2); D.top(S3, to_d(box(-20, 336, TW + 20, 342)), 3)
    D.top_logo(W, MAIN, cx, 170, 36, key=1); roofnum(500, 66)
elif M == 'sunburst2':   # Super Taikyu: geschwungenes Band von vorn unten nach hinten oben
    bot = lambda x: 216 - 100 * ((x + 20) / 933) ** 1.6
    top = lambda x: bot(x) - 44
    D.side(S2, to_d(band_f(top, bot)), 2)
    D.side(S3, to_d(band_f(lambda x: top(x) - 7, lambda x: top(x) - 4)), 3)
    D.side(S3, to_d(band_f(lambda x: bot(x) + 4, lambda x: bot(x) + 7)), 3)
    D.side_logo(W, MAIN, 520, top(520) + 22, 26, key=1)
    meatball(318, 116, 22)
    for i, s in enumerate(SMALL[:2]): D.side_logo(K, s, 820, 112 + i * 14, 9)
    D.top(S2, to_d(box(TW * 0.30 - 24, -20, TW * 0.30 + 24, 920)), 2)
    D.top(S3, to_d(union(box(TW * 0.30 - 31, -20, TW * 0.30 - 28, 920), box(TW * 0.30 + 28, -20, TW * 0.30 + 31, 920))), 3)
    D.top_logo(S2, MAIN, TW * 0.68, 150, 26, key=2); roofnum(500, 60)
elif M == 'sbr':   # GT500: breites Tuerband ueber die ganze Laenge, Zierlinien, Haube/Dach-Mittelstreifen
    D.side(S2, to_d(box(-20, 118, L + 20, 168)), 2)
    D.side(S3, to_d(union(box(-20, 111, L + 20, 114), box(-20, 172, L + 20, 175))), 3)
    D.side_logo(W, MAIN, 500, 143, 30, key=1)
    num_box(318, 143, 64, 40)
    for i, s in enumerate(SMALL[:3]): D.side_logo(K, s, 170 + i * 0, 192, 9) if i == 0 else D.side_logo(K, s, 700 + i * 60, 192, 9)
    D.side_text(K, C['maker'] + ' GT500', RB, 7, 780, 104, 'k', track=0.25)
    D.top(S2, to_d(box(cx - 62, -20, cx + 62, 920)), 2)
    D.top(S3, to_d(union(box(cx - 70, -20, cx - 67, 920), box(cx + 67, -20, cx + 70, 920))), 3)
    D.top_logo(W, MAIN, cx, 160, 34, key=1); roofnum(500, 66)
else:   # 200BX (abgenommen): Unterteil in Farbe 2, Nummernfeld an der Tuer
    split = [(-20, 124), (560, 124), (L + 20, 110)]
    D.side(S2, to_d(pg(split + [(L + 20, 240), (-20, 240)])), 2)
    D.side(S3, to_d(pg([(x, y - 7) for x, y in split] + [(x, y - 4) for x, y in split[::-1]])), 3)
    num_box(336, 155)
    D.side_logo(W, MAIN, 505, 155, 30, key=1)
    for i, s in enumerate(SMALL[:3]): D.side_logo(W, s, 330 + i * 76, 194, 11, key=1)
    D.side_text(K, C['maker'].upper() + '  ×  ' + MAIN.upper() + ' RACING', RB, 6, 760, 104, 'k', track=0.2)
    D.top(S2, to_d(box(-20, -20, TW + 20, 300)), 2); D.top(S2, to_d(box(-20, 760, TW + 20, 920)), 2)
    D.top_logo(W, MAIN, cx, 160, 40, key=1); roofnum()
D.write('bx_sponsor_a')
