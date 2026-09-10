#!/usr/bin/env python3
"""Automaticky test snake.xex v headless harnessu ../tetris/tools/emu.py.

Spusteni:  python test_snake.py          (predpoklada prelozeny snake.xex + snake.lab)
Vystup:    out_menu.png, out_game.png, out_over.png v tomto adresari.
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


def check(cond, msg):
    if not cond:
        raise SystemExit('FAIL: ' + msg)
    print('ok  ', msg)


def main():
    m = machine()
    m.run(5)
    rows = screen(m)
    check('S N A K E' in rows[4], 'menu: titulek')
    check('START GAME' in rows[10] and 'ABOUT' in rows[12], 'menu: polozky')
    check(m.mem[0x3000 + 10*40 + 15] & 0x80, 'menu: START GAME je inverzni (vybrany)')
    m.screenshot(os.path.join(HERE, 'out_menu.png'))

    # dolu -> ABOUT, RETURN -> obrazovka ABOUT, ESC -> zpet
    m.tap(stick='down'); m.run(2)
    check(m.mem[0x3000 + 12*40 + 17] & 0x80, 'menu: sipka dolu vybere ABOUT')
    m.tap(key=KEY_RETURN); m.run(3)
    check('SNAKE FOR ATARI XL/XE' in screen(m)[6], 'about: zobrazen')
    m.tap(key=KEY_ESC); m.run(3)
    check('START GAME' in screen(m)[10], 'about: ESC vraci do menu')

    # nahoru -> START GAME, FIRE -> hra
    m.tap(stick='up'); m.run(2)
    m.tap(fire=True); m.run(3)
    rows = screen(m)
    check('SCORE 000' in rows[0] and 'LENGTH 003' in rows[0], 'hra: stavovy radek')
    check(snake(m) == [(20, 12), (19, 12), (18, 12)], 'hra: vychozi had')
    check(rows[12][18:21] == 'OO@', 'hra: had vykreslen (OO@)')
    check(sum(r.count('*') for r in rows) == 1, 'hra: prave jedno jablko')

    # pohyb doprava: po 10 snimcich krok
    m.run(12)
    check(snake(m)[0] == (21, 12), 'hra: had udelal krok doprava')
    check(screen(m)[12][17] == ' ', 'hra: ocas smazan')

    # otoceni do sebe (vlevo pri pohybu vpravo) se ignoruje
    m.set_stick(left=True); m.run(10); m.set_stick()
    check(var(m, 'SnakeDir') == 1, 'hra: otoceni o 180 stupnu ignorovano')

    # nahoru, pak cesta k jablku: dojdi na sloupec jablka a pak na jeho radek
    def find_apple():
        for y, r in enumerate(screen(m)):
            x = r.find('*')
            if x >= 0:
                return x, y
    ax, ay = find_apple()
    hx, hy = snake(m)[0]
    # nejdriv svisle na radek jablka (pokud je jiny), pak vodorovne
    if ay != hy:
        m.set_stick(up=(ay < hy), down=(ay > hy)); m.run(10); m.set_stick()
        while snake(m)[0][1] != ay:
            m.run(10)
            assert not var(m, 'Dead'), 'cestou k jablku had zemrel'
    m.set_stick(left=(ax < hx), right=(ax > hx)); m.run(10); m.set_stick()
    while snake(m)[0][0] != ax:
        m.run(10)
        assert not var(m, 'Dead'), 'cestou k jablku had zemrel (vodorovne)'
    m.run(2)
    check(var(m, 'Score') == 1 and var(m, 'SnakeLen') == 4, 'hra: jablko sezrano, delka 4')
    check('SCORE 001' in screen(m)[0] and 'LENGTH 004' in screen(m)[0], 'hra: stav po jablku')
    check(sum(r.count('*') for r in screen(m)) == 1, 'hra: nove jablko')
    check(any(a == 1 and v for _, a, v in m.pokey_log), 'hra: zvuk pri sezrani')
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

    # ESC ve hre vraci do menu
    m.tap(fire=True); m.run(3)
    check('SCORE 000' in screen(m)[0], 'hra 2: spustena')
    m.tap(key=KEY_ESC); m.run(3)
    check('START GAME' in screen(m)[10], 'hra 2: ESC vraci do menu')
    print('ALL OK, frames', m.frame)


if __name__ == '__main__':
    main()
