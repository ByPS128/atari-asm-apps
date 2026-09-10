#!/usr/bin/env python3
"""Test UI hlasek: PAUSED blika inverzne (pomaleji nez DEMO), po odpauzovani zmizi."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from emu import Machine

MSG = 0x6000 + 25*40


def check(c, msg):
    if not c: raise SystemExit('FAIL: ' + msg)
    print('ok  ', msg)


m = Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20); m.tap(consol='start'); m.run(5); m.run(10)
m.tap(key=0x0A); m.run(2)                       # P = pauza
check(m.mem[m.label('Paused')] == 1, 'pauza zapnuta')
inv = []
for _ in range(140):
    m.run(1)
    inv.append(bool(m.mem[MSG + 6] & 0x80))
check(any(inv) and not all(inv), 'PAUSED strida inverzni a normalni zobrazeni')
runs = [len(list(g)) for _, g in __import__('itertools').groupby(inv)][1:-1]
check(runs and all(r == 32 for r in runs), 'perioda pauzy = 32 snimku (DEMO ma 16)')
m.tap(key=0x0A); m.run(2)
check(m.mem[m.label('Paused')] == 0 and m.mem[MSG + 6] == 0, 'po odpauzovani hlaska zmizi')
print('ALL OK')
