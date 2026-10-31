"""Render the Hindi lines (data/hindi.json) with Kokoro's Hindi voices.
   Usage: python3 tools/render_voices_hi.py <workdir> [limit]   (same workdir as render_voices.py)
   Clips are named assets/voice/<md5(hindi text)[:12]>.ogg (story) or md5(voice_type|text) (ambient)."""
import sys, os, json, re, hashlib, subprocess
src = open(os.path.join(os.path.dirname(__file__), "render_voices.py"), encoding="utf-8").read()
exec(compile(src.split("jobs = []")[0], "render_voices_prefix", "exec"))   # sess, VOICES, save, key_of, CAST ...

HI_M = ["hm_omega", "hm_psi"]
HI_F = ["hf_alpha", "hf_beta"]


def hi_voice(kokoro_voice, who):
    female = kokoro_voice[1] == "f"
    pool = HI_F if female else HI_M
    return pool[int(hashlib.md5(who.encode()).hexdigest(), 16) % 2]


def phonemize_hi(text):
    text = text.replace("।", ".").replace("...", ", ").replace("[ठक-ठक]", "").replace("—", ", ")
    parts = re.split(r"([,.;:!?])", text)
    out = ""
    for part in parts:
        if part in PUNCT and part:
            out = out.rstrip() + part + " "
        elif part.strip():
            r = subprocess.run([ESP, "-q", "--ipa", "-v", "hi", part.strip()], capture_output=True, text=True, env=env)
            ph = " ".join(r.stdout.split()).replace("‍", "").replace("_", "")
            out += ph
    return "".join(c for c in out if c in VOCAB).strip()


phonemize = phonemize_hi          # synth() looks the name up at call time

TR = json.load(open("data/hindi.json", encoding="utf-8"))
jobs = []
for who, text in voice_lines.story_lines():
    v, sp = CAST.get(who, ("am_michael", 1.0))
    hv = hi_voice(v, who)
    jobs.append((key_of(TR[text]), TR[text], hv, min(sp, 1.0) * 0.95))
# Ambient chatter: render one male ("man") and one female ("woman") clip per line, then reuse them for
# the other voice types (deep/old share the male clip, girl shares the female one) to halve render time.
ALIAS = {"deep": "man", "old": "man", "girl": "woman"}
for text in voice_lines.bark_lines() + voice_lines.enemy_lines():
    for vt in ("man", "woman"):
        v, sp = BARK[vt]
        jobs.append((key_of(TR[text], vt), TR[text], hi_voice(v, vt), sp * 0.95))
import shutil
def make_aliases():
    for text in voice_lines.bark_lines() + voice_lines.enemy_lines():
        for vt, base in ALIAS.items():
            a, b = f"{OUT}/{key_of(TR[text], base)}.ogg", f"{OUT}/{key_of(TR[text], vt)}.ogg"
            if os.path.exists(a) and not os.path.exists(b):
                shutil.copyfile(a, b)
n = 0
for key, text, v, sp in jobs:
    if os.path.exists(f"{OUT}/{key}.ogg"):
        continue
    if n >= LIMIT:
        break
    try:
        save(key, synth(text, v, sp))
        n += 1
        print(n, len(jobs), v, text[:40], flush=True)
    except Exception as e:
        print("FAIL", text[:40], e, flush=True)
make_aliases()
print("done", n, "new clips of", len(jobs))
