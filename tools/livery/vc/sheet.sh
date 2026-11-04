#!/bin/bash
# sheet.sh <name> <outname> <c1,c2,c3>
cd "$(dirname "$0")"; n=$1; o=$2; D=/mnt/project-files/hashiriya-battle/liveries-japan/vectorcraft
HB_LIVERY_WORK=../work timeout 600 python vc_bake.py bx $n.png out/$o "$3" '40,14;-40,14;90,3' >/dev/null 2>&1 || exit 1
python -c "
from PIL import Image
a=Image.open('out/${o}_0.png').crop((180,120,1080,620)); b=Image.open('out/${o}_1.png').crop((120,120,1020,620)); c=Image.open('out/${o}_2.png').crop((60,150,1140,600))
f=Image.open('${n}_prev.png'); bg=Image.new('RGBA',f.size,(255,255,255,255)); bg.alpha_composite(f); side=bg.crop((0,0,900,230)).resize((1800,460)).convert('RGB')
s=Image.new('RGB',(1800,500+750+460),(28,28,32))
s.paste(a,(0,0)); s.paste(b,(900,0)); s.paste(c.resize((1800,750)),(0,500)); s.paste(side,(0,1250))
s.save('$D/${o}-vorschau.jpg',quality=88)"
cp $n.psd $n.vectorcraft $D/
