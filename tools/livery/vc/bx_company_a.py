# Firmenwagen (Lieferwagen/Servicewagen einer Lore-Firma): Firmenlogo gross in Farbe 2, Zierband in Farbe 2/3,
# Service-Zeile mit Telefonnummer (erfunden), Logo auf dem Dach.
from shapely.geometry import Polygon
from vcsvg import Doc
from cars import CAR
from tribal import to_d
D = Doc(); C = CAR[D.model]; L, TW = D.lw, D.tw
RB, ZK = 'RobotoCondensed.ttf', 'ZenKakuGothicNew-Bold.ttf'
CO = {'pigeon': ('tims', 'TIMS', 'ティムス配送'), 'hopper': ('selecta', 'SELECTA', 'セレクタ・サービス')}.get(D.model, ('nodeoline', 'NODEOLINE', 'ノードオライン'))
logo, name, kata = CO
S2, S3 = 'Farbe_2_Firmenlogo_Band_GRUEN', 'Farbe_3_Zierlinie_Schrift_BLAU'
D.side(S2, to_d(Polygon([(-20, 172), (L + 20, 172), (L + 20, 186), (-20, 186)])), 2)
D.side(S3, to_d(Polygon([(-20, 166), (L + 20, 166), (L + 20, 168.5), (-20, 168.5)])), 3)
if D.model == 'pigeon':  # grosse Kofferflaeche: Logo + Katakana gross auf den Aufbau
    D.side_logo(S2, logo, 680, 70, 46, key=2)
    D.side_text(S3, kata, ZK, 15, 680, 118, 3)
else:
    D.side_logo(S2, logo, 450, 128, 26, key=2)
    D.side_text(S3, kata, ZK, 9, 450, 151, 3)
D.side_text(S3, name + ' SERVICE  ·  0120-46-4646', RB, 6.5, 450, 197, 3, track=0.2)
D.top_logo(S2, logo, TW / 2, 520, 36, key=2)
D.write('bx_company_a')
