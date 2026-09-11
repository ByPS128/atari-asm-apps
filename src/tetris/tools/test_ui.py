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

# skore roste postupne behem blikani smazane rady a na konci sedi presne
def score(m):
    b = m.label('Score'); return int('%02x%02x%02x' % (m.mem[b+2], m.mem[b+1], m.mem[b]))
m = Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20); m.tap(consol='start'); m.run(5); m.run(10)
check(m.mem[m.label('CurType')] == 2 and m.mem[m.label('CurX')] == 3 and m.mem[m.label('CurRot')] == 0, 'radky: T na x=3 (seed 5)')
B = m.label('Board')
for x in range(10):
    if x not in (3, 4, 5): m.mem[B + 23*10 + x] = 1     # rada 23 plna krome mista pro spodek T
s0 = score(m); y0 = m.mem[m.label('CurY')]
m.set_key(0x21); m.run(1); m.set_key(None)                # hard drop, vzorkovat od prvniho snimku
check(m.mem[m.label('State')] == 2, 'radky: blikani zacalo')
vals = [score(m)]
for _ in range(30):
    m.run(1); vals.append(score(m))
    if m.mem[m.label('State')] != 2: break
check(all(b >= a for a, b in zip(vals, vals[1:])), 'radky: skore behem blikani neklesa')
check(len(set(vals)) == 5, 'radky: 40 bodu = 4 dily po 10 rovnomerne (%d hodnot)' % len(set(vals)))
steps = [i for i in range(1, len(vals)) if vals[i] != vals[i-1]]
check(steps == [6, 12, 18, 24], 'radky: dily na snimcich 6/12/18/24 (%s)' % steps)
drop = 2 * (22 - y0)                                       # hard drop: 2 body za bunku (T dosedne na y=22)
check(vals[-1] == s0 + drop + 40 * m.mem[m.label('Level')], 'radky: konecne skore = drop + 40 x level (%d)' % vals[-1])
check(not any(a == 0 and v == 0x21 for f, a, v in m.pokey_log), 'radky: napocet bez pipani')

# bonus za level naskakuje 48 snimku a tika
m = Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20); m.tap(consol='start'); m.run(5); m.run(10)
B = m.label('Board')
for x in range(10):
    if x not in (3, 4, 5): m.mem[B + 23*10 + x] = 1
m.mem[m.label('RowsInLevel')] = m.mem[m.label('RowsTarget')] - 1
lvl = m.mem[m.label('Level')]
m.set_key(0x21); m.run(1); m.set_key(None)
s1 = score(m) + 40 * lvl                                   # po dropu; + rada, kterou smaze
m.run(23)                                                  # konec blikani, pred LevelDoneSeq
n0 = len(m.pokey_log)
check(m.mem[m.label('MsgId')] == 0, 'level: pred sekvenci jeste bez hlasky')
vals = []
for _ in range(60):
    m.run(1); vals.append(score(m))
check(m.mem[m.label('MsgId')] == 3, 'level: sekvence LEVEL COMPLETE bezi')
check(vals[-1] == s1 + 1000 * lvl, 'level: bonus 1000 x level pricten (%d -> %d)' % (s1, vals[-1]))
done = vals.index(vals[-1])
check(all(b >= a for a, b in zip(vals, vals[1:])) and len(set(vals)) > 10 and 44 <= done <= 50,
      'level: bonus naskakuje postupne, dojde ve snimku %d' % done)
bp = [f for f, a, v in m.pokey_log[n0:] if a == 1 and v == 0xA8]
check(14 <= len(bp) <= 17 and all(b - a == 3 for a, b in zip(bp, bp[1:])), 'level: pipani kazdy 3. snimek po dobu napoctu (%d pipnuti)' % len(bp))
check(m.pokey_log[-1][1] == 1 and m.pokey_log[-1][2] == 0 or m.reg(0xD201) == 0, 'level: po napoctu ticho')
print('ALL OK')
