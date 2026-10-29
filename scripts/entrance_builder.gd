class_name EntranceBuilder
extends RefCounted
## The monumental ancient entrance at the north end of the valley: a partly buried
## staircase, a raised platform, a 34 m wide / ~30 m tall carved facade with a sealed
## door, a bronze disc ringed by seven symbols, two guardian statues and ruined columns.
## All shapes are primitive placeholders (no imported art) built from PropFactory.

const STEP_COUNT := 14
const STEP_RISE := 0.55
const STEP_RUN := 1.6
const STAIR_Z0 := -138.0
const STAIR_WIDTH := 22.0
const BASE_Y := -1.0                      # top of the first (mostly buried) step is BASE_Y + RISE
const PLATFORM_Y := 6.7                   # BASE_Y + STEP_COUNT * STEP_RISE
const FACADE_FRONT_Z := -168.0
const FACADE_HEIGHT := 30.0               # above the platform

var terrain: TerrainBuilder


func _init(t: TerrainBuilder) -> void:
	terrain = t


func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "AncientEntrance"
	parent.add_child(root)
	_stairs(root)
	_platform_and_facade(root)
	_disc_and_symbols(root)
	_statues(root)
	_approach_columns(root)
	_rubble_and_drifts(root)
	return root


func _stairs(root: Node3D) -> void:
	var stairs := Node3D.new()
	stairs.name = "Staircase"
	root.add_child(stairs)
	var stone := PropFactory.sandstone_pale()
	for i in STEP_COUNT:
		var top := BASE_Y + (i + 1) * STEP_RISE
		var z_mid := STAIR_Z0 - (i + 0.5) * STEP_RUN
		var h := top + 3.0
		var mi := PropFactory.box(stairs, Vector3(STAIR_WIDTH, h, STEP_RUN), Vector3(0, (top - 3.0) * 0.5, z_mid), stone, Vector3.ZERO, false)
		mi.name = "Step_%d" % i

	# Smooth invisible ramp so the capsule walks up instead of snagging on each step.
	var p0 := Vector3(0, BASE_Y + STEP_RISE, STAIR_Z0)
	var p1 := Vector3(0, PLATFORM_Y, STAIR_Z0 - (STEP_COUNT - 1) * STEP_RUN)
	var length := p0.distance_to(p1)
	var theta := atan2(p1.y - p0.y, p0.z - p1.z)
	var angle := rad_to_deg(theta)
	# The ramp's top face passes exactly through the step noses (p0 and p1), so it meets the
	# platform top without a lip. Its centre sits half a thickness below that plane.
	var ramp_t := 0.6
	var ramp_centre := (p0 + p1) * 0.5 - Vector3(0, cos(theta), sin(theta)) * (ramp_t * 0.5)
	var ramp := PropFactory.box(stairs, Vector3(STAIR_WIDTH, ramp_t, length), ramp_centre, stone, Vector3(angle, 0, 0), true)
	ramp.name = "StairRamp"
	ramp.visible = false
	# Low balustrade walls along both sides of the staircase.
	for side in [-1.0, 1.0]:
		var wall := PropFactory.box(stairs, Vector3(1.4, 2.4, length + 1.5), (p0 + p1) * 0.5 + Vector3(side * (STAIR_WIDTH * 0.5 + 0.7), 1.0, 0), PropFactory.sandstone(), Vector3(angle, 0, 0), false)
		wall.name = "Balustrade"


func _platform_and_facade(root: Node3D) -> void:
	var stone := PropFactory.sandstone()
	var pale := PropFactory.sandstone_pale()
	# The platform starts at the nose of the last step (so it meets the ramp exactly) and
	# runs back to the rear of the facade.
	var plat_z0 := STAIR_Z0 - (STEP_COUNT - 1) * STEP_RUN
	var plat_z1 := FACADE_FRONT_Z - 6.0
	var length := plat_z0 - plat_z1
	PropFactory.box(root, Vector3(36, PLATFORM_Y + 3.0, length), Vector3(0, (PLATFORM_Y - 3.0) * 0.5, (plat_z0 + plat_z1) * 0.5), pale)
	var base_y := PLATFORM_Y
	var z := FACADE_FRONT_Z - 3.0                                           # facade is 6 m thick
	# Pylons either side of the doorway.
	PropFactory.box(root, Vector3(11, 16, 6), Vector3(-11.5, base_y + 8.0, z), stone)
	PropFactory.box(root, Vector3(11, 16, 6), Vector3(11.5, base_y + 8.0, z), stone)
	# Lintel across the full width.
	var lintel_h := FACADE_HEIGHT - 16.0
	PropFactory.box(root, Vector3(34, lintel_h, 6), Vector3(0, base_y + 16.0 + lintel_h * 0.5, z), stone)
	# Cornice and stepped crown for a monumental silhouette.
	PropFactory.box(root, Vector3(36, 1.6, 7.5), Vector3(0, base_y + FACADE_HEIGHT + 0.8, z), pale)
	PropFactory.box(root, Vector3(24, 2.0, 6.5), Vector3(0, base_y + FACADE_HEIGHT + 2.6, z), stone)
	# Sealed stone door, recessed into the doorway.
	var door := Node3D.new()
	door.name = "SealedDoor"
	door.position = Vector3(0, base_y, FACADE_FRONT_Z - 4.6)
	root.add_child(door)
	PropFactory.box(door, Vector3(12, 16, 1.6), Vector3(0, 8.0, 0), PropFactory.door_stone())
	var bronze := PropFactory.bronze()
	for k in 4:
		PropFactory.box(door, Vector3(12.4, 0.5, 0.5), Vector3(0, 2.0 + k * 4.0, 1.0), bronze, Vector3.ZERO, false)
	PropFactory.box(door, Vector3(0.5, 16, 0.5), Vector3(0, 8.0, 1.0), bronze, Vector3.ZERO, false)
	# Engraved-looking vertical pilasters flanking the door.
	for sx in [-6.4, 6.4]:
		PropFactory.box(root, Vector3(1.0, 16, 1.0), Vector3(sx, base_y + 8.0, FACADE_FRONT_Z + 0.4), pale, Vector3.ZERO, false)
	# Broken wall wings extending from the facade.
	var wings := [
		[Vector3(14, 11, 5), -24.0, -164.0, Vector3(0, 6, 3), stone],
		[Vector3(11, 6, 5), 23.5, -164.0, Vector3(0, -8, -4), stone],
		[Vector3(7, 3.5, 4), 31.0, -162.0, Vector3(4, -15, 8), pale],
	]
	for w in wings:
		var ws: Vector3 = w[0]
		var wg := terrain.sample_height(w[1], w[2])
		PropFactory.box(root, ws, Vector3(w[1], wg + ws.y * 0.5 - 1.2, w[2]), w[4], w[3])


func _disc_and_symbols(root: Node3D) -> void:
	var centre := Vector3(0, PLATFORM_Y + 23.0, FACADE_FRONT_Z + 0.6)
	var disc := Node3D.new()
	disc.name = "BronzeDisc"
	disc.position = centre
	root.add_child(disc)
	var bronze := PropFactory.bronze()
	PropFactory.cylinder(disc, 3.8, 3.8, 0.8, Vector3.ZERO, bronze, Vector3(90, 0, 0), false, 32)
	PropFactory.cylinder(disc, 2.5, 2.5, 1.1, Vector3(0, 0, 0.1), PropFactory.sandstone_dark(), Vector3(90, 0, 0), false, 24)
	PropFactory.cylinder(disc, 1.4, 1.4, 1.4, Vector3(0, 0, 0.2), PropFactory.glow_bronze(), Vector3(90, 0, 0), false, 20)
	PropFactory.sphere(disc, 0.8, Vector3(0, 0, 1.0), bronze)

	var ring := Node3D.new()
	ring.name = "SevenSymbols"
	ring.position = centre + Vector3(0, 0, 0.1)
	root.add_child(ring)
	for i in 7:
		var a := deg_to_rad(90.0 - i * (360.0 / 7.0))
		PropFactory.symbol(ring, i, Vector3(cos(a) * 5.6, sin(a) * 5.6, 0), 0.9)


func _statues(root: Node3D) -> void:
	var specs := [[-27.0, 10.0, false], [27.0, -10.0, true]]
	for s in specs:
		var x: float = s[0]
		var ground := maxf(terrain.sample_height(x, -154.0), 0.0)
		var st := PropFactory.statue(root, Vector3(x, ground, -154.0), s[1], s[2])
		st.name = "GuardianStatue_%s" % ("W" if x < 0.0 else "E")
		# Deep foundation so the plinth never floats on uneven ground.
		PropFactory.box(st, Vector3(11, 8, 11), Vector3(0, -3.5, 0), PropFactory.sandstone_dark())


func _approach_columns(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var cols := Node3D.new()
	cols.name = "ApproachColumns"
	root.add_child(cols)
	for k in 7:
		var z := -100.0 - k * 5.5
		for x in [-17.0, 17.0]:
			var xx: float = x + rng.randf_range(-1.2, 1.2)
			var zz := z + rng.randf_range(-1.0, 1.0)
			var ground := terrain.sample_height(xx, zz)
			var broken := rng.randf() < 0.45 or k > 4
			PropFactory.column(cols, Vector3(xx, ground, zz), rng.randf_range(9.0, 13.0), 0.9, broken, rng)
	# Two much larger columns marking the outer corners of the forecourt.
	for x in [-34.0, 34.0]:
		var ground := terrain.sample_height(x, -128.0)
		PropFactory.column(cols, Vector3(x, ground, -128.0), 17.0, 1.7, x > 0.0, rng)


func _rubble_and_drifts(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rub := Node3D.new()
	rub.name = "Rubble"
	root.add_child(rub)
	var mats := [PropFactory.sandstone(), PropFactory.sandstone_pale(), PropFactory.sandstone_dark()]
	for i in 36:
		var x := rng.randf_range(-30.0, 30.0)
		var z := rng.randf_range(-160.0, -106.0)
		if absf(x) < 11.5 and z < -136.0:
			continue
		var s := Vector3(rng.randf_range(0.8, 3.2), rng.randf_range(0.5, 2.0), rng.randf_range(0.8, 3.0))
		var y := terrain.sample_height(x, z) + s.y * 0.3
		PropFactory.box(rub, s, Vector3(x, y, z), mats[rng.randi() % mats.size()],
			Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-12, 12)))
	# Wind-blown sand banked against the lowest steps and the facade walls.
	var sand := PropFactory.material(Color(0.80, 0.64, 0.38))
	var drifts := [
		[Vector3(-10.5, 0.0, -141.0), 6.5, Vector3(1.0, 0.32, 1.5)],
		[Vector3(9.0, 0.0, -138.0), 5.0, Vector3(1.2, 0.28, 1.2)],
		[Vector3(-17.0, 2.0, -166.0), 7.0, Vector3(1.4, 0.45, 1.0)],
		[Vector3(19.0, 1.0, -165.0), 6.0, Vector3(1.3, 0.4, 1.0)],
	]
	for d in drifts:
		var sm := PropFactory.sphere(rub, d[1], d[0], sand, d[2], false)
		sm.name = "SandDrift"
