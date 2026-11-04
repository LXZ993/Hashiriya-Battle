# Werks-Rennteam (Variante 0 nach dem roten 46er), Nummer/Marke/Sponsor je Auto aus cars.py
from vcsvg import Doc
from txt import text
from cars import variant, CAR, sponsors
D = Doc(); V = variant(D.model, 'raceteam_a'); C = CAR[D.model]; SP = sponsors(D.model)
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
L, TW = D.lw, D.tw
O, S, K = 'Farbe_2_Oberteil_GRUEN', 'Farbe_3_Streifen_BLAU', 'Schwarz_Nummer_Sticker'
def slash(x, w, y0=104, y1=196): return P([(x, y0), (x + w, y0), (x + w - (y1 - y0) * 0.37, y1), (x - (y1 - y0) * 0.37, y1)])
works = C['maker'] + ' WORKS'
if V == 0:
    split = [(-20, 122), (120, 112), (320, 104), (620, 100), (L + 20, 94)]
    D.side(O, P([(-20, -20), (L + 20, -20)] + split[::-1]), 2)
    D.top(O, P([(-20, -20), (TW + 20, -20), (TW + 20, 920), (-20, 920)]), 2)
    D.side(S, P([(-20, 192), (L + 20, 190), (L + 20, 197), (-20, 199)]), 3)
    D.side(O, slash(300, 9), 2); D.side(S, slash(314, 9), 3)
    D.side_text(K, C['rnum'], RS, 64, 480, 150, 'k')
    d, *_ = text(C['rnum'], RS, 38, TW / 2, 52, rot=180); D.top(K, d, 'k')
    D.side_logo(K, SP[0], 812, 122, 14)
    D.side_text(K, works, RB, 8, 400, 186, 'k', track=0.12)
elif V == 1:
    # farbige Front bis zur Vordertuer (schraege Kante), Haube farbig, drei Schraegstreifen auf der Tuer
    D.side(O, P([(-20, -20), (318, -20), (282, 240), (-20, 240)]), 2)
    D.top(O, P([(-20, -20), (TW + 20, -20), (TW + 20, 300), (-20, 300)]), 2)
    for i, (x, k) in enumerate(((330, 2), (346, 3), (362, 2))): D.side(O if k == 2 else S, slash(x, 7, 100, 200), k)
    D.side_text(K, C['rnum'], RS, 60, 520, 150, 'k')
    d, *_ = text(C['rnum'], RS, 40, TW / 2, 140, rot=180); D.top(K, d, 1)
    D.side_text(K, works, RB, 9, 690, 120, 'k', track=0.12)
    D.side_logo(K, SP[0], 520, 186, 12)
else:
    # Unterteil in Farbe 2, steigt nach hinten an, Zierlinie Farbe 3 darueber, Nummer auf der Tuer
    edge = [(-20, 182), (260, 176), (L + 20, 126)]
    D.side(O.replace('Oberteil', 'Unterteil'), P(edge + [(L + 20, 240), (-20, 240)]), 2)
    from offset import band
    D.side(S, P(band([(x, y - 6) for x, y in edge], 3, (0, -1))), 3)
    D.side_text(K, C['rnum'], RS, 60, 470, 134, 'k')
    d, *_ = text(C['rnum'], RS, 36, TW / 2, 60, rot=180); D.top(K, d, 'k')
    D.side_text(K, works, RB, 9, 240, 120, 'k', track=0.12)
    D.side_logo(K, SP[0], 800, 112, 13)
D.write('bx_raceteam_a')
