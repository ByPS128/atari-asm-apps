#!/usr/bin/env python3
"""Test: player 2 sleduje aktivni kostku (pozice, rotace, typ -> barva), player 3 kostku v NEXT.
Spusteni: python test_piece_pm.py   (v src/tetris/tools, po prekladu tetris.xex + tetris.lab)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from emu import Machine

P2, P3 = 0x5600, 0x5700
MASK = [0xC0, 0x30, 0x0C, 0x03]
COL = [0x9A, 0xEE, 0x48, 0xB8, 0x34, 0x76, 0x1A]


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

# Regression against merging the gray-well renderer back: all 28 poses,
# NEXT centering/colors, and visibility during incremental AI planning.
m.tap(key=0x0A)                       # freeze gameplay; rendering still runs
m.mem[m.label('Board'):m.label('Board')+240] = bytes([8])*240
for typ in range(7):
    for rot in range(4):
        x, y = (0, 3, 6, 3)[rot], (0, 6, 20, 2)[rot]
        for name, value in [('CurType',typ), ('CurRot',rot), ('CurX',x), ('CurY',y),
                            ('State',m.label('ST_FALL')), ('NextType',typ),
                            ('BoardDirty',1), ('NextDirty',1)]:
            m.mem[m.label(name)] = value
        m.run(3)
        assert actual_rows(P2,m) == expected_rows(m,typ,rot,y), (typ,rot,'P2 bitmap')
        assert m.reg(0xD002) == 48+4*(15+x) and m.reg(0xD014) == COL[typ], (typ,rot,'P2 registers')
        assert all(m.mem[0x6000+r*40+15+c] == 0 for r in range(24) for c in range(10)), 'active cells must not be gray text'
        codes = m.mem[m.label('PieceTab')+typ*16:m.label('PieceTab')+typ*16+4]
        xs, ys = [c&15 for c in codes], [c>>4 for c in codes]
        ox = (4-(max(xs)-min(xs)+1))//2-min(xs)
        oy = (4-(max(ys)-min(ys)+1))//2-min(ys)
        assert actual_rows(P3,m) == expected_rows(m,typ,0,2+oy), (typ,'NEXT bitmap')
        assert m.reg(0xD003) == 48+4*(32+ox) and m.reg(0xD015) == COL[typ], (typ,'NEXT registers')
check(True, 'vsech 28 rotaci a 7 barev P2/P3, NEXT vycentrovany, aktivni bunky bez sedeho textu')
m.mem[m.label('State')] = m.label('ST_PLAN')
m.mem[m.label('BoardDirty')] = 1
m.run(3)
check(actual_rows(P2,m) == expected_rows(m,typ,rot,y) and m.reg(0xD002) != 0, 'kostka zustava barevna i pri planovani AI')
m.mem[m.label('State')] = m.label('ST_CLEAR')
m.mem[m.label('BoardDirty')] = 1
m.run(3)
check(not actual_rows(P2,m) and m.reg(0xD002) == 0, 'P2 po zamknuti zmizi beze zbytku')
m.mem[m.label('MenuSkill')] = 2
m.mem[m.label('NextDirty')] = 1
m.run(3)
check(m.reg(0xD003) == 0, 'EXPERT skryva i hrace P3')
print('ALL OK')
