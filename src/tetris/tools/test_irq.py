#!/usr/bin/env python3
"""Regresni test: VBI prerusuje hlavni kod uprostred kresleni (male instr_per_frame).

Puvodne SoundTick (VBI) sdilel ptr2/tmp4 s PutStr; kdyz SFX_SELECT hral behem
vykreslovani HELP, text se zapsal mimo obrazovku a hra v Altirre spadla
(program error -> SELF TEST). Harness normalne pousti VBI jen po 10000 instrukcich,
proto to nevidel; tady se VBI pousti kazdych 400 instrukci (kresleni HELP
ma nekolik tisic instrukci, takze ho VBI prerusi mnohokrat).
Spusteni: python test_irq.py [tetris.xex]
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from emu import Machine

xex = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'tetris.xex')
lab = xex[:-4] + '.lab'
m = Machine(xex=xex); m.load_labels(lab)
m.instr_per_frame = 400
F = 1
m.run(30 * F); m.tap(frames_down=3 * F, frames_up=3 * F, fire=True); m.run(20 * F)
for _ in range(3):
    m.tap(frames_down=3 * F, frames_up=3 * F, stick='down')
m.tap(frames_down=3 * F, frames_up=3 * F, fire=True)
m.run(30 * F)
rows = m.text_rows(0x6000, 26)
ok = 'TETRIS - HELP' in rows[1] and 'PRESS ANY KEY OR FIRE TO RETURN' in rows[24] and 'ABANDON GAME' in rows[21]
code = bytes(m.mem[m.label('HelpScreen'):m.label('HelpScreen') + 8])
print('\n'.join(rows[:3]))
if not ok:
    raise SystemExit('FAIL: HELP text poskozeny (VBI prepsal ptr2 behem PutStr)')
m.tap(frames_down=3 * F, frames_up=3 * F, key=0x1C); m.run(10 * F)
if m.mem[0xD403] != m.mem[m.label('DlPtr') + 1]:
    raise SystemExit('FAIL: po ESC neni DL menu')
print('ALL OK')
