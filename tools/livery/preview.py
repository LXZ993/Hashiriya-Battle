import numpy as np, trimesh, sys, subprocess, os
from daeload import load
from glb import body_mesh, flat_mesh
from PIL import Image
from livery import WORK, HERE
SRC=os.environ.get('HB_LIVERY_SRC', os.path.join(WORK,'src'))+os.sep
DAE={'pessima':(SRC+'pessima/vehicles/pessima/pessima.dae',['pessima','pessima_aftermarket'],'pessima_glass'),
     'midsize':(SRC+'midsize/vehicles/midsize/midsize.dae',['midsize_body'],'midsize_glass'),
     'sunburst2':(SRC+'sunburst2/vehicles/sunburst2/sunburst2.dae',['sunburst2_main'],'sunburst2_glass'),
     'pickup':(SRC+'pickup/vehicles/pickup/pickup.dae',['pickup'],'pickup_glass'),
     'van':(SRC+'van/vehicles/van/van.DAE',['van'],'van_glass')}
WHEEL={'pessima':(-1.40,1.36,0.29,0.29,0.72),'midsize':(-1.42,1.35,0.30,0.31,0.76),'sunburst2':(-1.38,1.25,0.30,0.31,0.74),
       'pickup':(-1.42,2.0,0.45,0.38,0.80),'van':(-1.42,2.12,0.40,0.37,0.86)}
VARIANT_SKIP={'pessima':(['pessima_aftermarket'],['Mesh_133-mesh','Mesh_019-mesh','Plane_113-mesh','Mesh_002-mesh','Mesh_127-mesh','Circle_006-mesh','Mesh_023-mesh'])}
def wheels(m):
    yf,yr,z,r,x=WHEEL[m]; ms=[]
    for y in (yf,yr):
        for sx in (-1,1):
            c=trimesh.creation.cylinder(radius=r,height=0.22,sections=40)
            c.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[0,1,0]))
            c.apply_translation([sx*x,z,y])
            c.visual=trimesh.visual.TextureVisuals(uv=np.zeros((len(c.vertices),2)),material=trimesh.visual.material.PBRMaterial(baseColorFactor=[18,18,18,255],roughnessFactor=0.8,metallicFactor=0))
            ms.append(c)
            h=trimesh.creation.cylinder(radius=r*0.62,height=0.225,sections=40)
            h.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[0,1,0])); h.apply_translation([sx*x,z,y])
            h.visual=trimesh.visual.TextureVisuals(uv=np.zeros((len(h.vertices),2)),material=trimesh.visual.material.PBRMaterial(baseColorFactor=[150,152,158,255],roughnessFactor=0.3,metallicFactor=0.8))
            ms.append(h)
    return ms
def make(m, tex, out, filt=None):
    dae,mats,glass=DAE[m]
    tris=load(dae,mats,os.path.join(WORK,f'{m}.pkl'))
    sm,sn=VARIANT_SKIP.get(m,([],[]))
    tris=[t for t in tris if t['mat'] not in sm and t['name'] not in sn]
    if m=='pickup':
        def clean(t):
            p=t['P'].reshape(-1,3)
            if np.abs(p[:,0]).max()>1.02: return False          # Dually-Kotflügel
            if p[:,2].min()>1.2 and p[:,1].min()>0.3: return False  # Hardtop/Kabine-Varianten
            return True
        tris=[t for t in tris if clean(t)]
    # nur Dreiecke mit gültigem UV1 (Varianten mit 0-UV weglassen)
    keep=[]
    for t in tris:
        U=t['U1']; ok=(np.abs(U).sum(axis=(1,2))>1e-6)
        if ok.sum()<max(8,len(ok)*0.1): continue
        keep.append(dict(t,P=t['P'][ok],U1=U[ok]))
    g=load(dae,[glass],os.path.join(WORK,f'{m}_glass.pkl')) if os.path.exists(dae) else []
    sc=trimesh.Scene()
    sc.add_geometry(body_mesh(keep,tex))
    if g: sc.add_geometry(flat_mesh(g,[20,26,32,235],0.05))
    for w in wheels(m): sc.add_geometry(w)
    sc.export(out)
if __name__=='__main__':
    m,tex,name=sys.argv[1:4]
    os.makedirs(os.path.join(WORK,'shots'),exist_ok=True)
    make(m,tex,os.path.join(HERE,'web',f'{name}.glb'))
    subprocess.run(['node',os.path.join(HERE,'web','shot.js'),f'{name}.glb',os.path.join(WORK,'shots',name),'35,12','-145,14','90,4'],check=True)
