import sys
from emu import Machine
def lab(m,n): return m.label(n)
def val(m,n): return m.mem[m.label(n)]
def start_game(m, expert=False):
    m.run(30); m.tap(fire=True); m.run(20)
    if expert: m.tap(consol='option')
    m.tap(consol='start'); m.run(5)

# --- 1. dokonceni levelu: 4 rady plne krome sloupce 9, spadne I svisle ---
m=Machine(seed=5); m.load_labels(); start_game(m)
B=lab(m,'Board')
for i in range(200): m.mem[B+i]=8
for y in range(16,20):
    for x in range(9): m.mem[B+y*10+x]=3
m.mem[lab(m,'NextType')]=0
m.mem[lab(m,'State')]=0        # novy spawn s I
m.run(3)
m.tap(fire=True)               # rotace na svislou (dx=2)
for i in range(6): m.tap(stick='right')
print('CurX', val(m,'CurX'), 'CurRot', val(m,'CurRot'))
m.tap(key=0x21)                # hard drop
m.run(5); print('State after drop', val(m,'State'), 'FullCnt', val(m,'FullCnt'))
m.run(30)
print('Lines', m.mem[lab(m,'Lines')], 'MsgId', val(m,'MsgId'), 'Level', val(m,'Level'))
m.screenshot('out_levelclear.png')
m.run(200)
print('after seq: Level', val(m,'Level'), 'Score', bytes(m.mem[lab(m,'Score'):lab(m,'Score')+3])[::-1].hex(), 'State', val(m,'State'))
print(m.board_str())

# --- 2. game over ---
m=Machine(seed=6); m.load_labels(); start_game(m)
for i in range(30,200): m.mem[B+i]=2 if i%10 else 8
m.mem[lab(m,'State')]=0
m.run(700)
print('GameOver', val(m,'GameOverFlag'), 'DL', hex(m.mem[0xD403]))
m.screenshot('out_gameover.png')
print(m.text_rows(0x6E00,3))
m.tap(consol='start'); m.run(10)
print('back in menu? DL', hex(m.mem[0xD403]), 'pc', hex(m.cpu.pc))

# --- 3. pauza + ESC ---
m=Machine(seed=7); m.load_labels(); start_game(m)
m.tap(consol='start'); m.run(5); print('Paused', val(m,'Paused'))
m.screenshot('out_paused.png')
m.tap(key=0x0A); m.run(5); print('Paused after P', val(m,'Paused'))
m.tap(key=0x1C); m.run(5); print('after ESC DL', hex(m.mem[0xD403]))

# --- 4. expert: bez NEXT ---
m=Machine(seed=8); m.load_labels(); start_game(m, expert=True)
m.run(30); print(m.text_rows(0x6E00,3)); m.screenshot('out_expert.png')
print('floor bytes', bytes(m.mem[0x5010+160*40+12:0x5010+160*40+26]).hex())
