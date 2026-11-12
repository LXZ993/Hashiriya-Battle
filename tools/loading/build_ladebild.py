# Entwurf Ladebild 1 (C1 bei Nacht). Erzeugt hashiriya_01.svg mit Ebenen für VectorCraft.
# Fertiges Bild als JPG (3840x2160) nach art/loading/ legen.
import random, base64, math
random.seed(7)
W,H=1920,1080
import os
HERE=os.path.dirname(os.path.abspath(__file__))
logo=base64.b64encode(open(os.path.join(HERE,'..','..','art','logo','hashiriya-battle-logo.png'),'rb').read()).decode()
o=[]
o.append(f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
o.append('''<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05060c"/><stop offset=".55" stop-color="#0d1226"/><stop offset=".78" stop-color="#2a1630"/><stop offset="1" stop-color="#4a1e1a"/></linearGradient>
<radialGradient id="glow" cx=".5" cy="1" r=".7"><stop offset="0" stop-color="#ff7a1a" stop-opacity=".45"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/></radialGradient>
<linearGradient id="road" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a1c24"/><stop offset="1" stop-color="#07080b"/></linearGradient>
<linearGradient id="vign" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000" stop-opacity=".85"/><stop offset=".45" stop-color="#000" stop-opacity=".25"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>
<linearGradient id="bot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".8"/></linearGradient>
<linearGradient id="tail" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff2a1a" stop-opacity="0"/><stop offset="1" stop-color="#ff4a2a"/></linearGradient>
<linearGradient id="head" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff2d0"/><stop offset="1" stop-color="#ffd58a" stop-opacity="0"/></linearGradient>
<linearGradient id="orangebar" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff6a00"/><stop offset="1" stop-color="#ffb347" stop-opacity="0"/></linearGradient>
<filter id="blur"><feGaussianBlur stdDeviation="3"/></filter>
<filter id="blur2"><feGaussianBlur stdDeviation="10"/></filter>
</defs>''')
o.append(f'<g id="himmel"><rect width="{W}" height="{H}" fill="url(#sky)"/><rect y="200" width="{W}" height="500" fill="url(#glow)"/></g>')
# skyline layers
hz=640
for layer,(col,wcol,hmin,hmax,dens,op) in enumerate([("#161b33","#3b4466",80,260,0.0,1),("#0c0f1e","#ffcf7a",120,420,0.06,1)]):
    o.append(f'<g id="skyline{layer+1}">')
    x=-20
    while x<W:
        bw=random.randint(40,130); bh=random.randint(hmin,hmax)
        if random.random()<.12: bh+=random.randint(100,200)
        o.append(f'<rect x="{x}" y="{hz-bh}" width="{bw}" height="{bh+20}" fill="{col}"/>')
        if layer==1 and random.random()<.3: o.append(f'<circle cx="{x+bw/2}" cy="{hz-bh-6}" r="3" fill="#ff3020"/>')
        if dens:
            for wy in range(hz-bh+10,hz,14):
                for wx in range(x+6,x+bw-6,10):
                    if random.random()<dens*(1.5 if wy>hz-120 else 1): o.append(f'<rect x="{wx}" y="{wy}" width="5" height="7" fill="{random.choice(["#ffcf7a","#ffe6b0","#9fd0ff"])}" opacity="{random.uniform(.4,.9):.2f}"/>')
        x+=bw+random.randint(-10,6)
    o.append('</g>')
# elevated highway in perspective: vanishing point
vx,vy=1250,610
o.append('<g id="autobahn">')
o.append(f'<polygon points="{vx-30},{vy} {vx+30},{vy} {W+700},{H} {-300},{H}" fill="url(#road)"/>')
# barrier walls
o.append(f'<polygon points="{vx-30},{vy} {vx-30},{vy-14} {-300},{H-260} {-300},{H}" fill="#14161e"/>')
o.append(f'<polygon points="{vx+30},{vy} {vx+30},{vy-14} {W+700},{H-300} {W+700},{H}" fill="#101219"/>')
# lane lines
for f in (-0.35,0,0.35):
    for i in range(14):
        t0=(i/14)**1.8; t1=((i+0.45)/14)**1.8
        def p(t,f=f):
            bx=vx+f*60; ex=W/2+200+f*2000
            return bx+(ex-bx)*t, vy+(H-vy)*t
        a=p(t0); b=p(t1)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#d8d8d0" stroke-opacity=".55" stroke-width="{1+t1*10:.1f}"/>')
# street lamps along walls
for i in range(1,12):
    t=(i/12)**1.7
    for side,ex in ((-1,-300),(1,W+700)):
        bx=vx+side*30; x=bx+(ex-bx)*t; y=vy-14+((H-(260 if side<0 else 300))-(vy-14))*t
        hgt=20+260*t
        o.append(f'<line x1="{x:.0f}" y1="{y:.0f}" x2="{x:.0f}" y2="{y-hgt:.0f}" stroke="#1d2029" stroke-width="{1+6*t:.1f}"/>')
        o.append(f'<circle cx="{x:.0f}" cy="{y-hgt:.0f}" r="{3+30*t:.0f}" fill="#ffb060" opacity=".35" filter="url(#blur2)"/>')
        o.append(f'<circle cx="{x:.0f}" cy="{y-hgt:.0f}" r="{1+5*t:.1f}" fill="#ffe0a0"/>')
o.append('</g>')
# light trails
o.append('<g id="lichtspuren">')
def trail(f,col,w,spread):
    pts=[]
    for k in range(40):
        t=(k/39)**1.4
        bx=vx+f*40; ex=W/2+200+f*spread
        pts.append(f'{bx+(ex-bx)*t:.0f},{vy-2+(H+40-vy)*t:.0f}')
    return pts
for f,col,w in [(-.55,"#ff3a20",3),(-.45,"#ff5a30",2),(-.62,"#ff2a10",5),(.5,"#ffe8c0",3),(.62,"#fff4dc",5),(.42,"#ffd08a",2),(-.2,"#ff4a2a",2)]:
    pts=trail(f,col,w,2400)
    o.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{col}" stroke-width="{w*6}" opacity=".25" filter="url(#blur2)"/>')
    o.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{col}" stroke-width="{w}" opacity=".9"/>')
o.append('</g>')
o.append(f'<g id="abdunkeln"><rect width="{W}" height="{H}" fill="url(#vign)"/><rect y="700" width="{W}" height="380" fill="url(#bot)"/></g>')
# logo + text
o.append('<g id="logo">')
o.append(f'<image x="90" y="330" width="820" height="327" xlink:href="data:image/png;base64,{logo}"/>')
o.append('</g>')
o.append('<g id="schrift" font-family="Inter Display, Inter" fill="#fff">')
o.append('<text x="130" y="720" font-size="30" font-weight="800" letter-spacing="10" font-style="italic" fill="#ffb347">SHUTOKO C1 · MIDNIGHT</text>')
o.append('<text x="130" y="762" font-size="22" font-weight="500" letter-spacing="3" fill="#c9ccd6">Wer hier schläft, verliert die Nacht.</text>')
o.append('<text x="1790" y="1030" font-size="16" font-weight="600" letter-spacing="4" text-anchor="end" fill="#7d8294">JDMARSCH (LXZ AKA. LXZOCKT)</text>')
o.append('</g>')
o.append('</svg>')
open(os.path.join(HERE,'hashiriya_01.svg'),'w',encoding='utf-8').write("\n".join(o))
