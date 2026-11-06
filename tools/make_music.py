"""
Synthesises Indian classical style music and the larger sound effects as 16-bit mono WAV.

Instruments are built from first principles, so the audio is original:
  sitar    Karplus-Strong plucked string with a bright pluck, a "jawari" buzz
           (soft clipping of the upper partials) and occasional meend (pitch glide)
  tanpura  slow Karplus-Strong plucks on Pa, Sa, Sa, low Sa, with long decay
  tabla    dayan strokes (tuned, ringing: na, tin, ta) and bayan strokes (low with an
           upward pitch glide: ge; dry slap: ka); dha = na + ge, dhin = tin + ge
  reverb   exponentially decaying noise impulse response, applied by FFT convolution

Raag Bhupali (Sa Re Ga Pa Dha), tonic Sa = D (146.83 Hz).

Outputs in godot/assets/audio/:
  music_menu.wav   slow alaap: sitar phrases over tanpura (loops seamlessly)
  music_loop.wav   gameplay: sitar gat over tabla in keherwa (8 beats) and tanpura
  impact.wav       fight hit: low boom, crack and a metallic ring
  six.wav          a bright sitar strum with a tabla flourish
  victory.wav      a tihai (phrase played three times) ending on Sa with a gong

Run: python3 tools/make_music.py
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "audio")
rng = np.random.default_rng(11)

SA = 146.83
# Bhupali scale degrees as frequency ratios (just intonation) across three octaves.
DEGREES = {"S": 1.0, "R": 9 / 8, "G": 5 / 4, "P": 3 / 2, "D": 5 / 3}


def note(name):
    """'S', 'R', 'G', 'P', 'D' with ' (upper octave) or . (lower octave) suffixes."""
    base = DEGREES[name[0]]
    octave = name.count("'") - name.count(".")
    return SA * 2 * base * (2 ** octave)


def write(name, samples, peak=0.85):
    x = np.asarray(samples, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("wrote", os.path.relpath(path), round(len(x) / RATE, 2), "s")


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def env(n, rate):
    return np.exp(-np.arange(n) / RATE * rate)


# --- instruments --------------------------------------------------------------------

def pluck(freq, seconds, damping=0.996, brightness=0.6, glide_to=None):
    """Karplus-Strong string. Processed one period at a time, so it stays fast in numpy."""
    n = int(seconds * RATE)
    period = max(2, int(round(RATE / freq)))
    burst = rng.uniform(-1, 1, period)
    burst = burst - brightness * np.roll(burst, 1) * 0.5     # brighter pluck
    out = np.zeros(n + period)
    out[:period] = burst
    pos = period
    while pos < n:
        prev = out[pos - period:pos]
        block = damping * 0.5 * (prev + np.concatenate(([out[pos - period - 1] if pos > period else 0.0], prev[:-1])))
        end = min(pos + period, n + period)
        out[pos:end] = block[:end - pos]
        pos += period
    y = out[:n]
    if glide_to:
        # Meend: resample along a smooth pitch curve.
        ratio = np.linspace(1.0, glide_to / freq, n) ** 0.5
        idx = np.cumsum(ratio)
        idx = idx[idx < n - 1]
        y = np.interp(idx, np.arange(n), y)
        y = np.pad(y, (0, n - len(y)))
    return y


def sitar(freq, seconds, glide_to=None):
    s = pluck(freq, seconds, damping=0.9975, brightness=0.9, glide_to=glide_to)
    buzz = np.tanh(s * 3.0) - s * 0.6          # jawari: bright buzzing partials
    sympathetic = pluck(freq * 2, seconds, damping=0.999, brightness=0.2) * 0.12
    attack = np.minimum(1.0, np.arange(len(s)) / (RATE * 0.003))
    return (s + buzz * 0.5 + sympathetic) * attack


def tanpura(freq, seconds):
    s = pluck(freq, seconds, damping=0.9993, brightness=0.3)
    s2 = pluck(freq * 1.003, seconds, damping=0.9993, brightness=0.3)  # slight chorus
    return np.tanh((s + s2) * 1.5) * 0.5


def tone_drum(f0, f1, seconds, decay, harmonics=((1, 1.0),)):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    freq = f1 + (f0 - f1) * np.exp(-t * 18)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    x = sum(a * np.sin(h * phase) for h, a in harmonics)
    return x * env(n, decay)


def click(seconds, cutoff, decay):
    n = int(seconds * RATE)
    return lowpass(rng.uniform(-1, 1, n), cutoff) * env(n, decay)


def tabla(stroke):
    dayan_f = SA * 2  # dayan tuned to Sa
    harm = ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15))
    if stroke == "na":
        return mix(tone_drum(dayan_f * 1.02, dayan_f, 0.5, 9, harm) * 0.8, click(0.03, 6000, 120) * 0.4)
    if stroke == "tin":
        return tone_drum(dayan_f, dayan_f, 0.7, 5, ((1, 1.0), (2, 0.25))) * 0.6
    if stroke == "ta":
        return mix(tone_drum(dayan_f * 1.05, dayan_f, 0.25, 22, harm) * 0.7, click(0.02, 8000, 150) * 0.5)
    if stroke == "ge":
        return tone_drum(70, 95, 0.8, 4.5, ((1, 1.0), (2, 0.2))) * 1.0
    if stroke == "ka":
        return click(0.08, 900, 45) * 0.9
    if stroke == "dha":
        return mix(tabla("na"), tabla("ge"))
    if stroke == "dhin":
        return mix(tabla("tin"), tabla("ge"))
    if stroke == "ti":
        return tabla("ta") * 0.8
    return np.zeros(1)


def mix(a, b):
    n = max(len(a), len(b))
    return np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b)))


def place(buf, sound, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    end = min(len(buf), start + len(sound))
    if start < len(buf):
        buf[start:end] += sound[:end - start] * gain


def reverb(x, seconds=1.8, wet=0.25):
    n = int(seconds * RATE)
    ir = rng.uniform(-1, 1, n) * env(n, 3.2)
    ir = lowpass(ir, 5000)
    ir[0] = 0
    size = 1
    while size < len(x) + n:
        size *= 2
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x) + n]
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    out = np.pad(x, (0, n)) * (1 - wet) + y * wet
    return out


def fold_loop(x, loop_seconds):
    """Makes a buffer loop seamlessly: whatever rings past the end is added to the start."""
    n = int(loop_seconds * RATE)
    out = x[:n].copy()
    tail = x[n:]
    while len(tail):
        k = min(n, len(tail))
        out[:k] += tail[:k]
        tail = tail[k:]
    # A 6 ms dip at the seam removes any click where the loop restarts.
    m = int(0.006 * RATE)
    out[:m] *= np.linspace(0.0, 1.0, m)
    out[-m:] *= np.linspace(1.0, 0.0, m)
    return out


# --- pieces -------------------------------------------------------------------------

def tanpura_bed(buf, seconds, cycle=4.0):
    pattern = [("P.", 0.0), ("S", 1.0), ("S", 2.0), ("S.", 3.0)]
    t = 0.0
    while t < seconds:
        for name, offset in pattern:
            place(buf, tanpura(note(name) / 2, 5.0), t + offset * cycle / 4, 0.22)
        t += cycle


def music_menu():
    seconds = 24.0
    buf = np.zeros(int((seconds + 6) * RATE))
    tanpura_bed(buf, seconds)
    # Slow alaap phrases: (note, start, length, glide target or None)
    phrase = [
        ("S", 0.5, 2.0, None), ("R", 2.4, 1.2, None), ("G", 3.5, 2.2, "R"),
        ("P", 6.0, 1.4, None), ("G", 7.3, 1.0, None), ("D", 8.4, 2.4, "P"),
        ("S'", 11.0, 2.6, None), ("D", 13.4, 1.0, None), ("P", 14.4, 1.4, None),
        ("G", 15.9, 1.6, "R"), ("R", 17.6, 1.2, None), ("S", 18.9, 3.6, None),
    ]
    for name, start, length, glide in phrase:
        f = note(name)
        place(buf, sitar(f, length + 1.5, note(glide) if glide else None), start, 0.5)
    return fold_loop(reverb(buf, 2.2, 0.3), seconds)


def music_game():
    beat = 0.6               # 100 bpm
    bars = 6                 # 6 cycles of keherwa (8 beats each)
    seconds = beat * 8 * bars
    buf = np.zeros(int((seconds + 6) * RATE))
    tanpura_bed(buf, seconds, cycle=beat * 8)
    keherwa = ["dha", "ge", "na", "ti", "na", "ka", "dhin", "na"]
    for bar in range(bars):
        for i, stroke in enumerate(keherwa):
            t = (bar * 8 + i) * beat
            place(buf, tabla(stroke), t, 0.55 if i in (0, 6) else 0.42)
            if bar % 2 == 1 and i in (3, 7):          # off-beat ornament
                place(buf, tabla("ta"), t + beat / 2, 0.25)
    # Gat: a two-bar sitar melody, played with variations over the six bars.
    gat = [
        ["S", "R", "G", "-", "P", "G", "R", "S"],
        ["D.", "S", "R", "G", "R", "-", "S", "-"],
        ["G", "P", "D", "-", "S'", "D", "P", "G"],
        ["P", "G", "R", "G", "R", "S", "D.", "S"],
        ["G", "G", "P", "D", "S'", "-", "R'", "S'"],
        ["D", "P", "G", "R", "S", "R", "S", "-"],
    ]
    for bar, line in enumerate(gat):
        for i, name in enumerate(line):
            if name == "-":
                continue
            t = (bar * 8 + i) * beat
            glide = None
            if i == 7 and bar % 2 == 1:
                glide = note("S")
            place(buf, sitar(note(name), beat * 2.4, glide), t + 0.01, 0.45)
            if i % 2 == 0:  # chikari: a quick high drone stroke between melody notes
                place(buf, pluck(note("S'") * 2, 0.4, 0.99, 0.9) * 0.12, t + beat / 2, 1.0)
    return fold_loop(reverb(buf, 1.6, 0.22), seconds)


def impact():
    n = int(0.9 * RATE)
    t = np.arange(n) / RATE
    boom = np.sin(2 * np.pi * (45 + 80 * np.exp(-t * 25)) * t) * env(n, 5)
    crack = click(0.12, 7000, 40)
    ring_n = int(0.9 * RATE)
    ring = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((523, 0.4), (1307, 0.25), (2093, 0.15))) * env(ring_n, 5)
    return mix(mix(boom * 1.2, crack * 0.8), ring * 0.4)


def six():
    buf = np.zeros(int(1.6 * RATE))
    for i, name in enumerate(["S", "G", "P", "S'"]):
        place(buf, sitar(note(name), 1.2), i * 0.045, 0.5)
    for i, stroke in enumerate(["ti", "ta", "dha"]):
        place(buf, tabla(stroke), 0.25 + i * 0.12, 0.6)
    return reverb(buf, 1.0, 0.2)


def gong(seconds=3.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    partials = ((82, 1.0), (164.5, 0.6), (231, 0.45), (311, 0.35), (437, 0.25), (603, 0.15))
    x = sum(a * np.sin(2 * np.pi * f * t * (1 + 0.002 * np.sin(2 * np.pi * 0.7 * t))) for f, a in partials)
    swell = np.minimum(1.0, t / 0.02)
    return x * env(n, 1.2) * swell


def victory():
    beat = 0.22
    phrase = ["S", "R", "G", "P", "D", "S'"]
    buf = np.zeros(int(6.0 * RATE))
    t = 0.0
    for rep in range(3):  # tihai: the phrase three times, landing on Sa
        for name in phrase:
            place(buf, sitar(note(name), 0.9), t, 0.45)
            place(buf, tabla("na" if name != "S'" else "dha"), t, 0.35)
            t += beat
        t += beat
    place(buf, sitar(note("S'"), 2.5), t, 0.6)
    place(buf, tabla("dha"), t, 0.7)
    place(buf, gong(3.0), t, 0.6)
    return reverb(buf, 2.0, 0.3)


def main():
    os.makedirs(OUT, exist_ok=True)
    write("music_menu", music_menu(), 0.6)
    write("music_loop", music_game(), 0.6)
    write("impact", impact())
    write("six", six())
    write("victory", victory())


if __name__ == "__main__":
    main()
