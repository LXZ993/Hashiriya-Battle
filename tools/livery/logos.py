"""Eigene, frei erfundene Firmenlogos (keine echten Marken)."""
from PIL import Image, ImageDraw
import math
from livery import font, hexc

S = 512

def _im():
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)

def shinonome(c1='#1f5e3b', c2='#e8742a', bg=None):
    """Aufgehende Sonne über Wolkenband (Taxi Shinonome Kōtsū)."""
    im, d = _im()
    if bg: d.ellipse([8, 8, S - 8, S - 8], fill=hexc(bg))
    d.ellipse([60, 60, S - 60, S - 60], outline=hexc(c1), width=26)
    d.pieslice([130, 170, S - 130, S - 90], 180, 360, fill=hexc(c2))
    for i in range(7):
        a = math.radians(180 + 15 + i * 25)
        cx, cy, r0, r1 = S / 2, (170 + S - 90) / 2, 135, 180
        d.line([cx + r0 * math.cos(a), cy + r0 * math.sin(a), cx + r1 * math.cos(a), cy + r1 * math.sin(a)], fill=hexc(c2), width=14)
    for k, y in enumerate((300, 340, 380)):
        d.rounded_rectangle([140 + k * 20, y, S - 140 - k * 20, y + 22], 11, fill=hexc(c1))
    return im

def crescent(c='#111111', ring='#111111', bg='#f3b800'):
    """Mondsichel im Ring (Gekkō Taxi)."""
    im, d = _im()
    d.ellipse([10, 10, S - 10, S - 10], fill=hexc(ring))
    d.ellipse([40, 40, S - 40, S - 40], fill=hexc(bg))
    d.ellipse([110, 100, S - 110, S - 120], fill=hexc(c))
    d.ellipse([170, 70, S - 60, S - 160], fill=hexc(bg))
    for x, y, r in ((360, 330, 16), (300, 380, 10), (390, 250, 9)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=hexc(c))
    return im

def police_emblem(gold='#d4a017', dark='#1b2a4a'):
    """Erfundenes Abzeichen: Kreis mit fünfzackigem Stern und 警."""
    im, d = _im()
    d.ellipse([10, 10, S - 10, S - 10], fill=hexc(gold))
    d.ellipse([40, 40, S - 40, S - 40], fill=hexc(dark))
    pts = []
    for i in range(10):
        r = 200 if i % 2 == 0 else 85
        a = math.radians(-90 + i * 36)
        pts.append((S / 2 + r * math.cos(a), S / 2 + r * math.sin(a)))
    d.polygon(pts, fill=hexc(gold))
    d.text((S / 2, S / 2 + 6), '警', font=font('jp', 120), fill=hexc(dark), anchor='mm')
    return im

def wrench(c='#c8102e', c2='#111111', bg='#ffffff'):
    """Schraubenschlüssel im Zahnrad (Tesshin Motors)."""
    im, d = _im()
    cx = cy = S / 2
    teeth = []
    for i in range(24):
        r = 240 if (i // 1) % 2 == 0 else 205
        a = math.radians(i * 15)
        teeth.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(teeth, fill=hexc(c2))
    d.ellipse([60, 60, S - 60, S - 60], fill=hexc(c))
    d.ellipse([110, 110, S - 110, S - 110], fill=hexc(bg))
    # Schlüssel diagonal
    w = Image.new('RGBA', (S, S), (0, 0, 0, 0)); wd = ImageDraw.Draw(w)
    wd.rounded_rectangle([S / 2 - 26, 150, S / 2 + 26, 400], 20, fill=hexc(c2))
    wd.ellipse([S / 2 - 70, 80, S / 2 + 70, 220], fill=hexc(c2))
    wd.rectangle([S / 2 - 26, 70, S / 2 + 26, 150], fill=(0, 0, 0, 0))
    wd.ellipse([S / 2 - 35, 360, S / 2 + 35, 430], fill=hexc(c2))
    w = w.rotate(-40, resample=Image.BICUBIC, center=(S / 2, S / 2))
    im.alpha_composite(w)
    return im

def swallow(c='#0b4ea2', c2='#3aa3e3'):
    """Stilisierte Schwalbe (Tsubame Unyu)."""
    im, d = _im()
    body = [(40, 300), (210, 250), (330, 170), (470, 90), (380, 210), (500, 200), (360, 270), (300, 330), (420, 440), (250, 350), (150, 330)]
    d.polygon(body, fill=hexc(c))
    d.polygon([(330, 170), (470, 90), (380, 210)], fill=hexc(c2))
    d.polygon([(300, 330), (420, 440), (250, 350)], fill=hexc(c2))
    d.ellipse([70, 270, 100, 300], fill=(255, 255, 255, 255))
    return im

def fox(c='#ee7a1a', c2='#ffffff', dark='#2b2b2b'):
    """Fuchskopf (Kitsune Kyūbin)."""
    im, d = _im()
    d.polygon([(70, 60), (210, 190), (120, 260)], fill=hexc(c))
    d.polygon([(442, 60), (302, 190), (392, 260)], fill=hexc(c))
    d.polygon([(95, 105), (180, 190), (125, 225)], fill=hexc(dark))
    d.polygon([(417, 105), (332, 190), (387, 225)], fill=hexc(dark))
    d.polygon([(100, 200), (412, 200), (440, 280), (256, 470), (72, 280)], fill=hexc(c))
    d.polygon([(72, 280), (256, 470), (180, 300)], fill=hexc(c2))
    d.polygon([(440, 280), (256, 470), (332, 300)], fill=hexc(c2))
    d.ellipse([236, 430, 276, 470], fill=hexc(dark))
    d.polygon([(165, 270), (225, 290), (170, 300)], fill=hexc(dark))
    d.polygon([(347, 270), (287, 290), (342, 300)], fill=hexc(dark))
    return im

def fire_emblem(red='#c8102e', gold='#e0b030'):
    """Erfundenes Feuerwehr-/Rettungsabzeichen: Flammenkreis mit Stern."""
    im, d = _im()
    d.ellipse([10, 10, S - 10, S - 10], fill=hexc(gold))
    d.ellipse([34, 34, S - 34, S - 34], fill=hexc(red))
    for i in range(12):
        a = math.radians(i * 30)
        d.polygon([(S / 2 + 60 * math.cos(a - 0.2), S / 2 + 60 * math.sin(a - 0.2)), (S / 2 + 200 * math.cos(a), S / 2 + 200 * math.sin(a)), (S / 2 + 60 * math.cos(a + 0.2), S / 2 + 60 * math.sin(a + 0.2))], fill=hexc(gold))
    d.ellipse([S / 2 - 80, S / 2 - 80, S / 2 + 80, S / 2 + 80], fill=(255, 255, 255, 255))
    d.text((S / 2, S / 2 + 4), '救', font=font('jp', 110), fill=hexc(red), anchor='mm')
    return im

def star_of_life(c='#c8102e'):
    """Rettungsstern (allgemeines Symbol, sechsarmig) mit Äskulapstab-Andeutung."""
    im, d = _im()
    for ang in (0, 60, 120):
        bar = Image.new('RGBA', (S, S), (0, 0, 0, 0)); bd = ImageDraw.Draw(bar)
        bd.rectangle([S / 2 - 70, 30, S / 2 + 70, S - 30], fill=hexc(c))
        im.alpha_composite(bar.rotate(ang, resample=Image.BICUBIC))
    d.rounded_rectangle([S / 2 - 10, 110, S / 2 + 10, S - 110], 8, fill=(255, 255, 255, 255))
    for k in range(4):
        y = 170 + k * 55
        d.arc([S / 2 - 40, y, S / 2 + 40, y + 55], 270 if k % 2 == 0 else 90, 90 if k % 2 == 0 else 270, fill=(255, 255, 255, 255), width=12)
    return im
