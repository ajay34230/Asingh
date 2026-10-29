#!/usr/bin/env python3
"""Generates every sound of The Lost Kingdom procedurally (own work, no third-party audio).
Run: python3 tools/make_audio.py assets/audio"""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(7)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
os.makedirs(out, exist_ok=True)


def save(name, x, peak=0.85):
    x = np.asarray(x, np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def t_(d): return np.arange(int(d * SR)) / SR
def env(n, a=0.005, d=0.1, sus=0.0, r=0.1):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e
def lp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, f0, f1, o=2): b, a = butter(o, [f0 / (SR / 2), f1 / (SR / 2)], "band"); return lfilter(b, a, x)
def noise(n): return rng.standard_normal(n)
def expdec(t, tau): return np.exp(-t / tau)
def saw(f, t):
    ph = np.cumsum(f) / SR if hasattr(f, "__len__") else f * t
    return 2 * (ph % 1.0) - 1
def formant(x, fs, q=8):
    y = 0
    for f, g in fs:
        y = y + g * bp(x, max(60, f * 0.9), min(SR / 2 - 100, f * 1.1), 2)
    return y
def periodic_noise(d, lo, hi, seed):
    n = int(d * SR); r = np.random.default_rng(seed)
    spec = np.zeros(n // 2 + 1, complex)
    fr = np.fft.rfftfreq(n, 1 / SR)
    mag = np.where((fr > lo) & (fr < hi), 1 / np.maximum(fr, 1) ** 0.6, 0)
    spec = mag * np.exp(1j * r.uniform(0, 2 * np.pi, len(fr)))
    return np.fft.irfft(spec, n)

# --- footsteps and body -------------------------------------------------------------------
for i in range(4):
    n = int(0.16 * SR); t = t_(0.16)
    s = lp(noise(n), 1400 + 300 * i) * expdec(t, 0.035)
    s += 0.8 * np.sin(2 * np.pi * (70 + 8 * i) * t) * expdec(t, 0.03)
    s += 0.25 * hp(noise(n), 3000) * expdec(t, 0.012)
    save(f"step_sand_{i}", s, 0.55)
for i in range(3):
    n = int(0.14 * SR); t = t_(0.14)
    s = lp(noise(n), 2200) * expdec(t, 0.03) * 0.5 + np.sin(2 * np.pi * (120 + 10 * i) * t) * expdec(t, 0.025)
    save(f"step_wood_{i}", s, 0.5)
t = t_(0.3); save("jump", bp(noise(len(t)), 300, 2500) * np.sin(np.pi * t / 0.3) ** 2 * (0.3 + t / 0.3), 0.4)
t = t_(0.35); save("land", (lp(noise(len(t)), 900) * expdec(t, 0.06) + np.sin(2 * np.pi * 60 * t) * expdec(t, 0.07)), 0.7)

# --- ambience -------------------------------------------------------------------------------
d = 16.0; t = t_(d)
w1 = periodic_noise(d, 80, 900, 1); w2 = periodic_noise(d, 400, 2500, 2)
swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / d * 2 + 0.7) * np.sin(2 * np.pi * t / d * 3)
gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / d * 1 + 2.0)
wind = w1 * (0.6 + 0.4 * swell) + 0.35 * w2 * gust ** 2
save("wind_loop", wind, 0.55)
for i in range(5):
    d = 0.35 + 0.1 * i; t = t_(d); n = len(t)
    f = 2600 + 700 * np.sin(2 * np.pi * (3 + i) * t / d * 0.5) + (1200 + 300 * i) * t / d
    ph = np.cumsum(f) / SR
    s = (np.sin(2 * np.pi * ph) + 0.3 * np.sin(4 * np.pi * ph)) * np.sin(np.pi * t / d) ** 1.5
    pulses = (np.sin(2 * np.pi * (14 + 4 * i) * t) > -0.3).astype(float)
    save(f"bird_{i}", s * (0.5 + 0.5 * pulses), 0.28)

# --- music: Hijaz mode, plucked strings + drone -------------------------------------------------
def pluck(freq, dur, bright=0.5):
    n = int(dur * SR); N = int(SR / freq)
    buf = rng.uniform(-1, 1, N) * np.hanning(N) ** 0.3; buf = lp(buf, 4000 * bright + 800, 1)
    y = np.zeros(n); idx = 0
    for i in range(n):
        y[i] = buf[idx]; nxt = buf[(idx + 1) % N]
        buf[idx] = 0.4985 * (buf[idx] + nxt); idx = (idx + 1) % N
    return y
D = 40.0; n = int(D * SR); mus = np.zeros(n); t = t_(D)
root = 146.83  # D3
ratios = {"D": 1, "Eb": 16 / 15, "F#": 5 / 4, "G": 4 / 3, "A": 3 / 2, "Bb": 8 / 5, "C": 9 / 5, "D2": 2}
# drone: root + fifth, slow swell, periodic
for f, g in ((root / 2, 0.5), (root * 0.75, 0.3), (root, 0.22)):
    for dt in (0.0, 0.3):
        mus += g * np.sin(2 * np.pi * (f + dt) * t) * (0.6 + 0.4 * np.sin(2 * np.pi * t / D * 2 + f))
mus *= 0.5
phrase = [("D", 0, 1), ("Eb", 1, 1), ("F#", 2, 2), ("G", 4, 1), ("F#", 5, 1), ("Eb", 6, 1), ("D", 7, 3),
          ("A", 10, 1), ("Bb", 11, 1), ("A", 12, 1), ("G", 13, 1), ("F#", 14, 2), ("Eb", 16, 1), ("D", 17, 4),
          ("G", 22, 1), ("A", 23, 1), ("Bb", 24, 2), ("A", 26, 1), ("G", 27, 1), ("F#", 28, 1), ("Eb", 29, 1), ("D", 30, 5)]
beat = 1.0
for name, st, ln in phrase:
    f = root * 2 * ratios[name]
    note = pluck(f, 3.0 + ln * 0.5, 0.6) * 0.7
    s0 = int(st * beat * SR); seg = note[: n - s0] if s0 + len(note) > n else note
    mus[s0: s0 + len(seg)] += seg
    if len(note) > n - s0:  # wrap tail for seamless loop
        tail = note[n - s0:]; mus[: len(tail)] += tail
# soft frame-drum pulse
for k in range(int(D)):
    if k % 2 == 0:
        tt = t_(0.4); h = np.sin(2 * np.pi * (90 - 30 * tt) * tt * 1.0) * expdec(tt, 0.12) * 0.35
        s0 = k * SR; mus[s0: s0 + len(h)] += h[: n - s0]
rev = np.zeros(n)
for dl, g in ((0.11, 0.35), (0.19, 0.28), (0.31, 0.2), (0.47, 0.14)):
    k = int(dl * SR); rev += g * np.roll(mus, k)
mus = lp(mus + rev, 5000, 2)
save("music_desert", mus, 0.6)

# --- impacts --------------------------------------------------------------------------------
t = t_(1.2); s = 0
for f, g, tau in ((1130, 1, 0.5), (2870, 0.6, 0.3), (4650, 0.4, 0.2), (6900, 0.25, 0.12), (790, 0.5, 0.6)):
    s = s + g * np.sin(2 * np.pi * f * t) * expdec(t, tau)
s += 0.8 * hp(noise(len(t)), 2000) * expdec(t, 0.01)
save("anvil", s, 0.7)
t = t_(0.9); f = 190 + 70 * np.sin(2 * np.pi * 4 * t) + 80 * t
save("door_creak", bp(saw(f, t), 200, 1800) * np.sin(np.pi * t / 0.9) ** 0.6 + 0.1 * bp(noise(len(t)), 800, 2500) * 0.2, 0.45)
t = t_(0.5); save("door_thud", (np.sin(2 * np.pi * 80 * t) * expdec(t, 0.08) + 0.3 * lp(noise(len(t)), 700) * expdec(t, 0.05)), 0.6)
d = 6.0; t = t_(d)
rum = periodic_noise(d, 30, 220, 5) * (0.7 + 0.3 * np.sin(2 * np.pi * t / d * 6))
creak = bp(periodic_noise(d, 300, 1500, 6), 400, 1200) * (np.sin(2 * np.pi * t / d * 3) > 0.7)
save("cart_loop", rum + 0.15 * creak, 0.4)
for i in range(2):
    t = t_(0.25); save(f"hoof_{i}", (np.sin(2 * np.pi * (260 + 60 * i) * t) * expdec(t, 0.02) + 0.5 * bp(noise(len(t)), 800, 3000) * expdec(t, 0.015)), 0.5)
t = t_(0.3); save("ui_blip", (np.sin(2 * np.pi * 880 * t) * expdec(t, 0.08) + 0.6 * np.sin(2 * np.pi * 1318 * t) * expdec(t, 0.1)), 0.35)
t = t_(0.5); save("chime", sum(g * np.sin(2 * np.pi * f * t) * expdec(t, tau) for f, g, tau in ((784, 1, 0.3), (1175, 0.6, 0.25), (1568, 0.3, 0.2))), 0.35)

# --- animals --------------------------------------------------------------------------------
def moo(f0, dur, rough=0.3):
    t = t_(dur); f = f0 * (1.15 - 0.3 * t / dur + 0.04 * np.sin(2 * np.pi * 5 * t))
    s = saw(f, t) + 0.3 * saw(f * 2.01, t)
    s = formant(s, ((500, 1), (900, 0.7), (2200, 0.2)))
    return s * env(len(t), 0.12, 0, 0, 0.35) * (1 + rough * np.sin(2 * np.pi * 30 * t))
save("cow_moo", moo(120, 1.5)); save("bull_moo", moo(85, 1.8, 0.4))
t = t_(1.5); f = np.where((t % 0.75) < 0.38, 520 - 100 * (t % 0.38) / 0.38, 240 + 40 * np.sin(2 * np.pi * 9 * t))
s = formant(saw(f, t), ((700, 1), (1400, 0.6), (2600, 0.2))) + 0.2 * hp(noise(len(t)), 1500) * 0.4
save("donkey_bray", s * env(len(t), 0.03, 0, 0, 0.25))
t = t_(1.0); f = 750 + 450 * np.sin(np.pi * np.clip(t / 0.8, 0, 1)) - 200 * (t / 1.0) ** 2
s = formant(saw(f, t) + 0.5 * saw(f * 1.5, t), ((900, 1), (2000, 0.7), (3400, 0.3))) * (1 + 0.15 * np.sin(2 * np.pi * 18 * t))
save("horse_whinny", s * env(len(t), 0.05, 0, 0, 0.4))
for i in range(3):
    t = t_(0.22); f = 520 - 130 * t / 0.22 + 20 * i
    s = formant(saw(f, t) + 0.6 * noise(len(t)) * 0.5, ((650, 1), (1200, 0.8), (2400, 0.4)))
    save(f"dog_bark_{i}", s * np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 0.7, 0.7)
t = t_(1.0); f = 95 + 25 * np.sin(2 * np.pi * 3 * t) - 20 * t
s = formant(saw(f, t) * (1 + 0.6 * np.sin(2 * np.pi * 22 * t)), ((300, 1), (700, 0.7), (1500, 0.2)))
save("camel_grunt", s * env(len(t), 0.1, 0, 0, 0.4))
t = t_(0.4); save("fox_yip", formant(saw(900 + 500 * np.sin(np.pi * t / 0.4), t), ((1200, 1), (2800, 0.5))) * env(len(t), 0.02, 0, 0, 0.15), 0.4)

# --- voice blips (speech-like babble) --------------------------------------------------------
vow = {"a": ((800, 1), (1200, 0.6), (2600, 0.2)), "e": ((500, 1), (1900, 0.6), (2600, 0.2)),
       "i": ((300, 1), (2200, 0.6), (3000, 0.2)), "o": ((500, 1), (900, 0.7), (2400, 0.15)), "u": ((330, 1), (800, 0.5), (2300, 0.1))}
voices = {"man": 105, "deep": 82, "woman": 205, "old": 170, "girl": 260}
for vn, f0 in voices.items():
    for i, v in enumerate("aeoiua"):
        dur = 0.11 + 0.02 * (i % 3); t = t_(dur)
        f = f0 * (1 + 0.12 * np.sin(np.pi * t / dur) * (1 if i % 2 else -0.6) + 0.02 * np.sin(2 * np.pi * 6 * t))
        if vn == "old": f = f * (1 + 0.03 * np.sin(2 * np.pi * 9 * t))
        s = formant(saw(f, t), vow[v]) + 0.05 * hp(noise(len(t)), 3000)
        s *= env(len(t), 0.015, 0, 0, 0.04)
        save(f"voice_{vn}_{i}", s, 0.6)

# --- story and action sounds -------------------------------------------------------------------
t = t_(0.5); save("pickup", sum(g * np.sin(2 * np.pi * f * t) * expdec(t, tau) for f, g, tau in ((988, 1, 0.12), (1319, 0.7, 0.14), (1976, 0.4, 0.1))), 0.4)
t = t_(0.9); save("seal_found", sum(g * np.sin(2 * np.pi * f * t) * expdec(t, tau) * (1 + 0.1 * np.sin(2 * np.pi * 5 * t)) for f, g, tau in ((392, 1, 0.5), (587, 0.8, 0.45), (784, 0.7, 0.4), (1175, 0.5, 0.35), (1568, 0.3, 0.3))), 0.5)
t = t_(0.7); save("mission_new", (np.sin(2 * np.pi * 523 * t) * expdec(t, 0.12) * (t < 0.25) + np.sin(2 * np.pi * 784 * np.clip(t - 0.18, 0, None)) * expdec(np.clip(t - 0.18, 0, None), 0.2) * (t > 0.18)), 0.4)
for i in range(3):
    t = t_(0.45); n = len(t)
    scr = bp(noise(n), 500 + 200 * i, 3500) * np.sin(np.pi * t / 0.45) ** 0.7 * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
    thump = np.sin(2 * np.pi * 70 * t) * expdec(t, 0.05) * (t > 0.3)
    save(f"dig_{i}", scr + 0.7 * thump, 0.55)
t = t_(0.35); save("page_turn", bp(noise(len(t)), 1500, 6000) * np.sin(np.pi * t / 0.35) ** 2 * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t)), 0.35)
d = 8.0; t = t_(d)
rum = periodic_noise(d, 25, 160, 11) * (0.6 + 0.4 * np.sin(2 * np.pi * t / d * 3))
grind = bp(periodic_noise(d, 100, 900, 12), 150, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 5))
save("gate_rumble", rum + 0.45 * grind, 0.7)
t = t_(2.0); save("stone_boom", np.sin(2 * np.pi * 48 * t) * expdec(t, 0.5) + 0.6 * lp(noise(len(t)), 400) * expdec(t, 0.25), 0.8)
t = t_(1.6); save("reveal", sum(g * np.sin(2 * np.pi * f * t) * expdec(t, 0.9) * np.clip(t / 0.4, 0, 1) for f, g in ((146.8, 1), (220, 0.7), (293.7, 0.5), (369.9, 0.4), (440, 0.35))), 0.5)
print("audio written to", out)

# --- extra ambience and stone footsteps (added in Phase 4) ---------------------------------
for i in range(3):
    n = int(0.15 * SR); t = t_(0.15)
    s = hp(noise(n), 900) * expdec(t, 0.02) * 0.6 + np.sin(2 * np.pi * (180 + 14 * i) * t) * expdec(t, 0.02)
    s += 0.5 * np.sin(2 * np.pi * (95 + 6 * i) * t) * expdec(t, 0.05)
    save(f"step_stone_{i}", s, 0.6)
# crickets: seamless 8 s loop of pulsed high chirps
d = 8.0; t = t_(d); cr = np.zeros(len(t))
for f0, rate, ph in [(4200, 11.0, 0.0), (4700, 9.0, 0.37), (3900, 13.0, 0.71)]:
    gate = (np.sin(2 * np.pi * rate * t + ph * 6.28) > 0.55).astype(float)
    gate = lp(gate, 90, 1)
    cr += np.sin(2 * np.pi * f0 * t + 0.4 * np.sin(2 * np.pi * 6 * t)) * gate * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 2 + ph))
save("crickets_loop", cr + 0.02 * periodic_noise(d, 2000, 7000, 11), 0.35)
# indoor room tone: soft low hum with slow breathing
d = 8.0; t = t_(d)
room = periodic_noise(d, 60, 400, 21) * (0.8 + 0.2 * np.sin(2 * np.pi * t / d * 2))
save("room_tone", room, 0.3)

# warm drone pad: always-on background tone (seamless 24 s loop: all frequencies are whole cycles)
d = 24.0; t = t_(d); pad = np.zeros(len(t))
for k, a in [(1760, 1.0), (2640, 0.7), (3520, 0.55), (5280, 0.3), (7040, 0.18)]:
    for det in (-1, 0, 1):
        ph = rng.uniform(0, 2 * np.pi)
        lfo = 0.65 + 0.35 * np.sin(2 * np.pi * rng.integers(1, 5) * t / d + rng.uniform(0, 6.28))
        pad += a * lfo * np.sin(2 * np.pi * (k + det) / d * t + ph)
save("ambient_pad", pad, 0.5)
