## DLC manager test against tests/dlc/server.py: manifest, compatibility, a download that is
## cut off and resumed, checksum rejection, mounting, removal and offline use.
extends SceneTree

var failures := 0
var mgr: DLCManager

func check(ok: bool, name: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + name)

func _initialize() -> void:
	_run()

func _run() -> void:
	mgr = DLCManager.new()
	root.add_child(mgr)
	await process_frame
	mgr.manifest_url = "http://127.0.0.1:%s/manifest.json" % OS.get_environment("DLC_PORT")
	await mgr.refresh()
	check(not mgr.offline and mgr.packs.size() == 3, "manifest loaded with 3 packs")
	check(mgr.status("test_pack") == "available", "pack starts as available")
	check(mgr.status("future_pack") == "incompatible", "pack needing a newer game is incompatible")
	check(DLCManager.compare_versions("1.9.2", "1.10.0") < 0 and DLCManager.compare_versions("2.0", "1.9.9") > 0, "version comparison")
	var seen := [0]
	mgr.progress.connect(func(_id: String, got: int, _t: int) -> void: seen[0] = maxi(seen[0], got))
	var result := []
	mgr.pack_finished.connect(func(id: String, ok: bool, msg: String) -> void: result.append([id, ok, msg]))
	mgr.download("test_pack")
	while result.is_empty():
		await create_timer(0.1).timeout
	check(result[0][1], "download finished after the cut-off connection was resumed (%s)" % result[0][2])
	check(seen[0] > 0, "progress was reported")
	check(mgr.status("test_pack") == "installed" and mgr.has_pack("test_pack"), "pack installed and mounted")
	check(FileAccess.file_exists("res://dlc_test/hello.txt") and FileAccess.get_file_as_string("res://dlc_test/hello.txt").begins_with("hello from the pack"), "mounted pack content is readable")
	check(mgr.storage_used() > 0, "storage used is counted")
	result.clear()
	mgr.download("bad_pack")
	while result.is_empty():
		await create_timer(0.1).timeout
	check(not result[0][1] and mgr.status("bad_pack") == "available", "a pack with a wrong checksum is rejected")
	result.clear()
	mgr.download("future_pack")
	check(not result.is_empty() and not result[0][1], "an incompatible pack is refused")
	# Offline: a dead server falls back to the cached manifest, and the installed pack remains.
	mgr.manifest_url = "http://127.0.0.1:1/manifest.json"
	await mgr.refresh()
	check(mgr.offline and mgr.packs.size() == 3 and mgr.status("test_pack") == "installed", "offline: cached manifest used, installed pack still available")
	# Restart: a new manager mounts the installed pack again without any network.
	var again := DLCManager.new()
	root.add_child(again)
	await process_frame
	check(again.status("test_pack") == "installed" and again.has_pack("test_pack"), "installed pack is remounted on the next start")
	mgr.remove("test_pack")
	check(not FileAccess.file_exists(mgr._installed.get("test_pack", {}).get("file", "")) and mgr.status("test_pack") == "available", "removing a pack deletes it")
	print("DLC TEST " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
