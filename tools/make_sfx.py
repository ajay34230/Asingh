"""
Synthesises the game's sound effects and background loop as 16-bit mono WAV files.
Every sound is generated here from sine waves, filtered noise and envelopes, so the
audio is original and carries no third-party licence.

Run: python3 tools/make_sfx.py   (writes godot/assets/audio/*.wav)
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env_exp(n, rate):
    return np.exp(-np.arange(n) / RATE * rate)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = a * acc + (1 - a) * x[i]
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(f0, f1, seconds):
    t = t_axis(seconds)
    f = np.linspace(f0, f1, len(t))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def write(name, samples, peak=0.9):
    samples = np.asarray(samples, dtype=np.float64)
    m = np.max(np.abs(samples)) or 1.0
    samples = samples / m * peak
    data = (samples * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", os.path.relpath(path), len(samples) / RATE, "s")


def dice_roll():
    total = 1.3
    x = np.zeros(int(RATE * total))
    for _ in range(9):
        start = int(rng.uniform(0.0, total - 0.08) * RATE)
        n = int(RATE * rng.uniform(0.02, 0.05))
        click = highpass(noise(n), 1800) * env_exp(n, 90)
        x[start:start + n] += click * rng.uniform(0.5, 1.0)
    return x


def dice_land():
    n = int(RATE * 0.5)
    thud = np.sin(2 * np.pi * 110 * t_axis(0.5)) * env_exp(n, 9)
    click = highpass(noise(n), 2500) * env_exp(n, 60) * 0.6
    return thud + click


def select_chime():
    n = int(RATE * 0.3)
    return sweep(880, 1320, 0.3) * env_exp(n, 9)


def step_tick():
    n = int(RATE * 0.09)
    return (np.sin(2 * np.pi * 620 * t_axis(0.09)) * 0.6 + highpass(noise(n), 3000) * 0.3) * env_exp(n, 40)


def jump_whoosh():
    n = int(RATE * 0.45)
    tone = sweep(320, 880, 0.45) * env_exp(n, 4) * 0.7
    air = lowpass(noise(n), 2200) * np.sin(np.pi * np.arange(n) / n) * 0.5
    return tone + air


def land_thump():
    n = int(RATE * 0.35)
    body = np.sin(2 * np.pi * 85 * t_axis(0.35)) * env_exp(n, 12)
    dust = lowpass(noise(n), 1400) * env_exp(n, 22) * 0.5
    return body + dust


def capture_crunch():
    n = int(RATE * 0.75)
    crunch = lowpass(noise(n), 3500) * env_exp(n, 6)
    drop = sweep(600, 110, 0.75) * env_exp(n, 4) * 0.8
    return crunch + drop


def finish_bell():
    n = int(RATE * 1.4)
    t = t_axis(1.4)
    partials = [(659, 1.0), (988, 0.5), (1318, 0.3), (1976, 0.12)]
    x = sum(a * np.sin(2 * np.pi * f * t) for f, a in partials)
    return x * env_exp(n, 2.2)


def victory_fanfare():
    notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5]
    gap = 0.16
    total = gap * len(notes) + 2.2
    x = np.zeros(int(RATE * total))
    for i, f in enumerate(notes):
        start = int(RATE * i * gap)
        n = int(RATE * 0.9)
        t = t_axis(0.9)
        tone = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * 2 * f * t)) * env_exp(n, 3.5)
        x[start:start + n] += tone * 0.6
    delay = int(RATE * 0.22)
    echoed = x.copy()
    echoed[delay:] += x[:-delay] * 0.35
    return echoed


def button_click():
    n = int(RATE * 0.06)
    return np.sin(2 * np.pi * 1800 * t_axis(0.06)) * env_exp(n, 60)


def background_loop():
    """16 s seamless loop: a soft drone with a slow pentatonic melody and a quiet tabla-like pulse."""
    seconds = 16.0
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    drone = (np.sin(2 * np.pi * 146.83 * t) + 0.5 * np.sin(2 * np.pi * 220.0 * t)) * 0.12
    pad_notes = [146.83, 164.81, 196.0, 220.0, 246.94]
    melody = np.zeros(n)
    note_len = 0.8
    seq = [0, 2, 3, 2, 4, 3, 1, 2, 0, 2, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3]
    for i in range(int(seconds / note_len)):
        f = pad_notes[seq[i % len(seq)]] * 2
        start = int(i * note_len * RATE)
        m = int(note_len * RATE)
        local = np.arange(m) / RATE
        tone = np.sin(2 * np.pi * f * local) * np.exp(-local * 3.0)
        end = min(start + m, n)
        melody[start:end] += tone[:end - start] * 0.18
    pulse = np.zeros(n)
    beat = 0.5
    for i in range(int(seconds / beat)):
        start = int(i * beat * RATE)
        m = int(0.12 * RATE)
        end = min(start + m, n)
        pulse[start:end] += (highpass(noise(end - start), 900) * env_exp(end - start, 35))[:end - start] * 0.12
    x = drone + melody + pulse
    fade = int(0.3 * RATE)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def main():
    os.makedirs(OUT, exist_ok=True)
    write("dice_roll", dice_roll())
    write("dice_land", dice_land())
    write("token_select", select_chime())
    write("token_step", step_tick(), 0.5)
    write("token_jump", jump_whoosh())
    write("token_land", land_thump())
    write("capture", capture_crunch())
    write("token_finish", finish_bell())
    write("victory", victory_fanfare())
    write("ui_click", button_click(), 0.5)
    write("music_loop", background_loop(), 0.5)


if __name__ == "__main__":
    main()
