"""Builds data/hindi.json (English text -> Hindi text) from the hi_*.py translation tables."""
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import voice_lines, hi_a, hi_b, hi_c, hi_d

story = voice_lines.story_lines()
bark = voice_lines.bark_lines()
enemy = voice_lines.enemy_lines()
hs = hi_a.HI_STORY_A + hi_b.HI_STORY_B
assert len(hs) == len(story), (len(hs), len(story))
assert len(hi_c.HI_BARK) == len(bark), (len(hi_c.HI_BARK), len(bark))
assert len(hi_c.HI_ENEMY) == len(enemy)
tr = {}
for (_, en), hi in zip(story, hs):
    tr[en] = hi
for en, hi in zip(bark, hi_c.HI_BARK):
    tr[en] = hi
for en, hi in zip(enemy, hi_c.HI_ENEMY):
    tr[en] = hi
tr.update(hi_c.HI_CHOICES)
tr.update(hi_d.HI_UI)
os.makedirs("data", exist_ok=True)
json.dump(tr, open("data/hindi.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(tr), "entries")
