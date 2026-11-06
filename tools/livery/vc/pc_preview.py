"""3D-Kontrollbild eines Percheron-Skins: python pc_preview.py <id> <box|tank> <ausgabe> [lack1 #hex]"""
import os, sys, pickle, subprocess, numpy as np, trimesh
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(HERE, '..'))
from PIL import Image
from glb import body_mesh, flat_mesh
from pc_sil import get, CAB, BOX
from pc_bake import OUT, TEX, WORK
did, kind, out = sys.argv[1:4]; paint = sys.argv[4] if len(sys.argv) > 4 else '#2a6fd1'
t = os.path.join(OUT, TEX)
def tex(path_b, path_p=None, path_o=None):
    b = np.asarray(Image.open(path_b).convert('RGB')).astype(np.float32) / 255
    if path_p:
        p = np.asarray(Image.open(path_p).convert('RGB')).astype(np.float32) / 255
        c = np.array([int(paint[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255
        b = b * (1 - p[..., :1]) + b * p[..., :1] * c   # Lackfarbe 1 über Paletten-Rot
    if path_o:
        o = np.asarray(Image.open(path_o).convert('L')).astype(np.float32)[..., None] / 255
        b = b * o + 0.75 * (1 - o)
    f = os.path.join(WORK, f'_prev_{did}_{os.path.basename(path_b)}')
    Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8)).save(f); return f
cab = [x for x in get('percheron.dae', 'cab', CAB) if x['mat'] in ('percheron_body_paint', 'percheron_body')]
glass = [x for x in get('percheron.dae', 'cab', CAB) if 'glass' in x['mat'] or 'black' in x['mat'] or 'interior' in x['mat']]
meshes = [body_mesh(cab, tex(f'{t}/{did}_cab_b.color.png', f'{t}/{did}_cab_p.color.png'))]
if glass: meshes.append(flat_mesh(glass, [20, 28, 36, 255]))
if kind == 'box':
    up = [x for x in get('percheron_upfits.dae', 'upfit', BOX) if x['mat'] == 'percheron_flatbed']
    meshes.append(body_mesh(up, tex(f'{t}/{did}_box_b.color.png')))
else:
    from pc_gbuf import TANKN
    tk = [x for x in get('percheron_tanker.dae', 'tank', TANKN) if x['mat'] == 'percheron_tanker']
    for x in tk:
        u = x['U1'].copy(); u[:, :, 0] -= np.floor(u[:, :, 0].mean(1, keepdims=True) + 1e-6); x['U1'] = u
    meshes.append(body_mesh(tk, tex(f'{t}/{did}_tank_b.color.png', None, f'{t}/{did}_tank_o.data.png')))
sc = trimesh.Scene(meshes)
web = os.path.join(HERE, '..', 'web'); glbn = f'pc_{did}.glb'
sc.export(os.path.join(web, glbn))
subprocess.run(['node', os.path.join(web, 'shot.js'), glbn, out, '60,12', '-60,12', '25,25'], check=True)
os.remove(os.path.join(web, glbn))
