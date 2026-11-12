"""Hashiriya Battle – japanische Liveries für PA-Arbeiter und Polizei. Alle Firmen frei erfunden."""
import numpy as np
from livery import Ctx, zbands, hexc
import logos

# Fahrzeug-Maße (Meter, Fahrzeugkoordinaten; y vorne negativ). belt = Fensterunterkante,
# door1/door2 = Mitte vordere/hintere Tür, q = Mitte hinterer Kotflügel bzw. Ladefläche/Laderaum, ff = vorderer Kotflügel
GEO = {
    'pessima':   dict(belt=0.84, sill=0.30, door1=-0.45, door2=0.50, q=1.65, ff=-1.55, top=1.32, hood=0.80),
    'midsize':   dict(belt=0.90, sill=0.28, door1=-0.45, door2=0.55, q=1.75, ff=-1.60, top=1.40, hood=0.85),
    'sunburst2': dict(belt=0.84, sill=0.27, door1=-0.45, door2=0.45, q=1.55, ff=-1.55, top=1.40, hood=0.80),
    'pickup':    dict(belt=1.16, sill=0.45, door1=-0.28, door2=0.75, q=2.10, ff=-1.45, top=1.77, hood=1.15),
    'van':       dict(belt=1.32, sill=0.42, door1=-0.50, door2=0.90, q=1.55, ff=-1.55, top=2.18, hood=1.20),
}


class D:
    def __init__(self, model):
        self.m = model; self.c = Ctx(model); self.g = GEO[model]
        self.lo = self.c.lo

    def s(self, y):  # y -> Meter ab Front
        return y - self.lo[1]

    def sides(self):
        return [self.c.c('L'), self.c.c('R')]

    def both(self, fn):
        for cv in self.sides(): fn(cv)


# ---------------------------------------------------------------- Taxi
def taxi_shinonome(model='pessima'):
    """東雲交通 (Shinonome Kōtsū): klassisches Tokioter Zweifarben-Taxi, unten Tannengrün, oben Creme."""
    d = D(model); g = d.g; c = d.c
    GREEN, CREAM, ORANGE = '#1d5a3a', '#efe6cc', '#e8742a'
    split = 0.60
    base = zbands(c, [(-9, split, GREEN), (split, split + 0.018, ORANGE), (split + 0.018, split + 0.026, CREAM), (split + 0.026, split + 0.034, ORANGE)], CREAM)
    logo = logos.shinonome(GREEN, ORANGE, bg=CREAM)
    def side(cv):
        s1, s2 = d.s(g['door1']), d.s(g['door2'])
        cv.paste(s1 - 0.42, 0.725, logo, 0.19)
        cv.text(s1 + 0.08, 0.745, '東雲交通', 'mincho', 0.125, GREEN, anchor='mm', spacing=0.06)
        cv.text(s1 + 0.08, 0.655, 'SHINONOME TAXI', 'latin', 0.040, GREEN, spacing=0.25)
        cv.text(s1, 0.525, '☎ 03-5523-1188', 'jp', 0.06, CREAM)
        cv.text(s1, 0.455, '無線配車  24時間', 'jpb', 0.042, CREAM, spacing=0.1)
        # Hintertür: Nichtraucher-Aufkleber + Wagennummer
        sx = s2 + 0.15
        cv.ellipse(sx - 0.06, sx + 0.06, 0.69, 0.81, GREEN)
        cv.text(sx, 0.75, '禁煙', 'jp', 0.04, CREAM)
        cv.text(d.s(g['q']) - 0.05, 0.71, '東雲 27', 'jp', 0.075, GREEN, spacing=0.05)
        cv.text(s2, 0.50, '安全運転・禁煙車', 'jpb', 0.04, CREAM, spacing=0.1)
    d.both(side)
    B = c.c('B'); B.text(0, 0.50, '東雲交通 ☎ 03-5523-1188', 'jp', 0.04, CREAM)
    return c.bake(base)


def taxi_gekko(model='pessima'):
    """月光タクシー (Gekkō Taxi): Sonnengelb mit schwarzem Schachbrett-Gürtel, Mondsichel-Logo."""
    d = D(model); g = d.g; c = d.c
    YEL, BLK, WHT = '#f2b705', '#151515', '#ffffff'
    base = zbands(c, [(0.56, 0.625, BLK)], YEL)
    logo = logos.crescent(BLK, BLK, YEL)
    def side(cv):
        # Schachbrett im Gürtel
        q = 0.0325; s = d.s(-3)
        i = 0
        while s < d.c.L + 0.5:
            cv.rect(s, s + q, 0.56 + (q if i % 2 else 0), 0.56 + q + (q if i % 2 else 0), WHT); s += q; i += 1
        s1, s2 = d.s(g['door1']), d.s(g['door2'])
        cv.paste(s1 - 0.30, 0.73, logo, 0.16)
        cv.text(s1 + 0.12, 0.745, '月光タクシー', 'jp', 0.075, BLK, spacing=0.02)
        cv.text(s1 + 0.12, 0.675, 'GEKKO TAXI', 'latin', 0.034, BLK, spacing=0.3)
        cv.text(s2, 0.73, '☎ 03-3960-0808', 'jp', 0.048, BLK)
        cv.text(s2, 0.48, 'こころをこめて、夜の東京へ', 'jpb', 0.032, BLK, spacing=0.05)
        cv.text(d.s(g['q']), 0.70, '308', 'latin', 0.10, BLK)
    d.both(side)
    B = c.c('B'); B.text(0, 0.48, '月光タクシー 308', 'jp', 0.045, BLK)
    return c.bake(base)


# ---------------------------------------------------------------- Polizei
def police(model='midsize', unit='自動車警ら隊', number='首都 11'):
    """白黒パトカー: oben weiß, unten schwarz, 首都警察 (erfundene Behörde)."""
    d = D(model); g = d.g; c = d.c
    WHT, BLK, GOLD = '#f4f4f2', '#0e0e10', '#c9a227'
    split = g['sill'] + (g['belt'] - g['sill']) * 0.47
    base = zbands(c, [(-9, split, BLK)], WHT)
    emb = logos.police_emblem()
    def side(cv):
        s1, s2 = d.s(g['door1']), d.s(g['door2'])
        cv.text(s1 + 0.02, (split + g['belt']) / 2 + 0.005, '首都警察', 'jp', 0.12, BLK, spacing=0.12)
        cv.paste(s1 - 0.42, (split + g['belt']) / 2, emb, 0.11)
        cv.text(s2, (split + g['belt']) / 2 + 0.01, 'POLICE', 'latin', 0.085, BLK, spacing=0.12)
        cv.text(s2, split - 0.07, unit, 'jpb', 0.04, WHT, spacing=0.1)
        cv.text(d.s(g['ff']), split - 0.08, '110', 'latin', 0.07, WHT)
    d.both(side)
    T = c.c('T')  # Dachkennung für Hubschrauber, Front = oben im Bild
    roof_y = (g['door1'] + g['door2']) / 2
    T.text(0, d.s(roof_y) - 0.12, number.split()[0], 'jp', 0.24, BLK)
    T.text(0, d.s(roof_y) + 0.17, number.split()[1], 'latin', 0.30, BLK)
    B = c.c('B'); B.text(0, split - 0.06, 'POLICE', 'latin', 0.07, WHT, spacing=0.2)
    F = c.c('F'); F.text(0, split - 0.05, '首都警察', 'jp', 0.05, WHT, spacing=0.1)
    return c.bake(base)


# ---------------------------------------------------------------- Werkstatt / Abschleppdienst
def mechanic(model):
    """鉄心モータース (Tesshin Motors) – Werkstatt & Pannendienst: weiß, rot-schwarze Schrägstreifen."""
    d = D(model); g = d.g; c = d.c
    WHT, RED, BLK = '#f6f6f4', '#c8102e', '#161616'
    lowz = g['sill'] + 0.16
    base = zbands(c, [(-9, lowz, BLK), (lowz, lowz + 0.03, RED)], WHT)
    logo = logos.wrench(RED, BLK, WHT)
    h = g['belt'] - g['sill']
    def side(cv):
        L = d.c.L; s1 = d.s(g['door1'])
        # Rote Keilform am Heck, die nach vorne in den Gürtel ausläuft
        z0 = lowz + 0.03; zt = g['sill'] + h * 0.88
        sa = d.s(g['door2']) + 0.05
        cv.poly([(sa, z0), (L + 1, z0), (L + 1, zt), (sa + 0.9, zt)], RED)
        cv.poly([(sa + 0.95, zt + 0.02), (L + 1, zt + 0.02), (L + 1, zt + 0.05), (sa + 1.0, zt + 0.05)], BLK)
        cv.paste(s1 - 0.30, g['sill'] + h * 0.62, logo, h * 0.36)
        cv.text(s1 + 0.30, g['sill'] + h * 0.70, '鉄心モータース', 'jp', h * 0.13, BLK, spacing=0.03)
        cv.text(s1 + 0.30, g['sill'] + h * 0.55, 'TESSHIN MOTORS', 'latin', h * 0.075, RED, spacing=0.2)
        cv.text(d.s(g['q']) + 0.45, g['sill'] + h * 0.62, 'ロードサービス', 'jp', h * 0.12, WHT, spacing=0.05)
        cv.text(d.s(g['q']) + 0.45, g['sill'] + h * 0.45, '24時間 年中無休 ☎ 0120-48-9248', 'jpb', h * 0.06, WHT)
        cv.text(d.s(g['ff']), g['sill'] + h * 0.55, '整備・車検・板金', 'jpb', h * 0.065, BLK)
    d.both(side)
    T = c.c('T'); T.text(0, d.s(g['hood'] and g['ff']), '鉄心', 'jp', 0.25, RED)
    B = c.c('B'); B.text(0, g['sill'] + h * 0.55, 'ROAD SERVICE 24h', 'latin', 0.07, RED, spacing=0.15)
    F = c.c('F'); F.text(0, g['sill'] + h * 0.15, 'TESSHIN', 'latin', 0.06, WHT, spacing=0.2)
    return c.bake(base)


# ---------------------------------------------------------------- Spedition
def spedition(model):
    """燕運輸 (Tsubame Unyu): weiß, blaue Doppellinie mit Schwalbe, wie klassische japanische Speditionen."""
    d = D(model); g = d.g; c = d.c
    WHT, BLUE, SKY = '#f7f8f8', '#0b4ea2', '#3aa3e3'
    h = g['belt'] - g['sill']
    zA = g['sill'] + h * 0.22
    base = zbands(c, [(zA, zA + h * 0.07, BLUE), (zA + h * 0.10, zA + h * 0.13, SKY)], WHT)
    bird = logos.swallow(BLUE, SKY)
    def side(cv):
        s1 = d.s(g['door1']); sq = d.s(g['q'])
        cv.paste(s1, g['sill'] + h * 0.66, bird, h * 0.38)
        cv.text(s1, g['sill'] + h * 0.40, '燕運輸', 'jp', h * 0.14, BLUE, spacing=0.15)
        cv.text(sq, g['sill'] + h * 0.72, 'TSUBAME', 'latin', h * 0.20, BLUE, spacing=0.06)
        cv.text(sq, g['sill'] + h * 0.52, '燕運輸株式会社  TRANSPORT & LOGISTICS', 'jpb', h * 0.055, SKY)
        cv.text(sq, zA - h * 0.08, '安全・確実・迅速', 'jpb', h * 0.06, BLUE, spacing=0.2)
    d.both(side)
    B = c.c('B'); B.text(0, g['sill'] + h * 0.6, '燕運輸', 'jp', 0.10, BLUE); B.text(0, g['sill'] + h * 0.35, '安全運転宣言車', 'jpb', 0.045, BLUE)
    T = c.c('T'); T.paste(0, d.s(g['door2']), bird, 0.5)
    return c.bake(base)


# ---------------------------------------------------------------- Kurier
def courier(model):
    """狐急便 (Kitsune Kyūbin): weiß mit orangefarbenem Unterteil, Fuchskopf, Paketdienst-Optik."""
    d = D(model); g = d.g; c = d.c
    WHT, ORG, DARK = '#fbfaf7', '#ee7a1a', '#2b2b2b'
    h = g['belt'] - g['sill']
    zA = g['sill'] + h * 0.26
    base = zbands(c, [(-9, zA, ORG), (zA, zA + 0.012, DARK)], WHT)
    fx = logos.fox(ORG, WHT, DARK)
    def side(cv):
        s1 = d.s(g['door1']); sq = d.s(g['q'])
        cv.paste(s1 - 0.25, g['sill'] + h * 0.62, fx, h * 0.34)
        cv.text(s1 + 0.18, g['sill'] + h * 0.68, '狐急便', 'jp', h * 0.16, DARK, spacing=0.1)
        cv.text(s1 + 0.18, g['sill'] + h * 0.52, 'KITSUNE EXPRESS', 'latin', h * 0.06, ORG, spacing=0.2)
        cv.paste(sq - 0.55, g['sill'] + h * 0.66, fx, h * 0.48)
        cv.text(sq + 0.25, g['sill'] + h * 0.74, 'ひとっ走りで、', 'jp', h * 0.10, DARK)
        cv.text(sq + 0.25, g['sill'] + h * 0.58, 'お届けします。', 'jp', h * 0.10, ORG)
        cv.text(sq, zA - h * 0.12, '宅配便・クール便・時間帯指定', 'jpb', h * 0.055, WHT, spacing=0.1)
    d.both(side)
    B = c.c('B'); B.text(0, g['sill'] + h * 0.62, '狐急便', 'jp', 0.10, DARK); B.text(0, zA - 0.05, 'KITSUNE EXPRESS', 'latin', 0.05, WHT, spacing=0.2)
    T = c.c('T'); T.paste(0, d.s(g['door2']) + 0.2, fx, 0.55)
    return c.bake(base)


# ---------------------------------------------------------------- Krankenwagen
def ambulance(model):
    """救急車 des 首都消防 (erfundene Feuerwehr): weiß, roter Gürtel, Spiegelschrift vorne."""
    d = D(model); g = d.g; c = d.c
    WHT, RED = '#fafafa', '#d0112b'
    h = g['belt'] - g['sill']
    zA = g['sill'] + h * 0.45
    base = zbands(c, [(zA, zA + h * 0.10, RED), (zA + h * 0.14, zA + h * 0.17, RED)], WHT)
    emb = logos.fire_emblem(RED); sol = logos.star_of_life(RED)
    def side(cv):
        s1 = d.s(g['door1']); sq = d.s(g['q'])
        cv.paste(s1 - 0.28, g['sill'] + h * 0.78, emb, h * 0.24)
        cv.text(s1 + 0.12, g['sill'] + h * 0.78, '首都消防', 'jp', h * 0.10, RED, spacing=0.12)
        cv.text(s1, zA - h * 0.12, '救急', 'jp', h * 0.12, RED, spacing=0.2)
        cv.text(sq, g['sill'] + h * 0.80, '救急車', 'jp', h * (0.13 if d.m == 'pickup' else 0.17), RED, spacing=0.25)
        cv.paste(sq + 0.8, g['sill'] + h * 0.80, sol, h * 0.24)
        cv.text(sq, zA - h * 0.14, 'AMBULANCE  119', 'latin', h * 0.08, RED, spacing=0.15)
        cv.text(sq, g['sill'] + h * 0.14, '首都消防 第三救急隊', 'jpb', h * 0.05, RED)
    d.both(side)
    F = c.c('F')
    F.text(0, g['hood'] - 0.12, 'AMBULANCE'[::-1], 'latin', 0.09, RED, spacing=0.1)  # gespiegelt
    # Spiegelschrift richtig: Buchstaben selbst spiegeln
    F.img.paste((0, 0, 0, 0), [0, 0, F.w, F.h])
    from PIL import Image, ImageDraw
    tmp = Image.new('RGBA', (F.w, F.h), (0, 0, 0, 0)); F2 = F.img; F.img = tmp; F.d = ImageDraw.Draw(tmp)
    F.text(0, g['hood'] - 0.10, 'AMBULANCE', 'latin', 0.10, RED, spacing=0.1)
    F.img = tmp.transpose(Image.FLIP_LEFT_RIGHT); F.d = ImageDraw.Draw(F.img)
    T = c.c('T'); T.paste(0, d.s(g['door2']), sol, 0.6)
    T.text(0, d.s(g['door2']) + 0.6, '首都消防', 'jp', 0.18, RED)
    B = c.c('B'); B.text(0, g['sill'] + h * 0.75, '救急車', 'jp', 0.12, RED); B.text(0, zA - 0.06, '119', 'latin', 0.08, RED)
    return c.bake(base)


LIVERIES = [
    # id, Modell, Funktion, Name DE, Name EN
    ('hb_taxi_shinonome', 'pessima', taxi_shinonome, 'Taxi Shinonome Kotsu', 'Taxi Shinonome Kotsu'),
    ('hb_taxi_gekko', 'pessima', taxi_gekko, 'Taxi Gekko', 'Taxi Gekko'),
    ('hb_police', 'midsize', lambda m: police(m, '自動車警ら隊', '首都 11'), 'Polizei (首都警察)', 'Police (Shuto Keisatsu)'),
    ('hb_police', 'sunburst2', lambda m: police(m, '高速道路交通警察隊', '首都 7'), 'Polizei Autobahn (首都警察)', 'Highway Police (Shuto Keisatsu)'),
    ('hb_mechanic', 'pickup', mechanic, 'Werkstatt Tesshin Motors', 'Tesshin Motors road service'),
    ('hb_mechanic', 'van', mechanic, 'Werkstatt Tesshin Motors', 'Tesshin Motors road service'),
    ('hb_freight', 'pickup', spedition, 'Spedition Tsubame Unyu', 'Tsubame Unyu freight'),
    ('hb_freight', 'van', spedition, 'Spedition Tsubame Unyu', 'Tsubame Unyu freight'),
    ('hb_courier', 'pickup', courier, 'Kurier Kitsune Kyubin', 'Kitsune Express courier'),
    ('hb_courier', 'van', courier, 'Kurier Kitsune Kyubin', 'Kitsune Express courier'),
    ('hb_ambulance', 'pickup', ambulance, 'Krankenwagen (首都消防)', 'Ambulance (Shuto Fire Dept.)'),
    ('hb_ambulance', 'van', ambulance, 'Krankenwagen (首都消防)', 'Ambulance (Shuto Fire Dept.)'),
]

if __name__ == '__main__':
    import sys, os
    from livery import WORK
    out = os.path.join(WORK, 'out') + os.sep; os.makedirs(out, exist_ok=True)
    only = sys.argv[1:]
    for sid, m, fn, de, en in LIVERIES:
        key = f'{m}_{sid}'
        if only and not any(o in key for o in only): continue
        im = fn(m)
        im.save(out + key + '.png'); print('ok', key, im.size)
