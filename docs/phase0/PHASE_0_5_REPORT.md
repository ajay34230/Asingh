# Phase Report: 0.5, Save v2

Branch: `phase-05-save-v2`. Starting commit: `bd8fbac`.

1. **Implemented:** `scripts/save_system.gd`. Versioned save (v2), atomic write (temp file, read back and verified, then renamed), previous save kept as `.bak`, v1 saves migrate forward in memory, a damaged file is copied to `.corrupt` (never deleted) and the backup is used. The player's health is now saved and restored.
2. **Existing systems modified:** `game_menu.gd` (save, load, has_save, new game now also clears the backup), `main.gd` (self-test only).
3. **Integration:** autosave every 20 s and on every story change now go through `SaveSystem`. Old `user://save.json` files still load.
4. **Tests (automated, desktop headless):** self-test PASS including four new checks: v1 migration, write plus backup, truncated main file falls back to backup, both damaged returns nothing and keeps the files.
5. **Not done, deliberately:** no separate `GameState` class and no JSON data folder yet. Story flags remain the single owner of state. Namespaced IDs and the data folder will be introduced with Phase 2 (inventory), where they are first needed, to avoid building an unused layer.
6. **Not tested:** on a real Android device (file rename behaviour on the phone's storage is untested).
