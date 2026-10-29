class_name RuinsBuilder
extends RefCounted
## Ruined caravan station, sandstone formations, boulders, riverbed gravel, dry shrubs and
## dead trees. Small repeated objects use MultiMesh instancing (a handful of draw calls
## instead of hundreds). Everything is procedural and seeded, so the layout is repeatable.

const STATION_CENTRE := Vector2(48.0, 40.0)

var terrain: TerrainBuilder
var _rng := RandomNumberGenerator.new()


func _init(t: TerrainBuilder, seed_value: int = 777) -> void:
	terrain = t
	_rng.seed = seed_value


func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Ruins"
	parent.add_child(root)
	_caravan_station(root)
	_formations(root)
	_boulders(root)
	_riverbed_stones(root)
	_shrubs(root)
	_dead_trees(root)
	return root


# --- helpers -------------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	return terrain.sample_height(x, z)


## A random point inside the valley that avoids the entrance forecourt and the start mound.
func _random_point(margin: float = 20.0) -> Vector2:
	for _attempt in 40:
		var p := Vector2(_rng.randf_range(-TerrainBuilder.HALF + margin, TerrainBuilder.HALF - margin),
			_rng.randf_range(-TerrainBuilder.HALF + margin + 15.0, TerrainBuilder.HALF - margin))
		if p.distance_to(TerrainBuilder.FORECOURT) < 55.0:
			continue
		if p.distance_to(TerrainBuilder.START_MOUND) < 30.0:
			continue
		return p
	return Vector2(0, 0)


func _scatter(parent: Node3D, mesh: Mesh, name_: String, points: Array, scale_min: Vector3,
		scale_max: Vector3, color_a: Color, color_b: Color, sink: float) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var p: Vector2 = points[i]
		var s := Vector3(
			_rng.randf_range(scale_min.x, scale_max.x),
			_rng.randf_range(scale_min.y, scale_max.y),
			_rng.randf_range(scale_min.z, scale_max.z))
		var b := Basis.from_euler(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.2, 0.2)))
		b = b * Basis.from_scale(s)
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, _ground(p.x, p.y) - sink * s.y, p.y)))
		mm.set_instance_color(i, color_a.lerp(color_b, _rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mmi.material_override = mat
	parent.add_child(mmi)


# --- caravan station ----------------------------------------------------------------

## A straight wall made of 3 m segments; some segments are lower or missing (collapsed).
func _wall_run(parent: Node3D, a: Vector2, b: Vector2, height: float, thickness: float,
		gap_chance: float, door_at: float = -1.0) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var along_x := absf(dir.x) > 0.5
	var segs := int(ceil(length / 3.0))
	var mats := [PropFactory.sandstone(), PropFactory.sandstone_pale(), PropFactory.sandstone_dark()]
	for i in segs:
		var t := (i + 0.5) / float(segs)
		if door_at >= 0.0 and absf(t - door_at) < 0.1:
			continue
		if _rng.randf() < gap_chance:
			continue
		var c := a.lerp(b, t)
		var h := height * _rng.randf_range(0.35, 1.0)
		var g := _ground(c.x, c.y)
		var size := Vector3(3.05, h + 1.5, thickness) if along_x else Vector3(thickness, h + 1.5, 3.05)
		PropFactory.box(parent, size, Vector3(c.x, g + (h - 1.5) * 0.5, c.y),
			mats[_rng.randi() % mats.size()], Vector3(0, _rng.randf_range(-2.0, 2.0), 0))


func _caravan_station(root: Node3D) -> void:
	var st := Node3D.new()
	st.name = "CaravanStation"
	root.add_child(st)
	var c := STATION_CENTRE
	var hw := 15.0
	var hd := 11.0
	var wall_h := 4.6
	_wall_run(st, Vector2(c.x - hw, c.y - hd), Vector2(c.x + hw, c.y - hd), wall_h, 1.2, 0.1)
	_wall_run(st, Vector2(c.x - hw, c.y + hd), Vector2(c.x + hw, c.y + hd), wall_h, 1.2, 0.18, 0.35)
	_wall_run(st, Vector2(c.x - hw, c.y - hd), Vector2(c.x - hw, c.y + hd), wall_h, 1.2, 0.3)
	_wall_run(st, Vector2(c.x + hw, c.y - hd), Vector2(c.x + hw, c.y + hd), wall_h, 1.2, 0.2)

	var wood := PropFactory.material(Color(0.34, 0.25, 0.17))
	var stone := PropFactory.sandstone()
	# Well in the courtyard.
	var wg := _ground(c.x - 3.0, c.y - 1.0)
	PropFactory.cylinder(st, 1.9, 2.0, 1.4, Vector3(c.x - 3.0, wg + 0.5, c.y - 1.0), stone, Vector3.ZERO, true, 14)
	PropFactory.cylinder(st, 1.4, 1.4, 0.1, Vector3(c.x - 3.0, wg + 1.15, c.y - 1.0), PropFactory.door_stone(), Vector3.ZERO, false, 14)
	# Lean-to along the north wall: posts, a sagging beam, and a collapsed roof plank.
	for k in 4:
		var px := c.x - 10.0 + k * 4.5
		var pg := _ground(px, c.y - hd + 3.5)
		PropFactory.box(st, Vector3(0.45, 3.4, 0.45), Vector3(px, pg + 1.5, c.y - hd + 3.5), wood, Vector3(0, 0, _rng.randf_range(-4, 4)))
	PropFactory.box(st, Vector3(16, 0.4, 0.5), Vector3(c.x - 3.0, _ground(c.x - 3.0, c.y - hd + 3.5) + 3.1, c.y - hd + 3.5), wood, Vector3(0, 0, 5), false)
	PropFactory.box(st, Vector3(9, 0.3, 3.6), Vector3(c.x + 4.0, _ground(c.x + 4.0, c.y - hd + 4.5) + 1.0, c.y - hd + 4.5), wood, Vector3(14, 6, 18), false)
	# Low stall partitions along the east side.
	for k in 4:
		var sz := c.y - 6.0 + k * 4.0
		PropFactory.box(st, Vector3(5, 1.1, 0.35), Vector3(c.x + hw - 3.2, _ground(c.x + hw - 3.2, sz) + 0.4, sz), stone)
	# A broken cart half buried in sand.
	var cg := _ground(c.x + 3.0, c.y + 4.0)
	PropFactory.box(st, Vector3(3.6, 0.3, 1.8), Vector3(c.x + 3.0, cg + 0.5, c.y + 4.0), wood, Vector3(0, 25, 12))
	PropFactory.cylinder(st, 0.95, 0.95, 0.18, Vector3(c.x + 4.6, cg + 0.6, c.y + 5.1), wood, Vector3(90, 25, 0), false, 14)
	PropFactory.cylinder(st, 0.95, 0.95, 0.18, Vector3(c.x + 0.8, cg + 0.2, c.y + 3.0), wood, Vector3(80, 25, 40), false, 14)
	# A few storage jars and pottery.
	var clay := PropFactory.material(Color(0.62, 0.36, 0.20))
	for k in 7:
		var jx := c.x - 11.0 + _rng.randf_range(0.0, 5.0)
		var jz := c.y + 3.0 + _rng.randf_range(0.0, 5.0)
		var jr := _rng.randf_range(0.35, 0.6)
		var jy := _ground(jx, jz) + jr * 0.9
		var tip := Vector3(_rng.randf_range(-70, 70), 0, _rng.randf_range(-70, 70)) if k > 3 else Vector3.ZERO
		PropFactory.sphere(st, jr, Vector3(jx, jy, jz), clay, Vector3(1, 1.25, 1), false).rotation_degrees = tip
	# Collapsed masonry spilled outside the south-west corner.
	for k in 12:
		var rx := c.x - hw - _rng.randf_range(0.5, 5.0)
		var rz := c.y + hd + _rng.randf_range(-3.0, 4.0)
		var s := Vector3(_rng.randf_range(0.8, 2.2), _rng.randf_range(0.5, 1.4), _rng.randf_range(0.8, 2.0))
		PropFactory.box(st, s, Vector3(rx, _ground(rx, rz) + s.y * 0.3, rz), stone,
			Vector3(_rng.randf_range(-15, 15), _rng.randf_range(0, 360), _rng.randf_range(-15, 15)))


# --- natural features ---------------------------------------------------------------

func _formations(root: Node3D) -> void:
	var f := Node3D.new()
	f.name = "SandstoneFormations"
	root.add_child(f)
	var strata := [
		PropFactory.material(Color(0.62, 0.40, 0.24)),
		PropFactory.material(Color(0.74, 0.54, 0.33)),
		PropFactory.material(Color(0.50, 0.32, 0.20)),
		PropFactory.material(Color(0.80, 0.64, 0.44)),
	]
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 400:
		tries += 1
		var p := _random_point(30.0)
		if absf(p.x - terrain.river_x(p.y)) < 40.0:
			continue
		if p.distance_to(STATION_CENTRE) < 35.0:
			continue
		# Keep the sight-line from the start viewpoint to the entrance clear.
		var cp := Geometry2D.get_closest_point_to_segment(p, TerrainBuilder.START_MOUND, Vector2(0.0, -168.0))
		if p.distance_to(cp) < 45.0:
			continue
		var g := _ground(p.x, p.y)
		var mesa := placed % 4 == 0
		if mesa:
			# Wide flat-topped mesa built from stacked, slightly different strata bands.
			var r := _rng.randf_range(9.0, 15.0)
			var y := g - 2.0
			for band in 4:
				var bh := _rng.randf_range(3.0, 5.0)
				var br := r * (1.0 - band * 0.06)
				PropFactory.cylinder(f, br * 0.94, br, bh, Vector3(p.x, y + bh * 0.5, p.y),
					strata[(band + placed) % strata.size()], Vector3.ZERO, true, 14)
				y += bh
		else:
			# Eroded hoodoo: narrow shaft with a wider cap.
			var h1 := _rng.randf_range(6.0, 11.0)
			var r1 := _rng.randf_range(2.2, 3.6)
			var lean := Vector3(_rng.randf_range(-3, 3), _rng.randf_range(0, 360), _rng.randf_range(-3, 3))
			PropFactory.cylinder(f, r1 * 0.6, r1, h1, Vector3(p.x, g + h1 * 0.5 - 1.5, p.y), strata[placed % 4], lean, true, 10)
			PropFactory.cylinder(f, r1 * 1.3, r1 * 0.8, 2.2, Vector3(p.x, g + h1 - 0.4, p.y), strata[(placed + 1) % 4], lean, true, 10)
		placed += 1


func _boulders(root: Node3D) -> void:
	var pts := []
	for i in 90:
		pts.append(_random_point(12.0))
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_scatter(root, mesh, "Boulders", pts, Vector3(0.6, 0.4, 0.6), Vector3(2.6, 1.6, 2.4),
		Color(0.56, 0.40, 0.27), Color(0.74, 0.58, 0.40), 0.25)


func _riverbed_stones(root: Node3D) -> void:
	var pts := []
	for i in 160:
		var z := _rng.randf_range(-170.0, 190.0)
		pts.append(Vector2(terrain.river_x(z) + _rng.randf_range(-16.0, 16.0), z))
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	_scatter(root, mesh, "RiverbedGravel", pts, Vector3(0.15, 0.1, 0.15), Vector3(0.7, 0.4, 0.7),
		Color(0.55, 0.50, 0.44), Color(0.74, 0.68, 0.58), 0.1)


func _shrubs(root: Node3D) -> void:
	var pts := []
	for i in 120:
		pts.append(_random_point(10.0))
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	_scatter(root, mesh, "DryShrubs", pts, Vector3(0.5, 0.3, 0.5), Vector3(1.3, 0.8, 1.3),
		Color(0.36, 0.33, 0.18), Color(0.55, 0.47, 0.25), 0.1)


func _dead_trees(root: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "DeadTrees"
	root.add_child(trees)
	var wood := PropFactory.material(Color(0.30, 0.24, 0.18))
	for i in 7:
		var p := _random_point(20.0)
		var g := _ground(p.x, p.y)
		var h := _rng.randf_range(3.0, 5.0)
		var yaw := _rng.randf_range(0.0, 360.0)
		var trunk := PropFactory.cylinder(trees, 0.12, 0.3, h, Vector3(p.x, g + h * 0.5 - 0.2, p.y), wood, Vector3(_rng.randf_range(-12, 12), yaw, _rng.randf_range(-12, 12)), false, 6)
		for k in 3:
			var br := PropFactory.cylinder(trunk, 0.04, 0.12, 1.6, Vector3(0, h * (0.1 + 0.2 * k), 0), wood, Vector3(0, k * 120.0, 50.0), false, 5)
			br.name = "Branch"
