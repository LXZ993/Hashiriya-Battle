from vcsvg import Doc
D = Doc()
def P(pts): return 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
# Werks-Zweifarbenlack: unterhalb der Karosserielinie Farbe 2 (rundum, auch Front-/Heckschuerze),
# genau auf der Trennkante ein Zierstreifen in Farbe 3
y0, rise, X0, X1 = 162, -4, -20, D.lw + 20
def yl(x): return y0 + rise * (x - X0) / (X1 - X0)
D.side('Farbe_2_Unterteil_GRUEN', P([(X0, yl(X0)), (X1, yl(X1)), (X1, 260 - 30), (X0, 260 - 30)]), 2)
th = 4
D.side('Farbe_3_Zierstreifen_BLAU', P([(X0, yl(X0) - th / 2), (X1, yl(X1) - th / 2), (X1, yl(X1) + th / 2), (X0, yl(X0) + th / 2)]), 3)
D.write('bx_twotone_a')
