"""Builds a DLC pack and adds it to dlc/manifest.json.

  python tools/build_dlc.py <pack_id> <version> <source_folder> "<Display name>" \
      --description "..." --min-game 1.9.0 --base-url https://github.com/<user>/RoyalIndiaLudo-DLC/releases/download

The source folder is laid out like res:// (for example textures/board/marble.png becomes
res://textures/board/marble.png). Files in a pack OVERRIDE the same paths in the game, so
a pack can swap in better assets, or add new ones; the game never needs a pack to run.
Writes dlc/packs/<id>_<version>.pck and updates dlc/manifest.json (size and SHA-256).
Then publish: gh release create <id>-v<version> dlc/packs/<id>_<version>.pck  (and upload manifest.json
to the release the game reads: .../releases/latest/download/manifest.json).
"""
import argparse, hashlib, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("id"); ap.add_argument("version"); ap.add_argument("source"); ap.add_argument("name")
ap.add_argument("--description", default=""); ap.add_argument("--min-game", default="1.9.0")
ap.add_argument("--base-url", default="https://github.com/ajay34230/RoyalIndiaLudo-DLC/releases/download")
ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
a = ap.parse_args()

out_dir = os.path.join(ROOT, "dlc", "packs"); os.makedirs(out_dir, exist_ok=True)
pck = os.path.join(out_dir, "%s_%s.pck" % (a.id, a.version))
env = dict(os.environ, DLC_SRC=os.path.abspath(a.source), DLC_OUT=pck)
subprocess.run([a.godot, "--headless", "--path", os.path.join(ROOT, "godot"), "--script", os.path.join(ROOT, "tools", "dlc", "pack_folder.gd")], env=env, check=True)
data = open(pck, "rb").read()
entry = {"id": a.id, "name": a.name, "version": a.version, "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
         "url": "%s/%s-v%s/%s_%s.pck" % (a.base_url, a.id, a.version, a.id, a.version),
         "min_game_version": a.min_game, "description": a.description}
mpath = os.path.join(ROOT, "dlc", "manifest.json")
manifest = json.load(open(mpath)) if os.path.exists(mpath) else {"schema": 1, "packs": []}
manifest["packs"] = [p for p in manifest["packs"] if p["id"] != a.id] + [entry]
json.dump(manifest, open(mpath, "w"), indent=1)
print("built %s (%.1f MB), sha256 %s" % (pck, len(data) / 1048576, entry["sha256"][:16]))
