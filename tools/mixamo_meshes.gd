extends SceneTree
## Diagnostics: which Mixamo files carry a body (meshes), and their sizes.
func _init() -> void:
	for d in ["res://mixamo_src/", "res://mixamo_src/models/"]:
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".fbx") or not (f.begins_with("bow_") or f.begins_with("mutant") or f.begins_with("jump_down") or d.ends_with("models/")):
				continue
			var inst := (load(d + f) as PackedScene).instantiate()
			var meshes := inst.find_children("*", "MeshInstance3D", true, false)
			var aps := inst.find_children("*", "AnimationPlayer", true, false)
			var alen := 0.0
			if not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation("mixamo_com"):
				alen = (aps[0] as AnimationPlayer).get_animation("mixamo_com").length
			var names: PackedStringArray = []
			for m in meshes:
				names.append(String(m.name))
			print("[mesh] %-28s meshes %d %s  anim %.2fs" % [f, meshes.size(), ",".join(names), alen])
			inst.free()
	quit()
