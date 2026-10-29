class_name HouseBuilder
extends RefCounted
## A small hamlet of enterable adobe/sandstone houses on levelled ground west of the river.
## Each house has real doorways and windows, a partition wall with its own doorway, a flat
## roof with parapet and exterior stairs, timber ceiling beams, furnished rooms, a hanging
## lantern, and a ReflectionProbe that darkens the ambient light indoors.
## Furniture lives in HouseInteriors. All shapes are primitive-built placeholders.

const WALL_H := 3.2
const WALL_T := 0.5
const FLOOR_Y := 0.14          # top of the floor above the ground at the house centre
const DOOR_W := 1.4
const DOOR_H := 2.3

var terrain: TerrainBuilder
## One entry per house, for the self-test: {name, door_out, inside, half (Vector2), stair_bottom}
var houses: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init(t: TerrainBuilder, seed_value: int = 31337) -> void:
	terrain = t
	_rng.seed = seed_value


func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Hamlet"
	parent.add_child(root)
	# site index, width (x), depth (z), yaw (deg, front door faces +Z before yaw), variant
	var specs := [
		[0, 10.0, 8.0, 84.0, 0],
		[1, 9.0, 7.0, 96.0, 1],
		[2, 11.0, 8.0, 74.0, 2],
		[3, 8.0, 7.0, 108.0, 1],
		[4, 10.0, 8.0, 92.0, 0],
	]
	for s in specs:
		_house(root, s[0], s[1], s[2], s[3], s[4])
	_hamlet_details(root)
	return root


func _house(parent: Node3D, index: int, w: float, d: float, yaw: float, variant: int) -> void:
	var site := TerrainBuilder.HOUSE_SITES[index]
	var ground := terrain.sample_height(site.x, site.y)
	var h := Node3D.new()
	h.name = "House_%d" % index
	h.position = Vector3(site.x, ground, site.y)
	h.rotation_degrees = Vector3(0, yaw, 0)
	parent.add_child(h)

	var door_x := -w * 0.18 if variant != 1 else w * 0.15
	var partition_x := w * 0.14 if variant != 1 else 99.0       # 99 = no partition
	_shell(h, w, d, door_x, partition_x, variant)
	_roof(h, w, d)
	var stair := _roof_stairs(h, w, d)
	HouseInteriors.furnish(h, w, d, door_x, partition_x, variant, _rng)
	_exterior(h, w, d, door_x, variant)
	_light_and_probe(h, w, d, partition_x)

	var xf := h.transform
	houses.append({
		"name": h.name,
		"door_out": xf * Vector3(door_x, 0.0, d * 0.5 + 3.0),
		"inside": xf * Vector3(door_x, 0.0, d * 0.5 - 2.5),
		"half": Vector2(w * 0.5, d * 0.5),
		"stair_bottom": xf * stair,
		"node": h,
	})


# --- shell -------------------------------------------------------------------------------

func _piece(parent: Node3D, along_x: bool, fixed: float, a: float, b: float, y0: float, y1: float,
		mat: Material, thick: float) -> void:
	var length := b - a
	var hh := y1 - y0
	if length < 0.02 or hh < 0.02:
		return
	var c := (a + b) * 0.5
	var size := Vector3(length, hh, thick) if along_x else Vector3(thick, hh, length)
	var y := FLOOR_Y + y0 + hh * 0.5
	var pos := Vector3(c, y, fixed) if along_x else Vector3(fixed, y, c)
	PropFactory.box(parent, size, pos, mat)


## A wall run along X (at z = fixed) or along Z (at x = fixed) from a to b. Each opening is
## [centre, width, bottom, top] with heights measured from the floor.
func _wall(parent: Node3D, along_x: bool, fixed: float, a: float, b: float, openings: Array,
		mat: Material, thick: float = WALL_T, height: float = WALL_H) -> void:
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p[0] < q[0])
	var cur := a
	for o in ops:
		var o0: float = o[0] - o[1] * 0.5
		var o1: float = o[0] + o[1] * 0.5
		_piece(parent, along_x, fixed, cur, o0 + 0.1, 0.0, height, mat, thick)
		_piece(parent, along_x, fixed, o0 - 0.1, o1 + 0.1, 0.0, o[2], mat, thick)
		_piece(parent, along_x, fixed, o0 - 0.1, o1 + 0.1, o[3], height, mat, thick)
		cur = o1 - 0.1
	_piece(parent, along_x, fixed, cur, b, 0.0, height, mat, thick)


func _shell(h: Node3D, w: float, d: float, door_x: float, partition_x: float, variant: int) -> void:
	var wall_mat := PropFactory.plaster() if variant != 2 else PropFactory.mud_brick()
	var trim := PropFactory.sandstone_dark()
	var wood := PropFactory.wood()
	var hw := w * 0.5
	var hd := d * 0.5
	var t := WALL_T

	# Raised plinth and interior floor.
	PropFactory.box(h, Vector3(w + 1.0, 0.7, d + 1.0), Vector3(0, FLOOR_Y - 0.35, 0), trim)
	PropFactory.box(h, Vector3(w - 0.4, 0.06, d - 0.4), Vector3(0, FLOOR_Y - 0.01, 0),
		PropFactory.stone(Color(0.50, 0.39, 0.28), 0.1), Vector3.ZERO, false, false)

	# Front wall (door + window), back wall (two windows), side walls.
	var front := [[door_x, DOOR_W, 0.0, DOOR_H], [w * 0.28 if door_x < 0.0 else -w * 0.28, 1.0, 1.0, 2.0]]
	_wall(h, true, hd - t * 0.5, -hw, hw, front, wall_mat)
	_wall(h, true, -hd + t * 0.5, -hw, hw, [[-w * 0.22, 0.9, 1.15, 2.1], [w * 0.22, 0.9, 1.15, 2.1]], wall_mat)
	_wall(h, false, hw - t * 0.5, -hd + t, hd - t, [[0.0, 1.0, 1.0, 2.0]], wall_mat)
	_wall(h, false, -hw + t * 0.5, -hd + t, hd - t, [[-d * 0.2, 0.6, 2.1, 2.7]], wall_mat)

	# Partition wall with its own doorway.
	if partition_x < 50.0:
		_wall(h, false, partition_x, -hd + t, hd - t, [[-d * 0.12, 1.2, 0.0, 2.1]], wall_mat, 0.35)
		PropFactory.box(h, Vector3(0.45, 0.16, 1.5), Vector3(partition_x, FLOOR_Y + 2.2, -d * 0.12), wood, Vector3.ZERO, false)

	# Door: timber frame, ajar leaf, stone threshold.
	var dz := hd - t * 0.5
	for sx in [-1.0, 1.0]:
		PropFactory.box(h, Vector3(0.14, DOOR_H + 0.1, t + 0.12), Vector3(door_x + sx * (DOOR_W * 0.5 + 0.02), FLOOR_Y + DOOR_H * 0.5, dz), wood, Vector3.ZERO, false)
	PropFactory.box(h, Vector3(DOOR_W + 0.5, 0.2, t + 0.2), Vector3(door_x, FLOOR_Y + DOOR_H + 0.08, dz), wood, Vector3.ZERO, false)
	var leaf := PropFactory.box(h, Vector3(DOOR_W * 0.5, DOOR_H - 0.1, 0.07), Vector3(door_x - DOOR_W * 0.5 + 0.28, FLOOR_Y + (DOOR_H - 0.1) * 0.5, dz - 0.5), wood, Vector3(0, 62, 0), false)
	leaf.name = "DoorLeaf"
	PropFactory.box(h, Vector3(DOOR_W + 0.4, 0.14, 0.8), Vector3(door_x, FLOOR_Y - 0.03, dz + 0.1), trim, Vector3.ZERO, true)

	# Window sills, lintels and open shutters.
	var wins := [
		[true, hd - t * 0.5, w * 0.28 if door_x < 0.0 else -w * 0.28, 1.0, 1.0, 2.0],
		[true, -hd + t * 0.5, -w * 0.22, 0.9, 1.15, 2.1],
		[true, -hd + t * 0.5, w * 0.22, 0.9, 1.15, 2.1],
		[false, hw - t * 0.5, 0.0, 1.0, 1.0, 2.0],
	]
	for wv in wins:
		_window_trim(h, wv[0], wv[1], wv[2], wv[3], wv[4], wv[5], trim, wood)


func _window_trim(h: Node3D, along_x: bool, fixed: float, c: float, width: float, y0: float, y1: float,
		trim: Material, wood: Material) -> void:
	var sill_size := Vector3(width + 0.3, 0.1, WALL_T + 0.25) if along_x else Vector3(WALL_T + 0.25, 0.1, width + 0.3)
	var sill_pos := Vector3(c, FLOOR_Y + y0 - 0.04, fixed) if along_x else Vector3(fixed, FLOOR_Y + y0 - 0.04, c)
	PropFactory.box(h, sill_size, sill_pos, trim, Vector3.ZERO, false)
	var lin_size := Vector3(width + 0.4, 0.14, WALL_T + 0.1) if along_x else Vector3(WALL_T + 0.1, 0.14, width + 0.4)
	var lin_pos := Vector3(c, FLOOR_Y + y1 + 0.07, fixed) if along_x else Vector3(fixed, FLOOR_Y + y1 + 0.07, c)
	PropFactory.box(h, lin_size, lin_pos, wood, Vector3.ZERO, false)
	# Two shutter leaves swung open against the outside wall.
	var out := 1.0 if (fixed > 0.0) else -1.0
	for s in [-1.0, 1.0]:
		var leaf_h := y1 - y0 - 0.05
		var sp := Vector3(c + s * (width * 0.5 + 0.28), FLOOR_Y + y0 + leaf_h * 0.5, fixed + out * 0.32)
		var rot := Vector3(0, 0, 0)
		var size := Vector3(width * 0.5, leaf_h, 0.04)
		if not along_x:
			sp = Vector3(fixed + out * 0.32, FLOOR_Y + y0 + leaf_h * 0.5, c + s * (width * 0.5 + 0.28))
			size = Vector3(0.04, leaf_h, width * 0.5)
		PropFactory.box(h, size, sp, wood, rot, false)


# --- roof, stairs ------------------------------------------------------------------------

func _roof(h: Node3D, w: float, d: float) -> void:
	var trim := PropFactory.sandstone_dark()
	var wood := PropFactory.wood()
	var y_under := FLOOR_Y + WALL_H
	# Roof slab (walkable) and parapet.
	PropFactory.box(h, Vector3(w + 0.9, 0.45, d + 0.9), Vector3(0, y_under + 0.225, 0), PropFactory.sandstone_pale())
	var top := y_under + 0.45
	var pt := 0.3
	PropFactory.box(h, Vector3(w + 0.9, 0.5, pt), Vector3(0, top + 0.25, d * 0.5 + 0.45 - pt * 0.5), trim)
	PropFactory.box(h, Vector3(w + 0.9, 0.5, pt), Vector3(0, top + 0.25, -d * 0.5 - 0.45 + pt * 0.5), trim)
	PropFactory.box(h, Vector3(pt, 0.5, d + 0.9), Vector3(-w * 0.5 - 0.45 + pt * 0.5, top + 0.25, 0), trim)
	# East parapet stops short of the stair landing at the back.
	var east_len := d + 0.9 - 2.8
	PropFactory.box(h, Vector3(pt, 0.5, east_len), Vector3(w * 0.5 + 0.45 - pt * 0.5, top + 0.25, d * 0.5 + 0.45 - east_len * 0.5), trim)
	# Roof drain spouts and a few clay vent pots.
	PropFactory.cylinder(h, 0.1, 0.1, 0.8, Vector3(-w * 0.2, top + 0.1, d * 0.5 + 0.55), wood, Vector3(90, 0, 0), false, 8)
	PropFactory.cylinder(h, 0.22, 0.28, 0.6, Vector3(w * 0.15, top + 0.3, -d * 0.2), PropFactory.clay(), Vector3.ZERO, true, 10)
	# Protruding timber roof beams (vigas) on the front and back faces.
	var n := int(d / 1.0)
	for i in n:
		var zz := -d * 0.5 + 0.5 + i * (d - 1.0) / maxf(1.0, n - 1.0)
		PropFactory.cylinder(h, 0.1, 0.11, w + 0.9, Vector3(0, y_under - 0.14, zz), wood, Vector3(0, 0, 90), false, 8)


## Exterior stair on the east wall climbing towards the back. Returns the local position of the
## bottom of the stair (used by the self-test).
func _roof_stairs(h: Node3D, w: float, d: float) -> Vector3:
	var stone := PropFactory.sandstone()
	var steps := 9
	var roof_top := FLOOR_Y + WALL_H + 0.45
	var rise := roof_top / steps
	var run := 0.7
	var x := w * 0.5 + 0.45 + 0.6
	var z0 := d * 0.5 - 0.4
	for i in steps:
		var top := rise * (i + 1)
		PropFactory.box(h, Vector3(1.2, top + 0.6, run), Vector3(x, (top - 0.6) * 0.5, z0 - i * run), stone, Vector3.ZERO, false)
	# Landing at the top, level with the roof.
	var zl := z0 - (steps - 1) * run
	PropFactory.box(h, Vector3(1.2, roof_top + 0.6, 1.2), Vector3(x, (roof_top - 0.6) * 0.5, zl - 0.9), stone)
	# Invisible smooth ramp through the step noses (so the capsule climbs without snagging).
	var p0 := Vector3(x, 0.0, z0 + run)
	var p1 := Vector3(x, roof_top, zl)
	var theta := atan2(p1.y - p0.y, p0.z - p1.z)
	var thick := 0.5
	var centre := (p0 + p1) * 0.5 - Vector3(0, cos(theta), sin(theta)) * (thick * 0.5)
	var ramp := PropFactory.box(h, Vector3(1.2, thick, p0.distance_to(p1)), centre, stone, Vector3(rad_to_deg(theta), 0, 0), true, false)
	ramp.visible = false
	return Vector3(x, 0.0, z0 + run + 1.5)


# --- exterior dressing -------------------------------------------------------------------

func _exterior(h: Node3D, w: float, d: float, door_x: float, variant: int) -> void:
	var wood := PropFactory.wood()
	var clay := PropFactory.clay()
	var front_z := d * 0.5
	# Water jars beside the door and a stone bench.
	for i in 2:
		var jx := door_x + 1.4 + i * 0.7
		PropFactory.sphere(h, 0.42, Vector3(jx, 0.5, front_z + 0.7), clay, Vector3(1, 1.2, 1), true)
		PropFactory.cylinder(h, 0.2, 0.3, 0.1, Vector3(jx, 1.0, front_z + 0.7), clay, Vector3.ZERO, false, 10)
	PropFactory.box(h, Vector3(1.8, 0.4, 0.5), Vector3(door_x - 2.0, 0.34, front_z + 0.55), PropFactory.sandstone())
	# Shade awning over the doorway on two timber posts.
	for sx in [-1.0, 1.0]:
		PropFactory.cylinder(h, 0.07, 0.08, 2.8, Vector3(door_x + sx * 1.5, 1.4, front_z + 1.6), wood, Vector3.ZERO, true, 8)
	PropFactory.box(h, Vector3(3.4, 0.05, 1.7), Vector3(door_x, 2.78, front_z + 0.9), PropFactory.cloth(Color(0.64, 0.33, 0.20)), Vector3(-8, 0, 0), false, false)
	# Firewood stack and a drying rack with cloth.
	var wx := -w * 0.5 + 1.5
	for row in 3:
		for k in 5 - row:
			PropFactory.cylinder(h, 0.1, 0.1, 1.2, Vector3(wx + k * 0.22 + row * 0.11, 0.12 + row * 0.2, d * 0.5 + 0.7), wood, Vector3(0, 0, 90), false, 6)
	if variant != 1:
		var rx := -w * 0.5 - 1.8
		for sz in [-1.0, 1.0]:
			PropFactory.cylinder(h, 0.05, 0.06, 1.9, Vector3(rx, 0.95, sz * 1.2), wood, Vector3(0, 0, sz * 8), false, 6)
		PropFactory.cylinder(h, 0.04, 0.04, 2.6, Vector3(rx, 1.85, 0), wood, Vector3(90, 0, 0), false, 6)
		PropFactory.box(h, Vector3(0.03, 1.0, 1.4), Vector3(rx, 1.3, 0.1), PropFactory.cloth(Color(0.32, 0.42, 0.50)), Vector3(0, 0, 3), false, false)
	# Wind-blown sand banked against the back wall.
	PropFactory.sphere(h, 3.0, Vector3(0, -0.4, -d * 0.5 - 1.4), PropFactory.material(Color(0.76, 0.62, 0.42)), Vector3(1.6, 0.35, 0.7))


# --- lighting ----------------------------------------------------------------------------

func _light_and_probe(h: Node3D, w: float, d: float, partition_x: float) -> void:
	var lamp_x := -w * 0.1 if partition_x < 50.0 else 0.0
	var lamp := OmniLight3D.new()
	lamp.name = "LanternLight"
	lamp.position = Vector3(lamp_x, FLOOR_Y + 2.5, 0.0)
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 1.5
	lamp.omni_range = 7.5
	lamp.shadow_enabled = false
	h.add_child(lamp)
	if partition_x < 50.0:
		var lamp2 := OmniLight3D.new()
		lamp2.name = "BedroomLight"
		lamp2.position = Vector3((partition_x + w * 0.5) * 0.5, FLOOR_Y + 1.5, d * 0.1)
		lamp2.light_color = Color(1.0, 0.68, 0.38)
		lamp2.light_energy = 0.9
		lamp2.omni_range = 4.5
		lamp2.shadow_enabled = false
		h.add_child(lamp2)

	# Interior probe: replaces the bright sky ambient with a dim warm ambient indoors.
	var probe := ReflectionProbe.new()
	probe.name = "InteriorProbe"
	probe.position = Vector3(0, FLOOR_Y + WALL_H * 0.5, 0)
	probe.size = Vector3(w - 0.6, WALL_H, d - 0.6)
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.55, 0.45, 0.36)
	probe.ambient_color_energy = 0.3
	probe.intensity = 0.4
	h.add_child(probe)


# --- hamlet-wide details -----------------------------------------------------------------

func _hamlet_details(root: Node3D) -> void:
	var stone := PropFactory.sandstone()
	var wood := PropFactory.wood()
	# A communal well between the houses.
	var wp := Vector2(-90.0, 12.0)
	var g := terrain.sample_height(wp.x, wp.y)
	var well := Node3D.new()
	well.name = "Well"
	well.position = Vector3(wp.x, g, wp.y)
	root.add_child(well)
	for i in 10:
		var a := TAU * i / 10.0
		PropFactory.box(well, Vector3(0.7, 1.0, 0.5), Vector3(cos(a) * 1.3, 0.4, sin(a) * 1.3), stone, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	PropFactory.cylinder(well, 1.1, 1.1, 0.1, Vector3(0, 0.1, 0), PropFactory.door_stone(), Vector3.ZERO, false, 16)
	for sx in [-1.0, 1.0]:
		PropFactory.cylinder(well, 0.1, 0.12, 2.6, Vector3(sx * 1.2, 1.9, 0), wood)
	PropFactory.cylinder(well, 0.08, 0.08, 2.6, Vector3(0, 3.1, 0), wood, Vector3(0, 0, 90), false, 8)
	PropFactory.cylinder(well, 0.2, 0.25, 0.4, Vector3(0.2, 2.4, 0), wood, Vector3.ZERO, false, 10)
	# Low stone fences and a loose handcart.
	var fences := [
		[Vector2(-88.0, -2.0), 0.0, 9.0], [Vector2(-110.0, 22.0), 90.0, 8.0], [Vector2(-70.0, -52.0), 20.0, 7.0],
	]
	for f in fences:
		var fp: Vector2 = f[0]
		var count := int(f[2] / 1.4)
		for i in count:
			var off := (i - count * 0.5) * 1.4
			var rot: float = f[1]
			var px := fp.x + cos(deg_to_rad(rot)) * off
			var pz := fp.y - sin(deg_to_rad(rot)) * off
			var pg := terrain.sample_height(px, pz)
			PropFactory.box(root, Vector3(1.4, 0.8 + (i % 3) * 0.15, 0.5), Vector3(px, pg + 0.3, pz), stone, Vector3(0, rot + _rng.randf_range(-6, 6), 0))
	var cp := Vector2(-84.0, -22.0)
	var cg := terrain.sample_height(cp.x, cp.y)
	var cart := Node3D.new()
	cart.name = "HandCart"
	cart.position = Vector3(cp.x, cg, cp.y)
	cart.rotation_degrees = Vector3(0, 25, 4)
	root.add_child(cart)
	PropFactory.box(cart, Vector3(1.6, 0.12, 1.0), Vector3(0, 0.75, 0), wood)
	for sz in [-1.0, 1.0]:
		PropFactory.box(cart, Vector3(1.6, 0.4, 0.08), Vector3(0, 0.98, sz * 0.5), wood, Vector3.ZERO, false)
		PropFactory.cylinder(cart, 0.38, 0.38, 0.08, Vector3(0, 0.38, sz * 0.58), wood, Vector3(90, 0, 0), false, 14)
	PropFactory.box(cart, Vector3(1.4, 0.08, 0.08), Vector3(1.4, 0.7, 0), wood, Vector3(0, 0, -8), false)
