"""Hashiriya Battle – lackierbare Japan-Liveries in 6 Stilen (Farbe 2 + Farbe 3, Farbe 1 = Grundlack).
Alle Sponsoren frei erfunden bzw. BeamNG-Lore-Marken (Ibishu, Hirochi). Keine echten Marken.

Die Formen werden in Fahrzeug-Einheiten beschrieben: u = 0 Mitte Vorderrad … 1 Mitte Hinterrad (Werte darüber/darunter
gehen Richtung Heck/Front), v = 0 Schweller … 1 Fensterlinie. So passt ein Entwurf auf alle Modelle.
"""
import math, random
import numpy as np
from paint import PaintCtx

# Maße je Modell (Meter, BeamNG-Koordinaten, vorne = -y):
# yf/yr Radmitte vorne/hinten, wr Radradius, belt Fensterunterkante, sill Schwellerhöhe, ws Scheibenfuß vorne (y),
# rw Heckscheibe/Kofferraum-Beginn (y), hood Haubenhöhe vorne (z), half halbe Breite
GEO = {
    'pessima':   dict(yf=-1.40, yr=1.36, wr=0.29, belt=0.84, sill=0.30, ws=-0.95, rw=1.50, hood=0.80, half=0.86),
    'midsize':   dict(yf=-1.45, yr=1.40, wr=0.31, belt=0.92, sill=0.27, ws=-1.00, rw=1.60, hood=0.85, half=0.90),
    'bx':        dict(yf=-1.45, yr=1.20, wr=0.30, belt=0.82, sill=0.30, ws=-0.95, rw=1.40, hood=0.78, half=0.83),
    'covet':     dict(yf=-1.40, yr=1.15, wr=0.29, belt=0.86, sill=0.28, ws=-0.95, rw=1.30, hood=0.80, half=0.89),
    'hopper':    dict(yf=-1.10, yr=1.10, wr=0.36, belt=1.10, sill=0.47, ws=-0.68, rw=1.70, hood=1.05, half=0.76),
    'miramar':   dict(yf=-1.25, yr=1.20, wr=0.30, belt=0.88, sill=0.32, ws=-0.70, rw=1.50, hood=0.85, half=0.80),
    'pigeon':    dict(yf=-0.95, yr=1.00, wr=0.25, belt=0.95, sill=0.36, ws=-0.85, rw=1.70, hood=0.90, half=0.63),
    'sunburst2': dict(yf=-1.40, yr=1.15, wr=0.30, belt=0.88, sill=0.26, ws=-0.85, rw=1.40, hood=0.80, half=0.86),
    'sbr':       dict(yf=-1.40, yr=1.30, wr=0.31, belt=0.80, sill=0.26, ws=-0.80, rw=1.50, hood=0.75, half=0.89),
}
BRAND = {'pessima': 'IBISHU', 'midsize': 'IBISHU', 'bx': 'IBISHU', 'covet': 'IBISHU', 'hopper': 'IBISHU', 'miramar': 'IBISHU',
         'pigeon': 'IBISHU', 'sunburst2': 'HIROCHI', 'sbr': 'HIROCHI'}
MODEL = {'pessima': 'Pessima', 'midsize': 'Pessima', 'bx': '200BX', 'covet': 'Covet', 'hopper': 'Hopper', 'miramar': 'Miramar',
         'pigeon': 'Pigeon', 'sunburst2': 'Sunburst', 'sbr': 'SBR4'}
INK = '#ffffff'  # Zeichenfarbe auf den Ebenen (nur Alpha zählt)


class G:
    """Umrechnung u/v -> Leinwand-Koordinaten (s = Meter ab Front, z)."""
    def __init__(self, pc, model):
        self.pc = pc; self.g = GEO[model]; self.model = model
        self.lo = pc.ctx.lo; self.hi = pc.ctx.hi
        self.sf = self.g['yf'] - self.lo[1]; self.sr = self.g['yr'] - self.lo[1]
        self.wb = self.sr - self.sf; self.vh = self.g['belt'] - self.g['sill']

    def s(self, u): return self.sf + u * self.wb
    def z(self, v): return self.g['sill'] + v * self.vh
    def uv(self, u, v): return (self.s(u), self.z(v))
    def m(self, x): return x * self.vh  # Breite relativ zur Seitenhöhe
    # Haube von oben: b = Meter ab Front
    @property
    def hood0(self): return max(self.g['yf'] - 0.55, self.lo[1] + 0.15) - self.lo[1]
    @property
    def hood1(self): return self.g['ws'] - self.lo[1] - 0.08


def bez(p0, p1, p2, p3, n=48):
    t = np.linspace(0, 1, n)[:, None]
    P = [np.array(p, float) for p in (p0, p1, p2, p3)]
    return (1 - t) ** 3 * P[0] + 3 * (1 - t) ** 2 * t * P[1] + 3 * (1 - t) * t ** 2 * P[2] + t ** 3 * P[3]


def blade_pts(spine, w0, w1=0.0, p=1.0, swell=0.0):
    """Spitz zulaufende Klinge entlang einer Kurve. w0 Breite am Ansatz, w1 an der Spitze (Meter)."""
    d = np.gradient(spine, axis=0); n = np.c_[-d[:, 1], d[:, 0]]; n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
    t = np.linspace(0, 1, len(spine))
    w = w0 * (1 - t) ** p + w1 * t + swell * np.sin(np.pi * t) * w0
    a = spine + n * (w / 2)[:, None]; b = spine - n * (w / 2)[:, None]
    return [tuple(x) for x in np.r_[a, b[::-1]]]


# ---------------------------------------------------------------------- Hilfen
from livery import font as _font

MODELS = list(GEO)
SHIFT = {'hb_streetdrift': 0, 'hb_factorysports': 1, 'hb_bosozoku': 2, 'hb_kaido': 0, 'hb_twotone': 1, 'hb_raceteam': 2}


def variant(model, sid, n):
    """Variante je Modell: Nachbarn in der Liste bekommen verschiedene Varianten, jedes Modell bleibt reproduzierbar."""
    return (MODELS.index(model) + SHIFT.get(sid, 0)) % n


def rng(model, sid):
    return random.Random(f'{model}/{sid}')


def thorn(root, ang, L, curl, n=40):
    """Dorn ab root, Richtung ang (Grad, 0 = +a = Richtung Heck auf den Seiten), Länge L (Meter), curl = Biegung (Grad)."""
    a0 = math.radians(ang); a1 = math.radians(ang + curl); am = (a0 + a1) / 2
    p0 = np.array(root, float)
    p3 = p0 + L * np.array([math.cos(am), math.sin(am)])
    p1 = p0 + 0.4 * L * np.array([math.cos(a0), math.sin(a0)])
    p2 = p3 - 0.4 * L * np.array([math.cos(a1), math.sin(a1)])
    return bez(p0, p1, p2, p3, n)


def both(ly, fn):
    for cv in ly.sides(): fn(cv)


def tw(text, fname, h):
    """Textbreite in Metern bei Schrifthöhe h."""
    f = _font(fname, h * 300)
    return f.getlength(text) / 300


def rrect(cv, a0, a1, b0, b1, r):
    p0 = cv.px(a0, b0); p1 = cv.px(a1, b1)
    box = [min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1])]
    cv.d.rounded_rectangle(box, radius=max(1, int(r * cv.ppm)), fill=(255, 255, 255, 255))


def sticker(box, txt, a, b, text, fname, h, pad=0.35, style='box'):
    """Sponsor-Aufkleber: Kasten (Farbe 3) mit ausgesparter Schrift (Farbe 1). Gibt die Breite zurück."""
    w = tw(text, fname, h) + h * pad * 2
    hh = h * 1.55
    if style == 'box': rrect(box, a - w / 2, a + w / 2, b - hh / 2, b + hh / 2, h * 0.25)
    elif style == 'pill': rrect(box, a - w / 2, a + w / 2, b - hh / 2, b + hh / 2, hh / 2)
    txt.text(a, b, text, fname, h, INK, anchor='mm')
    return w


SPONSORS = [('KAZE WORKS', 'racing'), ('RYUSEI', 'racing'), ('TOBIUO OIL', 'latin'), ('IKAZUCHI', 'racing'), ('MUGETSU WHEELS', 'latin'),
            ('KURENAI TUNE', 'racing'), ('SHINDEN', 'dela'), ('YOKAZE', 'racing'), ('KITSUNE AUDIO', 'latin'), ('AOI SEATS', 'latin'),
            ('GEKKO LIGHTS', 'latin'), ('HAGANE BRAKES', 'latin'), ('TSUBAME', 'racing'), ('HIROCHI SPORT', 'latin'), ('IBISHU TECNICA', 'latin'),
            ('SUZAKU EXHAUST', 'latin'), ('ODORI', 'racing'), ('HOSHI GARAGE', 'latin')]
TEAMS = ['Team Kaze Works', 'Ryusei Factory', 'Midnight Kurenai', 'Shinden Garage', 'Yokaze Style', 'Tobiuo Drift', 'Kasumi Nightrun',
         'Tsubame Sports', 'Hoshi Garage']
DRIVERS = ['K. Takeda', 'R. Morikawa', 'S. Hino', 'T. Aoyama', 'M. Kuroda', 'Y. Fujii', 'H. Sakai', 'N. Ishida', 'J. Kamiya']
KATAKANA = ['カイドーレーサー', 'ハシリヤ', 'リュウセイ', 'ヨカゼ', 'クレナイ', 'イカズチ', 'ツバメ', 'ゲッコウ', 'スザク']
GANGS = ['夜叉連合', '紅蓮會', '雷神會', '月光連合', '疾風組', '鬼神會', '朱雀連合', '黒龍會', '流星會']


def hood_box(G_):
    h0, h1, half = G_.hood0, G_.hood1, G_.g['half']
    return h0, h1, half, (h0 + h1) / 2


# ---------------------------------------------------------------------- Tribal-Generatoren (Seitenflächen, Einheiten u/v)
def tribal_shards(G_, rnd):
    """Zerrissene Splitter (wie Street-Drift-Shard-Tribals): gestaffelte Klingen mit Widerhaken."""
    S = []
    path = bez(G_.uv(-0.30, 0.55), G_.uv(0.20, 0.20), G_.uv(0.70, 0.30), G_.uv(1.30, 0.80))
    for i in range(9):
        t = 0.04 + i * 0.11 + rnd.uniform(-0.02, 0.02)
        r = path[int(min(t, 0.98) * (len(path) - 1))] + np.array([0, G_.m(rnd.uniform(-0.08, 0.10))])
        ang = rnd.uniform(8, 30); L = G_.wb * rnd.uniform(0.15, 0.27); w = G_.m(rnd.uniform(0.10, 0.17))
        sp = thorn(r, ang, L, rnd.uniform(-15, 10))
        S.append((sp, w, 0.0, 1.3, 0.15))
        for k in range(rnd.choice((1, 2))):
            m = sp[int(rnd.uniform(0.3, 0.6) * (len(sp) - 1))]
            S.append((thorn(m, rnd.choice((-1, 1)) * rnd.uniform(25, 45) + ang, L * rnd.uniform(0.25, 0.4), 0), w * 0.45, 0.0, 1.0, 0.1))
    return S


def tribal_flow(G_, rnd):
    """Lange, dünne Schwünge mit Haken (rauchiger Street-Tribal)."""
    S = []
    for i in range(6):
        u0 = rnd.uniform(-0.25, 0.30); v0 = rnd.uniform(0.18, 0.62)
        u1 = rnd.uniform(1.05, 1.38); v1 = min(1.0, v0 + rnd.uniform(0.10, 0.40))
        sp = bez(G_.uv(u0, v0), G_.uv(u0 + 0.35, v0 - rnd.uniform(0.05, 0.2)), G_.uv(u1 - 0.40, v1 + rnd.uniform(-0.05, 0.15)), G_.uv(u1, v1))
        w = G_.m(rnd.uniform(0.05, 0.10))
        S.append((sp, w * 0.25, 0.0, 1.0, 1.1))
        hk = thorn(sp[-6], rnd.uniform(40, 80), G_.m(rnd.uniform(0.25, 0.4)), rnd.uniform(60, 110))
        S.append((hk, w * 0.7, 0.0, 1.0, 0.2))
        for k in range(2):
            m = sp[int(rnd.uniform(0.35, 0.75) * (len(sp) - 1))]
            S.append((thorn(m, rnd.uniform(15, 45), G_.wb * rnd.uniform(0.07, 0.13), rnd.uniform(-30, 0)), w * 0.6, 0.0, 1.0, 0.1))
    return S


def tribal_splash(G_, rnd):
    """Großer Tribal-Körper mit Stacheln oben und unten (Platz für eine Unterschrift darüber)."""
    S = []
    main = bez(G_.uv(0.05, 0.30), G_.uv(0.40, 0.10), G_.uv(0.85, 0.50), G_.uv(1.32, 0.88))
    S.append((main, G_.m(0.42), 0.0, 0.55, 0.35))
    for i in range(5):
        t = 0.12 + i * 0.15 + rnd.uniform(-0.03, 0.03)
        r = main[int(t * (len(main) - 1))] + np.array([0, G_.m(0.10)])
        S.append((thorn(r, rnd.uniform(35, 70), G_.wb * rnd.uniform(0.12, 0.22), rnd.uniform(-50, -20)), G_.m(rnd.uniform(0.10, 0.15)), 0.0, 1.0, 0.25))
    for i in range(3):
        t = 0.25 + i * 0.2
        r = main[int(t * (len(main) - 1))] - np.array([0, G_.m(0.08)])
        S.append((thorn(r, rnd.uniform(-35, -15), G_.wb * rnd.uniform(0.10, 0.16), rnd.uniform(15, 35)), G_.m(0.09), 0.0, 1.0, 0.2))
    S.append((thorn(G_.uv(0.08, 0.30), 165, G_.wb * 0.12, -80), G_.m(0.12), 0.0, 1.0, 0.3))
    return S


def hood_tribal(G_, rnd, kind):
    """Symmetrisches Tribal-Emblem auf der Haube (a = quer, b = Meter ab Front)."""
    h0, h1, half, hc = hood_box(G_)
    L = h1 - h0; S = []
    if kind == 0:   # Flügel
        S.append((bez((0, h0 + L * 0.15), (0, h0 + L * 0.4), (0, h0 + L * 0.6), (0, h0 + L * 0.85)), 0.02, 0.0, 1.0, 3.0))
        for sx in (-1, 1):
            for i, (t, ang, ln) in enumerate(((0.35, 25, 0.55), (0.48, 45, 0.45), (0.60, 65, 0.32))):
                a = 0 if sx > 0 else 180
                S.append((thorn((sx * 0.03, h0 + L * t), a + sx * ang, half * ln, sx * rnd.uniform(25, 45)), 0.08 - i * 0.015, 0.0, 1.0, 0.25))
    elif kind == 1:  # Kantenstreifen mit Haken
        for sx in (-1, 1):
            sp = bez((sx * half * 0.86, h0 + 0.02), (sx * half * 0.80, h0 + L * 0.35), (sx * half * 0.70, h0 + L * 0.70), (sx * half * 0.48, h1))
            S.append((sp, 0.10, 0.0, 0.8, 0.35))
            S.append((thorn(tuple(sp[20]), (180 if sx > 0 else 0) - sx * 40, half * 0.35, -sx * 50), 0.05, 0.0, 1.0, 0.2))
            S.append((thorn(tuple(sp[32]), (180 if sx > 0 else 0) - sx * 60, half * 0.25, -sx * 40), 0.04, 0.0, 1.0, 0.2))
    else:            # Flamme aus der Mitte nach hinten
        for sx in (-1, 1):
            for i in range(3):
                r = (sx * half * (0.10 + i * 0.12), h0 + L * (0.10 + i * 0.05))
                S.append((thorn(r, 90 + sx * rnd.uniform(5, 25), L * (0.75 - i * 0.18), -sx * rnd.uniform(10, 30)), 0.09, 0.0, 1.0, 0.3))
    return S


def draw_shapes(cv, S, grow):
    for sp, w0, w1, p, sw in S:
        cv.poly(blade_pts(sp, w0 + grow * 2, w1 + grow, p, sw), INK)


# ====================================================================== 1 Street-Drift
def street_drift(model):
    """Street-Drift: Tribal (Splitter, Schwünge oder großer Körper – je Auto anders), großer Team-Schriftzug,
    Sponsor-Aufkleber am Kotflügel, Tribal-Emblem auf der Haube, Teamname an der Frontlippe.
    Farbe 2 = Tribal, Farbe 3 = Umrandung, Schriftzug, Aufkleber; Aufkleber-Schrift in Farbe 1."""
    sid = 'hb_streetdrift'
    pc = PaintCtx(model); G_ = G(pc, model); rnd = rng(model, sid); var = variant(model, sid, 3)
    out3 = pc.layer(3, 'Farbe 3 Umrandung'); fill2 = pc.layer(2, 'Farbe 2 Tribal'); sig1 = pc.layer(1, 'Farbe 1 Schrift-Rand')
    top3 = pc.layer(3, 'Farbe 3 Schriftzug + Aufkleber'); knock1 = pc.layer(1, 'Farbe 1 Aufkleber-Schrift')
    S = [tribal_shards, tribal_flow, tribal_splash][var](G_, rnd)
    for cv in out3.sides(): draw_shapes(cv, S, 0.014)
    for cv in fill2.sides(): draw_shapes(cv, S, 0.0)
    H = hood_tribal(G_, rnd, (var + 1) % 3)
    draw_shapes(out3.c('T'), H, 0.012); draw_shapes(fill2.c('T'), H, 0.0)

    team = TEAMS[MODELS.index(model) % len(TEAMS)]
    sp = rnd.sample(SPONSORS, 6)
    sh = G_.m(0.075)

    def side(cvs):
        cv_sig, cv_top, cv_kn = cvs
        if var == 2:   # Unterschrift über dem Tribal-Körper in Farbe 1
            cv_kn.text(G_.s(0.70), G_.z(0.50), team.replace('Team ', ''), 'kaushan', G_.m(0.26), INK, anchor='mm')
        else:
            a, b = G_.s(0.80), G_.z(0.80)
            cv_sig.text(a, b, team, 'kaushan', G_.m(0.20), INK, anchor='mm', stroke=G_.m(0.018))
            cv_top.text(a, b, team, 'kaushan', G_.m(0.20), INK, anchor='mm')
        # Aufkleber-Stapel hinter dem Vorderrad
        y = 0.93
        for i in range(3):
            t, f = sp[i]
            sticker(cv_top, cv_kn, G_.s(0.20), G_.z(y), t, f, sh * (1.0 if i else 1.2), style='pill' if i == 1 else 'box')
            y -= 0.16 if i == 0 else 0.13
        # kleiner Aufkleber hinten unten
        t, f = sp[3]; sticker(cv_top, cv_kn, G_.s(1.20), G_.z(0.22), t, f, sh * 0.85)
        cv_top.text(G_.s(0.20), G_.z(0.50), sp[4][0], sp[4][1], sh * 0.9, INK, anchor='mm', spacing=0.05)
    for cvs in zip(sig1.sides(), top3.sides(), knock1.sides()): side(cvs)
    h0, h1, half, hc = hood_box(G_)
    top3.c('T').text(0, h0 + 0.10, sp[0][0], sp[0][1], 0.065, INK, spacing=0.05)
    top3.c('F').text(0, G_.g['sill'] + 0.12, team.upper() + '  走り屋', 'jp', 0.04, INK, spacing=0.08)
    top3.c('B').text(0, G_.z(0.92), team, 'kaushan', 0.07, INK)
    return pc


# ====================================================================== 2 Factory Sports
def factory_sports(model):
    """Werks-Sportpaket der 80er/90er, drei Varianten: Blitz am Heck-Kotflügel, lange Klebestreifen, Stufenstreifen unten.
    Farbe 2 = Hauptstreifen, Farbe 3 = Begleitstreifen + Schriftzüge."""
    sid = 'hb_factorysports'
    pc = PaintCtx(model); G_ = G(pc, model); var = variant(model, sid, 3)
    l3 = pc.layer(3, 'Farbe 3 Begleitstreifen'); l2 = pc.layer(2, 'Farbe 2 Streifen'); tx = pc.layer(3, 'Farbe 3 Schrift')
    brand = BRAND.get(model, 'IBISHU'); name = MODEL.get(model, model)
    grade = ['Sports', 'GT Twincam', 'Turbo RS', 'SR Limited', 'GTi-R', 'Sprint', 'Super Sport', 'Type S', 'RS-X'][MODELS.index(model)]
    h0, h1, half, hc = hood_box(G_)
    if var == 0:
        def side(cv, k):
            a0 = G_.s(0.62)
            if k == 2:
                cv.poly([(a0, G_.z(0.86)), (G_.s(1.40), G_.z(0.92)), (G_.s(1.40), G_.z(0.76)), (a0 + G_.wb * 0.10, G_.z(0.72))], INK)
                for zz, ll in ((0.64, 0.62), (0.52, 0.44)):
                    cv.poly([(G_.s(1.40 - ll), G_.z(zz)), (G_.s(1.40), G_.z(zz + 0.02)), (G_.s(1.40), G_.z(zz - 0.05)), (G_.s(1.40 - ll + 0.06), G_.z(zz - 0.06))], INK)
            else:
                cv.poly([(a0 - G_.wb * 0.08, G_.z(0.69)), (G_.s(1.40), G_.z(0.73)), (G_.s(1.40), G_.z(0.70)), (a0 - G_.wb * 0.03, G_.z(0.665))], INK)
        txt_at = (1.02, 1.03)
    elif var == 1:
        def side(cv, k):
            if k == 2:
                cv.rect(G_.s(-0.10), G_.s(1.45), G_.z(0.70), G_.z(0.76), INK)
                for i in range(6):   # Strichelung vorne
                    a = G_.s(-0.12 - i * 0.045); cv.rect(a - G_.wb * (0.025 - i * 0.003), a, G_.z(0.70), G_.z(0.76), INK)
            else:
                cv.rect(G_.s(-0.10), G_.s(1.45), G_.z(0.64), G_.z(0.665), INK)
                cv.rect(G_.s(-0.10), G_.s(1.45), G_.z(0.79), G_.z(0.805), INK)
        txt_at = (1.05, 0.92)
    else:
        def side(cv, k):
            for i, (zz, ln) in enumerate(((0.36, 0.95), (0.26, 0.80), (0.16, 0.65))):
                if (i == 1) != (k == 3): continue
                a1 = G_.s(0.90); a0 = G_.s(0.90 - ln)
                cv.poly([(a0, G_.z(zz)), (a1 - G_.wb * 0.04, G_.z(zz)), (a1, G_.z(zz + 0.07)), (a0 + G_.wb * 0.02, G_.z(zz + 0.07))], INK)
        txt_at = (0.60, 0.50)
    for cv in l3.sides(): side(cv, 3)
    for cv in l2.sides(): side(cv, 2)
    def t(cv):
        cv.text(G_.s(txt_at[0]), G_.z(txt_at[1]), f'{name} {grade}', 'kaushan', G_.m(0.15), INK, anchor='mm')
        cv.text(G_.s(0.18), G_.z(0.66), 'TWINCAM 16 VALVE' if var != 1 else 'DOHC TURBO', 'latin', G_.m(0.045), INK, anchor='mm', spacing=0.25)
    both(tx, t)
    for ly, w in ((l3, 0.020), (l2, 0.05)):
        T = ly.c('T'); x = half * (0.55 if ly is l2 else 0.62)
        for sx in (-1, 1):
            T.poly([(sx * x, h0 + 0.05), (sx * (x + w), h0 + 0.05), (sx * (x + w - 0.10), h0 + (h1 - h0) * 0.45), (sx * (x - 0.10), h0 + (h1 - h0) * 0.45)], INK)
    tx.c('T').text(0, h1 - 0.12, brand, 'latin', 0.05, INK, spacing=0.6)
    tx.c('B').text(0, G_.z(0.85), f'{brand}  {name.upper()}  {grade.upper()}', 'latin', 0.035, INK, spacing=0.3)
    return pc


# ====================================================================== 3 Bosozoku
def star(cx, cy, r, ri=0.42, rot=-90):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * ri
        a = math.radians(rot + i * 36)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def bosozoku(model):
    """Bōsōzoku, drei Varianten: Zickzack-Blitz + Stern, Mittelstreifen über Haube/Dach + Stern, Flammen aus den Radläufen.
    Dazu Kanji-Gangname und Sprüche. Farbe 2 = Blitz/Flammen/Stern, Farbe 3 = Kanten, Streifen, Kanji."""
    sid = 'hb_bosozoku'
    pc = PaintCtx(model); G_ = G(pc, model); var = variant(model, sid, 3); rnd = rng(model, sid)
    l3 = pc.layer(3, 'Farbe 3 Kanten + Streifen'); l2 = pc.layer(2, 'Farbe 2 Blitz + Stern'); tx = pc.layer(3, 'Farbe 3 Kanji')
    gang = GANGS[MODELS.index(model) % len(GANGS)]
    h0, h1, half, hc = hood_box(G_)
    def bolt(cv, grow, thin=False):
        h = G_.m(0.20 if not thin else 0.10) / 2 + grow
        P = [(-0.45, 0.70), (0.30, 0.70), (0.42, 0.34), (0.78, 0.34), (0.90, 0.68), (1.40, 0.68)]
        P = [G_.uv(a, b) for a, b in P]
        top = [(x - grow, y + h) for x, y in P[:-1]]; bot = [(x + grow * 0.5, y - h) for x, y in P[:-1]]
        cv.poly(top + [(P[-1][0] + grow * 2, P[-1][1])] + bot[::-1], INK)
    if var in (0, 1):
        for cv in l3.sides(): bolt(cv, G_.m(0.035), var == 1)
        for cv in l2.sides(): bolt(cv, 0, var == 1)
    if var == 1:   # breiter Mittelstreifen über Haube, Dach, Kofferraum
        T = l3.c('T'); T.rect(-0.22, 0.22, h0 - 0.2, G_.lo[1] * 0 + 9, INK)
        l2.c('T').poly(star(0, hc, 0.20, rot=90), INK)
        l3.c('F').rect(-0.22, 0.22, G_.g['hood'] - 0.12, G_.g['hood'] + 0.3, INK)
        l3.c('B').rect(-0.22, 0.22, G_.z(0.85), G_.z(2.0), INK)
    else:
        for ly, r in ((l3, 0.30), (l2, 0.26)): ly.c('T').poly(star(0, hc, r, rot=90), INK)
    if var == 2:   # Flammen aus den Radläufen nach hinten
        F = []
        for u0 in (0.0, 1.0):
            for i in range(5):
                ang = 15 + i * 9 + rnd.uniform(-4, 4)
                r = G_.uv(u0 + 0.10 + i * 0.015, 0.45 + i * 0.07)
                F.append((thorn(r, ang, G_.wb * (0.42 - abs(i - 2) * 0.07) * (0.6 if u0 > 0.5 else 1), rnd.uniform(-25, 5)), G_.m(0.15), 0.0, 1.1, 0.4))
        for cv in l3.sides(): draw_shapes(cv, F, 0.014)
        for cv in l2.sides(): draw_shapes(cv, F, 0.0)
    def kanji(cv):
        cv.text(G_.s(1.12), G_.z(0.76), gang, 'mincho', G_.m(0.11), INK, vertical=True, anchor='mm', spacing=0.02)
        cv.text(G_.s(0.10), G_.z(0.88), ['夜露死苦', '爆走', '喧嘩上等', '天上天下'][MODELS.index(model) % 4], 'jp', G_.m(0.08), INK, anchor='mm')
        cv.text(G_.s(0.60), G_.z(0.15), '全国制覇', 'mincho', G_.m(0.07), INK, anchor='mm', spacing=0.2)
    both(tx, kanji)
    tx.c('B').text(0, G_.z(0.75), f'{gang} 首都高', 'mincho', 0.07, INK, spacing=0.1)
    return pc


# ====================================================================== 4 Kaido-Racer
def kaido_racer(model):
    """Kaidō-Racer (Rennwagen-Look der 70er, kein Stockcar): drei Varianten – Teilung mit Zickzack-Pfeil,
    Geschwindigkeitsbalken am Heck, klassischer Nummernkreis mit Zierlinien und Karo.
    Dazu Startnummer, Katakana-Teamname, Kanji-Aufkleber, Sponsoren."""
    sid = 'hb_kaido'
    pc = PaintCtx(model); G_ = G(pc, model); var = variant(model, sid, 3); rnd = rng(model, sid)
    l2 = pc.layer(2, 'Farbe 2 Fläche + Nummer'); l3 = pc.layer(3, 'Farbe 3 Pfeil/Balken/Kreis'); n2 = pc.layer(2, 'Farbe 2 Nummer')
    tx = pc.layer(3, 'Farbe 3 Schrift + Aufkleber'); kn = pc.layer(1, 'Farbe 1 Aufkleber-Schrift')
    num = str(rnd.choice([3, 7, 11, 13, 21, 27, 33, 43, 55, 67, 77, 88]))
    kata = KATAKANA[MODELS.index(model) % len(KATAKANA)]
    h0, h1, half, hc = hood_box(G_)
    split = 0.48
    if var == 0:   # vorne Farbe 2, Zickzack-Pfeil in Farbe 3 an der Teilung
        P = [(split - 0.02, 1.2), (split + 0.10, 0.80), (split - 0.02, 0.62), (split + 0.16, 0.30), (split + 0.02, 0.12), (split + 0.12, -0.3)]
        def sd(cv):
            cv.poly([(-1, G_.z(1.3))] + [G_.uv(a, b) for a, b in P] + [(-1, G_.z(-0.5))], INK)
        both(l2, sd)
        def arrow(cv):
            w = 0.07
            top = [G_.uv(a, b) for a, b in P]; bot = [G_.uv(a + w, b) for a, b in P]
            cv.poly(top + bot[::-1], INK)
        both(l3, arrow)
        l2.c('T').rect(-3, 3, -1, G_.s(split) - 0.02, INK)
        l2.c('F').rect(-3, 3, -1, 3, INK)
        nx, ny = 0.80, 0.52
    elif var == 1:   # hinten Farbe 2, Geschwindigkeitsbalken nach vorne
        def sd(cv):
            cv.rect(G_.s(0.62), 9, -1, 9, INK)
        both(l2, sd)
        def bars(cv):
            for i in range(10):
                v0 = 0.02 + i * 0.10
                ln = 0.10 + i * 0.035
                cv.rect(G_.s(0.62 - ln), G_.s(0.64), G_.z(v0), G_.z(v0 + 0.05), INK)
        both(l3, bars)
        l2.c('T').rect(-3, 3, G_.g['rw'] - G_.lo[1], 9, INK)
        l2.c('B').rect(-3, 3, -1, 3, INK)
        nx, ny = 0.30, 0.55
    else:            # klassisch: Zierlinien, Karo, Nummernkreis
        def lines(cv):
            cv.rect(G_.s(-0.40), G_.s(1.45), G_.z(0.88), G_.z(0.92), INK)
            cv.rect(G_.s(-0.40), G_.s(1.45), G_.z(0.06), G_.z(0.10), INK)
        both(l2, lines)
        def checker(cv):
            q = G_.m(0.055)
            for i in range(8):
                for j in range(3):
                    if (i + j) % 2: continue
                    a = G_.s(1.05) + i * q; b = G_.z(0.70) + j * q
                    cv.rect(a, a + q, b, b + q, INK)
        both(l3, checker)
        nx, ny = 0.40, 0.52
    R = G_.m(0.36)
    def circ(cv):
        c = G_.uv(nx, ny); cv.ellipse(c[0] - R, c[0] + R, c[1] - R, c[1] + R, INK)
    both(l3, circ)
    def number(cv):
        cv.text(G_.s(nx), G_.z(ny), num, 'mincho' if var == 2 else 'dela', G_.m(0.42), INK, anchor='mm')
    both(n2, number)
    l3.c('T').ellipse(-0.24 + half * 0.35, 0.24 + half * 0.35, hc - 0.24, hc + 0.24, INK)
    n2.c('T').text(half * 0.35, hc, num, 'dela', 0.28, INK)
    sp = rnd.sample(SPONSORS, 4)
    def t(cv_t, cv_k):
        cv_t.text(G_.s(1.08 if var != 1 else -0.10), G_.z(0.86 if var != 2 else 0.60), kata, 'jp', G_.m(0.10), INK, anchor='mm', spacing=0.02)
        cv_t.text(G_.s(-0.12), G_.z(0.55), GANGS[(MODELS.index(model) + 3) % len(GANGS)], 'mincho', G_.m(0.10), INK, vertical=True, anchor='mm')
        x = G_.s(0.18)
        for i, (s_, f) in enumerate(sp[:3]):
            w = sticker(cv_t, cv_k, x + 0.0, G_.z(0.17), s_, f, G_.m(0.055))
            x += w + 0.03
        cv_t.text(G_.s(0.90), G_.z(0.98), DRIVERS[MODELS.index(model)], 'latin', G_.m(0.05), INK, anchor='mm', spacing=0.1)
    for a, b in zip(tx.sides(), kn.sides()): t(a, b)
    tx.c('B').text(0, G_.z(0.80), kata, 'jp', 0.06, INK, spacing=0.1)
    return pc


# ====================================================================== 5 Factory Two-Tone
def factory_two_tone(model):
    """Werks-Zweifarben, drei Varianten: unten abgesetzt, Dach + Säulen abgesetzt, unten mit breitem Zierband.
    Farbe 2 = zweiter Lack, Farbe 3 = Zierlinien."""
    sid = 'hb_twotone'
    pc = PaintCtx(model); G_ = G(pc, model); var = variant(model, sid, 3)
    l2 = pc.layer(2, 'Farbe 2 Fläche'); l3 = pc.layer(3, 'Farbe 3 Zierlinie')
    if var in (0, 2):
        split = G_.z(0.30 if var == 0 else 0.24)
        both(l2, lambda cv: cv.rect(-1, 9, -1, split, INK))
        for k in ('F', 'B'): l2.c(k).rect(-3, 3, -1, split, INK)
        def pin(cv):
            if var == 0:
                cv.rect(-1, 9, split + G_.m(0.010), split + G_.m(0.028), INK)
                cv.rect(-1, 9, split + G_.m(0.040), split + G_.m(0.050), INK)
            else:
                cv.rect(-1, 9, split, split + G_.m(0.07), INK)
        both(l3, pin)
        for k in ('F', 'B'): l3.c(k).rect(-3, 3, split + G_.m(0.010), split + G_.m(0.028 if var == 0 else 0.07), INK)
    else:
        top = G_.z(1.0)
        both(l2, lambda cv: cv.rect(-1, 9, top, 9, INK))
        l2.c('T').rect(-3, 3, G_.g['ws'] - G_.lo[1] + 0.05, G_.g['rw'] - G_.lo[1] - 0.05, INK)
        both(l3, lambda cv: cv.rect(-1, 9, top - G_.m(0.03), top - G_.m(0.015), INK))
    name = MODEL.get(model, model)
    trim = ['Super Saloon', 'Royal Extra', 'Grande', 'Super Custom', 'Limited', 'Excel', 'Super Deluxe', 'Grand Extra', 'Supreme'][MODELS.index(model)]
    both(l3, lambda cv: cv.text(G_.s(1.10), G_.z(0.82), trim, 'kaushan', G_.m(0.10), INK, anchor='mm'))
    l3.c('B').text(0, G_.z(0.85), f'{name.upper()} {trim.upper()}', 'latin', 0.03, INK, spacing=0.3)
    return pc


# ====================================================================== 6 Factory Raceteam
def factory_raceteam(model):
    """Werks-Rennteam der 60er/70er (Tourenwagen, kein Stockcar), drei Varianten: Oberseite farbig, aufsteigender Unterteil,
    farbige Front. Dazu Startnummer, Schrägstreifen, Werks- und Fahrername, Sponsorreihe.
    Farbe 2 = Fläche + Streifen, Farbe 3 = zweiter Streifen, Nummer, Schrift; Aussparungen in Farbe 1."""
    sid = 'hb_raceteam'
    pc = PaintCtx(model); G_ = G(pc, model); var = variant(model, sid, 3); rnd = rng(model, sid)
    l2 = pc.layer(2, 'Farbe 2 Fläche + Streifen'); l3 = pc.layer(3, 'Farbe 3 Streifen + Nummer'); kn = pc.layer(1, 'Farbe 1 Aussparung')
    tx = pc.layer(3, 'Farbe 3 Schrift'); kn2 = pc.layer(1, 'Farbe 1 Aufkleber-Schrift')
    brand = BRAND.get(model, 'IBISHU')
    num = str(rnd.choice([2, 5, 8, 12, 15, 23, 25, 39, 46, 51, 68, 85]))
    h0, h1, half, hc = hood_box(G_)
    if var == 0:   # Oberseite (Haube, Dach, Kofferraum, Gürtel) Farbe 2
        both(l2, lambda cv: cv.rect(-1, 9, G_.z(0.86), 9, INK))
        l2.c('T').rect(-3, 3, -1, 9, INK); l2.c('F').rect(-3, 3, G_.g['hood'] - 0.10, 3, INK); l2.c('B').rect(-3, 3, G_.z(0.86), 3, INK)
        num_key = 3; nu = 0.55
    elif var == 1:  # Unterteil steigt nach hinten an
        both(l2, lambda cv: cv.poly([G_.uv(-0.6, -0.5), G_.uv(-0.6, 0.18), G_.uv(0.25, 0.22), G_.uv(1.6, 0.62), G_.uv(1.6, -0.5)], INK))
        l2.c('B').rect(-3, 3, -1, G_.z(0.55), INK)
        num_key = 1; nu = 0.60
    else:           # farbige Front bis zur Tür
        both(l2, lambda cv: cv.poly([G_.uv(-1, -0.5), G_.uv(-1, 1.5), G_.uv(0.16, 1.5), G_.uv(0.04, -0.5)], INK))
        l2.c('T').rect(-3, 3, -1, G_.hood1 + 0.05, INK); l2.c('F').rect(-3, 3, -1, 3, INK)
        num_key = 3; nu = 0.55
    def stripes(cv, k):
        w = G_.m(0.08); gap = G_.m(0.045); base = G_.s(0.30 if var == 2 else 0.12)
        for i in range(3):
            if k != (3 if i == 1 else 2): continue
            a = base + i * (w + gap)
            cv.poly([(a, G_.z(1.02)), (a + w, G_.z(1.02)), (a + w - G_.m(0.35), G_.z(-0.05)), (a - G_.m(0.35), G_.z(-0.05))], INK)
    for cv in l3.sides(): stripes(cv, 3)
    for cv in l2.sides(): stripes(cv, 2)
    # Nummer mit Rand
    def number(cv, ly):
        cv.text(G_.s(nu), G_.z(0.50), num, 'dela', G_.m(0.58), INK, anchor='mm', stroke=G_.m(0.03) if ly is l3 and num_key == 1 else 0)
    if num_key == 3:
        for cv in l3.sides(): number(cv, None)
    else:
        for cv in l3.sides(): number(cv, l3)
        for cv in kn.sides(): number(cv, kn)
    l3.c('T').text(0, hc, num, 'dela', 0.30, INK) if var != 0 else kn.c('T').text(0, hc, num, 'dela', 0.30, INK)
    sp = rnd.sample(SPONSORS, 4)
    def t(cv, ck):
        cv.text(G_.s(1.08), G_.z(0.80), brand, 'racing', G_.m(0.13), INK, anchor='mm', spacing=0.05)
        cv.text(G_.s(1.08), G_.z(0.68), 'WORKS RACING TEAM', 'latin', G_.m(0.045), INK, anchor='mm', spacing=0.25)
        cv.text(G_.s(nu), G_.z(0.90), DRIVERS[(MODELS.index(model) + 4) % len(DRIVERS)], 'latin', G_.m(0.05), INK, anchor='mm', spacing=0.1)
        x = G_.s(0.95)
        for s_, f in sp[:2]:
            w = sticker(cv, ck, x + 0.10, G_.z(0.18), s_, f, G_.m(0.05)); x += w + 0.03
        cv.text(G_.s(-0.20), G_.z(0.55), sp[2][0], sp[2][1], G_.m(0.06), INK, anchor='mm', spacing=0.05)
    for a, b in zip(tx.sides(), kn2.sides()): t(a, b)
    tx.c('T').text(0, h0 + 0.08, brand, 'latin', 0.06, INK, spacing=0.5)
    tx.c('B').text(0, G_.z(0.40), f'{brand} WORKS  {num}', 'latin', 0.04, INK, spacing=0.3)
    return pc


STYLES = [
    # id, Funktion, Name DE, Name EN
    ('hb_streetdrift', street_drift, 'Street-Drift Tribal', 'Street Drift Tribal'),
    ('hb_factorysports', factory_sports, 'Werks-Sportstreifen', 'Factory Sports'),
    ('hb_bosozoku', bosozoku, 'Bosozoku', 'Bosozoku'),
    ('hb_kaido', kaido_racer, 'Kaido-Racer', 'Kaido Racer'),
    ('hb_twotone', factory_two_tone, 'Werks-Zweifarben', 'Factory Two-Tone'),
    ('hb_raceteam', factory_raceteam, 'Werks-Rennteam', 'Factory Race Team'),
]
