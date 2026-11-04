#!/usr/bin/env python3
"""Hashiriya Battle: Bausteine der sichtbaren Aura erzeugen (aura.lua).

Schreibt nach art/shapes/hashiriya/:
  aura_shell.dae              Hülle: zwei Ringe aus weichen, senkrechten Flammen-Streifen um ein Einheits-Oval
                              (Radius 1, Höhe 0..1). aura.lua skaliert sie jeden Frame auf das Auto.
  aura_flame.color.png        Textur der Streifen (weiß, unten hell, nach oben und zu den Seiten weich aus)
  aura.materials.json         Material "hashiriya_aura_shell" (additiv, leuchtend, Farbe pro Auto über instanceColor)
Die Nebel-Partikel (Farbe und Stärke stecken im Datablock) legt aura.lua zur Laufzeit selbst an,
für jede Farbe und Nebel-Stufe (settings/hashiriya_battle/aura_fx/). Neu laufen lassen nur, wenn sich Hülle,
Textur oder Material ändern sollen:
  python tools/aura/build_aura_assets.py
"""
import json, math, os, random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'art', 'shapes', 'hashiriya')
DATA = os.path.join(ROOT, 'lua', 'ge', 'extensions', 'hashiriyaBattle', 'data')
VFS = 'art/shapes/hashiriya/'
# weiche Rauch-Textur des Spiels (eigene PNG-Sprites lädt das Partikelsystem nicht zuverlässig)
SMOKE = 'art/shapes/particles/particle_smoke_soft_01.dds'


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def flame_texture(path, w=128, h=256):
    rnd = random.Random(7)
    # weiche, senkrechte Strähnen
    cols = [0.65 + 0.35 * rnd.random() for _ in range(16)]
    img = Image.new('RGB', (w, h))
    px = img.load()
    for x in range(w):
        u = (x + 0.5) / w
        side = math.exp(-((u - 0.5) / 0.2) ** 2)
        f = u * 15
        i = int(f)
        k = f - i
        streak = cols[i] * (1 - k) + cols[min(i + 1, 15)] * k
        for y in range(h):
            v = 1 - (y + 0.5) / h  # 0 unten, 1 oben
            up = (1 - v) ** 1.5 * smooth(0.0, 0.22, v)
            wav = 0.85 + 0.15 * math.sin(v * 9 + u * 5)
            val = max(0.0, min(1.0, side * up * streak * wav * 1.15))
            c = int(round(val * 255))
            px[x, y] = (c, c, c)
    img.save(path)


def glow_texture(path, s=128):
    img = Image.new('RGBA', (s, s))
    px = img.load()
    for x in range(s):
        for y in range(s):
            d = math.hypot((x + 0.5) / s - 0.5, (y + 0.5) / s - 0.5) * 2
            a = max(0.0, 1 - d) ** 2.2
            c = int(round(a * 255))
            px[x, y] = (c, c, c, c)  # vormultipliert: auch bei rein additivem Mischen weich
    img.save(path)


def ring(segs, r0, r1, z1, width, seed=3):
    """Senkrechte Streifen tangential um den Kreis; unten Radius r0, oben r1 (leicht nach außen).
    Jeder Streifen bekommt eine etwas andere Höhe, damit die Kante wie Flammen aussieht."""
    rnd = random.Random(seed)
    pos, nrm, uv, tris = [], [], [], []
    for i in range(segs):
        a = 2 * math.pi * (i + rnd.uniform(-0.2, 0.2)) / segs
        zt = z1 * rnd.uniform(0.65, 1.0)
        cx, cy = math.cos(a), math.sin(a)
        tx, ty = -cy, cx
        hw = width / 2
        base = len(pos)
        for (s, z, r, uu, vv) in ((-1, 0, r0, 0, 0), (1, 0, r0, 1, 0), (1, zt, r1, 1, 1), (-1, zt, r1, 0, 1)):
            pos.append((cx * r + tx * hw * s, cy * r + ty * hw * s, z))
            nrm.append((cx, cy, 0))
            uv.append((uu, vv))
        tris += [(base, base + 1, base + 2), (base, base + 2, base + 3)]
        # Rückseite als eigene Flächen (statt doubleSided), Normale nach innen
        b2 = len(pos)
        for k in range(4):
            pos.append(pos[base + k]); nrm.append((-cx, -cy, 0)); uv.append(uv[base + k])
        tris += [(b2, b2 + 2, b2 + 1), (b2, b2 + 3, b2 + 2)]
    return pos, nrm, uv, tris


def write_dae(path, mat):
    pos, nrm, uv, tris = [], [], [], []
    for k, (segs, r0, r1, z1, wdt) in enumerate(((30, 1.0, 1.06, 1.0, 0.34), (20, 1.04, 1.16, 1.25, 0.42))):
        p, n, u, t = ring(segs, r0, r1, z1, wdt, seed=3 + k)
        off = len(pos)
        pos += p; nrm += n; uv += u
        tris += [(a + off, b + off, c + off) for a, b, c in t]
    f = lambda l: ' '.join('%.5f' % x for v in l for x in v)
    idx = ' '.join('%d %d %d' % (i, i, i) for t in tris for i in t)
    dae = f'''<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
  <asset><contributor><authoring_tool>Hashiriya Battle tools/aura/build_aura_assets.py</authoring_tool></contributor>
    <unit name="meter" meter="1"/><up_axis>Z_UP</up_axis></asset>
  <library_effects>
    <effect id="{mat}-effect"><profile_COMMON><technique sid="common"><lambert>
      <diffuse><color sid="diffuse">1 1 1 1</color></diffuse></lambert></technique></profile_COMMON></effect>
  </library_effects>
  <library_materials>
    <material id="{mat}-material" name="{mat}"><instance_effect url="#{mat}-effect"/></material>
  </library_materials>
  <library_geometries>
    <geometry id="aura-mesh" name="aura">
      <mesh>
        <source id="aura-pos"><float_array id="aura-pos-array" count="{len(pos)*3}">{f(pos)}</float_array>
          <technique_common><accessor source="#aura-pos-array" count="{len(pos)}" stride="3">
            <param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
        <source id="aura-nrm"><float_array id="aura-nrm-array" count="{len(nrm)*3}">{f(nrm)}</float_array>
          <technique_common><accessor source="#aura-nrm-array" count="{len(nrm)}" stride="3">
            <param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
        <source id="aura-uv"><float_array id="aura-uv-array" count="{len(uv)*2}">{f(uv)}</float_array>
          <technique_common><accessor source="#aura-uv-array" count="{len(uv)}" stride="2">
            <param name="S" type="float"/><param name="T" type="float"/></accessor></technique_common></source>
        <vertices id="aura-vtx"><input semantic="POSITION" source="#aura-pos"/></vertices>
        <triangles material="{mat}-material" count="{len(tris)}">
          <input semantic="VERTEX" source="#aura-vtx" offset="0"/>
          <input semantic="NORMAL" source="#aura-nrm" offset="1"/>
          <input semantic="TEXCOORD" source="#aura-uv" offset="2" set="0"/>
          <p>{idx}</p>
        </triangles>
      </mesh>
    </geometry>
  </library_geometries>
  <library_visual_scenes>
    <visual_scene id="Scene" name="Scene">
      <node id="aura_shell" name="aura_shell" type="NODE">
        <matrix sid="transform">1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1</matrix>
        <instance_geometry url="#aura-mesh" name="aura_shell">
          <bind_material><technique_common>
            <instance_material symbol="{mat}-material" target="#{mat}-material">
              <bind_vertex_input semantic="UVMap" input_semantic="TEXCOORD" input_set="0"/>
            </instance_material>
          </technique_common></bind_material>
        </instance_geometry>
      </node>
    </visual_scene>
  </library_visual_scenes>
  <scene><instance_visual_scene url="#Scene"/></scene>
</COLLADA>
'''
    open(path, 'w', encoding='utf-8').write(dae)


def hexrgb(h):
    h = str(h).lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def light(rgb):
    """wie aura.lua lightColor: hellste Komponente = 1, Sättigung leicht angehoben"""
    mx = max(max(rgb), 0.001)
    r, g, b = (c / mx for c in rgb)
    if min(r, g, b) < 0.95:
        k = 1.35
        r, g, b = (max(0.0, 1 - (1 - c) * k) for c in (r, g, b))
    return r, g, b


def colors():
    aura = json.load(open(os.path.join(DATA, 'aura.json'), encoding='utf-8'))
    riv = json.load(open(os.path.join(DATA, 'rivals.json'), encoding='utf-8'))
    out = {aura.get('defaultColor', '#ff6600'), aura.get('leaderRimColor', '#ffd257'), '#ffffff'}
    out |= set((aura.get('colors') or {}).values())
    out |= {t['color'] for t in riv.get('teams', []) if t.get('color')}
    out |= {r['aura'] for r in riv.get('rivals', []) if r.get('aura')}
    return sorted({c.lower() for c in out if isinstance(c, str) and len(c.lstrip('#')) == 6})


def main():
    os.makedirs(OUT, exist_ok=True)
    mat = 'hashiriya_aura_shell'
    flame_texture(os.path.join(OUT, 'aura_flame.color.png'))
    write_dae(os.path.join(OUT, 'aura_shell.dae'), mat)
    tex = '/' + VFS + 'aura_flame.color.png'  # Materialien mit führendem /, Partikel ohne (wie im Spiel)
    mats = {mat: {
        'name': mat, 'mapTo': mat, 'class': 'Material',
        'Stages': [{
            # Grundfarbe = Flammen-Textur x Aura-Farbe (instanceColor). Metall: kein grauer Streulicht-Anteil, Spiegelungen
            # nur in Flammenfarbe; Leuchten = Grundfarbe x emissive. Schwarz in der Textur = unsichtbar (additiv).
            'baseColorMap': tex, 'baseColorFactor': [1, 1, 1, 1], 'roughnessFactor': 1, 'metallicFactor': 1,
            'emissive': True, 'emissiveMap': tex, 'emissiveFactor': [1, 1, 1],
            'emissiveIgnoreExposure': True, 'emissiveIntensityNits': 6,
            'instanceDiffuse': True, 'instanceEmissive': True,
        }, {}, {}, {}],
        'castShadows': False, 'doubleSided': False, 'translucent': True, 'translucentBlendOp': 'Add',
        'alphaTest': False, 'alphaRef': 0,
        'translucentZWrite': False, 'version': 1.5,
    }}
    json.dump(mats, open(os.path.join(OUT, 'aura.materials.json'), 'w', encoding='utf-8'), indent=1)
    print('Aura-Bausteine ->', OUT)


if __name__ == '__main__':
    main()
