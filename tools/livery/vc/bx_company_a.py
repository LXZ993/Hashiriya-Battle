# Firmenwagen (Lieferwagen/Servicewagen einer Lore-Firma): Firmenlogo gross in Farbe 2, Zierband in Farbe 2/3,
# Service-Zeile mit Telefonnummer (erfunden). Pigeon (Lieferdienst) und Hopper (Service) mit eigenem Layout.
from shapely.geometry import Polygon
from vcsvg import Doc
from cars import CAR
from tribal import to_d
from lore_common import BRAND
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RB, ZK = 'RobotoCondensed.ttf', 'ZenKakuGothicNew-Bold.ttf'
CO = {'pigeon': ('tims', 'TIMS', 'ティムス配送'), 'hopper': ('selecta', 'SELECTA', 'セレクタ・サービス')}.get(D.model, ('nodeoline', 'NODEOLINE', 'ノードオライン'))
logo, name, kata = CO
S2, S3, W = 'Farbe_2_Firmenlogo_Flaeche_GRUEN', 'Farbe_3_Zierlinie_Schrift_BLAU', 'Farbe_1_Schrift_ROT'
if D.model == 'pigeon':  # Lieferwagen: Band unten, Logo + Katakana gross auf dem Koffer
    D.side(S2, to_d(Polygon([(-20, 172), (L + 20, 172), (L + 20, 186), (-20, 186)])), 2)
    D.side(S3, to_d(Polygon([(-20, 166), (L + 20, 166), (L + 20, 168.5), (-20, 168.5)])), 3)
    D.side_logo('Fest_Firmenlogo', logo, 680, 70, 46, key=BRAND[logo])
    D.side_text(S3, kata, ZK, 15, 680, 118, 3)
    D.side_text(S3, name + ' SERVICE  ·  0120-46-4646', RB, 6.5, 450, 197, 3, track=0.2)
    D.top_logo('Fest_Firmenlogo', logo, TW / 2, 520, 36, key=BRAND[logo])
else:  # Servicewagen: Heck in Farbe 2 mit Schraegschnitt, Logo vorn auf der Tuer, Katakana hinten
    D.side(S2, to_d(Polygon([(470, 250), (520, 92), (L + 20, 92), (L + 20, 250)])), 2)
    D.side(S3, to_d(Polygon([(456, 250), (506, 92), (512, 92), (462, 250)])), 3)
    D.side_logo('Fest_Firmenlogo', logo, 330, 136, 26, key=BRAND[logo])
    D.side_text(S3, name + ' SERVICE', RB, 7, 330, 160, 3, track=0.25)
    D.side_text(W, kata, ZK, 9, 690, 128, 1)
    D.side_text(W, '0120-46-4646', RB, 7, 690, 146, 1, track=0.2)
    D.top(S2, to_d(Polygon([(-20, 560), (TW + 20, 520), (TW + 20, 920), (-20, 920)])), 2)
    D.top_logo(S2, logo, TW / 2, 150, 34, key=2)
D.write('bx_company_a')
