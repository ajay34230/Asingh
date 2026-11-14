extends SceneTree
## Converts the Mixamo files in res://mixamo_src/ (X Bot rig, FBX) into res://assets/anims/mocap.res for our
## skeleton. Run: godot --headless --path . --script res://tools/bake_mixamo.gd  (after --import)

const FPS := 30.0
const SRC := "res://mixamo_src/"
const OUT := "res://assets/anims/mocap.res"
# Mixamo bone (without "mixamorig_") -> our bone
const MAP := {
	"Hips": "hips", "Spine": "spine", "Spine1": "chest", "Spine2": "spine_03", "Neck": "neck", "Head": "head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upper_arm_l", "LeftForeArm": "forearm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upper_arm_r", "RightForeArm": "forearm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "shin_l", "LeftFoot": "foot_l", "LeftToeBase": "toe_l",
	"RightUpLeg": "thigh_r", "RightLeg": "shin_r", "RightFoot": "foot_r", "RightToeBase": "toe_r",
}
const FINGERS := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Pinky": "pinky"}
# next bone along each chain, for lining up the rest directions
var NEXT := {
	"spine": "chest", "chest": "spine_03", "spine_03": "neck", "neck": "head",
	"clavicle_l": "upper_arm_l", "upper_arm_l": "forearm_l", "forearm_l": "hand_l", "hand_l": "middle_01_l",
	"clavicle_r": "upper_arm_r", "upper_arm_r": "forearm_r", "forearm_r": "hand_r", "hand_r": "middle_01_r",
	"thigh_l": "shin_l", "shin_l": "foot_l", "foot_l": "toe_l",
	"thigh_r": "shin_r", "shin_r": "foot_r", "foot_r": "toe_r",
}
const LOOPS := ["walk", "run", "strafe", "idle", "crouching", "block_idle"]


func _full_map() -> Dictionary:
	var m := MAP.duplicate()
	for side in [["Left", "l"], ["Right", "r"]]:
		for f in FINGERS:
			for j in 3:
				m["%sHand%s%d" % [side[0], f, j + 1]] = "%s_%02d_%s" % [FINGERS[f], j + 1, side[1]]
	for f in FINGERS:
		for side in ["l", "r"]:
			for j in 2:
				NEXT["%s_%02d_%s" % [FINGERS[f], j + 1, side]] = "%s_%02d_%s" % [FINGERS[f], j + 2, side]
	return m


func _init() -> void:
	await process_frame
	var map := _full_map()
	var lib := MocapLibrary.new()
	var files: PackedStringArray = []
	for f in DirAccess.get_files_at(SRC):
		if f.ends_with(".fbx") and f != "X_Bot.fbx":
			files.append(f)
	files.sort()
	for f in files:
		var name := f.get_basename()
		var ps := load(SRC + f) as PackedScene
		if ps == null:
			print("[bake] cannot load ", f)
			continue
		var inst := ps.instantiate()
		root.add_child(inst)
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var an := "mixamo_com"
		if not ap.has_animation(an):
			var best := 0.0
			for a in ap.get_animation_list():
				if ap.get_animation(a).length > best:
					best = ap.get_animation(a).length
					an = a
		var anim := ap.get_animation(an)
		var length := anim.length
		var n := int(ceil(length * FPS)) + 1
		var src_idx := {}
		for mb in map:
			var bi := sk.find_bone("mixamorig_" + mb)
			if bi >= 0:
				src_idx[map[mb]] = bi
		var hips_i: int = src_idx["hips"]
		var hip_h := sk.get_bone_global_rest(hips_i).origin.y
		if lib.rest_dirs.is_empty():
			for b in NEXT:
				if src_idx.has(b) and src_idx.has(NEXT[b]):
					lib.rest_dirs[b] = (sk.get_bone_global_rest(src_idx[NEXT[b]]).origin - sk.get_bone_global_rest(src_idx[b]).origin).normalized()
			lib.rest_dirs["_hip_h"] = hip_h
		var rest := {}
		for b in src_idx:
			rest[b] = sk.get_bone_global_rest(src_idx[b]).basis.orthonormalized()
		var bones := {}
		for b in src_idx:
			var arr := PackedFloat32Array()
			arr.resize(n * 4)
			bones[b] = arr
		var hips := PackedFloat32Array()
		hips.resize(n * 3)
		var hand_r := PackedVector3Array()
		var hand_l := PackedVector3Array()
		var foot_r := PackedVector3Array()
		var foot_l := PackedVector3Array()
		ap.play(an)
		for fi in n:
			var t := minf(fi / FPS, length)
			ap.seek(t, true)
			for b in src_idx:
				var g := sk.get_bone_global_pose(src_idx[b]).basis.orthonormalized()
				var q := (g * (rest[b] as Basis).inverse()).get_rotation_quaternion()
				var arr: PackedFloat32Array = bones[b]
				arr[fi * 4] = q.x
				arr[fi * 4 + 1] = q.y
				arr[fi * 4 + 2] = q.z
				arr[fi * 4 + 3] = q.w
				bones[b] = arr
			var o := (sk.get_bone_global_pose(hips_i).origin - sk.get_bone_global_rest(hips_i).origin) / hip_h
			hips[fi * 3] = o.x
			hips[fi * 3 + 1] = o.y
			hips[fi * 3 + 2] = o.z
			hand_r.append(sk.get_bone_global_pose(src_idx["hand_r"]).origin - sk.get_bone_global_pose(hips_i).origin)
			hand_l.append(sk.get_bone_global_pose(src_idx["hand_l"]).origin - sk.get_bone_global_pose(hips_i).origin)
			foot_r.append(sk.get_bone_global_pose(src_idx["foot_r"]).origin - sk.get_bone_global_pose(hips_i).origin)
			foot_l.append(sk.get_bone_global_pose(src_idx["foot_l"]).origin - sk.get_bone_global_pose(hips_i).origin)
		var loop := false
		for w in LOOPS:
			if name.contains(w):
				loop = true
		# take the travel out of looping clips (the game moves the character); keep its speed
		var travel := Vector3(hips[(n - 1) * 3] - hips[0], 0.0, hips[(n - 1) * 3 + 2] - hips[2])
		var speed := 0.0
		if loop:
			speed = travel.length() / maxf(length, 0.01)
			for fi in n:
				var k := float(fi) / float(n - 1)
				hips[fi * 3] -= travel.x * k
				hips[fi * 3 + 2] -= travel.z * k
		# the striking moment: where the sword hand (or the kicking foot) moves fastest
		var track := foot_r if name.contains("kick") else hand_r
		var hit := 0.0
		var best_v := 0.0
		for fi in range(1, n):
			var v := (track[fi] - track[fi - 1]).length()
			if v > best_v:
				best_v = v
				hit = fi / FPS
		# where the stride starts: the left foot furthest forward (so walk and run can be blended in step)
		var phase0 := 0.0
		var best_z := -INF
		for fi in n - 1:
			if foot_l[fi].z > best_z:
				best_z = foot_l[fi].z
				phase0 = float(fi) / float(n - 1)
		var low_t := 0.0                     # the deepest crouch (a landing)
		var low_y := INF
		for fi in n:
			if hips[fi * 3 + 1] < low_y:
				low_y = hips[fi * 3 + 1]
				low_t = fi / FPS
		lib.clips[name] = {"fps": FPS, "n": n, "len": length, "loop": loop, "speed": speed, "hit": hit, "phase0": phase0, "low_t": low_t, "bones": bones, "hips": hips}
		var ymin := 9.0
		for fi in n:
			ymin = minf(ymin, hips[fi * 3 + 1])
		print("[bake] %-22s %5.2fs %3d frames loop %-5s travel %5.2f hh (%4.2f hh/s) hit %4.2fs hips low %5.2f end %5.2f" % [name, length, n, str(loop), travel.length(), speed, hit, ymin, hips[(n - 1) * 3 + 1]])
		print("[bake]    phase0 %.2f  low_t %.2f" % [lib.clips[name]["phase0"], lib.clips[name]["low_t"]])
		inst.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://assets/anims")
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("[bake] saved %d clips -> %s (err %d)" % [lib.clips.size(), OUT, err])
	quit()
