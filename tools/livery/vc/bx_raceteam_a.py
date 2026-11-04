# Werks-Rennteam A: nach dem roten 46er (Oberteil Farbe 2, Seitenschlitze Farbe 2/3, Schwellerstreifen Farbe 3, Nummer schwarz)
from vcsvg import Doc
from txt import text
D = Doc()
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
L = D.lw
# Oberteil in Farbe 2: alles ueber einer Linie knapp unter der Fensterlinie, vorne ueber den Scheinwerfern
split = [(-20, 122), (120, 112), (320, 104), (620, 100), (L + 20, 94)]
D.side('Farbe_2_Oberteil_GRUEN', P([(-20, -20), (L + 20, -20)] + split[::-1]), 2)
D.top('Farbe_2_Oberteil_GRUEN', P([(-20, -20), (D.tw + 20, -20), (D.tw + 20, 920), (-20, 920)]), 2)
# Schwellerstreifen Farbe 3, durchgehend
D.side('Farbe_3_Streifen_BLAU', P([(-20, 192), (L + 20, 190), (L + 20, 197), (-20, 199)]), 3)
# zwei schraege Schlitze hinter dem vorderen Rad: Farbe 2 und Farbe 3, nach hinten geneigt
def slash(x, w):
    return P([(x, 104), (x + w, 104), (x + w - 34, 196), (x - 34, 196)])
D.side('Farbe_2_Oberteil_GRUEN', slash(300, 9), 2)
D.side('Farbe_3_Streifen_BLAU', slash(314, 9), 3)
# Startnummer schwarz an der Tuer + Haube (von vorne lesbar), Sponsor am hinteren Kotfluegel
D.side_text('Schwarz_Nummer_Sticker', '46', RS, 64, 480, 150, 'k')
d, *_ = text('46', RS, 38, D.tw / 2, 52, rot=180); D.top('Schwarz_Nummer_Sticker', d, 'k')
D.side_text('Schwarz_Nummer_Sticker', 'TOBIUO OIL', RB, 12, 812, 122, 'k', track=0.05)
D.side_text('Schwarz_Nummer_Sticker', 'IBISHU WORKS', RB, 8, 400, 186, 'k', track=0.12)
D.write('bx_raceteam_a')
