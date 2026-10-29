class_name HouseInteriors
extends RefCounted
## Furniture and household clutter for HouseBuilder houses (local space, origin at floor centre).
## The doorway path (door_x, front wall to the partition doorway) is kept clear.

const FY := HouseBuilder.FLOOR_Y


static func furnish(h: Node3D, w: float, d: float, door_x: float, partition_x: float, variant: int,
		rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var t := HouseBuilder.WALL_T
	var inner_w := -hw + t * 0.5 + 0.25          # west wall inside face
	var inner_back := -hd + t * 0.5 + 0.25       # back wall inside face
	var has_part := partition_x < 50.0
	var room_x1 := partition_x - 0.25 if has_part else hw - t * 0.5 - 0.25

	var wood := PropFactory.wood()
	var dark_wood := PropFactory.wood(Color(0.24, 0.16, 0.10))
	var clay := PropFactory.clay()
	var rug_a := PropFactory.cloth(Color(0.55, 0.20, 0.16))
	var rug_b := PropFactory.cloth(Color(0.82, 0.66, 0.36))

	# Woven rug under the middle of the main room.
	var rug_cx := (inner_w + room_x1) * 0.5
	PropFactory.box(h, Vector3(2.6, 0.03, 2.0), Vector3(rug_cx, FY + 0.03, -0.2), rug_a, Vector3.ZERO, false, false)
	PropFactory.box(h, Vector3(2.0, 0.035, 1.4), Vector3(rug_cx, FY + 0.04, -0.2), rug_b, Vector3.ZERO, false, false)

	# Low table with stools around it.
	var tx := rug_cx
	var tz := -0.2
	PropFactory.box(h, Vector3(1.3, 0.08, 0.8), Vector3(tx, FY + 0.72, tz), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			PropFactory.box(h, Vector3(0.08, 0.7, 0.08), Vector3(tx + sx * 0.58, FY + 0.35, tz + sz * 0.33), wood, Vector3.ZERO, false, false)
	for a in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)]:
		var sp := Vector3(tx + a.x * 1.05, FY + 0.22, tz + a.y * 0.8)
		PropFactory.cylinder(h, 0.22, 0.22, 0.44, sp, wood, Vector3.ZERO, true, 10, 0, false)
	# Table settings: bowls, a jug and bread.
	PropFactory.cylinder(h, 0.14, 0.07, 0.07, Vector3(tx - 0.3, FY + 0.79, tz), clay, Vector3.ZERO, false, 10, 0, false)
	PropFactory.cylinder(h, 0.14, 0.07, 0.07, Vector3(tx + 0.1, FY + 0.79, tz + 0.15), clay, Vector3.ZERO, false, 10, 0, false)
	PropFactory.sphere(h, 0.11, Vector3(tx + 0.4, FY + 0.88, tz - 0.15), clay, Vector3(1, 1.3, 1))
	PropFactory.box(h, Vector3(0.28, 0.06, 0.18), Vector3(tx - 0.05, FY + 0.79, tz - 0.22), PropFactory.cloth(Color(0.72, 0.52, 0.28)), Vector3(0, 20, 0), false, false)

	# Shelves on the west wall with jars and baskets.
	var sx0 := inner_w + 0.15
	for lv in 3:
		PropFactory.box(h, Vector3(0.35, 0.05, 2.2), Vector3(sx0, FY + 0.7 + lv * 0.62, 0.3), wood, Vector3.ZERO, false)
	for sz in [-0.8, 1.4]:
		for sd in [-1.0, 1.0]:
			PropFactory.box(h, Vector3(0.06, 1.9, 0.06), Vector3(sx0 - 0.1, FY + 0.95, sz + 0.3 * 0 + sd * 0.0 + 0.0), dark_wood, Vector3.ZERO, false, false)
	for lv in 3:
		for k in 4:
			var jz := -0.6 + k * 0.55 + rng.randf_range(-0.05, 0.05)
			var jy := FY + 0.72 + lv * 0.62
			if (k + lv) % 3 == 0:
				PropFactory.cylinder(h, 0.13, 0.15, 0.22, Vector3(sx0, jy + 0.12, jz + 0.3), PropFactory.cloth(Color(0.62, 0.48, 0.28)), Vector3.ZERO, false, 10, 0, false)
			else:
				PropFactory.sphere(h, 0.1, Vector3(sx0, jy + 0.11, jz + 0.3), clay, Vector3(1, 1.25, 1))

	# Clay oven in the back corner with a soot-dark mouth, a pot and a woodpile.
	var ox := inner_w + 0.8
	var oz := inner_back + 0.75
	PropFactory.cylinder(h, 0.45, 0.75, 1.15, Vector3(ox, FY + 0.58, oz), clay)
	PropFactory.sphere(h, 0.45, Vector3(ox, FY + 1.1, oz), clay, Vector3(1, 0.7, 1))
	PropFactory.box(h, Vector3(0.38, 0.32, 0.12), Vector3(ox + 0.5, FY + 0.35, oz + 0.2), PropFactory.material(Color(0.04, 0.03, 0.03)), Vector3(0, 40, 0), false, false)
	PropFactory.cylinder(h, 0.2, 0.28, 0.34, Vector3(ox + 1.1, FY + 0.17, oz - 0.1), PropFactory.iron(), Vector3.ZERO, true, 10, 0, false)
	for i in 4:
		PropFactory.cylinder(h, 0.06, 0.06, 0.7, Vector3(ox + 0.1 + i * 0.13, FY + 0.07 + (i % 2) * 0.12, oz + 1.0), wood, Vector3(0, 0, 90), false, 6, 0, false)

	# Large storage jars along the back wall.
	for i in 3:
		var jx := inner_w + 2.2 + i * 0.85
		var jr := 0.34 + 0.05 * (i % 2)
		PropFactory.sphere(h, jr, Vector3(jx, FY + jr * 1.2, inner_back + 0.1), clay, Vector3(1, 1.25, 1), true)
		PropFactory.cylinder(h, jr * 0.55, jr * 0.65, 0.12, Vector3(jx, FY + jr * 2.45, inner_back + 0.1), clay, Vector3.ZERO, false, 10, 0, false)

	# Hanging lantern (lit, emissive) on a chain from the ceiling beams.
	var lamp_x := -w * 0.1 if has_part else 0.0
	PropFactory.cylinder(h, 0.01, 0.01, 0.7, Vector3(lamp_x, FY + 2.85, 0.0), PropFactory.iron(), Vector3.ZERO, false, 6, 0, false)
	PropFactory.sphere(h, 0.12, Vector3(lamp_x, FY + 2.5, 0.0), PropFactory.glow_lamp(), Vector3(1, 1.3, 1))

	# Wall hanging on the back wall.
	PropFactory.box(h, Vector3(1.5, 1.1, 0.03), Vector3(inner_w + 5.5 if w > 9.5 else 0.0, FY + 1.9, -hd + t * 0.5 + 0.28), PropFactory.cloth(Color(0.45, 0.18, 0.15)), Vector3.ZERO, false, false)

	# Sleeping area.
	if has_part:
		var bx := (partition_x + hw - t * 0.5) * 0.5
		# Bed: timber frame, straw mattress, blanket, bolster.
		PropFactory.box(h, Vector3(1.0, 0.3, 2.0), Vector3(bx, FY + 0.15, -hd + 1.45), wood)
		PropFactory.box(h, Vector3(0.92, 0.14, 1.9), Vector3(bx, FY + 0.37, -hd + 1.45), PropFactory.cloth(Color(0.78, 0.68, 0.46)), Vector3.ZERO, false, false)
		PropFactory.box(h, Vector3(0.9, 0.1, 1.2), Vector3(bx, FY + 0.47, -hd + 1.8), PropFactory.cloth(Color(0.30, 0.38, 0.48)), Vector3.ZERO, false, false)
		PropFactory.cylinder(h, 0.14, 0.14, 0.8, Vector3(bx, FY + 0.5, -hd + 0.65), PropFactory.cloth(Color(0.85, 0.80, 0.68)), Vector3(0, 0, 90), false, 10, 0, false)
		# Chest at the foot of the bed with an iron band, and a small niche shelf.
		PropFactory.box(h, Vector3(0.9, 0.5, 0.5), Vector3(bx, FY + 0.25, 0.9), dark_wood)
		PropFactory.box(h, Vector3(0.94, 0.07, 0.54), Vector3(bx, FY + 0.28, 0.9), PropFactory.iron(), Vector3.ZERO, false, false)
		if variant == 0:
			PropFactory.box(h, Vector3(0.9, 0.4, 0.5), Vector3(bx + 0.3, FY + 0.2, 1.6), wood)
	else:
		# Single-room houses: a pallet bed and a chest against the east wall.
		PropFactory.box(h, Vector3(2.0, 0.3, 1.0), Vector3(hw - 1.5, FY + 0.15, -hd + 1.2), wood)
		PropFactory.box(h, Vector3(1.9, 0.14, 0.92), Vector3(hw - 1.5, FY + 0.37, -hd + 1.2), PropFactory.cloth(Color(0.76, 0.66, 0.44)), Vector3.ZERO, false, false)
		PropFactory.box(h, Vector3(0.9, 0.5, 0.5), Vector3(hw - 1.0, FY + 0.25, 0.4), dark_wood)

	# A loom in the larger houses.
	if variant == 2:
		var lx := inner_w + 1.2
		var lz := hd - 1.3
		for sx in [-1.0, 1.0]:
			PropFactory.box(h, Vector3(0.1, 1.6, 0.1), Vector3(lx + sx * 0.6, FY + 0.8, lz), dark_wood, Vector3.ZERO, false, false)
		PropFactory.box(h, Vector3(1.3, 0.1, 0.1), Vector3(lx, FY + 1.6, lz), dark_wood, Vector3.ZERO, false, false)
		PropFactory.box(h, Vector3(1.1, 1.1, 0.02), Vector3(lx, FY + 1.0, lz), PropFactory.cloth(Color(0.70, 0.35, 0.20)), Vector3.ZERO, false, false)
	# Hanging herb bundles and a water pot by the door.
	for i in 3:
		PropFactory.box(h, Vector3(0.08, 0.35, 0.08), Vector3(room_x1 - 0.2 - i * 0.3, FY + 2.7, -hd + 0.5), PropFactory.cloth(Color(0.38, 0.45, 0.25)), Vector3.ZERO, false, false)
	PropFactory.sphere(h, 0.28, Vector3(door_x + 1.0, FY + 0.34, hd - 0.55), clay, Vector3(1, 1.2, 1), true)
