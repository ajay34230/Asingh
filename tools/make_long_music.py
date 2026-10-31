#!/usr/bin/env python3
"""Long, through-composed ambient music for The Lost Kingdom (own work, CC0; no third-party audio).
Each track is ~2.5 minutes: intro, theme, contrasting theme, varied theme, bridge, outro. Melodies are
generated from a seeded random walk over the raga/mode, so every track has its own tune and nothing loops
under 2 minutes. Output is OGG (via ffmpeg). Run: python3 tools/make_long_music.py assets/audio"""
import sys, os, subprocess, wave, tempfile
import numpy as np
from scipy.signal import lfilter, butter

SR = 22050
out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"


def lp(x, fc, o=2): b, a = butter(o, min(fc, SR * 0.45) / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)


MODES = {
    "hijaz": [1, 16 / 15, 5 / 4, 4 / 3, 3 / 2, 8 / 5, 9 / 5],
    "bhupali": [1, 9 / 8, 5 / 4, 3 / 2, 5 / 3],
    "kafi": [1, 9 / 8, 6 / 5, 4 / 3, 3 / 2, 5 / 3, 9 / 5],
    "pentminor": [1, 6 / 5, 4 / 3, 3 / 2, 9 / 5],
    "bhairav": [1, 16 / 15, 5 / 4, 4 / 3, 3 / 2, 8 / 5, 15 / 8],
}


def pluck(f, d, rng, bright=1.0):
    t = np.arange(int(d * SR)) / SR
    y = np.zeros(len(t))
    for k in range(1, 9):
        if f * k > 7000: break
        y += (1.0 / k ** 1.3) * np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6.28)) * np.exp(-t * (1.6 + 1.1 * k * (1.3 - 0.5 * bright)) / max(d, 0.5) * 2.2)
    y[:60] *= np.linspace(0, 1, 60)
    return y


def bell(f, d, rng):
    t = np.arange(int(d * SR)) / SR
    y = np.zeros(len(t))
    for r, a, tau in ((1, 1, 1.6), (2.76, .5, 1.0), (5.4, .25, .5), (.5, .3, 2.2)):
        y += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    y[:40] *= np.linspace(0, 1, 40)
    return y


def flute(f, d, rng):
    n = int(d * SR); t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 0.3)
    ph = np.cumsum(f * vib) / SR
    y = np.sin(2 * np.pi * ph) + 0.25 * np.sin(4 * np.pi * ph) + 0.08 * np.sin(6 * np.pi * ph)
    y += 0.07 * lp(rng.standard_normal(n), 3500)
    env = np.minimum(1, t / 0.07) * np.minimum(1, (d - t) / 0.18) * (0.8 + 0.2 * np.sin(np.pi * np.minimum(1, t / d)))
    return y * np.clip(env, 0, 1)


def thump(rng, f0=95):
    t = np.arange(int(0.38 * SR)) / SR
    return np.sin(2 * np.pi * (f0 - 35 * np.minimum(t, .2) / .2 * 0.8) * t) * np.exp(-t / 0.11)


def tick(rng):
    t = np.arange(int(0.12 * SR)) / SR
    return hp(rng.standard_normal(len(t)), 1800) * np.exp(-t / 0.025) * 0.35


def reverb(x, taps):
    r = np.zeros_like(x)
    for dl, g in taps:
        k = int(dl * SR); r[k:] += g * x[:-k]
    return x + r


def put(buf, snd, at, gain=1.0):
    s = int(at * SR)
    if s >= len(buf): return
    e = min(len(buf), s + len(snd))
    buf[s:e] += snd[: e - s] * gain


def compose(name, mode, root, bpm, seed, lead, accomp, perc, drone_db=1.0, dur=150.0):
    rng = np.random.default_rng(seed)
    sc = MODES[mode]; nd = len(sc)
    beat = 60.0 / bpm; bar = 4 * beat
    bars = int(dur / bar); total = bars * bar
    buf = np.zeros(int((total + 6) * SR))
    t = np.arange(len(buf)) / SR
    def fr(idx, octv=1):
        return root * octv * sc[idx % nd] * 2 ** (idx // nd)
    # drone: root + fifth, slow swell, drifts with the section
    for f, g in ((root / 2, .5), (root * .75, .28), (root, .16)):
        buf += drone_db * g * 0.5 * np.sin(2 * np.pi * f * t) * (0.65 + 0.35 * np.sin(2 * np.pi * t / 37.0 + f))
    # section plan (in bars)
    plan = [("intro", 3), ("A", 10), ("B", 10), ("A2", 10), ("bridge", 5), ("C", 8), ("A3", 6)]
    scale_tot = sum(p[1] for p in plan)
    sections = []; b0 = 0
    for nm, ln in plan:
        L = max(2, round(ln * bars / scale_tot)); sections.append((nm, b0, L)); b0 += L
    sections[-1] = (sections[-1][0], sections[-1][1], bars - sections[-1][1])
    # motif: stepwise random walk, ends on the tonic or fifth
    def motif(base, length, lift=0):
        idx = base; ev = []; pos = 0.0
        while pos < length * 4 - 0.5:
            step = int(rng.choice([-2, -1, -1, 0, 1, 1, 2, 3], p=[.08, .22, .15, .05, .22, .15, .08, .05]))
            idx = int(np.clip(idx + step, base - 3, base + 5 + lift))
            dur_b = float(rng.choice([.5, 1, 1, 1.5, 2], p=[.25, .3, .2, .1, .15]))
            if rng.random() < .12:
                pos += dur_b; continue
            ev.append((pos, idx, dur_b)); pos += dur_b
        ev[-1] = (ev[-1][0], base + (0 if rng.random() < .6 else 3 % nd), 2.0)
        return ev
    mA = motif(nd, 4); mB = motif(nd + 2, 4, 2); mC = motif(nd - 1, 4)
    def vary(ev, shift):
        return [(p, i + (shift if rng.random() < .35 else 0), d) for p, i, d in ev]
    for nm, b_start, L in sections:
        t0 = b_start * bar
        if nm == "intro":
            for k in range(L * 2):
                put(buf, bell(fr(nd + int(rng.integers(0, nd))), 3.5, rng) * .16, t0 + k * 2 * beat + rng.uniform(0, beat))
            continue
        if nm == "bridge":
            for k in range(L * 2):
                put(buf, pluck(fr(int(rng.integers(0, nd)) + nd, 1), 3.0, rng) * .22, t0 + k * 2 * beat)
            continue
        mot = {"A": mA, "B": mB, "A2": vary(mA, 1), "C": mC, "A3": mA}[nm]
        for ph in range(0, L, 4):
            bars_here = min(4, L - ph)
            m = mot if (ph // 4) % 2 == 0 else vary(mot, -1)
            for p, i, d in m:
                if p >= bars_here * 4: continue
                at = t0 + ph * bar + p * beat
                dd = d * beat
                if lead == "flute":
                    put(buf, flute(fr(i), dd + .25, rng) * .30, at)
                    if nm in ("B", "C"): put(buf, pluck(fr(i), 2.5, rng) * .14, at)
                else:
                    put(buf, pluck(fr(i), 3.2, rng, 1.0) * .36, at)
        # accompaniment: chord tones on a two-bar harmony
        prog = [0, 3 % nd, 4 % nd, 0]
        for bb in range(L):
            root_i = prog[(bb // 2) % 4]
            tones = [root_i, root_i + 2, root_i + 4]
            if accomp == "arp" and nm not in ("intro",):
                for q in range(8):
                    if nm in ("A", "A3") and q % 2 == 1: continue
                    put(buf, pluck(fr(tones[q % 3] % (2 * nd) + 0), 1.6, rng, .7) * .12, t0 + bb * bar + q * beat * .5)
            elif accomp == "pad" and bb % 2 == 0:
                for tn in tones:
                    f = fr(tn)
                    ts = np.arange(int(2 * bar * SR)) / SR
                    pdv = np.sin(2 * np.pi * f * ts) * np.sin(np.pi * ts / ts[-1]) ** 1.5 * .06
                    put(buf, pdv, t0 + bb * bar)
            # percussion
            if perc and nm in ("B", "A2", "C", "A3"):
                put(buf, thump(rng) * .30, t0 + bb * bar)
                put(buf, thump(rng, 110) * .18, t0 + bb * bar + 2.5 * beat)
                for q in (1, 3):
                    put(buf, tick(rng), t0 + bb * bar + q * beat)
            elif perc == "soft" and nm == "A":
                put(buf, thump(rng) * .2, t0 + bb * bar)
    buf = reverb(buf, ((.17, .38), (.29, .32), (.43, .26), (.61, .2), (.89, .14), (1.3, .08)))
    buf = lp(buf, 5200)
    buf = buf[: int((total + 4) * SR)]
    fade = int(3.0 * SR)
    buf[:int(2 * SR)] *= np.linspace(0, 1, int(2 * SR))
    buf[-fade:] *= np.linspace(1, 0, fade)
    buf = buf / (np.max(np.abs(buf)) or 1) * 0.62
    with tempfile.TemporaryDirectory() as td:
        wp = f"{td}/x.wav"
        with wave.open(wp, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((buf * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wp, "-c:a", "libvorbis", "-q:a", "2", f"{out}/{name}.ogg"], check=True)
    print(name, round(len(buf) / SR), "s", os.path.getsize(f"{out}/{name}.ogg") // 1024, "KB")


os.makedirs(out, exist_ok=True)
#          name           mode        root    bpm  seed lead     accomp perc
compose("music_day_1", "hijaz", 146.83, 84, 11, "flute", "pad", "soft")
compose("music_day_2", "bhairav", 164.81, 92, 23, "pluck", "arp", True)
compose("music_day_3", "kafi", 130.81, 72, 37, "flute", "arp", False)
compose("music_night_1", "pentminor", 110.0, 58, 41, "pluck", "pad", False, dur=140.0)
compose("music_night_2", "hijaz", 98.0, 54, 53, "flute", "pad", False, dur=150.0)
compose("music_village_1", "bhupali", 164.81, 96, 61, "pluck", "arp", "soft")
compose("music_village_2", "bhupali", 196.0, 80, 73, "flute", "arp", True)
