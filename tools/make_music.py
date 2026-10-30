"""Procedural instrumental music and emotion stingers for The Lost Kingdom (all generated here, CC0).
   python3 tools/make_music.py assets/audio"""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(11)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"


def save(name, x, peak=0.7):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tt(d): return np.arange(int(d * SR)) / SR
def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def noise(n): return rng.standard_normal(n)
def mf(m): return 440.0 * 2 ** ((m - 69) / 12)
def saw(f, t): return 2 * ((f * t) % 1.0) - 1


def adsr(n, a, r):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e


def pluck(f, d=2.0, bright=0.6):
    t = tt(d); s = 0
    for k in range(1, 9):
        s = s + (1.0 / k) * np.sin(2 * np.pi * f * k * t * (1 + 0.0004 * k)) * np.exp(-t / (0.5 + 1.2 / k) * (1 + (1 - bright)))
    s += 0.12 * np.sin(2 * np.pi * f * 2.003 * t) * np.exp(-t / 0.25)
    return s * 0.6


def bell(f, d=3.0):
    t = tt(d); s = 0
    for r, g, tau in ((1, 1, 1.4), (2.76, 0.5, 0.9), (5.4, 0.3, 0.5), (8.9, 0.15, 0.3)):
        s = s + g * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau)
    return s * 0.5


def pad(f, d=4.0, a=0.8, r=1.2, bright=2200):
    t = tt(d); s = 0
    for det in (-0.006, 0.0, 0.007):
        s = s + saw(f * (1 + det), t) * 0.33
    s = lp(s, bright, 2) + 0.2 * np.sin(2 * np.pi * f * t)
    return s * adsr(len(t), a, r)


def flute(f, d=1.5, vib=5.0, breath=0.05, a=0.08):
    t = tt(d); fv = f * (1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.clip(t / 0.4, 0, 1))
    ph = np.cumsum(fv) / SR
    s = np.sin(2 * np.pi * ph) + 0.35 * np.sin(4 * np.pi * ph) + 0.12 * np.sin(6 * np.pi * ph)
    s = s + breath * lp(noise(len(t)), 3500) * 2
    return s * adsr(len(t), a, 0.25) * 0.5


def thump(f0=110, d=0.4):
    t = tt(d); return np.sin(2 * np.pi * (f0 * 0.5 + f0 * np.exp(-t / 0.05)) * t) * np.exp(-t / 0.18)


def tick(d=0.15, c=2400):
    t = tt(d); return hp(noise(len(t)), c) * np.exp(-t / 0.03) * 0.5


def dhol(d=0.3):
    t = tt(d); return (np.sin(2 * np.pi * (70 + 120 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.12) + 0.3 * lp(noise(len(t)), 900) * np.exp(-t / 0.04))


def reverb(x, taps=((0.13, 0.4), (0.23, 0.32), (0.37, 0.24), (0.53, 0.18), (0.71, 0.12))):
    y = x.copy()
    for d, g in taps:
        y = y + g * np.roll(x, int(d * SR))
    return y


def place(buf, snd, at, gain=1.0):
    s0 = int(at * SR); n = len(buf)
    if s0 >= n: return
    seg = snd[: n - s0]; buf[s0: s0 + len(seg)] += seg * gain
    if len(snd) > n - s0:                       # wrap the tail so loops are seamless
        tail = snd[n - s0:]; m = min(len(tail), n); buf[:m] += tail[:m] * gain


def loop(D): return np.zeros(int(D * SR))


# ------------------------------------------------------------------ loops
# RACE: fast, driving, D phrygian dominant (Ila's festival drums)
bpm = 144; beat = 60 / bpm; D = beat * 64 * 0.5   # 32 beats
m = loop(D)
D_ = 50  # D3
scale = [0, 1, 4, 5, 7, 8, 10, 12]
for b in range(int(D / beat * 2)):                     # eighth notes
    at = b * beat / 2
    if b % 8 in (0, 3, 6): place(m, dhol(), at, 0.9)
    if b % 2 == 1: place(m, tick(), at, 0.5)
    if b % 4 == 2: place(m, tick(0.1, 3800), at, 0.4)
    note = D_ + 12 + scale[[0, 0, 2, 0, 3, 2, 0, 4][b % 8]]
    place(m, pluck(mf(note), 0.6, 0.8), at, 0.55)
mel = [(0, 7, 2), (2, 8, 1), (3, 7, 1), (4, 4, 2), (6, 5, 1), (7, 4, 1), (8, 0, 3), (12, 0, 1), (13, 4, 1), (14, 5, 1), (15, 7, 1), (16, 8, 2), (18, 7, 1), (19, 5, 1), (20, 4, 4), (24, 7, 2), (26, 8, 2), (28, 7, 2), (30, 4, 2)]
for bt, deg, ln in mel:
    place(m, flute(mf(D_ + 24 + scale[deg % 8] - (12 if deg > 7 else 0)), ln * beat * 0.95), bt * beat, 0.7)
for bar in range(8):
    place(m, pad(mf(D_ - 12), beat * 4, 0.2, 0.4, 900), bar * beat * 4, 0.5)
race = lp(reverb(m, ((0.09, 0.25), (0.17, 0.18))), 6500)
save("music_race", race, 0.65)

# TENSION: low drone, heartbeat, tremolo cluster, sparse dissonant plucks
D = 24.0; m = loop(D); t = tt(D)
for f, g in ((55, 0.5), (58.3, 0.3), (82.4, 0.25)):
    m += g * np.sin(2 * np.pi * f * t) * (0.7 + 0.3 * np.sin(2 * np.pi * t / D * 2))
trem = 0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)
m += 0.12 * lp(saw(110, t) + saw(116.5, t) + saw(164.8, t), 800) * trem * (0.3 + 0.7 * np.sin(np.pi * t / D) ** 2)
for k in range(int(D / 1.0)):
    place(m, thump(70, 0.35), k * 1.0, 0.9); place(m, thump(60, 0.3), k * 1.0 + 0.28, 0.6)
for at, n in ((2, 45), (5.5, 46), (9, 43), (13, 45), (17, 47), (20.5, 44)):
    place(m, pluck(mf(n), 2.2, 0.3), at, 0.7)
save("music_tension", lp(reverb(m), 5000), 0.65)

# SACRED: shruti drone + slow bansuri in Bhairav + bells
D = 32.0; m = loop(D); t = tt(D)
for f, g in ((110, 0.5), (164.8, 0.35), (220, 0.25)):
    m += g * np.sin(2 * np.pi * f * t) * (0.8 + 0.2 * np.sin(2 * np.pi * t / D * 3 + f))
for at in (0, 8, 16, 24):
    place(m, pad(mf(57), 9.0, 2.5, 3.0, 1400), at, 0.45); place(m, pad(mf(64), 9.0, 3.0, 3.0, 1400), at, 0.3)
bh = [0, 1, 4, 5, 7, 8, 11, 12]; A3 = 57
phrase = [(1, 0, 3), (4, 1, 2), (6, 4, 3), (9, 5, 3), (12, 4, 2), (14, 1, 2), (16, 0, 4), (21, 4, 2), (23, 5, 2), (25, 7, 3), (28, 5, 2), (30, 4, 2)]
for at, deg, ln in phrase:
    place(m, flute(mf(A3 + 12 + bh[deg]), ln * 0.95, 4.6, 0.06, 0.2), at, 0.6)
for at, n in ((0, 81), (7, 76), (15, 84), (22, 79)):
    place(m, bell(mf(n), 5.0), at, 0.35)
save("music_sacred", lp(reverb(m, ((0.2, 0.45), (0.37, 0.35), (0.61, 0.28), (0.89, 0.2))), 4800), 0.6)

# MYSTERY: hollow drone, sparse high bells, slow swells (Queen's road / the gate)
D = 28.0; m = loop(D); t = tt(D)
m += 0.5 * np.sin(2 * np.pi * 73.4 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * t / D * 2))
m += 0.2 * lp(noise(len(t)), 500) * (0.4 + 0.6 * np.sin(np.pi * t / D * 2) ** 2)
for at, n in ((1, 86), (4.5, 89), (8, 82), (12, 85), (15.5, 92), (19, 87), (22.5, 80), (25, 84)):
    place(m, bell(mf(n), 4.5), at, 0.4)
for at in (0, 10, 19):
    place(m, pad(mf(50), 9.0, 4.0, 4.0, 700), at, 0.5); place(m, pad(mf(53), 9.0, 4.5, 4.0, 700), at + 0.5, 0.3)
save("music_mystery", lp(reverb(m, ((0.25, 0.5), (0.43, 0.4), (0.71, 0.3), (1.1, 0.2))), 4500), 0.55)

# ------------------------------------------------------------------ stingers (one shots)
def stinger(D, build):
    m = loop(D); build(m); return reverb(m, ((0.11, 0.3), (0.23, 0.22), (0.41, 0.15)))

# SURPRISE: sudden dissonant stab + boom + glass
def b_surprise(m):
    place(m, (pad(mf(62), 1.2, 0.01, 0.9, 5000) + pad(mf(63), 1.2, 0.01, 0.9, 5000) + pad(mf(68), 1.2, 0.01, 0.9, 5000)), 0.0, 0.9)
    place(m, thump(55, 1.0), 0.0, 1.2)
    place(m, bell(mf(93), 2.0), 0.02, 0.5)
    place(m, hp(noise(int(0.5 * SR)), 1500) * np.exp(-tt(0.5) / 0.1), 0.0, 0.5)
save("sting_surprise", stinger(3.0, b_surprise), 0.8)

# DISCOVERY: rising bell arpeggio, warm pad
def b_disc(m):
    for i, n in enumerate((69, 73, 76, 81, 85, 88)):
        place(m, bell(mf(n), 3.0), i * 0.13, 0.6)
    place(m, pad(mf(57), 4.0, 0.3, 1.5, 3000), 0.0, 0.5); place(m, pad(mf(64), 4.0, 0.4, 1.5, 3000), 0.1, 0.4)
save("sting_discovery", stinger(4.5, b_disc), 0.7)

# VICTORY: fanfare chords over drum roll
def b_vic(m):
    for at, chord, ln in ((0.0, (60, 64, 67), 0.9), (0.9, (62, 65, 69), 0.9), (1.8, (64, 67, 71), 0.9), (2.7, (65, 69, 72, 77), 2.8)):
        for n in chord:
            place(m, pad(mf(n), ln + 0.5, 0.04, 0.4, 3500), at, 0.5)
    for k in range(10): place(m, tick(0.1, 3000), 0.1 * k, 0.35)
    place(m, thump(70, 0.6), 2.7, 1.1)
    for i, n in enumerate((72, 76, 79, 84)): place(m, bell(mf(n + 12), 2.5), 2.7 + i * 0.08, 0.35)
    place(m, flute(mf(79), 2.0, 5.5), 2.7, 0.5)
save("sting_victory", stinger(6.5, b_vic), 0.75)

# SAD: falling minor bansuri line over a soft pad
def b_sad(m):
    for at, n, ln in ((0.3, 76, 1.2), (1.6, 74, 1.0), (2.7, 72, 1.0), (3.8, 71, 2.0)):
        place(m, flute(mf(n), ln * 1.1, 4.5, 0.07, 0.2), at, 0.7)
    for at, n in ((0.0, 57), (2.5, 55), (4.5, 52)):
        place(m, pad(mf(n), 3.5, 0.8, 1.5, 1200), at, 0.55); place(m, pad(mf(n + 7), 3.5, 1.0, 1.5, 1200), at, 0.35)
save("sting_sad", stinger(7.5, b_sad), 0.6)

# DANGER: low horn blast + tremolo
def b_danger(m):
    t = tt(2.5); tr = 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)
    place(m, lp(saw(55, t) + saw(58, t) + 0.7 * saw(82.4, t), 700, 2) * tr * adsr(len(t), 0.05, 0.8), 0.0, 0.8)
    place(m, thump(50, 1.0), 0.0, 1.2); place(m, thump(50, 1.0), 0.5, 0.9)
    place(m, pluck(mf(51), 2.0, 0.3), 0.0, 0.6)
save("sting_danger", stinger(3.5, b_danger), 0.8)

# REVEAL: rising swell to a bright open chord + bell
def b_reveal(m):
    for i, n in enumerate((50, 57, 62, 66)):
        place(m, pad(mf(n), 4.5, 1.8, 1.5, 2600), i * 0.15, 0.45)
    place(m, bell(mf(86), 4.0), 2.0, 0.5); place(m, bell(mf(90), 4.0), 2.15, 0.35); place(m, bell(mf(93), 4.0), 2.3, 0.3)
    place(m, thump(60, 0.8), 2.0, 0.8)
save("sting_reveal", stinger(6.0, b_reveal), 0.7)
print("music done")
