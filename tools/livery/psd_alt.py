"""PSDs für die festen Liveries (Taxi, Polizei, Arbeiter): eine Ebene mit der fertigen Textur.
Aufruf: python psd_alt.py <zielordner>   Rückweg: psd_zu_skin.py / PSD-zu-Skin.bat"""
import os, sys, glob
from PIL import Image
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer
from psd_tools.constants import Compression
from psd_tools.psd.image_data import ImageData
HERE = os.path.dirname(os.path.abspath(__file__)); MOD = os.path.abspath(os.path.join(HERE, '..', '..'))
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
for f in sorted(glob.glob(os.path.join(MOD, 'vehicles', '*', 'hashiriya_liveries', '*.color.png'))):
    model = f.split(os.sep)[-3]; sid = os.path.basename(f)[:-len('.color.png')]
    im = Image.open(f).convert('RGB')
    psd = PSDImage.new('RGB', im.size)
    psd.append(PixelLayer.frompil(im.convert('RGBA'), psd, f'{sid} (fertige Textur)', compression=Compression.RLE))
    idata = ImageData(compression=Compression.RLE); idata.set_data([c.tobytes() for c in im.split()], psd._record.header)
    psd._record.image_data = idata
    dst = os.path.join(out, f'{model}_{sid}.psd'); psd.save(dst); print('ok', dst, os.path.getsize(dst) // 1024, 'KB')
