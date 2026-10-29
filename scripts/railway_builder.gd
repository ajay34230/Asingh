class_name RailwayBuilder
extends RefCounted
## A derelict broad-gauge goods line ("maal gaadi") cutting east-west across the valley:
## levelled embankment (terrain strip), ballast, sleepers (MultiMesh), rails, a parked goods
## train (steam locomotive, tender, boxcar, open gondola, flatcar, covered wagon, tank wagon),
## a loading dock you can walk onto and into the boxcar, goods shed, water tower, signal,
## telegraph poles, crates/sacks/barrels and a wooden cargo cart. Static scenery only.

const RAIL_Z := 96.0
const RAIL_Y := 2.0                 # terrain strip height (see TerrainBuilder)
const GAUGE := 1.676                # Indian broad gauge
const RAIL_TOP := RAIL_Y + 0.30
const TRACK_HALF_LEN := 120.0
const DOCK_H := 1.4               # dock top above RAIL_Y; equals wagon floor (RAIL_TOP + FL)
const FL := 1.1                   # wagon floor height above the rail head

var terrain: TerrainBuilder
var train_x0 := -50.0
## For the self-test / captures.
var boxcar_door_world := Vector3.ZERO
var dock_ramp_foot := Vector3.ZERO
var train_centre := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init(t: TerrainBuilder) -> void:
	terrain = t
	_rng.seed = 424242


func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Railway"
	parent.add_child(root)
	_track(root)
	_train(root)
	_yard(root)
	_telegraph(root)
	return root


# --- track -------------------------------------------------------------------------------

func _track(root: Node3D) -> void:
	var gravel := PropFactory.material(Color(0.47, 0.43, 0.38), 1.0)
	var rail_mat := PropFactory.material(Color(0.33, 0.20, 0.14), 0.7, 0.6)
	var wood := PropFactory.wood(Color(0.27, 0.19, 0.13))
	var len := TRACK_HALF_LEN * 2.0
	PropFactory.box(root, Vector3(len, 0.22, 3.6), Vector3(0, RAIL_Y + 0.04, RAIL_Z), gravel, Vector3.ZERO, false, false)
	for s in [-1.0, 1.0]:
		PropFactory.box(root, Vector3(len, 0.16, 0.075), Vector3(0, RAIL_TOP - 0.08, RAIL_Z + s * GAUGE * 0.5), rail_mat, Vector3.ZERO, false, false)
		PropFactory.box(root, Vector3(len, 0.04, 0.16), Vector3(0, RAIL_TOP - 0.16, RAIL_Z + s * GAUGE * 0.5), rail_mat, Vector3.ZERO, false, false)
	# Sleepers.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.26, 0.16, 2.5)
	mm.mesh = bm
	var count := int(len / 0.72)
	mm.instance_count = count
	for i in count:
		var x := -TRACK_HALF_LEN + i * 0.72
		var jitter := _rng.randf_range(-0.03, 0.03)
		var b := Basis(Vector3.UP, jitter)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, RAIL_Y + 0.16, RAIL_Z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sleepers"
	mmi.multimesh = mm
	mmi.material_override = wood
	root.add_child(mmi)
	# Sand drifts burying the track ends, plus a few rusty fishplate/spike details.
	for sx in [-1.0, 1.0]:
		PropFactory.sphere(root, 6.0, Vector3(sx * (TRACK_HALF_LEN + 3.0), RAIL_Y - 0.5, RAIL_Z), PropFactory.material(Color(0.74, 0.60, 0.40)), Vector3(2.2, 0.7, 1.2))
	for i in 24:
		var x := _rng.randf_range(-TRACK_HALF_LEN + 10.0, TRACK_HALF_LEN - 10.0)
		PropFactory.sphere(root, _rng.randf_range(0.6, 1.4), Vector3(x, RAIL_Y + 0.05, RAIL_Z + _rng.randf_range(-1.8, 1.8)), PropFactory.material(Color(0.74, 0.60, 0.40)), Vector3(1.8, 0.25, 1.0))


# --- train -------------------------------------------------------------------------------

func _train(root: Node3D) -> void:
	var cursor := train_x0
	var kinds := [["tank", 8.0], ["covered", 8.4], ["flat", 8.4], ["gondola", 8.4], ["boxcar", 8.8], ["tender", 6.0], ["loco", 11.0]]
	for k in kinds:
		var L: float = k[1]
		var w := Node3D.new()
		w.name = "Wagon_" + str(k[0])
		w.position = Vector3(cursor + L * 0.5, RAIL_TOP, RAIL_Z)
		root.add_child(w)
		_running_gear(w, L, k[0] == "loco")
		match k[0]:
			"tank": _tank(w, L)
			"covered": _covered(w, L)
			"flat": _flat(w, L)
			"gondola": _gondola(w, L)
			"boxcar":
				_boxcar(w, L)
				boxcar_door_world = w.position + Vector3(0, DOCK_H + 0.4, -GAUGE * 0.5 - 1.5)
			"tender": _tender(w, L)
			"loco": _loco(w, L)
		# Link between vehicles.
		if k[0] != "loco":
			PropFactory.box(root, Vector3(1.0, 0.1, 0.1), Vector3(cursor + L + 0.45, RAIL_TOP + 0.9, RAIL_Z), PropFactory.iron(), Vector3.ZERO, false, false)
		cursor += L + 0.9
	train_centre = Vector3((train_x0 + cursor) * 0.5, RAIL_TOP, RAIL_Z)


func _wheel(w: Node3D, x: float, side: float, r: float) -> void:
	var iron := PropFactory.iron()
	var z := side * GAUGE * 0.5
	PropFactory.cylinder(w, r, r, 0.1, Vector3(x, r - 0.02, z), iron, Vector3(90, 0, 0), false, 18, 0, false)
	PropFactory.cylinder(w, r * 0.35, r * 0.35, 0.16, Vector3(x, r - 0.02, z + side * 0.02), iron, Vector3(90, 0, 0), false, 10, 0, false)
	PropFactory.cylinder(w, r + 0.04, r + 0.04, 0.03, Vector3(x, r - 0.02, z - side * 0.06), iron, Vector3(90, 0, 0), false, 18, 0, false)


func _running_gear(w: Node3D, L: float, is_loco: bool) -> void:
	if is_loco:
		return
	for ax in [-L * 0.32, L * 0.32]:
		for s in [-1.0, 1.0]:
			_wheel(w, ax, s, 0.46)
		PropFactory.cylinder(w, 0.06, 0.06, GAUGE + 0.3, Vector3(ax, 0.44, 0), PropFactory.iron(), Vector3(90, 0, 0), false, 8, 0, false)
	# Leaf springs and axle boxes.
	for ax in [-L * 0.32, L * 0.32]:
		for s in [-1.0, 1.0]:
			PropFactory.box(w, Vector3(1.1, 0.08, 0.1), Vector3(ax, 0.88, s * (GAUGE * 0.5 + 0.12)), PropFactory.iron(), Vector3.ZERO, false, false)
	# Buffers.
	for sx in [-1.0, 1.0]:
		for sz in [-0.8, 0.8]:
			PropFactory.cylinder(w, 0.14, 0.14, 0.4, Vector3(sx * (L * 0.5 + 0.2), 1.05, sz), PropFactory.iron(), Vector3(0, 0, 90), false, 10, 0, false)
			PropFactory.cylinder(w, 0.2, 0.2, 0.05, Vector3(sx * (L * 0.5 + 0.42), 1.05, sz), PropFactory.iron(), Vector3(0, 0, 90), false, 10, 0, false)


func _paint(c: Color) -> StandardMaterial3D:
	return PropFactory.material(c, 0.9)


func _frame(w: Node3D, L: float) -> void:
	PropFactory.box(w, Vector3(L + 0.2, 0.22, 2.7), Vector3(0, 0.98, 0), PropFactory.wood(Color(0.20, 0.15, 0.11)))
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(L, 0.2, 0.12), Vector3(0, 0.78, s * 0.7), PropFactory.iron(), Vector3.ZERO, false, false)


func _boxcar(w: Node3D, L: float) -> void:
	_frame(w, L)
	var red := _paint(Color(0.43, 0.20, 0.14))
	var plank := PropFactory.wood(Color(0.44, 0.30, 0.20))
	var bt := 0.12
	var top := FL + 2.35
	# +z wall solid, -z wall with a 3.2 m sliding-door gap (towards the dock).
	PropFactory.box(w, Vector3(L, 2.35, bt), Vector3(0, FL + 1.175, 1.29), red)
	var gap := 3.2
	var seg := (L - gap) * 0.5
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(seg, 2.35, bt), Vector3(s * (gap * 0.5 + seg * 0.5), FL + 1.175, -1.29), red)
	PropFactory.box(w, Vector3(gap, 0.3, bt), Vector3(0, FL + 2.2, -1.29), red, Vector3.ZERO, false)
	# Sliding door panel pushed along the outside, with rail and handle.
	PropFactory.box(w, Vector3(gap * 0.95, 2.2, 0.08), Vector3(gap * 0.95 + 0.9, FL + 1.1, -1.43), plank, Vector3.ZERO, false)
	PropFactory.box(w, Vector3(L * 0.9, 0.06, 0.08), Vector3(0, FL + 2.3, -1.45), PropFactory.iron(), Vector3.ZERO, false, false)
	# Ends and roof.
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(bt, 2.35, 2.7), Vector3(s * (L * 0.5 - bt * 0.5), FL + 1.175, 0), red)
	PropFactory.box(w, Vector3(L + 0.3, 0.1, 2.9), Vector3(0, top + 0.05, 0), PropFactory.iron())
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(L + 0.3, 0.08, 1.0), Vector3(0, top + 0.17, s * 0.55), PropFactory.iron(), Vector3(s * 8, 0, 0), false, false)
	# Diagonal bracing and rust streaks on the visible long side.
	for i in 3:
		PropFactory.box(w, Vector3(0.1, 2.3, 0.04), Vector3(-L * 0.4 + i * L * 0.4, FL + 1.15, 1.36), plank, Vector3.ZERO, false, false)
	# Cargo inside: crates, sacks and barrels, with a clear walkway next to the door.
	var crate := PropFactory.wood(Color(0.55, 0.40, 0.25))
	var sack := PropFactory.cloth(Color(0.70, 0.60, 0.42))
	PropFactory.box(w, Vector3(0.9, 0.9, 0.9), Vector3(-3.4, FL + 0.55, 0.5), crate)
	PropFactory.box(w, Vector3(0.9, 0.9, 0.9), Vector3(-3.4, FL + 0.55, -0.45), crate)
	PropFactory.box(w, Vector3(0.8, 0.8, 0.8), Vector3(-3.4, FL + 1.4, 0.0), crate, Vector3(0, 12, 0))
	for i in 5:
		PropFactory.box(w, Vector3(0.55, 0.28, 0.9), Vector3(3.0 + (i % 2) * 0.1, FL + 0.24 + (i / 2) * 0.28, 0.5 - 0.0), sack, Vector3(0, 6 * i, 0), false, false)
	PropFactory.cylinder(w, 0.35, 0.35, 0.9, Vector3(3.3, FL + 0.55, -0.6), PropFactory.wood(Color(0.33, 0.22, 0.14)), Vector3.ZERO, true, 12, 0, false)


func _gondola(w: Node3D, L: float) -> void:
	_frame(w, L)
	var side := _paint(Color(0.30, 0.31, 0.30))
	var h := 1.4
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(L, h, 0.1), Vector3(0, FL + h * 0.5, s * 1.3), side)
		PropFactory.box(w, Vector3(0.1, h, 2.7), Vector3(s * (L * 0.5 - 0.05), FL + h * 0.5, 0), side)
	# Ribs.
	for i in 6:
		for s in [-1.0, 1.0]:
			PropFactory.box(w, Vector3(0.1, h, 0.06), Vector3(-L * 0.42 + i * L * 0.168, FL + h * 0.5, s * 1.36), PropFactory.iron(), Vector3.ZERO, false, false)
	# Loose load heaped inside (stone chunks / coal).
	var coal := PropFactory.material(Color(0.10, 0.09, 0.09), 0.8)
	for i in 14:
		PropFactory.rock(w, Vector3(0.45, 0.35, 0.45) * _rng.randf_range(0.8, 1.6), Vector3(_rng.randf_range(-L * 0.4, L * 0.4), FL + 0.6 + _rng.randf_range(0.0, 0.45), _rng.randf_range(-0.8, 0.8)), coal, _rng.randf_range(0, 360), false)


func _flat(w: Node3D, L: float) -> void:
	_frame(w, L)
	var wood := PropFactory.wood(Color(0.40, 0.28, 0.19))
	# Low drop sides, then barrels strapped down and a tarp-covered stack.
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(L, 0.3, 0.07), Vector3(0, FL + 0.25, s * 1.32), wood, Vector3.ZERO, false)
	var barrel := PropFactory.wood(Color(0.36, 0.24, 0.15))
	for i in 5:
		for j in 2:
			PropFactory.cylinder(w, 0.4, 0.4, 0.95, Vector3(-L * 0.4 + i * 0.95, FL + 0.65, -0.6 + j * 1.2), barrel, Vector3.ZERO, true, 12, 0, false)
			PropFactory.cylinder(w, 0.42, 0.42, 0.05, Vector3(-L * 0.4 + i * 0.95, FL + 0.5, -0.6 + j * 1.2), PropFactory.iron(), Vector3.ZERO, false, 12, 0, false)
	PropFactory.box(w, Vector3(2.4, 1.2, 1.8), Vector3(L * 0.28, FL + 0.85, 0), PropFactory.cloth(Color(0.30, 0.38, 0.30)), Vector3(0, 4, 0))
	PropFactory.box(w, Vector3(0.04, 1.25, 1.85), Vector3(L * 0.28 - 0.4, FL + 0.85, 0), PropFactory.cloth(Color(0.22, 0.22, 0.20)), Vector3(0, 4, 0), false, false)


func _covered(w: Node3D, L: float) -> void:
	_frame(w, L)
	var canvas := PropFactory.cloth(Color(0.60, 0.55, 0.42))
	PropFactory.box(w, Vector3(L - 0.4, 0.4, 2.5), Vector3(0, FL + 0.4, 0), PropFactory.wood(Color(0.30, 0.21, 0.15)))
	# Hooped canvas roof.
	for i in 6:
		PropFactory.box(w, Vector3(0.06, 1.9, 2.5), Vector3(-L * 0.42 + i * L * 0.168, FL + 1.45, 0), PropFactory.wood(Color(0.30, 0.21, 0.15)), Vector3.ZERO, false, false)
	PropFactory.box(w, Vector3(L - 0.5, 1.5, 2.3), Vector3(0, FL + 1.4, 0), canvas)
	PropFactory.box(w, Vector3(L - 0.5, 0.35, 2.0), Vector3(0, FL + 2.3, 0), canvas, Vector3.ZERO, false)
	# Torn flap.
	PropFactory.box(w, Vector3(0.05, 1.2, 1.2), Vector3(L * 0.5 - 0.35, FL + 1.2, 0.2), PropFactory.cloth(Color(0.52, 0.47, 0.36)), Vector3(8, 0, 12), false, false)


func _tank(w: Node3D, L: float) -> void:
	_frame(w, L)
	var tank := PropFactory.material(Color(0.14, 0.14, 0.15), 0.6, 0.4)
	PropFactory.cylinder(w, 1.15, 1.15, L - 1.2, Vector3(0, FL + 1.15, 0), tank, Vector3(0, 0, 90), true, 20, 0, false)
	PropFactory.sphere(w, 1.15, Vector3((L - 1.2) * 0.5, FL + 1.15, 0), tank, Vector3(0.5, 1.0, 1.0))
	PropFactory.sphere(w, 1.15, Vector3(-(L - 1.2) * 0.5, FL + 1.15, 0), tank, Vector3(0.5, 1.0, 1.0))
	PropFactory.cylinder(w, 0.35, 0.4, 0.3, Vector3(0, FL + 2.4, 0), PropFactory.iron(), Vector3.ZERO, false, 12, 0, false)
	for s in [-1.0, 1.0]:
		PropFactory.cylinder(w, 1.18, 1.18, 0.07, Vector3(s * L * 0.28, FL + 1.15, 0), PropFactory.iron(), Vector3(0, 0, 90), false, 20, 0, false)
	PropFactory.box(w, Vector3(0.05, 0.9, 0.5), Vector3(0, FL + 2.0, 1.1), PropFactory.iron(), Vector3.ZERO, false, false)


func _tender(w: Node3D, L: float) -> void:
	_frame(w, L)
	var black := PropFactory.material(Color(0.07, 0.07, 0.08), 0.7, 0.3)
	PropFactory.box(w, Vector3(L - 0.2, 1.7, 2.6), Vector3(0, FL + 0.95, 0), black)
	PropFactory.box(w, Vector3(L - 0.6, 0.12, 2.0), Vector3(0, FL + 1.85, 0), PropFactory.iron(), Vector3.ZERO, false)
	var coal := PropFactory.material(Color(0.08, 0.08, 0.08), 0.8)
	for i in 10:
		PropFactory.rock(w, Vector3(0.4, 0.3, 0.4) * _rng.randf_range(0.8, 1.5), Vector3(_rng.randf_range(-L * 0.35, L * 0.35), FL + 1.95 + _rng.randf_range(0, 0.25), _rng.randf_range(-0.8, 0.8)), coal, _rng.randf_range(0, 360), false)


func _loco(w: Node3D, L: float) -> void:
	var black := PropFactory.material(Color(0.08, 0.08, 0.09), 0.65, 0.35)
	var green := PropFactory.material(Color(0.12, 0.25, 0.18), 0.8, 0.2)
	var brass := PropFactory.bronze()
	var iron := PropFactory.iron()
	# Frame, boiler, smokebox, chimney, dome.
	PropFactory.box(w, Vector3(L, 0.4, 2.3), Vector3(0, 1.0, 0), black)
	var bx := 1.2
	PropFactory.cylinder(w, 1.0, 1.0, 6.4, Vector3(bx, 2.35, 0), green, Vector3(0, 0, 90), true, 20, 0, false)
	for i in 4:
		PropFactory.cylinder(w, 1.03, 1.03, 0.08, Vector3(bx - 2.2 + i * 1.5, 2.35, 0), brass, Vector3(0, 0, 90), false, 20, 0, false)
	PropFactory.cylinder(w, 1.05, 1.05, 1.0, Vector3(bx + 3.5, 2.35, 0), black, Vector3(0, 0, 90), true, 20, 0, false)
	PropFactory.cylinder(w, 0.5, 0.3, 1.5, Vector3(bx + 3.4, 3.95, 0), black, Vector3.ZERO, true, 14, 0, false)
	PropFactory.sphere(w, 0.5, Vector3(bx + 0.5, 3.35, 0), brass, Vector3(1, 0.8, 1))
	PropFactory.cylinder(w, 0.1, 0.1, 0.5, Vector3(bx - 1.0, 3.5, 0), brass, Vector3.ZERO, false, 8, 0, false)
	# Headlamp, cowcatcher, front buffer beam.
	PropFactory.cylinder(w, 0.28, 0.28, 0.3, Vector3(bx + 4.1, 2.35, 0), black, Vector3(0, 0, 90), false, 12, 0, false)
	PropFactory.sphere(w, 0.2, Vector3(bx + 4.3, 2.35, 0), PropFactory.glow_lamp())
	PropFactory.box(w, Vector3(1.6, 0.1, 2.3), Vector3(L * 0.5 + 0.55, 0.7, 0), black, Vector3(0, 0, 18), false)
	PropFactory.box(w, Vector3(0.25, 0.4, 2.5), Vector3(L * 0.5 + 0.1, 1.1, 0), black)
	# Cab: walls with window openings, roof, floor.
	var cx := -L * 0.5 + 1.5
	PropFactory.box(w, Vector3(3.0, 0.15, 2.6), Vector3(cx, 1.3, 0), black)
	for s in [-1.0, 1.0]:
		PropFactory.box(w, Vector3(3.0, 0.9, 0.1), Vector3(cx, 1.85, s * 1.25), black)
		PropFactory.box(w, Vector3(0.9, 1.3, 0.1), Vector3(cx - 1.05, 3.0, s * 1.25), black)
		PropFactory.box(w, Vector3(0.9, 1.3, 0.1), Vector3(cx + 1.05, 3.0, s * 1.25), black)
		PropFactory.box(w, Vector3(3.0, 0.2, 0.1), Vector3(cx, 3.75, s * 1.25), black, Vector3.ZERO, false)
	PropFactory.box(w, Vector3(0.1, 2.4, 2.5), Vector3(cx + 1.45, 2.6, 0), black)
	PropFactory.box(w, Vector3(3.4, 0.12, 3.0), Vector3(cx - 0.1, 3.9, 0), black, Vector3.ZERO, false)
	# Driving wheels (3 per side) with coupling rod, plus leading bogie wheels.
	for s in [-1.0, 1.0]:
		for dx in [-1.4, 0.2, 1.8]:
			var x: float = bx - 0.4 + dx
			_wheel(w, x, s, 0.8)
		PropFactory.box(w, Vector3(3.4, 0.1, 0.06), Vector3(bx - 0.2, 0.9, s * (GAUGE * 0.5 + 0.12)), iron, Vector3.ZERO, false, false)
		PropFactory.cylinder(w, 0.1, 0.1, 2.4, Vector3(bx + 2.2, 1.35, s * 1.0), iron, Vector3(0, 0, 90 + 4), false, 8, 0, false)
		for dx in [-3.3, -4.0]:
			_wheel(w, bx + 3.2 + dx * -1.0 - 0.5, s, 0.4)


# --- yard: dock, goods shed, water tower, signal ----------------------------------------

func _yard(root: Node3D) -> void:
	var wood := PropFactory.wood(Color(0.37, 0.26, 0.17))
	var stone := PropFactory.sandstone()
	# Loading dock on the north (-z) side, along the gondola and boxcar.
	var dock_x0 := train_x0 + 8.0 + 8.4 + 8.4 + 2.7        # start at gondola
	var dock_x1 := dock_x0 + 8.4 + 8.8 + 0.9
	var dz := RAIL_Z - 3.95                                  # centre z of dock (inner edge 0.2 m from wagons)
	PropFactory.box(root, Vector3(dock_x1 - dock_x0, DOCK_H, 4.8), Vector3((dock_x0 + dock_x1) * 0.5, RAIL_Y + DOCK_H * 0.5 - 0.04, dz), stone)
	PropFactory.box(root, Vector3(dock_x1 - dock_x0 + 0.2, 0.12, 5.0), Vector3((dock_x0 + dock_x1) * 0.5, RAIL_Y + DOCK_H - 0.02, dz), wood, Vector3.ZERO, true, false)
	# Ramp down at the west end (slope ~10 degrees).
	var ramp_len := 6.0
	var ang := atan2(DOCK_H, ramp_len)
	var hyp := sqrt(ramp_len * ramp_len + DOCK_H * DOCK_H)
	PropFactory.box(root, Vector3(hyp, 0.2, 3.0), Vector3(dock_x0 - ramp_len * 0.5, RAIL_Y + DOCK_H * 0.5 - 0.1, dz), wood, Vector3(0, 0, rad_to_deg(ang)))
	dock_ramp_foot = Vector3(dock_x0 - ramp_len - 1.0, RAIL_Y, dz)
	# Goods on the dock: crates, sacks, barrels, hand trolley.
	var crate := PropFactory.wood(Color(0.55, 0.40, 0.25))
	var sack := PropFactory.cloth(Color(0.72, 0.62, 0.44))
	var top := RAIL_Y + DOCK_H
	for i in 6:
		var cx := dock_x0 + 2.0 + (i % 3) * 1.1
		var cz := dz - 1.2 - (i / 3) * 0.0
		PropFactory.box(root, Vector3(0.9, 0.8, 0.9), Vector3(cx, top + 0.4 + (0.8 if i == 4 else 0.0), cz), crate, Vector3(0, _rng.randf_range(-12, 12), 0))
	for i in 7:
		PropFactory.box(root, Vector3(0.55, 0.3, 0.95), Vector3(dock_x1 - 2.5 + (i % 2) * 0.55, top + 0.18 + (i / 2) * 0.3, dz - 1.4), sack, Vector3(0, _rng.randf_range(-8, 8), 0))
	for i in 3:
		PropFactory.cylinder(root, 0.4, 0.4, 0.95, Vector3(dock_x0 + 9.0 + i * 0.9, top + 0.48, dz + 1.0), PropFactory.wood(Color(0.34, 0.23, 0.14)), Vector3.ZERO, true, 12, 0, false)

	# Goods shed behind the dock.
	var sx := (dock_x0 + dock_x1) * 0.5
	var sz := dz - 7.5
	var plaster := PropFactory.plaster()
	PropFactory.box(root, Vector3(14.0, 4.0, 0.4), Vector3(sx, RAIL_Y + 2.0, sz - 3.5), plaster)
	for s in [-1.0, 1.0]:
		PropFactory.box(root, Vector3(0.4, 4.0, 7.0), Vector3(sx + s * 7.0, RAIL_Y + 2.0, sz), plaster)
	PropFactory.box(root, Vector3(4.5, 4.0, 0.4), Vector3(sx - 4.75, RAIL_Y + 2.0, sz + 3.5), plaster)
	PropFactory.box(root, Vector3(4.5, 4.0, 0.4), Vector3(sx + 4.75, RAIL_Y + 2.0, sz + 3.5), plaster)
	PropFactory.box(root, Vector3(5.0, 1.0, 0.4), Vector3(sx, RAIL_Y + 3.5, sz + 3.5), plaster)
	PropFactory.box(root, Vector3(14.6, 0.3, 7.8), Vector3(sx, RAIL_Y + 4.2, sz), PropFactory.iron())
	PropFactory.box(root, Vector3(14.6, 0.2, 4.2), Vector3(sx, RAIL_Y + 4.7, sz + 1.0), PropFactory.iron(), Vector3(-14, 0, 0), false)
	PropFactory.box(root, Vector3(14.6, 0.2, 4.2), Vector3(sx, RAIL_Y + 4.7, sz - 1.0), PropFactory.iron(), Vector3(14, 0, 0), false)
	for i in 4:
		PropFactory.box(root, Vector3(0.9, 0.9, 0.9), Vector3(sx - 4.0 + (i % 2) * 1.0, RAIL_Y + 0.5 + (i / 2) * 0.9, sz - 2.5), crate)
	PropFactory.box(root, Vector3(0.1, 0.8, 2.0), Vector3(sx + 6.78, RAIL_Y + 2.4, sz - 1.0), wood, Vector3.ZERO, false, false)
	PropFactory.cylinder(root, 0.05, 0.05, 1.5, Vector3(sx + 3.0, RAIL_Y + 4.0, sz + 3.9), PropFactory.iron(), Vector3.ZERO, false, 6, 0, false)
	PropFactory.sphere(root, 0.2, Vector3(sx + 3.0, RAIL_Y + 3.3, sz + 4.0), PropFactory.glow_lamp())

	# Water tower west of the train.
	var wx := train_x0 - 14.0
	var wz := RAIL_Z + 6.0
	var gy := RAIL_Y
	for ix in [-1.0, 1.0]:
		for iz in [-1.0, 1.0]:
			PropFactory.cylinder(root, 0.18, 0.22, 7.5, Vector3(wx + ix * 1.6, gy + 3.7, wz + iz * 1.6), wood, Vector3(iz * 3, 0, -ix * 3))
	PropFactory.cylinder(root, 2.4, 2.4, 3.0, Vector3(wx, gy + 9.0, wz), PropFactory.material(Color(0.28, 0.20, 0.16), 0.8), Vector3.ZERO, true, 20, 0, false)
	PropFactory.cylinder(root, 0.2, 2.5, 1.0, Vector3(wx, gy + 11.0, wz), PropFactory.iron(), Vector3.ZERO, false, 20, 0, false)
	PropFactory.cylinder(root, 0.2, 0.2, 5.0, Vector3(wx + 2.6, gy + 6.0, wz), PropFactory.iron(), Vector3(0, 0, 18), false, 8, 0, false)

	# Semaphore signal east of the train.
	var gx := train_x0 + 80.0
	PropFactory.cylinder(root, 0.12, 0.16, 6.5, Vector3(gx, gy + 3.25, RAIL_Z + 2.8), PropFactory.iron())
	PropFactory.box(root, Vector3(2.0, 0.3, 0.06), Vector3(gx + 0.8, gy + 6.0, RAIL_Z + 2.8), PropFactory.material(Color(0.55, 0.15, 0.12)), Vector3(0, 0, 28), false, false)
	PropFactory.sphere(root, 0.22, Vector3(gx, gy + 5.2, RAIL_Z + 2.6), PropFactory.glow_lamp())

	# Wooden cargo cart (bullock cart) with sacks, near the dock ramp.
	_cargo_cart(root, Vector3(dock_x0 - 11.0, RAIL_Y, dz + 0.5), 20.0)
	_cargo_cart(root, Vector3(dock_x1 + 9.0, RAIL_Y, dz - 1.0), -35.0)


func _cargo_cart(root: Node3D, pos: Vector3, yaw: float) -> void:
	var c := Node3D.new()
	c.name = "CargoCart"
	c.position = pos
	c.rotation_degrees = Vector3(0, yaw, 0)
	root.add_child(c)
	var wood := PropFactory.wood(Color(0.40, 0.28, 0.18))
	var dark := PropFactory.wood(Color(0.25, 0.17, 0.11))
	PropFactory.box(c, Vector3(3.0, 0.14, 1.7), Vector3(0, 0.95, 0), wood)
	for s in [-1.0, 1.0]:
		PropFactory.box(c, Vector3(3.0, 0.5, 0.07), Vector3(0, 1.28, s * 0.82), wood, Vector3.ZERO, false)
		PropFactory.box(c, Vector3(0.07, 0.5, 1.7), Vector3(s * 1.46, 1.28, 0), wood, Vector3.ZERO, false)
		# Spoked wheels.
		PropFactory.cylinder(c, 0.9, 0.9, 0.1, Vector3(0, 0.9, s * 1.0), dark, Vector3(90, 0, 0), false, 20, 0, false)
		for k in 4:
			PropFactory.box(c, Vector3(1.7, 0.08, 0.1), Vector3(0, 0.9, s * 1.06), dark, Vector3(0, 0, k * 45.0), false, false)
	PropFactory.cylinder(c, 0.05, 0.05, 2.2, Vector3(0, 0.9, 0), dark, Vector3(90, 0, 0), false, 6, 0, false)
	# Shafts resting on the ground, and the load.
	for s in [-1.0, 1.0]:
		PropFactory.cylinder(c, 0.05, 0.06, 3.6, Vector3(2.9, 0.85, s * 0.45), dark, Vector3(0, 0, 90 - 8), false, 6, 0, false)
	var sack := PropFactory.cloth(Color(0.72, 0.62, 0.44))
	for i in 8:
		PropFactory.box(c, Vector3(0.55, 0.32, 0.9), Vector3(-0.9 + (i % 4) * 0.62, 1.2 + (i / 4) * 0.3, -0.3 + (i / 4) * 0.5), sack, Vector3(0, (i * 13) % 20 - 10, 0))
	PropFactory.box(c, Vector3(0.9, 0.8, 0.9), Vector3(0.9, 1.5, 0.3), PropFactory.wood(Color(0.55, 0.40, 0.25)), Vector3(0, 10, 0))


# --- telegraph line ----------------------------------------------------------------------

func _telegraph(root: Node3D) -> void:
	var wood := PropFactory.wood(Color(0.30, 0.22, 0.16))
	var pole_z := RAIL_Z + 7.5
	var x := -TRACK_HALF_LEN + 8.0
	var i := 0
	while x < TRACK_HALF_LEN - 6.0:
		var lean := _rng.randf_range(-4.0, 4.0)
		var broken := (i == 6)
		PropFactory.cylinder(root, 0.1, 0.16, 6.5, Vector3(x, RAIL_Y + 3.2, pole_z), wood, Vector3(lean, 0, lean * 0.5), true, 8, 0, false)
		PropFactory.box(root, Vector3(0.1, 0.1, 1.6), Vector3(x, RAIL_Y + 6.1, pole_z), wood, Vector3.ZERO, false, false)
		if not broken:
			for s in [-1.0, 1.0]:
				PropFactory.cylinder(root, 0.03, 0.03, 0.15, Vector3(x, RAIL_Y + 6.2, pole_z + s * 0.7), PropFactory.material(Color(0.8, 0.8, 0.75)), Vector3.ZERO, false, 6, 0, false)
		x += 25.0
		i += 1
	# Sagging wires between poles.
	var wire := PropFactory.material(Color(0.05, 0.05, 0.05), 0.5, 0.5)
	x = -TRACK_HALF_LEN + 8.0
	var n := 0
	while x + 25.0 < TRACK_HALF_LEN - 6.0:
		if n != 5 and n != 6:
			for s in [-1.0, 1.0]:
				PropFactory.box(root, Vector3(25.0, 0.025, 0.025), Vector3(x + 12.5, RAIL_Y + 6.0, pole_z + s * 0.7), wire, Vector3.ZERO, false, false)
		x += 25.0
		n += 1
