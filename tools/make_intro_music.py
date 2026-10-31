"""Old-style intro theme (procedural, CC0): tanpura drone, plucked sitar-like melody, bansuri flute,
frame drum and a warm gramophone/tape character. python3 tools/make_intro_music.py assets/audio"""
import sys, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
rng = np.random.default_rng(1957)
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
DUR = 28.0
N = int(DUR * SR)
t = np.arange(N) / SR


def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, f0, f1, o=2): b, a = butter(o, [f0 / (SR / 2), f1 / (SR / 2)], "band"); return lfilter(b, a, x)


def pluck(f, d, bright=0.5):
    """Karplus-Strong string with a slightly buzzy sitar bridge."""
    n = int(d * SR); p = max(2, int(SR / f)); buf = rng.uniform(-1, 1, p) * bright
    buf = lp(buf, 6000)
    y = np.zeros(n)
    for i in range(n):
        y[i] = buf[i % p]
        buf[i % p] = 0.4985 * (buf[i % p] + buf[(i + 1) % p])
    y *= np.exp(-np.arange(n) / SR / (d * 0.6))
    buzz = np.tanh(3.0 * y) * 0.5
    return y + buzz


def flute(f, d, vib=5.0):
    n = int(d * SR); tt = np.arange(n) / SR
    fr = f * (1 + 0.006 * np.sin(2 * np.pi * vib * tt) * np.minimum(1, tt / 0.4))
    ph = np.cumsum(fr) / SR * 2 * np.pi
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    y += 0.05 * bp(rng.standard_normal(n), f, f * 3)
    return y * np.minimum(1, tt / 0.12) * np.minimum(1, (d - tt) / 0.25)


mix = np.zeros(N)

# tanpura drone: Sa (D3) and Pa, plucked in a cycle, with the jawari shimmer
sa = 146.83
for k in range(int(DUR / 1.6)):
    for j, f in enumerate([sa * 1.5, sa * 2, sa * 2, sa]):
        s = pluck(f, 4.0, 0.9) * 0.5
        i = int((k * 1.6 + j * 0.4) * SR)
        if i + len(s) > N: s = s[: N - i]
        mix[i:i + len(s)] += s * 0.25

# melody in raga Bhairav-like scale (Sa re ga ma pa dha ni): D Eb F# G A Bb C#
sc = [sa * 2 * r for r in (1.0, 16 / 15, 5 / 4, 4 / 3, 3 / 2, 8 / 5, 15 / 8, 2.0)]
phrase = [(0, 1.2), (1, 0.6), (2, 0.6), (3, 1.2), (4, 1.8), (3, 0.6), (2, 0.6), (1, 1.2), (0, 2.4),
          (4, 0.8), (5, 0.8), (4, 0.8), (3, 0.8), (2, 1.6), (1, 0.8), (0, 2.0)]
pos = 2.0
for rep in range(2):
    for si, d in phrase:
        if pos > DUR - 3: break
        s = pluck(sc[si], d * 1.7, 0.7) * 0.9
        i = int(pos * SR); m = min(len(s), N - i); mix[i:i + m] += s[:m] * 0.55
        pos += d

# bansuri flute answers from 12 s: slow, breathy, an octave up
pos = 12.0
for si, d in [(4, 2.2), (5, 1.0), (4, 1.2), (3, 2.0), (2, 1.0), (1, 1.0), (0, 3.6), (2, 1.0), (4, 2.0), (7, 3.0)]:
    if pos > DUR - 2: break
    s = flute(sc[si] * 1.0, d + 0.3)
    i = int(pos * SR); m = min(len(s), N - i); mix[i:i + m] += s[:m] * 0.38
    pos += d

# soft frame drum from 8 s: dum . tak . dum dum tak .
for b in np.arange(8.0, DUR - 2, 0.75):
    k = int(round((b - 8.0) / 0.75)) % 8
    if k in (0, 4, 5):
        tt = np.arange(int(0.3 * SR)) / SR
        h = np.sin(2 * np.pi * (85 if k != 5 else 105) * tt * (1 + 1.5 * np.exp(-tt / 0.03))) * np.exp(-tt / 0.1) * 0.35
    elif k in (2, 7):
        tt = np.arange(int(0.12 * SR)) / SR
        h = bp(rng.standard_normal(len(tt)), 1200, 4500) * np.exp(-tt / 0.03) * 0.12
    else:
        continue
    i = int(b * SR); mix[i:i + len(h)] += h[: N - i]

# closing gong swell
tt = np.arange(int(5.0 * SR)) / SR
gong = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) * g for f, d, g in [(110, 2.5, 1), (164, 2.0, 0.6), (231, 1.5, 0.4), (329, 1.0, 0.25)])
i = N - len(gong) - int(0.5 * SR)
mix[i:i + len(gong)] += gong * 0.4

# vintage character: band-limit like an old gramophone, slow wow/flutter, a little crackle and hiss
mix = bp(mix, 120, 5200, 2)
wow = 1 + 0.0025 * np.sin(2 * np.pi * 0.7 * t) + 0.0012 * np.sin(2 * np.pi * 5.1 * t)
mix = np.interp(np.cumsum(wow) / wow.sum() * (N - 1), np.arange(N), mix)
crackle = np.where(rng.random(N) > 0.9993, rng.standard_normal(N) * 2.5, 0.0)
crackle = hp(crackle, 600) * 0.12
hiss = hp(rng.standard_normal(N), 3000) * 0.006
mix = np.tanh(mix * 1.4) + crackle + hiss
fade = np.minimum(1, t / 1.5) * np.minimum(1, (DUR - t) / 2.5)
mix = mix * fade
mix = mix / np.abs(mix).max() * 0.85
with wave.open(f"{out}/music_intro.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("intro music done", DUR)
