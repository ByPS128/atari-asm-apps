"""Reproducible source-review probes for Tetris (11 September 2026).

Build tetris.xex and tetris.lab first, then run python tools/audit_tetris.py.
Runs the assembled routines and selected UI scenarios, prints JSON evidence.
Exit status 1 means a detected issue; assertions also fail on core regressions.
This is a targeted audit, not a complete hardware compatibility test.
"""
import json
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from emu import Machine

SOURCE = (ROOT / 'tetris.asm').read_text(encoding='utf-8')
RESULT = {}


def fresh():
    m = Machine(seed=13)
    m.load_labels()
    for vector, name in [(0x222, 'Vbi'), (0x200, 'Dli')]:
        m.mem[vector:vector+2] = m.label(name).to_bytes(2, 'little')
    return m


def put(m, name, value):
    m.mem[m.label(name)] = value & 255


def val(m, name):
    return m.mem[m.label(name)]


def word(m, name, value):
    a = m.label(name)
    m.mem[a:a+2] = value.to_bytes(2, 'little')


def begin(m, name):
    m.cpu.sp = 255
    m.cpu.push16(0x05FF)
    m.cpu.pc = m.label(name)


def finish(m, hook=None, limit=2000000):
    n = 0
    while m.cpu.pc != 0x0600:
        if n >= limit:
            raise RuntimeError('routine did not finish')
        if hook:
            hook(m, n)
        m.cpu.step()
        n += 1
    return n


def call(m, name, hook=None):
    begin(m, name)
    return finish(m, hook)


def bcd(data):
    return sum(((v >> 4)*10+(v & 15))*100**i for i, v in enumerate(data))


# Interrupt a real text write, with a real sound effect pending.
for interrupted in (False, True):
    m = fresh()
    m.cpu.x = 0
    call(m, 'PlaySfx')
    word(m, 'ptr', m.label('TxtLevel'))
    word(m, 'ptr2', 0x6000)
    put(m, 'tmp4', 0x7B)
    sound_addr = m.label('SdMove')
    original_sound = bytes(m.mem[sound_addr:sound_addr+6])
    begin(m, 'PutStr')
    if interrupted:
        m.run_interrupt(0x222, True)
    finish(m)
    RESULT['text_with_vbi' if interrupted else 'text_without_vbi'] = {
        'screen': list(m.mem[0x6000:0x6005]),
        'sound_before': list(original_sound),
        'sound_after': list(m.mem[sound_addr:sound_addr+6]),
        'tmp4_after': val(m, 'tmp4'),
    }

# Every effect preserves mainline ZP/registers and emits the original sequence.
for effect in range(13):
    m = fresh()
    channel = m.mem[m.label('SfxChan')+effect]
    pointer = m.mem[m.label('SfxLo')+effect] | (m.mem[m.label('SfxHi')+effect] << 8)
    expected = []
    tick = 0
    while m.mem[pointer+2]:
        freq, control, length = m.mem[pointer:pointer+3]
        expected.extend([(tick, channel*2, freq), (tick, channel*2+1, control)])
        tick += length + 1
        pointer += 3
    expected.append((tick, channel*2+1, 0))
    m.cpu.x = effect
    call(m, 'PlaySfx')
    protected = [a for a in range(0x80, m.label('SndRead'))
                 if a not in (m.label('FrameCnt'), m.label('DliMode'))]
    for a in protected:
        m.mem[a] = (a*37) & 255
    original_zp = [m.mem[a] for a in protected]
    m.cpu.a, m.cpu.x, m.cpu.y = 0xA5, 0x83, 0x72
    m.cpu.d = True
    original_cpu = (m.cpu.a, m.cpu.x, m.cpu.y, m.cpu.sp, m.cpu.pc, m.cpu.flags())
    for frame in range(tick+1):
        m.frame = frame
        m.run_interrupt(0x222, True)
        assert original_zp == [m.mem[a] for a in protected], ('VBI ZP', effect)
        assert original_cpu == (m.cpu.a, m.cpu.x, m.cpu.y, m.cpu.sp, m.cpu.pc, m.cpu.flags()), ('VBI registers', effect)
    assert m.pokey_log == expected, ('POKEY sequence', effect)
RESULT['sound_interrupts'] = '13 complete effects: registers/ZP/timing OK'

# Check scalar helpers and line awards across every supported level.
m = fresh()
for value in range(100):
    m.cpu.a, m.cpu.y = value, 0
    call(m, 'Bin2Dec')
    assert (val(m, 'tmp2'), val(m, 'tmp3')) == divmod(value, 10)
for level in range(1, 21):
    for count in range(1, 5):
        m = fresh()
        put(m, 'Level', level)
        put(m, 'FullCnt', count)
        call(m, 'ScoreLines')
        a = m.label('Score')
        assert bcd(m.mem[a:a+3]) == [0, 40, 100, 300, 1200][count]*level
        assert val(m, 'RowsInLevel') == count
RESULT['decimal_and_score'] = '100 conversions and 80 line awards OK'

# Compare removal of arbitrary row combinations against a simple reference.
rng = random.Random(67)
for test in range(120):
    m = fresh()
    rows = [[rng.choice([8, 8, 8, 0, 1, 2, 3]) for x in range(10)] for y in range(24)]
    for row in rows:
        row[rng.randrange(10)] = 8
    selected = sorted(rng.sample(range(24), 1 + test % 4))
    for y in selected:
        rows[y] = [test % 7]*10
    a = m.label('Board')
    m.mem[a:a+240] = bytes(v for row in rows for v in row)
    call(m, 'FindFull')
    assert val(m, 'FullCnt') == len(selected)
    call(m, 'RemoveFullRows')
    expected = [[8]*10 for y in selected] + [row for y, row in enumerate(rows) if y not in selected]
    assert list(m.mem[a:a+240]) == [v for row in expected for v in row]
RESULT['row_removal'] = '120 reference comparisons OK'

# Compare every skill/level pattern against the source data interpretation.
patterns = {}
for index in range(1, 13):
    match = re.search(r'^Pat'+str(index)+r'\s+\.byte (\d+)\n((?:[ \t]+dta c\'[.#]{10}\'\n)+)', SOURCE, re.M)
    patterns[index] = re.findall(r"'([.#]{10})'", match[2])
for skill in range(3):
    for level in range(1, 21):
        m = fresh()
        put(m, 'MenuSkill', skill)
        put(m, 'Level', level)
        call(m, 'StartLevel')
        rows = ['.'*10]*24
        if skill:
            index = level
            while index > 12:
                index -= 6
            bottom = patterns[index] + (['#.##.###.#'] if level > 12 else [])
            rows[24-len(bottom):] = bottom
        expected = [1 if c == '#' else 8 for row in rows for c in row]
        a = m.label('Board')
        assert list(m.mem[a:a+240]) == expected
RESULT['patterns'] = '60 skill/level combinations OK'

# Collision boundaries, including valid negative piece origins.
m = fresh()
p = m.label('PieceTab')
cases = 0
for piece in range(7):
    put(m, 'CurType', piece)
    for rotation in range(4):
        put(m, 'TestRot', rotation)
        cells = [(b & 15, b >> 4) for b in m.mem[p+piece*16+rotation*4:p+piece*16+rotation*4+4]]
        for x in range(-3, 11):
            for y in range(-3, 25):
                put(m, 'TestX', x)
                put(m, 'TestY', y)
                expected = all(0 <= x+dx < 10 and 0 <= y+dy < 24 for dx, dy in cells)
                call(m, 'Fits')
                assert m.cpu.c == expected, (piece, rotation, x, y)
                cases += 1
RESULT['fits_empty'] = f'{cases} boundary cases OK'

# Measure bounded AI steps, with rendering interleaved to clobber Test*.
RESULT['ai_instructions_empty'] = {}
for piece, name in enumerate(['I','O','T','S','Z','J','L']):
    m = fresh()
    put(m, 'CurType', piece)
    put(m, 'State', m.label('ST_PLAN'))
    before = bytes(m.mem[m.label('Board'):m.label('Board')+240])
    instructions = call(m, 'AiPlan')
    costs = []
    for step in range(48):
        costs.append(call(m, 'AiPlanStep'))
        done = m.cpu.c
        assert bytes(m.mem[m.label('Board'):m.label('Board')+240]) == before
        call(m, 'RenderGame')
        if done:
            break
    else:
        raise AssertionError('AI did not finish within 48 candidates')
    assert max(costs) < 6500, (name, max(costs))
    RESULT['ai_instructions_empty'][name] = {
        'total': instructions + sum(costs), 'max_step': max(costs), 'steps': len(costs),
    }
m = fresh()
call(m, 'SetGameScreen')
call(m, 'RenderGame')
writes = []
original_wr = m.wr
def traced_wr(addr, value):
    if 0x6000 <= addr < 0x6410:
        writes.append(addr)
    original_wr(addr, value)
m.wr = traced_wr
RESULT['idle_render'] = {'instructions': call(m, 'RenderGame'), 'screen_writes': len(writes)}
assert not writes and RESULT['idle_render']['instructions'] < 100, 'unchanged screen was redrawn'

def started():
    m = fresh()
    m.run(30)
    m.tap(fire=True)
    m.tap(consol='start')
    m.run(5)
    return m


# A short ESC press entirely inside AI planning is not sampled.
m = started()
put(m, 'Demo', 1)
put(m, 'State', 0)
put(m, 'NextType', 2)
m.run(1)
planning_pc = m.cpu.pc
m.set_key(0x1C)
m.run(3)
m.set_key(None)
m.run(28)
RESULT['demo_short_escape_during_plan'] = {
    'pc_when_pressed': hex(planning_pc),
    'abort_after_short_press': val(m, 'AbortFlag'),
    'display_list_high_after_short_press': hex(m.mem[0xD403]),
    'demo_after_short_press': val(m, 'Demo'),
}
m.set_key(0x1C)
m.run(35)
m.set_key(None)
m.run(5)
RESULT['demo_short_escape_during_plan']['display_list_after_held_escape'] = hex(m.mem[0xD403])

# Ordinary pause differs from the level-complete sequence.
m = started()
a = m.label('Board')
m.mem[a:a+240] = bytes([8])*240
put(m, 'State', 2)
put(m, 'FullCnt', 0)
put(m, 'FlashCnt', 23)
put(m, 'RowsInLevel', val(m, 'RowsTarget'))
m.run(5)
assert val(m, 'MsgId') == 3
m.tap(key=0x0A)
before = {n: val(m,n) for n in ['Level','Paused','SeqCnt']}
m.run(160)
after = {n: val(m,n) for n in ['Level','Paused','SeqCnt']}
RESULT['level_transition_while_paused'] = {'before': before, 'after': after}
assert before['Paused'] == after['Paused'] == 1
assert before['SeqCnt'] == after['SeqCnt'], 'paused countdown advanced'
m.tap(key=0x0A)
m.run(160)
assert val(m,'Level') == 2 and val(m,'Paused') == 0, 'level did not resume'

# OPTION is sampled at boot; debug shortcuts must stay disabled normally.
m = fresh()
m.set_consol(option=True)
m.run(3)
m.set_consol()
m.run(10)
m.tap(fire=True)
assert val(m,'DevMode') == 1 and val(m,'LevelMax') == 20
put(m,'MenuLevel',20)
m.tap(consol='select')
assert val(m,'MenuLevel') == 1
put(m,'MenuLevel',15)
m.tap(consol='select')
assert val(m,'MenuLevel') == 16
m.tap(consol='start')
m.run(5)
m.tap(key=0x23)
m.run(5)
assert val(m,'Level') == 17 and val(m,'RowsInLevel') == 0
m.tap(key=0x3D)
m.run(60)
assert val(m,'GameOverFlag') == 1
m = started()
m.tap(key=0x23)
m.tap(key=0x3D)
assert val(m,'Level') == 1 and val(m,'GameOverFlag') == 0
RESULT['dev_mode'] = 'boot OPTION, level bounds, N/G and normal-mode guards OK'

# Changing only the instruction budget should never modify immutable code/data.
RESULT['phase_sweep'] = []
for budget in [3500, 4500, 6000, 8000, 10000]:
    m = fresh()
    m.instr_per_frame = budget
    lo, hi = m.label('RowOff10'), m.label('PS_e')+1
    immutable = bytes(m.mem[lo:hi])
    error = None
    try:
        m.run(20)
        m.tap(fire=True)
        m.tap(consol='option')
        m.tap(consol='select')
        m.tap(consol='select')
        m.tap(consol='select')
        m.tap(consol='start')
        m.run(10)
        for _ in range(4):
            m.tap(key=0x21)
            m.run(5)
    except Exception as exc:
        error = str(exc)
    changed = [hex(lo+i) for i,(a,b) in enumerate(zip(immutable, m.mem[lo:hi])) if a != b]
    RESULT['phase_sweep'].append({'budget': budget, 'changed_immutable_bytes': len(changed), 'first_addresses': changed[:5], 'error': error})

issues = []
normal, interrupted = RESULT['text_without_vbi'], RESULT['text_with_vbi']
if (interrupted['screen'] != normal['screen'] or
        interrupted['sound_after'] != interrupted['sound_before'] or
        interrupted['tmp4_after'] != normal['tmp4_after']):
    issues.append('VBI corrupts mainline temporaries/text destination')
if any(r['changed_immutable_bytes'] or r['error'] for r in RESULT['phase_sweep']):
    issues.append('Normal UI scenario corrupts immutable data or crashes')
if RESULT['demo_short_escape_during_plan']['display_list_high_after_short_press'] != '0x71':
    issues.append('Demo misses short ESC press during AI planning')
if after['Paused'] and after['Level'] != before['Level']:
    issues.append('Level completion advances while paused')
RESULT['detected_issues'] = issues
print(json.dumps(RESULT, indent=2), flush=True)
raise SystemExit(1 if issues else 0)
