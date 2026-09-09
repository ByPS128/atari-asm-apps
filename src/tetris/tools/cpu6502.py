# 6502 CPU core (prevzato z mini-emulatoru ve skillu atari-to-web-emulator)

class CPU:
    def __init__(self, machine):
        self.m = machine
        self.a = self.x = self.y = 0
        self.sp = 0xFF
        self.pc = 0
        self.n = self.v = self.z = self.c = False
        self.i = True; self.d = False

    def push(self, v):
        self.m.mem[0x100 + self.sp] = v & 0xFF; self.sp = (self.sp - 1) & 0xFF
    def pop(self):
        self.sp = (self.sp + 1) & 0xFF; return self.m.mem[0x100 + self.sp]
    def push16(self, v): self.push((v >> 8) & 0xFF); self.push(v & 0xFF)
    def pop16(self): lo = self.pop(); return lo | (self.pop() << 8)

    def flags(self):
        return ((0x80 if self.n else 0) | (0x40 if self.v else 0) | 0x20 | 0x10 |
                (0x08 if self.d else 0) | (0x04 if self.i else 0) |
                (0x02 if self.z else 0) | (0x01 if self.c else 0))
    def setflags(self, p):
        self.n = bool(p & 0x80); self.v = bool(p & 0x40); self.d = bool(p & 0x08)
        self.i = bool(p & 0x04); self.z = bool(p & 0x02); self.c = bool(p & 0x01)

    def nz(self, v):
        v &= 0xFF; self.n = v >= 0x80; self.z = v == 0; return v

    def imm(self):  v = self.pc; self.pc += 1; return v
    def zp(self):   a = self.m.mem[self.pc]; self.pc += 1; return a
    def zpx(self):  a = (self.m.mem[self.pc] + self.x) & 0xFF; self.pc += 1; return a
    def zpy(self):  a = (self.m.mem[self.pc] + self.y) & 0xFF; self.pc += 1; return a
    def abs(self):
        a = self.m.mem[self.pc] | (self.m.mem[self.pc+1] << 8); self.pc += 2; return a
    def absx(self): return (self.abs() + self.x) & 0xFFFF
    def absy(self): return (self.abs() + self.y) & 0xFFFF
    def indx(self):
        z = (self.m.mem[self.pc] + self.x) & 0xFF; self.pc += 1
        return self.m.mem[z] | (self.m.mem[(z+1) & 0xFF] << 8)
    def indy(self):
        z = self.m.mem[self.pc]; self.pc += 1
        return ((self.m.mem[z] | (self.m.mem[(z+1) & 0xFF] << 8)) + self.y) & 0xFFFF

    def adc(self, v):
        if self.d:
            lo = (self.a & 0x0F) + (v & 0x0F) + (1 if self.c else 0)
            hi = (self.a >> 4) + (v >> 4)
            if lo > 9: lo -= 10; hi += 1
            self.z = ((self.a + v + (1 if self.c else 0)) & 0xFF) == 0
            if hi > 9: hi -= 10; self.c = True
            else: self.c = False
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            self.n = self.a >= 0x80
        else:
            r = self.a + v + (1 if self.c else 0)
            self.v = (~(self.a ^ v) & (self.a ^ r) & 0x80) != 0
            self.c = r > 0xFF
            self.a = self.nz(r)

    def sbc(self, v):
        if self.d:
            b = 0 if self.c else 1
            r = self.a - v - b
            lo = (self.a & 0x0F) - (v & 0x0F) - b
            hi = (self.a >> 4) - (v >> 4)
            if lo < 0: lo += 10; hi -= 1
            if hi < 0: hi += 10; self.c = False
            else: self.c = True
            self.z = (r & 0xFF) == 0
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            self.n = self.a >= 0x80
        else:
            self.adc((v ^ 0xFF) & 0xFF)

    def cmp(self, r, v):
        self.c = r >= v
        self.nz((r - v) & 0xFF)

    def branch(self, cond):
        off = self.m.mem[self.pc]; self.pc += 1
        if cond:
            self.pc = (self.pc + (off if off < 128 else off - 256)) & 0xFFFF

    def step(self):
        m = self.m; mem = m.mem; rd = m.rd; wr = m.wr
        op = mem[self.pc]; self.pc = (self.pc + 1) & 0xFFFF
        s = self
        if   op == 0xA9: s.a = s.nz(mem[s.imm()])
        elif op == 0xA5: s.a = s.nz(rd(s.zp()))
        elif op == 0xB5: s.a = s.nz(rd(s.zpx()))
        elif op == 0xAD: s.a = s.nz(rd(s.abs()))
        elif op == 0xBD: s.a = s.nz(rd(s.absx()))
        elif op == 0xB9: s.a = s.nz(rd(s.absy()))
        elif op == 0xA1: s.a = s.nz(rd(s.indx()))
        elif op == 0xB1: s.a = s.nz(rd(s.indy()))
        elif op == 0xA2: s.x = s.nz(mem[s.imm()])
        elif op == 0xA6: s.x = s.nz(rd(s.zp()))
        elif op == 0xB6: s.x = s.nz(rd(s.zpy()))
        elif op == 0xAE: s.x = s.nz(rd(s.abs()))
        elif op == 0xBE: s.x = s.nz(rd(s.absy()))
        elif op == 0xA0: s.y = s.nz(mem[s.imm()])
        elif op == 0xA4: s.y = s.nz(rd(s.zp()))
        elif op == 0xB4: s.y = s.nz(rd(s.zpx()))
        elif op == 0xAC: s.y = s.nz(rd(s.abs()))
        elif op == 0xBC: s.y = s.nz(rd(s.absx()))
        elif op == 0x85: wr(s.zp(), s.a)
        elif op == 0x95: wr(s.zpx(), s.a)
        elif op == 0x8D: wr(s.abs(), s.a)
        elif op == 0x9D: wr(s.absx(), s.a)
        elif op == 0x99: wr(s.absy(), s.a)
        elif op == 0x81: wr(s.indx(), s.a)
        elif op == 0x91: wr(s.indy(), s.a)
        elif op == 0x86: wr(s.zp(), s.x)
        elif op == 0x96: wr(s.zpy(), s.x)
        elif op == 0x8E: wr(s.abs(), s.x)
        elif op == 0x84: wr(s.zp(), s.y)
        elif op == 0x94: wr(s.zpx(), s.y)
        elif op == 0x8C: wr(s.abs(), s.y)
        elif op == 0xAA: s.x = s.nz(s.a)
        elif op == 0xA8: s.y = s.nz(s.a)
        elif op == 0x8A: s.a = s.nz(s.x)
        elif op == 0x98: s.a = s.nz(s.y)
        elif op == 0x9A: s.sp = s.x
        elif op == 0xBA: s.x = s.nz(s.sp)
        elif op == 0x69: s.adc(mem[s.imm()])
        elif op == 0x65: s.adc(rd(s.zp()))
        elif op == 0x75: s.adc(rd(s.zpx()))
        elif op == 0x6D: s.adc(rd(s.abs()))
        elif op == 0x7D: s.adc(rd(s.absx()))
        elif op == 0x79: s.adc(rd(s.absy()))
        elif op == 0x61: s.adc(rd(s.indx()))
        elif op == 0x71: s.adc(rd(s.indy()))
        elif op == 0xE9: s.sbc(mem[s.imm()])
        elif op == 0xE5: s.sbc(rd(s.zp()))
        elif op == 0xF5: s.sbc(rd(s.zpx()))
        elif op == 0xED: s.sbc(rd(s.abs()))
        elif op == 0xFD: s.sbc(rd(s.absx()))
        elif op == 0xF9: s.sbc(rd(s.absy()))
        elif op == 0xE1: s.sbc(rd(s.indx()))
        elif op == 0xF1: s.sbc(rd(s.indy()))
        elif op == 0x29: s.a = s.nz(s.a & mem[s.imm()])
        elif op == 0x25: s.a = s.nz(s.a & rd(s.zp()))
        elif op == 0x35: s.a = s.nz(s.a & rd(s.zpx()))
        elif op == 0x2D: s.a = s.nz(s.a & rd(s.abs()))
        elif op == 0x3D: s.a = s.nz(s.a & rd(s.absx()))
        elif op == 0x39: s.a = s.nz(s.a & rd(s.absy()))
        elif op == 0x21: s.a = s.nz(s.a & rd(s.indx()))
        elif op == 0x31: s.a = s.nz(s.a & rd(s.indy()))
        elif op == 0x09: s.a = s.nz(s.a | mem[s.imm()])
        elif op == 0x05: s.a = s.nz(s.a | rd(s.zp()))
        elif op == 0x15: s.a = s.nz(s.a | rd(s.zpx()))
        elif op == 0x0D: s.a = s.nz(s.a | rd(s.abs()))
        elif op == 0x1D: s.a = s.nz(s.a | rd(s.absx()))
        elif op == 0x19: s.a = s.nz(s.a | rd(s.absy()))
        elif op == 0x01: s.a = s.nz(s.a | rd(s.indx()))
        elif op == 0x11: s.a = s.nz(s.a | rd(s.indy()))
        elif op == 0x49: s.a = s.nz(s.a ^ mem[s.imm()])
        elif op == 0x45: s.a = s.nz(s.a ^ rd(s.zp()))
        elif op == 0x55: s.a = s.nz(s.a ^ rd(s.zpx()))
        elif op == 0x4D: s.a = s.nz(s.a ^ rd(s.abs()))
        elif op == 0x5D: s.a = s.nz(s.a ^ rd(s.absx()))
        elif op == 0x59: s.a = s.nz(s.a ^ rd(s.absy()))
        elif op == 0x41: s.a = s.nz(s.a ^ rd(s.indx()))
        elif op == 0x51: s.a = s.nz(s.a ^ rd(s.indy()))
        elif op == 0xC9: s.cmp(s.a, mem[s.imm()])
        elif op == 0xC5: s.cmp(s.a, rd(s.zp()))
        elif op == 0xD5: s.cmp(s.a, rd(s.zpx()))
        elif op == 0xCD: s.cmp(s.a, rd(s.abs()))
        elif op == 0xDD: s.cmp(s.a, rd(s.absx()))
        elif op == 0xD9: s.cmp(s.a, rd(s.absy()))
        elif op == 0xC1: s.cmp(s.a, rd(s.indx()))
        elif op == 0xD1: s.cmp(s.a, rd(s.indy()))
        elif op == 0xE0: s.cmp(s.x, mem[s.imm()])
        elif op == 0xE4: s.cmp(s.x, rd(s.zp()))
        elif op == 0xEC: s.cmp(s.x, rd(s.abs()))
        elif op == 0xC0: s.cmp(s.y, mem[s.imm()])
        elif op == 0xC4: s.cmp(s.y, rd(s.zp()))
        elif op == 0xCC: s.cmp(s.y, rd(s.abs()))
        elif op == 0xE6: a = s.zp();  wr(a, s.nz(rd(a) + 1))
        elif op == 0xF6: a = s.zpx(); wr(a, s.nz(rd(a) + 1))
        elif op == 0xEE: a = s.abs(); wr(a, s.nz(rd(a) + 1))
        elif op == 0xFE: a = s.absx();wr(a, s.nz(rd(a) + 1))
        elif op == 0xC6: a = s.zp();  wr(a, s.nz(rd(a) - 1))
        elif op == 0xD6: a = s.zpx(); wr(a, s.nz(rd(a) - 1))
        elif op == 0xCE: a = s.abs(); wr(a, s.nz(rd(a) - 1))
        elif op == 0xDE: a = s.absx();wr(a, s.nz(rd(a) - 1))
        elif op == 0xE8: s.x = s.nz(s.x + 1)
        elif op == 0xC8: s.y = s.nz(s.y + 1)
        elif op == 0xCA: s.x = s.nz(s.x - 1)
        elif op == 0x88: s.y = s.nz(s.y - 1)
        elif op == 0x0A: s.c = s.a >= 0x80; s.a = s.nz(s.a << 1)
        elif op == 0x06: a = s.zp();  v = rd(a); s.c = v >= 0x80; wr(a, s.nz(v << 1))
        elif op == 0x16: a = s.zpx(); v = rd(a); s.c = v >= 0x80; wr(a, s.nz(v << 1))
        elif op == 0x0E: a = s.abs(); v = rd(a); s.c = v >= 0x80; wr(a, s.nz(v << 1))
        elif op == 0x1E: a = s.absx();v = rd(a); s.c = v >= 0x80; wr(a, s.nz(v << 1))
        elif op == 0x4A: s.c = bool(s.a & 1); s.a = s.nz(s.a >> 1)
        elif op == 0x46: a = s.zp();  v = rd(a); s.c = bool(v & 1); wr(a, s.nz(v >> 1))
        elif op == 0x56: a = s.zpx(); v = rd(a); s.c = bool(v & 1); wr(a, s.nz(v >> 1))
        elif op == 0x4E: a = s.abs(); v = rd(a); s.c = bool(v & 1); wr(a, s.nz(v >> 1))
        elif op == 0x5E: a = s.absx();v = rd(a); s.c = bool(v & 1); wr(a, s.nz(v >> 1))
        elif op == 0x2A: c = 1 if s.c else 0; s.c = s.a >= 0x80; s.a = s.nz((s.a << 1) | c)
        elif op == 0x26: a = s.zp();  v = rd(a); c = 1 if s.c else 0; s.c = v >= 0x80; wr(a, s.nz((v << 1) | c))
        elif op == 0x36: a = s.zpx(); v = rd(a); c = 1 if s.c else 0; s.c = v >= 0x80; wr(a, s.nz((v << 1) | c))
        elif op == 0x2E: a = s.abs(); v = rd(a); c = 1 if s.c else 0; s.c = v >= 0x80; wr(a, s.nz((v << 1) | c))
        elif op == 0x3E: a = s.absx();v = rd(a); c = 1 if s.c else 0; s.c = v >= 0x80; wr(a, s.nz((v << 1) | c))
        elif op == 0x6A: c = 0x80 if s.c else 0; s.c = bool(s.a & 1); s.a = s.nz((s.a >> 1) | c)
        elif op == 0x66: a = s.zp();  v = rd(a); c = 0x80 if s.c else 0; s.c = bool(v & 1); wr(a, s.nz((v >> 1) | c))
        elif op == 0x76: a = s.zpx(); v = rd(a); c = 0x80 if s.c else 0; s.c = bool(v & 1); wr(a, s.nz((v >> 1) | c))
        elif op == 0x6E: a = s.abs(); v = rd(a); c = 0x80 if s.c else 0; s.c = bool(v & 1); wr(a, s.nz((v >> 1) | c))
        elif op == 0x7E: a = s.absx();v = rd(a); c = 0x80 if s.c else 0; s.c = bool(v & 1); wr(a, s.nz((v >> 1) | c))
        elif op == 0x24: v = rd(s.zp());  s.z = (s.a & v) == 0; s.n = v >= 0x80; s.v = bool(v & 0x40)
        elif op == 0x2C: v = rd(s.abs()); s.z = (s.a & v) == 0; s.n = v >= 0x80; s.v = bool(v & 0x40)
        elif op == 0x10: s.branch(not s.n)
        elif op == 0x30: s.branch(s.n)
        elif op == 0x50: s.branch(not s.v)
        elif op == 0x70: s.branch(s.v)
        elif op == 0x90: s.branch(not s.c)
        elif op == 0xB0: s.branch(s.c)
        elif op == 0xD0: s.branch(not s.z)
        elif op == 0xF0: s.branch(s.z)
        elif op == 0x4C: s.pc = s.abs()
        elif op == 0x6C:
            a = s.abs()
            s.pc = mem[a] | (mem[(a & 0xFF00) | ((a + 1) & 0xFF)] << 8)
        elif op == 0x20:
            a = s.abs()
            s.push16(s.pc - 1)
            s.pc = a
        elif op == 0x60: s.pc = (s.pop16() + 1) & 0xFFFF
        elif op == 0x40:
            s.setflags(s.pop()); s.pc = s.pop16()
        elif op == 0x18: s.c = False
        elif op == 0x38: s.c = True
        elif op == 0x58: s.i = False
        elif op == 0x78: s.i = True
        elif op == 0xB8: s.v = False
        elif op == 0xD8: s.d = False
        elif op == 0xF8: s.d = True
        elif op == 0x48: s.push(s.a)
        elif op == 0x68: s.a = s.nz(s.pop())
        elif op == 0x08: s.push(s.flags())
        elif op == 0x28: s.setflags(s.pop())
        elif op == 0xEA: pass
        elif op == 0x00:
            raise RuntimeError(f'BRK at {s.pc - 1:04X}')
        else:
            raise RuntimeError(f'unimplemented opcode {op:02X} at {s.pc - 1:04X}')


# ---------------- PAL paleta + render ----------------
