"""Render every spoken line to an Ogg Vorbis file with the Kokoro neural voice model.
   Models/binaries are not in the repo; see docs/VOICES.md. Usage:
   python3 tools/render_voices.py <workdir with kokoro.onnx, voices.bin, esp/> [limit]"""
import sys, os, re, hashlib, subprocess, importlib.util, json
import numpy as np
import onnxruntime as ort

W = sys.argv[1]
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 else 10**9
OUT = "assets/voice"
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, "tools")
import voice_lines

spec = importlib.util.spec_from_file_location("kcfg", f"{W}/kokoro-onnx/src/kokoro_onnx/config.py")
kcfg = importlib.util.module_from_spec(spec); spec.loader.exec_module(kcfg)
VOCAB = kcfg.DEFAULT_VOCAB
sess = ort.InferenceSession(f"{W}/kokoro.onnx", providers=["CPUExecutionProvider"])
VOICES = np.load(f"{W}/voices.bin")
ESP = f"{W}/esp/bin/espeak-ng"
env = dict(os.environ, ESPEAK_DATA_PATH=f"{W}/esp/share/espeak-ng-data")

# who -> (kokoro voice, speed)
CAST = {
    "Chief Bhairav": ("bm_george", 0.92), "Dr. Arin Rao": ("am_adam", 1.0), "Dhruv the blacksmith": ("am_fenrir", 0.95),
    "Kabir": ("am_michael", 1.0), "Hari the farmer": ("bm_lewis", 0.95), "Anita": ("af_sarah", 1.0),
    "Race Master Bhim": ("am_onyx", 1.0), "Arin's journal": ("am_adam", 0.9), "Mohan": ("am_eric", 1.0),
    "Elder Kamla": ("bf_alice", 0.88), "Meera the weaver": ("af_nicole", 0.95), "Imran the trader": ("am_puck", 1.05),
    "Merchant": ("bm_fable", 1.0), "Dev the potter": ("am_echo", 1.0), "Old Ganesh": ("bm_lewis", 0.88),
    "Chhoti": ("af_sky", 1.12), "Bholu": ("am_liam", 1.1), "Pandit Rishi": ("bm_daniel", 0.92), "Shanta": ("bf_isabella", 0.95),
    "Roshni": ("af_bella", 1.0), "Scholar Vikram": ("am_michael", 0.98), "Guard Veer": ("am_onyx", 1.0), "Guard Shera": ("af_heart", 1.0),
    "The map table": ("bm_george", 0.9), "You": ("am_michael", 1.0), "Reaver Garr": ("bm_lewis", 0.95), "Reaver Naag": ("am_eric", 1.0), "Tara": ("af_heart", 0.98), "Salim": ("am_eric", 1.0), "Villager": ("am_liam", 1.0), "Raju": ("am_liam", 1.05),
    "Old Lakshmi": ("bf_emma", 0.88), "Pinky": ("af_sky", 1.1), "Traveller": ("af_heart", 1.0), "Narrator": ("bm_george", 0.92),
}
BARK = {"man": ("am_michael", 1.0), "deep": ("am_onyx", 0.95), "old": ("bm_lewis", 0.88), "woman": ("af_bella", 1.0), "girl": ("af_sky", 1.12)}
PUNCT = ",.;:!?"


def phonemize(text):
    text = text.replace("’", "'").replace("—", ", ").replace("...", ", ").replace("…", ", ").replace("[CLANG]", "")
    text = text.replace("Dr.", "Doctor")
    parts = re.split(r"([,.;:!?])", text)
    out = ""
    for part in parts:
        if part in PUNCT and part:
            out = out.rstrip() + part + " "
        elif part.strip():
            r = subprocess.run([ESP, "-q", "--ipa", "-v", "en-us", part.strip()], capture_output=True, text=True, env=env)
            ph = " ".join(r.stdout.split()).replace("‍", "").replace("_", "")
            out += ph
    return "".join(c for c in out if c in VOCAB).strip()


def synth(text, voice, speed):
    ph = phonemize(text)[:500]
    toks = [VOCAB[c] for c in ph if c in VOCAB]
    style = VOICES[voice][min(len(toks), len(VOICES[voice])) - 1]
    a = sess.run(None, {"tokens": np.array([[0, *toks, 0]], np.int64), "style": np.asarray(style, np.float32).reshape(1, 256), "speed": np.array([speed], np.float32)})[0].ravel()
    return a


def save(key, audio):
    raw = f"{OUT}/{key}.raw"
    (audio * 32767).clip(-32768, 32767).astype(np.int16).tofile(raw)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", raw,
                    "-af", "silenceremove=start_periods=1:start_threshold=-50dB,loudnorm=I=-18:TP=-2", "-c:a", "libvorbis", "-q:a", "3", f"{OUT}/{key}.ogg"], check=True)
    os.remove(raw)


def key_of(text, voice_type=None):
    s = text if voice_type is None else voice_type + "|" + text
    return hashlib.md5(s.encode()).hexdigest()[:12]


jobs = []
for who, text in voice_lines.story_lines():
    v, sp = CAST.get(who, ("am_michael", 1.0))
    jobs.append((key_of(text), text, v, sp))
for text in voice_lines.bark_lines():
    for vt, (v, sp) in BARK.items():
        jobs.append((key_of(text, vt), text, v, sp))
for text in voice_lines.enemy_lines():
    for vt in ("deep", "man"):
        v, sp = BARK[vt]
        jobs.append((key_of(text, vt), text, v, sp))
manifest = {}
n = 0
for key, text, v, sp in jobs:
    if os.path.exists(f"{OUT}/{key}.ogg"):
        manifest[key] = text
        continue
    if n >= LIMIT:
        break
    try:
        save(key, synth(text, v, sp))
        manifest[key] = text
        n += 1
        print(n, len(jobs), v, text[:50], flush=True)
    except Exception as e:
        print("FAIL", text[:40], e, flush=True)
json.dump(manifest, open(f"{OUT}/manifest.json", "w"), indent=0)
print("done", len(manifest), "clips")
