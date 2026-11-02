## Verifies, without rendering, that the dice orientation table shows the correct
## number of pips on top for every result 1..6.
## The supplied model names its meshes by face (face_N_...) and each pip has a
## "pip_gem_core" mesh. Pip count per face = number of gem cores on that face.
## The face's outward direction comes from the centre of its meshes.
extends SceneTree

const DICE := "res://assets/models/02_Dice/Royal_India_Royal_Jewel_Dice.glb"

func _init() -> void:
	var root := (load(DICE) as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	var pips := {}        ## face label -> count of gem cores
	var centres := {}     ## face label -> sum of mesh centres (for direction)
	var counts := {}
	for mi in _meshes(root):
		var name_text := String(mi.name)
		if not name_text.begins_with("face_"):
			continue
		var face := int(name_text.split("_")[1])
		var c := mi.get_aabb().get_center()
		centres[face] = centres.get(face, Vector3.ZERO) + c
		counts[face] = int(counts.get(face, 0)) + 1
		if name_text.contains("pip_gem_core"):
			pips[face] = int(pips.get(face, 0)) + 1
	var outward := {}
	for face in centres:
		outward[face] = (centres[face] / counts[face]).normalized()
	var failures := 0
	var controller := DiceController.new()
	for face in range(1, 7):
		print("face %d: %d pips, outward %s" % [face, int(pips.get(face, 0)) / 9, str(outward.get(face, Vector3.ZERO).snapped(Vector3.ONE * 0.01))])
	for value in range(1, 7):
		var rot := Basis.from_euler(controller.orientation_for_result(value) * PI / 180.0)
		var top := _face_pointing_up(rot, outward)
		var shown := int(pips.get(top, -1)) / 9  ## 9 gem-core meshes per pip
		var ok := shown == value
		print("result %d: top face %d shows %d pips %s" % [value, top, shown, "OK" if ok else "WRONG"])
		if not ok:
			failures += 1
	print("DICE FACE TEST " + ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _face_pointing_up(rot: Basis, outward: Dictionary) -> int:
	var best := 0
	var best_y := -INF
	for face in outward:
		var world: Vector3 = rot * (outward[face] as Vector3)
		if world.y > best_y:
			best_y = world.y
			best = face
	return best

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
