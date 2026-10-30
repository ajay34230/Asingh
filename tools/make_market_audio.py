"""Market / town sounds (procedural, CC0). python3 tools/make_market_audio.py assets/audio"""
import sys, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(77)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"


def save(name, x, peak=0.8, loop=False):
    x = np.asarray(x, np.float64)
    if loop:  # crossfade the ends so it loops without a click
        n = int(0.25 * SR); fade = np.linspace(0, 1, n)
        x = np.concatenate([x[:-n]]); x[:n] = x[:n] * fade + 0 * fade
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


def seamless(x, xf=0.3):
    """Make x loop: fade the tail into the head."""
    n = int(xf * SR); head = x[:n].copy(); tail = x[-n:].copy(); fade = np.linspace(0, 1, n)
    y = x[:-n].copy(); y[:n] = head * fade + tail * (1 - fade); return y


def syllable(f0, d, vowel):
    t = tt(d); f = f0 * (1 + 0.12 * np.sin(2 * np.pi * 5 * t) + 0.1 * (rng.random() - 0.5))
    ph = np.cumsum(f) / SR; s = 2 * (ph % 1.0) - 1
    y = sum(g * bp(s, fc * 0.85, fc * 1.15, 2) for fc, g in vowel)
    return y * np.sin(np.pi * t / d) ** 1.5


VOW = [((700, 1.0), (1100, 0.6), (2500, 0.2)), ((400, 1.0), (2000, 0.5), (2800, 0.2)), ((300, 1.0), (800, 0.6), (2300, 0.2)), ((550, 1.0), (1700, 0.6), (2500, 0.2))]


def crowd(dur, people, base_lo, base_hi):
    n = int(dur * SR); y = np.zeros(n)
    for _ in range(people):
        f0 = rng.uniform(base_lo, base_hi); pos = rng.uniform(0, dur - 1)
        while pos < dur - 0.5:
            d = rng.uniform(0.09, 0.22); s = syllable(f0 * rng.uniform(0.9, 1.15), d, VOW[rng.integers(4)])
            i = int(pos * SR); m = min(len(s), n - i); y[i:i + m] += s[:m] * rng.uniform(0.3, 1.0)
            pos += d + (rng.uniform(0.02, 0.15) if rng.random() < 0.8 else rng.uniform(0.4, 1.4))
    return y


# ---- crowd murmur (market square) and quieter streets
c = crowd(14.0, 26, 95, 230); c = lp(c, 3200) + 0.05 * lp(noise(len(c)), 900)
save("market_crowd_loop", seamless(c), 0.55)
c = crowd(12.0, 8, 100, 220); c = lp(c, 3000)
save("street_murmur_loop", seamless(c), 0.45)

# ---- work sounds
t = tt(0.5)
for i in range(3):  # scrubbing cloth on stone with water
    n = noise(len(t)); s = bp(n, 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)) * np.sin(np.pi * t / 0.5) ** 0.7
    s += 0.35 * lp(noise(len(t)), 700) * ex(t, 0.3) * (rng.random(len(t)) > 0.99)
    save(f"scrub_{i}" if i else "scrub", s, 0.5)
t = tt(0.7)
save("sweep", bp(noise(len(t)), 1800, 7000) * (np.sin(np.pi * t / 0.7) ** 1.3), 0.4)
t = tt(0.22)
save("chop", np.sin(2 * np.pi * 180 * t * (1 + ex(t, 0.02))) * ex(t, 0.05) + 0.8 * bp(noise(len(t)), 1500, 5000) * ex(t, 0.012), 0.8)
t = tt(0.4)
save("knead", lp(noise(len(t)), 500) * np.sin(np.pi * t / 0.4) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)), 0.5)
t = tt(0.9)
save("pot_clink", sum(np.sin(2 * np.pi * f * t) * ex(t, d) * g for f, d, g in [(1240, 0.25, 1), (1870, 0.18, 0.6), (2650, 0.1, 0.4)]) + 0.3 * hp(noise(len(t)), 3000) * ex(t, 0.01), 0.55)
t = tt(0.6)
save("coin_clink", sum(np.sin(2 * np.pi * f * t) * ex(t, d) * g for f, d, g in [(3100, 0.12, 1), (4200, 0.09, 0.7), (5300, 0.07, 0.5)]) * (1 + 0.4 * (t > 0.09) * np.sin(2 * np.pi * 3100 * t) ), 0.5)
t = tt(0.25)
save("tink", sum(np.sin(2 * np.pi * f * t) * ex(t, d) for f, d in [(2400, 0.08), (3700, 0.05)]) + 0.4 * hp(noise(len(t)), 4000) * ex(t, 0.008), 0.55)
t = tt(0.5)
save("cloth_flap", bp(noise(len(t)), 150, 1500) * ex(t, 0.12) * (0.6 + 0.4 * np.sin(2 * np.pi * 20 * t)), 0.55)

# ---- ambience loops
t = tt(8.0)
w = lp(noise(len(t)), 3500) * (0.6 + 0.4 * lp(noise(len(t)), 8)); w = hp(w, 400)
save("water_splash_loop", seamless(w), 0.5)
t = tt(6.0)
z = hp(noise(len(t)), 1800) * (0.5 + 0.5 * lp(noise(len(t)), 25)) ** 1.5
z += 0.4 * bp(noise(len(t)), 300, 900) * (rng.random(len(t)) > 0.995)
save("sizzle_loop", seamless(z), 0.4)
t = tt(4.0)
fire = lp(noise(len(t)), 1200) * 0.4 + np.where(rng.random(len(t)) > 0.9985, noise(len(t)) * 3, 0) * ex(np.arange(len(t)) % 600 / SR, 0.01)
save("fire_crackle_loop", seamless(lp(fire, 5000)), 0.45)

# ---- animals / people of the bazaar
t = tt(0.9)
f = 700 + 500 * ex(t, 0.2) * np.sin(2 * np.pi * 9 * t)
save("goat_bleat", (syllable(420, 0.9, ((900, 1), (1600, 0.7), (2600, 0.3))) * (1 + 0.5 * np.sin(2 * np.pi * 28 * t))), 0.7)
y = np.zeros(int(1.0 * SR))
for k, (st, d, f0) in enumerate([(0.0, 0.12, 650), (0.15, 0.1, 800), (0.3, 0.1, 700), (0.5, 0.35, 900)]):
    s = syllable(f0, d, ((1200, 1), (2400, 0.6), (3500, 0.3))); i = int(st * SR); y[i:i + len(s)] += s
save("hen_cluck", y, 0.55)
y = np.zeros(int(1.6 * SR))
for k in range(5):
    s = syllable(520 + 60 * (k % 2), 0.16, ((900, 1), (2500, 0.6))) * 1.0; i = int((0.05 + k * 0.2) * SR); y[i:i + len(s)] += s
save("child_laugh", y * (1 + 0.5 * np.sin(2 * np.pi * 9 * tt(1.6))), 0.55)
t = tt(2.5)
save("cart_creak", bp(noise(len(t)), 300, 1100) * (0.4 + 0.6 * np.sin(2 * np.pi * 3.2 * t) ** 2) * np.sin(np.pi * t / 2.5) ** 0.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 47 * t)), 0.45)
t = tt(1.4)
save("bicycle_bell", sum(np.sin(2 * np.pi * f * t) * ex(t, 0.5) for f in (2700, 3400)) * (1 + 0.7 * np.sin(2 * np.pi * 24 * t) * ex(t, 0.4)), 0.5)

# ---- street music: a simple bansuri-like flute over a drone and a hand drum
bpm_t = tt(24.0); n = len(bpm_t)
scale = [293.7, 329.6, 370.0, 392.0, 440.0, 493.9, 587.3]   # D major-ish pentatonic neighbours
mel = np.zeros(n); pos = 0.0
seq = [0, 2, 4, 3, 2, 0, 1, 2, 4, 5, 4, 2, 3, 2, 1, 0]
for k, si in enumerate(seq * 2):
    d = [0.9, 0.9, 1.4, 0.7, 0.7, 1.4, 0.9, 0.9, 1.4, 0.9, 0.7, 0.7, 0.9, 0.9, 0.9, 1.5][k % 16]
    nn = int(d * SR); tt_ = np.arange(nn) / SR; fr = scale[si] * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * tt_))
    ph = np.cumsum(fr) / SR
    note = (np.sin(2 * np.pi * ph) + 0.25 * np.sin(4 * np.pi * ph) + 0.08 * np.sin(6 * np.pi * ph)) * np.minimum(1, tt_ / 0.08) * ex(np.maximum(tt_ - d * 0.6, 0), 0.25)
    note += 0.03 * hp(noise(nn), 3000)
    i = int(pos * SR)
    if i >= n: break
    m = min(nn, n - i); mel[i:i + m] += note[:m]; pos += d
drone = np.sin(2 * np.pi * 146.8 * bpm_t) * 0.5 + np.sin(2 * np.pi * 220.0 * bpm_t) * 0.3
drum = np.zeros(n)
for b in np.arange(0, 24.0, 0.5):
    tt_ = tt(0.3); hitv = (np.sin(2 * np.pi * (110 if int(b * 2) % 4 else 160) * tt_ * (1 + ex(tt_, 0.04))) * ex(tt_, 0.09)) * (1.0 if int(b * 2) % 2 == 0 else 0.5)
    i = int(b * SR); drum[i:i + len(hitv)] += hitv[: n - i]
music = 0.8 * mel + 0.25 * drone + 0.35 * drum
save("music_bazaar", seamless(lp(music, 6000), 0.5), 0.6)
print("market audio done")
