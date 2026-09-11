#!/usr/bin/env python3
"""Headless mini-emulator pro vyvoj tetris.xex (6502 + ANTIC/GTIA/POKEY jen v rozsahu,
ktery hra pouziva). Slouzi k automatickemu testovani a k renderu obrazovky do PNG.

Model snimku:
  1. kus hlavniho kodu (N instrukci),
  2. "zobrazeni": projde display list radek po radku; na instrukci s DLI bitem
     spusti DLI handler (VDSLST). Zapis do WSYNC uvnitr handleru vykresli aktualni
     scanline a posune se na dalsi (takze duha titulku funguje jako na realu),
  3. VBI pres VVBLKI (OS pushne A,X,Y; skok na XITVBV $E462 = PLA Y,X,A + RTI).
OS neni - hra ho nepouziva (vlastni DL, VBI, cteni HW registru).

Pouziti:  python emu.py [frames] [out.png]
Skriptovani: viz tridu Machine (set_stick, press_key, consol, ...) a test_tetris.py.
"""
import os, sys, random, re
from cpu6502 import CPU

HERE = os.path.dirname(os.path.abspath(__file__))
XEX = os.path.join(HERE, '..', 'tetris.xex')
XITVBV = 0xE462


def load_font():
    from PIL import Image
    im = Image.open(os.path.join(HERE, 'atari-rom-font.png')).convert('L')
    data = bytearray(1024)
    for ch in range(128):
        ox, oy = (ch % 32) * 8, (ch // 32) * 8
        for r in range(8):
            b = 0
            for bit in range(8):
                if im.getpixel((ox + bit, oy + r)) >= 128:
                    b |= 0x80 >> bit
            data[ch * 8 + r] = b
    return bytes(data)


def load_pal():
    p = open(os.path.join(HERE, 'DefaultPAL.pal'), 'rb').read()
    return [(p[i*3], p[i*3+1], p[i*3+2]) for i in range(256)]


class Machine:
    def __init__(self, xex=XEX, seed=1):
        self.mem = bytearray(0x10000)
        self.rng = random.Random(seed)
        self.frame = 0
        self.pokey_log = []
        self.hw = {}                     # posledni zapis do HW registru
        self.consol = 7                  # bit0 START, bit1 SELECT, bit2 OPTION (0 = stisk)
        self.porta = 0xFF
        self.trig0 = 1
        self.kbcode = 0xFF
        self.key_down = False
        self.font = load_font()
        self.mem[0xE000:0xE400] = self.font
        self.cpu = CPU(self)
        self.run_addr = self.load_xex(xex)
        self.cpu.pc = self.run_addr
        self.cpu.sp = 0xFF
        self.in_dli = False
        self.wsync_cb = None
        self.instr_per_frame = 10000     # ~ 30000 cyklu / 3

    # ---- XEX loader ----
    def load_xex(self, path):
        d = open(path, 'rb').read()
        i = 0
        run = None
        while i < len(d):
            if d[i] == 0xFF and d[i+1] == 0xFF:
                i += 2
            start = d[i] | (d[i+1] << 8); end = d[i+2] | (d[i+3] << 8); i += 4
            n = end - start + 1
            self.mem[start:start+n] = d[i:i+n]
            i += n
            if start <= 0x2E0 <= end:
                run = self.mem[0x2E0] | (self.mem[0x2E1] << 8)
        return run

    # ---- HW ----
    def hw_read(self, a):
        if a == 0xD20A: return self.rng.randint(0, 255)
        if a == 0xD01F: return self.consol
        if a == 0xD010: return self.trig0
        if 0xD011 <= a <= 0xD013: return 1
        if a == 0xD300: return self.porta
        if a == 0xD209: return self.kbcode
        if a == 0xD20F: return 0xFF & ~(0x04 if self.key_down else 0)
        if a == 0xD40B: return self.rng.randint(0, 155)
        return self.mem[a]

    def hw_write(self, a, v):
        if 0xD200 <= a <= 0xD208:
            self.pokey_log.append((self.frame, a & 0xF, v))
        if a == 0xD40A and self.wsync_cb:      # WSYNC v DLI
            self.wsync_cb()
        self.hw[a] = v
        self.mem[a] = v

    def rd(self, a):
        return self.hw_read(a) if 0xD000 <= a <= 0xD7FF else self.mem[a]

    def wr(self, a, v):
        if 0xD000 <= a <= 0xD7FF: self.hw_write(a, v)
        else: self.mem[a] = v

    def reg(self, a, default=0):
        return self.hw.get(a, default)

    # ---- CPU ----
    def run_slice(self, n):
        c = self.cpu
        for _ in range(n):
            if c.pc >= 0xC000:
                raise RuntimeError(f'skok do ROM {c.pc:04X} mimo preruseni')
            c.step()

    def run_interrupt(self, vector, os_pushes_axy):
        c = self.cpu
        sp_before = c.sp
        c.push16(c.pc)
        c.push(c.flags())
        if os_pushes_axy:
            c.push(c.a); c.push(c.x); c.push(c.y)
        c.pc = self.mem[vector] | (self.mem[vector+1] << 8)
        for _ in range(200000):
            if c.sp == sp_before:
                return
            if c.pc == XITVBV:
                c.y = c.pop(); c.x = c.pop(); c.a = c.pop()
                c.setflags(c.pop()); c.pc = c.pop16()
                continue
            if c.pc >= 0xC000:
                raise RuntimeError(f'preruseni skocilo do ROM {c.pc:04X}')
            c.step()
        raise RuntimeError('preruseni se nevratilo')

    # ---- display list -> seznam scanlines ----
    def scanlines(self):
        dl = self.reg(0xD402) | (self.reg(0xD403) << 8)
        lines = []
        addr = None
        pc = dl
        for _ in range(300):
            op = self.mem[pc]; pc += 1
            mode = op & 0x0F
            dli = bool(op & 0x80)
            if mode == 0:
                n = ((op >> 4) & 7) + 1
                for i in range(n):
                    lines.append(dict(mode=0, addr=0, sub=i, dli=dli and i == n-1))
                continue
            if mode == 1:
                if op & 0x40:
                    break                     # JVB
                pc = self.mem[pc] | (self.mem[pc+1] << 8)
                continue
            if op & 0x40:
                addr = self.mem[pc] | (self.mem[pc+1] << 8); pc += 2
            h = {2: 8, 4: 8, 6: 8, 7: 16, 0xF: 1}.get(mode, 8)
            w = {2: 40, 4: 40, 6: 20, 7: 20, 0xF: 40}.get(mode, 40)
            for i in range(h):
                lines.append(dict(mode=mode, addr=addr, sub=i, dli=dli and i == h-1))
            addr = (addr & 0xF000) | ((addr + w) & 0x0FFF)
        return lines

    # ---- render jedne scanline do bufferu (320 px) ----
    def render_line(self, ln, out):
        pal = self.pal
        bk = pal[self.reg(0xD01A)]
        pf = [self.reg(0xD016 + i) for i in range(4)]
        pm = [self.reg(0xD012 + i) for i in range(4)]
        mode, addr, sub = ln['mode'], ln['addr'], ln['sub']
        if mode == 0:
            out[:] = [bk] * 320
            return
        chbase = self.reg(0xD409, 0xE0) << 8
        if mode == 2:
            bg = pal[pf[2]]
            fg = pal[(pf[2] & 0xF0) | (pf[1] & 0x0F)]
            lit = self.cur_lit
            for ci in range(40):
                ch = self.mem[addr + ci]
                b = self.mem[chbase + (ch & 0x7F) * 8 + sub]
                if ch & 0x80: b ^= 0xFF
                for bit in range(8):
                    if b & (0x80 >> bit):
                        out[ci*8 + bit] = fg; lit[ci*8 + bit] = True
                    else:
                        out[ci*8 + bit] = bg
        elif mode == 4:
            for ci in range(40):
                ch = self.mem[addr + ci]
                b = self.mem[chbase + (ch & 0x7F) * 8 + sub]
                for p2 in range(4):
                    v = (b >> (6 - p2*2)) & 3
                    if v == 0: c = bk
                    elif v == 3: c = pal[pf[3]] if ch & 0x80 else pal[pf[2]]
                    else: c = pal[pf[v-1]]
                    x0 = ci*8 + p2*2
                    out[x0] = c; out[x0+1] = c
        elif mode in (6, 7):
            row = sub if mode == 6 else sub // 2
            for ci in range(20):
                ch = self.mem[addr + ci]
                b = self.mem[chbase + (ch & 0x3F) * 8 + row]
                col = pal[pf[ch >> 6]]
                for bit in range(8):
                    c = col if b & (0x80 >> bit) else bk
                    out[ci*16 + bit*2] = c; out[ci*16 + bit*2 + 1] = c
        elif mode == 0xF:
            prior = self.reg(0xD01B)
            if prior & 0xC0 == 0x80:          # GTIA mode 10 (9 barev)
                for bx in range(40):
                    b = self.mem[addr + bx]
                    for half in range(2):
                        v = (b >> (4 - half*4)) & 0xF
                        if v < 4: c = pal[pm[v]]
                        elif v < 8: c = pal[pf[v-4]]
                        elif v in (9, 10, 11): c = pal[pf[v-9]]
                        else: c = bk
                        x0 = bx*8 + half*4
                        out[x0:x0+4] = [c]*4
            else:
                bg = pal[pf[2]]
                fg = pal[(pf[2] & 0xF0) | (pf[1] & 0x0F)]
                for bx in range(40):
                    b = self.mem[addr + bx]
                    for bit in range(8):
                        out[bx*8 + bit] = fg if b & (0x80 >> bit) else bg

    # ---- jeden snimek ----
    def step_frame(self, render=False):
        self.run_slice(self.instr_per_frame)
        nmien = self.mem[0xD40E]
        lines = self.scanlines() if (self.mem[0xD402] | self.mem[0xD403]) else []
        if render:
            self.pal = load_pal()
            self.img_lines = []
            self.lit_lines = []
            self.pf1_lines = []
            self.pm_lines = []
        i = 0
        n = len(lines)
        while i < n:
            ln = lines[i]
            if ln['dli'] and nmien & 0x80:
                # DLI: fires na zacatku posledni scanline instrukce
                state = {'i': i}
                def on_wsync():
                    if state['i'] < n:
                        if render:
                            self.cur_lit = [False]*320
                            buf = [None]*320; self.render_line(lines[state['i']], buf)
                            self.img_lines.append(buf); self.lit_lines.append(self.cur_lit); self.pf1_lines.append(self.reg(0xD017)); self.pm_lines.append([self.reg(0xD012+i) for i in range(4)])
                        state['i'] += 1
                self.wsync_cb = on_wsync
                self.run_interrupt(0x0200, False)
                self.wsync_cb = None
                i = state['i']
                if i >= n:
                    break
                ln = lines[i]
            if render:
                self.cur_lit = [False]*320
                buf = [None]*320; self.render_line(ln, buf)
                self.img_lines.append(buf); self.lit_lines.append(self.cur_lit); self.pf1_lines.append(self.reg(0xD017)); self.pm_lines.append([self.reg(0xD012+i) for i in range(4)])
            i += 1
        if nmien & 0x40:
            self.run_interrupt(0x0222, True)
        self.frame += 1

    def run(self, frames, render_last=False):
        for f in range(frames):
            self.step_frame(render=(render_last and f == frames-1))

    def screenshot(self, path, scale=2):
        from PIL import Image
        self.step_frame(render=True)
        h = max(len(self.img_lines), 1)
        img = Image.new('RGB', (320, h))
        px = img.load()
        for y, row in enumerate(self.img_lines):
            for x in range(320):
                px[x, y] = row[x] or (0, 0, 0)
        # PMG overlay (jen playeri, single-line, PRIOR ignorovan: player navrchu)
        dmactl = self.reg(0xD400)
        h = len(self.img_lines)
        if dmactl & 0x08 and self.reg(0xD01D) & 2:
            pmbase = self.reg(0xD407) << 8
            single = bool(dmactl & 0x10)
            for pnum in range(4):
                hpos = self.reg(0xD000 + pnum)
                if not hpos: continue
                wmul = {0: 1, 1: 2, 3: 4}.get(self.reg(0xD008 + pnum) & 3, 1)
                base = pmbase + (0x400 if single else 0x200) + pnum * (0x100 if single else 0x80)
                for y in range(h):
                    scan = y + 8
                    idx = scan if single else scan // 2
                    b = self.mem[base + idx]
                    if not b: continue
                    creg = self.pm_lines[y][pnum]
                    col = self.pal[creg]
                    for bit in range(8):
                        if b & (0x80 >> bit):
                            for k in range(2*wmul):
                                x = (hpos - 48)*2 + bit*2*wmul + k
                                if 0 <= x < 320:
                                    # hi-res trik: rozsviceny pixel textu dostane odstin playera + jas PF1
                                    if self.lit_lines[y][x]:
                                        px[x, y] = self.pal[(creg & 0xF0) | (self.pf1_lines[y] & 0x0F)]
                                    else:
                                        px[x, y] = col
        img = img.resize((320*scale, h*scale), Image.NEAREST)
        img.save(path)
        return path

    # ---- zvuk (viz audio.py) ----
    def audio_samples(self, start_frame=0, rate=44100):
        """Syntetizovany zvuk od snimku start_frame do ted (numpy float32 mono)."""
        import audio
        log = [(f - start_frame, a, v) for f, a, v in self.pokey_log if f >= start_frame]
        # stav registru pred start_frame prenest jako zapisy ve snimku -1
        pre = {}
        for f, a, v in self.pokey_log:
            if f < start_frame: pre[a] = v
        log = [(-1, a, v) for a, v in pre.items()] + log
        return audio.render(log, self.frame - start_frame, rate)

    def audio_wav(self, path, start_frame=0, rate=44100, trim=True):
        """Ulozi zvuk od snimku start_frame do WAV (pro poslech clovekem); trim = bez ticha okolo."""
        import audio
        s = self.audio_samples(start_frame, rate)
        if trim: s, _ = audio.trim(s, rate)
        return audio.save_wav(s, path, rate)

    def audio_png(self, path, start_frame=0, rate=44100, title=None, trim=True):
        """Ulozi spektrogram + obalku hlasitosti do PNG (pro 'poslech' AI); osa x = snimky od start_frame."""
        import audio
        s = self.audio_samples(start_frame, rate)
        f0 = 0.0
        if trim: s, f0 = audio.trim(s, rate)
        return audio.spectrogram(s, path, rate, title or os.path.basename(path), f0)

    def audio_describe(self, start_frame=0):
        """Useky zvuku od snimku start_frame: list dict(ch, frame, len, ms, audf, audc, hz, vol, kind)."""
        import audio
        log = [(f - start_frame, a, v) for f, a, v in self.pokey_log if f >= start_frame]
        return audio.describe(log, self.frame - start_frame)

    def audio_text(self, start_frame=0):
        import audio
        return audio.format_describe(self.audio_describe(start_frame))

    # ---- vstupy ----
    def set_stick(self, up=False, down=False, left=False, right=False):
        v = 0xFF
        if up: v &= ~1
        if down: v &= ~2
        if left: v &= ~4
        if right: v &= ~8
        self.porta = v & 0xFF

    def set_fire(self, pressed):
        self.trig0 = 0 if pressed else 1

    def set_key(self, code=None):
        """code = KBCODE (None = nic nedrzeno)"""
        if code is None:
            self.key_down = False
        else:
            self.kbcode = code; self.key_down = True

    def set_consol(self, start=False, select=False, option=False):
        v = 7
        if start: v &= ~1
        if select: v &= ~2
        if option: v &= ~4
        self.consol = v

    def tap(self, frames_down=3, frames_up=3, **what):
        """Kratke stisknuti (klavesa/joystick/console) a uvolneni."""
        if 'key' in what: self.set_key(what['key'])
        if 'fire' in what: self.set_fire(True)
        if 'stick' in what: self.set_stick(**{what['stick']: True})
        if 'consol' in what: self.set_consol(**{what['consol']: True})
        self.run(frames_down)
        self.set_key(None); self.set_fire(False); self.set_stick(); self.set_consol()
        self.run(frames_up)

    # ---- pomucky pro testy ----
    def label(self, name):
        return self.labels[name.upper()]

    def load_labels(self, lab=os.path.join(HERE, '..', 'tetris.lab')):
        """Nacte tabulku labelu z mads -t: (format: bank<TAB>addr<TAB>NAME). Klice jsou UPPERCASE."""
        self.labels = {}
        for line in open(lab, encoding='utf-8', errors='replace'):
            parts = line.strip().split('	')
            if len(parts) == 3 and re.fullmatch(r'[0-9A-F]{4}', parts[1]):
                self.labels[parts[2].upper()] = int(parts[1], 16)
        return self.labels

    def board(self):
        b = self.label('Board')
        return [list(self.mem[b + y*10: b + y*10 + 10]) for y in range(24)]

    def board_str(self):
        rows = []
        for r in self.board():
            rows.append(''.join('.' if v == 8 else ('#' if v == 7 else str(v)) for v in r))
        return '\n'.join(rows)

    def text_rows(self, base, rows, width=40):
        out = []
        for r in range(rows):
            s = ''
            for c in range(width):
                v = self.mem[base + r*width + c] & 0x7F
                s += chr(v + 32) if v < 64 else (chr(v) if 64 <= v < 96 else '?')
            out.append(s)
        return out


if __name__ == '__main__':
    frames = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, 'out.png')
    m = Machine()
    m.run(frames)
    m.screenshot(out)
    print('frames', m.frame, 'pc', hex(m.cpu.pc), 'png', out)
