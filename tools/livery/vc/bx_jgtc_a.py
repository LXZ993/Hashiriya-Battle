# JGTC-Wellen (90er GT-Rennen): drei ueberlappende Wellen (Farbe 2, Farbe 3, festes Silber) steigen von vorn unten
# nach hinten oben und loesen sich vorn in Rasterpunkte auf. Grosser Hauptsponsor fest, Startnummernfeld.
import math
from shapely.geometry import Point, box
from vcsvg import Doc
from txt import text
from cars import CAR
from tribal import to_d, union
from lore_common import pg, curve
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RS, RB = 'RacingSansOne-Regular.ttf', 'RobotoCondensed.ttf'
SILVER, WHITE, INK, YEL = '#c9cdd2', '#f7f7f2', '#111111', '#ffd21a'
P = {'bx': dict(amp=18, ph=0.0, sp='eshock', spc=YEL), 'sbr': dict(amp=22, ph=1.2, sp='okudai', spc=WHITE),
     'sunburst2': dict(amp=14, ph=2.0, sp='wangan', spc=WHITE), 'midsize': dict(amp=20, ph=0.6, sp='oilex', spc=YEL),
     'covet': dict(amp=16, ph=2.6, sp='gripall', spc=INK)}.get(M, dict(amp=18, ph=0.0, sp='eshock', spc=YEL))
S2, S3, G, F = 'Farbe_2_Welle_GRUEN', 'Farbe_3_Welle_BLAU', 'Fest_Silber_Welle', 'Fest_Sponsor_Nummer'
REV = M in ('sbr', 'covet')   # Wellen fallen von vorn oben nach hinten unten
def wave_y(base, slope, amp, ph):
    if REV: return lambda x: base - slope * (L - x) / 933 + amp * math.sin((x + 20) / 933 * math.pi * 1.6 + ph)
    return lambda x: base - slope * (x + 20) / 933 + amp * math.sin((x + 20) / 933 * math.pi * 1.6 + ph)
def wave_band(top, bot, x0):
    if REV: x0 = L - x0
    a, b = (-20, x0) if REV else (x0, L + 20)
    return pg(curve(top, a, b) + curve(bot, b, a))
def dots_tail(top, bot, x0, x1, step=7.5, rev=False):
    """Rasterpunkte vor dem Wellenanfang: zum freien Ende hin kleiner werdend."""
    out = []
    x = x1
    while x > x0:
        t = (x - x0) / (x1 - x0); t = 1 - t if rev else t; r = 3.6 * t
        y = top(x)
        while y < bot(x):
            if r > 0.5: out.append(Point(x, y).buffer(r, 8))
            y += step
        x -= step
    return union(*out) if out else None
a, ph = P['amp'], P['ph']
layers = [(S2, 2, wave_y(214, 70, a, ph), wave_y(240, 40, a, ph), 300),
          (G, SILVER, wave_y(196, 80, a * 0.8, ph + 0.5), wave_y(214, 70, a, ph), 360),
          (S3, 3, wave_y(184, 84, a * 0.7, ph + 0.9), wave_y(196, 80, a * 0.8, ph + 0.5), 420)]
for lid, key, top, bot, x0 in layers:
    D.side(lid, to_d(wave_band(top, bot, x0).intersection(box(-20, 96, L + 20, 240))), key)
    dt = dots_tail(top, bot, L - x0, L - x0 + 170, rev=True) if REV else dots_tail(top, bot, x0 - 170, x0)
    if dt is not None: D.side(lid, to_d(dt.intersection(box(-20, 96, L + 20, 240))), key)
SX, NX = {'covet': (560, 330)}.get(M, (400, 620) if REV else (560, 336))
D.side_logo(F, P['sp'], SX, 128, 24, key=P['spc'])
nb = box(NX - 36, 108, NX + 36, 146).buffer(-5).buffer(5)
D.side(F, to_d(nb.buffer(1.5)), INK); D.side(F, to_d(nb), WHITE); D.side_text(F, C['rnum'], RS, 30, NX, 128, INK)
D.side_text(F, 'ALL JAPAN GT CHAMPIONSHIP', RB, 5.5, NX, 156, INK, track=0.25)
cx = TW / 2
for lid, key, off, w in ((S2, 2, -50, 40), (G, SILVER, -6, 14), (S3, 3, 14, 20)):
    D.top(lid, to_d(pg([(cx + off, 920), (cx + off + w, 920), (cx + off + w * 0.4, 200), (cx + off + w * 0.2, 200)])), key)
D.top_logo(F, P['sp'], cx, 120, 30, key=P['spc'])
D.write('bx_jgtc_a')
