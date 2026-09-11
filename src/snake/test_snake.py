#!/usr/bin/env python3
"""Automaticky test snake.xex v headless harnessu ../tetris/tools/emu.py.

Spusteni:  python test_snake.py          (predpoklada prelozeny snake.xex + snake.lab)
Vystup:    out_menu.png, out_game.png, out_over.png, out_eat.wav/.png v tomto adresari.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tetris', 'tools'))
from emu import Machine

XEX = os.path.join(HERE, 'snake.xex')
LAB = os.path.join(HERE, 'snake.lab')
KEY_RETURN, KEY_ESC = 0x0C, 0x1C


def machine(seed=1):
    m = Machine(xex=XEX, seed=seed)
    m.load_labels(LAB)
    return m


def screen(m):
    return m.text_rows(m.label('SCREEN') if 'SCREEN' in m.labels else 0x3000, 24)


def var(m, name):
    return m.mem[m.label(name)]


def snake(m):
    n = var(m, 'SnakeLen')
    x, y = m.label('SnakeX'), m.label('SnakeY')
    return [(m.mem[x + i], m.mem[y + i]) for i in range(n)]


APPLE = 0x6E
GL = 0x60   # BODY_H, BODY_V, C_LU, C_LD, C_RU, C_RD, HEAD U/R/D/L, TAIL U/R/D/L


def cell(m, x, y):
    return m.mem[0x3000 + y*40 + x]


def apples(m):
    return [(i % 40, i // 40) for i in range(960) if m.mem[0x3000 + i] == APPLE]


P0DATA = 0x3C00


def sprite_ok(m, x, y):
    rows = list(m.mem[P0DATA + 32 + 8*y: P0DATA + 32 + 8*y + 8])
    leaf = list(m.mem[P0DATA + 0x100 + 32 + 8*y: P0DATA + 0x100 + 32 + 8*y + 8])
    return (rows == [0, 0, 0x60, 0xF0, 0xF0, 0xF0, 0xF0, 0x60] and leaf == [0x20, 0xE0, 0, 0, 0, 0, 0, 0]
            and m.mem[m.label('AppleHpos')] == 48 + 4*x)


def check(cond, msg):
    if not cond:
        raise SystemExit('FAIL: ' + msg)
    print('ok  ', msg)


def main():
    m = machine()
    m.run(5)
    rows = screen(m)
    tb = m.label('TitleBuf')
    check(bytes(m.mem[tb+7:tb+12]) == bytes(b & 0x3F for b in (0xF3, 0xEE, 0xE1, 0xEB, 0xE5)) or
          [b & 0x3F for b in m.mem[tb+7:tb+12]] == [0x33, 0x2E, 0x21, 0x2B, 0x25], 'menu: titulek SNAKE v mode 6')
    check(m.mem[0xD402] | (m.mem[0xD403] << 8) == m.label('DListMenu'), 'menu: display list menu')
    check('START GAME' in rows[10] and 'ABOUT' in rows[12], 'menu: polozky')
    check(cell(m, 14, 10) == 0x80 and cell(m, 25, 10) == 0x80, 'menu: START GAME inverzni vcetne mezer po stranach')
    m.screenshot(os.path.join(HERE, 'out_menu.png'))

    # dolu -> ABOUT, RETURN -> obrazovka ABOUT, ESC -> zpet
    m.tap(stick='down'); m.run(2)
    check(cell(m, 16, 12) == 0x80 and cell(m, 22, 12) == 0x80 and cell(m, 14, 10) == 0, 'menu: sipka dolu vybere ABOUT')
    m.tap(key=KEY_RETURN); m.run(3)
    check('SNAKE FOR ATARI XL/XE' in screen(m)[6], 'about: zobrazen')
    check(cell(m, 15, 14) == APPLE and sprite_ok(m, 15, 14), 'about: v napovede je jablko (znak + sprite)')
    check(cell(m, 1, 4) == GL+10 and cell(m, 1, 1) == GL+5 and cell(m, 4, 1) == GL+7, 'about: dekoracni had (ocas, roh, hlava)')
    seen = set()
    for _ in range(400):
        m.run(1); seen.add(cell(m, 4, 1))
    check(seen == {GL+7, GL+15}, 'about: hlava mrka (stridaji se otevrene a zavrene oci)')
    m.tap(key=KEY_ESC); m.run(3)
    check('START GAME' in screen(m)[10], 'about: ESC vraci do menu')

    # nahoru -> START GAME, FIRE -> hra
    m.tap(stick='up'); m.run(2)
    m.tap(fire=True); m.run(3)
    rows = screen(m)
    check('SCORE 000' in rows[0] and 'LENGTH 003' in rows[0], 'hra: stavovy radek')
    check(snake(m) == [(20, 12), (19, 12), (18, 12)], 'hra: vychozi had')
    check([cell(m, x, 12) for x in (18, 19, 20)] == [GL+11, GL+0, GL+7], 'hra: had = ocas, telo, hlava vpravo')
    check(m.mem[0xD402] | (m.mem[0xD403] << 8) == m.label('DList'), 'hra: herni display list')
    check(cell(m, 0, 1) == 0x51 and cell(m, 39, 23) == 0x43 and cell(m, 5, 1) == 0x52 and cell(m, 0, 5) == 0x7C, 'hra: ramecek z ROM znaku')
    check(len(apples(m)) == 1 and sprite_ok(m, *apples(m)[0]), 'hra: prave jedno jablko, sprite na jeho pozici')
    check(sum(m.mem[P0DATA:P0DATA+512]) == 0x60*2 + 0xF0*4 + 0x20 + 0xE0, 'hra: sprite jablka z About je schovany')

    # pohyb doprava: po 10 snimcich krok
    m.run(12)
    check(snake(m)[0] == (21, 12), 'hra: had udelal krok doprava')
    check(cell(m, 18, 12) == 0 and cell(m, 19, 12) == GL+11 and cell(m, 20, 12) == GL+0 and cell(m, 21, 12) == GL+7, 'hra: ocas smazan, novy ocas a telo prekresleny')

    # otoceni do sebe (vlevo pri pohybu vpravo) se ignoruje
    n0 = len(m.pokey_log)
    m.set_stick(left=True); m.run(10); m.set_stick()
    check(var(m, 'SnakeDir') == 1, 'hra: otoceni o 180 stupnu ignorovano')
    denied = [(a, v) for _, a, v in m.pokey_log[n0:] if a == 1 and v == 0xAA]
    check(len(denied) == 6, 'hra: zvuk denied zazni jednou (ne kazdy snimek drzeni)')
    # klavesa: CTRL+'+' (vlevo) pri jizde vpravo -> take denied
    m.run(2)                      # uvolneni joysticku se musi projevit
    n0 = len(m.pokey_log)
    m.tap(key=0x06); m.run(2)
    check(any(a == 1 and v == 0xAA for _, a, v in m.pokey_log[n0:]), 'hra: denied i z klavesnice')
    # zatacka: nahoru -> stara hlava se stane rohem, hlava miri nahoru
    m.set_stick(up=True); m.run(10); m.set_stick()
    hx, hy = snake(m)[0]
    check(cell(m, hx, hy) == GL+6 and cell(m, hx, hy+1) == GL+2, 'hra: zatacka = roh LU, hlava nahoru')
    # U: doleva a dolu -> dva rohy, svisle segmenty v sousednich sloupcich
    m.set_stick(left=True); m.run(10); m.set_stick()
    m.set_stick(down=True); m.run(10); m.set_stick()
    hx, hy = snake(m)[0]
    check(cell(m, hx, hy) == GL+8 and cell(m, hx, hy-1) == GL+5 and cell(m, hx+1, hy-1) == GL+13, 'hra: pismeno U = roh RD, ocas miri vlevo')
    m.screenshot(os.path.join(HERE, 'out_u.png'))

    # nahoru, pak cesta k jablku: dojdi na sloupec jablka a pak na jeho radek
    ax, ay = apples(m)[0]
    hx, hy = snake(m)[0]
    # nejdriv svisle na radek jablka (pokud je jiny), pak vodorovne
    if ay != hy:
        if (ay < hy) == (var(m, 'SnakeDir') == 2):      # opacny smer -> nejdriv uhnout do strany
            m.set_stick(left=(ax < hx), right=(ax > hx)); m.run(10); m.set_stick()
        m.set_stick(up=(ay < hy), down=(ay > hy)); m.run(10); m.set_stick()
        while snake(m)[0][1] != ay:
            m.run(10)
            assert not var(m, 'Dead'), 'cestou k jablku had zemrel'
    m.set_stick(left=(ax < hx), right=(ax > hx)); m.run(10); m.set_stick()
    f0 = m.frame                  # odsud se nahrava zvuk (out_eat.wav / out_eat.png)
    while snake(m)[0][0] != ax:
        m.run(10)
        assert not var(m, 'Dead'), 'cestou k jablku had zemrel (vodorovne)'
    m.run(2)
    check(var(m, 'Score') == 1 and var(m, 'SnakeLen') == 4, 'hra: jablko sezrano, delka 4')
    check('SCORE 001' in screen(m)[0] and 'LENGTH 004' in screen(m)[0], 'hra: stav po jablku')
    segs = snake(m)
    glyphs = [cell(m, x, y) for x, y in segs]
    check(glyphs[0] in range(GL+6, GL+10) and glyphs[-1] in range(GL+10, GL+14)
          and all(g in range(GL, GL+6) for g in glyphs[1:-1]), 'hra: po sezrani jedna hlava, tela, jeden ocas')
    check(len(apples(m)) == 1 and sprite_ok(m, *apples(m)[0]), 'hra: nove jablko i se spritem')
    check(sum(m.mem[P0DATA:P0DATA+512]) == 0x60*2 + 0xF0*4 + 0x20 + 0xE0, 'hra: stary sprite jablka zmizel')
    # zvuk: syntetizovany POKEY (audio.py) - useky kanalu 1 od f0
    m.audio_wav(os.path.join(HERE, 'out_eat.wav'), f0)
    m.audio_png(os.path.join(HERE, 'out_eat.png'), f0, title='snake: sezrani jablka')
    eat = [d for d in m.audio_describe(f0) if d['ch'] == 1][:4]   # dal muze byt uz game over
    check([d['kind'] for d in eat] == ['tone'] * 4, 'hra: zvuk pri sezrani = ciste tony')
    check([d['len'] for d in eat] == [2, 2, 1, 1] and [d['vol'] for d in eat] == [8, 8, 6, 4], 'hra: blip 2+2+1+1 snimku, dozniva 6 -> 4')
    hz = [d['hz'] for d in eat]
    check(hz[0] < hz[1] < hz[2] == hz[3] and 300 < hz[0] and hz[3] < 700, 'hra: blip stoupa (~330 -> ~650 Hz)')
    m.screenshot(os.path.join(HERE, 'out_game.png'))

    # naraz do zdi -> GAME OVER
    m.set_stick(up=True); m.run(10); m.set_stick()
    for _ in range(30):
        m.run(10)
        if var(m, 'Dead'):
            break
    check(var(m, 'Dead') == 1, 'hra: naraz do zdi = smrt')
    m.run(3)
    check('GAME OVER' in screen(m)[11], 'game over: text')
    m.screenshot(os.path.join(HERE, 'out_over.png'))
    m.tap(fire=True); m.run(3)
    check('START GAME' in screen(m)[10], 'game over: FIRE vraci do menu')

    # pauza: P zastavi hada, P znovu pokracuje, START take, ESC v pauze = menu
    m.tap(fire=True); m.run(3)
    check('SCORE 000' in screen(m)[0], 'hra 2: spustena')
    m.tap(key=0x0A); m.run(1)
    pos = snake(m)[0]
    check('PAUSED' in screen(m)[0] and cell(m, 16, 0) == 0x80, 'pauza: napis PAUSED inverzne')
    m.run(30)
    check(snake(m)[0] == pos, 'pauza: had stoji')
    m.tap(key=0x0A); m.run(1)
    check('PAUSED' not in screen(m)[0], 'pauza: P znovu = pokracovani, napis smazan')
    m.run(30)
    check(snake(m)[0] != pos, 'pauza: had zase jede')
    m.tap(consol='start'); m.run(1)
    check('PAUSED' in screen(m)[0], 'pauza: START pauzu zapne')
    m.tap(key=KEY_ESC); m.run(3)
    check('START GAME' in screen(m)[10], 'pauza: ESC v pauze vraci do menu')

    # ESC ve hre vraci do menu
    m.tap(fire=True); m.run(3)
    check('SCORE 000' in screen(m)[0], 'hra 3: spustena')
    m.tap(key=KEY_ESC); m.run(3)
    check('START GAME' in screen(m)[10], 'hra 3: ESC vraci do menu')
    # deterministicky: jablko primo pred hlavu, kontrola glyfu hned po sezrani
    # (chyba 'dva ocasy' byla videt jen do dalsiho kroku)
    m = machine(seed=3)
    m.run(5); m.tap(fire=True); m.run(3)
    ax, ay = apples(m)[0]
    m.mem[0x3000 + ay*40 + ax] = 0
    m.mem[0x3000 + 12*40 + 22] = APPLE
    for _ in range(40):
        m.run(1)
        if var(m, 'Score'):
            break
    segs = snake(m)
    glyphs = [cell(m, x, y) for x, y in segs]
    check(segs == [(22, 12), (21, 12), (20, 12), (19, 12)] and glyphs == [GL+7, GL+0, GL+0, GL+11],
          'hra: hned po sezrani je byvaly ocas prekresleny na telo (ne dva ocasy)')
    print('ALL OK, frames', m.frame)


if __name__ == '__main__':
    main()
