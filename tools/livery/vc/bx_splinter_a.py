# Splitter-Tarn (Nacht-Tarnmuster): kantige Scherben in Farbe 2, Farbe 3 und festem Dunkelgrau, Vorderkante gezackt.
# Schablonen-Schrift in Schwarz, Warndreieck-Aufkleber fest. Jedes Auto anderes Muster (Seed) und Ausschnitt.
import random
from shapely.geometry import MultiPoint, Polygon, box
from shapely.ops import voronoi_diagram
from vcsvg import Doc
from cars import CAR, MODELS
from tribal import to_d, union
from lore_common import pg
D = Doc(); M = D.model; C = CAR[M]; L, TW = D.lw, D.tw
RB = 'RobotoCondensed.ttf'
GREY, YEL = '#3a3d42', '#f0c419'
S2, S3, G, K = 'Farbe_2_Scherben_GRUEN', 'Farbe_3_Scherben_BLAU', 'Fest_Dunkelgrau_Scherben', 'Schwarz_Schablone'
P = {'bx': dict(seed=4, fx=300, n=26, ang=-24), 'sbr': dict(seed=9, fx=420, n=30, ang=-34), 'sunburst2': dict(seed=13, fx=250, n=28, ang=18),
     'hopper': dict(seed=21, fx=0, n=34, ang=-12), 'miramar': dict(seed=27, fx=360, n=24, ang=28)}.get(M, dict(seed=4, fx=300, n=26, ang=-24))
rnd = random.Random(P['seed'])
def shards(region, n, rnd, ang=-24):
    """Splittertarn: Flaeche in schraege Streifen (Winkel ang, Breite 10-26) teilen, jeden Streifen mit schraegen
    Schnitten in lange spitze Stuecke zerlegen, Stuecke zufaellig auf 3 Toene + Grundlack verteilen."""
    from shapely import affinity
    c = region.centroid
    rg = affinity.rotate(region, -ang, origin=c)
    x0, y0, x1, y1 = rg.bounds
    out = {0: [], 1: [], 2: [], 3: [], 4: []}
    y = y0 - 5
    while y < y1:
        h = rnd.uniform(9, 26); x = x0 - 40
        while x < x1:
            w = rnd.uniform(25, 95); sk = rnd.uniform(-14, 14); sk2 = rnd.uniform(-14, 14)
            piece = Polygon([(x + sk, y), (x + w + sk2, y), (x + w - sk2, y + h), (x - sk, y + h)])
            out[rnd.choices(range(5), weights=(3, 3, 2, 3, 0))[0]].append(piece)
            x += w
        y += h
    for k in out:
        out[k] = [affinity.rotate(p, ang, origin=c).intersection(region).buffer(-0.6, join_style=2) for p in out[k]]
    return out
fx = P['fx']
edge = [(fx + 40, 250)] + [(fx + (0 if i % 2 else 34) - i * 4, 230 - i * 22) for i in range(8)] + [(fx + 90, 70)]
region = pg(edge + [(L + 20, 70), (L + 20, 250)]).intersection(box(-20, 96, L + 20, 240))
sh = shards(region, P['n'], rnd, ang=P['ang'])
D.side(S2, to_d(union(*sh[0])), 2); D.side(S3, to_d(union(*sh[1])), 3); D.side(G, to_d(union(*sh[2])), GREY)
D.side_text(K, 'HASHIRIYA  NIGHT  UNIT  ' + C['rnum'], RB, 7, 200 if fx > 200 else 720, 120, 'k', track=0.5)
tri = pg([(150, 178), (166, 150), (182, 178)]) if fx > 200 else pg([(790, 178), (806, 150), (822, 178)])
D.side(G, to_d(tri.buffer(1.5)), '#111111'); D.side(G, to_d(tri), YEL)
tsh = shards(box(-20, 560, TW + 20, 920), 14, rnd, ang=P['ang'] + 60)
D.top(S2, to_d(union(*tsh[0])), 2); D.top(S3, to_d(union(*tsh[1])), 3); D.top(G, to_d(union(*tsh[2])), GREY)
D.write('bx_splinter_a')
