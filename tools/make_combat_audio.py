"""Fight, pain, crying and dying sounds (procedural, CC0). python3 tools/make_combat_audio.py assets/audio"""
import sys, os, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(23)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"


def save(name, x, peak=0.8):
    x = np.asarray(x, np.float64); x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def tt(d): return np.arange(int(d * SR)) / SR
def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, f0, f1, o=2): b, a = butter(o, [f0 / (SR / 2), f1 / (SR / 2)], "band"); return lfilter(b, a, x)
def noise(n): return rng.standard_normal(n)
def ex(t, tau): return np.exp(-t / tau)


def env(n, a, r):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e


def voiced(f, t, vowel=((700, 1.0), (1200, 0.6), (2600, 0.2)), rough=0.15):
    ph = np.cumsum(f) / SR if hasattr(f, "__len__") else f * t
    s = 2 * (ph % 1.0) - 1
    s = s * (1 + rough * noise(len(t)) * 0.3)
    y = 0
    for fc, g in vowel:
        y = y + g * bp(s, max(100, fc * 0.8), fc * 1.2, 2)
    return y + 0.15 * lp(noise(len(t)), 2500) * rough * 3


# ---- impacts
t = tt(0.25)
for i in range(2):
    save(f"punch_hit_{i}", (np.sin(2 * np.pi * (90 + 25 * i) * t * (1 + 2 * ex(t, 0.03))) * ex(t, 0.07) + 0.6 * lp(noise(len(t)), 1800) * ex(t, 0.025)), 0.85)
t = tt(0.35)
save("kick_hit", np.sin(2 * np.pi * 70 * t * (1 + 2.5 * ex(t, 0.04))) * ex(t, 0.12) + 0.8 * lp(noise(len(t)), 1400) * ex(t, 0.04) + 0.3 * hp(noise(len(t)), 3000) * ex(t, 0.015), 0.9)
t = tt(0.3)
save("whoosh_punch", bp(noise(len(t)), 600, 3200) * np.sin(np.pi * t / 0.3) ** 2, 0.5)
t = tt(0.5)
save("whoosh_kick", bp(noise(len(t)), 300, 2600) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 1.5 * (0.4 + 0.6 * t / 0.5), 0.55)
t = tt(0.8)
save("whoosh_throw", bp(noise(len(t)), 200, 1800) * np.sin(np.pi * t / 0.8) ** 2, 0.55)
t = tt(0.7)
save("body_fall", (np.sin(2 * np.pi * 55 * t * (1 + ex(t, 0.05))) * ex(t, 0.2) + 0.7 * lp(noise(len(t)), 600) * ex(t, 0.09) + 0.25 * bp(noise(len(t)), 800, 2500) * ex(t, 0.4) * (rng.random(len(t)) > 0.97)), 0.9)
t = tt(1.0)
save("body_slam", (np.sin(2 * np.pi * 45 * t * (1 + 1.5 * ex(t, 0.06))) * ex(t, 0.3) + lp(noise(len(t)), 900) * ex(t, 0.12) + 0.3 * hp(noise(len(t)), 2500) * ex(t, 0.02)), 0.95)
t = tt(0.4)
save("cloth_grab", bp(noise(len(t)), 800, 4000) * ex(t, 0.12) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)), 0.4)

# ---- voices
male = ((650, 1.0), (1100, 0.7), (2400, 0.25))
for i, (f0, d) in enumerate(((120, 0.35), (105, 0.45), (135, 0.3))):          # pain grunts
    t = tt(d); f = f0 * (1.25 - 0.4 * t / d)
    save(f"grunt_{i}", voiced(f, t, male, 0.3) * env(len(t), 0.02, 0.12), 0.75)
for i, (f0, d) in enumerate(((210, 0.5), (240, 0.45), (190, 0.6))):           # yelps of pain
    t = tt(d); f = f0 * (1.1 + 0.5 * np.sin(np.pi * t / d) - 0.25 * t / d)
    save(f"pain_{i}", voiced(f, t, ((800, 1.0), (1500, 0.6), (2800, 0.25)), 0.25) * env(len(t), 0.03, 0.15), 0.75)
for i, (f0, d) in enumerate(((150, 1.4), (125, 1.9), (170, 1.2))):           # dying groans, different lengths
    t = tt(d); f = f0 * (1.0 - 0.45 * (t / d) ** 1.2) * (1 + 0.03 * np.sin(2 * np.pi * 5 * t))
    g = voiced(f, t, ((600, 1.0), (1000, 0.7), (2200, 0.2)), 0.4) * env(len(t), 0.05, 0.4) * (1 - 0.6 * t / d)
    save(f"death_{i}", g + 0.05 * lp(noise(len(t)), 900) * (t / d), 0.75)
t = tt(1.1); f = 300 + 350 * np.sin(np.pi * np.clip(t / 0.8, 0, 1) ** 0.7)
save("scream", voiced(f, t, ((900, 1.0), (1800, 0.7), (3200, 0.3)), 0.35) * env(len(t), 0.02, 0.25), 0.8)
# crying / sobbing: breathy voiced bursts that pulse
d = 3.4; t = tt(d)
pulse = np.clip(np.sin(2 * np.pi * 2.6 * t), 0, 1) ** 0.7
f = (250 + 40 * np.sin(2 * np.pi * 2.6 * t)) * (1 + 0.04 * np.sin(2 * np.pi * 6 * t))
save("cry_loop", (voiced(f, t, ((700, 1.0), (1400, 0.6), (2600, 0.2)), 0.3) * pulse + 0.15 * hp(noise(len(t)), 2500) * (1 - pulse) * 0.5) * env(len(t), 0.05, 0.1), 0.6)
for i in range(2):                                                           # begging whimpers
    d = 0.9 + 0.3 * i; t = tt(d); f = (330 - 90 * t / d) * (1 + 0.05 * np.sin(2 * np.pi * 8 * t))
    save(f"whimper_{i}", voiced(f, t, ((750, 1.0), (1500, 0.5), (2800, 0.2)), 0.3) * env(len(t), 0.08, 0.3) * (0.6 + 0.4 * np.sin(2 * np.pi * 5 * t)), 0.6)
t = tt(0.6); save("gasp", bp(noise(len(t)), 500, 3500) * np.sin(np.pi * t / 0.6) ** 1.5, 0.45)
print("combat audio done")
