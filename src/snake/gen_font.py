#!/usr/bin/env python3
"""Generuje snake_font.inc - vlastni glyfy hada pro snake.asm (interni kody $60-$6E).

Telo je 6 px silne s 1px okrajem, takze sousedni rovnobezne segmenty
(napr. pismeno U) nesplyvaji. Rotace/zrcadleni se dopocitavaji z jednoho vzoru.
Spusteni: python gen_font.py   (prepise snake_font.inc)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# vzory jako 8 radku po 8 znacich ('#' = pixel)
BODY_H = """
........
########
########
########
########
########
########
........"""

# roh spojujici LEVOU a DOLNI stranu (had prijel zleva a zatoci dolu, nebo naopak)
CORNER_LD = """
........
.######.
#######.
#######.
#######.
#######.
#######.
.######."""

# hlava smerem doprava (telo navazuje zleva), dve oci
HEAD_R = """
........
######..
###.###.
########
########
###.###.
######..
........"""

# ocas, jehoz dalsi segment je vpravo (spicka miri doleva)
TAIL_R = """
........
.....###
...#####
.#######
.#######
...#####
.....###
........"""

APPLE = """
...#....
..##....
.######.
########
########
########
.######.
..####.."""


def grid(s):
    return [list(r) for r in s.strip('\n').split('\n')]


def rot90(g):        # otoceni o 90 stupnu po smeru hodin
    return [[g[7 - x][y] for x in range(8)] for y in range(8)]


def flip_h(g):
    return [r[::-1] for r in g]


def flip_v(g):
    return g[::-1]


def rows(g):
    return [int(''.join('1' if c == '#' else '0' for c in r), 2) for r in g]


body_h = grid(BODY_H)
body_v = rot90(body_h)
c_ld = grid(CORNER_LD)
c_lu = flip_v(c_ld)
c_rd = flip_h(c_ld)
c_ru = flip_v(c_rd)
head_r = grid(HEAD_R)
head_r_blink = [[('#' if c == '.' and 0 < x < 7 else c) for x, c in enumerate(r)] for r in head_r]
head_r_blink = [r if i in (2, 5) else head_r[i] for i, r in enumerate(head_r_blink)]   # jen radky s ocima
head_l = flip_h(head_r)
head_d = rot90(head_r)
head_u = flip_v(head_d)
tail_r = grid(TAIL_R)
tail_l = flip_h(tail_r)
tail_d = rot90(tail_r)
tail_u = flip_v(tail_d)

# poradi = interni kody od $60; smery v poradi UP, RIGHT, DOWN, LEFT jako v asm
GLYPHS = [
    ('BODY_H', body_h), ('BODY_V', body_v),
    ('CORNER_LU', c_lu), ('CORNER_LD', c_ld), ('CORNER_RU', c_ru), ('CORNER_RD', c_rd),
    ('HEAD_U', head_u), ('HEAD_R', head_r), ('HEAD_D', head_d), ('HEAD_L', head_l),
    ('TAIL_U', tail_u), ('TAIL_R', tail_r), ('TAIL_D', tail_d), ('TAIL_L', tail_l),
    ('APPLE', grid(APPLE)),
    ('HEAD_R_BLINK', head_r_blink),   # mrknuti (About)
]

out = ['; Generovano gen_font.py - NEEDITOVAT rucne. Glyfy hada, interni kody od $60.',
       'SnakeGlyphs']
for i, (name, g) in enumerate(GLYPHS):
    out.append('        .byte ' + ','.join('$%02X' % b for b in rows(g)) + '   ; $%02X %s' % (0x60 + i, name))
out.append('SNAKE_GLYPHS = %d' % len(GLYPHS))
open(os.path.join(HERE, 'snake_font.inc'), 'w', encoding='ascii').write('\n'.join(out) + '\n')
print('snake_font.inc:', len(GLYPHS), 'glyfu')
