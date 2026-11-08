## For every result 1..6, orients the custom dice as DiceController would and checks
## that the face carrying that many pips is the one pointing up.
extends SceneTree

func _init() -> void:
	var dice := DiceController.new()
	var model := RoyalDice.build()
	var failures := 0
	for result in range(1, 7):
		model.rotation_degrees = dice.orientation_for_result(result)
		var best := -1
		var best_dot := -2.0
		for child in model.get_children():
			if child.has_meta("face"):
				var up: Vector3 = (model.basis * (child as Node3D).basis).y.normalized()
				if up.dot(Vector3.UP) > best_dot:
					best_dot = up.dot(Vector3.UP)
					best = child.get_meta("face")
		var ok := best == result and best_dot > 0.99
		if not ok:
			failures += 1
		print("result %d -> face up %d (%.3f) %s" % [result, best, best_dot, "ok" if ok else "FAIL"])
	print("ROYAL DICE FACES " + ("PASS" if failures == 0 else "FAIL"))
	model.free()
	dice.free()
	quit(1 if failures else 0)
