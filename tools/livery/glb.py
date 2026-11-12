import numpy as np, trimesh, sys
from daeload import load
from PIL import Image
def body_mesh(tris, tex_path):
    P=np.concatenate([t['P'] for t in tris]).reshape(-1,3)
    U=np.concatenate([t['U1'] for t in tris]).reshape(-1,2)
    F=np.arange(len(P)).reshape(-1,3)
    # BeamNG: x right?, y back, z up -> glTF y up: (x, z, y)
    V=np.c_[-P[:,0],P[:,2],P[:,1]]
    mat=trimesh.visual.material.PBRMaterial(baseColorTexture=Image.open(tex_path).convert('RGB'), metallicFactor=0.1, roughnessFactor=0.35, doubleSided=True)
    m=trimesh.Trimesh(vertices=V,faces=F,visual=trimesh.visual.TextureVisuals(uv=U,material=mat),process=False)
    return m
def flat_mesh(tris, rgba, rough=0.2):
    P=np.concatenate([t['P'] for t in tris]).reshape(-1,3)
    V=np.c_[-P[:,0],P[:,2],P[:,1]]; F=np.arange(len(P)).reshape(-1,3)
    mat=trimesh.visual.material.PBRMaterial(baseColorFactor=rgba, metallicFactor=0.0, roughnessFactor=rough, doubleSided=True, alphaMode='BLEND' if rgba[3]<255 else 'OPAQUE')
    return trimesh.Trimesh(vertices=V,faces=F,visual=trimesh.visual.TextureVisuals(uv=np.zeros((len(V),2)),material=mat),process=False)
