"""Collect every spoken line in the game from the GDScript sources.
Returns (story_lines, bark_lines): story_lines = [(speaker, text)], bark_lines = [text]."""
import re, glob, os

STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
SPOKEN = re.compile(r"^[A-Z\"'(‘“].{14,}[.!?…\"')]$")
STORY_FILES = ["story.gd", "story_builder.gd", "story_links.gd", "race_builder.gd", "combat_builder.gd", "water_builder.gd", "temple_builder.gd"]


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", " ").replace("\\'", "'")


def story_lines(root="scripts"):
    out = []
    for fn in STORY_FILES:
        p = os.path.join(root, fn)
        if not os.path.exists(p):
            continue
        src = open(p, encoding="utf-8").read()
        speaker = "Narrator"
        for m in re.finditer(r'(?:_small\(\s*"([^"]+)"\s*,\s*\[((?:[^\]])*)\]|"who":\s*"([^"]+)"|var w := "([^"]+)"|(?:"text"|text):\s*"((?:[^"\\]|\\.)*)"|_simple\(\s*\w+\s*,\s*"((?:[^"\\]|\\.)*)")', src):
            if m.group(1):
                for s in STR.findall(m.group(2)):
                    t = unescape(s)
                    if SPOKEN.match(t) and "%" not in t:
                        out.append((m.group(1), t))
            elif m.group(3) or m.group(4):
                speaker = m.group(3) or m.group(4)
            elif m.group(5):
                t = unescape(m.group(5))
                if SPOKEN.match(t) and "%" not in t:
                    out.append((speaker, t))
            elif m.group(6):
                t = unescape(m.group(6))
                if SPOKEN.match(t) and "%" not in t:
                    out.append((speaker, t))
    seen = {}
    for sp, t in out:
        seen.setdefault(t, sp)
    return [(sp, t) for t, sp in seen.items()]


def bark_lines(root="scripts"):
    src = open(os.path.join(root, "npc.gd"), encoding="utf-8").read()
    out = []
    for s in STR.findall(src):
        t = unescape(s)
        if SPOKEN.match(t) and "%" not in t and "res://" not in t:
            out.append(t)
    return sorted(set(out))


def enemy_lines(root="scripts"):
    """Begging / confession lines of beaten attackers (rendered in two male voices)."""
    src = open(os.path.join(root, "enemy.gd"), encoding="utf-8").read()
    out = []
    for s in STR.findall(src):
        t = unescape(s)
        if SPOKEN.match(t) and "%" not in t and "res://" not in t:
            out.append(t)
    return sorted(set(out))


if __name__ == "__main__":
    sl = story_lines(); bl = bark_lines()
    print(len(sl), "story lines;", len(bl), "bark lines")
    from collections import Counter
    print(Counter(s for s, _ in sl).most_common(40))
    for s, t in sl[:6]: print(s, "|", t[:70])
    for t in bl[:6]: print("bark |", t)
