# Voices and music

## Spoken dialogue
Every story line (about 130) and ambient NPC remark (about 60, in five voice types) is pre-rendered
as `assets/voice/<md5(text)[:12]>.ogg` with male and female neural voices (each character has a fixed
voice and speed, see `CAST` in `tools/render_voices.py`). At runtime `Sfx.speak` looks the clip up by the
line's text; if no clip exists (a dynamically built line) it falls back to the phone's own
text-to-speech, and finally to blips.
To re-render after changing dialogue: download `kokoro-v1.0.int8.onnx` and `voices-v1.0.bin` from
github.com/thewh1teagle/kokoro-onnx releases (model-files-v1.0), build espeak-ng, then
`python3 tools/render_voices.py <workdir>` (needs numpy, onnxruntime, ffmpeg). Existing clips are kept.
Lines containing numbers built at runtime (`%d`) are not pre-rendered.
Not verified: how the voices sound on the device (rendered and checked for length/loudness only).

## Music
Ambient day/night/village music plus mood loops that fade in over it: `race` (Sand Circuit),
`tension` (enemy within 22 m), `sacred` (temple), `mystery` (Sun Gate approach). Stingers: surprise,
discovery, victory, sad, danger, reveal (see `Sfx.sting`). Mood loops duck the ambient music.
