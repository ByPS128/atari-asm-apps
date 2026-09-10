#!/usr/bin/env python3
"""Test: player 2 sleduje aktivni kostku (pozice, rotace, typ -> barva), player 3 kostku v NEXT.
Spusteni: python test_piece_pm.py   (v src/tetris/tools, po prekladu tetris.xex + tetris.lab)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from emu import Machine

P2, P3 = 0x5600, 0x5700
MASK = [0xC0, 0x30, 0x0C, 0x03]
COL = [0x90, 0xE0, 0x60, 0xB0, 0x30, 0x70, 0x10]


def v(m, n): return m.mem[m.label(n)]


def expected_rows(m, typ, rot, y, x0=None):
    """ocekavana data hrace: {scanline: maska} podle PieceTab"""
    tab = m.label('PieceTab') + typ*16 + rot*4
    rows = {}
    for i in range(4):
        b = m.mem[tab + i]; dx, dy = b & 15, b >> 4
        for l in range(8):
            k = 16 + 8*(y + dy) + l
            rows[k] = rows.get(k, 0) | MASK[dx]
    return rows


def actual_rows(base, m):
    return {i: m.mem[base + i] for i in range(256) if m.mem[base + i]}


def check(c, msg):
    if not c: raise SystemExit('FAIL: ' + msg)
    print('ok  ', msg)


m = Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20); m.tap(consol='start'); m.run(5); m.run(40)
check(v(m, 'State') == 1, 'kostka pada')
t, r, x, y = v(m, 'CurType'), v(m, 'CurRot'), v(m, 'CurX'), v(m, 'CurY')
check(actual_rows(P2, m) == expected_rows(m, t, r, y), 'P2 data = bunky aktivni kostky')
check(v(m, 'PcHpos') == 48 + 4*(15 + x) and v(m, 'PcCol') == COL[t], 'P2 HPOS a barva podle typu')
check(m.reg(0xD00A) == 1 and m.reg(0xD00B) == 1, 'P2/P3 dvojnasobna sirka')
m.tap(fire=True); m.run(3)
check(v(m, 'CurRot') == (r + 1) % 4, 'rotace probehla')
check(actual_rows(P2, m) == expected_rows(m, t, v(m, 'CurRot'), v(m, 'CurY')), 'P2 data po rotaci')
m.tap(stick='left'); m.run(3)
check(v(m, 'CurX') == x - 1 and v(m, 'PcHpos') == 48 + 4*(15 + x - 1), 'P2 HPOS po posunu vlevo')
y1 = v(m, 'CurY'); m.run(60)
check(v(m, 'CurY') > y1 and actual_rows(P2, m) == expected_rows(m, t, v(m, 'CurRot'), v(m, 'CurY')), 'P2 data po padu (stare radky smazane)')
# NEXT
nt = v(m, 'NextType')
rows3 = actual_rows(P3, m)
check(rows3 and v(m, 'NxCol') == COL[nt] and all(16 + 8*2 <= k < 16 + 8*6 for k in rows3), 'P3 = NEXT kostka uvnitr ramecku, barva podle typu')
# hard drop -> po zamknuti kostka zmizi, po spawnu se objevi nova s barvou noveho typu
m.tap(key=0x21); m.run(2)
check(v(m, 'State') != 1 or v(m, 'CurType') == nt, 'po hard dropu novy kus = byvaly NEXT')
m.run(20)
check(v(m, 'State') == 1 and v(m, 'PcCol') == COL[v(m, 'CurType')], 'P2 barva noveho kusu')
print('ALL OK')
