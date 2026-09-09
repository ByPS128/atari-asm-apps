import sys
from emu import Machine
from PIL import Image
def lab(m,n): return m.label(n)
def val(m,n): return m.mem[m.label(n)]
def start_game(m, skill=0, level_taps=0):
    m.run(30); m.tap(fire=True); m.run(20)
    for i in range(skill): m.tap(consol='option')
    for i in range(level_taps): m.tap(consol='select')
    m.tap(consol='start'); m.run(5)
shots=[]
# --- menu + help ---
m=Machine(seed=5); m.load_labels()
m.run(30); m.tap(fire=True); m.run(20)
m.tap(consol='option'); m.run(3); m.screenshot('out_n_menu.png'); shots.append('out_n_menu.png')
print('menu rows', m.text_rows(0x6A40,4,20))
m.tap(stick='down'); m.tap(stick='down'); m.tap(stick='down'); m.tap(fire=True); m.run(30)
print('help DL', hex(m.mem[0xD403]), 'PmOn', val(m,'PmOn')); m.screenshot('out_n_help.png'); shots.append('out_n_help.png')
print('\n'.join(m.text_rows(0x6000,26)[:8]))
m.tap(fire=True); m.run(10); print('back DL', hex(m.mem[0xD403]))
# --- easy game ---
m=Machine(seed=5); m.load_labels(); start_game(m)
m.run(60); m.tap(stick='left'); m.tap(fire=True); m.tap(key=0x21); m.run(30)
m.screenshot('out_n_easy.png'); shots.append('out_n_easy.png')
print('\n'.join(m.text_rows(0x6000,26)))
print('RowsTarget', val(m,'RowsTarget'), 'Time', m.mem[lab(m,'TimeSec')])
# --- level clear via target: set RowsInLevel = target-1, fill 1 row except col 9, drop I vertical ---
B=lab(m,'Board')
for i in range(240): m.mem[B+i]=8
for x in range(9): m.mem[B+23*10+x]=3
m.mem[lab(m,'RowsInLevel')]=val(m,'RowsTarget')-1
m.mem[lab(m,'NextType')]=0; m.mem[lab(m,'State')]=0; m.run(3)
m.tap(fire=True)
for i in range(6): m.tap(stick='right')
m.tap(key=0x21); m.run(40)
print('MsgId', val(m,'MsgId'), 'Level', val(m,'Level'), 'Rows', val(m,'RowsInLevel'))
m.screenshot('out_n_level.png'); shots.append('out_n_level.png')
m.run(200); print('after: Level', val(m,'Level'), 'Rows', val(m,'RowsInLevel'), 'Target', val(m,'RowsTarget'))
# --- advanced level 4 pattern ---
m=Machine(seed=6); m.load_labels(); start_game(m, skill=1, level_taps=3)
m.run(10); print('ADV level', val(m,'Level')); print(m.board_str()); m.screenshot('out_n_adv.png'); shots.append('out_n_adv.png')
# --- expert: no next ---
m=Machine(seed=7); m.load_labels(); start_game(m, skill=2)
m.run(10); print('EXP row0', m.text_rows(0x6000,1)[0]); m.screenshot('out_n_exp.png'); shots.append('out_n_exp.png')
# --- pause / esc ---
m.tap(key=0x0A); m.run(5); print('Paused', val(m,'Paused'), m.text_rows(0x6000+25*40,1)[0])
m.tap(key=0x0A); m.tap(key=0x1C); m.run(5); print('after ESC DL', hex(m.mem[0xD403]), 'PmOn', val(m,'PmOn'))
# --- game over ---
m=Machine(seed=8); m.load_labels(); start_game(m)
for i in range(30,240): m.mem[B+i]=2 if i%10 else 8
m.mem[lab(m,'State')]=0
m.run(600); print('GameOver', val(m,'GameOverFlag'), m.text_rows(0x6000+25*40,1)[0]); m.screenshot('out_n_over.png'); shots.append('out_n_over.png')
m.tap(consol='start'); m.run(10); print('menu DL', hex(m.mem[0xD403]))
# --- demo ---
m=Machine(seed=3); m.load_labels(); m.run(30); m.tap(fire=True); m.run(800)
print('Demo', val(m,'Demo')); m.run(1500); print(m.board_str()); m.screenshot('out_n_demo.png'); shots.append('out_n_demo.png')
m.tap(key=0x21); m.run(10); print('after key DL', hex(m.mem[0xD403]))
imgs=[Image.open(f) for f in shots]; w,h=imgs[0].size
sheet=Image.new('RGB',(w*2,h*4))
for i,im in enumerate(imgs): sheet.paste(im,((i%2)*w,(i//2)*h))
sheet.save('out_n_sheet.png')
