#!/usr/bin/env python3
"""Synteza zvuku POKEY z logu zapisu (Machine.pokey_log) - "usi" pro headless emulator.

Model (PAL, 1.773447 MHz):
  - AUDF1-4 / AUDC1-4 / AUDCTL, kazdy kanal samostatne. Divider kanalu tika kazdych
    (AUDF+1)*28 cyklu (64 kHz), s AUDCTL bitem 0 *114 (15 kHz); kanal 1 resp. 3 muze
    bezet na 1.79 MHz (AUDF+4 cyklu, AUDCTL bity 6 resp. 5).
  - Distortion (AUDC bity 7-5): bit7 = obejit 5bit poly, bit5 = obejit 17/4bit poly
    (cisty ton = preklapeni pri kazdem tiku), bit6 = 4bit misto 17bit poly;
    AUDCTL bit7 meni 17bit poly na 9bit. Tedy $A0 = cisty ton, $80 = 17bit sum,
    $20 = ton skrz 5bit poly (bzucak), $00 = 5bit+17bit sum, $C0 = 4bit sum.
    Bit4 = volume-only (konstantni uroven = hlasitost).
  - Zapisy se uplatnuji na zacatku snimku, ve kterem se do logu dostaly (VBI zapisuje
    na konci snimku, takze zvuk zacne o snimek pozdeji; pro testy staci).
  Neni: spojeni kanalu do 16 bitu, hi-pass filtry, presne poly startovni faze.

API (viz Machine.audio_*):
  render(pokey_log, frames, rate)  -> numpy float32 mono v <-1, 1>
  save_wav(samples, path, rate)
  spectrogram(samples, path, rate) -> PNG (spektrogram + obalka hlasitosti)
  describe(pokey_log, frames)      -> seznam useku: (kanal, od_snimku, snimku, hz, hlasitost, typ)
"""
import numpy as np

CLOCK = 1773447                 # PAL cykly/s
FRAME_CYCLES = 312 * 114        # PAL snimek
FPS = CLOCK / FRAME_CYCLES      # ~49.86


def _poly(bits, taps):
    """Sekvence LFSR (delka 2^bits-1) jako pole 0/1."""
    n = (1 << bits) - 1
    out = np.zeros(n, dtype=np.uint8)
    s = n
    for i in range(n):
        out[i] = s & 1
        fb = 0
        for t in taps:
            fb ^= (s >> t) & 1
        s = (s >> 1) | (fb << (bits - 1))
    return out


POLY4 = _poly(4, (0, 1))
POLY5 = _poly(5, (0, 2))
POLY9 = _poly(9, (0, 4))
POLY17 = _poly(17, (0, 5))


def _channel_pulses(seg_cycles, period, phase):
    """Cykly tiku divideru v useku delky seg_cycles; phase = cyklu do prvniho tiku."""
    if period <= 0:
        return np.zeros(0, dtype=np.int64), phase
    first = phase
    if first >= seg_cycles:
        return np.zeros(0, dtype=np.int64), phase - seg_cycles
    t = np.arange(first, seg_cycles, period, dtype=np.int64)
    next_phase = t[-1] + period - seg_cycles
    return t, next_phase


def _regs_per_frame(pokey_log, frames):
    """Stav registru $D200-$D208 na zacatku kazdeho snimku 0..frames-1."""
    regs = [0] * 9
    out = []
    i = 0
    log = sorted(pokey_log, key=lambda e: e[0])
    for f in range(frames):
        while i < len(log) and log[i][0] < f:
            _, r, v = log[i]
            if r < 9:
                regs[r] = v
            i += 1
        # zapisy ze snimku f-1 (VBI na jeho konci) plati od snimku f
        out.append(list(regs))
    return out


def channel_period(audf, audctl, ch):
    """Perioda divideru kanalu v cyklech (ch = 0..3)."""
    if ch == 0 and audctl & 0x40:
        return audf + 4
    if ch == 2 and audctl & 0x20:
        return audf + 4
    return (audf + 1) * (114 if audctl & 0x01 else 28)


def channel_hz(audf, audc, audctl, ch):
    """Zakladni frekvence kanalu v Hz (cisty ton: tik prepina -> /2), None = ticho/sum."""
    if not (audc & 0x0F):
        return None
    if audc & 0x10:
        return 0.0
    if not (audc & 0x20):
        return None                       # sum (17/9/4bit poly)
    p = channel_period(audf, audctl, ch)
    hz = CLOCK / p / 2
    if not (audc & 0x80):
        hz = hz * 16 / 31                 # 5bit poly propousti 16 z 31 tiku (priblizne)
    return hz


def render(pokey_log, frames, rate=44100):
    """Mono float32 signal delky frames snimku (soucet 4 kanalu, normovany na 60 = max)."""
    per_frame = _regs_per_frame(pokey_log, frames)
    total_cycles = frames * FRAME_CYCLES
    n_samples = int(total_cycles / CLOCK * rate) + 1
    sample_cycles = np.arange(n_samples, dtype=np.float64) * CLOCK / rate
    mix = np.zeros(n_samples, dtype=np.float32)
    for ch in range(4):
        phase = 0
        level = 0                          # aktualni bit vystupu (0/1)
        events_t = [np.array([0], dtype=np.int64)]
        events_v = [np.array([0.0], dtype=np.float32)]
        for f, regs in enumerate(per_frame):
            audf, audc, audctl = regs[ch * 2], regs[ch * 2 + 1], regs[8]
            vol = audc & 0x0F
            base = f * FRAME_CYCLES
            if vol == 0:
                events_t.append(np.array([base])); events_v.append(np.array([0.0], dtype=np.float32))
                phase = 0
                continue
            if audc & 0x10:                # volume-only
                events_t.append(np.array([base])); events_v.append(np.array([float(vol)], dtype=np.float32))
                continue
            period = channel_period(audf, audctl, ch)
            t, phase = _channel_pulses(FRAME_CYCLES, period, phase)
            if len(t) == 0:
                events_t.append(np.array([base])); events_v.append(np.array([float(vol * level)], dtype=np.float32))
                continue
            abs_t = t + base
            keep = np.ones(len(t), dtype=bool)
            if not (audc & 0x80):          # 5bit poly filtruje tiky
                keep = POLY5[abs_t % len(POLY5)].astype(bool)
            tk = abs_t[keep]
            start_level = level
            if audc & 0x20:                # cisty ton: kazdy propusteny tik preklopi
                lv = (level ^ (np.arange(1, len(tk) + 1) & 1)).astype(np.uint8)
            else:                          # sum: vzorek poly pri tiku
                poly = POLY4 if audc & 0x40 else (POLY9 if audctl & 0x80 else POLY17)
                lv = poly[tk % len(poly)]
            if len(tk):
                level = int(lv[-1])
            events_t.append(np.concatenate(([base], tk)))
            events_v.append(np.concatenate(([float(vol * start_level)], (lv * vol).astype(np.float32))))
        et = np.concatenate(events_t)
        ev = np.concatenate(events_v)
        idx = np.searchsorted(et, sample_cycles, side='right') - 1
        idx = np.clip(idx, 0, len(ev) - 1)
        mix += ev[idx]
    return (mix / 60.0).astype(np.float32)


def trim(samples, rate=44100, pad_frames=1.0):
    """Orizne ticho na zacatku a konci (nechava pad_frames snimku okolo). Vraci (samples, offset_frames)."""
    nz = np.flatnonzero(np.abs(samples) > 1e-4)
    if len(nz) == 0:
        return samples, 0.0
    pad = int(rate / FPS * pad_frames)
    a = max(0, nz[0] - pad); b = min(len(samples), nz[-1] + pad)
    return samples[a:b], a / rate * FPS


def save_wav(samples, path, rate=44100):
    import wave
    data = np.clip(samples * 32767 * 4, -32768, 32767).astype('<i2')   # 4 kanaly po 15 = plny rozsah
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(data.tobytes())
    return path


def spectrogram(samples, path, rate=44100, title='POKEY', frame0=0.0):
    """PNG: nahore spektrogram (0-4 kHz), dole obalka hlasitosti; osa x ve snimcich (od frame0)."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    n = len(samples)
    frames = n / rate * FPS
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True,
                                   gridspec_kw={'height_ratios': [3, 1]})
    win = 1024
    if n >= win:
        samples = samples + 1e-5 * np.sin(np.arange(n))   # dither: ticho neni log(0)
        ax1.specgram(samples, NFFT=win, Fs=rate, noverlap=win - 128, cmap='magma',
                     xextent=(frame0, frame0 + frames), vmin=-120, vmax=-20)
    ax1.set_ylim(0, 4000)
    ax1.set_ylabel('Hz'); ax1.set_title(title)
    ax1.grid(alpha=0.3)
    hop = max(1, int(rate / FPS / 4))       # ctvrt snimku
    env = np.array([np.abs(samples[i:i + hop]).max() if i < n else 0 for i in range(0, n, hop)])
    ax2.plot(frame0 + np.arange(len(env)) * hop / rate * FPS, env * 60, lw=1)
    ax2.set_ylabel('hlasitost'); ax2.set_xlabel('snimek'); ax2.set_ylim(0, 16)
    ax2.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=100)
    plt.close(fig)
    return path


def _kind(audc, audctl):
    if audc & 0x10:
        return 'volume'
    base = ('tone' if audc & 0x20 else 'noise4' if audc & 0x40 else
            'noise9' if audctl & 0x80 else 'noise17')
    return base if audc & 0x80 else base + '+5bit'


def describe(pokey_log, frames):
    """Useky konstantniho stavu kanalu: list dict(ch, frame, len, audf, audc, hz, vol, kind)."""
    per_frame = _regs_per_frame(pokey_log, frames)
    out = []
    for ch in range(4):
        cur = None
        for f, regs in enumerate(per_frame):
            audf, audc, audctl = regs[ch * 2], regs[ch * 2 + 1], regs[8]
            vol = audc & 0x0F
            key = (audf, audc, audctl) if vol else None
            if cur and cur['key'] == key:
                cur['len'] += 1
                continue
            if cur and cur['key'] is not None:
                out.append(cur)
            cur = {'key': key, 'ch': ch + 1, 'frame': f, 'len': 1, 'audf': audf, 'audc': audc,
                   'vol': vol, 'hz': channel_hz(audf, audc, audctl, ch),
                   'kind': _kind(audc, audctl)}
        if cur and cur['key'] is not None:
            out.append(cur)
    for d in out:
        d.pop('key', None)
        d['ms'] = d['len'] / FPS * 1000
    out.sort(key=lambda d: (d['frame'], d['ch']))
    return out


def format_describe(segs):
    lines = []
    for d in segs:
        hz = '-' if d['hz'] is None else f"{d['hz']:7.1f} Hz"
        lines.append(f"ch{d['ch']} snimek {d['frame']:4d} +{d['len']:3d} ({d['ms']:5.0f} ms) "
                     f"AUDF=${d['audf']:02X} AUDC=${d['audc']:02X} {d['kind']:12s} {hz} vol {d['vol']}")
    return '\n'.join(lines)
