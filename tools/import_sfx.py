"""
Converts recorded CC0 sound packs into the game's sound effect variants.

Each game event gets several recorded variants (picked at random in game, so repeats
never sound mechanical). Every file is trimmed of leading silence, peak-normalised to
a per-event level, given a short fade-out and written as Ogg Vorbis.

Sources (all CC0 1.0, from opengameart.org; see docs/CREDITS.md):
  kenney_casino-audio.zip          Kenney, "Casino Audio"
  kenney_interfaceSounds.zip       Kenney, "Interface Sounds"
  RPGsounds_Kenney.zip             Kenney, "50 RPG Sound Effects"
  independent_nu_ljudbank-hits_and_punches.7z   Independent.nu, "37 Hits/Punches"
  impact_-_starninjas.zip          StarNinjas, "10 Impact/Shield Blocks"
  swishes.zip                      "Swishes Sound Pack"

Run: python3 tools/import_sfx.py <folder with the extracted packs>
"""
import os
import subprocess
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "audio", "sfx")

# event -> (peak level in dB, max seconds, [source files relative to the packs folder])
MAP = {
    "dice_shake": (-3, 0.55, ["x_kenney_casino-audio/Audio/dice-shake-1.ogg", "x_kenney_casino-audio/Audio/dice-shake-2.ogg",
                             "x_kenney_casino-audio/Audio/dice-shake-3.ogg"]),
    "dice_bounce": (-6, 0.6, ["x_kenney_casino-audio/Audio/die-throw-1.ogg", "x_kenney_casino-audio/Audio/die-throw-2.ogg",
                              "x_kenney_casino-audio/Audio/die-throw-3.ogg", "x_kenney_casino-audio/Audio/die-throw-4.ogg"]),
    "dice_land": (-2, 0.8, ["x_kenney_casino-audio/Audio/dice-throw-1.ogg", "x_kenney_casino-audio/Audio/dice-throw-2.ogg",
                            "x_kenney_casino-audio/Audio/dice-throw-3.ogg"]),
    "token_step": (-14, 0.35, ["x_RPGsounds_Kenney/OGG/footstep0%d.ogg" % i for i in range(10)]),
    "token_land": (-4, 0.4, ["x_kenney_casino-audio/Audio/chip-lay-1.ogg", "x_kenney_casino-audio/Audio/chip-lay-2.ogg",
                             "x_kenney_casino-audio/Audio/chip-lay-3.ogg", "x_kenney_casino-audio/Audio/chips-collide-1.ogg"]),
    "token_select": (-6, 0.5, ["x_kenney_interfaceSounds/Audio/select_00%d.ogg" % i for i in (1, 2, 3)]),
    "ui_click": (-6, 0.3, ["x_kenney_interfaceSounds/Audio/click_00%d.ogg" % i for i in (1, 2, 3, 4)]),
    "ui_open": (-6, 0.6, ["x_kenney_interfaceSounds/Audio/maximize_00%d.ogg" % i for i in (1, 2, 3)]),
    "ui_back": (-6, 0.6, ["x_kenney_interfaceSounds/Audio/back_00%d.ogg" % i for i in (1, 2, 3)]),
    "error": (-6, 0.6, ["x_kenney_interfaceSounds/Audio/error_00%d.ogg" % i for i in (1, 2, 3)]),
    "blade": (-3, 0.8, ["x_RPGsounds_Kenney/OGG/drawKnife%d.ogg" % i for i in (1, 2, 3)]),
    "swish": (-3, 0.4, ["x_swishes/swishes/swish-%d.wav" % i for i in (2, 3, 4, 7, 8, 9)]),
    "punch": (-1, 0.9, ["x_hits/hits/hit%02d.mp3.flac" % i for i in (20, 34, 33, 7, 8, 35)]),
    "kick": (-1, 0.9, ["x_hits/hits/hit%02d.mp3.flac" % i for i in (37, 24, 19, 36)]),
    "thud": (-2, 0.7, ["x_impact_-_starninjas/impact.%d.ogg" % i for i in (4, 5, 8, 10)]),
    "shield": (-5, 0.8, ["x_kenney_interfaceSounds/Audio/glass_00%d.ogg" % i for i in (1, 3, 6)]),
    "coins": (-4, 1.0, ["x_RPGsounds_Kenney/OGG/handleCoins.ogg", "x_RPGsounds_Kenney/OGG/handleCoins2.ogg"]),
    "confirm": (-5, 0.9, ["x_kenney_interfaceSounds/Audio/confirmation_00%d.ogg" % i for i in (1, 2, 3, 4)]),
}


def convert(src, dst, peak_db, max_seconds):
    # Pass 1: measure the peak after trimming silence.
    trim = "silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:%s" % max_seconds
    probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", src, "-af", trim + ",volumedetect", "-f", "null", "-"],
                           capture_output=True, text=True).stderr
    peak = 0.0
    for line in probe.splitlines():
        if "max_volume" in line:
            peak = float(line.split("max_volume:")[1].split("dB")[0])
    gain = peak_db - peak
    fade_start = max(0.0, max_seconds - 0.08)
    chain = "%s,volume=%.2fdB,afade=t=out:st=%.2f:d=0.08" % (trim, gain, fade_start)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-af", chain, "-ac", "1", "-ar", "44100",
                    "-c:a", "libvorbis", "-q:a", "5", dst], check=True)


def main():
    packs = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for event, (peak_db, max_seconds, files) in MAP.items():
        for i, rel in enumerate(files, 1):
            convert(os.path.join(packs, rel), os.path.join(OUT, "%s_%d.ogg" % (event, i)), peak_db, max_seconds)
        print("%-13s %d variants" % (event, len(files)))


if __name__ == "__main__":
    main()
