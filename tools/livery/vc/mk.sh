#!/bin/bash
# mk.sh <name> : SVG -> Vorschau, PNG (Backen), PSD + .vectorcraft (Alex)
cd "$(dirname "$0")"; VC=../vcdl/x/vectorcraft-0.19.0-linux-x86_64/bin/vectorcraft-cli; n=$1
python $n.py || exit 1
$VC convert ${n}_guide.svg ${n}_prev.png --scale 2 >/dev/null
$VC convert $n.svg $n.png --scale 1.5 >/dev/null
$VC convert $n.svg $n.psd --hidden-objects layer >/dev/null
$VC convert $n.svg $n.vectorcraft >/dev/null
python -c "
from PIL import Image
im=Image.open('${n}_prev.png'); bg=Image.new('RGBA',im.size,(255,255,255,255)); bg.alpha_composite(im)
bg.crop((0,0,1800,980)).save('crop_side.png'); bg.crop((1880,0,2600,1800)).resize((360,900)).save('crop_top.png')"
