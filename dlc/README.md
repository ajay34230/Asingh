# Royal India Ludo: downloadable graphics packs (DLC)

The game ships complete. Packs are optional and never required: if one is missing, removed or
fails to mount, the original graphics are used.

## How it fits together
- `dlc/manifest.json`: the list the game reads (id, version, size, SHA-256, URL, minimum game version).
- `tools/build_dlc.py`: builds a `.pck` from a folder laid out like `res://`, and updates the manifest.
- `godot/scripts/app/dlc_manager.gd`: the game side (manifest, resumable downloads, checksum, mounting,
  updates, removal, offline use). `Settings > Resource Centre` is its screen.

## Hosting (this repository, replaceable)
The game reads `DLCManager.DEFAULT_MANIFEST_URL`, the raw `dlc/manifest.json` of this repository's
branch (change the branch name in that URL once the work is merged, e.g. to `main`). Pack files live in
`dlc/packs/` and are served the same way (GitHub rejects files over 100 MB).
To use GitHub Releases (a separate `RoyalIndiaLudo-DLC` repository), Cloudflare R2 or any CDN, host the same
manifest and `.pck` files there, pass `--base-url` to the build tool and change that one URL
(or set `[dlc] manifest_url` in the settings file). Nothing else changes.

## Publishing a pack
1. `python tools/build_dlc.py robots 1.0.0 path/to/folder "Ultra Realistic Robot Pack" --description "..."`
2. Commit and push `dlc/manifest.json` and `dlc/packs/robots_1.0.0.pck`.

Bump the pack `version` to ship an update; the Resource Centre then shows "Update".
A pack's `min_game_version` keeps it away from game versions it was not made for.

## Test
`tests/dlc/` runs the manager against a local server that cuts the first download off and
requires a resume: `python3 tests/dlc/server.py <pck> <port> <log>` then
`DLC_PORT=<port> godot --headless --path godot --script tests/dlc/dlc_test.gd`.
