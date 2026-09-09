import sys, time
from emu import Machine
m = Machine(seed=int(sys.argv[1]) if len(sys.argv) > 1 else 3)
m.load_labels()
t=time.time()
m.run(30); m.tap(fire=True); m.run(20)      # menu
m.run(800)                                 # necinnost -> demo
print('Demo', m.mem[m.label('Demo')], 'State', m.mem[m.label('State')], 'frame', m.frame)
m.screenshot('out_demo1.png')
for i in range(6):
    m.run(500)
    print('--- frame', m.frame, 'score', bytes(m.mem[m.label('Score'):m.label('Score')+3])[::-1].hex(), 'lines', bytes(m.mem[m.label('Lines'):m.label('Lines')+2])[::-1].hex(), 'level', m.mem[m.label('Level')], 'over', m.mem[m.label('GameOverFlag')], 'abort', m.mem[m.label('AbortFlag')])
    print(m.board_str())
m.screenshot('out_demo2.png')
# preruseni dema klavesou
m.tap(key=0x21); m.run(10)
print('after key: Demo', m.mem[m.label('Demo')], 'pc', hex(m.cpu.pc), 'DL', hex(m.mem[0xD403]))
m.screenshot('out_after_demo.png')
print('time', time.time()-t)
