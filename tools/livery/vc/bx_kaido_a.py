from vcsvg import Doc
from txt import text
D = Doc()
SM, ZK = 'ShipporiMincho-ExtraBold.ttf', 'ZenKakuGothicNew-Black.ttf'
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
# Farbe 3: duenner Seitenstreifen auf der Karosserielinie, durchgehend von Stossstange zu Stossstange
y, th = 160, 5
D.side('Farbe_3_Seitenstreifen_BLAU', P([(-20, y), (D.lw + 20, y - 4), (D.lw + 20, y - 4 + th), (-20, y + th)]), 3)
# Farbe 2: Startnummer an der Tuer (Zekken-Stil, fette Serifenschrift) + Katakana am hinteren Kotfluegel
D.side_text('Farbe_2_Nummer_Schrift_GRUEN', '43', SM, 52, 482, 128, 2, track=0.02)
D.side_text('Farbe_2_Nummer_Schrift_GRUEN', 'カイドー・レーサー', ZK, 13, 778, 112, 2, track=0.02)
# Haube: Nummer quer, von der linken Fahrzeugseite lesbar (wie auf deinem Bild)
d, *_ = text('43', SM, 56, D.tw * 0.25, 120, rot=-90)
D.top('Farbe_2_Nummer_Schrift_GRUEN', d, 2)
D.write('bx_kaido_a')
