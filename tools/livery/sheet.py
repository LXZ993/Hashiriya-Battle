import sys, os
from livery import WORK
from PIL import Image
names=sys.argv[2:]; out=sys.argv[1]
ims=[]
for n in names:
    row=[Image.open(os.path.join(WORK,'shots',f'{n}_{i}.png')).crop((150,100,1050,650)) for i in (0,1,2)]
    ims.append(row)
w,h=900,550
S=Image.new('RGB',(w*3,h*len(ims)))
for r,row in enumerate(ims):
    for c,im in enumerate(row): S.paste(im,(c*w,r*h))
S.save(out)
