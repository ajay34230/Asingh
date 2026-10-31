#!/usr/bin/env python3
"""Footstep surfaces and wild-animal voices for The Lost Kingdom (own synthesis, CC0).
Run: python3 tools/make_nature_audio.py assets/audio"""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(31)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
os.makedirs(out, exist_ok=True)


def save(name, x, peak=0.7):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tt(d): return np.arange(int(d * SR)) / SR
def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, f0, f1, o=2): b, a = butter(o, [f0 / (SR / 2), f1 / (SR / 2)], "band"); return lfilter(b, a, x)
def noise(n): return rng.standard_normal(n)
def ex(t, tau): return np.exp(-t / tau)
def env(t, a, d): return np.minimum(1, t / a) * np.minimum(1, (d - t) / (d * 0.35))
def place(buf, snd, at):
    s = int(at * SR); e = min(len(buf), s + len(snd))
    if s < len(buf): buf[s:e] += snd[: e - s]


# --- footsteps ------------------------------------------------------------------------------
for i in range(3):          # dry leaves and twigs (forest floor): a crunch of tiny crackles
    t = tt(0.26); n = len(t)
    s = np.zeros(n)
    for k in range(rng.integers(10, 18)):
        at = int(rng.uniform(0, 0.16) * SR)
        c = hp(noise(260), 2500) * ex(tt(260 / SR), 0.006)
        s[at: at + len(c)] += c[: n - at] * rng.uniform(0.3, 1.0)
    s += bp(noise(n), 800, 3000) * ex(t, 0.05) * 0.5
    save(f"step_leaf_{i}", s, 0.5)
for i in range(3):          # splashing through shallow water
    t = tt(0.4); n = len(t)
    splash = bp(noise(n), 500, 4500) * ex(t, 0.09)
    bub = np.sin(2 * np.pi * (350 + 500 * t / 0.4 * (1 + i * 0.15)) * t) * ex(t, 0.07) * 0.5
    drip = hp(noise(n), 3000) * ex(t - 0.12, 0.05).clip(0, 1) * (t > 0.12) * 0.3
    save(f"step_water_{i}", splash + bub + drip, 0.55)
for i in range(2):          # wet ground / mud: a low squelch
    t = tt(0.32); n = len(t)
    sq = np.sin(2 * np.pi * (150 - 80 * t / 0.32) * t * (1 + 0.2 * i)) * ex(t, 0.1)
    sl = lp(noise(n), 900) * ex(t, 0.08) + 0.3 * bp(noise(n), 1500, 3500) * ex(t - 0.08, 0.04).clip(0, 1) * (t > 0.08)
    save(f"step_mud_{i}", sq * 0.7 + sl, 0.55)

# --- wild animal voices ---------------------------------------------------------------------
# crow: three harsh caws
buf = np.zeros(int(1.6 * SR))
for k, at in enumerate((0.0, 0.42, 0.84)):
    d = 0.3 + 0.04 * k; t = tt(d)
    f = 430 - 110 * t / d + 25 * np.sin(2 * np.pi * 38 * t)
    ph = np.cumsum(f) / SR
    saw = 2 * ((ph) % 1.0) - 1
    c = bp(saw + 0.4 * noise(len(t)), 700, 2600) * env(t, 0.02, d)
    place(buf, c, at)
save("crow", buf, 0.6)
# owl: "hoo, hoo-hoo, hoooo" - soft sine hoots with a slight pitch drop
buf = np.zeros(int(2.6 * SR))
for at, d, f0 in ((0.0, 0.42, 395), (0.75, 0.28, 385), (1.1, 0.28, 385), (1.6, 0.8, 370)):
    t = tt(d); f = f0 * (1 - 0.05 * t / d)
    h = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.25 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    place(buf, lp(h, 1500) * np.sin(np.pi * np.minimum(1, t / d)) ** 1.4, at)
save("owl", buf, 0.5)
# jackal: rising, wavering howl and a few yips
buf = np.zeros(int(3.4 * SR))
t = tt(2.4)
f = 430 + 380 * np.sin(np.pi * np.minimum(1, t / 1.6) * 0.5) ** 1.0 - 120 * np.maximum(0, t - 1.6) + 18 * np.sin(2 * np.pi * 6.0 * t)
ph = np.cumsum(f) / SR
howl = (np.sin(2 * np.pi * ph) + 0.5 * np.sin(4 * np.pi * ph) + 0.25 * np.sin(6 * np.pi * ph)) * np.sin(np.pi * t / 2.4) ** 0.8
place(buf, lp(howl, 3500) * 0.9, 0.0)
for at in (2.55, 2.8, 3.02):
    t2 = tt(0.16); f2 = 900 + 500 * t2 / 0.16
    place(buf, np.sin(2 * np.pi * np.cumsum(f2) / SR) * np.sin(np.pi * t2 / 0.16) * 0.6, at)
save("jackal", buf, 0.55)
# frog: a trill of short croak pulses
buf = np.zeros(int(1.5 * SR))
for k in range(9):
    at = 0.05 + k * 0.13; t = tt(0.1)
    p = bp(noise(len(t)) * 0.4 + np.sin(2 * np.pi * (110 + 25 * k % 3) * t), 500, 1800) * np.sin(np.pi * t / 0.1) ** 1.5
    place(buf, p, at)
save("frog", buf, 0.5)
# peacock: a loud two-part "pee-awk"
buf = np.zeros(int(1.4 * SR))
for at, d, f0, f1 in ((0.0, 0.5, 780, 1250), (0.55, 0.55, 1180, 820)):
    t = tt(d); f = f0 + (f1 - f0) * (t / d) + 40 * np.sin(2 * np.pi * 22 * t)
    ph = np.cumsum(f) / SR
    c = bp((2 * (ph % 1.0) - 1) + 0.3 * noise(len(t)), 600, 3800) * env(t, 0.03, d)
    place(buf, c, at)
save("peacock", buf, 0.6)
# village cat: a short meow
t = tt(0.8); f = 480 + 260 * np.sin(np.pi * np.minimum(1, t / 0.5)) * (1 - t / 0.8) ** 0.5
ph = np.cumsum(f) / SR
m = (np.sin(2 * np.pi * ph) + 0.4 * np.sin(4 * np.pi * ph) + 0.2 * np.sin(6 * np.pi * ph)) * np.sin(np.pi * np.minimum(1, t / 0.8)) ** 0.7
save("cat_meow", bp(m, 400, 4200), 0.5)
print("done")
