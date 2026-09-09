import sys, time
from emu import Machine
m = Machine(seed=int(sys.argv[1]) if len(sys.argv) > 1 else 1)
m.load_labels()
t=time.time()
m.run(30)
m.tap(fire=True)            # title -> menu
m.run(20)
m.screenshot('out_menu.png')
m.tap(stick='down'); m.tap(stick='right'); m.tap(stick='right')   # level 3
m.run(5)
m.screenshot('out_menu2.png')
m.tap(consol='start')       # start hry
m.run(60)
m.screenshot('out_game.png')
print(m.board_str()); print(m.text_rows(0x6E00,3))
# par tahu
m.tap(stick='left'); m.tap(stick='left'); m.tap(fire=True); m.run(10)
m.screenshot('out_game2.png')
print(m.board_str())
m.tap(key=0x21)             # space = hard drop
m.run(30)
print(m.board_str()); print(m.text_rows(0x6E00,3))
m.screenshot('out_game3.png')
print('time', time.time()-t, 'frames', m.frame, 'pokey writes', len(m.pokey_log))
