import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
import os
from livery import WORK, FONTS
m=sys.argv[1]; d=np.load(os.path.join(WORK,m+'_gb.npz')); pos,nrm,mask=d['pos'],d['nrm'],d['mask']
P=pos[mask]; N=nrm[mask]
lo=np.percentile(P,0.2,0); hi=np.percentile(P,99.8,0); print(m,'bbox',lo.round(3),hi.round(3))
ppm=200
sel=(np.abs(N[:,0])>np.abs(N[:,1]))&(np.abs(N[:,0])>np.abs(N[:,2]))&(P[:,0]>0)
W=int((hi[1]-lo[1])*ppm)+40; H=int((hi[2]-lo[2])*ppm)+40
img=np.zeros((H,W,3),np.uint8)+30
c=((P[sel,1]-lo[1])*ppm+20).astype(int); r=((hi[2]-P[sel,2])*ppm+20).astype(int)
ok=(c>=0)&(c<W)&(r>=0)&(r<H)
img[r[ok],c[ok]]=(np.abs(N[sel][ok])*200+40).astype(np.uint8)
im=Image.fromarray(img); dr=ImageDraw.Draw(im)
f=ImageFont.truetype(FONTS+'RobotoCondensed.ttf',12)
z=np.ceil(lo[2]*10)/10
while z<hi[2]:
    r=int((hi[2]-z)*ppm+20); dr.line([(0,r),(W,r)],fill=(90,90,0)); dr.text((2,r-12),f'{z:.1f}',fill=(255,255,0),font=f); z+=0.1
y=np.ceil(lo[1]*10)/10
while y<hi[1]:
    c=int((y-lo[1])*ppm+20); dr.line([(c,0),(c,H)],fill=(0,70,90)); 
    if round(y*10)%5==0: dr.text((c+2,H-14),f'{y:.1f}',fill=(0,255,255),font=f)
    y+=0.1
im.save(os.path.join(WORK,m+'_side.png'))
