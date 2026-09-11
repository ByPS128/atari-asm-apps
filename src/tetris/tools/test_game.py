from emu import Machine
from PIL import Image
def lab(m,n): return m.label(n)
def val(m,n): return m.mem[m.label(n)]

def check(ok, message):
    if not ok:
        raise AssertionError(message)

def check_board_screen(m):
    cells = list(m.mem[lab(m,'Board'):lab(m,'Board')+240])
    state = val(m,'State')
    if state in (m.label('ST_FALL'), m.label('ST_PLAN')):
        base = lab(m,'PieceTab') + val(m,'CurType')*16 + val(m,'CurRot')*4
        for code in m.mem[base:base+4]:
            x, y = val(m,'CurX')+(code & 15), val(m,'CurY')+(code >> 4)
            x &= 255
            check(x < 10 and y < 24, 'active piece outside well')
            cells[y*10+x] = 8  # active cells are rendered by P2, not text
    elif state == m.label('ST_CLEAR') and val(m,'FlashPhase'):
        for row in m.mem[lab(m,'FullRows'):lab(m,'FullRows')+val(m,'FullCnt')]:
            cells[row*10:row*10+10] = [8]*10
    actual = [m.mem[0x6000+y*40+15+x] for y in range(24) for x in range(10)]
    expected = [0 if cell in (7,8) else 0x80 for cell in cells]
    check(actual == expected, 'screen does not match board/active piece')
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
check(val(m,'MenuSkill') == 1 and m.mem[0xD403] == 0x71, 'menu skill selection')
m.tap(stick='down'); m.tap(stick='down'); m.tap(stick='down'); m.tap(fire=True); m.run(30)
print('help DL', hex(m.mem[0xD403]), 'PmOn', val(m,'PmOn')); m.screenshot('out_n_help.png'); shots.append('out_n_help.png')
print('\n'.join(m.text_rows(0x6000,26)[:8]))
check(m.mem[0xD403] == 0x70 and val(m,'PmOn') == 0, 'HELP graphics')
check('TETRIS - HELP' in m.text_rows(0x6000+40,1)[0], 'HELP title')
m.tap(fire=True); m.run(10)
check('TETRIS - SCORING' in m.text_rows(0x6000+40,1)[0], 'HELP scoring page')
m.tap(fire=True); m.run(10); print('back DL', hex(m.mem[0xD403]))
check(m.mem[0xD403] == 0x71, 'HELP return to menu')
# --- easy game ---
m=Machine(seed=5); m.load_labels(); start_game(m)
m.run(60); m.tap(stick='left'); m.tap(fire=True); m.tap(key=0x21); m.run(30)
m.screenshot('out_n_easy.png'); shots.append('out_n_easy.png')
print('\n'.join(m.text_rows(0x6000,26)))
print('RowsTarget', val(m,'RowsTarget'), 'Time', m.mem[lab(m,'TimeSec')])
check(val(m,'Level') == 1 and val(m,'RowsTarget') == 5, 'EASY level and target')
check_board_screen(m)
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
check(val(m,'MsgId') == 3 and val(m,'RowsInLevel') == 5, 'level-complete trigger')
check_board_screen(m)
m.screenshot('out_n_level.png'); shots.append('out_n_level.png')
m.run(200); print('after: Level', val(m,'Level'), 'Rows', val(m,'RowsInLevel'), 'Target', val(m,'RowsTarget'))
check((val(m,'Level'), val(m,'RowsInLevel'), val(m,'RowsTarget')) == (2,0,7), 'next level reset')
check_board_screen(m)
# --- advanced level 4 pattern ---
m=Machine(seed=6); m.load_labels(); start_game(m, skill=1, level_taps=3)
m.run(10); print('ADV level', val(m,'Level')); print(m.board_str()); m.screenshot('out_n_adv.png'); shots.append('out_n_adv.png')
check(val(m,'Level') == 4 and val(m,'MenuSkill') == 1, 'ADVANCED level selection')
check(any(v != 8 for row in m.board() for v in row), 'ADVANCED obstacles')
check_board_screen(m)
# --- expert: no next ---
m=Machine(seed=7); m.load_labels(); start_game(m, skill=2)
m.run(10); print('EXP row0', m.text_rows(0x6000,1)[0]); m.screenshot('out_n_exp.png'); shots.append('out_n_exp.png')
check(val(m,'MenuSkill') == 2, 'EXPERT selection')
check(all(m.mem[0x6000+y*40+x] == 0 for y in range(7) for x in range(31,37)), 'EXPERT hides complete NEXT area')
check_board_screen(m)
# --- pause / esc ---
m.tap(key=0x0A); m.run(5); print('Paused', val(m,'Paused'), m.text_rows(0x6000+25*40,1)[0])
check(val(m,'Paused') == 1, 'pause entered')
frozen = tuple(val(m,n) for n in ('CurX','CurY','State','TimeFrm','TimeSec','TimeMin'))
m.run(60)
check(frozen == tuple(val(m,n) for n in ('CurX','CurY','State','TimeFrm','TimeSec','TimeMin')), 'pause freezes game and time')
check('PAUSED' in m.text_rows(0x6000+25*40,1)[0], 'pause message')
m.tap(key=0x0A); m.tap(key=0x1C); m.run(5); print('after ESC DL', hex(m.mem[0xD403]), 'PmOn', val(m,'PmOn'))
check(m.mem[0xD403] == 0x71 and val(m,'PmOn') == 0, 'ESC returns to menu')
# --- game over ---
m=Machine(seed=8); m.load_labels(); start_game(m)
for i in range(30,240): m.mem[B+i]=2 if i%10 else 8
m.mem[lab(m,'State')]=0
m.run(600); print('GameOver', val(m,'GameOverFlag'), m.text_rows(0x6000+25*40,1)[0]); m.screenshot('out_n_over.png'); shots.append('out_n_over.png')
check(val(m,'GameOverFlag') == 1, 'blocked spawn causes game over')
check(all(v == 1 for row in m.board() for v in row), 'game-over fill completed')
check_board_screen(m)
m.tap(key=0x0A)
check(val(m,'Paused') == 0 and 'GAME OVER' in m.text_rows(0x6000+25*40,1)[0], 'game over ignores pause')
m.tap(consol='start'); m.run(10); print('menu DL', hex(m.mem[0xD403]))
check(m.mem[0xD403] == 0x71, 'game-over confirmation')
# --- demo ---
m=Machine(seed=3); m.load_labels(); m.run(30); m.tap(fire=True); m.run(800)
print('Demo', val(m,'Demo')); m.run(1500); print(m.board_str()); m.screenshot('out_n_demo.png'); shots.append('out_n_demo.png')
check(val(m,'Demo') == 1 and m.mem[0xD403] == 0x70, 'idle starts demo')
m.tap(key=0x21); m.run(10); print('after key DL', hex(m.mem[0xD403]))
check(m.mem[0xD403] == 0x71, 'short input exits demo')
imgs=[Image.open(f) for f in shots]; w=max(im.width for im in imgs); h=max(im.height for im in imgs)
sheet=Image.new('RGB',(w*2,h*4))
for i,im in enumerate(imgs): sheet.paste(im,((i%2)*w,(i//2)*h))
sheet.save('out_n_sheet.png')
for im in imgs: im.close()
print('ALL OK')
