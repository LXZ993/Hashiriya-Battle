# Startet den Offline-Test des Gegner-Fahrers mit LuaJIT (pip install lupa)
# python3 tools/driver-sim/run.py [highway|touge] [skill] [courage]
import os, sys
import lupa.luajit21 as lupa

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
L = lupa.LuaRuntime()
g = L.globals()
g.SCENARIO = sys.argv[1] if len(sys.argv) > 1 else 'highway'
if len(sys.argv) > 2: g.SKILL = float(sys.argv[2])
if len(sys.argv) > 3: g.COURAGE = float(sys.argv[3])
if os.environ.get('TRACE'):
    a, b = os.environ['TRACE'].split('-'); g.TRACE_FROM = float(a); g.TRACE_TO = float(b)
extra = os.environ.get('EXTRA')
if extra:
    g.EXTRA = L.eval('{' + extra + '}')
if os.environ.get('MAXANGLE'): g.MAXANGLE = float(os.environ['MAXANGLE'])
g.DRIVER_PATH = os.path.join(root, 'lua', 'vehicle', 'extensions', 'hashiriyaDriver.lua')
L.execute(open(os.path.join(root, 'tools', 'driver-sim', 'sim.lua'), encoding='utf-8').read())
