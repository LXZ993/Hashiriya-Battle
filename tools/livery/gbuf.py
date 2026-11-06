import numpy as np, sys, pickle
from daeload import load
def gbuffer(tris, W, H):
    def cr2(a,b): return a[:,0]*b[:,1]-a[:,1]*b[:,0]
    ds=[]
    for t in tris:
        P=t['P'].astype(np.float64); U=t['U1'].astype(np.float64)
        a3=np.linalg.norm(np.cross(P[:,1]-P[:,0],P[:,2]-P[:,0]),axis=1)/2
        au=np.abs(cr2(U[:,1]-U[:,0],U[:,2]-U[:,0]))/2
        with np.errstate(all='ignore'): d=au/a3
        t['dens']=d; ds.append(d[(a3>1e-7)&(au>1e-12)&np.isfinite(d)])
    med=np.median(np.concatenate(ds)); print('median density',med)
    pos = np.zeros((H,W,3),np.float32); nrm=np.zeros((H,W,3),np.float32); mask=np.zeros((H,W),bool)
    for t in tris:
        P=t['P'].astype(np.float64); U=t['U1'].astype(np.float64)
        dens=t['dens']
        for k in range(len(P)):
            if not (med/3.5 < dens[k] < med*3.5): continue
            p=P[k]; u=U[k]
            if u.min()<-0.01 or u.max()>1.01: continue
            if not np.isfinite(u).all() or not np.isfinite(p).all(): continue
            px=u[:,0]*W - 0.5; py=(1-u[:,1])*H - 0.5
            x0=int(np.floor(px.min())); x1=int(np.ceil(px.max())); y0=int(np.floor(py.min())); y1=int(np.ceil(py.max()))
            if x1<0 or y1<0 or x0>=W or y0>=H: continue
            x0=max(x0,0);y0=max(y0,0);x1=min(x1,W-1);y1=min(y1,H-1)
            den=(py[1]-py[2])*(px[0]-px[2])+(px[2]-px[1])*(py[0]-py[2])
            if abs(den)<1e-9: continue
            n=np.cross(p[1]-p[0],p[2]-p[0]); ln=np.linalg.norm(n)
            if ln<1e-12: continue
            n/=ln
            gx,gy=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1))
            a=((py[1]-py[2])*(gx-px[2])+(px[2]-px[1])*(gy-py[2]))/den
            b=((py[2]-py[0])*(gx-px[2])+(px[0]-px[2])*(gy-py[2]))/den
            c=1-a-b
            e=-0.02
            ins=(a>=e)&(b>=e)&(c>=e)
            if not ins.any(): continue
            X=gx[ins];Y=gy[ins]
            pp=a[ins,None]*p[0]+b[ins,None]*p[1]+c[ins,None]*p[2]
            pos[Y,X]=pp; nrm[Y,X]=n; mask[Y,X]=True
    return pos,nrm,mask
if __name__=='__main__':
    import os
    from livery import WORK
    dae,mats,out,W,H=sys.argv[1],sys.argv[2].split(','),os.path.join(WORK,sys.argv[3]),int(sys.argv[4]),int(sys.argv[5])
    tag=sys.argv[3]
    tris=load(dae,mats,os.path.join(WORK,tag.split('@')[0]+'.pkl'))
    import re
    if len(sys.argv)>6 and sys.argv[6]: tris=[t for t in tris if not re.search(sys.argv[6],t['name'])]
    if len(sys.argv)>7 and sys.argv[7]: tris=[t for t in tris if re.search(sys.argv[7],t['name'])]
    print('meshes',len(tris))
    pos,nrm,mask=gbuffer(tris,W,H)
    np.savez_compressed(out+'_gb.npz',pos=pos,nrm=nrm,mask=mask)
    from PIL import Image
    v=np.zeros((H,W,3),np.uint8); v[mask]=(np.abs(nrm[mask])*255).astype(np.uint8)
    Image.fromarray(v).resize((1024,int(1024*H/W))).save(out+'_gb.png')
    print('filled',mask.mean())
