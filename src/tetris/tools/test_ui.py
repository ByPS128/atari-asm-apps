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

# HELP: 2 stranky, libovolna klavesa listuje, ESC vraci do menu
m = Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20)
for _ in range(3): m.tap(stick='down'); m.run(2)
m.tap(fire=True); m.run(20)
rows = m.text_rows(0x6000, 26)
check('TETRIS - HELP' in rows[1] and 'NEXT PAGE' in rows[24], 'help: strana 1')
m.tap(fire=True); m.run(20)
rows = m.text_rows(0x6000, 26)
check('TETRIS - SCORING' in rows[1] and '1200 X LEVEL' in rows[7] and 'BACK TO MENU' in rows[24], 'help: strana 2 = bodovani')
m.tap(fire=True); m.run(10)
check(m.mem[0xD403] == m.mem[m.label('DlPtr') + 1] and m.mem[0xD403] != 0x70, 'help: po strane 2 zpet v menu')
m.tap(fire=True); m.run(20)              # MenuSel zustava na HELP
check('TETRIS - HELP' in m.text_rows(0x6000, 26)[1], 'help: znovu strana 1')
m.tap(key=0x1C); m.run(10)
check(m.mem[0xD403] != 0x70, 'help: ESC ze strany 1 rovnou do menu')
print('ALL OK')
