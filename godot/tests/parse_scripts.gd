## Loads every animation script so Godot reports syntax and type errors.
extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://scripts/animation")
	var failed := 0
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		count += 1
		var script := load("res://scripts/animation/" + file) as GDScript
		if script == null or not script.can_instantiate():
			print("PARSE FAIL: " + file)
			failed += 1
		else:
			print("OK  " + file)
	print("%d scripts, %d failed" % [count, failed])
	quit(1 if failed > 0 else 0)
