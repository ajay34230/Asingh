class_name PropFactory
extends RefCounted
## Primitive-based building blocks (boxes, cylinders, columns, statues, symbols).
## Everything is generated in code from Godot's built-in meshes, so there are no imported
## assets in Phase 1. These shapes are deliberately simple placeholders for the final art.

static var _materials := {}


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


static func sandstone() -> StandardMaterial3D:
	return material(Color(0.57, 0.41, 0.26))


static func sandstone_dark() -> StandardMaterial3D:
	return material(Color(0.40, 0.30, 0.21))


static func sandstone_pale() -> StandardMaterial3D:
	return material(Color(0.66, 0.53, 0.36))


static func bronze() -> StandardMaterial3D:
	return material(Color(0.56, 0.37, 0.15), 0.5, 0.75)


static func glow_bronze() -> StandardMaterial3D:
	return material(Color(0.60, 0.40, 0.16), 0.5, 0.7, Color(1.0, 0.62, 0.2), 0.55)


static func door_stone() -> StandardMaterial3D:
	return material(Color(0.30, 0.25, 0.20))


static func _add_collision(mi: MeshInstance3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot_deg: Vector3 = Vector3.ZERO, collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_collision(mi, shape)
	return mi


static func cylinder(parent: Node3D, radius_top: float, radius_bottom: float, height: float,
		pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, collide: bool = true,
		segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius_top, radius_bottom)
		shape.height = height
		_add_collision(mi, shape)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material,
		scale_xyz: Vector3 = Vector3.ONE, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_xyz
	parent.add_child(mi)
	if collide:
		var shape := SphereShape3D.new()
		shape.radius = radius
		_add_collision(mi, shape)
	return mi


## A classical column. `broken` columns have a jagged top and a fallen drum nearby.
## `pos` is the base centre on the ground.
static func column(parent: Node3D, pos: Vector3, height: float, radius: float,
		broken: bool, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var stone := sandstone_pale() if rng.randf() > 0.5 else sandstone()
	box(root, Vector3(radius * 2.8, radius * 0.9, radius * 2.8), Vector3(0, radius * 0.35, 0), stone)
	var shaft_h := height * (rng.randf_range(0.35, 0.7) if broken else 1.0)
	cylinder(root, radius * 0.85, radius, shaft_h, Vector3(0, radius * 0.8 + shaft_h * 0.5, 0), stone)
	if not broken:
		box(root, Vector3(radius * 2.6, radius * 0.7, radius * 2.6),
			Vector3(0, radius * 0.8 + shaft_h + radius * 0.35, 0), stone)
	else:
		# Fallen drum lying next to the stump.
		var drum_len := height * 0.22
		cylinder(root, radius * 0.85, radius * 0.88, drum_len,
			Vector3(radius * 2.6, radius * 0.85, radius * 1.4), stone,
			Vector3(88.0, rng.randf_range(0.0, 360.0), 90.0), true, 10)
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
		0:  # ring
			var t := _torus(root, 0.55, 0.9, m)
			t.rotation_degrees = Vector3(90, 0, 0)
		1:  # triangle
			var p := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(1.8, 1.6, d)
			p.mesh = pm
			p.material_override = m
			root.add_child(p)
		2:  # three bars
			for k in 3:
				box(root, Vector3(0.35, 1.7 - 0.25 * k, d), Vector3(-0.6 + 0.6 * k, -0.125 * k, 0), m, Vector3.ZERO, false)
		3:  # cross
			box(root, Vector3(0.4, 1.8, d), Vector3.ZERO, m, Vector3.ZERO, false)
			box(root, Vector3(1.8, 0.4, d), Vector3.ZERO, m, Vector3.ZERO, false)
		4:  # diamond with a dot
			box(root, Vector3(1.2, 1.2, d), Vector3.ZERO, m, Vector3(0, 0, 45), false)
			sphere(root, 0.22, Vector3(0, 0, d * 0.6), glow_bronze())
		5:  # ring with an offset dot
			var t2 := _torus(root, 0.4, 0.7, m)
			t2.rotation_degrees = Vector3(90, 0, 0)
			sphere(root, 0.28, Vector3(0.55, 0.55, d * 0.4), m)
		6:  # the "seventh mark": an eye over a line
			box(root, Vector3(1.9, 0.22, d), Vector3(0, -0.7, 0), m, Vector3.ZERO, false)
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


## A monumental guardian statue, roughly 24 m tall including its plinth.
## `damaged` removes one arm and tilts the head to suggest erosion and collapse.
static func statue(parent: Node3D, pos: Vector3, yaw_deg: float, damaged: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)
	var stone := sandstone_pale()
	var dark := sandstone()
	box(root, Vector3(10, 3, 10), Vector3(0, 1.5, 0), dark)                       # plinth
	box(root, Vector3(8, 1, 8), Vector3(0, 3.5, 0), stone)                        # upper plinth
	box(root, Vector3(2.8, 8, 2.8), Vector3(-1.9, 8.0, 0), stone)                 # legs
	box(root, Vector3(2.8, 8, 2.8), Vector3(1.9, 8.0, 0), stone)
	box(root, Vector3(7.2, 3, 3.8), Vector3(0, 13.5, 0), dark)                    # kilt / hips
	box(root, Vector3(6.6, 7, 3.6), Vector3(0, 18.5, 0), stone)                   # torso
	box(root, Vector3(2.2, 7.5, 2.2), Vector3(-4.6, 17.5, 0.2), stone, Vector3(0, 0, 4))
	if not damaged:
		box(root, Vector3(2.2, 7.5, 2.2), Vector3(4.6, 17.5, 0.2), stone, Vector3(0, 0, -4))
		cylinder(root, 0.35, 0.45, 22.0, Vector3(5.6, 14.0, 1.6), dark, Vector3.ZERO, false, 8)  # staff
	else:
		box(root, Vector3(2.2, 3.2, 2.2), Vector3(4.6, 20.2, 0.2), stone, Vector3(0, 0, -20))
		box(root, Vector3(2.6, 2.0, 2.4), Vector3(8.5, 1.0, 5.5), stone, Vector3(10, 25, 14))  # fallen arm
	var head := Node3D.new()
	head.position = Vector3(0, 23.0, 0)
	head.rotation_degrees = Vector3(0, 0, 6 if damaged else 0)
	root.add_child(head)
	box(head, Vector3(3.2, 3.4, 3.0), Vector3.ZERO, stone)
	cylinder(head, 1.1, 1.9, 3.4, Vector3(0, 3.2, 0), dark, Vector3.ZERO, false, 8)   # tall crown
	return root
