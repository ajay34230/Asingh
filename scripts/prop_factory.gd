class_name PropFactory
extends RefCounted
## Building blocks for the environment: weathered stone boxes and cylinders, columns,
## statues, symbols and procedural PBR-style materials (albedo, normal and roughness from
## small tiling noise textures, applied in world space so texel density stays constant at
## any object size). Everything is generated in code: no imported assets in Phase 1.

static var _materials := {}
static var _textures := {}


# --- procedural textures -----------------------------------------------------------------

static func _noise_texture(id: String, freq: float, octaves: int, seed_value: int, as_normal: bool,
		bump: float = 3.0, grey_low: float = 0.6, cellular: bool = false, size: int = 512) -> NoiseTexture2D:
	if _textures.has(id):
		return _textures[id]
	var fn := FastNoiseLite.new()
	fn.seed = seed_value
	fn.frequency = freq
	if cellular:
		fn.noise_type = FastNoiseLite.TYPE_CELLULAR
		fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		fn.cellular_jitter = 0.9
	else:
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.fractal_octaves = octaves
	var tex := NoiseTexture2D.new()
	tex.noise = fn
	tex.width = size
	tex.height = size
	tex.seamless = true
	if as_normal:
		tex.as_normal_map = true
		tex.bump_strength = bump
	else:
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(grey_low, grey_low, grey_low), Color(1, 1, 1)])
		ramp.offsets = PackedFloat32Array([0.0, 1.0])
		tex.color_ramp = ramp
	_textures[id] = tex
	return tex


static func sand_normal_texture() -> NoiseTexture2D:
	return _noise_texture("sand_n", 0.03, 3, 31, true, 1.6)


# --- materials ---------------------------------------------------------------------------

static func material(color: Color, roughness: float = 0.95, metallic: float = 0.0,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s_%s" % [color, roughness, metallic, emission, emission_energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_materials[key] = m
	return m


## Sandstone / mud-brick style surface: layered albedo, cracked normal map, rough.
static func stone(color: Color, strata: float = 0.9) -> StandardMaterial3D:
	var key := "stone_%s_%s" % [color, strata]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise_texture("stone_a", 0.018, 4, 11, false, 0.0, 0.62)
	m.normal_enabled = true
	m.normal_texture = _noise_texture("stone_n", 0.028, 1, 12, true, 4.5, 0.6, true)
	m.normal_scale = 1.0
	m.roughness = 0.96
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 3.0
	m.uv1_scale = Vector3(0.22, 0.22 + 0.9 * strata, 0.22)
	_materials[key] = m
	return m


static func sandstone() -> StandardMaterial3D:
	return stone(Color(0.62, 0.47, 0.31))


static func sandstone_dark() -> StandardMaterial3D:
	return stone(Color(0.42, 0.31, 0.22))


static func sandstone_pale() -> StandardMaterial3D:
	return stone(Color(0.72, 0.60, 0.44))


## Lime/mud plaster for house walls.
static func plaster() -> StandardMaterial3D:
	return stone(Color(0.80, 0.69, 0.52), 0.1)


static func wood(color: Color = Color(0.36, 0.25, 0.16)) -> StandardMaterial3D:
	var key := "wood_%s" % color
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise_texture("wood_a", 0.035, 3, 21, false, 0.0, 0.55)
	m.roughness = 0.82
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.4, 0.35, 1.4)
	_materials[key] = m
	return m


static func cloth(color: Color) -> StandardMaterial3D:
	return material(color, 1.0)


static func clay() -> StandardMaterial3D:
	return material(Color(0.58, 0.34, 0.20), 0.9)


static func iron() -> StandardMaterial3D:
	return material(Color(0.16, 0.15, 0.15), 0.55, 0.8)


static func bronze() -> StandardMaterial3D:
	return material(Color(0.56, 0.37, 0.15), 0.5, 0.75)


static func glow_bronze() -> StandardMaterial3D:
	return material(Color(0.60, 0.40, 0.16), 0.5, 0.7, Color(1.0, 0.62, 0.2), 0.55)


static func door_stone() -> StandardMaterial3D:
	return stone(Color(0.26, 0.21, 0.17), 0.3)


static func glow_lamp() -> StandardMaterial3D:
	return material(Color(1.0, 0.8, 0.45), 0.4, 0.0, Color(1.0, 0.66, 0.26), 3.0)


# --- primitives --------------------------------------------------------------------------

static func _add_collision(node: Node3D, shape: Shape3D, offset: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)
	node.add_child(body)


static func _variant(pos: Vector3) -> int:
	return int(absf(pos.x * 3.1 + pos.y * 5.3 + pos.z * 7.7)) % 4


## A box. Returns a Node3D root (position/rotation) holding the visual and, optionally,
## a static collider of exactly `size`. `weathered` uses an eroded, softened-edge mesh.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, collide: bool = true, weathered: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot_deg
	parent.add_child(root)
	var vis := MeshInstance3D.new()
	if weathered:
		vis.mesh = WeatheredMesh.box(_variant(pos))
		vis.scale = size
	else:
		var bm := BoxMesh.new()
		bm.size = size
		vis.mesh = bm
	vis.material_override = mat
	root.add_child(vis)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_collision(root, shape)
	return root


static func cylinder(parent: Node3D, radius_top: float, radius_bottom: float, height: float,
		pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, collide: bool = true,
		segments: int = 12, flutes: int = 0, weathered: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot_deg
	parent.add_child(root)
	var big := maxf(maxf(radius_top, radius_bottom), 0.001)
	var vis := MeshInstance3D.new()
	if weathered:
		vis.mesh = WeatheredMesh.cylinder(radius_top / big, radius_bottom / big, _variant(pos),
			maxi(segments, 8), 4, flutes)
		vis.scale = Vector3(big * 2.0, height, big * 2.0)
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = radius_top
		cm.bottom_radius = radius_bottom
		cm.height = height
		cm.radial_segments = segments
		cm.rings = 1
		vis.mesh = cm
	vis.material_override = mat
	root.add_child(vis)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = big
		shape.height = height
		_add_collision(root, shape)
	return root


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material,
		scale_xyz: Vector3 = Vector3.ONE, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_xyz
	parent.add_child(mi)
	if collide:
		var shape := SphereShape3D.new()
		shape.radius = radius
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## An eroded rock (weathered blob). `r` is the approximate radius in metres.
static func rock(parent: Node3D, r: Vector3, pos: Vector3, mat: Material, yaw_deg: float = 0.0,
		collide: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)
	var vis := MeshInstance3D.new()
	vis.mesh = WeatheredMesh.rock(_variant(pos))
	vis.scale = r
	vis.material_override = mat
	root.add_child(vis)
	if collide:
		var shape := SphereShape3D.new()
		shape.radius = minf(r.x, r.z) * 0.85
		_add_collision(root, shape, Vector3(0, r.y * 0.2, 0))
	return root


## A classical column. `broken` columns have a jagged top and a fallen drum nearby.
## `pos` is the base centre on the ground.
static func column(parent: Node3D, pos: Vector3, height: float, radius: float,
		broken: bool, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var stone_mat := sandstone_pale() if rng.randf() > 0.5 else sandstone()
	var flutes := 14 if radius > 0.7 else 0
	box(root, Vector3(radius * 2.8, radius * 0.9, radius * 2.8), Vector3(0, radius * 0.35, 0), stone_mat)
	var shaft_h := height * (rng.randf_range(0.35, 0.7) if broken else 1.0)
	cylinder(root, radius * 0.85, radius, shaft_h, Vector3(0, radius * 0.8 + shaft_h * 0.5, 0),
		stone_mat, Vector3.ZERO, true, 16, flutes)
	if not broken:
		box(root, Vector3(radius * 2.6, radius * 0.7, radius * 2.6),
			Vector3(0, radius * 0.8 + shaft_h + radius * 0.35, 0), stone_mat)
	else:
		var drum_len := height * 0.22
		cylinder(root, radius * 0.85, radius * 0.88, drum_len,
			Vector3(radius * 2.6, radius * 0.85, radius * 1.4), stone_mat,
			Vector3(88.0, rng.randf_range(0.0, 360.0), 90.0), true, 14, flutes)
	return root


## One of seven symbols (index 0-6), built as a shallow relief facing +Z, about 2 m across.
## These are decorative placeholders: Phase 1 has no puzzle logic.
static func symbol(parent: Node3D, index: int, pos: Vector3, symbol_scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * symbol_scale
	parent.add_child(root)
	var m := glow_bronze()
	var d := 0.35
	match index:
		0:
			var t := _torus(root, 0.55, 0.9, m)
			t.rotation_degrees = Vector3(90, 0, 0)
		1:
			var p := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(1.8, 1.6, d)
			p.mesh = pm
			p.material_override = m
			root.add_child(p)
		2:
			for k in 3:
				box(root, Vector3(0.35, 1.7 - 0.25 * k, d), Vector3(-0.6 + 0.6 * k, -0.125 * k, 0), m, Vector3.ZERO, false, false)
		3:
			box(root, Vector3(0.4, 1.8, d), Vector3.ZERO, m, Vector3.ZERO, false, false)
			box(root, Vector3(1.8, 0.4, d), Vector3.ZERO, m, Vector3.ZERO, false, false)
		4:
			box(root, Vector3(1.2, 1.2, d), Vector3.ZERO, m, Vector3(0, 0, 45), false, false)
			sphere(root, 0.22, Vector3(0, 0, d * 0.6), glow_bronze())
		5:
			var t2 := _torus(root, 0.4, 0.7, m)
			t2.rotation_degrees = Vector3(90, 0, 0)
			sphere(root, 0.28, Vector3(0.55, 0.55, d * 0.4), m)
		6:
			box(root, Vector3(1.9, 0.22, d), Vector3(0, -0.7, 0), m, Vector3.ZERO, false, false)
			var t3 := _torus(root, 0.18, 0.5, m)
			t3.rotation_degrees = Vector3(90, 0, 0)
			t3.position = Vector3(0, 0.1, 0)
			sphere(root, 0.16, Vector3(0, 0.1, d * 0.5), m)
	return root


static func _torus(parent: Node3D, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3(1, 0.4, 1)
	parent.add_child(mi)
	return mi


## A monumental guardian statue, roughly 28 m tall including its plinth.
## `damaged` removes one arm and tilts the head to suggest erosion and collapse.
static func statue(parent: Node3D, pos: Vector3, yaw_deg: float, damaged: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)
	var pale := sandstone_pale()
	var dark := sandstone()
	box(root, Vector3(10, 3, 10), Vector3(0, 1.5, 0), dark)
	box(root, Vector3(8, 1, 8), Vector3(0, 3.5, 0), pale)
	box(root, Vector3(2.8, 8, 2.8), Vector3(-1.9, 8.0, 0), pale)
	box(root, Vector3(2.8, 8, 2.8), Vector3(1.9, 8.0, 0), pale)
	box(root, Vector3(7.2, 3, 3.8), Vector3(0, 13.5, 0), dark)
	box(root, Vector3(6.6, 7, 3.6), Vector3(0, 18.5, 0), pale)
	box(root, Vector3(2.2, 7.5, 2.2), Vector3(-4.6, 17.5, 0.2), pale, Vector3(0, 0, 4))
	if not damaged:
		box(root, Vector3(2.2, 7.5, 2.2), Vector3(4.6, 17.5, 0.2), pale, Vector3(0, 0, -4))
		cylinder(root, 0.35, 0.45, 22.0, Vector3(5.6, 14.0, 1.6), dark, Vector3.ZERO, false, 8)
	else:
		box(root, Vector3(2.2, 3.2, 2.2), Vector3(4.6, 20.2, 0.2), pale, Vector3(0, 0, -20))
		box(root, Vector3(2.6, 2.0, 2.4), Vector3(8.5, 1.0, 5.5), pale, Vector3(10, 25, 14))
	var head := Node3D.new()
	head.position = Vector3(0, 23.0, 0)
	head.rotation_degrees = Vector3(0, 0, 6 if damaged else 0)
	root.add_child(head)
	box(head, Vector3(3.2, 3.4, 3.0), Vector3.ZERO, pale)
	cylinder(head, 1.1, 1.9, 3.4, Vector3(0, 3.2, 0), dark, Vector3.ZERO, false, 10)
	return root
