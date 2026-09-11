#!/usr/bin/env python3
"""Unit test syntezy POKEY (audio.py): frekvence cisteho tonu, sum vs ton, hlasitost, popis useku."""
import os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import audio

fails = 0
def check(cond, msg):
    global fails
    print(('ok   ' if cond else 'FAIL: ') + msg)
    if not cond: fails += 1

RATE = 44100

def peak_hz(samples):
    n = len(samples)
    spec = np.abs(np.fft.rfft(samples * np.hanning(n)))
    spec[:3] = 0
    return np.fft.rfftfreq(n, 1 / RATE)[spec.argmax()]

# cisty ton: AUDF=$1B (28*28 cyklu -> 1773447/784/2 = 1131 Hz), vol 8, 20 snimku od snimku 1
log = [(0, 0, 0x1B), (0, 1, 0xA8), (20, 1, 0)]
s = audio.render(log, 25, RATE)
check(abs(peak_hz(s) - 1131) < 15, f'ton $1B/$A8 ~1131 Hz (namereno {peak_hz(s):.0f})')
check(abs(s.max() - 8 / 60) < 1e-3 and s.min() == 0, 'hlasitost 8 -> amplituda 8/60, 0..vol')
zero = np.flatnonzero(s > 0)
check(zero[0] >= RATE / audio.FPS * 0.99 and zero[-1] < RATE / audio.FPS * 21.01, 'zvuk zni od snimku 1 do 21')

# 15 kHz clock (AUDCTL bit0): 114 cyklu na tik -> 1773447/(28*114)/2 = 278 Hz
log = [(0, 8, 0x01), (0, 0, 0x1B), (0, 1, 0xA8)]
s = audio.render(log, 25, RATE)
check(abs(peak_hz(s) - 278) < 8, f'AUDCTL 15 kHz: ~278 Hz (namereno {peak_hz(s):.0f})')

# 1.79 MHz clock kanalu 1 (AUDCTL bit6): (AUDF+4) cyklu -> 1773447/31/2 = 28604 Hz (nad Nyquist/2? ne, 44.1k/2=22k -> alias); zkusit AUDF=$FF: 1773447/259/2=3424 Hz
log = [(0, 8, 0x40), (0, 0, 0xFF), (0, 1, 0xA8)]
s = audio.render(log, 25, RATE)
check(abs(peak_hz(s) - 3424) < 30, f'AUDCTL ch1 1.79 MHz: ~3424 Hz (namereno {peak_hz(s):.0f})')

# sum ($80 = 17bit): siroke spektrum, bez dominantni spicky
log = [(0, 0, 0x1B), (0, 1, 0x88)]
s = audio.render(log, 25, RATE)
spec = np.abs(np.fft.rfft(s[2000:] - s[2000:].mean())) ** 2
check(spec.max() / spec.sum() < 0.05, f'sum $88: zadna dominantni spicka ({spec.max() / spec.sum():.3f} energie v 1 binu)')
spec_t = np.abs(np.fft.rfft(audio.render([(0, 0, 0x1B), (0, 1, 0xA8)], 25, RATE)[2000:])) ** 2
check(spec_t.max() / spec_t.sum() > 0.3, 'ton $A8: dominantni spicka')

# volume-only ($1x): konstantni uroven
log = [(0, 1, 0x1C)]
s = audio.render(log, 5, RATE)
check(np.allclose(s[int(RATE / audio.FPS * 1.5):], 12 / 60), 'volume-only $1C = konstantni 12/60')

# dva kanaly se scitaji
log = [(0, 0, 0x1B), (0, 1, 0x18), (0, 3, 0x14)]
s = audio.render(log, 5, RATE)
check(np.allclose(s[int(RATE / audio.FPS * 1.5):], 12 / 60), 'kanaly 1+2 volume-only 8+4 = 12/60')

# describe: useky
log = [(0, 0, 0x60), (0, 1, 0xA8), (2, 0, 0x40), (4, 1, 0xA6), (6, 1, 0), (10, 2, 0x10), (10, 3, 0x21), (12, 3, 0)]
d = audio.describe(log, 20)
check([(x['ch'], x['frame'], x['len'], x['vol'], x['kind']) for x in d] ==
      [(1, 1, 2, 8, 'tone'), (1, 3, 2, 8, 'tone'), (1, 5, 2, 6, 'tone'), (2, 11, 2, 1, 'tone+5bit')],
      'describe: useky kanalu 1 a 2 (kind, delka, hlasitost)')
check(abs(d[0]['hz'] - 326.5) < 1 and abs(d[1]['hz'] - 487.2) < 1 and abs(d[0]['ms'] - 40) < 1, 'describe: Hz a ms')
check('326.5 Hz' in audio.format_describe(d), 'format_describe obsahuje Hz')

# trim + spektrogram + wav do scratch
out = os.path.join(HERE, 'out_audio_test.png')
s = audio.render([(5, 0, 0x60), (5, 1, 0xA8), (8, 1, 0)], 30, RATE)
t, f0 = audio.trim(s, RATE)
check(abs(f0 - 5) < 0.5 and len(t) < len(s) / 2, f'trim: zacatek ~snimek 6-1 (namereno {f0:.1f}), zkraceno')
audio.spectrogram(t, out, RATE, 'test', f0)
check(os.path.getsize(out) > 5000, 'spectrogram PNG vytvoren')
wav = os.path.join(HERE, 'out_audio_test.wav')
audio.save_wav(t, wav, RATE)
check(os.path.getsize(wav) == 44 + 2 * len(t), 'WAV 16bit mono spravne delky')

print('ALL OK' if not fails else f'{fails} FAIL')
sys.exit(1 if fails else 0)
