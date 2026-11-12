import sys, numpy as np
sys.path.insert(0,'/home/user/hashiriya-battle/tools/livery')
from livery import Ctx
from PIL import Image, ImageFilter
m=sys.argv[1]; ppm=int(sys.argv[2]) if len(sys.argv)>2 else 200
c=Ctx(m); P=c.P; lo,hi=c.lo,c.hi
def splat(sel,a,b,w,h,shade):
    img=np.zeros((h,w),np.float32); cnt=np.zeros((h,w),np.float32)
    xi=np.clip((a*ppm).astype(int),0,w-1); yi=np.clip((b*ppm).astype(int),0,h-1)
    np.add.at(img,(yi,xi),shade); np.add.at(cnt,(yi,xi),1)
    out=np.where(cnt>0,img/np.maximum(cnt,1),0)
    m_=cnt>0
    im=Image.fromarray((m_*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    sh=Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return im,sh
N=c.nrm[c.mask]
info={}
# side L (x>0), front left
sel=(c.cls==0)
w=int((hi[1]-lo[1])*ppm)+1; h=int((hi[2]-lo[2])*ppm)+1
a=P[sel,1]-lo[1]; b=hi[2]-P[sel,2]
shade=0.45+0.5*np.clip(N[sel,2]*0.5+0.5,0,1)
msk,sh=splat(sel,a,b,w,h,shade)
rgb=np.array(sh.convert('RGB')).astype(np.float32)
alpha=np.array(msk)
edge=np.array(msk.filter(ImageFilter.FIND_EDGES))>0
rgb[edge]=[30,30,30]
Image.fromarray(np.dstack([rgb.astype(np.uint8),alpha])).save(f'{m}_L.png')
# top
sel=(c.cls==2)
w2=int((hi[0]-lo[0])*ppm)+1; h2=int((hi[1]-lo[1])*ppm)+1
a=-P[sel,0]+(hi[0]-lo[0])/2; b=P[sel,1]-lo[1]
shade=0.5+0.5*np.clip(N[sel,1]*0.5+0.5,0,1)
msk,sh=splat(sel,a,b,w2,h2,shade)
rgb=np.array(sh.convert('RGB')).astype(np.float32); alpha=np.array(msk)
rgb[np.array(msk.filter(ImageFilter.FIND_EDGES))>0]=[30,30,30]
Image.fromarray(np.dstack([rgb.astype(np.uint8),alpha])).save(f'{m}_T.png')
print(m,'L',w,h,'T',w2,h2,'lo',lo.round(3),'hi',hi.round(3))
