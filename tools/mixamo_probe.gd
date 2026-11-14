extends SceneTree
## Diagnostics: compare a Mixamo file's skeleton with the hero's (directions in model space, sizes, clips).

func _frame_of(sk: Skeleton3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = sk
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _report(tag: String, root: Node, names: Array) -> void:
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var fr := _frame_of(sk, root)
	print("[probe] %s: bones %d, frame basis %s scale %s" % [tag, sk.get_bone_count(), str(fr.basis.orthonormalized()), str(fr.basis.get_scale())])
	for nm in names:
		var bi := sk.find_bone(nm)
		if bi < 0:
			print("   missing ", nm)
			continue
		print("   %-24s model pos %s" % [nm, str((fr * sk.get_bone_global_rest(bi).origin).snapped(Vector3.ONE * 0.001))])


func _init() -> void:
	var xb := (load("res://mixamo_src/walk.fbx") as PackedScene).instantiate()
	root.add_child(xb)
	var sk: Skeleton3D = xb.find_children("*", "Skeleton3D", true, false)[0]
	var bl: PackedStringArray = []
	for i in sk.get_bone_count():
		bl.append(sk.get_bone_name(i))
	print("[probe] xbot bones: ", " ".join(bl))
	for ap in xb.find_children("*", "AnimationPlayer", true, false):
		for an in (ap as AnimationPlayer).get_animation_list():
			var a := (ap as AnimationPlayer).get_animation(an)
			print("[probe] anim '%s' len %.2f tracks %d first %s" % [an, a.length, a.get_track_count(), str(a.track_get_path(0))])
	_report("xbot", xb, ["mixamorig_Hips", "mixamorig_Head", "mixamorig_LeftHand", "mixamorig_RightHand", "mixamorig_LeftFoot", "mixamorig_LeftToeBase", "mixamorig_LeftArm"])
	var hero := (load("res://assets/characters/striker_mail.glb") as PackedScene).instantiate()
	root.add_child(hero)
	_report("hero", hero, ["hips", "head", "hand_l", "hand_r", "foot_l", "toe_l", "upper_arm_l"])
	quit()
