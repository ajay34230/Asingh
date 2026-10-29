class_name PropsExtra
extends RefCounted
## Hand tools, workshop gear and household equipment built from primitives. Every function
## places one prop group under `parent` at local `pos`, rotated by `yaw` degrees.


static func _root(parent: Node3D, pos: Vector3, yaw: float, label: String) -> Node3D:
	var r := Node3D.new()
	r.name = label
	r.position = pos
	r.rotation_degrees = Vector3(0, yaw, 0)
	parent.add_child(r)
	return r


## Long-handled tool leaning against a wall. kind: 0 shovel, 1 pickaxe, 2 hoe, 3 broom.
static func leaning_tool(parent: Node3D, pos: Vector3, yaw: float, kind: int) -> Node3D:
	var r := _root(parent, pos, yaw, "Tool")
	var wood := PropFactory.wood()
	var iron := PropFactory.iron()
	var t := Node3D.new()
	t.rotation_degrees = Vector3(-12, 0, 0)
	t.position = Vector3(0, 0.0, 0)
	r.add_child(t)
	PropFactory.cylinder(t, 0.025, 0.03, 1.7, Vector3(0, 0.85, 0), wood, Vector3.ZERO, false, 6, 0, false)
	match kind:
		0:
			PropFactory.box(t, Vector3(0.22, 0.3, 0.025), Vector3(0, 1.82, 0), iron, Vector3.ZERO, false, false)
		1:
			PropFactory.box(t, Vector3(0.7, 0.05, 0.05), Vector3(0, 1.72, 0), iron, Vector3(0, 0, 4), false, false)
		2:
			PropFactory.box(t, Vector3(0.2, 0.18, 0.025), Vector3(0, 1.8, 0.1), iron, Vector3(40, 0, 0), false, false)
		_:
			PropFactory.cylinder(t, 0.12, 0.05, 0.3, Vector3(0, 0.15, 0), PropFactory.cloth(Color(0.55, 0.45, 0.25)), Vector3.ZERO, false, 8, 0, false)
	return r


## Wall-mounted rack with a row of hand tools (hammer, saw, tongs, chisel, mallet).
static func tool_rack(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := _root(parent, pos, yaw, "ToolRack")
	var wood := PropFactory.wood()
	var iron := PropFactory.iron()
	PropFactory.box(r, Vector3(1.6, 0.12, 0.06), Vector3(0, 0, 0), wood, Vector3.ZERO, false, false)
	PropFactory.box(r, Vector3(1.6, 0.05, 0.1), Vector3(0, -0.45, 0.03), wood, Vector3.ZERO, false, false)
	# Hammer
	PropFactory.cylinder(r, 0.015, 0.02, 0.4, Vector3(-0.6, -0.22, 0.07), wood, Vector3.ZERO, false, 6, 0, false)
	PropFactory.box(r, Vector3(0.12, 0.05, 0.05), Vector3(-0.6, -0.04, 0.07), iron, Vector3.ZERO, false, false)
	# Saw
	PropFactory.box(r, Vector3(0.05, 0.45, 0.01), Vector3(-0.25, -0.25, 0.07), iron, Vector3(0, 0, 3), false, false)
	PropFactory.box(r, Vector3(0.05, 0.1, 0.04), Vector3(-0.25, -0.02, 0.07), wood, Vector3.ZERO, false, false)
	# Tongs
	for s in [-1.0, 1.0]:
		PropFactory.box(r, Vector3(0.02, 0.5, 0.02), Vector3(0.15 + s * 0.012, -0.25, 0.07), iron, Vector3(0, 0, s * 2), false, false)
	# Mallet
	PropFactory.cylinder(r, 0.015, 0.02, 0.38, Vector3(0.5, -0.2, 0.07), wood, Vector3.ZERO, false, 6, 0, false)
	PropFactory.cylinder(r, 0.06, 0.06, 0.16, Vector3(0.5, -0.02, 0.07), wood, Vector3(0, 0, 90), false, 8, 0, false)
	return r


static func workbench(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := _root(parent, pos, yaw, "Workbench")
	var wood := PropFactory.wood()
	var dark := PropFactory.wood(Color(0.24, 0.16, 0.10))
	PropFactory.box(r, Vector3(1.8, 0.1, 0.8), Vector3(0, 0.9, 0), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			PropFactory.box(r, Vector3(0.1, 0.9, 0.1), Vector3(sx * 0.8, 0.45, sz * 0.32), dark, Vector3.ZERO, false, false)
	PropFactory.box(r, Vector3(1.6, 0.05, 0.6), Vector3(0, 0.3, 0), wood, Vector3.ZERO, false, false)
	# Vice, plane, pegs and small clay pots of nails.
	PropFactory.box(r, Vector3(0.14, 0.14, 0.2), Vector3(0.7, 1.03, -0.25), PropFactory.iron(), Vector3.ZERO, false, false)
	PropFactory.box(r, Vector3(0.3, 0.07, 0.08), Vector3(-0.3, 0.98, 0.1), wood, Vector3(0, 12, 0), false, false)
	PropFactory.cylinder(r, 0.06, 0.05, 0.1, Vector3(0.1, 0.99, 0.2), PropFactory.clay(), Vector3.ZERO, false, 8, 0, false)
	PropFactory.cylinder(r, 0.025, 0.025, 0.3, Vector3(-0.6, 0.97, -0.1), PropFactory.iron(), Vector3(0, 0, 90), false, 6, 0, false)
	return r


## Blacksmith anvil on a log stump with a hammer and a water bucket.
static func anvil(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := _root(parent, pos, yaw, "Anvil")
	var iron := PropFactory.iron()
	PropFactory.cylinder(r, 0.32, 0.36, 0.55, Vector3(0, 0.28, 0), PropFactory.wood(), Vector3.ZERO, true, 10, 0, false)
	PropFactory.box(r, Vector3(0.55, 0.12, 0.22), Vector3(0, 0.62, 0), iron, Vector3.ZERO, false, false)
	PropFactory.box(r, Vector3(0.22, 0.14, 0.16), Vector3(0, 0.74, 0), iron, Vector3.ZERO, true, false)
	PropFactory.box(r, Vector3(0.3, 0.06, 0.1), Vector3(0.38, 0.69, 0), iron, Vector3(0, 0, -12), false, false)
	PropFactory.cylinder(r, 0.02, 0.025, 0.35, Vector3(-0.1, 0.84, 0.3), PropFactory.wood(), Vector3(0, 0, 90), false, 6, 0, false)
	PropFactory.cylinder(r, 0.06, 0.06, 0.12, Vector3(-0.3, 0.84, 0.3), iron, Vector3(0, 0, 90), false, 8, 0, false)
	bucket(r, Vector3(0.8, 0.0, 0.2))
	return r


static func bucket(parent: Node3D, pos: Vector3) -> Node3D:
	var r := _root(parent, pos, 0.0, "Bucket")
	PropFactory.cylinder(r, 0.2, 0.15, 0.3, Vector3(0, 0.15, 0), PropFactory.wood(Color(0.30, 0.21, 0.14)), Vector3.ZERO, true, 10, 0, false)
	PropFactory.cylinder(r, 0.19, 0.19, 0.02, Vector3(0, 0.28, 0), PropFactory.material(Color(0.07, 0.10, 0.12), 0.1, 0.0), Vector3.ZERO, false, 10, 0, false)
	PropFactory.cylinder(r, 0.2, 0.2, 0.02, Vector3(0, 0.1, 0), PropFactory.iron(), Vector3.ZERO, false, 10, 0, false)
	return r


static func basket(parent: Node3D, pos: Vector3, filled: bool = true) -> Node3D:
	var r := _root(parent, pos, 0.0, "Basket")
	var straw := PropFactory.material(Color(0.62, 0.48, 0.26), 1.0)
	PropFactory.cylinder(r, 0.32, 0.22, 0.38, Vector3(0, 0.19, 0), straw, Vector3.ZERO, true, 12, 0, false)
	PropFactory.cylinder(r, 0.33, 0.33, 0.03, Vector3(0, 0.38, 0), PropFactory.material(Color(0.50, 0.38, 0.20), 1.0), Vector3.ZERO, false, 12, 0, false)
	if filled:
		for i in 5:
			PropFactory.sphere(r, 0.09, Vector3(cos(i * 1.3) * 0.12, 0.42, sin(i * 1.3) * 0.12), PropFactory.material(Color(0.62, 0.22, 0.12)), Vector3.ONE)
	return r


static func rope_coil(parent: Node3D, pos: Vector3, scale_m: float = 1.0) -> Node3D:
	var r := _root(parent, pos, 0.0, "RopeCoil")
	var rope := PropFactory.material(Color(0.55, 0.44, 0.26), 1.0)
	for i in 4:
		PropFactory.cylinder(r, 0.32 * scale_m, 0.32 * scale_m, 0.06, Vector3(0, 0.04 + i * 0.065, 0), rope, Vector3.ZERO, false, 14, 0, false)
	PropFactory.cylinder(r, 0.2 * scale_m, 0.2 * scale_m, 0.26, Vector3(0, 0.14, 0), PropFactory.material(Color(0.05, 0.04, 0.03), 1.0), Vector3.ZERO, false, 12, 0, false)
	return r


## Oil can / small lantern for yards and workshops.
static func oil_lamp(parent: Node3D, pos: Vector3, lit: bool = true) -> Node3D:
	var r := _root(parent, pos, 0.0, "Lantern")
	var iron := PropFactory.iron()
	PropFactory.cylinder(r, 0.09, 0.11, 0.05, Vector3(0, 0.025, 0), iron, Vector3.ZERO, false, 8, 0, false)
	PropFactory.cylinder(r, 0.08, 0.08, 0.2, Vector3(0, 0.15, 0), PropFactory.glow_lamp() if lit else PropFactory.material(Color(0.7, 0.7, 0.6), 0.2), Vector3.ZERO, false, 8, 0, false)
	PropFactory.cylinder(r, 0.1, 0.07, 0.05, Vector3(0, 0.27, 0), iron, Vector3.ZERO, false, 8, 0, false)
	PropFactory.sphere(r, 0.015, Vector3(0, 0.31, 0), iron)
	return r


static func ladder(parent: Node3D, pos: Vector3, yaw: float, height: float = 3.0) -> Node3D:
	var r := _root(parent, pos, yaw, "Ladder")
	var t := Node3D.new()
	t.rotation_degrees = Vector3(-14, 0, 0)
	r.add_child(t)
	var wood := PropFactory.wood()
	for s in [-1.0, 1.0]:
		PropFactory.cylinder(t, 0.035, 0.04, height, Vector3(s * 0.25, height * 0.5, 0), wood, Vector3.ZERO, false, 6, 0, false)
	var n := int(height / 0.32)
	for i in n:
		PropFactory.cylinder(t, 0.025, 0.025, 0.5, Vector3(0, 0.3 + i * 0.32, 0), wood, Vector3(0, 0, 90), false, 6, 0, false)
	return r


static func crate_stack(parent: Node3D, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> Node3D:
	var r := _root(parent, pos, yaw, "Crates")
	var wood := PropFactory.wood(Color(0.50, 0.37, 0.24))
	PropFactory.box(r, Vector3(0.8, 0.6, 0.8), Vector3(0, 0.3, 0), wood)
	PropFactory.box(r, Vector3(0.7, 0.55, 0.7), Vector3(0.85, 0.275, 0.05), wood, Vector3(0, rng.randf_range(-10, 10), 0))
	PropFactory.box(r, Vector3(0.65, 0.5, 0.65), Vector3(0.4, 0.85, 0.0), wood, Vector3(0, rng.randf_range(-15, 15), 0))
	return r


## A treadle spinning wheel: seat, frame, big wheel and distaff with a little wool.
static func spinning_wheel(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := _root(parent, pos, yaw, "SpinningWheel")
	var wood := PropFactory.wood()
	PropFactory.box(r, Vector3(0.9, 0.06, 0.3), Vector3(0, 0.45, 0), wood, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		PropFactory.cylinder(r, 0.03, 0.04, 0.45, Vector3(s * 0.38, 0.22, 0), wood, Vector3.ZERO, false, 6, 0, false)
	PropFactory.cylinder(r, 0.38, 0.38, 0.03, Vector3(-0.25, 0.8, 0), wood, Vector3(90, 0, 0), false, 20, 0, false)
	for k in 6:
		PropFactory.box(r, Vector3(0.74, 0.02, 0.02), Vector3(-0.25, 0.8, 0), wood, Vector3(0, 0, k * 30.0), false, false)
	PropFactory.box(r, Vector3(0.04, 0.5, 0.04), Vector3(0.3, 0.7, 0), wood, Vector3.ZERO, false, false)
	PropFactory.sphere(r, 0.1, Vector3(0.3, 1.0, 0), PropFactory.cloth(Color(0.88, 0.84, 0.74)), Vector3(1, 1.3, 1))
	return r


## Stone mortar and pestle for grinding grain.
static func grinding_stone(parent: Node3D, pos: Vector3) -> Node3D:
	var r := _root(parent, pos, 0.0, "GrindingStone")
	var stone := PropFactory.sandstone_dark()
	PropFactory.cylinder(r, 0.35, 0.4, 0.2, Vector3(0, 0.1, 0), stone, Vector3.ZERO, true, 14)
	PropFactory.cylinder(r, 0.3, 0.3, 0.12, Vector3(0, 0.26, 0), PropFactory.sandstone(), Vector3.ZERO, false, 14)
	PropFactory.cylinder(r, 0.025, 0.025, 0.5, Vector3(0.2, 0.55, 0), PropFactory.wood(), Vector3(0, 0, 12), false, 6, 0, false)
	return r
