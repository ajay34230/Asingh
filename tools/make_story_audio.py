#!/usr/bin/env python3
"""Story voices without words: screams, battle cries, wails, sobbing, panicked and cheering crowds,
roars (own formant synthesis, CC0). Run: python3 tools/make_story_audio.py assets/audio"""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(77)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
os.makedirs(out, exist_ok=True)


def save(name, x, peak=0.8):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tt(d): return np.arange(int(d * SR)) / SR
def bp(x, f0, f1, o=2): b, a = butter(o, [max(20, f0) / (SR / 2), min(f1, SR * 0.45) / (SR / 2)], "band"); return lfilter(b, a, x)
def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def noise(n): return rng.standard_normal(n)


def place(buf, snd, at):
    s = int(at * SR); e = min(len(buf), s + len(snd))
    if 0 <= s < len(buf): buf[s:e] += snd[: e - s]


VOWELS = {"a": [(800, 90), (1200, 110), (2800, 160)], "o": [(500, 80), (900, 100), (2700, 150)], "e": [(550, 80), (1800, 120), (2600, 150)], "ae": [(700, 90), (1700, 120), (2700, 150)]}


def voice(dur, f0_curve, vowel="a", rough=0.3, breath=0.15, vib=(5.5, 0.02), env_a=0.04, env_r=0.25, bright=1.0):
    """A sung/shouted vowel: glottal pulse train at a time-varying pitch through three formant filters."""
    t = tt(dur); n = len(t)
    f0 = np.interp(t, np.linspace(0, dur, len(f0_curve)), f0_curve)
    f0 = f0 * (1 + vib[1] * np.sin(2 * np.pi * vib[0] * t)) * (1 + rough * 0.03 * noise(n))
    ph = np.cumsum(f0) / SR
    src = (ph % 1.0) * 2 - 1                      # sawtooth, rich in harmonics
    src = src - np.mean(src)
    src = src + rough * 0.5 * noise(n) * (np.abs(src) > 0.2)
    y = np.zeros(n)
    for (fc, bw), g in zip(VOWELS[vowel], (1.0, 0.8, 0.5 * bright)):
        y += g * bp(src, fc - bw, fc + bw, 2)
    y += breath * 0.3 * bp(noise(n), 1200, 3500)
    e = np.minimum(1, t / env_a) * np.minimum(1, np.maximum(0, (dur - t)) / env_r)
    y = np.tanh(1.4 * y * e)
    return lp(y, 3200 * bright + 600, 3)


def scream_woman(seed_shift=0):
    f0 = [700 + seed_shift, 1100 + seed_shift, 1450 + seed_shift, 1350, 1150, 800]
    return voice(1.6, f0, "a", rough=0.5, breath=0.25, vib=(6.5, 0.03), env_a=0.03, env_r=0.5)


def scream_man():
    f0 = [260, 420, 520, 480, 380, 240]
    return voice(1.4, f0, "ae", rough=0.7, breath=0.3, vib=(5.0, 0.03), env_a=0.04, env_r=0.45, bright=1.3)


def battle_cry():
    a = voice(0.9, [200, 280, 300, 270, 200], "a", rough=0.8, breath=0.35, vib=(4.5, 0.02), env_a=0.05, env_r=0.3)
    return a


def wail_woman():
    f0 = [420, 520, 480, 560, 470, 380]
    return voice(3.2, f0, "o", rough=0.2, breath=0.12, vib=(5.0, 0.05), env_a=0.3, env_r=0.9)


def sob_child():
    buf = np.zeros(int(3.0 * SR))
    for k in range(5):
        s = voice(0.38, [620 - k * 15, 560 - k * 20, 430 - k * 25], "e", rough=0.25, breath=0.35, vib=(7.0, 0.05), env_a=0.05, env_r=0.2)
        place(buf, s * (1.0 - k * 0.1), 0.1 + k * 0.52)
    return buf


def groan_man():
    return voice(1.2, [150, 135, 120, 105], "o", rough=0.7, breath=0.4, vib=(3.5, 0.03), env_a=0.15, env_r=0.5)


def laugh_villain():
    buf = np.zeros(int(2.2 * SR))
    for k in range(6):
        place(buf, voice(0.22, [190 + (k % 2) * 25, 170], "a", rough=0.6, breath=0.3, env_a=0.02, env_r=0.12), 0.1 + k * 0.28)
    return buf


def crowd(dur, kind):
    buf = np.zeros(int(dur * SR))
    for k in range(int(dur * 9)):
        at = rng.uniform(0, dur - 0.6)
        if kind == "panic":
            s = scream_woman(int(rng.integers(-250, 150))) if rng.random() < 0.6 else scream_man()
            s = s[: int(rng.uniform(0.5, 1.2) * SR)]
        else:                                           # cheer: many short "ahh/ooh" shouts
            s = voice(rng.uniform(0.35, 0.8), [rng.uniform(220, 520), rng.uniform(280, 650), rng.uniform(220, 480)], "a" if rng.random() < 0.6 else "o", rough=0.5, breath=0.4)
        place(buf, s * rng.uniform(0.2, 0.7), at)
    n = len(buf)
    buf += 0.25 * lp(noise(n), 1800) * np.minimum(1, tt(dur) / 0.4) * np.minimum(1, (dur - tt(dur)) / 0.6)
    if kind == "panic":                                 # running feet and clatter
        for k in range(int(dur * 7)):
            c = lp(noise(500), 700) * np.exp(-tt(500 / SR) / 0.015) * rng.uniform(0.3, 0.8)
            place(buf, c, rng.uniform(0, dur - 0.1))
    return buf


def horse_scream():
    f0 = [500, 1100, 1500, 1200, 900, 600, 750, 620]
    v = voice(1.8, f0, "ae", rough=0.9, breath=0.3, vib=(9.0, 0.04), env_a=0.04, env_r=0.6, bright=1.4)
    return v


def bull_bellow():
    return voice(2.2, [90, 110, 105, 95, 70], "o", rough=0.9, breath=0.5, vib=(3.0, 0.03), env_a=0.2, env_r=0.8)


def camel_roar():
    return voice(1.8, [130, 170, 150, 120, 90], "a", rough=1.0, breath=0.6, vib=(7.0, 0.05), env_a=0.1, env_r=0.6)


def war_roar():
    a = voice(2.0, [110, 160, 170, 150, 90], "a", rough=1.0, breath=0.5, vib=(4.0, 0.03), env_a=0.1, env_r=0.7)
    b = voice(2.0, [140, 200, 210, 180, 120], "ae", rough=1.0, breath=0.5, vib=(4.5, 0.03), env_a=0.1, env_r=0.7)
    return a + 0.8 * b


for i in range(2):
    save(f"scream_woman_{i}", scream_woman(i * 120 - 60))
    save(f"yell_man_{i}", battle_cry() if i == 0 else scream_man())
save("wail_woman", wail_woman())
save("sob_child", sob_child())
save("groan_man", groan_man())
save("laugh_villain", laugh_villain())
save("panic_crowd", crowd(6.0, "panic"))
save("cheer_crowd", crowd(5.0, "cheer"))
save("horse_scream", horse_scream())
save("bull_bellow", bull_bellow())
save("camel_roar", camel_roar())
save("war_roar", war_roar())
print("ok")
