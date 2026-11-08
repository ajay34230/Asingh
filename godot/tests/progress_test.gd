## Checks coins, shop purchases, equipping, daily reward and achievements. Backs up
## and restores the real save file.
extends SceneTree

var failures := 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + name)

func _init() -> void:
	var path := GameSettings.PATH
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	_check("starts with 0 coins", Progress.coins() == 0)
	_check("free items owned", Progress.owns("theme_royal") and Progress.owns("dice_ivory"))
	_check("cannot afford jade", Progress.buy("dice_jade") == "coins")
	var st := Progress.daily_status()
	_check("daily claimable, day 1 = 50", st[0] and st[1] == 0 and st[2] == 50)
	_check("claim pays 50", Progress.claim_daily() == 50 and Progress.coins() == 50)
	_check("second claim same day refused", Progress.claim_daily() == 0)
	Progress.add_coins(300)
	_check("buy jade", Progress.buy("dice_jade") == "ok" and Progress.coins() == 100)
	_check("buy again says owned", Progress.buy("dice_jade") == "owned")
	Progress.equip("dice_jade")
	_check("jade equipped", Progress.equipped("dice") == "dice_jade")
	var got := Progress.record_game({"won": true, "place": 1, "captures": 3, "lost": 0, "home": 4, "sixes": 3, "difficulty": 3})
	_check("win unlocks first_win, triple, flawless, sixes, expert", got.has("first_win") and got.has("triple_capture") and got.has("flawless") and got.has("sixes_3") and got.has("expert_win"))
	_check("achievement coins paid", Progress.coins() == 100 + 100 + 50 + 150 + 250 + 75 + 400)
	var again := Progress.record_game({"won": false, "place": 2, "captures": 0, "lost": 2, "home": 0, "sixes": 0, "difficulty": 1})
	_check("no repeat achievements", again.is_empty())
	var s := Progress.stats()
	_check("stats add up", s["games"] == 2 and s["wins"] == 1 and s["captures"] == 3 and s["lost"] == 2 and s["streak"] == 0 and s["best_streak"] == 1)

	_check("level 1 at 0 xp", Progress.level_for(0) == 1 and Progress.level_for(119) == 1 and Progress.level_for(120) == 2 and Progress.level_for(360) == 3)
	var c0 := Progress.coins()
	var r := Progress.add_game_xp({"won": true, "captures": 2, "home": 4})
	_check("win xp = 50+100+20+60", r[0] == 230)
	_check("level-up pays 100 x level", r[1] == 1 and Progress.coins() == c0 + 200)
	Progress.set_title("first_win")
	_check("title from unlocked achievement", Progress.title() == "first_win")
	Progress.set_title("wins_10")
	_check("locked title refused", Progress.title() == "first_win")
	Progress.set_player_name("  Arjun  ")
	_check("name trimmed", Progress.player_name() == "Arjun")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
	print("PROGRESS TEST " + ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
