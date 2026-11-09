"""
Generates the spoken Hindi dialogue with Kokoro-82M (Apache-2.0 open-weight TTS).

Every line has the Devanagari text that is spoken and a romanised caption that the
game shows (speech bubbles and subtitles). Several variants per event keep it fresh.

Voices: announcer = hm_omega; each colour's token has its own voice.
Outputs godot/assets/audio/voice/<key>_<n>.ogg and godot/assets/audio/voice/lines.json.

Run with a Python that has `kokoro` and `soundfile` installed (Kokoro needs espeak-ng):
  python tools/make_voice.py              # everything
  python tools/make_voice.py --designs    # only the token-design victory lines
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf
from kokoro import KPipeline

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "audio", "voice")

ANNOUNCER = "hm_omega"
TOKEN_VOICES = {"blue": "hm_psi", "yellow": "hf_alpha", "green": "hf_beta", "red": "hm_omega"}

# key -> list of (spoken Hindi, caption)
# Wordings were chosen by transcribing each candidate with Whisper and keeping the clearest.
ANNOUNCER_LINES = {
    "start": [("चलो, खेल शुरू करते हैं!", "Chalo, khel shuru karte hain!"), ("खेल शुरू करते हैं!", "Khel shuru karte hain!")],
    "six": [("क्या बात है, छक्का आया!", "Kya baat hai, chhakka aaya!"), ("वाह! छक्का आया!", "Waah! Chhakka aaya!"),
            ("शानदार छक्का!", "Shaandaar chhakka!")],
    "capture": [("एक ही वार में!", "Ek hi vaar mein!"), ("गोटी कट गई!", "Goti kat gayi!"), ("घर वापस जाओ!", "Ghar wapas jao!")],
    "safe": [("यहाँ कोई नहीं मार सकता!", "Yahan koi nahin maar sakta!"), ("अब सुरक्षित हो!", "Ab surakshit ho!")],
    "home": [("शाबाश! एक गोटी घर पहुँची!", "Shabaash! Ek goti ghar pahunchi!"), ("बहुत बढ़िया!", "Bahut badhiya!")],
    "three_sixes": [("तीन छक्के, बारी गई!", "Teen chhakke, baari gayi!")],
    "no_move": [("अरे, कोई चाल नहीं!", "Arre, koi chaal nahin!")],
    "your_turn": [("आपकी बारी!", "Aapki baari!")],
    "win": [("जीत मुबारक हो!", "Jeet mubaarak ho!"), ("आप जीत गए!", "Aap jeet gaye!")],
    "lose": [("अगली बार ज़रूर!", "Agli baar zaroor!")],
    "ladder": [("सीढ़ी चढ़ गए!", "Seedhi chadh gaye!"), ("ऊपर चलो!", "Upar chalo!")],
    "snake": [("अरे, साँप ने काट लिया!", "Arre, saanp ne kaat liya!"), ("नीचे गिर गए!", "Neeche gir gaye!")],
    "shield": [("ढाल मिल गई!", "Dhaal mil gayi!")],
    "star": [("एक और मौका!", "Ek aur mauka!")],
    "replay": [("फिर से देखिए!", "Phir se dekhiye!")],
    "team_win": [("आपकी टीम जीत गई!", "Aapki team jeet gayi!")],
    "journey": [("नई यात्रा शुरू!", "Nayi yaatra shuru!")],
    "capture_blue": [("नीली गोटी का वार!", "Neeli goti ka vaar!")],
    "capture_yellow": [("पीली गोटी का वार!", "Peeli goti ka vaar!")],
    "capture_green": [("हरी गोटी का वार!", "Hari goti ka vaar!")],
    "capture_red": [("लाल गोटी का वार!", "Laal goti ka vaar!")],
}
TOKEN_LINES = {
    "taunt": [("ये लो एक!", "Ye lo ek!"), ("हट जाओ रास्ते से!", "Hat jao raaste se!"), ("तैयार हो जाओ!", "Taiyaar ho jao!")],
    "hurt": [("अरे नहीं!", "Arre nahin!"), ("बचाओ!", "Bachao!"), ("अरे बाप रे!", "Arre baap re!")],
    "cheer": [("मैं घर आ गया!", "Main ghar aa gaya!"), ("जय हो!", "Jai ho!")],
}

# Victory lines for token designs: design id -> (voice, spoken Hindi, caption).
DESIGN_LINES = {
    "design_rani": ("hf_alpha", "मैं अपनी झाँसी नहीं दूँगी!", "Main apni Jhansi nahin doongi!"),
    "design_hanuman": ("hm_omega", "जय बजरंगबली!", "Jai Bajrangbali!"),
    "design_garuda": ("hm_psi", "आसमान मेरा है!", "Aasmaan mera hai!"),
    "design_nataraja": ("hm_omega", "नटराज का तांडव!", "Nataraj ka taandav!"),
    "design_robo": ("hm_psi", "मिशन पूरा हुआ!", "Mission poora hua!"),
    "design_ghost": ("hf_beta", "इस महल में मेरा राज है!", "Is mahal mein mera raaj hai!"),
    "design_surya": ("hm_omega", "सूरज कभी नहीं डूबता!", "Suraj kabhi nahin doobta!"),
    "design_shadow": ("hm_psi", "अंधेरे की जीत!", "Andhere ki jeet!"),
    "design_maharaja": ("hm_omega", "राजा तो राजा है!", "Raja to raja hai!"),
    "design_warrior": ("hm_psi", "रणभूमि मेरी है!", "Ranbhoomi meri hai!"),
    "design_bollywood": ("hm_psi", "पिक्चर अभी बाकी है, दोस्त!", "Picture abhi baaki hai, dost!"),
    "design_cricket": ("hm_psi", "छक्का! मैच हमारा!", "Chhakka! Match hamara!"),
    "design_chai": ("hm_omega", "जीत की चाय हो जाए!", "Jeet ki chai ho jaaye!"),
    "design_lion": ("hm_omega", "जंगल का राजा कौन? मैं!", "Jungle ka raja kaun? Main!"),
    "design_tiger": ("hm_psi", "बाघ की दहाड़ सुनो!", "Baagh ki dahaad suno!"),
    "design_naga": ("hm_omega", "नागराज की जय!", "Naagraaj ki jai!"),
    "design_mughal": ("hm_omega", "शहंशाह की जीत!", "Shahenshah ki jeet!"),
    "design_maratha": ("hm_psi", "हर हर महादेव!", "Har Har Mahadev!"),
    "design_lotus": ("hf_beta", "कमल की तरह खिली जीत!", "Kamal ki tarah khili jeet!"),
    "design_peacock": ("hf_alpha", "मोर की शान देखो!", "Mor ki shaan dekho!"),
    "design_diya": ("hf_alpha", "शुभ दीपावली!", "Shubh Deepavali!"),
    "design_holi": ("hf_beta", "बुरा न मानो, होली है!", "Bura na mano, Holi hai!"),
    "design_tiranga": ("hm_omega", "जय हिंद!", "Jai Hind!"),
    "design_airavata": ("hm_omega", "ऐरावत जीत गया!", "Airavat jeet gaya!"),
    "design_monsoon": ("hf_beta", "जीत की बारिश!", "Jeet ki baarish!"),
}


def render(pipeline, text, voice, speed, path):
    audio = np.concatenate([a for _, _, a in pipeline(text, voice=voice, speed=speed)])
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        sf.write(tmp.name, audio, 24000)
    # Trim silence at the start, then at the end (reverse, trim the start, reverse back);
    # pauses inside a sentence are kept.
    trim = ("silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
            "silenceremove=start_periods=1:start_threshold=-45dB,areverse,apad=pad_dur=0.12")
    probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", tmp.name, "-af", trim + ",volumedetect", "-f", "null", "-"],
                           capture_output=True, text=True).stderr
    peak = next((float(l.split("max_volume:")[1].split("dB")[0]) for l in probe.splitlines() if "max_volume" in l), 0.0)
    # A touch of room so the voice sits in the palace, not in a booth.
    chain = "%s,volume=%.2fdB,aecho=0.8:0.5:40:0.12,highpass=f=80" % (trim, -2.0 - peak)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-af", chain, "-ac", "1",
                    "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.unlink(tmp.name)


def render_designs(pipeline):
    """Only the design victory lines, merged into the existing lines.json."""
    path = os.path.join(OUT, "lines.json")
    with open(path, encoding="utf-8") as f:
        table = json.load(f)
    table["design"] = {}
    for key, (voice, text, caption) in DESIGN_LINES.items():
        name = "%s_win" % key
        render(pipeline, text, voice, 1.05, os.path.join(OUT, name + ".ogg"))
        table["design"][key] = [{"file": name, "caption": caption, "text": text}]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=1)
    print("design lines written:", len(DESIGN_LINES))


def main():
    os.makedirs(OUT, exist_ok=True)
    pipeline = KPipeline(lang_code="h")
    if "--designs" in sys.argv:
        render_designs(pipeline)
        return
    table = {"announcer": {}, "token": {}}
    for key, lines in ANNOUNCER_LINES.items():
        table["announcer"][key] = []
        for i, (text, caption) in enumerate(lines, 1):
            name = "ann_%s_%d" % (key, i)
            render(pipeline, text, ANNOUNCER, 1.0, os.path.join(OUT, name + ".ogg"))
            table["announcer"][key].append({"file": name, "caption": caption, "text": text})
    for key, lines in TOKEN_LINES.items():
        table["token"][key] = {}
        for color, voice in TOKEN_VOICES.items():
            table["token"][key][color] = []
            for i, (text, caption) in enumerate(lines, 1):
                name = "%s_%s_%d" % (color, key, i)
                render(pipeline, text, voice, 1.1, os.path.join(OUT, name + ".ogg"))
                table["token"][key][color].append({"file": name, "caption": caption, "text": text})
    with open(os.path.join(OUT, "lines.json"), "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=1)
    render_designs(pipeline)
    print("voice lines written to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
