"""Lädt die freien Schriften (SIL Open Font License, Google Fonts) nach tools/livery/fonts/."""
import os, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__)); D = os.path.join(HERE, 'fonts'); os.makedirs(D, exist_ok=True)
BASE = 'https://raw.githubusercontent.com/google/fonts/main/ofl/'
FILES = {'ZenKakuGothicNew-Black.ttf': 'zenkakugothicnew/ZenKakuGothicNew-Black.ttf', 'ZenKakuGothicNew-Bold.ttf': 'zenkakugothicnew/ZenKakuGothicNew-Bold.ttf',
         'MPLUS1p-Black.ttf': 'mplus1p/MPLUS1p-Black.ttf', 'DelaGothicOne-Regular.ttf': 'delagothicone/DelaGothicOne-Regular.ttf',
         'ShipporiMincho-ExtraBold.ttf': 'shipporimincho/ShipporiMincho-ExtraBold.ttf', 'RobotoCondensed.ttf': 'robotocondensed/RobotoCondensed%5Bwght%5D.ttf',
         'KaushanScript-Regular.ttf': 'kaushanscript/KaushanScript-Regular.ttf', 'RacingSansOne-Regular.ttf': 'racingsansone/RacingSansOne-Regular.ttf'}
for name, path in FILES.items():
    dst = os.path.join(D, name)
    if not os.path.exists(dst):
        print('lade', name); urllib.request.urlretrieve(BASE + path, dst)
print('Schriften fertig in', D)
